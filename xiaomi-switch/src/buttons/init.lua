local zcl_clusters = require "st.zigbee.zcl.clusters"

local OnOff = zcl_clusters.OnOff
local log = require "log"
local utils = require "utils"

local function on_off_attr_handler(_driver, device, value, zb_rx)
    local endpoint = zb_rx.address_header.src_endpoint.value

    local CLICK_TIMER  = string.format("button_timer%d", endpoint)
    local DOWN_COUNTER = string.format("down_counter%d", endpoint)

    local down_counter = device:get_field(DOWN_COUNTER)
    local click_timer = device:get_field(CLICK_TIMER)

    local timer_func = function()
        local f_down_counter = device:get_field(DOWN_COUNTER)
        log.debug("down_counter: " .. tostring(f_down_counter))

        local func_click_type = utils.click_types[f_down_counter]

        if func_click_type then
            utils.emit_button_event(device, endpoint, func_click_type({state_change = true}))
        end

        device:set_field(CLICK_TIMER, nil)
        device:set_field(DOWN_COUNTER, 0)
    end

    if click_timer then
        if value.value then
            down_counter = down_counter + 1
            device:set_field(DOWN_COUNTER, down_counter)
        end
    else
        if value.value then
            local timer = device.thread:call_with_delay(0.4, timer_func)
            device:set_field(CLICK_TIMER, timer)
            device:set_field(DOWN_COUNTER, 1)
        else
            log.warn("stray up event, from previous held?")
        end
    end
end

local button_handler = {
    NAME = "Button Handler",
    zigbee_handlers = {
        attr = {
            [OnOff.ID] = {
                [OnOff.attributes.OnOff.ID] = on_off_attr_handler
            }
        },
    },
    can_handle = function(_opts, _driver, device)
        return utils.first_switch_ep(device) < 1 and device:get_model() ~= "lumi.sensor_switch"
    end
}

return button_handler
