local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"

local PRIVATE_CLUSTER_ID = 0xFCC0
local PRIVATE_ATTRIBUTE_ID = 0x0009
local PRIVATE_SWITCH_MODE_ATTR_ID = 0x0200
local MULTISTATE_INPUT_CLUSTER_ID = 0x0012
local MFG_CODE = 0x115F

local mock_device = test.mock_device.build_test_zigbee_device({
  label = "Aqara Z1 Pro",
  profile = t_utils.get_profile_definition("switch-neutral-button-3-main.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
        manufacturer = "Aqara",
        model = "lumi.switch.acn058",
        server_clusters = {
          clusters.OnOff.ID,
        MULTISTATE_INPUT_CLUSTER_ID,
        PRIVATE_CLUSTER_ID
      }
    },
    [2] = {
      id = 2,
      server_clusters = {
        clusters.OnOff.ID,
        MULTISTATE_INPUT_CLUSTER_ID,
        PRIVATE_CLUSTER_ID
      }
    },
    [3] = {
      id = 3,
      server_clusters = {
        clusters.OnOff.ID,
        MULTISTATE_INPUT_CLUSTER_ID,
        PRIVATE_CLUSTER_ID
      }
    }
  }
})

local function build_opple_write(attr_id, value, endpoint)
  local message = cluster_base.write_attribute(
    mock_device,
    data_types.ClusterId(PRIVATE_CLUSTER_ID),
    data_types.AttributeId(attr_id),
    data_types.Uint8(value)
  )
  message.body.zcl_header.frame_ctrl:set_mfg_specific()
  message.body.zcl_header.mfg_code = data_types.validate_or_build_type(MFG_CODE, data_types.Uint16, "mfg_code")
  return message:to_endpoint(endpoint)
end

zigbee_test_utils.prepare_zigbee_env_info()
local function expect_init_button_events()
  test.socket.capability:__expect_send(
    mock_device:generate_test_message("main", capabilities.button.supportedButtonValues({
      "pushed", "pushed_2x", "held"
    }))
  )
  test.socket.capability:__expect_send(
    mock_device:generate_test_message("main", capabilities.button.numberOfButtons({ value = 1 }))
  )
  test.socket.capability:__expect_send(
    mock_device:generate_test_message("group1", capabilities.button.supportedButtonValues({
      "pushed", "pushed_2x", "held"
    }))
  )
end

local function test_init()
  test.mock_device.add_test_device(mock_device)
  zigbee_test_utils.init_noop_health_check_timer()
  test.socket.capability:__set_channel_ordering("relaxed")
  expect_init_button_events()
end
test.set_test_init_function(test_init)

test.register_coroutine_test(
  "Adding Aqara Z1 Pro 3-gang should create the two relay children",
  function()
    mock_device:expect_device_create({
      type = "EDGE_CHILD",
      label = string.format("%s2", mock_device.label),
      profile = "aqara-switch-child",
      parent_device_id = mock_device.id,
      parent_assigned_child_key = "02"
    })
    mock_device:expect_device_create({
      type = "EDGE_CHILD",
      label = string.format("%s3", mock_device.label),
      profile = "aqara-switch-child",
      parent_device_id = mock_device.id,
      parent_assigned_child_key = "03"
    })

    test.socket.device_lifecycle:__queue_receive({ mock_device.id, "added" })
    test.socket.capability:__expect_send(
      mock_device:generate_test_message("main", capabilities.powerMeter.power({ value = 0.0, unit = "W" }))
    )
    test.socket.capability:__expect_send(
      mock_device:generate_test_message("main", capabilities.energyMeter.energy({ value = 0.0, unit = "Wh" }))
    )
    test.socket.zigbee:__expect_send({
      mock_device.id,
      cluster_base.write_manufacturer_specific_attribute(
        mock_device,
        PRIVATE_CLUSTER_ID,
        PRIVATE_ATTRIBUTE_ID,
        MFG_CODE,
        data_types.Uint8,
        0x01
      )
    })
  end
)

test.register_coroutine_test(
  "Detached button preferences should write the existing Opple relay mode attribute per endpoint",
  function()
    test.socket.zigbee:__set_channel_ordering("relaxed")
    test.socket.device_lifecycle:__queue_receive(mock_device:generate_info_changed({
      preferences = {
        button1 = "0xFE",
        button2 = "0x22",
        button3 = "0xFE"
      }
    }))

    test.socket.zigbee:__expect_send({ mock_device.id, build_opple_write(PRIVATE_SWITCH_MODE_ATTR_ID, 0, 1) })
    test.socket.zigbee:__expect_send({ mock_device.id, build_opple_write(PRIVATE_SWITCH_MODE_ATTR_ID, 0, 3) })
  end
)

test.run_registered_tests()
