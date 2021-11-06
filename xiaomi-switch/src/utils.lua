
local capabilities = require "st.capabilities"

utils = {}

function utils.first_switch_ep(device)
    return device:get_field("first_switch_ep") or 0
end

function utils.first_button_ep(device)
    return device:get_field("first_button_ep") or 0
end

utils.click_types = {
    capabilities.button.button.held,
    capabilities.button.button.pushed, 
    capabilities.button.button.double, 
    capabilities.button.button.pushed_3x, 
    capabilities.button.button.pushed_4x
}

return utils