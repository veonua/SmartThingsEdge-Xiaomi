local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"

local AnalogInput = clusters.AnalogInput
local DeviceTemperatureConfiguration = clusters.DeviceTemperatureConfiguration

local mock_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("plug.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.plug.maus01",
      server_clusters = { clusters.OnOff.ID, DeviceTemperatureConfiguration.ID }
    },
    [2] = {
      id = 2,
      server_clusters = { AnalogInput.ID }
    },
    [3] = {
      id = 3,
      server_clusters = { AnalogInput.ID }
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
  "Power reports should show current watt draw",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, AnalogInput.attributes.PresentValue:build_test_attr_report(mock_device, 12.34):to_endpoint(2) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.powerMeter.power({ value = 12.34, unit = "W" }))
    }
  }
)

test.register_message_test(
  "Energy reports should show cumulative usage",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, AnalogInput.attributes.PresentValue:build_test_attr_report(mock_device, 45.67):to_endpoint(3) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.energyMeter.energy({ value = 45.67, unit = "Wh" }))
    }
  }
)

test.register_message_test(
  "Device temperature reports should be visible to the user",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = {
        mock_device.id,
        DeviceTemperatureConfiguration.attributes.CurrentTemperature:build_test_attr_report(mock_device, 38)
      }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.temperatureMeasurement.temperature({ value = 38, unit = "C" }))
    }
  }
)

test.run_registered_tests()
