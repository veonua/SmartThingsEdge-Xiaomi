local Driver = require('st.driver')
local caps = require('st.capabilities')

-- local imports
local config = require('config')
local discovery = require('discovery')
local commands = require('commands')
local log = require('log')


local function device_removed(_self, device)
  log.warn("!!! Device removed: " .. device.device_network_id)
  commands.send_lan_command(device, 'DELETE', '')
end

local function device_added(_self, device)
  log.info("dicso.token:".. discovery.token)
  device:set_field('token', discovery.token, {persist=true})
  --device:refresh()
end

local function device_init(_driver, device)
  -- Refresh schedule
  device.thread:call_on_schedule(
    config.SCHEDULE_PERIOD,
    function ()

      return commands.refresh(nil, device, false)
    end,
    'Refresh schedule')
end

--------------------
-- Driver definition
local driver =
  Driver(
    'Nanoleaf',
    {
      discovery = discovery.start,
      supported_capabilities = {
        caps.switch,
        caps.switchLevel,
        caps.statelessSwitchLevelStep,
        caps.colorControl,
        caps.mediaPresets,
        caps.refresh
      },
      lifecycle_handlers = {
        added = device_added,
        removed = device_removed,
        init = device_init
      },
      capability_handlers = {
        [caps.switch.ID] = {
          [caps.switch.commands.on.NAME] = commands.on_off,
          [caps.switch.commands.off.NAME] = commands.on_off
        },
        [caps.switchLevel.ID] = {
          [caps.switchLevel.commands.setLevel.NAME] = commands.set_level
        },
        [caps.statelessSwitchLevelStep.ID] = {
          [caps.statelessSwitchLevelStep.commands.stepLevel.NAME] = commands.step_level
        },
        [caps.colorControl.ID] = {
          [caps.colorControl.commands.setColor.NAME] = commands.set_color
        },
        [caps.colorTemperature.ID] = {
          [caps.colorTemperature.commands.setColorTemperature.NAME] = commands.set_temp
        },
        [caps.mediaPresets.ID] = {
          [caps.mediaPresets.commands.playPreset.NAME] = commands.playPreset
        },
        [caps.refresh.ID] = {
          [caps.refresh.commands.refresh.NAME] = commands.refresh
        }
      }
    }
  )

---------------------------------------
-- Switch control for external commands
function driver:on_off(device, on_off)
  local _ = self
  if on_off == 'off' then
    return device:emit_event(caps.switch.switch.off())
  end
  return device:emit_event(caps.switch.switch.on())
end

---------------------------------------------
-- Switch level control for external commands
function driver:set_level(device, lvl)
  local _ = self
  if lvl == 0 then
    device:emit_event(caps.switch.switch.off())
  else
    device:emit_event(caps.switch.switch.on())
  end
  return device:emit_event(caps.switchLevel.level(lvl))
end

--------------------
-- Initialize Driver
driver:run()
