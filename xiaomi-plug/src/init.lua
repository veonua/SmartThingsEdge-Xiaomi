local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local log = require "log"
local xiaomi_utils = require "xiaomi_utils"

local function temp_attr_handler(driver, device, value, zb_rx)
end

local function attr_handler0C(driver, device, value, zb_rx)
  local endpoint = zb_rx.address_header.src_endpoint.value
  
  if endpoint == 2 then
    device:emit_event( capabilities.powerMeter.power({value=value.value, unit="W"}) )
  elseif endpoint == 3 then
    device:emit_event( capabilities.energyMeter.energy({value=value.value, unit="Wh"}) )
  end
end

local function consumption_handler(device, value)
  device:emit_event( capabilities.energyMeter.energy({value=value.value, unit="Wh"}) )
end

local function voltage_handler(device, value)
  device:emit_event( capabilities.voltageMeasurement.voltage({value=value.value//10, unit="V"}) )
end

local function resetEnergyMeter(device)
end

local function saveStatus(device, value)
  --device:
  -- zigbee.writeAttribute(0xFCC0, 0x0201, 0x10, 1)
end

xiaomi_utils.xiami_events[0x95] = consumption_handler
xiaomi_utils.xiami_events[0x96] = voltage_handler

local plug_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.powerMeter,
    capabilities.energyMeter,    
    capabilities.temperatureAlarm,
    capabilities.voltageMeasurement,
    capabilities.refresh,
  },
  use_defaults = false,
  zigbee_handlers = {
    global = {},
    cluster = {},
    attr = {
      [zcl_clusters.basic_id] = {
        [xiaomi_utils.attr_id] = xiaomi_utils.handler
      },
      [0002] = {
        [0x00] = temp_attr_handler,
      },
      [0x0C] = {
        [0x0055] = attr_handler0C
      }
    }
  },
  
}

defaults.register_for_default_handlers(plug_driver_template, plug_driver_template.supported_capabilities)
local plug = ZigbeeDriver("plug", plug_driver_template)
plug:run()

-- TODO: add zigbee binding for plug