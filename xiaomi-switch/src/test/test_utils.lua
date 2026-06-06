-- Copyright 2024 SmartThings
-- Tests for utils.lua module
local test = require "integration_test"

-- Create a minimal mock device that satisfies the utils module expectations
local function make_mock_device(fields)
    local fields_table = fields or {}
    return {
        get_field = function(_, name)
            return fields_table[name]
        end,
        set_field = function(_, name, value, opts)
            fields_table[name] = value
        end,
        emit_event_for_endpoint = function(self, ep, event)
            if not self._events then self._events = {} end
            if not self._events[ep] then self._events[ep] = {} end
            table.insert(self._events[ep], event)
        end,
        preferences = {},
        get_model = function() return "lumi.test.device" end,
        _field_data = fields_table,
        thread = {
            call_with_delay = function(...) return nil end
        }
    }
end

-- Load utils (may already be loaded in the test environment)
local utils = require "utils"

-- ===== Click types table tests =====

do
    -- Verify click_types mapping: value 0 -> held, 1 -> pushed, etc.
    local cap_button = require "st.capabilities"

    assert.equals(cap_button.button.held, utils.click_types[0],
        "click_types[0] should map to capabilities.button.button.held")
    assert.equals(cap_button.button.pushed, utils.click_types[1],
        "click_types[1] should map to capabilities.button.button.pushed")
    assert.equals(cap_button.button.pushed_2x, utils.click_types[2],
        "click_types[2] should map to capabilities.button.button.pushed_2x")
    assert.equals(cap_button.button.pushed_3x, utils.click_types[3],
        "click_types[3] should map to capabilities.button.button.pushed_3x")
    assert.equals(cap_button.button.pushed_4x, utils.click_types[4],
        "click_types[4] should map to capabilities.button.button.pushed_4x")
    assert.equals(cap_button.button.pushed_5x, utils.click_types[5],
        "click_types[5] should map to capabilities.button.button.pushed_5x")

    -- Verify extended click types
    assert.equals(cap_button.button.held, utils.click_types[0x10],
        "click_types[0x10] should map to held")
    assert.equals(nil, utils.click_types[0x11],
        "click_types[0x11] (released) should be nil")
    assert.equals(nil, utils.click_types[0xff],
        "click_types[0xff] should be nil")

    -- Verify no entry for value 6+ (beyond the defined range)
    assert.equals(nil, utils.click_types[6],
        "click_types[6] should be nil (no such button type)")
end

-- ===== first_switch_ep tests =====

do
    -- When get_field returns a value
    local dev = make_mock_device({ first_switch_ep = 0x05 })
    assert.equals(0x05, utils.first_switch_ep(dev),
        "first_switch_ep should return the stored field value")

    -- When get_field returns nil (default to 0)
    local dev2 = make_mock_device(nil)
    assert.equals(0, utils.first_switch_ep(dev2),
        "first_switch_ep should default to 0 when field not set")

    -- When get_field returns explicit 0
    local dev3 = make_mock_device({ first_switch_ep = 0 })
    assert.equals(0, utils.first_switch_ep(dev3),
        "first_switch_ep should return 0 when stored as 0")
end

-- ===== first_button_ep tests =====

do
    -- When get_field returns a value
    local dev = make_mock_device({ first_button_ep = 0x04 })
    assert.equals(0x04, utils.first_button_ep(dev),
        "first_button_ep should return the stored field value")

    -- When get_field returns nil (default to 0)
    local dev2 = make_mock_device(nil)
    assert.equals(0, utils.first_button_ep(dev2),
        "first_button_ep should default to 0 when field not set")
end

-- ===== first_button_group_ep tests =====

do
    -- When get_field returns a value
    local dev = make_mock_device({ first_button_group_ep = 10 })
    assert.equals(10, utils.first_button_group_ep(dev),
        "first_button_group_ep should return the stored field value")

    -- When get_field returns nil (default to 999)
    local dev2 = make_mock_device(nil)
    assert.equals(999, utils.first_button_group_ep(dev2),
        "first_button_group_ep should default to 999 when field not set")
end

-- ===== emit_button_event tests =====

do
    local cap_button = require "st.capabilities"
    local test_event = cap_button.button.pushed({state_change = true})

    -- splitEvents = '1': broadcast to all buttons in group
    do
        local dev = make_mock_device({
            first_button_ep = 0x04,
            first_button_group_ep = 0x06  -- ep 4 and 5 are button eps
        })
        dev.preferences['splitEvents'] = '1'

        utils.emit_button_event(dev, 0x04, test_event)

        assert.is_not_nil(dev._events[0x04], "endpoint 0x04 should receive event when splitEvents='1'")
        assert.is_not_nil(dev._events[0x05], "endpoint 0x05 should also receive event when splitEvents='1'")
    end

    -- splitEvents = '0': emit only to single endpoint (ep < first_button_group_ep)
    do
        local dev = make_mock_device({
            first_button_ep = 0x04,
            first_button_group_ep = 0x06
        })
        dev.preferences['splitEvents'] = '0'

        utils.emit_button_event(dev, 0x04, test_event)

        assert.is_not_nil(dev._events[0x04], "endpoint 0x04 should receive event when ep < group_ep")
        assert.equals(nil, dev._events[0x05] and #dev._events[0x05],
            "only endpoint 0x04 should get the event for splitEvents='0' with matching endpoint")
    end

    -- When ep >= first_button_group_ep (ep=10): iterate from first_button_ep to group_ep-1
    do
        local dev = make_mock_device({
            first_button_ep = 0x04,
            first_button_group_ep = 0x06
        })
        dev.preferences['splitEvents'] = '0'

        utils.emit_button_event(dev, 0x0A, test_event)  -- ep=10 >= group_ep=6

        assert.is_not_nil(dev._events[0x04], "endpoint 0x04 should receive event (iteration start)")
        assert.is_not_nil(dev._events[0x05], "endpoint 0x05 should receive event (iteration end)")
    end

    -- When splitEvents is not set at all: defaults to '0' (single endpoint)
    do
        local dev = make_mock_device({
            first_button_ep = 0x04,
            first_button_group_ep = 0x06
        })
        -- no preferences['splitEvents'] set

        utils.emit_button_event(dev, 0x04, test_event)

        assert.is_not_nil(dev._events[0x04], "endpoint 0x04 should receive event with default splitEvents")
    end

    -- Test that ep >= button_group_ep triggers broadcast (all buttons)
    do
        local dev = make_mock_device({
            first_button_ep = 0x01,
            first_button_group_ep = 0x05  -- group starts at ep 5
        })
        dev.preferences['splitEvents'] = '0'

        utils.emit_button_event(dev, 0x0A, test_event)  -- ep=10 >= 5

        assert.is_not_nil(dev._events[0x01])
        assert.is_not_nil(dev._events[0x02])
        assert.is_not_nil(dev._events[0x03])
        assert.is_not_nil(dev._events[0x04])
    end
end

-- ===== Edge case: click_types out of bounds =====

do
    -- Negative index
    assert.equals(nil, utils.click_types[-1], "click_types with negative index should be nil")

    -- String key (should also be nil)
    assert.equals(nil, utils.click_types["abc"], "click_types with string key should be nil")
end

-- ===== Edge case: get_field returning falsy but non-nil =====

do
    local dev = make_mock_device({ first_switch_ep = false })
    -- false is falsy in Lua, so get_field returns false, and 'or 0' converts it to 0
    assert.equals(0, utils.first_switch_ep(dev),
        "first_switch_ep should default to 0 for false value")

    local dev2 = make_mock_device({ first_switch_ep = "" })
    assert.equals(0, utils.first_switch_ep(dev2),
        "first_switch_ep should default to 0 for empty string")
end

test.run_registered_tests()
