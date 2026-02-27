-- Zigbee Driver utilities
local ZigbeeDriver          = require "st.zigbee"
local device_management     = require "st.zigbee.device_management"
local defaults              = require "st.zigbee.defaults"
local utils                 = require "st.utils"
local constants             = require "st.zigbee.constants"
local data_types            = require "st.zigbee.data_types"
local cluster_base          = require "st.zigbee.cluster_base"
local xiaomi_utils          = require "xiaomi_utils"
local driver_utils          = require "driver_utils"
local log                   = require "log"

-- Zigbee Spec Utils
local clusters                      = require "st.zigbee.zcl.clusters"
local PowerConfiguration            = clusters.PowerConfiguration
local Thermostat                    = clusters.Thermostat
local TemperatureMeasurement        = clusters.TemperatureMeasurement
local ElectricalMeasurement          = clusters.ElectricalMeasurement
local SimpleMetering                 = clusters.SimpleMetering
local RelativeHumidityCluster        = clusters.RelativeHumidity

local ThermostatSystemMode      = Thermostat.attributes.SystemMode

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
local W500_PRESET_TEMPS_ATTR = 0x0317
-- Additional manufacturer-specific preset temperature attributes (not handled yet):
-- preset_temps_packed = 0x0317 (LVBytes)
-- home_preset_temperature = 0x1001 (uint16)
-- away_preset_temperature = 0x1002 (uint16)
-- sleep_preset_temperature = 0x1003 (uint16)
-- day_off_preset_temperature = 0x1005 (uint16)
-- comfort_preset_temperature = 0x1006 (uint16)

-- Reference (Python) for parsing/building preset_temps_packed:
-- def _parse_preset_temps(self, data: bytes) -> dict:
--     """Parse packed preset temperatures."""
--     temps = {}
--     if len(data) < 6:
--         return temps
--     num_presets = data[0]  # First byte is the count (0x05 = 5 presets)
--     pos = 1
--     for _ in range(num_presets):  # Only parse the expected number of records
--         if pos + 5 > len(data):
--             break
--         mode_id = data[pos]
--         temp = data[pos + 3] | (data[pos + 4] << 8)
--         if mode_id in (PRESET_HOME, PRESET_AWAY, PRESET_SLEEP, PRESET_DAYOFF, PRESET_COMFORT):
--             temps[mode_id] = temp
--         pos += 5
--     return temps
--
-- def _build_preset_temps(self, temps: dict) -> bytes:
--     """Build packed preset temperatures byte array."""
--     data = bytearray([0x05])
--     for mode_id in [PRESET_HOME, PRESET_AWAY, PRESET_SLEEP, PRESET_DAYOFF, PRESET_COMFORT]:
--         if mode_id in temps:
--             temp = temps[mode_id]
--             data.extend([mode_id, 0x00, 0x00, temp & 0xFF, (temp >> 8) & 0xFF])
--     data.extend([0x06, 0x00, 0x00, 0x00, 0x00])
--     return bytes(data)

local DEFAULT_ELECTRICAL_MEASUREMENT_DIVISOR = 10
local DEFAULT_SIMPLE_METERING_DIVISOR = 1000

local W500_PRESET_TEMP_IDS = { 1, 2, 3, 5, 6 }
local PRESET_TEMP_ORDER = W500_PRESET_TEMP_IDS
local PRESET_PREF_MAP = {
  homePresetTemp = 1,
  awayPresetTemp = 2,
  sleepPresetTemp = 3,
  dayOffPresetTemp = 5,
  comfortPresetTemp = 6
}

-- W500 preset attribute values (original preset strings in comments)
local W500_PRESET_VALUE_TO_THERMOSTAT_MODE = {
  [1] = ThermostatMode.thermostatMode.home,    -- home
  [2] = ThermostatMode.thermostatMode.away,    -- away
  [3] = ThermostatMode.thermostatMode.asleep,  -- sleep
  [5] = ThermostatMode.thermostatMode.dayoff,  -- day off
  [6] = ThermostatMode.thermostatMode.comfort, -- comfort
  [7] = ThermostatMode.thermostatMode.manual,  -- manual
}

local W500_THERMOSTAT_MODE_TO_PRESET_VALUE = {
  [ThermostatMode.thermostatMode.home.NAME] = 1,    -- home
  [ThermostatMode.thermostatMode.away.NAME] = 2,    -- away
  [ThermostatMode.thermostatMode.asleep.NAME] = 3,  -- sleep
  [ThermostatMode.thermostatMode.dayoff.NAME] = 5,  -- vacation
  [ThermostatMode.thermostatMode.comfort.NAME] = 6, -- evening
  [ThermostatMode.thermostatMode.manual.NAME] = 7   -- manual
}

local W500_SUPPORTED_MODES = {
  ThermostatMode.thermostatMode.off.NAME,
  ThermostatMode.thermostatMode.home.NAME,
  ThermostatMode.thermostatMode.away.NAME,
  ThermostatMode.thermostatMode.asleep.NAME,
  ThermostatMode.thermostatMode.comfort.NAME,
  ThermostatMode.thermostatMode.dayoff.NAME,
  ThermostatMode.thermostatMode.manual.NAME
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

local function active_power_handler(driver, device, value, zb_rx)
  local divisor = driver_utils.get_divisor(
    device,
    constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY,
    DEFAULT_ELECTRICAL_MEASUREMENT_DIVISOR
  )
  local power = value.value / divisor
  device:emit_event(PowerMeter.power({ value = power, unit = "W" }))
end

local function current_summation_delivered_handler(driver, device, value, zb_rx)
  local divisor = driver_utils.get_divisor(
    device,
    constants.SIMPLE_METERING_DIVISOR_KEY,
    DEFAULT_SIMPLE_METERING_DIVISOR
  )
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

local function info_changed(driver, device, event, args)
  local preset_temps_changed = false
  for id, value in pairs(device.preferences) do
    if args.old_st_store.preferences[id] ~= value then
      local pref_value = value
      local payload
      local attr

      if id == "sensor" then
        attr = 0x0280
        payload = data_types.Uint8(tonumber(pref_value))
      elseif id == "ntcSensorType" then
        attr = 0x0315
        payload = data_types.Uint32(tonumber(pref_value))
      elseif id == "windowDetection" then
        attr = 0x0273
        payload = data_types.Uint8(pref_value and 1 or 0)
      elseif id == "childLock" then
        attr = 0x0277
        payload = data_types.Uint8(pref_value and 1 or 0)
      elseif id == "hysteresis" then
        attr = 0x030c
        local scaled = math.floor((tonumber(pref_value) or 0) * 10 + 0.5)
        payload = data_types.Uint8(scaled)
      elseif PRESET_PREF_MAP[id] ~= nil then
        preset_temps_changed = true
      end

      if payload and attr then
        driver_utils.send_mfg_attribute(device, xiaomi_utils.OppleCluster, attr, payload, MFG_CODE)
      end
    end
  end

  if preset_temps_changed then
    local temps = {}
    for pref_name, mode_id in pairs(PRESET_PREF_MAP) do
      local pref_value = device.preferences[pref_name]
      if pref_value ~= nil then
        temps[mode_id] = scale_preset_temp(pref_value)
      end
    end
    local payload = data_types.OctetString(build_preset_temps(temps))
    driver_utils.send_mfg_attribute(device, xiaomi_utils.OppleCluster, W500_PRESET_TEMPS_ATTR, payload, MFG_CODE)
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
  else
    log.warn_with({ hub_logs = true }, string.format("Unknown preset value: 0x%02X", value.value))
  end
end

local function bytes_to_table(data)
  if type(data) == "string" then
    return { string.byte(data, 1, #data) }
  end
  return data or {}
end

local function parse_preset_temps(data)
  local bytes = bytes_to_table(data)
  local temps = {}
  if #bytes < 6 then
    return temps
  end

  local num_presets = bytes[1]
  local pos = 2
  for _ = 1, num_presets do
    if pos + 4 > #bytes then
      break
    end
    local mode_id = bytes[pos]
    local temp = bytes[pos + 3] + (bytes[pos + 4] << 8)
    if W500_PRESET_VALUE_TO_THERMOSTAT_MODE[mode_id] ~= nil then
      temps[mode_id] = temp
    end
    pos = pos + 5
  end

  return temps
end

local function scale_preset_temp(value)
  return math.floor((tonumber(value) or 0) * 100 + 0.5)
end

local function build_preset_temps(temps)
  local data = { #PRESET_TEMP_ORDER }
  for _, mode_id in ipairs(PRESET_TEMP_ORDER) do
    local temp = temps[mode_id]
    if temp ~= nil then
      table.insert(data, mode_id)
      table.insert(data, 0x00)
      table.insert(data, 0x00)
      table.insert(data, temp & 0xFF)
      table.insert(data, (temp >> 8) & 0xFF)
    end
  end
  table.insert(data, 0x06)
  table.insert(data, 0x00)
  table.insert(data, 0x00)
  table.insert(data, 0x00)
  table.insert(data, 0x00)
  return data
end

local preset_temps_handler = function(driver, device, value, zb_rx)
  local temps = parse_preset_temps(value.value)
  device:set_field("preset_temps", temps)
  log.info("Decoded preset temps", temps)
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

end

local thermostat_mode_setter = function(mode_name)
  return function(driver, device, command)
    return set_thermostat_mode(driver, device, {component = command.component, args = {mode = mode_name}})
  end
end


--TODO: Update this once we've decided how to handle setpoint commands

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
  device:send(cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, W500_PRESET_TEMPS_ATTR, MFG_CODE))
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
        [W500_PRESET_ATTR] = preset_mode_handler,
        [W500_PRESET_TEMPS_ATTR] = preset_temps_handler
      },
      [Thermostat.ID] = {
        [Thermostat.attributes.ControlSequenceOfOperation.ID] = supported_thermostat_modes_handler,
        [Thermostat.attributes.ThermostatRunningState.ID] = thermostat_operating_state_handler,
        [Thermostat.attributes.ThermostatRunningMode.ID] = thermostat_mode_handler,
        [Thermostat.attributes.SystemMode.ID] = thermostat_mode_handler,
        [Thermostat.attributes.MinHeatSetpointLimit.ID] = driver_utils.setpoint_limit_handler_factory(capabilities, 'min', 'heat'),
        [Thermostat.attributes.MaxHeatSetpointLimit.ID] = driver_utils.setpoint_limit_handler_factory(capabilities, 'max', 'heat'),
        [Thermostat.attributes.MinCoolSetpointLimit.ID] = driver_utils.setpoint_limit_handler_factory(capabilities, 'min', 'cool'),
        [Thermostat.attributes.MaxCoolSetpointLimit.ID] = driver_utils.setpoint_limit_handler_factory(capabilities, 'max', 'cool'),
      },
      [ElectricalMeasurement.ID] = {
        [ElectricalMeasurement.attributes.ActivePower.ID] = active_power_handler
      },
      [SimpleMetering.ID] = {
        [SimpleMetering.attributes.CurrentSummationDelivered.ID] = current_summation_delivered_handler
      },
      [TemperatureMeasurement.ID] = {
        [TemperatureMeasurement.attributes.MinMeasuredValue.ID] = driver_utils.temperature_measurement_min_max_attr_handler(
          capabilities,
          temperature_measurement_defaults,
          temperature_measurement_defaults.MIN_TEMP
        ),
        [TemperatureMeasurement.attributes.MaxMeasuredValue.ID] = driver_utils.temperature_measurement_min_max_attr_handler(
          capabilities,
          temperature_measurement_defaults,
          temperature_measurement_defaults.MAX_TEMP
        ),
      },
      [RelativeHumidityCluster.ID] = {
        [RelativeHumidityCluster.attributes.MeasuredValue.ID] = RelativeHumidityClusterHandler
      }
    }
  },
  capability_handlers = {
    [ThermostatMode.ID] = {
      [ThermostatMode.commands.setThermostatMode.NAME] = set_thermostat_mode,
      [ThermostatMode.commands.off.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.off.NAME),
      [ThermostatMode.commands.heat.NAME] = thermostat_mode_setter(ThermostatMode.thermostatMode.heat.NAME),
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
    [capabilities.thermostatCoolingSetpoint.ID] = {
      [capabilities.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME] = driver_utils.set_setpoint_factory(
        utils,
        clusters.Thermostat.attributes.OccupiedCoolingSetpoint
      )
    },
    [capabilities.thermostatHeatingSetpoint.ID] = {
      [capabilities.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = driver_utils.set_setpoint_factory(
        utils,
        clusters.Thermostat.attributes.OccupiedHeatingSetpoint
      )
    }
  },
  lifecycle_handlers = {
    doConfigure = do_configure,
    added = device_added,
    infoChanged = info_changed
  },
  
  health_check = false,
}

defaults.register_for_default_handlers(zigbee_thermostat_driver, zigbee_thermostat_driver.supported_capabilities)
local thermostat = ZigbeeDriver("zigbee-thermostat", zigbee_thermostat_driver)
thermostat:run()