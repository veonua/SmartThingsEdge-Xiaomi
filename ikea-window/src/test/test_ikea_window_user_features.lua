local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"

local WindowCovering = clusters.WindowCovering
local OnOff = clusters.OnOff

local blind_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("blind.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "IKEA of Sweden",
      model = "FYRTUR block-out roller blind",
      server_clusters = { WindowCovering.ID, clusters.PowerConfiguration.ID }
    }
  }
})

local remote_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("five-buttons-battery.yaml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "IKEA of Sweden",
      model = "TRADFRI remote control",
      client_clusters = { OnOff.ID }
    }
  }
})

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(blind_device)
  test.mock_device.add_test_device(remote_device)
  zigbee_test_utils.init_noop_health_check_timer()
end
test.set_test_init_function(test_init)

test.register_message_test(
  "Blind position reports should show the blind as open",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = {
        blind_device.id,
        WindowCovering.attributes.CurrentPositionLiftPercentage:build_test_attr_report(blind_device, 0)
      }
    },
    {
      channel = "capability",
      direction = "send",
      message = blind_device:generate_test_message("main", capabilities.windowShade.windowShade.open())
    },
    {
      channel = "capability",
      direction = "send",
      message = blind_device:generate_test_message("main", capabilities.windowShadeLevel.shadeLevel(100))
    }
  }
)

test.register_message_test(
  "Remote open button presses should surface as button events",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { remote_device.id, OnOff.server.commands.On.build_test_rx(remote_device) }
    },
    {
      channel = "capability",
      direction = "send",
      message = remote_device:generate_test_message("button1", capabilities.button.button.pushed({ state_change = true }))
    }
  }
)

test.run_registered_tests()
