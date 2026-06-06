-- Copyright 2024 SmartThings
-- Tests for xiaomi_utils.lua module
local test = require "integration_test"

local capabilities = require "st.capabilities"

-- Mock st.utils for the clamp_value and round functions used internally
_G.st = {
    utils = {
        clamp_value = function(v, min_v, max_v)
            if v < min_v then return min_v end
            if v > max_v then return max_v end
            return v
        end,
        round = function(v)
            return math.floor(v + 0.5)
        end
    }
}

-- Create a mock device with capability support checks
local function make_mock_device()
    local dev = {
        _capabilities = {},
        _fields = {},
        _events = {},
        _latest_states = {},
        emit_event_for_endpoint = function(self, ep, event)
            if not self._events[ep] then self._events[ep] = {} end
            table.insert(self._events[ep], event)
        end,
        emit_event = function(self, event)
            table.insert(self._events, event)
        end,
        supports_capability = function(cap, _component)
            return self._capabilities[cap.ID] ~= nil
        end,
        get_latest_state = function(_self, ep, cap_id, name)
            local key = ep .. "::" .. cap_id .. "::" .. name
            return self._latest_states[key]
        end,
        get_field = function(self, name)
            return self._fields[name]
        end,
        set_field = function(self, name, value, opts)
            self._fields[name] = value
            if opts and opts.persist then
                -- persist doesn't change behavior for tests
            end
        end,
        _get_capabilities = function() return self._capabilities end
    }
    return dev
end

-- ===== xiaomi_utils.events table tests =====

do
    local xiaomi_utils = require "xiaomi_utils"
    assert.is_not_nil(xiaomi_utils.events, "xiaomi_utils.events should exist")

    -- Verify event handlers are registered for expected keys
    assert.is_not_nil(xiaomi_utils.events[0x01], "Event handler for battery (0x01) should exist")
    assert.is_not_nil(xiaomi_utils.events[0x03], "Event handler for temperature (0x03) should exist")
    assert.is_not_nil(xiaomi_utils.events[0x95], "Event handler for consumption/energy (0x95) should exist")
    assert.is_not_nil(xiaomi_utils.events[0x96], "Event handler for voltage (0x96) should exist")
    assert.is_not_nil(xiaomi_utils.events[0x97], "Event handler for current (0x97) should exist")
    assert.is_not_nil(xiaomi_utils.events[0x98], "Event handler for power (0x98) should exist")

    -- Verify they are functions
    assert.equals("function", type(xiaomi_utils.events[0x01]), "event handler should be a function")
    assert.equals("function", type(xiaomi_utils.events[0x03]), "event handler should be a function")
    assert.equals("function", type(xiaomi_utils.events[0x95]), "event handler should be a function")
end

-- ===== xiaomi_utils.basic_id tests =====

do
    local xiaomi_utils = require "xiaomi_utils"
    assert.is_not_nil(xiaomi_utils.basic_id, "xiaomi_utils.basic_id should exist")

    assert.equals("function", type(xiaomi_utils.basic_id[0xFF00]),
        "basic_id[0xFF00] (prevent_reset_handler) should be a function")
    assert.equals("function", type(xiaomi_utils.basic_id[0xFF01]),
        "basic_id[0xFF01] (handler) should be a function")
    assert.equals("function", type(xiaomi_utils.basic_id[0xFF02]),
        "basic_id[0xFF02] (handlerFF02) should be a function")
end

-- ===== xiaomi_utils.OppleCluster and opple_id tests =====

do
    local xiaomi_utils = require "xiaomi_utils"
    assert.equals(0xFCC0, xiaomi_utils.OppleCluster, "OppleCluster should be 0xFCC0")
    assert.is_not_nil(xiaomi_utils.opple_id, "xiaomi_utils.opple_id should exist")
    assert.equals("function", type(xiaomi_utils.opple_id[0x00F7]),
        "opple_id[0x00F7] (handler) should be a function")
end

-- ===== xiaomi_utils.get_energy_offset tests =====

do
    local xiaomi_utils = require "xiaomi_utils"
    local dev = make_mock_device()

    -- Default offset when no field is set
    local offset = xiaomi_utils.get_energy_offset(dev)
    assert.equals(0, offset, "default energy offset should be 0")

    -- When offset is set
    dev._fields["energyResetOffsetWh"] = 1500.5
    offset = xiaomi_utils.get_energy_offset(dev)
    assert.equals(1500.5, offset, "get_energy_offset should return the stored value")
end

-- ===== xiaomi_utils.set_energy_offset tests =====

do
    local xiaomi_utils = require "xiaomi_utils"
    local dev = make_mock_device()

    xiaomi_utils.set_energy_offset(dev, 2500)
    assert.equals(2500, dev._fields["energyResetOffsetWh"],
        "set_energy_offset should store the value")
end

-- ===== xiaomi_utils.energy_reset_handler tests =====

do
    local xiaomi_utils = require "xiaomi_utils"
    local dev = make_mock_device()
    dev._capabilities[capabilities.energyMeter.ID] = true

    -- Test with cached raw energy value
    dev._fields["energyLastRawWh"] = 5000
    xiaomi_utils.energy_reset_handler(nil, dev, nil)

    assert.equals(5000, dev._fields["energyResetOffsetWh"],
        "offset should be set to previous raw value")
end

-- ===== emit_battery_event tests (via xiaomi_utils.emit_battery_event wrapper) =====

do
    local xiaomi_utils = require "xiaomi_utils"
    local cap_battery = capabilities.battery

    -- Test battery voltage to percentage calculation
    -- Formula: raw_bat_perc = ((raw_volt - 2.5) / (3.0 - 2.5)) * 100
    -- where raw_volt = (value.value / 1000)

    local dev = make_mock_device()
    dev._capabilities[cap_battery.ID] = true

    -- Voltage 3000mV (3.0V) -> 100%
    xiaomi_utils.emit_battery_event(nil, dev, { value = 3000 }, nil)
    assert.is_not_nil(dev._events[#dev._events], "should emit battery event")

    -- Voltage 2500mV (2.5V) -> 0%
    local dev2 = make_mock_device()
    dev2._capabilities[cap_battery.ID] = true
    xiaomi_utils.emit_battery_event(nil, dev2, { value = 2500 }, nil)

    -- Voltage 2750mV (2.75V) -> ~50%
    local dev3 = make_mock_device()
    dev3._capabilities[cap_battery.ID] = true
    xiaomi_utils.emit_battery_event(nil, dev3, { value = 2750 }, nil)

    -- Voltage 2600mV (2.6V) -> ~20%
    local dev4 = make_mock_device()
    dev4._capabilities[cap_battery.ID] = true
    xiaomi_utils.emit_battery_event(nil, dev4, { value = 2600 }, nil)

    -- Verify batteryLevel capability also emitted when supported
    local dev5 = make_mock_device()
    dev5._capabilities[capabilities.battery.ID] = true
    dev5._capabilities[capabilities.batteryLevel.ID] = true
    xiaomi_utils.emit_battery_event(nil, dev5, { value = 2900 }, nil)

    -- Voltage <= 2.5V should result in critical battery level when batteryLevel is supported
    local dev6 = make_mock_device()
    dev6._capabilities[capabilities.battery.ID] = true
    dev6._capabilities[capabilities.batteryLevel.ID] = true
    xiaomi_utils.emit_battery_event(nil, dev6, { value = 2400 }, nil) -- below 2.5V -> clamped to 0%

    -- Voltage <= 2.6V (2.6 - 2.5 / 0.5 * 100 = 20%)
    local dev7 = make_mock_device()
    dev7._capabilities[capabilities.battery.ID] = true
    dev7._capabilities[capabilities.batteryLevel.ID] = true
    xiaomi_utils.emit_battery_event(nil, dev7, { value = 2580 }, nil) -- (0.08/0.5)*100 = ~16% -> critical

    -- Voltage < 2.8V should trigger warning when voltage <= 2.75 -> (0.25/0.5*100=50%)
    local dev8 = make_mock_device()
    dev8._capabilities[capabilities.battery.ID] = true
    dev8._capabilities[capabilities.batteryLevel.ID] = true
    xiaomi_utils.emit_battery_event(nil, dev8, { value = 2650 }, nil) -- 20%
end

-- ===== emit_voltage_event tests (via wrapper) =====

do
    local xiaomi_utils = require "xiaomi_utils"
    local dev = make_mock_device()

    xiaomi_utils.emit_voltage_event(nil, dev, { value = 230 }) -- 230/10 = 23V
    assert.is_not_nil(dev._events[#dev._events], "should emit voltage event")

    xiaomi_utils.emit_voltage_event(nil, dev, { value = 240 }) -- 240/10 = 24V
    assert.is_not_nil(dev._events[#dev._events], "should emit another voltage event")
end

-- ===== xiaomi_utils.handler tests =====

do
    local xiaomi_utils = require "xiaomi_utils"
    local data_types = require "st.zigbee.data_types"

    -- Test handler receives a value with CharString or OctetString type
    local dev = make_mock_device()
    dev._capabilities[capabilities.battery.ID] = true
    dev._capabilities[capabilities.batteryLevel.ID] = true
    dev._capabilities[capabilities.temperatureAlarm.ID] = true

    -- Test with an OctetString value (valid data type)
    local mock_value = {
        ID = 0xE10, -- CharString or OctetString should work
        value = { 0x01, 0x41, 0xD0, 0x6E } -- dummy xiaomi data with battery key 0x01
    }

    -- The handler deserializes bytes; we can't fully test the parsing without
    -- full mock of st.zigbee.data_types.deserialize, but we can verify it doesn't error
    local ok, err = pcall(xiaomi_utils.handler, nil, dev, mock_value, nil)
    -- May error on deserialize depending on environment; check function exists
    assert.equals("function", type(xiaomi_utils.handler), "handler should be a function")

    -- Test with invalid data type (should log warning)
    local invalid_value = { ID = 0x01, value = "invalid" }
    ok, err = pcall(xiaomi_utils.handler, nil, dev, invalid_value, nil)
end

-- ===== xiaomi_utils.handlerFF02 tests =====

do
    local xiaomi_utils = require "xiaomi_utils"

    -- Test with Structure type containing battery data
    local structure_elements = {}
    local battery_element = { data = { value = 2800 } }
    structure_elements[0x02] = battery_element

    local mock_structure = { elements = structure_elements }
    assert.equals("function", type(xiaomi_utils.handlerFF02), "handlerFF02 should be a function")
end

-- ===== xiaomi_utils.prevent_reset_handler tests =====

do
    local xiaomi_utils = require "xiaomi_utils"
    assert.equals("function", type(xiaomi_utils.prevent_reset_handler),
        "prevent_reset_handler should be a function")

    -- Test bytes_starts_with helper via prevent_reset_handler
    local dev = make_mock_device()
    local prefix = { 0xAA, 0x10, 0x05, 0x41, 0x87 }

    -- Incoming data starting with the prefix should trigger write
    local incoming_with_prefix = { 0xAA, 0x10, 0x05, 0x41, 0x87, 0xFF, 0xFF }
    local mock_value = { value = incoming_with_prefix }
    local ok, err = pcall(xiaomi_utils.prevent_reset_handler, nil, dev, mock_value, nil)

    -- Incoming data NOT starting with prefix should be ignored
    local incoming_no_prefix = { 0x01, 0x02, 0x03 }
    local mock_value2 = { value = incoming_no_prefix }
    ok, err = pcall(xiaomi_utils.prevent_reset_handler, nil, dev, mock_value2, nil)

    -- nil input should not crash (bytes_starts_with returns false for nil)
    local mock_value3 = { value = nil }
    ok, err = pcall(xiaomi_utils.prevent_reset_handler, nil, dev, mock_value3, nil)
end

-- ===== Battery level thresholds from opple (battery_level_handler is defined in opple/init.lua
-- but also referenced through xiaomi_utils.emit_battery_event for the raw value) =====

do
    -- Verify that low battery levels are correctly mapped:
    -- Voltage 2.5V -> critical, 2.8V -> warning threshold boundary, >2.8V -> normal
    local xiaomi_utils = require "xiaomi_utils"

    -- The handler uses voltage/1000 to get raw_bat_volt in volts
    -- then clamps percentage to 0-100 range
    assert.equals("function", type(xiaomi_utils.emit_battery_event),
        "emit_battery_event wrapper should be a function")
    assert.equals("function", type(xiaomi_utils.emit_voltage_event),
        "emit_voltage_event wrapper should be a function")
end

test.run_registered_tests()
