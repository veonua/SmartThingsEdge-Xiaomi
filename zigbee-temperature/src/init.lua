local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local log = require "log"
local xiaomi_utils = require "xiaomi_utils"
local zcl_clusters = require "st.zigbee.zcl.clusters"

local tempearture_value_attr_handler = function(driver, device, value, zb_rx)
  local temperature = value.value / 100
  device:emit_event(capabilities.temperatureMeasurement.temperature({ value = temperature, unit = "C" }))
  
  local alarm = "cleared"
  if temperature > 60 then
    alarm = "heat"
  elseif temperature < -20 then
    alarm = "freeze"
  end
  
  device:emit_event(capabilities.temperatureAlarm.temperatureAlarm(alarm))
end

local humidity_value_attr_handler = function(driver, device, value, zb_rx)
  local percent = utils.clamp_value(value.value / 100, 0.0, 100.0)
  device:emit_event(capabilities.relativeHumidityMeasurement.humidity(percent))
end

local pressure_value_attr_handler = function(driver, device, value, zb_rx)
  local kPa = math.floor(value.value/10)
  device:emit_event(capabilities.atmosphericPressureMeasurement.atmosphericPressure({value = kPa, unit = "kPa"}))
end

local function refresh_handler(driver, device, command)
  device:send(zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue:read(device))
  device:send(zcl_clusters.RelativeHumidityMeasurement.attributes.MeasuredValue:read(device))
  device:send(zcl_clusters.PressureMeasurement.attributes.MeasuredValue:read(device))
end

local zigbee_temp_driver_template = {
  supported_capabilities = {
    capabilities.relativeHumidityMeasurement,
    capabilities.atmosphericPressureMeasurement,
    capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.temperatureAlarm,
  },
  use_defaults = true,
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler
    }
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.basic_id] = {
        [0xFF01] = xiaomi_utils.handler
      },
      [zcl_clusters.TemperatureMeasurement.ID] = {
        [zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.ID] = tempearture_value_attr_handler
      },
      [zcl_clusters.RelativeHumidity.ID] = {
        [zcl_clusters.RelativeHumidity.attributes.MeasuredValue.ID] = humidity_value_attr_handler
      },
      [zcl_clusters.PressureMeasurement.ID] = {
        [zcl_clusters.PressureMeasurement.attributes.MeasuredValue.ID] = pressure_value_attr_handler
      }
    }
  },
}

defaults.register_for_default_handlers(zigbee_temp_driver_template, zigbee_temp_driver_template.supported_capabilities)
local driver = ZigbeeDriver("xiaomi_temp", zigbee_temp_driver_template)
driver:run()