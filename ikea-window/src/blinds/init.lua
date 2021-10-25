local zcl_clusters = require "st.zigbee.zcl.clusters"
local capabilities = require "st.capabilities"

local WindowCovering = zcl_clusters.WindowCovering

local log = require "log"

local function added_handler(self, device)
    device:emit_event(capabilities.windowShade.supportedWindowShadeCommands({ value = { "open", "close", "pause"} }))
    device:refresh()
end

local blinds_handler = {
    NAME = "Blinds Handler",
    supported_capabilities = {
        capabilities.windowShade,
        capabilities.windowShadeLevel,
        capabilities.windowShadePreset,
        capabilities.battery,
        capabilities.refresh,
    },
    lifecycle_handlers = {
        added = added_handler,
    },
    capability_handlers = {
        [capabilities.refresh.ID] = {
          [capabilities.refresh.commands.refresh.NAME] = do_refresh,
        },
      },
    zigbee_handlers = {
    },
    can_handle = function(opts, driver, device)
        return true
    end
}

return blinds_handler
