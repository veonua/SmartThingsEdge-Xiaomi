-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"
local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local log = require "log"


local ZIGBEE_LUMI_MOTION_SENSOR_FINGERPRINTS = {
    { mfr = "LUMI", model = "lumi.sensor_motion" },
    { mfr = "LUMI", model = "lumi.sensor_motion.aq2" }
}


local is_zigbee_lumi_motion_sensor = function(opts, driver, device)
  for _, fingerprint in ipairs(ZIGBEE_LUMI_MOTION_SENSOR_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
          return true
      end
  end
  return true
end


local MOTION_RESET_TIMER = "motionResetTimer"

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
  motion_reset_timer = device.thread:call_with_delay(60, reset_motion_status)
  device:set_field(MOTION_RESET_TIMER, motion_reset_timer)
end


local function ias_zone_status_change_handler(driver, device, zone_status, zigbee_message)
  -- never happens
  log.debug("ias_zone_status_change_handler " .. tostring(zone_status))

  device:emit_event_for_endpoint(
      zigbee_message.address_header.src_endpoint.value,
      (zone_status:is_alarm1_set() or zone_status:is_alarm2_set()) and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())
end


local function illuminance_attr_handler(driver, device, value, zb_rx)
  log.debug("illuminance_attr_handler " .. tostring(value))

  local lux_value = value.value --math.floor(10 ^ ((value.value - 1) / 10000))
  device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, capabilities.illuminanceMeasurement.illuminance(lux_value))
end

local function xiaomi_attr_handler(driver, device, value, zb_rx)
  log.debug("xiaomi_attr_handler " .. tostring(value))
  device:emit_event(capabilities.battery.battery(55))
end
--- <ZigbeeDevice: 25931f2c-e1d6-4a73-9786-2209b583f13a [0x03BD] (Living room Sensor)> received Zigbee message: < ZigbeeMessageRx || type: 0x00, < AddressHeader || src_addr: 0x03BD, src_endpoint: 0x01, dest_addr: 0x0000, dest_endpoint: 0x01, profile: 0x0104, cluster: Basic >, lqi: 0xCC, rssi: -49, body_length: 0x0044, < ZCLMessageBody || < ZCLHeader || frame_ctrl: 0x1C, mfg_code: 0x115F, seqno: 0x02, ZCLCommandId: 0x0A >, < ReportAttribute || < AttributeRecord || AttributeId: 0x0005, DataType: CharString, ModelIdentifier: "lumi.sensor_motion.aq2" >, 
---                                                                                                                                                                                                                                                                                                                                                                                                                                                            < AttributeRecord || AttributeId: 0xFF01, DataType: CharString, CharString: "\x01\x21\xBD\x0B\x03\x28\x1C\x04\x21\xA8\x31\x05\x21\xAC\x00\x06\x24\x01\x00\x00\x00\x00\x0A\x21\x00\x00\x64\x10\x00\x0B\x21\xC8\x01" > > > >
--  <ZigbeeDevice: 25931f2c-e1d6-4a73-9786-2209b583f13a [0x03BD] (Living room Sensor)> received Zigbee message: < ZigbeeMessageRx || type: 0x00, < AddressHeader || src_addr: 0x03BD, src_endpoint: 0x01, dest_addr: 0x0000, dest_endpoint: 0x01, profile: 0x0104, cluster: Basic >, lqi: 0xB8, rssi: -54, body_length: 0x001D, < ZCLMessageBody || < ZCLHeader || frame_ctrl: 0x18, seqno: 0x06,                   ZCLCommandId: 0x0A >, < ReportAttribute || < AttributeRecord || AttributeId: 0x0005, DataType: CharString, ModelIdentifier: "lumi.sensor_motion.aq2" > > > >


local lumi_motion_handler = {
  NAME = "LUMI Motion Handler",
  --lifecycle_handlers = {
  --  init = battery_defaults.build_linear_voltage_init(2.1, 3.0)
  --},
  zigbee_handlers = {
    attr = {
      [clusters.Basic.ID] = {
        [0xFF01] = xiaomi_attr_handler
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

