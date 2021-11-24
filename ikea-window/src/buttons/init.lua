local capabilities = require "st.capabilities"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local json = require "dkjson"
local log = require "log"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local device_management = require "st.zigbee.device_management"

local WindowCovering = zcl_clusters.WindowCovering
local OnOff = zcl_clusters.OnOff
local Level = zcl_clusters.Level


local PowerConfiguration = zcl_clusters.PowerConfiguration
local Groups = zcl_clusters.Groups
local Scenes = zcl_clusters.Scenes

local btn_cap = capabilities.button
local button  = capabilities.button.button

local zigbee_utils = require "zigbee_utils"

local can_handle = function(opts, driver, device)
  return zigbee_utils.supports_client_cluster(device, WindowCovering.ID) or zigbee_utils.supports_client_cluster(device, OnOff.ID)
end

local device_added = function(self, device)
  device:emit_event(btn_cap.numberOfButtons({value = 1}))
  device:emit_event(btn_cap.supportedButtonValues({"held", "up", "down"}))
  device:emit_event(button.held())
end

function open_command_handler(driver, device, zb_rx)
  device:emit_event(button.up({state_change = true}))
end

function close_command_handler(driver, device, zb_rx)
  device:emit_event(button.down({state_change = true}))
end

function stop_command_handler(driver, device, zb_rx)
  device:emit_event(button.held({state_change = true}))
end

function press_handler(driver, device, zb_rx)
  local btn = zb_rx.body.zcl_body.body_bytes:byte(1)
  local btn_map = {button.down, button.up}
  local event = btn_map[btn+1]
  if event then
    device:emit_event(event({state_change = true}))
  end
  
  -- 00 01 0D 00
  -- 01 01 0D 00
  -- 02 01 00 00 -- release
end

function hold_handler(driver, device, zb_rx)
  device:emit_event(button.held({state_change = true}))
end


local function do_configure(self, device)
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1))
  zigbee_utils.send_read_binding_table(device)
end


local function info_changed(driver, device, event, args)
  log.info(tostring(event))
  
  for id, value in pairs(device.preferences) do
    local old_value = args.old_st_store.preferences[id] 
    if old_value ~= value then
      
      if id == "group" then
        if old_value > 0 then
          zigbee_utils.send_unbind_request(device, WindowCovering.ID, value)
          -- 
          zigbee_utils.send_unbind_request(device, OnOff.ID, value)
          zigbee_utils.send_unbind_request(device, Level.ID, value)
        end
        if value > 0 then
          zigbee_utils.send_bind_request(device, WindowCovering.ID, value)
          -- 
          zigbee_utils.send_bind_request(device, OnOff.ID, value)
          zigbee_utils.send_bind_request(device, Level.ID, value)
        end
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
      },
      [Scenes.ID] = {
        [Scenes.server.commands.StoreScene.ID] = scenes_handler,
        [Scenes.server.commands.RecallScene.ID] = scenes_handler,
        [0x07] = press_handler,
        [0x09] = hold_handler
      }
    },
  },
  can_handle = can_handle
}

return handler
