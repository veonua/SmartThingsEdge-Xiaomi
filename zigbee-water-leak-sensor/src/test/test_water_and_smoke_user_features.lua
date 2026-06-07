local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"

local IASZone = clusters.IASZone
local ZoneStatusAttribute = IASZone.attributes.ZoneStatus

local water_sensor = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("water-battery.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.sensor_wleak.aq1",
      server_clusters = { IASZone.ID, clusters.PowerConfiguration.ID }
    }
  }
})

local smoke_sensor = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("smoke-battery.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.sensor_smoke",
      server_clusters = { IASZone.ID, clusters.PowerConfiguration.ID }
    }
  }
})

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(water_sensor)
  test.mock_device.add_test_device(smoke_sensor)
  zigbee_test_utils.init_noop_health_check_timer()
end
test.set_test_init_function(test_init)

test.register_message_test(
  "Leak sensors should show wet when water is detected",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { water_sensor.id, ZoneStatusAttribute:build_test_attr_report(water_sensor, 0x0001) }
    },
    {
      channel = "capability",
      direction = "send",
      message = water_sensor:generate_test_message("main", capabilities.waterSensor.water.wet())
    }
  }
)

test.register_message_test(
  "Leak sensors should show dry when the alert clears",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { water_sensor.id, ZoneStatusAttribute:build_test_attr_report(water_sensor, 0x0000) }
    },
    {
      channel = "capability",
      direction = "send",
      message = water_sensor:generate_test_message("main", capabilities.waterSensor.water.dry())
    }
  }
)

test.register_message_test(
  "Smoke sensors should show detected smoke in the app",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { smoke_sensor.id, ZoneStatusAttribute:build_test_attr_report(smoke_sensor, 0x0001) }
    },
    {
      channel = "capability",
      direction = "send",
      message = smoke_sensor:generate_test_message("main", capabilities.smokeDetector.smoke.detected())
    }
  }
)

test.register_message_test(
  "Smoke sensors should clear smoke alarms when the device clears",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { smoke_sensor.id, ZoneStatusAttribute:build_test_attr_report(smoke_sensor, 0x0000) }
    },
    {
      channel = "capability",
      direction = "send",
      message = smoke_sensor:generate_test_message("main", capabilities.smokeDetector.smoke.clear())
    }
  }
)

test.run_registered_tests()
