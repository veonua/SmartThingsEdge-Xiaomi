local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"

local cube_cap = capabilities["winterdictionary35590.cube"]
local AnalogInput = clusters.AnalogInput

local mock_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("cube.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.sensor_cube.aqgl01",
      server_clusters = {
        clusters.PowerConfiguration.ID,
        AnalogInput.ID
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
  "Rotation should update both knob and dimmer values for automations",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, AnalogInput.attributes.PresentValue:build_test_attr_report(mock_device, 45) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.switchLevel.level(70))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", cube_cap.rotation(45))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.knob.rotateAmount(45, { state_change = true }))
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", cube_cap.rotation(0))
    }
  }
)

test.run_registered_tests()
