local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"

local OnOff = clusters.OnOff
local MULTISTATE_INPUT_CLUSTER_ID = 0x0012
local WIRELESS_SWITCH_ATTRIBUTE_ID = 0x0055

local mock_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("button.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.remote.b1acn01",
      server_clusters = { OnOff.ID }
    }
  }
})

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device)
  zigbee_test_utils.init_noop_health_check_timer()
end
test.set_test_init_function(test_init)

test.register_coroutine_test(
  "Configure should request change-only multistate button reports",
  function()
    test.wait_for_events()
    test.socket.device_lifecycle:__queue_receive({ mock_device.id, "doConfigure" })
    test.socket.zigbee:__set_channel_ordering("relaxed")
    test.socket.zigbee:__expect_send({
      mock_device.id,
      cluster_base.configure_reporting(
        mock_device,
        data_types.ClusterId(MULTISTATE_INPUT_CLUSTER_ID),
        data_types.AttributeId(WIRELESS_SWITCH_ATTRIBUTE_ID),
        data_types.ZigbeeDataType(data_types.Uint16.ID),
        data_types.Uint16(0),
        data_types.Uint16(0xFFFF),
        data_types.Uint16(1)
      )
    })
  end
)

test.register_coroutine_test(
  "A single press should become a pushed button event",
  function()
    test.socket.zigbee:__queue_receive({ mock_device.id, OnOff.attributes.OnOff:build_test_attr_report(mock_device, true) })
    test.wait_for_events()
    test.mock_time.advance_time(1)
    test.socket.capability:__expect_send(
      mock_device:generate_test_message("main", capabilities.button.button.pushed({ state_change = true }))
    )
  end
)

test.run_registered_tests()
