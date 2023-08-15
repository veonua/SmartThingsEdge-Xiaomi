local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local utils = require "st.utils"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local log = require "log"
local xiaomi_utils = require "xiaomi_utils"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"
local json = require "dkjson"
local zigbee_utils = require "zigbee_utils"

local function added_handler(self, device)
  -- https://github.com/veonua/SmartThingsEdge-Xiaomi/issues/6
  device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, 10, {persists= true})        -- Current Summation Delivered
  device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, 10, {persists= true}) -- Active Power
end

local function temp_attr_handler(driver, device, value, zb_rx)
  device:emit_event(capabilities.temperatureMeasurement.temperature({ value = value.value, unit = "C"}) )
end

local function analog_input_handler(driver, device, e_value, zb_rx)
  local endpoint = zb_rx.address_header.src_endpoint.value
  local value = utils.round(e_value.value * 100)/100.0
  
  if endpoint == 2 or endpoint == 21 then
    device:emit_event( capabilities.powerMeter.power({value=value, unit="W"}) )
  elseif endpoint == 3 then
    device:emit_event( capabilities.energyMeter.energy({value=value, unit="Wh"}) )
  else
    log.warn("unknown AnalogInput ep:" .. tostring(endpoint) .. " value:" .. tostring(value) )
  end
end

function bool_to_number(value)
  return value and 0x01 or 0x00
end

function octetstring_from(t)
  local bytearr = {}
  for _, v in ipairs(t) do
    local utf8byte = v < 0 and (0xff + v + 1) or v
    table.insert(bytearr, string.char(utf8byte))
  end
  return data_types.OctetString(table.concat(bytearr))
end

local function info_changed(driver, device, event, args)
  zigbee_utils.print_clusters(device)

  for id, value in pairs(device.preferences) do
    if args.old_st_store.preferences[id] ~= value then
      local value = device.preferences[id]
      local cluster_id = xiaomi_utils.OppleCluster
      
      log.info("preferences changed: " .. id .. " " .. tostring(value))

      local model = device:get_model()
      local data_type
      local payload
      local attr
      
      if id == "stse.restorePowerState" then
        if model == "lumi.plug" then
          payload = octetstring_from({ 0xaa, 0x80, 0x05, 0xd1, 0x47, value and 0x09 or 0x07, 0x01, 0x10, bool_to_number(not value)})
          cluster_id = zcl_clusters.basic_id
          attr = 0xFFF0
        else
          payload = data_types.Boolean(value)
          attr = 0x0201
        end
      elseif id == "autoOff" then
        if model == "lumi.plug" then
          payload = octetstring_from({ 0xaa, 0x80, 0x05, 0xd1, 0x47, bool_to_number(not value), 0x02, 0x10, bool_to_number(value)})
          cluster_id = zcl_clusters.basic_id
          attr = 0xFFF0
        else
          payload = data_types.Boolean(value)
          attr = 0x0202
        end
      elseif id == "stse.turnOffIndicatorLight" then
        if model == "lumi.plug.aq1" or model == "lumi.plug" then
          local pl = bool_to_number(not value)
          payload = octetstring_from({ 0xaa, 0x80, 0x05, 0xd1, 0x47, pl, 0x03, 0x10, pl})
          attr = 0xFFF0
          cluster_id = zcl_clusters.basic_id
        else
          payload = data_types.Boolean(value)
          attr = 0x0203
        end
      elseif id == "overloadProtection" then
        local sign = 0
        local mantissa, exponent = math.frexp(value)
        mantissa = mantissa * 2 - 1
        exponent = exponent - 1
        
        payload = data_types.SinglePrecisionFloat(sign, exponent, mantissa)
        data_type = data_types.SinglePrecisionFloat
        attr = 0x020b
      end

      if payload then
        local message = cluster_base.write_attribute(device, data_types.ClusterId(cluster_id), data_types.AttributeId(attr), payload)
        message.body.zcl_header.frame_ctrl:set_mfg_specific()
        message.body.zcl_header.mfg_code = data_types.validate_or_build_type(0x115F, data_types.Uint16, "mfg_code")
        log.info("writing attribute: " .. tostring(message) )
        device:send(message)
      end
    end
  end
end

local plug_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.powerMeter,
    capabilities.energyMeter,    
    capabilities.temperatureAlarm,
    capabilities.voltageMeasurement,
    capabilities.refresh,
  },
  lifecycle_handlers = {
    added = added_handler,
    infoChanged = info_changed,
  },
  zigbee_handlers = {
    global = {},
    cluster = {},
    attr = {
      [zcl_clusters.basic_id] = xiaomi_utils.basic_id,
      [xiaomi_utils.OppleCluster] = xiaomi_utils.opple_id,
      [zcl_clusters.DeviceTemperatureConfiguration.ID] = {
        [zcl_clusters.DeviceTemperatureConfiguration.attributes.CurrentTemperature.ID] = temp_attr_handler,
      },
      [zcl_clusters.analog_input_id] = {
        [zcl_clusters.AnalogInput.attributes.PresentValue.ID] = analog_input_handler
      }
    }
  },
  
}

defaults.register_for_default_handlers(plug_driver_template, plug_driver_template.supported_capabilities)
local plug = ZigbeeDriver("plug", plug_driver_template)
plug:run()

-- TODO: add zigbee binding for plug