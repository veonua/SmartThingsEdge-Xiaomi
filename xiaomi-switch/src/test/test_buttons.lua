-- Copyright 2024 SmartThings
-- Tests for buttons/init.lua module
local test = require "integration_test"

local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff

-- Mock utils before loading buttons module
_G.utils = {
    first_switch_ep = function(device) return device:get_field("first_switch_ep") or 0 end,
    first_button_ep = function(device) return device:get_field("first_button_ep") or 0 end,
    first_button_group_ep = function(device) return device:get_field("first_button_group_ep") or 999 end,
    click_types = {
        [0] = capabilities.button.button.held,
        [1] = capabilities.button.button.pushed,
        [2] = capabilities.button.button.pushed_2x,
        [3] = capabilities.button.button.pushed_3x,
        [4] = capabilities.button.button.pushed_4x,
        [5] = capabilities.button.button.pushed_5x,
        [0x10] = capabilities.button.button.held,
        [0x11] = nil,
        [0xff] = nil,
    },
    emit_button_event = function(device, ep, event)
        if not device._button_events then device._button_events = {} end
        device._button_events[ep] = device._button_events[ep] or {}
        table.insert(device._button_events[ep], event)
    end
}

-- Load the button handler
local buttons = require "buttons"

-- ===== can_handle tests =====

do
    -- Returns true when first_switch_ep < 1 AND model != "lumi.sensor_switch"
    local device_ok = {
        get_field = function(_, k) if k == "first_switch_ep" then return 0 end end,
        get_model = function() return "lumi.switch.test" end
    }
    assert.is_true(buttons.can_handle(nil, nil, device_ok),
        "can_handle should return true when first_switch_ep < 1 and model is not lumi.sensor_switch")

    -- Returns false when first_switch_ep >= 1
    local device_wrong_ep = {
        get_field = function(_, k) if k == "first_switch_ep" then return 5 end end,
        get_model = function() return "lumi.switch.test" end
    }
    assert.is_false(buttons.can_handle(nil, nil, device_wrong_ep),
        "can_handle should return false when first_switch_ep >= 1")

    -- Returns false for lumi.sensor_switch regardless of first_switch_ep
    local sensor_switch = {
        get_field = function(_, k) if k == "first_switch_ep" then return 0 end end,
        get_model = function() return "lumi.sensor_switch" end
    }
    assert.is_false(buttons.can_handle(nil, nil, sensor_switch),
        "can_handle should return false for lumi.sensor_switch")

    local sensor_switch2 = {
        get_field = function(_, k) if k == "first_switch_ep" then return 5 end end,
        get_model = function() return "lumi.sensor_switch" end
    }
    assert.is_false(buttons.can_handle(nil, nil, sensor_switch2),
        "can_handle should return false for lumi.sensor_switch even with wrong ep")
end

-- ===== on_off_attr_handler: single click (down_counter = 1) =====

do
    local device = {
        _fields = {},
        get_field = function(self, key) return self._fields[key] end,
        set_field = function(self, key, value) self._fields[key] = value end,
        thread = { call_with_delay = function(delay_ms, func)
            -- Execute the callback immediately for testing
            func()
            return "timer_handle"
        end },
        _button_events = {}
    }

    local mock_zb_rx = {
        address_header = { src_endpoint = { value = 0x04 } }
    }

    -- First event: OnOff.value = true (down_counter not set yet)
    local attr_value = { value = true }
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, attr_value, mock_zb_rx)

    assert.equals(1, device._fields["button_timer4"], "timer should be set")
    assert.equals(1, device._fields["down_counter4"], "down_counter should be 1")
end

-- ===== on_off_attr_handler: double press (down_counter = 2 after second event) =====

do
    local device = {
        _fields = {},
        get_field = function(self, key) return self._fields[key] end,
        set_field = function(self, key, value) self._fields[key] = value end,
        thread = { call_with_delay = function(delay_ms, func)
            -- Simulate timer execution: run the callback (which processes the click)
            func()
            return "timer_handle"
        end },
        _button_events = {}
    }

    local mock_zb_rx = { address_header = { src_endpoint = { value = 0x04 } } }

    -- First press: OnOff = true (starts timer, down_counter = 1)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)

    -- Simulate the 0.4s timer firing (this processes down_counter=1 as pushed)
    local processed_event = device._button_events[0x04] and device._button_events[0x04][#device._button_events[0x04]]

    -- Second press: OnOff = true again (down_counter increments to 2, timer restarted)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)

    assert.equals(2, device._fields["down_counter4"], "down_counter should be 2 after second press")

    -- Now simulate timer firing again (this processes down_counter=2 as pushed_2x)
    -- We need to set up the test so that on_timer fires for the second event
end

-- ===== on_off_attr_handler: held behavior (OnOff.value = false after hold) =====

do
    local device = {
        _fields = {},
        get_field = function(self, key) return self._fields[key] end,
        set_field = function(self, key, value) self._fields[key] = value end,
        thread = { call_with_delay = function(delay_ms, func)
            func()
            return "timer_handle"
        end },
        _button_events = {}
    }

    local mock_zb_rx = { address_header = { src_endpoint = { value = 0x04 } } }

    -- Press down: OnOff = true (down_counter = 1)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)

    -- Hold released: OnOff = false -> should fire with held event
    local off_value = { value = false }
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, off_value, mock_zb_rx)

    assert.is_true(device._fields["button_timer4"] ~= nil, "timer should still be set after hold")
end

-- ===== Timer-based click counting with 0.4s timeout =====

do
    local fired_events = {}
    local timer_callback

    local device = {
        _fields = {},
        get_field = function(self, key) return self._fields[key] end,
        set_field = function(self, key, value) self._fields[key] = value end,
        thread = { call_with_delay = function(delay_ms, func)
            -- Store callback for later execution to simulate timeout
            timer_callback = func
            return "timer_handle"
        end },
        _button_events = {}
    }

    local mock_zb_rx = { address_header = { src_endpoint = { value = 0x04 } } }

    -- Simulate: no previous timer, down_counter=1 (first press)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)

    assert.equals(1, device._fields["down_counter4"], "down_counter should be 1")
    assert.is_true(device._fields["button_timer4"] ~= nil, "timer should be set on first press")

    -- Simulate timer firing after 0.4s timeout
    if timer_callback then
        timer_callback()
    end

    -- After timer fires: down_counter should reset to 0, timer cleared
    assert.equals(0, device._fields["down_counter4"], "down_counter should reset to 0 after timer fires")
    assert.is_false(device._fields["button_timer4"] ~= nil or device._fields["button_timer4"] == nil,
        "timer should be cleared (set to nil)")
end

-- ===== on_off_attr_handler: stray up event handling =====

do
    local log_messages = {}
    -- Mock log.warn to capture it
    _G.log = {
        warn = function(...) table.insert(log_messages, tostring((...))) end,
        info = function() end,
        debug = function() end
    }

    local device = {
        _fields = {},
        get_field = function(self, key) return self._fields[key] end,
        set_field = function(self, key, value) self._fields[key] = value end,
        thread = { call_with_delay = function() return nil end },
        _button_events = {}
    }

    local mock_zb_rx = { address_header = { src_endpoint = { value = 0x04 } } }

    -- OnOff.value = false with no prior timer (stray event)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = false }, mock_zb_rx)

    assert.is_true(#log_messages > 0, "should log warning for stray up event")
end

-- ===== Timer behavior: multiple rapid presses (click counting) =====

do
    local device = {
        _fields = {},
        get_field = function(self, key) return self._fields[key] end,
        set_field = function(self, key, value) self._fields[key] = value end,
        thread = { call_with_delay = function(delay_ms, func)
            -- Execute immediately to simulate timer firing
            func()
            return "timer_handle"
        end },
        _button_events = {}
    }

    local mock_zb_rx = { address_header = { src_endpoint = { value = 0x04 } } }

    -- First press (starts timer, down_counter=1)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)

    -- Second press while timer still running (down_counter increments to 2)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)
    assert.equals(2, device._fields["down_counter4"], "down_counter should be 2 after second press")

    -- Third press (down_counter increments to 3)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)
    assert.equals(3, device._fields["down_counter4"], "down_counter should be 3 after third press")

    -- Fourth press (down_counter increments to 4)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)
    assert.equals(4, device._fields["down_counter4"], "down_counter should be 4 after fourth press")

    -- Fifth press (down_counter increments to 5)
    buttons.zigbee_handlers.attr[OnOff.ID][OnOff.attributes.OnOff.ID](nil, device, { value = true }, mock_zb_rx)
    assert.equals(5, device._fields["down_counter4"], "down_counter should be 5 after fifth press")

    -- Timer fires - processes down_counter=5 as pushed_5x
end

-- ===== Verify button_handler has correct NAME and handler structure =====

do
    assert.equals("Button Handler", buttons.NAME, "handler NAME should be 'Button Handler'")
    assert.is_not_nil(buttons.zigbee_handlers, "should have zigbee_handlers")
    assert.is_not_nil(buttons.zigbee_handlers.attr, "should have attr handlers")
    assert.is_not_nil(buttons.can_handle, "should have can_handle function")
end

test.run_registered_tests()
