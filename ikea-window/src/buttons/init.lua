local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local json = require "dkjson"
local log = require "log"
local zcl_clusters = require "st.zigbee.zcl.clusters"

local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"

local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"
local zdo_messages = require "st.zigbee.zdo"

local WindowCovering = zcl_clusters.WindowCovering
local PowerConfiguration = zcl_clusters.PowerConfiguration


function supports_client_cluster(device, cluster_id)
  for ep_id, ep in pairs(device.zigbee_endpoints) do
    for _, cluster in ipairs(ep.client_clusters) do
      if cluster == cluster_id then
        return true
      end
    end
  end
  return false
end

local can_handle = function(opts, driver, device)
  return supports_client_cluster(device, WindowCovering.ID)
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

local handler = {
  NAME = "Button",
  supported_capabilities = {
    capabilities.button,
    capabilities.battery,
  },
  lifecycle_handlers = {
    added = device_added,
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
