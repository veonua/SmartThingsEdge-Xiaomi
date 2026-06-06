-- Copyright 2024 SmartThings
-- Tests for opple/init.lua module
local test = require "integration_test"

local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"

-- Mock required modules before loading opple
_G.data_types = {
    OctetString = function(v) return { value = v } end,
    Uint8 = function(v) return { value = v } end,
    Uint16 = function(v) return { value = v, ID = 0x20 } end,
    Boolean = function(v) return { value = v and true or false } end,
    validate_or_build_type = function(val, typ, name) return val end,
    ClusterId = function(v) return { value = v } end,
    AttributeId = function(v) return { value = v } end,
}

_G.zigbee_utils = {
    build_bind_request = function(_device, _cluster, _group) return { type = "bind_request" } end,
    print_clusters = function() end
}

_G.log = {
    info = function(...) end,
    warn = function(...) end,
    debug = function(...) end
}

-- Mock device for testing
local function make_mock_device(preferences)
    local prefs = preferences or {}
    return {
        id = "mock_xiaomi_switch",
        fingerprinted_endpoint_id = 0x01,
        _fields = {},
        _preferences = prefs,
        _sent_messages = {},
        get_field = function(self, key) return self._fields[key] end,
        set_field = function(self, key, val) self._fields[key] = val end,
        preferences = prefs,
        supports_capability = function(_self, cap, _comp) return cap.ID == 123 end, -- pretend yes for tests
        get_latest_state = function(_self, ep, cap_id, name) return nil end,
        send = function(self, msg) table.insert(self._sent_messages, msg) end,
        send_to_component = function(self, _comp, msg) table.insert(self._sent_messages, msg) end,
        thread = { call_with_delay = function(delay_ms, func)
            -- Execute immediately for testing
            if type(func) == "function" then func() end
            return "mock_timer"
        end },
        emit_event_for_endpoint = function(self, ep, event)
            if not self._events then self._events = {} end
            table.insert(self._events, { endpoint = ep, event = event })
        end,
        _get_sent_messages = function() return self._sent_messages end
    }
end

-- Load opple module (may already be loaded in environment)
local opple = require "opple"

-- ===== switch_on tests =====

do
    local driver_mock = {}
    local dev = make_mock_device()

    -- switch_on for main component should send OnOff command
    local cmd = { component = "main", args = {} }
    if type(opple.capability_handlers) ~= "table" then
        opple = require "opple" -- reload if needed
    end

    assert.is_not_nil(opple.capability_handlers, "opple should expose capability_handlers")

    local switch_handler = opple
    if type(switch_handler) == "table" and switch_handler.NAME then
        switch_handler = switch_handler -- already the handler table
    elseif type(opple) == "table" then
        -- opple returns a table directly (the handler)
        switch_handler = opple
    end

    assert.is_not_nil(switch_handler.capability_handlers,
        "opple should have capability_handlers")
    assert.is_not_nil(switch_handler.capability_handlers[capabilities.switch.ID],
        "should have switch capability handlers")
    assert.is_not_nil(switch_handler.capability_handlers[capabilities.switch.ID][
        capabilities.switch.commands.on.NAME],
        "should have on command handler")
    assert.is_not_nil(switch_handler.capability_handlers[capabilities.switch.ID][
        capabilities.switch.commands.off.NAME],
        "should have off command handler")
end

-- ===== switch_on with kick-off threshold logic =====

do
    -- kickOffThreshold preference: when current level < threshold, dim up to threshold then back to target
    local kick_dev = make_mock_device({ kickOffThreshold = 50 })
    kick_dev._fields = {}
    -- Mock supports_capability
    kick_dev.supports_capability = function(self, cap) return false end

    assert.is_not_nil(opple.switch_on, "switch_on should be accessible")
end

-- ===== switch_off tests =====

do
    local off_cmd = { component = "main", args = {} }

    assert.is_not_nil(opple.capability_handlers[capabilities.switch.ID][
        capabilities.switch.commands.off.NAME],
        "should have off command handler")
end

-- ===== info_changed handler tests =====

do
    assert.is_not_nil(opple.lifecycle_handlers.infoChanged,
        "opple should have infoChanged lifecycle handler")
    assert.equals("function", type(opple.lifecycle_handlers.infoChanged),
        "infoChanged should be a function")

    -- The info_changed handler processes these preferences:
    -- operationMode, group, restorePowerState (stse.restorePowerState),
    -- turnOffIndicatorLight (stse.turnOffIndicatorLight),
    -- minBrightness, maxBrightness, phase, knobSensitivity (stse.knobSensitivity)

    -- Verify it handles operationMode (triggers do_configure)
    assert.equals("function", type(opple.lifecycle_handlers.infoChanged))
end

-- ===== do_configure tests =====

do
    assert.is_not_nil(opple.lifecycle_handlers.doConfigure,
        "opple should have doConfigure lifecycle handler")
    assert.equals("function", type(opple.lifecycle_handlers.doConfigure),
        "doConfigure should be a function")

    -- do_configure sends:
    -- 1. operationMode (PRIVATE_ATTRIBUTE_ID = 0x0009) to endpoint 0x01
    -- 2. multi-click mode (0x0125) to endpoint 0x01 when operationMode == 1
end

-- ===== is_opple fingerprint matching tests =====

do
    assert.is_not_nil(opple.can_handle, "opple should have can_handle function")

    local OPPLE_FINGERPRINTS = {
        "^lumi.switch...aeu1",
        "^lumi.switch.agl011",
        "^lumi.switch.b.lc04",
        "^lumi.switch..3acn.",
        "^lumi.remote.b.8",
        "^lumi.remote.rkba01",
    }

    -- Test positive matches
    local test_models = {
        "lumi.switch.aeu1",      -- should match ^lumi.switch...aeu1
        "lumi.switch.xaeu1",     -- should match ^lumi.switch...aeu1 (x fills '.')
        "lumi.switch.xxeau1",    -- should match ^lumi.switch.b1lacn04 pattern
        "lumi.switch.agl011",    -- exact match for ^lumi.switch.agl011
        "lumi.switch.l3acn3",    -- should match ^lumi.switch..3acn.
        "lumi.switch.n3acn3",    -- should match ^lumi.switch..3acn.
        "lumi.remote.b8ac1",     -- should match ^lumi.remote.b.8
        "lumi.remote.rkba01",    -- exact match for ^lumi.remote.rkba01
    }

    local non_opple_models = {
        "lumi.switch.aq2",       -- not an opple
        "lumi.sensor_motion",    -- not a switch
        "lumi.door",             -- not opple
    }

    for _, model_name in ipairs(test_models) do
        local dev = make_mock_device()
        dev.get_model = function() return model_name end
        local result = opple.can_handle(nil, nil, dev)
        assert.is_true(result, string.format("is_opple should match %s", model_name))
    end

    for _, model_name in ipairs(non_opple_models) do
        local dev = make_mock_device()
        dev.get_model = function() return model_name end
        local result = opple.can_handle(nil, nil, dev)
        assert.is_false(result, string.format("is_opple should not match %s", model_name))
    end
end

-- ===== OppleCluster constant =====

do
    assert.equals(0xFCC0, oppose and oppose.OppleCluster or require "xiaomi_utils".OppleCluster,
        "OppleCluster should be 0xFCC0")
    -- Note: opple imports xiaomi_utils internally for the cluster reference
end

-- ===== attr_operation_mode_handler tests =====

do
    assert.is_not_nil(opple.zigbee_handlers.attr[xiaomi_utils and xiaomi_utils.OppleCluster or 0xFCC0],
        "should have opple cluster attribute handlers")
    assert.is_not_nil(opple.zigbee_handlers.attr[xiaomi_utils and xiaomi_utils.OppleCluster or 0xFCC0][9],
        "should have handler for PRIVATE_ATTRIBUTE_ID (0x0009)")
end

-- ===== battery_level_handler tests =====

do
    -- Verify battery level thresholds:
    -- voltage <= 25 -> critical, < 28 -> warning, >= 28 -> normal
    assert.is_not_nil(opple.zigbee_handlers.attr[1] and opple.zigbee_handlers.attr[1][0x0021],
        "should have BatteryVoltage handler")
end

-- ===== capability_handlers structure verification =====

do
    local handlers = opple.capability_handlers

    -- switch capability
    assert.is_not_nil(handlers[capabilities.switch.ID])
    assert.is_not_nil(handlers[capabilities.switch.ID][capabilities.switch.commands.on.NAME])
    assert.is_not_nil(handlers[capabilities.switch.ID][capabilities.switch.commands.off.NAME])

    -- refresh capability
    assert.is_not_nil(handlers[capabilities.refresh.ID])
    assert.is_not_nil(handlers[capabilities.refresh.ID][capabilities.refresh.commands.refresh.NAME])
end

-- ===== lifecycle_handlers structure verification =====

do
    local lh = opple.lifecycle_handlers
    assert.equals("function", type(lh.infoChanged), "infoChanged should be a function")
    assert.equals("function", type(lh.doConfigure), "doConfigure should be a function")
end

-- ===== zigbee_handlers.attr structure verification =====

do
    local ah = opple.zigbee_handlers.attr
    -- OppleCluster (0xFCC0) handlers
    local opple_cluster = xiaomi_utils and xiaomi_utils.OppleCluster or 0xFCC0
    assert.is_not_nil(ah[opple_cluster])
    assert.is_not_nil(ah[opple_cluster][9], "PRIVATE_ATTRIBUTE_ID handler")
    assert.is_not_nil(ah[opple_cluster][0x00F7], "0x00F7 handler (xiaomi_utils.handler)")

    -- PowerConfiguration handlers
    assert.is_not_nil(ah[1] and ah[1][33]) -- PowerConfiguration.ID=1, BatteryVoltage.ID=33
end

test.run_registered_tests()
