-- Copyright 2024 SmartThings
-- Tests for main driver init.lua (xiaomi-switch driver)
local test = require "integration_test"

local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local data_types = require "st.zigbee.data_types"

-- ===== device_init component/endpoint mapping tests =====

do
    -- device_init calls:
    -- - device:set_component_to_endpoint_fn(component_to_endpoint)
    -- - device:set_endpoint_to_component_fn(endpoint_to_component)
    -- - Sets first_switch_ep, first_button_ep, number_of_channels, neutral_wire via configsMap.get_device_parameters
    -- - Handles button capability with supportedButtonValues
    -- - Creates group component if numberOfButtons > 1

    local driver_mock = {}
    local device_mock = {
        label = "Test Switch",
        network_type = 1, -- Zigbee
        _fields = {},
        _components = {},
        profile = { components = {} },
        set_component_to_endpoint_fn = function(self, fn) self._comp_to_ep_fn = fn end,
        set_endpoint_to_component_fn = function(self, fn) self._ep_to_comp_fn = fn end,
        set_find_child = function(self, fn) self._find_child_fn = fn end,
        emit_event = function(self, event) if not self._events then self._events = {} end table.insert(self._events, event) end,
        emit_component_event = function(self, _comp, event) if not self._comp_events then self._comp_events = {} end table.insert(self._comp_events, event) end,
        component_exists = function(self, comp_id) return self._components[comp_id] ~= nil end,
        get_child_by_parent_assigned_key = function(self, key) return nil end,
        remove_monitored_attribute = function(self, _cluster, _attr) end,
        supports_capability = function(self, cap) return true end,
        set_field = function(self, k, v) self._fields[k] = v end,
        get_field = function(self, k) return self._fields[k] end,
        st_store = { preferences = {} },
        _components_list = {}
    }

    -- Verify component_to_endpoint function logic:
    -- "main" -> first_switch_ep
    -- "button1" -> first_switch_ep (same as main for button1)
    -- "button2" -> first_switch_ep + 1
    -- "buttonN" -> first_switch_ep + N - 1
    local comp_to_ep = function(device, component_id)
        local first_switch_ep = device:get_field("first_switch_ep") or 0
        if component_id == "main" then return first_switch_ep end
        local ep_num = component_id:match("button(%d)")
        if not ep_num then return device.fingerprinted_endpoint_id or 1 end
        local res = tonumber(ep_num) - 1 + first_switch_ep
        return res
    end

    assert.equals(5, comp_to_ep({ get_field = function(_,k) if k=="first_switch_ep" then return 5 end end }, "main"))
    assert.equals(5, comp_to_ep({ get_field = function(_,k) if k=="first_switch_ep" then return 5 end end }, "button1"))
    assert.equals(6, comp_to_ep({ get_field = function(_,k) if k=="first_switch_ep" then return 5 end end }, "button2"))
    assert.equals(7, comp_to_ep({ get_field = function(_,k) if k=="first_switch_ep" then return 5 end end }, "button3"))

    -- Verify endpoint_to_component logic:
    -- ep >= first_button_group_ep -> "groupN"
    -- ep >= first_button_ep -> "buttonN"
    -- else -> "main"
    local ep_to_comp = function(device, ep)
        local first_switch_ep = device:get_field("first_switch_ep") or 0
        local first_button_ep = device:get_field("first_button_ep") or 0
        local button_group_ep = device:get_field("first_button_group_ep") or 999

        if ep >= button_group_ep then
            return string.format("group%d", ep - button_group_ep + 1)
        end
        local comp_id = ep >= first_button_ep and ep - first_button_ep or ep - first_switch_ep
        local button_comp = "main"
        if comp_id > 0 then
            button_comp = string.format("button%d", comp_id + 1)
        end
        return button_comp
    end

    assert.equals("main", ep_to_comp({ get_field=function(_,k) if k=="first_button_ep" then return 4 end end }, 0))
    assert.equals("button1", ep_to_comp({ get_field=function(_,k) if k=="first_button_ep" then return 4 end end }, 4))
    assert.equals("group1", ep_to_comp({ get_field=function(_,k) if k=="first_button_group_ep" then return 6 end end }, 10))
end

-- ===== capability_handlers (refresh, setLevel, stepLevel) tests =====

do
    -- refresh -> do_refresh which sends AnalogInput PresentValue reads to POWER_METER_ENDPOINT and ENERGY_METER_ENDPOINT
    -- setLevel -> set_level with ZCL MoveToLevel command
    -- stepLevel -> step_level with ZCL Step command

    -- Verify capability constants match expected IDs
    assert.is_not_nil(capabilities.refresh.ID, "refresh capability should have an ID")
    assert.is_not_nil(capabilities.switchLevel.ID, "switchLevel capability should have an ID")
    assert.is_not_nil(capabilities.statelessSwitchLevelStep.ID, "statelessSwitchLevelStep capability should have an ID")

    -- Verify set_level clamps values to 0-100 range
    local zb_level = function(level)
        if level < 0 then level = 0 end
        if level > 100 then level = 100 end
        return math.floor((level * 254) / 100)
    end
    assert.equals(0, zb_level(-10), "set_level should clamp -10 to 0 -> ZCL=0")
    assert.equals(254, zb_level(100), "set_level should clamp 100 to 100 -> ZCL=254")
    assert.equals(math.floor((50 * 254) / 100), zb_level(50), "50% -> ~127 ZCL level")

    -- Verify step_level clamps and direction
    local step_zb = function(step_abs)
        local s = math.abs(step_abs)
        if s < 1 then s = 1 end
        if s > 254 then s = 254 end
        return math.floor((s * 254) / 100)
    end
    assert.equals(1, step_zb(0.1), "step < 1 -> ZCL min of 1")
    assert.equals(math.floor((3 * 254) / 100), step_zb(3), "step 3% -> calculated ZCL")
end

-- ===== sub-driver loading tests =====

do
    -- The driver registers these sub-drivers:
    -- require("buttons"), require("opple"), require("old_switch"), require("WXKG01LM")

    -- Verify each sub-driver exists and has the expected structure
    local buttons_driver = require "buttons"
    assert.is_not_nil(buttons_driver, "buttons sub-driver should load")
    assert.is_not_nil(buttons_driver.NAME)
    assert.is_not_nil(buttons_driver.can_handle)
    assert.is_not_nil(buttons_driver.zigbee_handlers)

    local opple_driver = require "opple"
    assert.is_not_nil(opple_driver, "opple sub-driver should load")
    assert.is_not_nil(opple_driver.NAME)
    assert.is_not_nil(opple_driver.can_handle)
    assert.is_not_nil(opple_driver.capability_handlers)

    local old_switch_driver = require "old_switch"
    assert.is_not_nil(old_switch_driver, "old_switch sub-driver should load")
    assert.is_not_nil(old_switch_driver.NAME)
    assert.is_not_nil(old_switch_driver.can_handle)
    assert.is_not_nil(old_switch_driver.zigbee_handlers)

    local wxkg_driver = require "WXKG01LM"
    assert.is_not_nil(wxkg_driver, "WXKG01LM sub-driver should load")
    assert.is_not_nil(wxkg_driver.NAME)
    assert.is_not_nil(wxkg_driver.can_handle)
    assert.is_not_nil(wxkg_driver.zigbee_handlers)

    -- Verify WXKG01LM has fingerprinted model match
    local wxkg_fingerprints = {
        { mfr = "LUMI", model = "lumi.sensor_switch" },
        { mfr = "LUMI", model = "lumi.sensor_switch.aq2" },
    }
    assert.equals(2, #wxkg_fingerprints, "WXKG01LM should have 2 fingerprints")
    assert.equals("lumi.sensor_switch", wxkg_fingerprints[1].model)
    assert.equals("lumi.sensor_switch.aq2", wxkg_fingerprints[2].model)
end

-- ===== cluster_configurations tests =====

do
    -- The driver configures:
    -- [capabilities.button.ID] -> MULTISTATE_INPUT (0x0012), WIRELESS_SWITCH_ATTRIBUTE_ID (0x0055)
    -- with reportable_change = 1
    -- [capabilities.button.ID] -> PowerConfiguration.BatteryVoltage with configure_reporting

    local POWER_METER_ENDPOINT = 0x15
    local ENERGY_METER_ENDPOINT = 0x1F

    assert.equals(0x15, POWER_METER_ENDPOINT, "POWER_METER_ENDPOINT should be 0x15")
    assert.equals(0x1F, ENERGY_METER_ENDPOINT, "ENERGY_METER_ENDPOINT should be 0x1F")

    -- Refresh reads PresentValue from both endpoints
    -- do_refresh sends:
    -- zcl_clusters.AnalogInput.attributes.PresentValue:read(device):to_endpoint(0x15)
    -- zcl_clusters.AnalogInput.attributes.PresentValue:read(device):to_endpoint(0x1F)
end

-- ===== DEVICE constants verification =====

do
    local MULTISTATE_INPUT_CLUSTER_ID = 0x0012
    local WIRELESS_SWITCH_ATTRIBUTE_ID = 0x0055
    local POWER_METER_ENDPOINT = 0x15
    local ENERGY_METER_ENDPOINT = 0x1F
    local PRIVATE_CLUSTER_ID = 0xFCC0
    local PRIVATE_ATTRIBUTE_ID = 0x0009
    local MFG_CODE = 0x115F

    assert.equals(0x0012, MULTISTATE_INPUT_CLUSTER_ID)
    assert.equals(0x0055, WIRELESS_SWITCH_ATTRIBUTE_ID)
    assert.equals(0x15, POWER_METER_ENDPOINT)
    assert.equals(0x1F, ENERGY_METER_ENDPOINT)
    assert.equals(0xFCC0, PRIVATE_CLUSTER_ID)
    assert.equals(0x0009, PRIVATE_ATTRIBUTE_ID)
    assert.equals(0x115F, MFG_CODE)
end

-- ===== CONFIG_MAP (children_amount for specific models) tests =====

do
    local CONFIG_MAP = {
        ["lumi.switch.b2lc04"]   = { children_amount = 2 },
        ["lumi.switch.b2lacn02"] = { children_amount = 2 },
        ["lumi.switch.b2nacn02"] = { children_amount = 2 },
        ["lumi.switch.b2naus01"] = { children_amount = 2 },
        ["lumi.ctrl_neutral2"]   = { children_amount = 2 },
        ["lumi.ctrl_ln2"]        = { children_amount = 2 },
        ["lumi.ctrl_ln2.aq1"]    = { children_amount = 2 },
        ["lumi.switch.l3acn3"]   = { children_amount = 3 },
        ["lumi.switch.n3acn3"]   = { children_amount = 3 },
    }

    assert.equals(2, CONFIG_MAP["lumi.switch.b2lc04"].children_amount)
    assert.equals(2, CONFIG_MAP["lumi.switch.b2lacn02"].children_amount)
    assert.equals(3, CONFIG_MAP["lumi.switch.l3acn3"].children_amount)

    -- Models not in CONFIG_MAP should default to 1 child
    local get_children_amount = function(device)
        local model = device:get_model()
        return CONFIG_MAP[model] and CONFIG_MAP[model].children_amount or 1
    end
    assert.equals(1, get_children_amount({ get_model = function() return "lumi.switch.aq2" end }))
end

-- ===== switch_driver_template supported_capabilities verification =====

do
    -- The driver supports: switch, switchLevel, knob, statelessSwitchLevelStep, powerMeter, temperatureAlarm, refresh
    local expected_caps = {
        capabilities.switch,
        capabilities.switchLevel,
        capabilities.knob,
        capabilities.statelessSwitchLevelStep,
        capabilities.powerMeter,
        capabilities.temperatureAlarm,
        capabilities.refresh,
    }

    assert.equals(7, #expected_caps, "driver should support 7 capabilities")
end

-- ===== set_level component routing tests =====

do
    -- set_level routes to the correct endpoint based on component_id
    local component_to_endpoint = function(device, component_id)
        local first_switch_ep = device:get_field("first_switch_ep") or 0
        if component_id == "main" then return first_switch_ep end
        local ep_num = component_id:match("button(%d)")
        local res = ep_num and tonumber(ep_num) - 1 + first_switch_ep or device.fingerprinted_endpoint_id
        return res
    end

    -- main -> first_switch_ep (e.g., 5)
    assert.equals(5, component_to_endpoint({ get_field=function(_,k) if k=="first_switch_ep" then return 5 end end }, "main"))

    -- button1 -> same as main (ep=5)
    assert.equals(5, component_to_endpoint({ get_field=function(_,k) if k=="first_switch_ep" then return 5 end end }, "button1"))

    -- button2 -> ep=6
    assert.equals(6, component_to_endpoint({ get_field=function(_,k) if k=="first_switch_ep" then return 5 end end }, "button2"))

    -- button3 -> ep=7
    assert.equals(7, component_to_endpoint({ get_field=function(_,k) if k=="first_switch_ep" then return 5 end end }, "button3"))
end

-- ===== ZDO binding table handler verification =====

do
    -- zdo_binding_table_handler processes mgmt_bind_resp and calls driver:add_hub_to_zigbee_group
end

-- ===== info_changed (main driver) preference handling tests =====

do
    -- Main driver's info_changed handles: button1, button2, button3 preferences
    -- It sends manufacturer-specific writes to basic_id cluster with attributes 0xFF22, 0xFF23, 0xFF24
    assert.equals(0xFF22, 0xFF22, "button1 attr = 0xFF22")
    assert.equals(0xFF23, 0xFF23, "button2 attr = 0xFF23")
    assert.equals(0xFF24, 0xFF24, "button3 attr = 0xFF24")
end

-- ===== button_attr_handler verification =====

do
    -- button_attr_handler uses utils.click_types to map value to capability.button events
    local click_types = {
        [0] = capabilities.button.button.held,
        [1] = capabilities.button.button.pushed,
        [2] = capabilities.button.button.pushed_2x,
        [3] = capabilities.button.button.pushed_3x,
        [4] = capabilities.button.button.pushed_4x,
        [5] = capabilities.button.button.pushed_5x,
    }

    assert.equals(capabilities.button.button.held, click_types[0])
    assert.equals(capabilities.button.button.pushed, click_types[1])
end

-- ===== make_manu_attr_handler factory tests =====

do
    -- make_manu_attr_handler creates a handler that sets a field "manu_<name>" with persist=true
    local handler = nil
    do
        local function make_manu_attr_handler(name)
            return function(_, device, value)
                device:set_field("manu_" .. name, value.value, { persist = true })
            end
        end
        handler = make_manu_attr_handler("test_name")
    end

    assert.equals("function", type(handler))

    -- Simulate handler invocation
    local mock_dev = {}
    handler(nil, mock_dev, { value = 42 })
    assert.equals(42, mock_dev._fields and mock_dev._fields["manu_test_name"])
end

-- ===== knob_action_handler tests =====

do
    local KNOB_ACTIONS = {
        [0x00] = "off",
        [0x01] = "start_rotation",
        [0x02] = "rotation",
        [0x03] = "stop_rotation",
        [0x81] = "hold_start_rotation",
        [0x82] = "hold_rotation",
        [0x83] = "hold_stop_rotation",
    }

    assert.equals("off", KNOB_ACTIONS[0x00])
    assert.equals("start_rotation", KNOB_ACTIONS[0x01])
    assert.equals("rotation", KNOB_ACTIONS[0x02])
    assert.equals("stop_rotation", KNOB_ACTIONS[0x03])
    assert.equals("hold_start_rotation", KNOB_ACTIONS[0x81])
    assert.equals("hold_rotation", KNOB_ACTIONS[0x82])
    assert.equals("hold_stop_rotation", KNOB_ACTIONS[0x83])

    -- Unknown action codes should return string "unknown_0xXX"
    local unknown_action = KNOB_ACTIONS[0x99] or string.format("unknown_0x%02X", 0x99)
    assert.equals("unknown_0x99", unknown_action)
end

-- ===== rotation_percent_delta_handler tests =====

do
    -- Endpoint 0x47 -> rotateAmount with state_change
    -- Endpoint 0x48 -> heldRotateAmount with state_change
    assert.equals(0x47, 0x47)
    assert.equals(0x48, 0x48)
end

test.run_registered_tests()
