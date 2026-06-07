local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"

local TemperatureMeasurement = clusters.TemperatureMeasurement
local RelativeHumidity = clusters.RelativeHumidity
local PressureMeasurement = clusters.PressureMeasurement
local atmos_pressure = capabilities["legendabsolute60149.atmosPressure"]

local mock_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("temp-pressure.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.weather",
      server_clusters = {
        TemperatureMeasurement.ID,
        RelativeHumidity.ID,
        PressureMeasurement.ID
      }
    }
  }
})

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device)
  zigbee_test_utils.init_noop_health_check_timer()
end
test.set_test_init_function(test_init)

test.register_message_test(
  "Temperature reports should update temperature and clear alarms in the app",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, TemperatureMeasurement.attributes.MeasuredValue:build_test_attr_report(mock_device, 2150) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.temperatureMeasurement.temperature({ value = 21.5, unit = "C" }))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.temperatureAlarm.temperatureAlarm.cleared())
    }
  }
)

test.register_message_test(
  "High temperatures should raise a heat alarm",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, TemperatureMeasurement.attributes.MeasuredValue:build_test_attr_report(mock_device, 6500) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.temperatureMeasurement.temperature({ value = 65.0, unit = "C" }))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.temperatureAlarm.temperatureAlarm.heat())
    }
  }
)

test.register_message_test(
  "Humidity reports should update humidity in the app",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, RelativeHumidity.attributes.MeasuredValue:build_test_attr_report(mock_device, 4550) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.relativeHumidityMeasurement.humidity({ value = 45.5 }))
    }
  }
)

test.register_message_test(
  "Pressure reports should update both standard and custom pressure capabilities",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, PressureMeasurement.attributes.MeasuredValue:build_test_attr_report(mock_device, 1013) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.atmosphericPressureMeasurement.atmosphericPressure({ value = 101, unit = "kPa" }))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", atmos_pressure.atmosPressure(1013))
    }
  }
)

test.run_registered_tests()
