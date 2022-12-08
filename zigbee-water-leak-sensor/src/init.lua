local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local log = require "log"
local xiaomi_utils = require "xiaomi_utils"
local zigbee_utils = require "zigbee_utils"
local PowerConfiguration = zcl_clusters.PowerConfiguration
local cluster_base = require "st.zigbee.cluster_base"


local function do_refresh(self, device)
  zigbee_utils.print_clusters(device)

  local Groups = zcl_clusters.Groups
  device:send(Groups.server.commands.GetGroupMembership(device, {}))  
  device:send( zigbee_utils.build_read_binding_table(device) )
end

--- Smoke Detector

--- ZbSend {"Device":"<device>","Manuf":"0x115F","Write":{"0500/FFF1%23":"0x04020000"}} where the value is one of the following: 'low': 0x04010000, 'medium': 0x04020000, 'high': 0x04030000
--- To run a self-test use:
--- 
--- ZbSend {"Device":"<device>","Manuf":"0x115F","Write":{"0500/FFF1%23":"0x03010000"}}

xiaomi_utils.events[0x96] = nil -- otherwise replaces voltage measurement with 0


local function battery_voltage_attr_handler(_, device, value)
  xiaomi_utils.emit_voltage_event(device, value)
end

local xiaomi_water_driver_template = {
  supported_capabilities = {
    capabilities.temperatureAlarm,
    capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.refresh,

    capabilities.waterSensor,
    capabilities.smokeDetector
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.basic_id] = xiaomi_utils.basic_id,
      [xiaomi_utils.OppleCluster] = xiaomi_utils.opple_id,

      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryVoltage.ID] = battery_voltage_attr_handler,
      }
    },
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  sub_drivers = { require('leak'), require('smoke') },
}

defaults.register_for_default_handlers(xiaomi_water_driver_template, xiaomi_water_driver_template.supported_capabilities)
local xiaomi_water_driver = ZigbeeDriver("xiaomi-water", xiaomi_water_driver_template)
xiaomi_water_driver:run()
