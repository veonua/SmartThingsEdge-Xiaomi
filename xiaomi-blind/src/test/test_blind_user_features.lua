local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"

local AnalogOutput = clusters.AnalogOutput

local mock_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("blind.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.curtain.acn002",
      server_clusters = { AnalogOutput.ID, clusters.PowerConfiguration.ID }
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
  "A fully open report should show the blind as open at 100 percent",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, AnalogOutput.attributes.PresentValue:build_test_attr_report(mock_device, 100) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.windowShadeLevel.shadeLevel({ value = 100 }))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.windowShade.windowShade.open())
    }
  }
)

test.register_message_test(
  "A closed report should show the blind as closed",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, AnalogOutput.attributes.PresentValue:build_test_attr_report(mock_device, 0) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.windowShadeLevel.shadeLevel({ value = 0 }))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.windowShade.windowShade.closed())
    }
  }
)

test.run_registered_tests()
