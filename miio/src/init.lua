local Driver = require('st.driver')
local caps = require('st.capabilities')

-- local imports
local discovery = require('discovery')
local commands = require('commands')
local log = require('log')
local json = require('dkjson')
local stutils = require('st.utils')

local function device_added(self, device)
  log.info(stutils.stringify_table(device, "device"))
  --device:set_field('token', discovery.token, {persist=true})
  --device:refresh()
end

--------------------
-- Driver definition
local driver =
  Driver(
    'Miio',
    {
      discovery = discovery.start,
      supported_capabilities = {
        caps.refresh
      },
      lifecycle_handlers = {
        added = device_added
      },
      capability_handlers = {
        [caps.refresh.ID] = {
          [caps.refresh.commands.refresh.NAME] = commands.refresh
        }
      }
    }
  )


--------------------
-- Initialize Driver
driver:run()