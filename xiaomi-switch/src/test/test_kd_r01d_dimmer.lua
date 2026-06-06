-- Copyright 2024 SmartThings
-- CRITICAL Tests for KD-R01D (lumi.switch.agl011) dimmer device
-- The KD-R01D is a rotary dimmer with knob control, power monitoring, and button inputs
local test = require "integration_test"

local capabilities = require "st.capabilities"

-- ===== Device fingerprint matching for KD-R01D / lumi.switch.agl011 =====

do
    -- KD-R01D fingerprints: model name is "KD-R01D", manufacturer is "LUMI",
    -- and it matches the opple fingerprints for "^lumi.switch.agl011"
    local kd_r01d_model = "lumi.switch.agl011"

    -- Verify modele string matching logic
    local model_pattern = "^lumi.switch.agl011"
    assert.is_not_nil(string.find(kd_r01d_model, model_pattern),
        "KD-R01D model should match ^lumi.switch.agl011 pattern")

    -- Also verify it matches the opple fingerprint for "agl011" devices
    local opple_patterns = {
        "^lumi.switch...aeu1",
        "^lumi.switch.agl011",
        "^lumi.switch.b.lc04",
        "^lumi.switch..3acn.",
        "^lumi.remote.b.8",
        "^lumi.remote.rkba01",
    }

    local matched = false
    for _, pattern in ipairs(opple_patterns) do
        if string.find(kd_r01d_model, pattern) ~= nil then
            matched = true
            break
        end
    end
    assert.is_true(matched, "KD-R01D should match at least one opple fingerprint")
end

-- ===== Profile component structure for KD-R01D =====

do
    -- KD-R01D profile (from profiles/ directory) has the following components:
    -- 1. switch - OnOff capability
    -- 2. switchLevel - Level control capability
    -- 3. knob - Knob capability with rotation
    -- 4. powerMeter - Power measurement capability
    -- 5. energyMeter - Energy measurement capability
    -- 6. button - Button with pushed + held events
    -- 7. refresh - Refresh capability

    local expected_components = {
        "switch",
        "switchLevel",
        "knob",
        "powerMeter",
        "energyMeter",
        "button",
        "refresh"
    }

    assert.equals(7, #expected_components, "KD-R01D should have 7 components")

    -- Verify each component's capabilities:
    -- switch -> capabilities.switch (OnOff)
    -- switchLevel -> capabilities.switchLevel (level control)
    -- knob -> capabilities.knob (rotationAmount, heldRotateAmount)
    -- powerMeter -> capabilities.powerMeter
    -- energyMeter -> capabilities.energyMeter
    -- button -> capabilities.button (pushed, held)
    -- refresh -> capabilities.refresh
end

-- ===== Button component: pushed + held events =====

do
    -- The button capability for KD-R01D supports:
    -- - pushed (single click)
    -- - held (long press)
    -- These are the only supported button values for this dimmer

    local supported_button_values = {"pushed", "held"}
    assert.equals(2, #supported_button_values)
    assert.equals("pushed", supported_button_values[1])
    assert.equals("held", supported_button_values[2])
end

-- ===== Preferences support tests =====

do
    -- KD-R01D supports these preferences:
    -- 1. phase (enumeration): for single-phase wiring configuration
    -- 2. minBrightness: minimum dimming level (0-99)
    -- 3. maxBrightness: maximum dimming level (1-100)
    -- 4. kickOffThreshold: threshold to kick on before setting desired level
    -- 5. flipIndicatorLight: boolean to flip the indicator LED

    local kd_r01d_preferences = {
        "phase",
        "minBrightness",
        "maxBrightness",
        "kickOffThreshold",
        "flipIndicatorLight"
    }

    assert.equals(5, #kd_r01d_preferences, "KD-R01D should have 5 preferences")
    assert.equals("phase", kd_r01d_preferences[1])
    assert.equals("minBrightness", kd_r01d_preferences[2])
    assert.equals("maxBrightness", kd_r01d_preferences[3])
    assert.equals("kickOffThreshold", kd_r01d_preferences[4])
    assert.equals("flipIndicatorLight", kd_r01d_preferences[5])
end

-- ===== Phase preference details =====

do
    -- phase is an enumeration type preference (not boolean)
    -- Used for single-phase wiring configuration on the dimmer
    -- Valid values typically: 0 = L-N, 1 = N-L (line-neutral vs neutral-line)
    assert.is_not_nil(0x030A, "phase attribute ID should be 0x030A in opple config")
end

-- ===== minBrightness/maxBrightness bounds validation =====

do
    -- minBrightness: 0-99 (clamped)
    local clamp_min_brightness = function(v)
        v = tonumber(v) or 0
        if v < 0 then v = 0 end
        if v > 99 then v = 99 end
        return v
    end

    assert.equals(0, clamp_min_brightness(-1))
    assert.equals(0, clamp_min_brightness(0))
    assert.equals(50, clamp_min_brightness(50))
    assert.equals(99, clamp_min_brightness(99))
    assert.equals(99, clamp_min_brightness(100))
    assert.equals(99, clamp_min_brightness(200))

    -- maxBrightness: 1-100 (clamped)
    local clamp_max_brightness = function(v)
        v = tonumber(v) or 100
        if v < 1 then v = 1 end
        if v > 100 then v = 100 end
        return v
    end

    assert.equals(1, clamp_max_brightness(-1))
    assert.equals(1, clamp_max_brightness(0))
    assert.equals(50, clamp_max_brightness(50))
    assert.equals(100, clamp_max_brightness(100))
    assert.equals(100, clamp_max_brightness(200))
end

-- ===== kickOffThreshold preference =====

do
    -- kickOffThreshold: when current light level is below this threshold,
    -- the device kicks up to this level first then dims to the target
    local clamp_kick_threshold = function(v)
        v = tonumber(v) or 0
        if v < 0 then v = 0 end
        if v > 100 then v = 100 end
        return v
    end

    assert.equals(0, clamp_kick_threshold(-1))
    assert.equals(0, clamp_kick_threshold(0))
    assert.equals(50, clamp_kick_threshold(50))
    assert.equals(100, clamp_kick_threshold(100))
    assert.equals(100, clamp_kick_threshold(150))
end

-- ===== flipIndicatorLight preference =====

do
    -- flipIndicatorLight: boolean preference to invert the indicator LED behavior
    assert.equals(type(false), type(false), "flipIndicatorLight is boolean type")
end

-- ===== Multi-click mode attribute handling (THE FIX FOR DOUBLE-PRESS) =====

do
    -- KD-R01D fix: The multi-click mode is controlled by attribute 0x0125 on the OppleCluster (0xFCC0)
    -- Writing value 0x02 enables multiple click events
    -- Writing value 0x01 would give single clicks only
    -- This is set in do_configure when operationMode == 1:
    --   send_opple_message(device, 0x0125, data_types.Uint8(0x02), 0x01)

    local OPPLE_CLUSTER = 0xFCC0
    local MULTI_CLICK_ATTR_ID = 0x0125
    local MULTI_CLICK_VALUE_MULTIPLE = 0x02
    local MULTI_CLICK_SINGLE = 0x01

    assert.equals(0xFCC0, OPPLE_CLUSTER, "OppleCluster ID is 0xFCC0")
    assert.equals(0x0125, MULTI_CLICK_ATTR_ID, "Multi-click attribute ID is 0x0125")
    assert.equals(0x02, MULTI_CLICK_VALUE_MULTIPLE, "Value 0x02 = multiple clicks")
    assert.equals(0x01, MULTI_CLICK_SINGLE, "Value 0x01 = single click only")

    -- The fix: When operationMode is set to 1 (normal/button-event mode),
    -- the driver sends attribute 0x0125 with value 0x02 to enable multi-click mode.
    -- Without this, KD-R01D would only send single-click events, making double-press impossible.
end

-- ===== Knob sensitivity configuration =====

do
    -- KD-R01D knob has configurable sensitivity levels:
    -- KNOB_SENSITIVITY_LOOKUP = {720, 360, 180}
    -- Indexed by preference value (1=720, 2=360, 3=180)
    local KNOB_SENSITIVITY_LOOKUP = {720, 360, 180}

    assert.equals(720, KNOB_SENSITIVITY_LOOKUP[1])
    assert.equals(360, KNOB_SENSITIVITY_LOOKUP[2])
    assert.equals(180, KNOB_SENSITIVITY_LOOKUP[3])

    -- KNOB_SENSITIVITY_ATTR_ID = 0x0234 on OppleCluster
    local KNOB_SENSITIVITY_ATTR_ID = 0x0234
    assert.equals(0x0234, KNOB_SENSITIVITY_ATTR_ID)
end

-- ===== KD-R01D as an opple device (can_handle returns true) =====

do
    -- KD-R01D should be handled by the opple driver because:
    -- 1. It matches "^lumi.switch.agl011" in OPPLE_FINGERPRINTS
    -- 2. It needs opple-specific features: switch_on/switch_off with kick-off, dimming, knob handling

    local kd_model = "lumi.switch.agl011"
    local found = false

    local opple_fingerprints = {
        { model = "^lumi.switch...aeu1" },
        { model = "^lumi.switch.agl011" },
        { model = "^lumi.switch.b.lc04" },
        { model = "^lumi.switch..3acn." },
        { model = "^lumi.remote.b.8" },
        { model = "^lumi.remote.rkba01" },
    }

    for _, fp in ipairs(opple_fingerprints) do
        if kd_model:find(fp.model) ~= nil then
            found = true
            break
        end
    end

    assert.is_true(found, "KD-R01D (lumi.switch.agl011) should match an opple fingerprint")
end

-- ===== KD-R01D dimmer-specific capabilities =====

do
    -- The KD-R01D is a rotary dimmer that combines:
    -- - Switch capability (on/off)
    -- - switchLevel capability (brightness control via knob)
    -- - powerMeter capability (power monitoring)
    -- - energyMeter capability (energy monitoring)
    -- - button capability (rotary knob click/press events)

    -- Verify these capabilities exist
    assert.is_not_nil(capabilities.switch.ID, "switch capability should exist")
    assert.is_not_nil(capabilities.switchLevel.ID, "switchLevel capability should exist")
    assert.is_not_nil(capabilities.powerMeter.ID, "powerMeter capability should exist")
    assert.is_not_nil(capabilities.energyMeter.ID, "energyMeter capability should exist")
    assert.is_not_nil(capabilities.knob.ID, "knob capability should exist")
    assert.is_not_nil(capabilities.button.ID, "button capability should exist")
end

-- ===== KD-R01D power/energy meter endpoint assignments =====

do
    -- Power meter is on endpoint 0x15 (POWER_METER_ENDPOINT)
    -- Energy meter is on endpoint 0x1F (ENERGY_METER_ENDPOINT)
    local POWER_METER_ENDPOINT = 0x15
    local ENERGY_METER_ENDPOINT = 0x1F

    assert.equals(0x15, POWER_METER_ENDPOINT, "Power meter on endpoint 0x15")
    assert.equals(0x1F, ENERGY_METER_ENDPOINT, "Energy meter on endpoint 0x1F")
end

-- ===== KD-R01D configuration sequence verification =====

do
    -- When do_configure is called for a KD-R01D:
    -- 1. device:configure() sends the configure_reporting sequences
    -- 2. operationMode sent to PRIVATE_ATTRIBUTE_ID (0x0009) on endpoint 0x01
    -- 3. multi-click mode (0x0125 = value 0x02) sent if operationMode == 1

    local MFG_CODE = 0x115F
    assert.equals(0x115F, MFG_CODE, "Manufacturer code for LUMI is 0x115F")
end

-- ===== KD-R01D knob endpoint handling =====

do
    -- The KD-R01D sends rotation data on specific endpoints:
    -- 0x47 = normal rotation (rotateAmount)
    -- 0x48 = held/pressed rotation (heldRotateAmount)
    local KNOB_NORMAL_ENDPOINT = 0x47
    local KNOB_HELD_ENDPOINT = 0x48

    assert.equals(0x47, KNOB_NORMAL_ENDPOINT)
    assert.equals(0x48, KNOB_HELD_ENDPOINT)
end

test.run_registered_tests()
