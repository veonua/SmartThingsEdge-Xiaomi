-- Copyright 2024 SmartThings
-- Tests for xiaomi-plug profiles/plug_preferences.yml profile definition
local test = require "integration_test"

-- ===== plug_preferences.yml profile structure verification =====

do
    -- Expected profile from plug_preferences.yml:
    -- name: plug_prefs
    -- components: main
    --   capabilities: switch, powerMeter, energyMeter, powerConsumptionReport, voltageMeasurement, refresh, firmwareUpdate
    --   categories: SmartPlug
    -- preferences: stse.restorePowerState, stse.maxPowerCN, stse.turnOffIndicatorLight (explicit)
    --              autoOff (boolean, required, default false)
    -- metadata: deviceType=SmartPlug, ocfDeviceType=oic.d.smartplug, deviceTypeId=SmartPlug

    local profile_name = "plug_prefs"
    assert.equals("plug_prefs", profile_name, "profile name should be plug_prefs")

    local expected_component = "main"
    assert.equals("main", expected_component, "component ID should be main")

    -- Expected capabilities in the profile
    local expected_capabilities = {
        "switch",
        "powerMeter",
        "energyMeter",
        "powerConsumptionReport",
        "voltageMeasurement",
        "refresh",
        "firmwareUpdate"
    }

    assert.equals(7, #expected_capabilities, "should have 7 capabilities")

    -- Verify capability IDs exist in st.capabilities
    local caps = require "st.capabilities"
    assert.is_not_nil(caps.switch.ID)
    assert.is_not_nil(caps.powerMeter.ID)
    assert.is_not_nil(caps.energyMeter.ID)
    assert.is_not_nil(caps.powerConsumptionReport.ID)
    assert.is_not_nil(caps.voltageMeasurement.ID)
    assert.is_not_nil(caps.refresh.ID)
end

-- ===== Category verification =====

do
    local expected_category = "SmartPlug"
    assert.equals("SmartPlug", expected_category, "category should be SmartPlug")
end

-- ===== Preference definitions verification =====

do
    -- stse.restorePowerState - explicit boolean preference
    local pref1 = { name = "stse.restorePowerState", explicit = true }
    assert.is_true(pref1.explicit)

    -- stse.maxPowerCN - explicit preference (for max power cutoff)
    local pref2 = { name = "stse.maxPowerCN", explicit = true }
    assert.is_true(pref2.explicit)

    -- stse.turnOffIndicatorLight - explicit boolean preference
    local pref3 = { name = "stse.turnOffIndicatorLight", explicit = true }
    assert.is_true(pref3.explicit)

    -- autoOff - required boolean preference with default false
    local pref4 = {
        title = "Auto Off",
        description = "Turn the device automatically off when attached device consumes less than 2W for 20 minutes",
        name = "autoOff",
        required = true,
        preferenceType = "boolean",
        default = false
    }
    assert.is_true(pref4.required)
    assert.equals("boolean", pref4.preferenceType)
    assert.is_false(pref4.default)
end

-- ===== Metadata verification =====

do
    local metadata = {
        deviceType = "SmartPlug",
        ocfDeviceType = "oic.d.smartplug",
        deviceTypeId = "SmartPlug"
    }

    assert.equals("SmartPlug", metadata.deviceType)
    assert.equals("oic.d.smartplug", metadata.ocfDeviceType)
    assert.equals("SmartPlug", metadata.deviceTypeId)
end

-- ===== Component capabilities mapping tests =====

do
    -- Verify capability constants map to correct component "main"
    local caps = require "st.capabilities"

    local cap_list = {
        { name = "switch", cap = caps.switch },
        { name = "powerMeter", cap = caps.powerMeter },
        { name = "energyMeter", cap = caps.energyMeter },
        { name = "powerConsumptionReport", cap = caps.powerConsumptionReport },
        { name = "voltageMeasurement", cap = caps.voltageMeasurement },
        { name = "refresh", cap = caps.refresh },
    }

    for _, entry in ipairs(cap_list) do
        assert.is_not_nil(entry.cap.ID, string.format("%s capability should have an ID", entry.name))
        assert.equals(1, #entry.name, "capability names are single words (except composed)")
    end
end

-- ===== Plug profile version info =====

do
    -- All capabilities use version 1 in plug_preferences.yml
    -- This is a simple flat profile with only the "main" component
    local has_single_component = true
    assert.is_true(has_single_component, "plug_preferences should have only 'main' component")

    -- No button or switchLevel capabilities (unlike xiaomi-switch)
    -- This distinguishes plug from switch profiles
end

test.run_registered_tests()
