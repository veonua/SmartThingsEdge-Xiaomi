local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local cluster_base = require "st.zigbee.cluster_base"
local log = require "log"
local OccupancySensing = clusters.OccupancySensing
local OnOff = clusters.OnOff
local PowerConfiguration = clusters.PowerConfiguration
local data_types = require "st.zigbee.data_types"

---
local device_management = require "st.zigbee.device_management"
local messages = require "st.zigbee.messages"
local mgmt_bind_resp = require "st.zigbee.zdo.mgmt_bind_response"
local zdo_messages = require "st.zigbee.zdo"
---

local OPPLE_CLUSTER = 0xFCC0

local ZIGBEE_LUMI_MOTION_SENSOR_FINGERPRINTS = {
    { mfr = "LUMI", model = "lumi.sensor_motion" },
    { mfr = "LUMI", model = "lumi.sensor_motion.aq2" },
    { mfr = "LUMI", model = "lumi.motion.agl04" }
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

  motion_reset_timer = device.thread:call_with_delay(62, reset_motion_status)
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

local function device_added(self, device)
  device:refresh()
end

local do_configure = function(self, device)
  device:send(cluster_base.write_manufacturer_specific_attribute(device, OPPLE_CLUSTER, 0x010c, 0x115F, data_types.Uint8, 1) )
  device:send(OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:write(device, 2))

  device:send(device_management.build_bind_request(device, PowerConfiguration.ID, self.environment_info.hub_zigbee_eui))
  device:send(device_management.build_bind_request(device, OccupancySensing.ID, self.environment_info.hub_zigbee_eui))
end

local do_refresh = function(self, device)
  -- do_configure(self, device)

  device:send(OccupancySensing.attributes.Occupancy:read(device))
  device:send(OccupancySensing.attributes.PIROccupiedToUnoccupiedDelay:read(device))
end

local lumi_motion_handler = {
  NAME = "LUMI Motion Handler",
  supported_capabilities = {
    capabilities.motionSensor,
    capabilities.illuminanceMeasurement,
    capabilities.battery,
    capabilities.refresh
  },
  zigbee_handlers = {
    attr = {
      [clusters.IASZone.ID] = {
        [0x0002] = ias_zone_status_change_handler
      },   
      [OccupancySensing.ID] = {
        [OccupancySensing.attributes.Occupancy.ID] = occupancy_attr_handler
      },
      [clusters.IlluminanceMeasurement.ID] = {
        [clusters.IlluminanceMeasurement.attributes.MeasuredValue.ID] = illuminance_attr_handler,
      },
    }
  },
  lifecycle_handlers = {
    added = device_added,
    doConfigure = do_configure
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = do_refresh,
    }
  },
  can_handle = is_zigbee_lumi_motion_sensor
}

return lumi_motion_handler
