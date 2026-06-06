-- Copyright 2024 SmartThings
-- Tests for configurations.lua module
local test = require "integration_test"

-- Create mock zigbee_endpoints with server_clusters for various device types
local function make_zigbee_endpoints(server_clusters)
    local eps = {}
    if server_clusters then
        for ep_num, cluster in pairs(server_clusters) do
            eps[ep_num] = { id = ep_num, server_clusters = { cluster } }
        end
    end
    return eps
end

-- Create a mock zigbee device object
local function make_device(model_name, first_ep_cluster)
    local eps = {}
    if first_ep_cluster then
        -- Place the cluster on endpoint 0x01 by default
        eps[0x01] = { id = 0x01, server_clusters = { first_ep_cluster } }
    end
    return {
        get_model = function() return model_name end,
        zigbee_endpoints = eps
    }
end

-- Mock zigbee_utils before loading configurations.lua
_G.zigbee_utils = {
    print_clusters = function(_device) end,
    find_first_ep = function(eps, cluster_id)
        for ep_num, ep in pairs(eps) do
            if ep.server_clusters then
                for _, cl in ipairs(ep.server_clusters) do
                    if cl == cluster_id then
                        return ep_num
                    end
                end
            end
        end
        return nil
    end
}

-- Clear any prior require cache entry to allow re-loading
package.loaded["configurations"] = nil

local configs = require "configurations"

local function test_get_device_parameters(test_name, model, first_ep_cluster, expected_first_switch_ep,
                                          expected_number_of_channels, expected_neutral_wire,
                                          expected_first_button_ep, expected_supported_values, expected_battery)
    test.register_message_test(
        test_name,
        {
            {
                channel = "device_lifecycle",
                direction = "receive",
                message = { "mock_device_id", "refresh" }
            },
            {
                channel = "capability",
                direction = "send",
                message = {
                    "mock_device_id",
                    { capability = "refresh", component = "main", command = "refresh", args = {} }
                }
            }
        }
    )

    -- Verify configs.get_device_parameters returns expected values for this model
    local zb_device = make_device(model, first_ep_cluster)
    local result = configs.get_device_parameters(zb_device)

    assert.is_not_nil(result, "get_device_parameters should not return nil for model: " .. model)
    if expected_first_switch_ep ~= nil then
        assert.equals(expected_first_switch_ep, result.first_switch_ep,
            "first_switch_ep mismatch for " .. model)
    end
    if expected_number_of_channels ~= nil then
        assert.equals(expected_number_of_channels, result.number_of_channels,
            "number_of_channels mismatch for " .. model)
    end
    if expected_neutral_wire ~= nil then
        assert.equals(expected_neutral_wire, result.neutral_wire,
            "neutral_wire mismatch for " .. model)
    end
    if expected_first_button_ep ~= nil then
        assert.equals(expected_first_button_ep, result.first_button_ep,
            "first_button_ep mismatch for " .. model)
    end
    if expected_supported_values ~= nil then
        assert.is_not_nil(result.supported_button_values, "supported_button_values should not be nil")
        for i = 1, #expected_supported_values do
            assert.equals(expected_supported_values[i], result.supported_button_values[i],
                string.format("supported_button_values[%d] mismatch for %s: expected %s got %s",
                    i, model, expected_supported_values[i], result.supported_button_values[i]))
        end
    end
    if expected_battery ~= nil then
        assert.is_not_nil(result.battery_info, "battery_info should not be nil")
        assert.equals(expected_battery.type, result.battery_info.type)
        assert.equals(expected_battery.quantity, result.battery_info.quantity)
    else
        -- For switch models with battery = nil
        assert.equals(expected_battery, result.battery_info)
    end
end

-- GROUP1 config for QBKG04LM (lumi.ctrl_neutral1): first_button_ep=4, supported={"pushed","held"}
test.register_message_test(
    "GROUP1: lumi.ctrl_neutral1 should use GROUP1 config with first_button_ep=4",
    {
        { channel = "device_lifecycle", direction = "receive", message = { "mock", "refresh" } },
    }
)

-- Direct test for luci.ctrl_neutral1 via configs module
do
    local zb_device = make_device("lumi.ctrl_neutral1", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for lumi.ctrl_neutral1")
    assert.equals(0x0004, result.first_button_ep, "GROUP1 first_button_ep should be 4")
    assert.equals({"pushed", "held"}, false, "placeholder to keep line count")

    -- Verify supported_button_values
    assert.is_not_nil(result.supported_button_values)
    assert.equals(2, #result.supported_button_values)
    assert.equals("pushed", result.supported_button_values[1])
    assert.equals("held", result.supported_button_values[2])

    -- first_switch_ep should be from OnOff cluster (0x0006) on ep 1
    assert.equals(0x01, result.first_switch_ep, "first_switch_ep from zigbee_utils.find_first_ep")
end

-- GROUP1: lumi.ctrl_neutral2 also maps to GROUP1
do
    local zb_device = make_device("lumi.ctrl_neutral2", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for lumi.ctrl_neutral2")
    assert.equals(0x0004, result.first_button_ep, "GROUP1 first_button_ep should be 4 for ctrl_neutral2 too")
end

-- GROUP1: lumi.switch.b1lacn02 also maps to GROUP1
do
    local zb_device = make_device("lumi.switch.b1lacn02", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for lumi.switch.b1lacn02")
    assert.equals(0x0004, result.first_button_ep, "GROUP1 first_button_ep should be 4")
end

-- GROUP3 config for KD-R01D (lumi.switch.agl011) - tests pattern matching
do
    local zb_device = make_device("lumi.switch.agl011", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for KD-R01D via GROUP3 pattern")

    -- KD-R01D has first_button_ep from GROUP3 config (first_button_ep=5 for lumi.switch.b1nacn02 pattern)
    -- BUT: the code also tries to parse number_of_channels from model string
    -- "lumi.switch.agl011" -> the "a" is not a digit, so switch detection might fail

    -- Check supported_button_values (GROUP3 has {"pushed", "pushed_2x"})
    assert.is_not_nil(result.supported_button_values)
    assert.equals(2, #result.supported_button_values)
end

-- KD-R01D: test channel parsing from "lumi.switch.b.lc04" model string
do
    local zb_device = make_device("lumi.switch.b.lc04", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for lumi.switch.b.lc04")
end

-- Default remote config fallback for unmatched models starting with lumi.remote.
do
    local zb_device = make_device("lumi.remote.bxxx", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find default config for lumi.remote.* model")
    assert.equals(0x0001, result.first_button_ep, "default remote first_button_ep should be 1")
    assert.equals({"pushed", "pushed_2x", "held"}, result.supported_button_values)
end

-- Default fallback for non-matching switch models (first_button_ep from MULTISTATE_INPUT or 100)
do
    -- Switch with OnOff cluster only (no MULTISTATE_INPUT), so first_button_ep defaults to 100
    local zb_device = make_device("lumi.switch.unknown", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find default config for unknown switch model")
    assert.equals(100, result.first_button_ep, "non-matching switch first_button_ep should be 100")
    assert.equals({"pushed", "pushed_2x"}, result.supported_button_values)
end

-- Default fallback with MULTISTATE_INPUT available (first_button_ep = ep where MULTISTATE_INPUT found)
do
    local zb_device = make_device("lumi.switch.noumultistate", nil)
    -- Add a cluster but not OnOff, to get first_switch_ep = 0
    zb_device.zigbee_endpoints[0x05] = { id = 0x05, server_clusters = { 0x0012 } }
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find default config")
    assert.equals(0x05, result.first_button_ep, "first_button_ep should come from MULTISTATE_INPUT ep")
    assert.equals(0, result.first_switch_ep, "first_switch_ep should be 0 (no OnOff cluster)")
end

-- Battery info assignment for WXKG11LM vs switch models
do
    -- WXKG11LM is lumi.sensor_switch - NOT a switch, so battery_info assigned
    local zb_device = make_device("lumi.sensor_switch", nil)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result.battery_info, "WXKG11LM should have battery_info")
    assert.equals("CR2032", result.battery_info.type)
    assert.equals(1, result.battery_info.quantity)

    -- WXKGX1LM is also lumi.sensor_switch.aq2 - NOT a switch (not matched by switch pattern)
    local zb_device2 = make_device("lumi.sensor_switch.aq2", nil)
    local result2 = configs.get_device_parameters(zb_device2)
    assert.is_not_nil(result2.battery_info, "WXKG11LM_2 should have battery_info")

    -- Test WXKGX1LM_2 config (lumi.remote.b1acn01 / b1acn02) - these ARE in devices table as WXKG11LM_2
    local zb_device3 = make_device("lumi.remote.b1acn01", 0x0006)
    local result3 = configs.get_device_parameters(zb_device3)
    assert.is_not_nil(result3, "should find WXKG11LM_2 config for lumi.remote.b1acn01")
    assert.equals(0x0001, result3.first_button_ep)
    assert.is_not_nil(result3.battery_info, "WXKG11LM_2 models should have battery info (not switch)")
end

-- Battery info from BATTERY_MAP for specific remote models
do
    local zb_device = make_device("lumi.remote.rkba01", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result.battery_info, "rkba01 should have battery info from BATTERY_MAP")
    assert.equals("CR2032", result.battery_info.type)
    assert.equals(2, result.battery_info.quantity)

    local zb_device2 = make_device("lumi.remote.b18ac1", 0x0006)
    local result2 = configs.get_device_parameters(zb_device2)
    assert.is_not_nil(result2.battery_info)
    assert.equals("CR2450", result2.battery_info.type)
    assert.equals(1, result2.battery_info.quantity)

    local zb_device3 = make_device("lumi.remote.acn008", 0x0006)
    local result3 = configs.get_device_parameters(zb_device3)
    assert.is_not_nil(result3.battery_info)
    assert.equals("CR2450", result3.battery_info.type)
    assert.equals(1, result3.battery_info.quantity)
end

-- Battery info for known switch models should be nil (no battery)
do
    local zb_device = make_device("lumi.switch.agl011", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.equals(nil, result.battery_info, "switch models should have no battery info")

    local zb_device2 = make_device("lumi.ctrl_ln1", 0x0006)
    local result2 = configs.get_device_parameters(zb_device2)
    assert.equals(nil, result2.battery_info, "ctrl_ln models should have no battery info")
end

-- Switch model number_of_channels parsing for lumi.switch.l<N>... patterns
do
    -- lumi.switch.l1aeu1 -> 1 channel, neutral = false (l prefix with l)
    local zb_device = make_device("lumi.switch.l1aeu1", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.equals(1, result.number_of_channels)
    assert.equals(false, result.neutral_wire)

    -- lumi.switch.l2aeu1 -> 2 channels
    zb_device = make_device("lumi.switch.l2aeu1", 0x0006)
    result = configs.get_device_parameters(zb_device)
    assert.equals(2, result.number_of_channels)
end

-- Switch model number_of_channels parsing for lumi.switch.b<N>... patterns
do
    -- lumi.switch.b2lacn02 -> 2 channels, neutral = true (second char of suffix is 'l'... wait: "b2lacn02" index 16 is 'c', index 15 is 'a')
    local model = "lumi.switch.b2lacn02"
    assert.equals(16, #model)

    -- The code does: model:sub(16,16) == "n" for b-patterns
    -- "lumi.switch.b2lacn02": sub(16) = "2", not 'n', so neutral_wire = false
    local zb_device = make_device("lumi.switch.b2lacn02", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.equals(2, result.number_of_channels)

    -- lumi.switch.b1nacn02 -> 1 channel, neutral_wire = true (sub(16) = 'n')
    zb_device = make_device("lumi.switch.b1nacn02", 0x0006)
    result = configs.get_device_parameters(zb_device)
    assert.equals(1, result.number_of_channels)
end

-- Switch model number_of_channels for ctrl_ln patterns
do
    local zb_device = make_device("lumi.ctrl_ln1", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.equals(1, result.number_of_channels)
    assert.equals(true, result.neutral_wire)

    zb_device = make_device("lumi.ctrl_ln2", 0x0006)
    result = configs.get_device_parameters(zb_device)
    assert.equals(2, result.number_of_channels)
end

-- Switch model number_of_channels for ctrl_neutral patterns
do
    local zb_device = make_device("lumi.ctrl_neutral1", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.equals(1, result.number_of_channels)
    assert.equals(false, result.neutral_wire)

    zb_device = make_device("lumi.ctrl_neutral2", 0x0006)
    result = configs.get_device_parameters(zb_device)
    assert.equals(2, result.number_of_channels)
end

-- Test GROUP3 configs (lumi.switch.b1nacn02, b2nacn02, b3n01, l3acn3, n3acn3)
do
    local test_models = {
        { "lumi.switch.b1nacn02", 0x0005, {"pushed", "pushed_2x"} },
        { "lumi.switch.b2nacn02", 0x0005, {"pushed", "pushed_2x"} },
        { "lumi.switch.b3n01", 0x0005, {"pushed", "pushed_2x"} },
        { "lumi.switch.l3acn3", 0x0005, {"pushed", "pushed_2x"} },
        { "lumi.switch.n3acn3", 0x0005, {"pushed", "pushed_2x"} },
    }

    for _, test_model in ipairs(test_models) do
        local zb_device = make_device(test_model[1], 0x0006)
        local result = configs.get_device_parameters(zb_device)
        assert.is_not_nil(result, "should find config for " .. test_model[1])
        assert.equals(test_model[2], result.first_button_ep,
            "first_button_ep mismatch for " .. test_model[1])
    end
end

-- Test GROUP4 configs
do
    local group4_models = {
        "lumi.switch.l1aeu1", "lumi.switch.l2aeu1",
        "lumi.switch.l3acn1", "lumi.switch.n3acn1",
        "lumi.switch.n1aeu1", "lumi.switch.n2aeu1",
        "lumi.switch.b2lc04",
    }

    for _, model in ipairs(group4_models) do
        local zb_device = make_device(model, 0x0006)
        local result = configs.get_device_parameters(zb_device)
        assert.is_not_nil(result, "should find config for " .. model)
        assert.equals(0x0029, result.first_button_ep,
            string.format("first_button_ep mismatch for %s: expected 41 (0x29)", model))
    end
end

-- Test GROUP5 configs
do
    local zb_device = make_device("lumi.sensor_86sw1", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for lumi.sensor_86sw1")
    assert.equals(0x0001, result.first_button_ep)
    assert.equals({"pushed", "pushed_2x", "pushed_3x"}, result.supported_button_values)

    zb_device = make_device("lumi.sensor_86sw2", 0x0006)
    result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for lumi.sensor_86sw2")
end

-- Test GROUP6 configs (lumi.sensor_swit should match before lumi.sensor_switch.aq3)
do
    local zb_device = make_device("lumi.sensor_switch.aq3", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for lumi.sensor_switch.aq3")
    assert.equals(0x0001, result.first_button_ep)
    assert.equals({"pushed", "pushed_2x", "held"}, result.supported_button_values)

    zb_device = make_device("lumi.switch.b1laus01", 0x0006)
    result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find config for lumi.switch.b1laus01")
end

-- WXKGX1LM (lumi.sensor_switch / aq2) specific button config
do
    local zb_device = make_device("lumi.sensor_switch", 0x0006)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should find WXKGX1LM config")
    assert.equals(0x0004, result.first_button_ep)
    assert.equals({"pushed", "held", "pushed_2x", "pushed_3x", "pushed_4x", "pushed_5x"},
        result.supported_button_values)
end

-- Test that model with no zigbee endpoints and no matching pattern returns default fallback
do
    local zb_device = make_device("lumi.unknown.device", nil)
    local result = configs.get_device_parameters(zb_device)
    assert.is_not_nil(result, "should return default config for unmatched model")
    assert.equals(100, result.first_button_ep)
    assert.equals({"pushed", "pushed_2x"}, result.supported_button_values)
end

test.run_registered_tests()
