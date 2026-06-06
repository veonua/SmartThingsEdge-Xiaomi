local zcl_clusters = require "st.zigbee.zcl.clusters"
local device_lib = require "st.device"
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local log = require "log"

local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"

local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"

local st_utils = require "st.utils"
local xiaomi_utils = require "xiaomi_utils"
local configsMap   = require "configurations"
local utils = require "utils"

local MULTISTATE_INPUT_CLUSTER_ID = 0x0012
local WIRELESS_SWITCH_ATTRIBUTE_ID = 0x0055

local POWER_METER_ENDPOINT = 0x15
local ENERGY_METER_ENDPOINT = 0x1F

local PRIVATE_CLUSTER_ID = 0xFCC0
local PRIVATE_ATTRIBUTE_ID = 0x0009
local MFG_CODE = 0x115F

local knob = capabilities.knob


local function component_to_endpoint(device, component_id)
  local first_switch_ep = utils.first_switch_ep(device)

  if component_id == "main" then
    -- log.info("component:", component_id, "> ep:", first_switch_ep)
    return first_switch_ep -- device.fingerprinted_endpoint_id
  else
    local ep_num = component_id:match("button(%d)")
    local res = ep_num and tonumber(ep_num) - 1 + first_switch_ep or device.fingerprinted_endpoint_id
    -- log.info("component:", component_id, "> ep:", res)
    return res
  end
end

local function endpoint_to_component(device, ep)
  -- we have an error here for H1 dimmer
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

--

local function find_child(parent, ep)
  local first_switch_ep = utils.first_switch_ep(parent)
  local first_button_ep = utils.first_button_ep(parent)
  local button_group_ep = utils.first_button_group_ep(parent)

  if ep >= button_group_ep then
    return nil
  end

  local comp_id = ep
  if ep >= first_button_ep then
    comp_id = ep - first_button_ep + first_switch_ep -- + 1
  end

  local button_comp = parent:get_child_by_parent_assigned_key(string.format("%02X", comp_id))
  return button_comp
end


local CONFIG_MAP = {

  ["lumi.switch.b2lc04"]   = { children_amount = 2 },
  ["lumi.switch.b2lacn02"] = { children_amount = 2 },
  ["lumi.switch.b2nacn02"] = { children_amount = 2 },
  ["lumi.switch.b2naus01"] = { children_amount = 2 },
  ["lumi.ctrl_neutral2"]   = { children_amount = 2 },
  ["lumi.ctrl_ln2"]        = { children_amount = 2 },
  ["lumi.ctrl_ln2.aq1"]    = { children_amount = 2 },
  ["lumi.switch.l3acn3"]   = { children_amount = 3 },
  ["lumi.switch.n3acn3"]   = { children_amount = 3 },
}


local function get_children_amount(device)
  local model = device:get_model()
  return CONFIG_MAP[model] and CONFIG_MAP[model].children_amount or 1
end

local function device_added(driver, device)
  -- Only create children for the actual Zigbee device and not the children
  if device.network_type ~= device_lib.NETWORK_TYPE_ZIGBEE then
    log.info("Device is not Zigbee")
    return
  end

  device:emit_event(knob.supportedAttributes({"rotateAmount"}, {visibility = {displayed = false}}))


  device:emit_event(capabilities.powerMeter.power({ value = 0.0, unit = "W" }))
  device:emit_event(capabilities.energyMeter.energy({ value = 0.0, unit = "Wh" }))

  device:send(cluster_base.write_manufacturer_specific_attribute(device,
    PRIVATE_CLUSTER_ID, PRIVATE_ATTRIBUTE_ID, MFG_CODE, data_types.Uint8, 0x01)) -- private

  local configs = configsMap.get_device_parameters(device)
  device:set_field("first_switch_ep", configs.first_switch_ep, {persist = true})
  device:set_field("first_button_ep", configs.first_button_ep, {persist = true})
  device:set_field("number_of_channels", configs.number_of_channels, {persist = true})
  device:set_field("neutral_wire", configs.neutral_wire, {persist = true})

  local battery_info = configs.battery_info
  if battery_info then
    local type = battery_info.type or "CR2032"
    local quantity = battery_info.quantity or 1
    device:emit_event(capabilities.batteryLevel.battery.normal())
    device:emit_event(capabilities.batteryLevel.type(type))
    device:emit_event(capabilities.batteryLevel.quantity(quantity))
  end

  local first_switch_ep = configs.first_switch_ep
  local children_amount = get_children_amount(device)

  if children_amount >= 2 then
    for i = first_switch_ep + 1, first_switch_ep + children_amount - 1, 1 do
      -- log.info("--- Creating child device: ", i)

      if find_child(device, i) == nil then
        local name = string.format("%s%d", device.label, i)
        local child_profile = "aqara-switch-child"
        local metadata = {
          type = "EDGE_CHILD",
          label = name,
          profile = child_profile,
          parent_device_id = device.id,
          parent_assigned_child_key = string.format("%02X", i), -- same as Zigbee endpoint
          vendor_provided_label = name
        }
        -- log.info("+++ Creating child device: ", name)
        driver:try_create_device(metadata)
      end
    end
  end
end
---

local device_init = function(_self, device)

  log.warn(st_utils.stringify_table(device.st_store, "st_store"))

  log.info("------- device_init -------")
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)

  if device.network_type ~= device_lib.NETWORK_TYPE_ZIGBEE then
    -- Device is Virtual
    device:emit_event(capabilities.button.supportedButtonValues({"pushed", "pushed_2x", "held"},
                                      { visibility = { displayed = false } }))

    return
  end

  device:set_find_child(find_child)

  device:remove_monitored_attribute(zcl_clusters.OnOff.ID, zcl_clusters.OnOff.attributes.OnOff.ID) -- remove held event

  local configs = configsMap.get_device_parameters(device)

  if device:supports_capability(capabilities.button, "main") then
    local event = capabilities.button.supportedButtonValues(configs.supported_button_values)
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

    log.info("number of buttons:", numberOfButtons)
    log.info("number of channels:", configs.number_of_channels)
    log.info("neutral wire:", configs.neutral_wire)

    device:emit_event(capabilities.button.numberOfButtons({ value=numberOfButtons }))

    numberOfButtons = math.max(numberOfButtons, configs.number_of_channels)
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
  log.info("------- do_refresh -------")
  -- device_added(self, device)
  device_init(self, device)

  --device:send(zcl_clusters.OnOff.attributes.OnOff:read(device))
  device:send(zcl_clusters.AnalogInput.attributes.PresentValue:read(device):to_endpoint(POWER_METER_ENDPOINT))
  device:send(zcl_clusters.AnalogInput.attributes.PresentValue:read(device):to_endpoint(ENERGY_METER_ENDPOINT))
end

local function button_attr_handler(_driver, device, value, zb_rx)
  local click_type = utils.click_types[value.value]

  if click_type ~= nil then
    utils.emit_button_event(device, zb_rx.address_header.src_endpoint.value, click_type({state_change = true}))
  else
    log.info("No such st event, Button released or unknown click type: ", value.value)
  end
end

local function zdo_binding_table_handler(driver, _device, zb_rx)
  log.warn("ZDO Binding Table Response")

  for _, binding_table in pairs(zb_rx.body.zdo_body.binding_table_entries) do
    if binding_table.dest_addr_mode.value == binding_table.DEST_ADDR_MODE_SHORT then
      driver:add_hub_to_zigbee_group(binding_table.dest_addr.value)
      log.info("add hub to zigbee group: " .. tostring( binding_table.dest_addr.value) )
    end
  end
end

local function make_manu_attr_handler(name)
  return function(_, device, value)
    local v = value.value
    log.info(string.format("manuSpecificLumi %s: %s", name, tostring(v)))
    device:set_field("manu_" .. name, v, { persist = true })
  end
end

local KNOB_ACTIONS = {
  [0x00] = "off",
  [0x01] = "start_rotation",
  [0x02] = "rotation",
  [0x03] = "stop_rotation",
  [0x81] = "hold_start_rotation",
  [0x82] = "hold_rotation",
  [0x83] = "hold_stop_rotation",
}

local function knob_action_handler(_, device, value)
  local v = value.value
  local label = KNOB_ACTIONS[v] or string.format("unknown_0x%02X", v)
  log.info(string.format("manuSpecificLumi action: %s (%s)", label, tostring(v)))
  device:set_field("manu_action", v, { persist = true })
end

local function rotation_percent_delta_handler(_, device, value, zb_rx)
  local end_point = zb_rx.address_header.src_endpoint.value
  local raw_val = st_utils.round(value.value)

  if end_point == 0x47 then -- normal
    device:emit_event(capabilities.knob.rotateAmount({value = raw_val}, {state_change = true}))
  elseif end_point == 0x48 then -- press
    device:emit_event(capabilities.knob.heldRotateAmount({value = raw_val}, {state_change = true}))
  end

  -- log.info(string.format("manuSpecificLumi rotation_percent_delta: %s", tostring(scroll_amount)))
  -- device:set_field("manu_rotation_percent_delta", scroll_amount, { persist = true })
end

local function set_level(_, device, command)
  local level = command.args.level or 0
  if level < 0 then level = 0 end
  if level > 100 then level = 100 end

  local zb_level = math.floor((level * 254) / 100)

  local ep = component_to_endpoint(device, command.component or "main") or device.fingerprinted_endpoint_id
  device:send(
    zcl_clusters.Level.commands.MoveToLevel(device, zb_level, 0)
      :to_endpoint(ep)
  )

  device:emit_event(capabilities.switchLevel.level(level))
end

local function step_level(_, device, command)
  local step = command.args.stepSize

  if type(step) ~= "number" then
    step = tonumber(step) or 10
  end

  local step_mode = 0x00 -- up
  if step < 0 then
    step_mode = 0x01 -- down
  end

  local step_abs = math.abs(step)
  local step_zb = math.floor((step_abs * 254) / 100)
  if step_zb < 1 then step_zb = 1 end
  if step_zb > 254 then step_zb = 254 end

  local ep = component_to_endpoint(device, command.component or "main") or device.fingerprinted_endpoint_id
  device:send(
    zcl_clusters.Level.commands.Step(device, step_mode, step_zb, 0)
      :to_endpoint(ep)
  )

end

local function info_changed(_driver, device, _event, args)
  local preferences = device.preferences
  if preferences == nil then
    log.warn("preferences is nil")
    return
  end

  -- xiaomi_switch_operation_mode_basic
  for id, value in pairs(device.preferences) do
      if args.old_st_store.preferences[id] ~= value then --and preferences[id] then
          local data = tonumber(device.preferences[id])

          if data == nil then
            -- convert boolean to int
            data = device.preferences[id] == true and 1 or 0
          end

          local attr
          if id == "button1" then
            attr = 0xFF22
          elseif id == "button2" then
              attr = 0xFF23
          elseif id == "button3" then
              attr = 0xFF24
          end

          if attr then
            log.info("+info_changed: ", id, value, data, attr)
            device:send(
              cluster_base.write_manufacturer_specific_attribute(
                device,
                zcl_clusters.basic_id,
                attr,
                MFG_CODE,
                data_types.Uint8,
                data
              )
            )
          else
            log.error("info not changed ", id, value)
          end
      end
  end
end

local switch_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.switchLevel,
    capabilities.knob,
    capabilities.statelessSwitchLevelStep,
    capabilities.powerMeter,
    capabilities.temperatureAlarm,
    capabilities.refresh,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = set_level,
    },
    [capabilities.statelessSwitchLevelStep.ID] = {
      [capabilities.statelessSwitchLevelStep.commands.stepLevel.NAME] = step_level,
    }
  },
  cluster_configurations = {
    [capabilities.button.ID] = { -- have no idea if it works
      {
        cluster = MULTISTATE_INPUT_CLUSTER_ID,
        attribute = WIRELESS_SWITCH_ATTRIBUTE_ID,
        minimum_interval = 100,
        maximum_interval = 7200,
        data_type = data_types.Uint16,
        reportable_change = 1
      },
      {
        cluster = zcl_clusters.PowerConfiguration.ID,
        attribute = zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.ID,
        minimum_interval = 30,
        maximum_interval = 3600,
        data_type = zcl_clusters.PowerConfiguration.attributes.BatteryVoltage.base_type,
        reportable_change = 1
      }
      -- ,{
      --   cluster = zcl_clusters.OnOff.ID,
      --   attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
      --   minimum_interval = 100,
      --   maximum_interval = 3600,
      --   data_type = data_types.Boolean
      -- }
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
      [MULTISTATE_INPUT_CLUSTER_ID] = {
        [WIRELESS_SWITCH_ATTRIBUTE_ID] = button_attr_handler
      },
      [PRIVATE_CLUSTER_ID] = {
        --[0x022E] = make_manu_attr_handler("rotation_angle"),
        --[0x022C] = make_manu_attr_handler("rotation_time_delta"),

        --[0x0230] = make_manu_attr_handler("rotation_angle_delta"),
        --[0x0231] = make_manu_attr_handler("rotation_time"),
        [0x0232] = rotation_percent_delta_handler,
        --[0x0233] = make_manu_attr_handler("rotation_percent"),

        --[0x0238] = make_manu_attr_handler("unknown_0238"),
        [0x023A] = knob_action_handler,
        --[0x0301] = make_manu_attr_handler("multiplier"),

      },
    }
  },
  sub_drivers = { require ("buttons"), require ("opple"), require ("old_switch"), require("WXKG01LM") },

  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    infoChanged = info_changed,
  }
}

defaults.register_for_default_handlers(switch_driver_template, switch_driver_template.supported_capabilities)
local driver = ZigbeeDriver("lumi-switch", switch_driver_template)
driver:run()
