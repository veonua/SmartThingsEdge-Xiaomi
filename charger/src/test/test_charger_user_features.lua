local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"

local AnalogInput = clusters.AnalogInput

local mock_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("plug.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "ZNCZ11LM"
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
  "Charging power should mark the charger as actively charging",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, AnalogInput.attributes.PresentValue:build_test_attr_report(mock_device, 15.2):to_endpoint(2) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.powerMeter.power({ value = 15.2, unit = "W" }))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.robotCleanerMovement.robotCleanerMovement({ value = "charging" }))
    }
  }
)

test.register_message_test(
  "Very low power draw should show the charger as idle",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, AnalogInput.attributes.PresentValue:build_test_attr_report(mock_device, 1.5):to_endpoint(2) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.powerMeter.power({ value = 1.5, unit = "W" }))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.robotCleanerMovement.robotCleanerMovement({ value = "idle" }))
    }
  }
)

test.register_message_test(
  "Energy reports should show cumulative charged energy",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, AnalogInput.attributes.PresentValue:build_test_attr_report(mock_device, 123.4):to_endpoint(3) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.energyMeter.energy({ value = 123.4, unit = "Wh" }))
    }
  }
)

test.run_registered_tests()
