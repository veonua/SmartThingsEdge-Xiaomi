local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"

local OnOff = zcl_clusters.OnOff
local log = require "log"
local utils = require "utils"

local function on_off_attr_handler(_driver, device, value, zb_rx)
    local ep = zb_rx.address_header.src_endpoint.value
    local first_button_ep = utils.first_button_ep(device)

    if ep < first_button_ep  then -- handled by default handler
        local attr = capabilities.switch.switch
        device:emit_event_for_endpoint(ep, value.value and attr.on() or attr.off())
        return
    end

    local press_type = zb_rx.body_length.value>8 and capabilities.button.button.pushed or capabilities.button.button.held
    local text = zb_rx.body_length.value>8 and "pushed" or "held"

    log.info(" old button " .. tostring(text), value.value)
    if not value.value then
        -- press = off/on in the same message
        -- hold  = off, pause, on. so we emit only off
        utils.emit_button_event(device, ep, press_type({state_change = true}))
    end
    --old_button_handler(device, component_id, value)
end

--

-- local function info_changed(driver, device, event, args)
--     -- xiaomi_switch_operation_mode_basic
--     for id, value in pairs(device.preferences) do
--         if args.old_st_store.preferences[id] ~= value then --and preferences[id] then
--             local data = tonumber(device.preferences[id])

--             local attr
--             if id == "button1" then
--                 attr = 0xFF22
--             elseif id == "button2" then
--                 attr = 0xFF23
--             elseif id == "button3" then
--                 attr = 0xFF24
--             end

--             if attr then
--                 device:send(cluster_base.write_manufacturer_specific_attribute(device, zcl_clusters.basic_id, attr, 0x115F, data_types.Uint8, data) )
--             end
--         end
--     end
-- end

--

local old_switch_handler = {
    NAME = "Old Switch Handler",
    zigbee_handlers = {
        attr = {
            [OnOff.ID] = {
                [OnOff.attributes.OnOff.ID] = on_off_attr_handler
            }
        },
    },
    can_handle = function(_opts, _driver, device)
        return utils.first_switch_ep(device) > 0 and utils.first_button_ep(device) == 4
    end
}

return old_switch_handler
