local capabilities = require "st.capabilities"
local defaults = require "st.zigbee.defaults"
local cluster_base = require "st.zigbee.cluster_base"
local json = require "dkjson"
local xiaomi_utils = require "xiaomi_utils"
local data_types = require "st.zigbee.data_types"
local OPPLE_CLUSTER = xiaomi_utils.OppleCluster
local zcl_clusters = require "st.zigbee.zcl.clusters"
local log = require "log"
local zigbee_utils = require "zigbee_utils"

local zb_const = require "st.zigbee.constants"
local zcl_messages = require "st.zigbee.zcl"
local Status = require "st.zigbee.generated.types.ZclStatus"
local generic_body = require "st.zigbee.generic_body"
local messages = require "st.zigbee.messages"


local config_rep = require "st.zigbee.zcl.global_commands.configure_reporting"



local function info(device, id, data)
    log.info("info: ", id, " data:", data)

    if id == "heartbeatIndicator" then
        device:send(cluster_base.write_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x013c, 0x115F, data_types.Uint8, data) )
    elseif id == "linkageAlarm" then
        device:send(cluster_base.write_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x014b, 0x115F, data_types.Uint8, data) )
    elseif id == "sensivity" then
        device:send(cluster_base.write_manufacturer_specific_attribute(device, zcl_clusters.IASZone.ID, 0xFFF1, 0x115F, data_types.Uint32, data) )

    elseif id == "buzzerManualAlarm" then
        if data == 0 then
            device:send(cluster_base.write_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x0126, 0x115F, data_types.Uint8, 0) )
        else
            device:send(cluster_base.write_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x013d, 0x115F, data_types.Uint8, 1) )
        end
    end
end

local function info_changed(driver, device, event, args)
    log.info(tostring(event))
    
    for id, value in pairs(device.preferences) do
      if args.old_st_store.preferences[id] ~= value then
        local data = tonumber(device.preferences[id])
        info(device, id, data)
      end
    end 
end


local function reporting (device, attr)
    local data_type = data_types.Uint8

    local min = data_types.validate_or_build_type(30, data_types.Uint16, "minimum_reporting_interval")
    local max = data_types.validate_or_build_type(21600, data_types.Uint16, "maximum_reporting_interval")
    local rep_change = data_types.validate_or_build_type(1, data_type, "reportable_change")
    
    local msg = cluster_base.configure_reporting(device, 
          data_types.ClusterId(xiaomi_utils.OppleCluster), 
          data_types.AttributeId(attr), 
          data_types.ZigbeeDataType(data_type.ID), 
          min, max, rep_change)

    device:send(msg)
end

local function do_refresh(self, device)
    zigbee_utils.print_clusters(device)
  
    local Groups = zcl_clusters.Groups
    device:send(Groups.server.commands.GetGroupMembership(device, {}))  
    device:send( zigbee_utils.build_read_binding_table(device) )
  
    device:send( cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x013a, 0x115F) )
    device:send( cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x013b, 0x115F) )
    device:send( cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x013c, 0x115F) )
    device:send( cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x013d, 0x115F) )
  
    device:send( cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x0126, 0x115F) )
    device:send( cluster_base.read_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x0146, 0x115F) )
  
  
    ---
    reporting(device, 0x013a)
    reporting(device, 0x013b)
    reporting(device, 0x013c)
    reporting(device, 0x013d)
    reporting(device, 0x0126)
    reporting(device, 0x0146)

    ---
  end
  
  

local function selftest_handler(_, device, command)
    log.info("selftest_handler")
    
    do_refresh(_, device)

    if device:get_model() == "lumi.sensor_smoke" then
        device:send(cluster_base.write_manufacturer_specific_attribute(device, zcl_clusters.IASZone.ID, 0xFFF1, 0x115F, data_types.Uint32, 0x03010000) )
    else
        device:send(cluster_base.write_manufacturer_specific_attribute(device, xiaomi_utils.OppleCluster, 0x0127, 0x115F, data_types.Boolean, True) )
    end
end

local smoke_handler = {
    NAME = "Smoke",
    supported_capabilities = {
        capabilities.smokeDetector,
        capabilities.battery,
        capabilities.refresh,
    },
    lifecycle_handlers = {
        infoChanged = info_changed,
    },
    capability_handlers = {
        [capabilities.momentary.ID] = {
          [capabilities.momentary.commands.push.NAME] = selftest_handler,
        }
    },
    can_handle = function(opts, driver, device)
        return device:get_model() == "lumi.sensor_smoke" or device:get_model() == "lumi.sensor_smoke.acn03"
    end
}

defaults.register_for_default_handlers(smoke_handler, smoke_handler.supported_capabilities)
return smoke_handler
