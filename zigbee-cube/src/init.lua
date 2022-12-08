local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"

local log = require "log"
local xiaomi_utils = require "xiaomi_utils"

local MOTION_RESET_TIMER = "motionResetTimer"
local LEVEL_TS  = "level_ts"
local CURRENT_LEVEL = "current_level"
local SIDE = "side"
local DEFAULT_LEVEL = 50

local cube = capabilities["winterdictionary35590.cube"]
local map_side_to_name = { "up", "left", "front", "down", "right", "back" }

local generate_switch_level_event = function(device, value)
  device:emit_event(capabilities.switchLevel.level(value))
  device:set_field(CURRENT_LEVEL, value)
  device:set_field(LEVEL_TS, os.time())
end

local function added_handler(self, device)
  log.info("Added device: " .. device:get_model())
  device:emit_event(capabilities.switch.switch.on())
end


local function emit_action_event(device, action, state_change)
  local event = cube.action(action)
  if state_change==false then
    event.state_change = false
  else
    event.state_change = true
  end
  device:emit_event(event)
end

local function cube_attr_handler(driver, device, value, zb_rx)
  local val = value.value 
  local side = val & 0x7
  local action = (val >> 8) & 0xFF
  local prev_side = device:get_field(SIDE)

  local reset_motion_status = function()
    device:emit_event(capabilities.motionSensor.motion.inactive())
    emit_action_event(device, "Ready", false)
  end
  motion_reset_timer = device.thread:call_with_delay(2, reset_motion_status)

  if action == 0x00 then -- flip
    local flip_type = (val >> 6) & 0x3
    
    if flip_type == 0 then  
      -- final side is unknown
      side = -1
      prev_side = -1
      device:set_field(SIDE, side)
      
      if val == 0 then -- shake
        emit_action_event(device, "shake")
      elseif val == 2 then -- wake up
        device:emit_event(capabilities.motionSensor.motion.active())
      elseif val == 3 then -- toss
        emit_action_event(device, "toss")
      end

      return
    else
      prev_side = (val >> 3) & 0x7 
      log.debug("flip_type: ", flip_type, " prev_side: ", prev_side, " side: ", side)
  
      if flip_type == 1 then
        log.info("flip  90* " .. tostring(prev_side) .. ">" .. tostring(side))
        emit_action_event(device, "flip90")
        
      elseif flip_type == 2 then
        if side==0 then
          prev_side = 3 -- because of bug in cube
        end
        log.info("flip 180* " .. tostring(side))
        emit_action_event(device, "flip180")
      end
    end
  elseif action == 0x01 then -- slide
    emit_action_event(device, "slide")
  elseif action == 0x02 then -- double tap
    emit_action_event(device, "tap")
  end

  if side ~= prev_side then
    device:set_field(SIDE, side)
    event = cube.face(map_side_to_name[side+1])
    --event.state_change = true
    device:emit_event(event)   
  end
end


local function rotate_attr_handler(driver, device, value, zb_rx)
  local val = utils.round( utils.clamp_value(value.value, -180, 180) ) -- between -180 and 180
  local delta = math.floor( val / 18 * 8) -- 80 percent for every 180*
  
  -- if device is on 
  local level = device:get_field(CURRENT_LEVEL) or DEFAULT_LEVEL
  if level >= 0 then
    log.debug("rotate: ", val, "old_level ", level, " delta: ", delta)
    local new_level = utils.clamp_value( level + delta, 2, 100)
    generate_switch_level_event(device, new_level)
  end

  local event = cube.rotation(val)
  event.state_change = true
  device:emit_event( event )

  --- to force run subsequent actions  
  device:emit_event( cube.rotation(0) )
end

function set_level(_, device, command)
  local last_rotate = device:get_field(LEVEL_TS) or 0
  if os.time() - last_rotate < 5 then
    log.info("ignore dimmer loopback")
    return
  end
  
  local value = command.args.level
  device:emit_event(capabilities.switchLevel.level(value))
  device:set_field(CURRENT_LEVEL, value)
end

local do_refresh = function(self, device)
  added_handler(self, device)
end

function on_off(_, device, command)
  local last_state = device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME)
  
  if (last_state == command.command) then
    log.info("ignore on/off loopback")
    return
  end

  local on_off = command.command == 'on'
  if on_off then
    local last_level = device:get_latest_state("main", capabilities.switchLevel.ID, capabilities.switchLevel.level.NAME)
    if last_level == nil then
      last_level = DEFAULT_LEVEL
    end
    log.debug("on_off: ", on_off, " last_level: ", last_level)

    device:set_field(CURRENT_LEVEL, last_level)
    return device:emit_event(capabilities.switch.switch.on())
  end

  device:set_field(CURRENT_LEVEL, -1)
  log.debug("on_off: ", on_off)
  return device:emit_event(capabilities.switch.switch.off())
end

xiaomi_utils.events[0x98] = nil -- supress power reports

local aqara_cube_driver_template = {
  supported_capabilities = {
    capabilities.motionSensor,
    capabilities.battery,
    capabilities.temperatureAlarm,
  },
  lifecycle_handlers = {
    added = added_handler,
  },

  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    },
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = on_off,
      [capabilities.switch.commands.off.NAME] = on_off
    },
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = set_level
    }
  },
  use_defaults = false,
  zigbee_handlers = {
    global = {},
    cluster = {},
    attr = {
      [zcl_clusters.basic_id] = xiaomi_utils.basic_id,
      [0x12] = {
        [0x0055] = cube_attr_handler
      }, 
      [zcl_clusters.analog_input_id] = {
        [zcl_clusters.AnalogInput.attributes.PresentValue.ID] = rotate_attr_handler
      }
    }
  },
}

local aqara_cube = ZigbeeDriver("aqara_cube", aqara_cube_driver_template)
aqara_cube:run()
