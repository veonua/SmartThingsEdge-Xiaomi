local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local log = require "log"
local xiaomi_utils = require "xiaomi_utils"

local side = 0
-- 0 : front (aqara face up)
-- 1 : right
-- 2 : top
-- 3 : back
-- 4 : left
-- 5 : bottom

local map_flip_attribute_to_capability = {
  [0] = capabilities.button.button.up,
  [1] = capabilities.button.button.up_2x,
  [2] = capabilities.button.button.up_3x,
  [3] = capabilities.button.button.up_4x,
  [4] = capabilities.button.button.up_5x,
  [5] = capabilities.button.button.up_6x
}

local map_slide_attribute_to_capability = {
  [0] = capabilities.button.button.pushed,
  [1] = capabilities.button.button.pushed_2x,
  [2] = capabilities.button.button.pushed_3x,
  [3] = capabilities.button.button.pushed_4x,
  [4] = capabilities.button.button.pushed_5x,
  [5] = capabilities.button.button.pushed_6x
}

local function added_handler(self, device)
  device:emit_event(capabilities.button.numberOfButtons({ value=6 }))
  device:emit_event(capabilities.button.supportedButtonValues(
    {"up", "up_2x", "up_3x", "up_4x", "up_5x", "up_6x",
     "pushed", "pushed_2x", "pushed_3x", "pushed_4x", "pushed_5x", "pushed_6x"}))

  local presets = {
    {id="0", name="front"}
  }

  device:emit_event(capabilities.mediaPresets.presets({ value = presets }))
end

local function cube_attr_handler(driver, device, value, zb_rx)
  local val = value.value 
  side = val & 0x7
  local action = (val >> 8) & 0xFF

  
  if action == 0x01 then
    device:emit_event(capabilities.motionSensor.motion.active())
    device:emit_event(map_slide_attribute_to_capability[side]({state_change = true}))
  elseif action == 0x02 then
    device:emit_event(capabilities.tamperAlert.tamper.detected())
  elseif action == 0x00 then
    local prev_side = (val >> 3) & 0x7 
    if side == prev_side and side == 0 then
      device:emit_event(capabilities.accelerationSensor.acceleration.active())
    else
      local flip_type = (val >> 6) & 0x3
      if flip_type == 1 then
        log.info("flip  90* " .. tostring(prev_side) .. ">" .. tostring(side))
      elseif flip_type == 2 then
        log.info("flip 180* " .. tostring(side))
      end

      device:emit_event(map_flip_attribute_to_capability[side]({state_change = true}))
    end
  end

  local reset_motion_status = function()
    device:emit_event(capabilities.motionSensor.motion.inactive())
    device:emit_event(capabilities.accelerationSensor.acceleration.inactive())
    device:emit_event(capabilities.tamperAlert.tamper.clear())
  end  
  motion_reset_timer = device.thread:call_with_delay(2, reset_motion_status)
end


local MOTION_RESET_TIMER = "motionResetTimer"


local function rotate_attr_handler(driver, device, value, zb_rx)
  local val = math.floor(value.value * 10) -- between -1800 and 1800
  log.info("rotate " .. tostring(val))

  device:emit_event(capabilities.threeAxis.threeAxis({value = {val, 0, 0}}))
  local motion_reset_timer = device:get_field(MOTION_RESET_TIMER)
  device:emit_event(capabilities.motionSensor.motion.active())

  if motion_reset_timer then
    device.thread:cancel_timer(motion_reset_timer)
    device:set_field(MOTION_RESET_TIMER, nil)
  end
  local reset_motion_status = function()
    device:emit_event(capabilities.motionSensor.motion.inactive())
  end
  motion_reset_timer = device.thread:call_with_delay(2, reset_motion_status)
  device:set_field(MOTION_RESET_TIMER, motion_reset_timer)
end


local aqara_cube_driver_template = {
  supported_capabilities = {
    capabilities.button,
    capabilities.motionSensor,
    capabilities.mediaPresets,    
    capabilities.accelerationSensor,
    capabilities.threeAxis,
    capabilities.battery,
    capabilities.temperatureAlarm,
  },
  lifecycle_handlers = {
    added = added_handler,
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

defaults.register_for_default_handlers(aqara_cube_driver_template, aqara_cube_driver_template.supported_capabilities)
local aqara_cube = ZigbeeDriver("aqara_cube", aqara_cube_driver_template)
aqara_cube:run()
