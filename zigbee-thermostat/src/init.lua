-- Zigbee Driver utilities
local ZigbeeDriver          = require "st.zigbee"
local device_management     = require "st.zigbee.device_management"
local defaults              = require "st.zigbee.defaults"
local utils                 = require "st.utils"
local constants             = require "st.zigbee.constants"
local data_types            = require "st.zigbee.data_types"
local cluster_base          = require "st.zigbee.cluster_base"
local xiaomi_utils          = require "xiaomi_utils"

-- Zigbee Spec Utils
local clusters                      = require "st.zigbee.zcl.clusters"
local PowerConfiguration            = clusters.PowerConfiguration
local Thermostat                    = clusters.Thermostat
local TemperatureMeasurement        = clusters.TemperatureMeasurement
local ElectricalMeasurement          = clusters.ElectricalMeasurement
local SimpleMetering                 = clusters.SimpleMetering
local RelativeHumidityCluster        = clusters.RelativeHumidity

local ThermostatSystemMode      = Thermostat.attributes.SystemMode
local ThermostatControlSequence = Thermostat.attributes.ControlSequenceOfOperation

-- Capabilities
local capabilities              = require "st.capabilities"
local Temperature               = capabilities.temperatureMeasurement
local ThermostatCoolingSetpoint = capabilities.thermostatCoolingSetpoint
local ThermostatHeatingSetpoint = capabilities.thermostatHeatingSetpoint
local ThermostatMode            = capabilities.thermostatMode
local ThermostatOperatingState  = capabilities.thermostatOperatingState
local Battery                   = capabilities.battery
local PowerSource               = capabilities.powerSource
local RelativeHumidity          = capabilities.relativeHumidityMeasurement
local PowerMeter                = capabilities.powerMeter
local EnergyMeter               = capabilities.energyMeter
local Refresh                   = capabilities.refresh

-- lux thermostat uses min 5V, max of 6.5V
local BAT_MIN = 50.0
local BAT_MAX = 65.0

local MFG_CODE = 0x115F
local W500_PRESET_ATTR = 0x0311

local DEFAULT_ELECTRICAL_MEASUREMENT_DIVISOR = 10
local DEFAULT_SIMPLE_METERING_DIVISOR = 1000

-- W500 preset attribute values (original preset strings in comments)
local W500_PRESET_VALUE_TO_THERMOSTAT_MODE = {
  [1] = ThermostatMode.thermostatMode.home,    -- home
  [2] = ThermostatMode.thermostatMode.away,    -- away
  [3] = ThermostatMode.thermostatMode.asleep,  -- sleep
  [5] = ThermostatMode.thermostatMode.dayoff,  -- vacation
  [6] = ThermostatMode.thermostatMode.comfort, -- evening
  [8] = ThermostatMode.thermostatMode.manual   -- manual
}

local W500_THERMOSTAT_MODE_TO_PRESET_VALUE = {
  [ThermostatMode.thermostatMode.home.NAME] = 1,    -- home
  [ThermostatMode.thermostatMode.away.NAME] = 2,    -- away
  [ThermostatMode.thermostatMode.asleep.NAME] = 3,  -- sleep
  [ThermostatMode.thermostatMode.dayoff.NAME] = 5,  -- vacation
  [ThermostatMode.thermostatMode.comfort.NAME] = 6, -- evening
  [ThermostatMode.thermostatMode.manual.NAME] = 8   -- manual
}

-- Map the Zigbee attribute value to the corresponding capability for supported modes
local SUPPORTED_THERMOSTAT_MODES = {
  [ThermostatControlSequence.COOLING_ONLY]                    = { ThermostatMode.thermostatMode.off.NAME,
                                                                  ThermostatMode.thermostatMode.cool.NAME},
  [ThermostatControlSequence.COOLING_WITH_REHEAT]             = { ThermostatMode.thermostatMode.off.NAME,
                                                                  ThermostatMode.thermostatMode.cool.NAME},
  [ThermostatControlSequence.HEATING_ONLY]                    = { ThermostatMode.thermostatMode.off.NAME,
                                                                  ThermostatMode.thermostatMode.heat.NAME,
                                                                  ThermostatMode.thermostatMode.emergency_heat.NAME},
  [ThermostatControlSequence.HEATING_WITH_REHEAT]             = { ThermostatMode.thermostatMode.off.NAME,
                                                                  ThermostatMode.thermostatMode.heat.NAME,
                                                                  ThermostatMode.thermostatMode.emergency_heat.NAME},
  [ThermostatControlSequence.COOLING_AND_HEATING4PIPES]             = { ThermostatMode.thermostatMode.off.NAME,
                                                                        ThermostatMode.thermostatMode.heat.NAME,
                                                                        ThermostatMode.thermostatMode.auto.NAME,
                                                                        ThermostatMode.thermostatMode.cool.NAME,
                                                                        ThermostatMode.thermostatMode.emergency_heat.NAME},
  [ThermostatControlSequence.COOLING_AND_HEATING4PIPES_WITH_REHEAT] = { ThermostatMode.thermostatMode.off.NAME,
                                                                        ThermostatMode.thermostatMode.heat.NAME,
                                                                        ThermostatMode.thermostatMode.auto.NAME,
                                                                        ThermostatMode.thermostatMode.cool.NAME,
                                                                        ThermostatMode.thermostatMode.emergency_heat.NAME}
}

local W500_SUPPORTED_MODES = {
  ThermostatMode.thermostatMode.off.NAME,
  ThermostatMode.thermostatMode.home.NAME,
  ThermostatMode.thermostatMode.away.NAME,
  ThermostatMode.thermostatMode.comfort.NAME,
  ThermostatMode.thermostatMode.dayoff.NAME,
  ThermostatMode.thermostatMode.manual.NAME,
  ThermostatMode.thermostatMode.asleep.NAME
}

-- TemperatureMeasurement cluster defaults
local temperature_measurement_defaults = {
  MIN_TEMP = "MIN_TEMP",
  MAX_TEMP = "MAX_TEMP"
}

local battery_voltage_handler = function(driver, device, battery_voltage)
  if (battery_voltage.value == 0) then -- this means we're plugged in
    device:emit_event(PowerSource.powerSource.mains())
    device:emit_event(Battery.battery(100))
  else
    local perc_value = utils.round((battery_voltage.value - BAT_MIN)/(BAT_MAX - BAT_MIN) * 100)
    device:emit_event(Battery.battery(utils.clamp_value(perc_value, 0, 100)))
  end
end

local function get_divisor(device, key)
  local divisor = device:get_field(key)
  if divisor == nil or divisor == 0 then
    if key == constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY then
      return DEFAULT_ELECTRICAL_MEASUREMENT_DIVISOR
    end
    if key == constants.SIMPLE_METERING_DIVISOR_KEY then
      return DEFAULT_SIMPLE_METERING_DIVISOR
    end
    return 1
  end
  return divisor
end

local function active_power_handler(driver, device, value, zb_rx)
  local divisor = get_divisor(device, constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY)
  local power = value.value / divisor
  device:emit_event(PowerMeter.power({ value = power, unit = "W" }))
end

local function current_summation_delivered_handler(driver, device, value, zb_rx)
  local divisor = get_divisor(device, constants.SIMPLE_METERING_DIVISOR_KEY)
  local energy = value.value / divisor
  device:emit_event(EnergyMeter.energy({ value = energy, unit = "kWh" }))
end

local power_source_handler = function(driver, device, battery_alarm_mask)
  if (battery_alarm_mask:is_bit_set(31)) then
    device:emit_event(PowerSource.powerSource.battery())
  else
    device:emit_event(PowerSource.powerSource.mains())
  end
end

local supported_thermostat_modes_handler = function(driver, device, supported_modes)
  device:emit_event(ThermostatMode.supportedThermostatModes(W500_SUPPORTED_MODES, { visibility = { displayed = false } }))
end

local thermostat_mode_handler = function(driver, device, thermostat_mode)
  if thermostat_mode.value == ThermostatSystemMode.OFF then
    device:emit_event(ThermostatMode.thermostatMode.off())
    return
  end

  device:send(cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, W500_PRESET_ATTR, MFG_CODE))
end

local thermostat_operating_state_handler = function(driver, device, operating_state)
  if (operating_state:is_heat_second_stage_on_set() or operating_state:is_heat_on_set()) then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.heating())
  elseif (operating_state:is_cool_second_stage_on_set() or operating_state:is_cool_on_set()) then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.cooling())
  elseif (operating_state:is_fan_on_set()) then
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.fan_only())
  else
    device:emit_event(ThermostatOperatingState.thermostatOperatingState.idle())
  end
end

local preset_mode_handler = function(driver, device, value, zb_rx)
  local event_builder = W500_PRESET_VALUE_TO_THERMOSTAT_MODE[value.value]
  if event_builder ~= nil then
    device:emit_event(event_builder())
  end
end

local set_thermostat_mode = function(driver, device, command)
  if command.args.mode == ThermostatMode.thermostatMode.off.NAME then
    device:send_to_component(command.component, Thermostat.attributes.SystemMode:write(device, ThermostatSystemMode.OFF))
    device.thread:call_with_delay(1, function(d)
      device:send_to_component(command.component, Thermostat.attributes.SystemMode:read(device))
    end)
    return
  end

  local preset_value = W500_THERMOSTAT_MODE_TO_PRESET_VALUE[command.args.mode]
  if preset_value ~= nil then
    device:send_to_component(command.component, Thermostat.attributes.SystemMode:write(device, ThermostatSystemMode.HEAT))
    local message = cluster_base.write_attribute(
      device,
      data_types.ClusterId(xiaomi_utils.OppleCluster),
      data_types.AttributeId(W500_PRESET_ATTR),
      data_types.Uint8(preset_value)
    )
    message.body.zcl_header.frame_ctrl:set_mfg_specific()
    message.body.zcl_header.mfg_code = data_types.validate_or_build_type(MFG_CODE, data_types.Uint16, "mfg_code")
    device:send(message)

    device.thread:call_with_delay(1, function(d)
      device:send_to_component(command.component, Thermostat.attributes.SystemMode:read(device))
      device:send(cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, W500_PRESET_ATTR, MFG_CODE))
    end)
    return
  end

  -- No other system modes supported besides OFF/HEAT; preset write handled above.
end

local thermostat_mode_setter = function(mode_name)
  return function(driver, device, command)
    return set_thermostat_mode(driver, device, {component = command.component, args = {mode = mode_name}})
  end
end


local setpoint_limit_handler_factory = function(min_or_max, heat_or_cool)

  local field = 'setpoint_' .. min_or_max .. '_' .. heat_or_cool
  local paired_field = 'setpoint_min_' .. heat_or_cool
  if min_or_max == 'min' then
    paired_field = 'setpoint_max_' .. heat_or_cool
  end

  return function(driver, device, setpoint)
    local celsius_value =  setpoint.value / 100.0
    device:set_field(field, celsius_value)
    if device:get_field(field) and device:get_field(paired_field) then

      local event_constructor = capabilities.thermostatHeatingSetpoint.heatingSetpointRange
      
      device:emit_event(event_constructor(
        {
          unit = 'C',
          value = {
            minimum = device:get_field('setpoint_min_' .. heat_or_cool),
            maximum = device:get_field('setpoint_max_' .. heat_or_cool)
          }
        }
      ))

      device:set_field(field, nil)
      device:set_field(paired_field, nil)
    end
  end
end

--TODO: Update this once we've decided how to handle setpoint commands
local set_setpoint_factory = function(setpoint_attribute)
  return function(driver, device, command)
    local value = command.args.setpoint
    if (value >= 40) then -- assume this is a fahrenheit value
      value = utils.f_to_c(value)
    end
    device:send_to_component(command.component, setpoint_attribute:write(device, utils.round(value*100)))

    device.thread:call_with_delay(2, function(d)
      device:send_to_component(command.component, setpoint_attribute:read(device))
    end)
  end
end

local temperature_measurement_min_max_attr_handler = function(minOrMax)
  return function(driver, device, value, zb_rx)
    local raw_temp = value.value
    local celc_temp = raw_temp / 100.0
    local temp_scale = "C"

    device:set_field(string.format("%s", minOrMax), celc_temp)

    local min = device:get_field(temperature_measurement_defaults.MIN_TEMP)
    local max = device:get_field(temperature_measurement_defaults.MAX_TEMP)

    if min ~= nil and max ~= nil then
      if min < max then
        device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.temperatureMeasurement.temperatureRange({ value = { minimum = min, maximum = max }, unit = temp_scale }))
        device:set_field(temperature_measurement_defaults.MIN_TEMP, nil)
        device:set_field(temperature_measurement_defaults.MAX_TEMP, nil)
      else
        device.log.warn_with({hub_logs = true}, string.format("Device reported a min temperature %d that is not lower than the reported max temperature %d", min, max))
      end
    end
  end
end

local RelativeHumidityClusterHandler = function(driver, device, value, zb_rx)
  local percent = utils.clamp_value(value.value / 100, 0.0, 100.0)
  if percent < 99 then -- filter out spurious values
    device:emit_event(RelativeHumidity.humidity(percent))
  end
end

local do_refresh = function(self, device)
  local attributes = {
    Thermostat.attributes.OccupiedHeatingSetpoint,
    Thermostat.attributes.LocalTemperature,
    Thermostat.attributes.ControlSequenceOfOperation,
    Thermostat.attributes.ThermostatRunningState,
    Thermostat.attributes.SystemMode,
    Thermostat.attributes.MinHeatSetpointLimit,
    Thermostat.attributes.MaxHeatSetpointLimit,
    Thermostat.attributes.ThermostatOperatingState,
    ElectricalMeasurement.attributes.ActivePower,
    SimpleMetering.attributes.CurrentSummationDelivered,
    RelativeHumidityCluster.attributes.MeasuredValue
  }

  for _, attribute in pairs(attributes) do
    device:send(attribute:read(device))
  end

  device:emit_event(ThermostatMode.supportedThermostatModes(W500_SUPPORTED_MODES, { visibility = { displayed = false } }))

  device:send(cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, W500_PRESET_ATTR, MFG_CODE))
end

local do_configure = function(self, device)
  device:send(device_management.build_bind_request(device, Thermostat.ID, self.environment_info.hub_zigbee_eui))
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(PowerConfiguration.attributes.BatteryVoltage:configure_reporting(device, 30, 21600, 1))

  device:send(device_management.build_bind_request(device, ElectricalMeasurement.ID, self.environment_info.hub_zigbee_eui))
  device:send(device_management.build_bind_request(device, SimpleMetering.ID, self.environment_info.hub_zigbee_eui))
end

local device_added = function(self, device)
  device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, DEFAULT_ELECTRICAL_MEASUREMENT_DIVISOR, { persists = true })
  device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, DEFAULT_SIMPLE_METERING_DIVISOR, { persists = true })

  device:send(TemperatureMeasurement.attributes.MinMeasuredValue:read(device))
  device:send(TemperatureMeasurement.attributes.MaxMeasuredValue:read(device))
  do_refresh(self, device)
end

local zigbee_thermostat_driver = {
  supported_capabilities = {
    Temperature,
    ThermostatCoolingSetpoint,
    ThermostatHeatingSetpoint,
    ThermostatMode,
    ThermostatOperatingState,
    RelativeHumidity,
    PowerMeter,
    EnergyMeter,
    Battery,
    PowerSource,
    Refresh
  },
  zigbee_handlers = {
    attr = {
      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryVoltage.ID] = battery_voltage_handler,
        [PowerConfiguration.attributes.BatteryAlarmState.ID] = power_source_handler
      },
      [xiaomi_utils.OppleCluster] = {
        [0x00F7] = xiaomi_utils.handler,
        [W500_PRESET_ATTR] = preset_mode_handler
      },
      [Thermostat.ID] = {
        [Thermostat.attributes.ControlSequenceOfOperation.ID] = supported_thermostat_modes_handler,
        [Thermostat.attributes.ThermostatRunningState.ID] = thermostat_operating_state_handler,
        [Thermostat.attributes.ThermostatRunningMode.ID] = thermostat_mode_handler,
        [Thermostat.attributes.SystemMode.ID] = thermostat_mode_handler,
        [Thermostat.attributes.MinHeatSetpointLimit.ID] = setpoint_limit_handler_factory('min', 'heat'),
        [Thermostat.attributes.MaxHeatSetpointLimit.ID] = setpoint_limit_handler_factory('max', 'heat'),
        [Thermostat.attributes.MinCoolSetpointLimit.ID] = setpoint_limit_handler_factory('min', 'cool'),
        [Thermostat.attributes.MaxCoolSetpointLimit.ID] = setpoint_limit_handler_factory('max', 'cool'),
      },
      [ElectricalMeasurement.ID] = {
        [ElectricalMeasurement.attributes.ActivePower.ID] = active_power_handler
      },
      [SimpleMetering.ID] = {
        [SimpleMetering.attributes.CurrentSummationDelivered.ID] = current_summation_delivered_handler
      },
      [TemperatureMeasurement.ID] = {
        [TemperatureMeasurement.attributes.MinMeasuredValue.ID] = temperature_measurement_min_max_attr_handler(temperature_measurement_defaults.MIN_TEMP),
        [TemperatureMeasurement.attributes.MaxMeasuredValue.ID] = temperature_measurement_min_max_attr_handler(temperature_measurement_defaults.MAX_TEMP),
      },
      [RelativeHumidityCluster.ID] = {
        [RelativeHumidityCluster.attributes.MeasuredValue.ID] = RelativeHumidityClusterHandler
      }
    }
  },
  capability_handlers = {
    [ThermostatMode.ID] = {
      [ThermostatMode.commands.setThermostatMode.NAME] = set_thermostat_mode,
      [ThermostatMode.commands.auto.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.auto.NAME),
      [ThermostatMode.commands.off.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.off.NAME),
      [ThermostatMode.commands.cool.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.cool.NAME),
      [ThermostatMode.commands.heat.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.heat.NAME),
      [ThermostatMode.commands.emergencyHeat.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.emergency_heat.NAME)
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
    [capabilities.thermostatCoolingSetpoint.ID] = {
      [capabilities.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME] = set_setpoint_factory(clusters.Thermostat.attributes.OccupiedCoolingSetpoint)
    },
    [capabilities.thermostatHeatingSetpoint.ID] = {
      [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = set_setpoint_factory(clusters.Thermostat.attributes.OccupiedHeatingSetpoint)
    }
  },
  lifecycle_handlers = {
    doConfigure = do_configure,
    added = device_added
  },
  
  health_check = false,
}

defaults.register_for_default_handlers(zigbee_thermostat_driver, zigbee_thermostat_driver.supported_capabilities)
local thermostat = ZigbeeDriver("zigbee-thermostat", zigbee_thermostat_driver)
thermostat:run()