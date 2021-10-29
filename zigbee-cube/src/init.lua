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
-- 0 : front (aqara face up)
-- 1 : right
-- 2 : top
-- 3 : back
-- 4 : left
-- 5 : bottom

local button = capabilities.button.button 

local map_side_to_lightingMode = { "reading", "writing", "computer", "night", "sleepPreparation", "day" }
local map_flip_attribute_to_capability = { button.up, button.up_2x, button.up_3x, button.up_4x, button.up_5x, button.up_6x }
local map_slide_attribute_to_capability = { button.pushed, button.pushed_2x, button.pushed_3x, button.pushed_4x, button.pushed_5x, button.pushed_6x}

local generate_switch_level_event = function(device, value)
  device:emit_event(capabilities.switchLevel.level(value))
  device:set_field(CURRENT_LEVEL, value)
  device:set_field(LEVEL_TS, os.time())
end

local function added_handler(self, device)
  device:emit_event(capabilities.button.numberOfButtons({ value = 1 }))
  device:emit_event(capabilities.button.supportedButtonValues(
    {"up", "up_2x", "up_3x", "up_4x", "up_5x", "up_6x",
     "pushed", "pushed_2x", "pushed_3x", "pushed_4x", "pushed_5x", "pushed_6x"}))
  device:emit_event(capabilities.button.button.pushed({state_change = true}))
end

local function cube_attr_handler(driver, device, value, zb_rx)
  local val = value.value 
  local side = val & 0x7
  local action = (val >> 8) & 0xFF
  local prev_side = device:get_field(SIDE)
    
  if action == 0x01 then     -- slide
    device:emit_event(capabilities.motionSensor.motion.active())
    device:emit_event(map_slide_attribute_to_capability[side+1]({state_change = true}))
  elseif action == 0x02 then -- knock
    device:emit_event(capabilities.tamperAlert.tamper.detected())
  elseif action == 0x00 then -- flip
    local flip_type = (val >> 6) & 0x3
    prev_side = (val >> 3) & 0x7 
    log.debug("flip_type: ", flip_type, " prev_side: ", prev_side, " side: ", side)
  
    if flip_type == 0 then 
      if side == 0 and prev_side == 0 then -- shake
        device:emit_event(capabilities.accelerationSensor.acceleration.active())
      else
        -- just echoing last movement
        return
      end
    else
      if flip_type == 1 then
        log.info("flip  90* " .. tostring(prev_side) .. ">" .. tostring(side))
      elseif flip_type == 2 then
        if side==0 then
          prev_side = 3 -- because of bug in cube
        end
        log.info("flip 180* " .. tostring(side))
      end

      device:emit_event(map_flip_attribute_to_capability[side + 1]({state_change = true}))
    end
  end

  if side ~= prev_side then
    device:emit_event(capabilities.activityLightingMode.lightingMode({ value = map_side_to_lightingMode[side+1] })) -- , state_change = true
    device:set_field(SIDE, side)
  end
  
  local reset_motion_status = function()
    device:emit_event(capabilities.motionSensor.motion.inactive())
    device:emit_event(capabilities.accelerationSensor.acceleration.inactive())
    device:emit_event(capabilities.tamperAlert.tamper.clear())
  end
  motion_reset_timer = device.thread:call_with_delay(2, reset_motion_status)
end

local function rotate_attr_handler(driver, device, value, zb_rx)
  local val = value.value -- between -180 and 180
  local delta = math.floor( val / 18 * 8) -- 80 percent for every 180*
  
  log.debug("rotate: ", val, " delta: ", delta)
  -- local min_sensivity = 10
  -- if val > min_sensivity then
  --   val = val - min_sensivity
  -- elseif val > -min_sensivity then
  --   val = val + min_sensivity
  -- end
  local level = device:get_field(CURRENT_LEVEL) or DEFAULT_LEVEL
  local new_level = utils.clamp_value( level + delta, 2, 100)
  generate_switch_level_event(device, new_level)
end

function set_level(_, device, command)
  local last_rotate = device:get_field(LEVEL_TS) or 0
  if os.time() - last_rotate < 5 then
    log.info("ignore dimmer loopback")
    return
  end

  device:emit_event(capabilities.switchLevel.level(command.args.level))
  device:set_field(CURRENT_LEVEL, value)
end

local do_refresh = function(self, device)
  added_handler(self, device)
end

local aqara_cube_driver_template = {
  supported_capabilities = {
    capabilities.button,
    capabilities.motionSensor,
    capabilities.accelerationSensor,
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
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = set_level
    }
  },
  use_defaults = false,
  zigbee_handlers = {
    global = {},
    cluster = {},
    attr = {
      [zcl_clusters.basic_id] = {
        [xiaomi_utils.attr_id] = xiaomi_utils.handler
      },
      [0x12] = {
        [0x0055] = cube_attr_handler
      }, 
      [0x0C] = {
        [0x0055] = rotate_attr_handler
      }
    }
  },
}

--defaults.register_for_default_handlers(aqara_cube_driver_template, aqara_cube_driver_template.supported_capabilities)
local aqara_cube = ZigbeeDriver("aqara_cube", aqara_cube_driver_template)
aqara_cube:run()
