local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"

local MULTISTATE_INPUT_CLUSTER_ID = 0x0012
local WIRELESS_SWITCH_ATTRIBUTE_ID = 0x0055
local WIRELESS_SWITCH_ATTRIBUTE = {
  ID = WIRELESS_SWITCH_ATTRIBUTE_ID,
  NAME = "WirelessSwitch",
  base_type = data_types.Uint16,
  _cluster = { ID = MULTISTATE_INPUT_CLUSTER_ID }
}

local mock_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("button.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.remote.b1acn01",
      server_clusters = { MULTISTATE_INPUT_CLUSTER_ID }
    }
  }
})

local function expect_startup_button_metadata()
  test.socket.capability:__expect_send(
    mock_device:generate_test_message("main", capabilities.button.supportedButtonValues({
      "pushed", "held", "pushed_2x", "pushed_3x", "pushed_4x", "pushed_5x"
    }))
  )
  test.socket.capability:__expect_send(
    mock_device:generate_test_message("main", capabilities.button.numberOfButtons({ value = 1 }))
  )
end

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device)
  mock_device:set_field("first_switch_ep", 1, { persist = false })
  mock_device:set_field("first_button_ep", 1, { persist = false })
  zigbee_test_utils.init_noop_health_check_timer()
  test.socket.capability:__set_channel_ordering("relaxed")
  expect_startup_button_metadata()
end
test.set_test_init_function(test_init)

test.register_coroutine_test(
  "Init should advertise supported button values for the wireless switch",
  function()
    test.wait_for_events()
  end
)

test.register_coroutine_test(
  "A multistate input press should become a pushed button event",
  function()
    test.wait_for_events()
    test.socket.zigbee:__queue_receive({
      mock_device.id,
      cluster_base.build_test_attr_report(WIRELESS_SWITCH_ATTRIBUTE, mock_device, data_types.Uint16(1))
    })
    test.socket.capability:__expect_send(
      mock_device:generate_test_message("main", capabilities.button.button.pushed({ state_change = true }))
    )
  end
)

test.run_registered_tests()
