local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local json = require "dkjson"
local log = require "log"

local zcl_clusters = require "st.zigbee.zcl.clusters"
local PowerConfiguration = zcl_clusters.PowerConfiguration
local Groups = zcl_clusters.Groups

local zigbee_utils = require "zigbee_utils"

local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"


local function zdo_unbinding_table_handler(_driver, _device, zb_rx)
  log.warn("zdo_unbinding_table_handler", json.encode(zb_rx.body.zdo_body))
end

local function zdo_binding_table_handler(driver, _device, zb_rx)
  log.warn("zdo_binding_table_handler")
  for _, binding_table in pairs(zb_rx.body.zdo_body.binding_table_entries) do
    log.info("binding_table: " .. json.encode(binding_table))

    if binding_table.dest_addr_mode.value == binding_table.DEST_ADDR_MODE_SHORT then
      -- send add hub to zigbee group command
      driver:add_hub_to_zigbee_group(binding_table.dest_addr.value)
      log.info("add hub to zigbee group: " .. tostring( binding_table.dest_addr.value) )
    end
  end
end

local function do_configure(_self, device)
  log.info("do_configure")
  zigbee_utils.send_read_binding_table(device)
end

local do_refresh = function(_self, device)
  zigbee_utils.print_clusters(device)
  zigbee_utils.send_read_binding_table(device)
  device:send(Groups.server.commands.GetGroupMembership(device, {}))
end

local function battery_perc_attr_handler(_driver, device, value, zb_rx)
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.battery.battery(value.value))
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
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  zigbee_handlers = {
    attr = {
      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_perc_attr_handler,
      }
    },
    zdo = {
      [mgmt_bind_resp.MGMT_BIND_RESPONSE] = zdo_binding_table_handler,
      [0x8022] = zdo_unbinding_table_handler
    }
  },
  lifecycle_handlers = {
    doConfigure = do_configure
  },
  sub_drivers = { require('blinds') , require('buttons') },
}

defaults.register_for_default_handlers(ikea_window_driver_template, ikea_window_driver_template.supported_capabilities)
local driver = ZigbeeDriver("ikea-window", ikea_window_driver_template)
driver:run()
