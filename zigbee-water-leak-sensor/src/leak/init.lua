local capabilities = require "st.capabilities"
local defaults = require "st.zigbee.defaults"

local leak_handler = {
    NAME = "Leak",
    supported_capabilities = {
        capabilities.waterSensor,
        capabilities.battery,
        capabilities.refresh,
    },
    can_handle = function(opts, driver, device)
        local model = device:get_model()
        return model == "lumi.sensor_wleak.aq1" or model == "TS0207"
    end
}

defaults.register_for_default_handlers(leak_handler, leak_handler.supported_capabilities)
return leak_handler
