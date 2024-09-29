local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local windowShadePreset_defaults = require "st.zigbee.defaults.windowShadePreset_defaults"
local log = require "log"
local cluster_base = require "st.zigbee.cluster_base"
local data_types = require "st.zigbee.data_types"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local mgmt_bind_req = require "st.zigbee.zdo.mgmt_bind_request"

---
local deviceInitialization = capabilities["stse.deviceInitialization"]
local reverseCurtainDirection = capabilities["stse.reverseCurtainDirection"]
local softTouch = capabilities["stse.softTouch"]
local setInitializedStateCommandName = "setInitializedState"

local INIT_STATE = "initState"
local INIT_STATE_INIT = "init"
local INIT_STATE_OPEN = "open"
local INIT_STATE_CLOSE = "close"
local INIT_STATE_REVERSE = "reverse"

---

local Basic = zcl_clusters.Basic
local WindowCovering = zcl_clusters.WindowCovering
local AnalogOutput = zcl_clusters.AnalogOutput
local Groups = zcl_clusters.Groups
local PowerConfiguration = zcl_clusters.PowerConfiguration

local MFG_CODE = 0x115F

-- see https://raw.githubusercontent.com/markus-li/Hubitat/release/drivers/expanded/zigbee-aqara-smart-curtain-motor-expanded.groovy
-- for referance

local function zdo_binding_table_handler(driver, device, zb_rx)
  for _, binding_table in pairs(zb_rx.body.zdo_body.binding_table_entries) do
    log.info("binding_table: %s", binding_table)
    --if binding_table.dest_addr_mode.value == binding_table.DEST_ADDR_MODE_SHORT then
      -- send add hub to zigbee group command
    --  driver:add_hub_to_zigbee_group(binding_table.dest_addr.value)
    --end
  end
end

local function added_handler(self, device)
  device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({ value = { "open", "close", "pause"} }))
  --device:emit_component_event(main_comp,
  --  deviceInitialization.supportedInitializedState({ "notInitialized", "initializing", "initialized" }))

  device:send(Groups.server.commands.RemoveAllGroups(device))

  -- Set default value to the device.
  --write_pref_attribute(device, PREF_REVERSE_OFF)
  --write_pref_attribute(device, PREF_SOFT_TOUCH_ON)

  device:refresh()
end

local level_handler = function(self, device, value, zb_rx) 
  local body_length = zb_rx.body_length.value
  local val = math.floor(value.value)

  log.debug("level_handler: ", value, " body_length: ", body_length, " val: ", val)

  local state = nil
  
  if body_length == 0x11 then
    if val == 0 then
      device:send(AnalogOutput.attributes.PresentValue:read(device))
    else
      log.info("moving")
    end
  else
    if val <= 3 then
      state = "closed"
      val = 0
    elseif val >= 97 then
      state = "open"
      val = 100
    else
      state = "partially open"
    end
    device:emit_event(capabilities.windowShadeLevel.shadeLevel({ value = val }))
    device:set_field("shadeLevel", val)
  end

  if state then
    device:emit_event(capabilities.windowShade.windowShade(state))
  end
end

function pause(driver, device, command)
  device:send_to_component(command.component, WindowCovering.server.commands.Stop(device))
end

function toggle(driver, device, command)
  local level = device:get_latest_state("main", capabilities.windowShadeLevel.ID,
      capabilities.windowShadeLevel.shadeLevel.NAME) or 0

  log.info("toggle level: ", level)

  if level < 50 then
    set_window_shade_level(driver, device, 100)
  else
    set_window_shade_level(driver, device, 0)
  end
end

function set_window_shade_level(driver, device, number)
  local lastLevel = device:get_latest_state("main", capabilities.windowShadeLevel.ID,
      capabilities.windowShadeLevel.shadeLevel.NAME) or 0
  
  if lastLevel == number then
    log.info("window shade level is already set to ", number)
  return end

  log.info("setting window shade level to ", number, " from ", lastLevel)
  
  if number == 0 then -- zero is not a valid value
    number = 1
  end

  local sign = 0
  local mantissa, exponent = math.frexp(number)
  mantissa = mantissa * 2 - 1
  exponent = exponent - 1
  
  local data = data_types.SinglePrecisionFloat(sign, exponent, mantissa)
  device:send(AnalogOutput.attributes.PresentValue:write(device, data))

  local state = (number < lastLevel) and "closing" or "opening"
  device:emit_event(capabilities.windowShade.windowShade(state))
end

function window_shade_level_cmd(driver, device, command)
  local number = command.args.shadeLevel
  set_window_shade_level(driver, device, number)
end

function preset(driver, device, command)
  local level = device.preferences.presetPosition or device:get_field(windowShadePreset_defaults.PRESET_LEVEL_KEY) or windowShadePreset_defaults.PRESET_LEVEL
  
  set_window_shade_level(driver, device, level)
end


local function build_window_shade_level(value)
  return function(driver, device, command)
    set_window_shade_level(driver, device, value)
  end
end

local do_refresh = function(self, device)
  device:send(AnalogOutput.attributes.PresentValue:read(device))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))
  device:send(PowerConfiguration.attributes.BatteryVoltage:read(device))

  --device:send(cluster_base.read_manufacturer_specific_attribute(device, Basic.ID, aqara_utils.PREF_ATTRIBUTE_ID,
  --  MFG_CODE))
end

local do_configure = function(self, device)
  -- device:send(AnalogOutput.attributes.PresentValue:configure_reporting(device, 30, 21600, 1))
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1))

  device:configure()
  device:send(Basic.attributes.ApplicationVersion:read(device))
  device:send(Groups.server.commands.RemoveAllGroups(device))
  do_refresh(self, device)
end

local function info_changed(driver, device, event, args)
  log.info(tostring(event))
  
  for id, value in pairs(device.preferences) do
    if args.old_st_store.preferences[id] ~= value then
      local data = device.preferences[id]
      
      local attr
      local val
      if id == "touchStart" then
        val = not data
        attr = 0xFF29
      elseif id == "reverse" then
        attr = 0xFF28
        val = data
      elseif id == "reset" then
        attr = 0xFF27
        val = false
      end

      device:send(cluster_base.write_manufacturer_specific_attribute(device, zcl_clusters.basic_id, attr, MFG_CODE, data_types.Boolean, val) )
    end
  end
end

local function application_version_handler(driver, device, value, zb_rx)
  local version = tonumber(value.value)
  device:set_field("application_version", version, { persist = true })
  log.info("application_version_handler: ", version)
end

local blinds_driver_template = {
  supported_capabilities = {
    capabilities.windowShadeLevel,
    capabilities.windowShadePreset,
    capabilities.battery,
    capabilities.refresh,
  },
  lifecycle_handlers = {
    added = added_handler,
    doConfigure = do_configure,
    infoChanged = info_changed,
  },
  cluster_configurations = {
    [capabilities.windowShadeLevel.ID] = { -- have no idea if it works
      {
        cluster = AnalogOutput.ID,
        attribute = AnalogOutput.attributes.PresentValue.ID,
        minimum_interval = 1,
        maximum_interval = 600,
        data_type = data_types.SinglePrecisionFloat,
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
      -- [PowerConfiguration.ID] = {
      --   [PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_perc_attr_handler,
      -- },
      [AnalogOutput.ID] = {
        [AnalogOutput.attributes.PresentValue.ID] = level_handler,
      }
    }
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
    [capabilities.windowShade.ID] = {
      [capabilities.windowShade.commands.close.NAME] = build_window_shade_level(1),
      [capabilities.windowShade.commands.pause.NAME] = pause,
      [capabilities.windowShade.commands.open.NAME]  = build_window_shade_level(100),
    },
    [capabilities.windowShadeLevel.ID] = {
      [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = window_shade_level_cmd
    },
    [capabilities.windowShadePreset.ID] = {
      [capabilities.windowShadePreset.commands.presetPosition.NAME] = preset
    },
    [capabilities.statelessPowerToggleButton.ID] = {
      [capabilities.statelessPowerToggleButton.commands.setButton.NAME] = toggle
    },
    [Basic.ID] = {
    --  [aqara_utils.SHADE_STATE_ATTRIBUTE_ID] = shade_state_report_handler,
    --  [aqara_utils.PREF_ATTRIBUTE_ID] = pref_report_handler,
        [Basic.attributes.ApplicationVersion.ID] = application_version_handler
    }
  },
  sub_drivers = {},
}

defaults.register_for_default_handlers(blinds_driver_template, blinds_driver_template.supported_capabilities)
local blinds = ZigbeeDriver("blinds", blinds_driver_template)
blinds:run()