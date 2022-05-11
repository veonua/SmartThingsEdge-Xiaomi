local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local device_management = require "st.zigbee.device_management"
local zigbee_utils = require "zigbee_utils"

local WindowCovering = zcl_clusters.WindowCovering
local Groups = zcl_clusters.Groups
local windowShade_defaults = require "st.zigbee.defaults.windowShade_defaults"

local json = require "dkjson"
local log  = require "log"


---
local SHADE_SET_STATUS = "shade_set_status"

local function current_position_attr_handler(driver, device, value, zb_rx)
  log.info("current_position_attr_handler", value.value)

  local level = 100 - value.value
  local current_level = device:get_latest_state("main", capabilities.windowShadeLevel.ID, capabilities.windowShadeLevel.shadeLevel.NAME)  
  local windowShade = capabilities.windowShade.windowShade
  if level <= 1 then
    device:emit_event(windowShade.closed())
    device:emit_event(capabilities.windowShadeLevel.shadeLevel(0))
  elseif level >= 99 then
    device:emit_event(windowShade.open())
    device:emit_event(capabilities.windowShadeLevel.shadeLevel(100))
  else
    if current_level ~= level or current_level == nil then
      current_level = current_level or 0
      device:emit_event(capabilities.windowShadeLevel.shadeLevel(level))
      local event = nil
      if current_level ~= level then
        event = current_level < level and windowShade.opening() or windowShade.closing()
      end
      if event ~= nil then
        device:emit_event(event)
      end
    end
    local set_status_timer = device:get_field(SHADE_SET_STATUS)
    if set_status_timer then
      device.thread:cancel_timer(set_status_timer)
      device:set_field(SHADE_SET_STATUS, nil)
    end
    local set_window_shade_status = function()
      local current_level = device:get_latest_state("main", capabilities.windowShadeLevel.ID, capabilities.windowShadeLevel.shadeLevel.NAME)
      log.info("set_window_shade_status", current_level)
      
      if current_level <= 1 then
        device:emit_event(windowShade.closed())
      elseif current_level >= 99 then
        device:emit_event(windowShade.open())
      else
        device:emit_event(windowShade.partially_open())
      end
    end
    set_status_timer = device.thread:call_with_delay(1, set_window_shade_status)
    device:set_field(SHADE_SET_STATUS, set_status_timer)
  end
end
---

local function device_added(self, device)
    device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({ value = { "open", "close", "pause"} }))
    device:refresh()
end

function current_lift_percentage_handler(driver, device, value, zb_rx)
    value.value = 100 - value.value
    windowShade_defaults.default_current_lift_percentage_handler(driver, device, value, zb_rx)
end

function window_shade_level_cmd(driver, device, command)
    local level = 100 - command.args.shadeLevel
    device:send_to_component(command.component, WindowCovering.server.commands.GoToLiftPercentage(device, level))

    log.info(">> window_shade_level_cmd: " .. level .. " component: " .. command.component)
end


local function info_changed(driver, device, event, args)
    log.info(tostring(event))
    
    for id, value in pairs(device.preferences) do
      if args.old_st_store.preferences[id] ~= value then
        local data = device.preferences[id]
        
        if id == "group" then
            device:send(Groups.server.commands.AddGroup(device, data, "Group"..tostring(data)))
        end
      end
    end
end
  
local function do_configure(self, device)
   device:send(device_management.build_bind_request(device, WindowCovering.ID, self.environment_info.hub_zigbee_eui))
   device:send(WindowCovering.attributes.CurrentPositionLiftPercentage:configure_reporting(device, 5, 21600, 1))
--     super:do_configure
   zigbee_utils.send_read_binding_table(device)
end


local blinds_handler = {
    NAME = "Blinds",
    supported_capabilities = {
        capabilities.windowShade,
        capabilities.windowShadeLevel,
        capabilities.windowShadePreset,
        capabilities.battery,
        capabilities.refresh,
    },
    lifecycle_handlers = {
        added = device_added,
        infoChanged = info_changed,
        doConfigure = do_configure,
    },
    capability_handlers = {
        [capabilities.windowShadeLevel.ID] = {
            [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = window_shade_level_cmd
        }
    },
    zigbee_handlers = {
        attr = {
            [WindowCovering.ID] = {
                [WindowCovering.attributes.CurrentPositionLiftPercentage.ID] = current_position_attr_handler
                --current_lift_percentage_handler
            }
        }
    },
    can_handle = function(opts, driver, device)
        return device:supports_server_cluster(WindowCovering.ID)
    end
}

return blinds_handler
