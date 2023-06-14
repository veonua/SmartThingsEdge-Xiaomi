local capabilities = require "st.capabilities"
local log = require "log"
--local json = require "dkjson"

utils = {}

function utils.first_switch_ep(device)
    return device:get_field("first_switch_ep") or 0
end

function utils.first_button_ep(device)
    return device:get_field("first_button_ep") or 0
end

function utils.first_button_group_ep(device)
    return device:get_field("first_button_group_ep") or 999
end

function utils.emit_button_event(device, ep, event)
    local all_buttons_ep = utils.first_button_group_ep(device)
    
    local splitEvents = device.preferences['splitEvents'] or '0'
    if ep < all_buttons_ep or splitEvents == '1' then -- broadcast event to all buttons
        device:emit_event_for_endpoint(ep, event)
    else
        local first_button_ep = utils.first_button_ep(device)
        for i = first_button_ep, all_buttons_ep-1 do
            device:emit_event_for_endpoint(i, event)
        end
    end
end

utils.click_types = {
    [0] = capabilities.button.button.held,
    [1] = capabilities.button.button.pushed, 
    [2] = capabilities.button.button.pushed_2x, 
    [3] = capabilities.button.button.pushed_3x, 
    [4] = capabilities.button.button.pushed_4x,
    [5] = capabilities.button.button.pushed_5x,
    [0x10] = capabilities.button.button.held,
    [0x11] = nil, -- released
    [0xff] = nil, 
}

return utils