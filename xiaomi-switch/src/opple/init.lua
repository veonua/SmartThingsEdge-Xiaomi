-- https://github.com/Koenkk/zigbee-herdsman-converters/blob/master/devices/xiaomi.js
local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"

local log = require "log"
local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"
local xiaomi_utils = require "xiaomi_utils"
local zigbee_utils = require "zigbee_utils"

local OnOff = zcl_clusters.OnOff
local Level = zcl_clusters.Level
local Scenes = zcl_clusters.Scenes
local ColorControl = zcl_clusters.ColorControl
local PowerConfiguration = zcl_clusters.PowerConfiguration
local Groups = zcl_clusters.Groups

local MFG_CODE = 0x115F
local PRIVATE_ATTRIBUTE_ID = 0x0009
local KNOB_SENSITIVITY_ATTR_ID = 0x0234
local KNOB_SENSITIVITY_LOOKUP = {720, 360, 180}

local EVENTS_WHILE_OFF_MODE = 0x02
local KD_R01D_MODEL = "lumi.switch.agl011"
local KD_R01D_PROFILE_EVENTS = "switch-kd-r01d"
local KD_R01D_PROFILE_BASIC = "switch-kd-r01d-basic"

local OPPLE_FINGERPRINTS = {
    { model = "^lumi.switch...aeu1" },
    { model = "^lumi.switch.agl011" },
    { model = "^lumi.switch.b.lc04" },
    { model = "^lumi.switch..3acn." },
    { model = "^lumi.switch.acn05[58]$" },
    { model = "^lumi.remote.b.8" },
    { model = "^lumi.remote.rkba01" }, -- NEW
}

local is_opple = function(_opts, _driver, device)
    for _, fingerprint in ipairs(OPPLE_FINGERPRINTS) do
        if (device:get_model():find(fingerprint.model) ~= nil) then
            return true
        end
    end
    return false
end

local send_opple_message = function (device, attr, payload, endpoint)
    local message = cluster_base.write_attribute(
        device,
        data_types.ClusterId(xiaomi_utils.OppleCluster),
        data_types.AttributeId(attr),
        payload
    )
    message.body.zcl_header.frame_ctrl:set_mfg_specific()
    message.body.zcl_header.mfg_code = data_types.validate_or_build_type(MFG_CODE, data_types.Uint16, "mfg_code")
    if (endpoint ~= nil) then
        message:to_endpoint(endpoint)
    end
    device:send(message)
end

local function get_off_state_event_mode(device)
    local pref = device.preferences and (device.preferences.offStateEventMode or device.preferences.clickMode)
    return tonumber(pref) or EVENTS_WHILE_OFF_MODE
end

local function sync_profile(device)
    if device:get_model() ~= KD_R01D_MODEL then return end

    local mode = get_off_state_event_mode(device)
    local target_profile = mode == EVENTS_WHILE_OFF_MODE and KD_R01D_PROFILE_EVENTS or KD_R01D_PROFILE_BASIC
    local current_profile = device.profile and device.profile.name or ""

    if current_profile ~= target_profile then
        device:try_update_metadata({ profile = target_profile })
    end
end

local function switch_on(_driver, device, command)
    local attr = capabilities.switch.switch
    if command.component == "main" then
        log.info(string.format("opple switch_on main: device=%s", device.id))
        local level = device:get_latest_state(
            "main",
            capabilities.switchLevel.ID,
            capabilities.switchLevel.level.NAME
        ) or 0
        local kick_threshold = device.preferences and device.preferences.kickOffThreshold or 0
        kick_threshold = tonumber(kick_threshold) or 0
        if kick_threshold < 0 then kick_threshold = 0 end
        if kick_threshold > 100 then kick_threshold = 100 end

        device:send(zcl_clusters.OnOff.commands.On(device):to_endpoint(device.fingerprinted_endpoint_id))
        if level > 0 and level < kick_threshold then
            local kick_zb_level = math.floor((kick_threshold * 254) / 100)
            local target_zb_level = math.floor((level * 254) / 100)

            log.info(string.format("opple kick-off: level=%s threshold=%s", tostring(level), tostring(kick_threshold)))
            device:send(
                zcl_clusters.Level.commands.MoveToLevelWithOnOff(device, kick_zb_level, 0)
                    :to_endpoint(device.fingerprinted_endpoint_id)
            )

            device.thread:call_with_delay(1, function()
                log.info(string.format("opple kick-off: dim to target=%s", tostring(level)))
                device:send(
                    zcl_clusters.Level.commands.MoveToLevel(device, target_zb_level, 5)
                        :to_endpoint(device.fingerprinted_endpoint_id)
                )
            end)

            device:emit_event_for_endpoint(device.fingerprinted_endpoint_id, attr.on())
        else
            device:emit_event_for_endpoint(device.fingerprinted_endpoint_id, attr.on())
            -- device.thread:call_with_delay(1, function()
            --     device:emit_event_for_endpoint(device.fingerprinted_endpoint_id, attr.off())
            -- end)
        end
    else
        log.info(string.format("opple switch_on component: %s", command.component))
        device:send_to_component(command.component, zcl_clusters.OnOff.server.commands.On(device))
    end
end

local function switch_off(_driver, device, command)
    local attr = capabilities.switch.switch
    if command.component == "main" then
        log.info(string.format("opple switch_off main: device=%s", device.id))
        device:send(zcl_clusters.OnOff.commands.Off(device):to_endpoint(device.fingerprinted_endpoint_id))
        device:emit_event_for_endpoint(device.fingerprinted_endpoint_id, attr.off())
    else
        log.info(string.format("opple switch_off component: %s", command.component))
        device:send_to_component(command.component, zcl_clusters.OnOff.server.commands.Off(device))
    end
end
---

local do_refresh = function(_self, device)
    device:send(PowerConfiguration.attributes.BatteryVoltage:read(device))

    device:send(
        cluster_base.read_manufacturer_specific_attribute(
            device,
            xiaomi_utils.OppleCluster,
            PRIVATE_ATTRIBUTE_ID,
            MFG_CODE
        )
    )
    -- device:send(
    --     cluster_base.read_manufacturer_specific_attribute(
    --         device,
    --         xiaomi_utils.OppleCluster,
    --         0x0125,
    --         MFG_CODE
    --     )
    -- )
    zigbee_utils.print_clusters(device)
    device:send(Groups.server.commands.GetGroupMembership(device, {}))
    log.info("---")
    device:send( zigbee_utils.build_read_binding_table(device) )
    log.info("~~~")
end


-- Zigbee 3 device supports two operation modes:
-- 0: Direct mode is not well supported by ST and sends switch/light/color
--    commands directly to the target device or group.
--    Binding request is mandatory, in other way commands will be sent to all connected devices
-- 1: Normal mode which sends button click messages to the hub, and actions can be reprogrammed by the user
local do_configure = function(_self, device)
    sync_profile(device)
    device:configure()
    local operationMode = device.preferences.operationMode or 1
    operationMode = tonumber(operationMode)

    log.info("Configuring Opple device " .. tostring(operationMode))

    data_types.id_to_name_map[0xE10] = "OctetString"
    data_types.name_to_id_map["SpecialType"] = 0xE10
    -- Equivalent manufacturer-specific write reference:
    -- cluster_base.write_manufacturer_specific_attribute(...)

    send_opple_message(device, PRIVATE_ATTRIBUTE_ID, data_types.Uint8(operationMode), 0x01)

    if operationMode == 1 then -- button events
        -- offStateEventMode controls how events are generated while relay output is off:
        -- 1 = single press only (faster), 2 = multi-click + knob events.
        -- Equivalent write:
        -- cluster_base.write_manufacturer_specific_attribute(...)

        local click_mode = get_off_state_event_mode(device)

        send_opple_message(device, 0x0286, data_types.Uint8(click_mode), 0x01) -- for new devices
        send_opple_message(device, 0x0125, data_types.Uint8(click_mode), 0x01)
    elseif operationMode == 0 then      -- light group binding
        local group = device.preferences.group or 1
        group = tonumber(group)

        device:send(zigbee_utils.build_bind_request(device, OnOff.ID, group))
        device:send(zigbee_utils.build_bind_request(device, Level.ID, group))
        device:send(zigbee_utils.build_bind_request(device, Scenes.ID, group))
        device:send(zigbee_utils.build_bind_request(device, ColorControl.ID, group))
        device:send(zigbee_utils.build_read_binding_table(device))
    end

    if device:supports_capability(capabilities.battery, "main") then
        -- TODO: update to device:add_configured_attribute(attribute)
        device:send(
            PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(
                device,
                30,
                21600,
                1
            )
        )
        device:send(
            PowerConfiguration.attributes.BatteryVoltage:configure_reporting(
                device,
                30,
                21600,
                1
            )
        )
    end
end

local function info_changed(driver, device, event, args)
    log.info(tostring(event))
    -- For reference: zigbee-herdsman-converters converters/toZigbee.js
    for id, value in pairs(device.preferences) do
        if args.old_st_store.preferences[id] ~= value then
            --local data = tonumber(device.preferences[id])
            -- if device.preferences[id] is number, then data will be number, otherwise it will be string

            local data = device.preferences[id]
            data = tonumber(data) or data

            local attr
            local payload
            local endpoint

            if id == "operationMode" then
                do_configure(driver, device)
            elseif id == "offStateEventMode" or id == "clickMode" then
                sync_profile(device)
                local click_mode = tonumber(data) or EVENTS_WHILE_OFF_MODE
                send_opple_message(device, 0x0286, data_types.Uint8(click_mode), 0x01) -- for new devices
                send_opple_message(device, 0x0125, data_types.Uint8(click_mode), 0x01)
            elseif id == "group" then
                device:send(zigbee_utils.build_bind_request(device, OnOff.ID, data))
                device:send(zigbee_utils.build_bind_request(device, Level.ID, data))
                device:send(zigbee_utils.build_bind_request(device, Scenes.ID, data))
                device:send(zigbee_utils.build_bind_request(device, ColorControl.ID, data))
            elseif id == "stse.restorePowerState" then
                payload = data_types.validate_or_build_type(data, data_types.Boolean, id)
                attr = 0x0201
            elseif id == "stse.turnOffIndicatorLight" then
                payload = data_types.validate_or_build_type(not data, data_types.Boolean, id)
                attr = 0x0203
            elseif id == "stse.changeToWirelessSwitch" then
                attr = 0x0200
                endpoint = 1
                payload = data_types.validate_or_build_type(data and 0 or 1, data_types.Uint8, id)
            elseif id == "button1" then
                attr = 0x0200
                endpoint = 1
                payload = data_types.validate_or_build_type(data<0xF0 and 1 or 0, data_types.Uint8, id)
            elseif id == "button2" then
                attr = 0x0200
                endpoint = 2
                payload = data_types.validate_or_build_type(data<0xF0 and 1 or 0, data_types.Uint8, id)
            elseif id == "button3" then
                attr = 0x0200
                endpoint = 3
                payload = data_types.validate_or_build_type(data<0xF0 and 1 or 0, data_types.Uint8, id)
            elseif id == "minBrightness" then
                local v = tonumber(data) or 0
                if v < 0 then v = 0 end
                if v > 99 then v = 99 end
                attr = 0x0515
                payload = data_types.validate_or_build_type(v, data_types.Uint8, id)
            elseif id == "maxBrightness" then
                local v = tonumber(data) or 100
                if v < 1 then v = 1 end
                if v > 100 then v = 100 end
                attr = 0x0516
                payload = data_types.validate_or_build_type(v, data_types.Uint8, id)
            elseif id == "phase" then
                local v = tonumber(data) or 0
                attr = 0x030A
                payload = data_types.validate_or_build_type(v, data_types.Uint8, id)
            elseif id == "stse.knobSensitivity" then
                local v = KNOB_SENSITIVITY_LOOKUP[tonumber(data)] or 360
                attr = KNOB_SENSITIVITY_ATTR_ID
                payload = data_types.validate_or_build_type(v, data_types.Uint16, id)
            end

            if attr then
                send_opple_message(device, attr, payload, endpoint)
            end
        end
    end
end


local function attr_operation_mode_handler(_driver, device, value, _zb_rx)
    log.info("attr_operation_mode_handler " .. tostring(value))
    device:set_field("operationMode", value.value, {persist = true})
end

local function battery_level_handler(_driver, device, value, _zb_rx)
  local voltage = value.value
  local batteryLevel = "normal"

  if voltage <= 25 then
    batteryLevel = "critical"
  elseif voltage < 28 then
    batteryLevel = "warning"
  end

  device:emit_event(capabilities.batteryLevel.battery(batteryLevel))
end

local switch_handler = {
    NAME = "Zigbee3 Aqara/Opple",
    capability_handlers = {
        [capabilities.switch.ID] = {
            [capabilities.switch.commands.on.NAME] = switch_on,
            [capabilities.switch.commands.off.NAME] = switch_off,
        },
        [capabilities.refresh.ID] = {
          [capabilities.refresh.commands.refresh.NAME] = do_refresh,
        }
    },
    zigbee_handlers = {
        attr = {
            [xiaomi_utils.OppleCluster] = {
                [PRIVATE_ATTRIBUTE_ID] = attr_operation_mode_handler,
                [0x00F7] = xiaomi_utils.handler
            },
            [PowerConfiguration.ID] = {
                [PowerConfiguration.attributes.BatteryVoltage.ID] = battery_level_handler
            }
        }
    },
    lifecycle_handlers = {
        infoChanged = info_changed,
        doConfigure = do_configure,
    },
    can_handle = is_opple
}

return switch_handler
