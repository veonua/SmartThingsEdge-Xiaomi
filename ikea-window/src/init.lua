local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local log = require "log"
local zcl_clusters = require "st.zigbee.zcl.clusters"

local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"
local zdo_messages = require "st.zigbee.zdo"
local windowShade_defaults = require "st.zigbee.defaults.windowShade_defaults"

local WindowCovering = zcl_clusters.WindowCovering
local PowerConfiguration = zcl_clusters.PowerConfiguration

local device_added = function(self, device)
  log.info("device_added: " .. tostring(device))
  device:emit_event(capabilities.button.numberOfButtons({value = 1}))
  device:emit_event(capabilities.button.supportedButtonValues({"up", "down", "held"}))
  device:emit_event(capabilities.button.button.held({state_change = true}))
end

function open_command_handler(driver, device, zb_rx)
  log.info("open_command_handler")
  -- zb_rx.body.zcl_body
  device:emit_event(capabilities.button.button.up({state_change = true}))
end

function close_command_handler(driver, device, zb_rx)
  device:emit_event(capabilities.button.button.down({state_change = true}))
end

function stop_command_handler(driver, device, zb_rx)
  device:emit_event(capabilities.button.button.held({state_change = true}))
end

local function zdo_binding_table_handler(driver, device, zb_rx)
  for _, binding_table in pairs(zb_rx.body.zdo_body.binding_table_entries) do
    if binding_table.dest_addr_mode.value == binding_table.DEST_ADDR_MODE_SHORT then
      -- send add hub to zigbee group command
      driver:add_hub_to_zigbee_group(binding_table.dest_addr.value)
      log.info("add hub to zigbee group: " .. tostring( binding_table.dest_addr.value) )
    end
  end
end

local function device_added(self, device)
  device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({ value = { "open", "close", "pause"} }))
  device:refresh()
end

local do_configure = function(self, device)
  log.info("do_configure")
  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(device_management.build_bind_request(device, WindowCovering.ID, self.environment_info.hub_zigbee_eui))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1))
  device:send(WindowCovering.attributes.CurrentPositionLiftPercentage:configure_reporting(device, 0, 600, 1))
  
  -- Read binding table
  local addr_header = messages.AddressHeader(
    constants.HUB.ADDR,
    constants.HUB.ENDPOINT,
    device:get_short_address(),
    device.fingerprinted_endpoint_id,
    constants.ZDO_PROFILE_ID,
    mgmt_bind_req.BINDING_TABLE_REQUEST_CLUSTER_ID
  )
  local binding_table_req = mgmt_bind_req.MgmtBindRequest(0) -- Single argument of the start index to query the table
  local message_body = zdo_messages.ZdoMessageBody({
                                                   zdo_body = binding_table_req
                                                 })
  local binding_table_cmd = messages.ZigbeeMessageTx({
                                                     address_header = addr_header,
                                                     body = message_body
                                                   })
  device:send(binding_table_cmd)
end

function current_lift_percentage_handler(ZigbeeDriver, ZigbeeDevice, value, zb_rx)
  value.value = 100 - value.value
  windowShade_defaults.default_current_lift_percentage_handler(ZigbeeDriver, ZigbeeDevice, value, zb_rx)
end

function window_shade_level_cmd(ZigbeeDriver, ZigbeeDevice, command)
  local level = 100 - command.args.shadeLevel
  ZigbeeDevice:send_to_component(command.component, WindowCovering.server.commands.GoToLiftPercentage(ZigbeeDevice, level))
end

local ikea_window_driver_template = {
  supported_capabilities = {
    capabilities.button,
    capabilities.windowShade,
    capabilities.windowShadeLevel,
    capabilities.windowShadePreset,
    capabilities.battery,
    capabilities.refresh,
  },
  capability_handlers = {
    [capabilities.windowShadeLevel.ID] = {
      [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = window_shade_level_cmd
    }
  },
  zigbee_handlers = {
    cluster = {
      [WindowCovering.ID] = {
          [WindowCovering.server.commands.UpOrOpen.ID] = open_command_handler,
          [WindowCovering.server.commands.DownOrClose.ID] = close_command_handler,
          [WindowCovering.server.commands.Stop.ID] = stop_command_handler,
      }
    },
    attr = {
      [WindowCovering.ID] = {
        [WindowCovering.attributes.CurrentPositionLiftPercentage.ID] = current_lift_percentage_handler
      }
    },
    zdo = {
      [mgmt_bind_resp.MGMT_BIND_RESPONSE] = zdo_binding_table_handler
    }
  },
  lifecycle_handlers = {
    added = device_added,
    doConfigure = do_configure
  },
  sub_drivers = { }
}

defaults.register_for_default_handlers(ikea_window_driver_template, ikea_window_driver_template.supported_capabilities)
local driver = ZigbeeDriver("ikea-window", ikea_window_driver_template)
driver:run()
