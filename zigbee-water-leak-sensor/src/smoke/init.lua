local capabilities = require "st.capabilities"
local defaults = require "st.zigbee.defaults"

local smoke_handler = {
    NAME = "Smoke",
    supported_capabilities = {
        capabilities.smokeDetector,
        capabilities.battery,
        capabilities.refresh,
    },
    can_handle = function(opts, driver, device)
        return device:get_model() == "lumi.sensor_smoke"
    end
}

defaults.register_for_default_handlers(smoke_handler, smoke_handler.supported_capabilities)
return smoke_handler
