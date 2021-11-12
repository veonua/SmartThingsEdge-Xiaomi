local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local log = require "log"


local ZIGBEE_LUMI_MOTION_SENSOR_FINGERPRINTS = {
    { mfr = "LUMI", model = "lumi.sensor_motion" },
    { mfr = "LUMI", model = "lumi.sensor_motion.aq2" }
}
local MOTION_RESET_TIMER = "motionResetTimer"


local is_zigbee_lumi_motion_sensor = function(opts, driver, device)
  for _, fingerprint in ipairs(ZIGBEE_LUMI_MOTION_SENSOR_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
        return true
      end
  end
  return true
end



local function occupancy_attr_handler(driver, device, occupancy, zb_rx)
  log.debug("occupancy_attr_handler " .. tostring(occupancy))

  local motion_reset_timer = device:get_field(MOTION_RESET_TIMER)
  device:emit_event(capabilities.motionSensor.motion.active())

  if motion_reset_timer then
    log.debug("reset")
    device.thread:cancel_timer(motion_reset_timer)
    device:set_field(MOTION_RESET_TIMER, nil)
  end
  local reset_motion_status = function()
    log.debug("no motion")
    device:emit_event(capabilities.motionSensor.motion.inactive())
  end

  motion_reset_timer = device.thread:call_with_delay(61, reset_motion_status)
  device:set_field(MOTION_RESET_TIMER, motion_reset_timer)
end


local function ias_zone_status_change_handler(driver, device, zone_status, zigbee_message)
  -- never happens
  log.warn("ias_zone_status_change_handler " .. tostring(zone_status))

  device:emit_event_for_endpoint(
      zigbee_message.address_header.src_endpoint.value,
      (zone_status:is_alarm1_set() or zone_status:is_alarm2_set()) and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())
end


local function illuminance_attr_handler(driver, device, value, zb_rx)
  local lux_value = value.value --math.floor(10 ^ ((value.value - 1) / 10000))
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(lux_value))
end


local lumi_motion_handler = {
  NAME = "LUMI Motion Handler",
  use_defaults = false,
  zigbee_handlers = {
    attr = {
      [clusters.IASZone.ID] = {
        [0x0002] = ias_zone_status_change_handler
      },   
      [clusters.OccupancySensing.ID] = {
        [clusters.OccupancySensing.attributes.Occupancy.ID] = occupancy_attr_handler
      },
      [clusters.IlluminanceMeasurement.ID] = {
        [clusters.IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_attr_handler,
      },
    }
  },

  can_handle = is_zigbee_lumi_motion_sensor
}

return lumi_motion_handler
