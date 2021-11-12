
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

function utils.last_button_ep(device)
    return device:get_field("last_button_ep") or 0
end

function utils.emit_button_event(device, ep, event)
    local all_buttons_ep = device:get_field("last_button_ep") or 0
    local eps = {ep}
    if ep == all_buttons_ep then -- broadcast event to all buttons
        local first_button_ep = utils.first_button_ep(device)
        for i = first_button_ep, all_buttons_ep-1 do
            table.insert(eps, i)
        end
    end

    --log.info("emitting ", json.encode(eps))
    for _, _ep in ipairs(eps) do
        device:emit_event_for_endpoint(_ep, event)
    end
end

utils.click_types = {
    capabilities.button.button.held,
    capabilities.button.button.pushed, 
    capabilities.button.button.pushed_2x, 
    capabilities.button.button.pushed_3x, 
    capabilities.button.button.pushed_4x
}

return utils