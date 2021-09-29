local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local log = require "log"

local clusters = require "st.zigbee.zcl.clusters"
local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"
local zdo_messages = require "st.zigbee.zdo"
local data_types = require "st.zigbee.data_types"

local OnOff = clusters.OnOff
local PowerConfiguration = clusters.PowerConfiguration

local xiaomi_utils = require "xiaomi_utils"
local configsMap = require "configurations"

local click_types = {capabilities.button.button.pushed, capabilities.button.button.double}

local function first_switch_ep(device)
  return device:get_field("first_switch_ep")
end

local function first_button_ep(device)
  return device:get_field("first_button_ep")
end

local function component_to_endpoint(device, component_id)
  log.warn("component_to_endpoint", component_id)
  
  local first_switch_ep = first_switch_ep(device)

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
  if ep == device.fingerprinted_endpoint_id or ep == 0 then --  
    button_comp = "main"
  else
    button_comp = string.format("button%d", ep)
  end

  log.debug("endpoint_to_component: " .. tostring(button_comp) .. " ep:" ..tostring(ep))
  return button_comp
end


local function consumption_handler(device, value)
  device:emit_event( capabilities.energyMeter.energy({value=value.value, unit="Wh"}) )
end

local function voltage_handler(device, value)
  device:emit_event( capabilities.voltageMeasurement.voltage({value=value.value//10, unit="V"}) )
end

local function resetEnergyMeter(device)
end

local function added_handler(self, device)
  
end

local device_init = function(self, device)
  log.warn("device_init: " .. tostring(device))
  -- device:set_field("onOff", "catchAll", {persist = true})
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
  
  local click_type = click_types[val]
  local component_id = ep - first_button_ep(device) + 1

  device:emit_event_for_endpoint(component_id, click_type({state_change = true})) 
end

function old_button_handler(device, component_id, value)
  local CLICK_TIMER  = string.format("button_timer%d", component_id)
  local UP_COUNTER   = string.format("up_counter%d"  , component_id)
  local DOWN_COUNTER = string.format("down_counter%d", component_id)
  
  local click_timer = device:get_field(CLICK_TIMER)
  local down_counter = device:get_field(DOWN_COUNTER)
  local up_counter = device:get_field(UP_COUNTER)

  local held = function()
    local f_down_counter = device:get_field(DOWN_COUNTER)
    local f_up_counter = device:get_field(UP_COUNTER)
    local button = capabilities.button.button
    log.warn(">>> up_counter: " .. tostring(f_up_counter) .. ", down_counter: " .. tostring(f_down_counter))

    local click_type
    if f_down_counter == 1 and f_up_counter == 0 then
      click_type = button.held
    elseif f_down_counter < f_up_counter then
      click_type = button.up
      log.warn("WTF up_counter: " .. tostring(f_up_counter) .. "> down_counter: " .. tostring(f_down_counter))
    else
      click_type = click_types[f_down_counter]   
    end
    
    device:emit_event_for_endpoint(component_id, click_type({state_change = true}))
    device:set_field(CLICK_TIMER, nil)
    device:set_field(DOWN_COUNTER, 0)
    device:set_field(UP_COUNTER, 0)
  end

  if value.ID == data_types.Boolean.ID then
    if click_timer then
      if not value.value then
        down_counter = down_counter + 1
        device:set_field(DOWN_COUNTER, down_counter)
      else
        up_counter = up_counter + 1
        device:set_field(UP_COUNTER, up_counter)
      end
    else
      if not value.value then
        timer = device.thread:call_with_delay(1, held)
        device:set_field(CLICK_TIMER, timer)
        device:set_field(DOWN_COUNTER, 1)
        device:set_field(UP_COUNTER, 0)
      else
        --log.warn("up without down, from previous held?")
      end
    end
  else
    log.warn("unhandled button value: " .. tostring(value))
  end
end

function on_off_attr_handler(driver, device, value, zb_rx)
  local ep = zb_rx.address_header.src_endpoint.value
  local first_button_ep = first_button_ep(device)

  if ep < first_button_ep  then
    local attr = capabilities.switch.switch
    local component_id = ep - first_switch_ep(device) + 1
    log.debug("switch" .. tostring(component_id))
    device:emit_event_for_endpoint(component_id, value.value and attr.on() or attr.off())
  else
    local component_id = ep - first_button_ep + 1
    old_button_handler(device, component_id, value)
  end
end

local function do_configure(self, device)
  log.info("Configure ".. tostring(device.preferences.detach1) .. " " .. tostring(device.preferences.detach2))
  device:refresh()
  --device:configure()
  -- device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(device_management.build_bind_request(device, OnOff.ID, self.environment_info.hub_zigbee_eui))
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
  local message_body = zdo_messages.ZdoMessageBody({ zdo_body = binding_table_req })
  local binding_table_cmd = messages.ZigbeeMessageTx({
                                                     address_header = addr_header,
                                                     body = message_body
                                                   })
  device:send(binding_table_cmd)
end

local function zdo_binding_table_handler(driver, device, zb_rx)
  log.info("ZDO Binding Table Response")
  for _, binding_table in pairs(zb_rx.body.zdo_body.binding_table_entries) do
    if binding_table.dest_addr_mode.value == binding_table.DEST_ADDR_MODE_SHORT then
      -- send add hub to zigbee group command
      driver:add_hub_to_zigbee_group(binding_table.dest_addr.value)
    end
  end
end

xiaomi_utils.xiami_events[0x95] = consumption_handler

local switch_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    -- capabilities.button,
    -- capabilities.powerMeter,
    -- capabilities.energyMeter,    
    capabilities.temperatureAlarm,
    capabilities.refresh,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  use_defaults = false,
  zigbee_handlers = {
    global = {},
    cluster = {},
    zdo = {
      [mgmt_bind_resp.MGMT_BIND_RESPONSE] = zdo_binding_table_handler
    },
    attr = {
      [OnOff.ID] = {
        [OnOff.attributes.OnOff.ID] = on_off_attr_handler
      },
      [0x12] = {
        [0x55] = button_attr_handler
      },
      [zcl_clusters.basic_id] = {
        [xiaomi_utils.attr_id] = xiaomi_utils.handler
      }
    }
  },
  sub_drivers = {},
  lifecycle_handlers = {
    init = device_init,
    added = added_handler,
    doConfigure = do_configure,
  }
}

defaults.register_for_default_handlers(switch_driver_template, switch_driver_template.supported_capabilities)
local plug = ZigbeeDriver("switch", switch_driver_template)
plug:run()