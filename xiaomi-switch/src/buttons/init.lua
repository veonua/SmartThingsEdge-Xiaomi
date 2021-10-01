local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"

local OnOff = zcl_clusters.OnOff
local log = require "log"

function on_off_attr_handler(driver, device, value, zb_rx)
    local click_type = zb_rx.body_length.value>8 and capabilities.button.button.pushed or capabilities.button.button.held
    if not value.value then
        device:emit_event_for_endpoint(zb_rx.address_header.src_endpoint.value, click_type({state_change = true}))
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
    can_handle = function(opts, driver, device)
        return device:get_field("first_switch_ep") < 1
    end
}

return button_handler
