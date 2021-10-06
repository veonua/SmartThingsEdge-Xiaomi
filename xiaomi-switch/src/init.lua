local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local log = require "log"

local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"
local zdo_messages = require "st.zigbee.zdo"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"

local OnOff = zcl_clusters.OnOff
local PowerConfiguration = zcl_clusters.PowerConfiguration
local MultistateInput = 0x0012

local xiaomi_utils = require "xiaomi_utils"
local configsMap   = require "configurations"
local utils = require "utils"
local click_types = {capabilities.button.button.pushed, capabilities.button.button.double, capabilities.button.button.pushed_3x, capabilities.button.button.pushed_4x}

local function component_to_endpoint(device, component_id)
  local first_switch_ep = utils.first_switch_ep(device)

  if component_id == "main" then
    return first_switch_ep -- device.fingerprinted_endpoint_id -- 
  else
    local ep_num = component_id:match("button(%d)")
    local res = ep_num and tonumber(ep_num - 1 + first_switch_ep) or device.fingerprinted_endpoint_id
    log.info("component_to_endpoint", component_id, res)
    return res
  end
end

local function endpoint_to_component(device, ep)
  local button_comp
  if ep == device.fingerprinted_endpoint_id or ep < 2 then --  
    button_comp = "main"
  else
    button_comp = string.format("button%d", ep)
  end

  return button_comp
end


local function consumption_handler(device, value)
  device:emit_event( capabilities.energyMeter.energy({value=value.value, unit="Wh"}) )
end

local function voltage_handler(device, value)
  device:emit_event( capabilities.voltageMeasurement.voltage({value=value.value//10, unit="V"}) )
end


local device_init = function(self, device)
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)

  device:emit_event(capabilities.button.numberOfButtons({ value=2 }))
  local configs = configsMap.get_device_parameters(device)

  device:set_field("first_switch_ep", configs.first_switch_ep, {persist = true})
  device:set_field("first_button_ep", configs.first_button_ep, {persist = true})

  event = capabilities.button.supportedButtonValues(configs.supportedButtonValues)
  device:emit_event(event)
  for i = 2, 5 do
    if not device:component_exists(string.format("button%d", i)) then
      break
    end
    device:emit_event_for_endpoint(i, event)
  end
end

local do_refresh = function(self, device)
  device_init(self, device)
end

function button_attr_handler(driver, device, value, zb_rx)
  local val = value.value
  local ep = zb_rx.address_header.src_endpoint.value
  
  local click_type = utils.click_types[val]
  local component_id = ep - utils.first_button_ep(device) + 1

  if click_type ~= nil then
    device:emit_event_for_endpoint(component_id, click_type({state_change = true})) 
  end
end


local function info_changed(driver, device, event, args)
  log.info("info changed: " .. tostring(event))
  
  for id, value in pairs(device.preferences) do
    if args.old_st_store.preferences[id] ~= value then --and preferences[id] then
      local data = tonumber(device.preferences[id])
      
      local attr
      if id == "button1" then
        attr = 0xFF22
      elseif id == "button2" then
        attr = 0xFF23
      elseif id == "button3" then
        attr = 0xFF24
      end

      if attr then
        device:send(cluster_base.write_manufacturer_specific_attribute(device, zcl_clusters.basic_id, attr, 0x115F, data_types.Uint8, data) )
      end
    end
  end
end



xiaomi_utils.xiami_events[0x95] = consumption_handler

local switch_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.temperatureAlarm,
    capabilities.refresh,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  use_defaults = false,
  cluster_configurations = {
    [capabilities.button.ID] = { -- have no idea if it works
      {
        cluster = MultistateInput,
        attribute = 0x55,
        minimum_interval = 100,
        maximum_interval = 600,
        data_type = Uint16,
        reportable_change = 1
      }
    }
  },
  zigbee_handlers = {
    global = {},
    cluster = {},
    attr = {
      [OnOff.ID] = {
        [OnOff.attributes.OnOff.ID] = on_off_attr_handler
      },
      [MultistateInput] = { 
        [0x55] = button_attr_handler
      },

      [zcl_clusters.basic_id] = {
        [xiaomi_utils.attr_id] = xiaomi_utils.handler
      },

      [0XFFC0] = { -- Aqara
        [0x00F7] = xiaomi_utils.handler
      },
    }
  },

  sub_drivers = {require ("buttons"), require ("opple"), require ("old_switch")},
  
  lifecycle_handlers = {
    init = device_init,
    added = device_init,
    infoChanged = info_changed,
    doConfigure = do_configure,
  }
}

defaults.register_for_default_handlers(switch_driver_template, switch_driver_template.supported_capabilities)
local plug = ZigbeeDriver("switch", switch_driver_template)
plug:run()
