local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"
local xiaomi_utils = require "xiaomi_utils"
local zigbee_utils = require "zigbee_utils"

local log = require "log"
local utils = require "utils"

local function analog_input_handler(_driver, device, e_value, zb_rx)
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

local function bool_to_number(value)
    return value and 0x01 or 0x00
end

local function octetstring_from(t)
    local bytearr = {}
    for _, v in ipairs(t) do
      local utf8byte = v < 0 and (0xff + v + 1) or v
      table.insert(bytearr, string.char(utf8byte))
    end
    return data_types.OctetString(table.concat(bytearr))
end

local function temp_attr_handler(_driver, device, value, _zb_rx)
    device:emit_event(capabilities.temperatureMeasurement.temperature({ value = value.value, unit = "C"}) )
end

local function info_changed(_driver, device, _event, args)
    zigbee_utils.print_clusters(device)

    for id, value in pairs(device.preferences) do
      if args.old_st_store.preferences[id] ~= value then
        local pref_value = device.preferences[id]
        local cluster_id = xiaomi_utils.OppleCluster

        log.info("preferences changed: " .. id .. " " .. tostring(pref_value))

        local model = device:get_model()
        local payload
        local attr

        if id == "stse.restorePowerState" then
          if model == "lumi.plug" then
            payload = octetstring_from({ 0xaa, 0x80, 0x05, 0xd1, 0x47, pref_value and 0x09 or 0x07, 0x01, 0x10, bool_to_number(not pref_value)})
            cluster_id = zcl_clusters.basic_id
            attr = 0xFFF0
          else
            payload = data_types.Boolean(pref_value)
            attr = 0x0201
          end
        elseif id == "autoOff" then
          if model == "lumi.plug" then
            payload = octetstring_from({ 0xaa, 0x80, 0x05, 0xd1, 0x47, bool_to_number(not pref_value), 0x02, 0x10, bool_to_number(pref_value)})
            cluster_id = zcl_clusters.basic_id
            attr = 0xFFF0
          else
            payload = data_types.Boolean(pref_value)
            attr = 0x0202
          end
        elseif id == "stse.turnOffIndicatorLight" then
          if model == "lumi.plug.aq1" or model == "lumi.plug" then
            local pl = bool_to_number(not pref_value)
            payload = octetstring_from({ 0xaa, 0x80, 0x05, 0xd1, 0x47, pl, 0x03, 0x10, pl})
            attr = 0xFFF0
            cluster_id = zcl_clusters.basic_id
          else
            payload = data_types.Boolean(pref_value)
            attr = 0x0203
          end
        elseif id == "stse.maxPowerCN" then
          local sign = 0
          local mantissa, exponent = math.frexp(pref_value)
          mantissa = mantissa * 2 - 1
          exponent = exponent - 1

          payload = data_types.SinglePrecisionFloat(sign, exponent, mantissa)
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

local plug_handler = {
    NAME = "Plug Handler",
    lifecycle_handlers = {
      infoChanged = info_changed,
    },
    zigbee_handlers = {
        attr = {
            --[zcl_clusters.basic_id] = xiaomi_utils.basic_id,
            [xiaomi_utils.OppleCluster] = xiaomi_utils.opple_id,
            [zcl_clusters.DeviceTemperatureConfiguration.ID] = {
              [zcl_clusters.DeviceTemperatureConfiguration.attributes.CurrentTemperature.ID] = temp_attr_handler,
            },
            [zcl_clusters.analog_input_id] = {
              [zcl_clusters.AnalogInput.attributes.PresentValue.ID] = analog_input_handler
            }
          }
    },
  can_handle = function(_opts, _driver, device)
        return device:get_model():find("^lumi%.plug") ~= nil
    end
}

return plug_handler
