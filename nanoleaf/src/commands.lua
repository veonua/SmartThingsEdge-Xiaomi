local caps = require('st.capabilities')
local utils = require('st.utils')
local neturl = require('net.url')
local log = require('log')
local json = require('dkjson')
local http = require('socket.http')
local ltn12 = require('ltn12')

local command_handler = {}

function command_handler.new(_, device)
  local token = command_handler.send_lan_command(device, 'POST', 'new')
  device:set_field('token', token, {persist = true})
  return token
end
---------------
-- Ping command
function command_handler.ping(address, port, device)
  local ping_data = {ip=address, port=port, ext_uuid=device.id}
  return command_handler.send_lan_command(device, 'POST', 'ping', ping_data)
end
------------------
-- Refresh command
function command_handler.refresh(_, device)
  local success, data = command_handler.send_lan_command(device, 'GET', 'state')

  -- Check success
  if success then
    local raw_data = json.decode(table.concat(data))
    device:online()
    device:emit_event(caps.switchLevel.level(raw_data.brightness.value))
    if raw_data.on.value==false then
      device:emit_event(caps.switch.switch.off())
    else
      device:emit_event(caps.switch.switch.on())
    end

    device:emit_event(caps.colorControl.saturation(raw_data.sat.value))
    device:emit_event(caps.colorControl.hue(raw_data.hue.value))
    device:emit_event(caps.colorTemperature.colorTemperature(raw_data.ct.value))
  else
    log.error('failed to poll device state')
    device:offline()
  end

  local success, data = command_handler.send_lan_command(device, 'GET', 'effects/effectsList')
  if success then
    local raw_data = json.decode(table.concat(data))
    local presets = {}

    for id, effect in ipairs(raw_data) do
      table.insert(presets, {id=effect, name=effect}) -- tostring(id)
    end
    device:emit_event(caps.mediaPresets.presets({ value = presets }))
  end
end

function command_handler.on_off(_, device, command)
  local on_off = command.command == 'on'
  local success = command_handler.send_lan_command(device, 'PUT', 'state', {on={value=on_off}} )

  if success then
    if on_off then
      return device:emit_event(caps.switch.switch.on())
    end
    return device:emit_event(caps.switch.switch.off())
  end
  log.error('no response from device')
end

function command_handler.set_level(_, device, command)
  local lvl = command.args.level
  local success = command_handler.send_lan_command( device, 'PUT', 'state', {brightness = {value = lvl }})

  if success then
    if lvl == 0 then
      device:emit_event(caps.switch.switch.off())
    else
      device:emit_event(caps.switch.switch.on())
    end
    device:emit_event(caps.switchLevel.level(lvl))
    return
  end
  log.error('no response from device')
end

function command_handler.set_color(_, device, command)
  local hue = math.floor(command.args.color.hue * 360 / 100)
  local sat = math.floor(command.args.color.saturation)

  local palette = {
    { hue= hue, saturation= sat, brightness= 60 },
    { hue= hue, saturation= sat, brightness= 80 },
    { hue= hue, saturation= sat, brightness= 100 }
  }
  
  local transTime = { minValue= 0, maxValue= 20 }
  local delayTime = { minValue= 0, maxValue= 3 }
  local payload = { write = {
    command= "display", version= "2.0", animType= "random", 
    colorType= "HSB", transTime= transTime,  palette= palette --    //delayTime= delayTime,
  } }

  local success = command_handler.send_lan_command(device, 'PUT', 'effects', payload)
  
  -- Check if success
  if success then
    device:emit_event(caps.switch.switch.on())
    device:emit_event(caps.colorControl.saturation(sat))
    device:emit_event(caps.colorControl.hue(hue))
    return
  end
  log.error('no response from device')
end

function command_handler.set_temp(_, device, command)
  local ct = command.args.temperature

  local success = command_handler.send_lan_command(device, 'PUT', 'state', {ct={value = ct}})

  if success then
    device:emit_event(caps.switch.switch.on())
    device:emit_event(caps.colorTemperature.colorTemperature({ value = ct }))
    return
  end
  log.error('no response from device')
end

function command_handler.playPreset(_, device, command)
  local id = command.args.presetId
  local success = command_handler.send_lan_command(device, 'PUT', 'effects', {select=id})

  if success then
    return
  end
  log.error('no response from device')
end

----
local capabilities = require('st.capabilities')
local level_Steps = capabilities["legendabsolute60149.levelSteps"]
local color_Temperature_Steps = capabilities["legendabsolute60149.colorTemperatureSteps"]

function command_handler.level_Steps_handler(_, device, command)
  local level = command.args.value
  device:emit_event(level_Steps.levelSteps(level))
  
  local prev_level = device:get_latest_state("main", caps.switchLevel.ID, caps.switchLevel.level.NAME)
  
  level = utils.round( utils.clamp_value( math.floor( level + prev_level ), 2, 100 ) )
  print("new Level value =", level, "Prev value =", prev_level)
  
  command.args.level = level
  command_handler.set_level(_, device, command)
end


function command_handler.color_Temperature_Steps_handler(self, device, command)
    ---Next Color Temperature calculation
    local colorTemp = command.args.value
    device:emit_event(color_Temperature_Steps.colorTempSteps(colorTemp))
    print("Last Color Temperature =", device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME))
    colorTemp = utils.clamp_value( colorTemp + device:get_latest_state("main", capabilities.colorTemperature.ID, capabilities.colorTemperature.colorTemperature.NAME), 
                                   2700, 6000 )
    print("colorTemp", colorTemp)

    command.args.temperature = math.floor(colorTemp)
    command_handler.set_temp(_, device, command)
end

------------------------
-- Send LAN HTTP Request
function command_handler.send_lan_command(device, method, path, body)
  
  local device_network_id = device.device_network_id
  if device_network_id == "http://192.168.0.155:16021/api/v1/b7uFIgZ1MywU0r6FW6ECPxMqAnHm3BgZ" then
   log.info("patch on fly")
   device_network_id = "http://192.168.0.155:16021/api/v1/fvTBDLvOXYJ2UR6mQz7P6oSqYfLrmViU"
  end
 
  local dest_url = device_network_id .. '/' ..path
  local source
  local payload = ''
  if body then
    payload = json.encode(body)
    log.trace(method .. ' ' .. dest_url)
    log.trace(payload)
    source = ltn12.source.string(payload)
  end
  local res_body = {}

  -- HTTP Request
  local _, code = http.request({
    method=method,
    url=dest_url,
    source = source,
    sink   = ltn12.sink.table(res_body),
    headers={
      ['Content-Type'] = "application/json",
      ["Content-Length"] = payload:len()
    }})

  log.trace("code:"..tostring( code ))
  -- Handle response
  if code < 300 then
    return true, res_body
  end
  return false, nil
end

return command_handler