local capabilities = require "st.capabilities"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local json = require "dkjson"
local log = require "log"
local zcl_clusters = require "st.zigbee.zcl.clusters"

local WindowCovering = zcl_clusters.WindowCovering
local PowerConfiguration = zcl_clusters.PowerConfiguration
local Groups = zcl_clusters.Groups

local zigbee_utils = require "zigbee_utils"

local can_handle = function(opts, driver, device)
  return zigbee_utils.supports_client_cluster(device, WindowCovering.ID)
end

local device_added = function(self, device)
  device:emit_event(capabilities.button.numberOfButtons({value = 1}))
  device:emit_event(capabilities.button.supportedButtonValues({"up", "down", "held"}))
  device:emit_event(capabilities.button.button.held({state_change = true}))
end

function open_command_handler(driver, device, zb_rx)
  device:emit_event(capabilities.button.button.up({state_change = true}))
end

function close_command_handler(driver, device, zb_rx)
  device:emit_event(capabilities.button.button.down({state_change = true}))
end

function stop_command_handler(driver, device, zb_rx)
  device:emit_event(capabilities.button.button.held({state_change = true}))
end

local function do_configure(self, device)
  log.warn("do_configure")
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1))
end


local function info_changed(driver, device, event, args)
  log.info(tostring(event))
  
  for id, value in pairs(device.preferences) do
    if args.old_st_store.preferences[id] ~= value then
      local data = device.preferences[id]
      
      if id == "group" then
        device:send(zigbee_utils.build_bind_request(device, WindowCovering.ID, data))
      end
    end
  end
end

local handler = {
  NAME = "Button",
  supported_capabilities = {
    capabilities.button,
    capabilities.battery,
  },
  lifecycle_handlers = {
    added = device_added,
    doConfigure = do_configure,
    infoChanged = info_changed,
  },
  zigbee_handlers = {
    cluster = {
      [WindowCovering.ID] = { 
          [WindowCovering.server.commands.UpOrOpen.ID] = open_command_handler,
          [WindowCovering.server.commands.DownOrClose.ID] = close_command_handler,
          [WindowCovering.server.commands.Stop.ID] = stop_command_handler,
      }
    },  
  },
  can_handle = can_handle
}

return handler
