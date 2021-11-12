local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"

local OnOff = zcl_clusters.OnOff
local log = require "log"
local utils = require "utils"
local socket = require "socket"

local CLICK_TIMER = "timer"

function on_off_attr_handler(driver, device, value, zb_rx)
    local held = function()
        device:emit_event(capabilities.button.button.held({state_change = true}))
        device:set_field(CLICK_TIMER, nil)
    end

    local timer = device:get_field(CLICK_TIMER)
    if not value.value then -- press
        timer = device.thread:call_with_delay(1, held)
        device:set_field(CLICK_TIMER, timer)
    elseif timer then -- release
        device.thread:cancel_timer(timer)
        device:set_field(CLICK_TIMER, nil)
        device:emit_event(capabilities.button.button.pushed({state_change = true})) 
    end
end

function multi_click_handler(driver, device, zb_rx)
    local val = zb_rx.value
    if val>4 then -- we don't count after 4
        val = 5 
    end

    local click_type = utils.click_types[val+1]
    if click_type then
        device:emit_event(click_type({state_change = true}))
    end
end

local wxkg_handler = {
    NAME = "WXKG01LM",
    zigbee_handlers = {
        attr = {
            [OnOff.ID] = {
                [OnOff.attributes.OnOff.ID] = on_off_attr_handler,
                [0x8000] = multi_click_handler,
            }
        },
    },
    can_handle = function(opts, driver, device)
        return device:get_model() == "lumi.sensor_switch"
    end
}

return wxkg_handler
