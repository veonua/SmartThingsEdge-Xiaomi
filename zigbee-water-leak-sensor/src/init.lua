local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local log = require "log"
local xiaomi_utils = require "xiaomi_utils"
local zigbee_utils = require "zigbee_utils"

local do_refresh = function(self, device)
  zigbee_utils.print_clusters(device)

  local Groups = zcl_clusters.Groups
  device:send(Groups.server.commands.GetGroupMembership(device, {}))  
end

local xiaomi_water_driver_template = {
  supported_capabilities = {
    capabilities.waterSensor,
    capabilities.temperatureAlarm,
    capabilities.temperatureMeasurement,
    capabilities.battery,
  },
  use_defaults = false,
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  zigbee_handlers = {
    global = {},
    cluster = {},
    attr = {
      [zcl_clusters.basic_id] = {
        [xiaomi_utils.attr_id] = xiaomi_utils.handler
      },
    },
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  sub_drivers = {  },
}

defaults.register_for_default_handlers(xiaomi_water_driver_template, xiaomi_water_driver_template.supported_capabilities)
local xiaomi_water_driver = ZigbeeDriver("xiaomi-water", xiaomi_water_driver_template)
xiaomi_water_driver:run()
