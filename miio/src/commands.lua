local caps = require('st.capabilities')
local utils = require('st.utils')
local log = require('log')
local json = require('dkjson')
--local packet = require('packet')
local socket = require('socket')
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
  return command_handler.send_lan_command(
    device, 'POST', 'ping', ping_data)
end
------------------
-- Refresh command
function command_handler.refresh(_, device)
  log.info('Refreshing device')
  local success, data = command_handler.send_lan_command(
    device, 'GET', 'state')

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

  local success, data = command_handler.send_lan_command(
    device, 'GET', 'effects/effectsList')
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
  local success = command_handler.send_lan_command(device, 'PUT', 'state', 
    {on={value=on_off}} )

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
  local success = command_handler.send_lan_command( device, 'PUT', 'state',   
    {brightness = {value = lvl }})

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
  
  -- no animation
  -- payload = {hue={value = hue}, sat={value = sat}}
  -- local success = command_handler.send_lan_command(device, 'PUT', 'state', payload)

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

------------------------
-- Send LAN HTTP Request
function command_handler.send_lan_command(device, method, body)
  local ip = device.device_network_id
  local port = 54321
  
  log.info('Sending command to ' .. ip .. ':' .. port)
  local udp = socket.udp()
  --assert(udp:setsockname("*", 0))
  --assert(udp:setoption('reuseaddr', true))
  --assert(udp:setoption("ip-add-membership", {multiaddr = ip, interface = "0.0.0.0"}), "join multicast group")
  assert(udp:settimeout(0.1))

  --local Array = require("lockbox.util.array")
  
  local handshake = Array.fromHex("21310020ffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
  -- send query
  log.info('sending command to ' .. ip .. ':' .. port .. ' ' .. method .. ' ' .. path)
  --assert(udp:sendto(packet.handshake, ip, port))
  local data, peeraddr, peerport = udp:receivefrom()
  print('>> peeraddr:', peeraddr, 'peerport:', peerport, 'data:', data)
        

  return false, nil
end

return command_handler