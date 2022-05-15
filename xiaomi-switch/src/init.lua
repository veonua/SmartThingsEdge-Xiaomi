local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local log = require "log"

local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"

local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"

local MultistateInput = 0x0012

local st_utils = require "st.utils"
local xiaomi_utils = require "xiaomi_utils"
local configsMap   = require "configurations"
local utils = require "utils"


local function component_to_endpoint(device, component_id)
  local first_switch_ep = utils.first_switch_ep(device)
  
  if component_id == "main" then
    -- log.info("component:", component_id, "> ep:", first_switch_ep)
    return first_switch_ep -- device.fingerprinted_endpoint_id -- 
  else
    local ep_num = component_id:match("button(%d)")
    local res = ep_num and tonumber(ep_num) - 1 + first_switch_ep or device.fingerprinted_endpoint_id
    -- log.info("component:", component_id, "> ep:", res)
    return res
  end
end

local function endpoint_to_component(device, ep)
  local first_switch_ep = utils.first_switch_ep(device)
  local first_button_ep = utils.first_button_ep(device)
  local button_group_ep = utils.first_button_group_ep(device)
  
  if ep >= button_group_ep then
    return string.format("group%d", ep - button_group_ep + 1)
  end

  local comp_id
  if ep >= first_button_ep then
    comp_id = ep - first_button_ep
  else
    comp_id = ep - first_switch_ep
  end

  local button_comp = "main"
  if comp_id > 0 then
    button_comp = string.format("button%d", comp_id + 1)
  end

  --log.info("endpoint:", ep, "> component:", button_comp)
  return button_comp
end

local device_init = function(self, device)
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)

  ---
  device:remove_monitored_attribute(0x0006, 0x0000)
  device:remove_monitored_attribute(0x0012, 0x0055)
  ---
  local configs = configsMap.get_device_parameters(device)

  device:set_field("first_switch_ep", configs.first_switch_ep, {persist = true})
  device:set_field("first_button_ep", configs.first_button_ep, {persist = true})

  if device:supports_capability(capabilities.button, "main") then
    event = capabilities.button.supportedButtonValues(configs.supported_button_values)
    device:emit_event(event)

    local numberOfButtons = 1
    for i = 2, 10 do
      local comp_id = string.format("button%d", i)
      if not device:component_exists(comp_id) then
        numberOfButtons = i-1
        break
      end
      
      local comp = device.profile.components[comp_id]
      device:emit_component_event(comp, event)
    end

    log.info("number of buttons:",numberOfButtons)
    device:emit_event(capabilities.button.numberOfButtons({ value=numberOfButtons }))
    
    if numberOfButtons > 1 then
      local comp_id = string.format("group%d", 1)
      if device:component_exists(comp_id) then
        local comp = device.profile.components[comp_id]
        device:emit_component_event(comp, event)

        local button_group_ep = configs.first_button_ep + numberOfButtons 
        device:set_field("first_button_group_ep", button_group_ep, {persist = true})
        log.info("first_button_group_ep:", button_group_ep)
      end
    end

  end
  
end

local do_refresh = function(self, device)
  device_init(self, device)
end

function button_attr_handler(driver, device, value, zb_rx)
  local val = value.value
  
  if val == 255 then
    log.info("button released, no such st event")
    return
  end

  local click_type = utils.click_types[val]
  --local component_id = ep - utils.first_button_ep(device) + 1

  if click_type ~= nil then
    utils.emit_button_event(device, zb_rx.address_header.src_endpoint.value, click_type({state_change = true}))
  end
end

local function zdo_binding_table_handler(driver, device, zb_rx)
  log.warn("ZDO Binding Table Response")    
  
  for _, binding_table in pairs(zb_rx.body.zdo_body.binding_table_entries) do
    if binding_table.dest_addr_mode.value == binding_table.DEST_ADDR_MODE_SHORT then
      driver:add_hub_to_zigbee_group(binding_table.dest_addr.value)
      log.info("add hub to zigbee group: " .. tostring( binding_table.dest_addr.value) )
    end
  end
end

local switch_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.powerMeter,
    capabilities.temperatureAlarm,
    capabilities.refresh,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  cluster_configurations = {
    [capabilities.button.ID] = { -- have no idea if it works
      {
        cluster = MultistateInput,
        attribute = 0x55,
        minimum_interval = 100,
        maximum_interval = 3600,
        data_type = Uint16,
        reportable_change = 1
      }
    }
  },
  zigbee_handlers = {
    global = {},
    cluster = {},
    zdo = {
      [mgmt_bind_resp.MGMT_BIND_RESPONSE] = zdo_binding_table_handler
    },
    attr = {
      [zcl_clusters.basic_id] = xiaomi_utils.basic_id,
      [MultistateInput] = { 
        [0x55] = button_attr_handler
      },
    }
  },

  sub_drivers = { require ("buttons"), require ("opple"), require ("old_switch"), require("WXKG01LM") },
  
  lifecycle_handlers = {
    init = device_init,
    added = device_init,
  }
}

defaults.register_for_default_handlers(switch_driver_template, switch_driver_template.supported_capabilities)
local plug = ZigbeeDriver("switch", switch_driver_template)
plug:run()
