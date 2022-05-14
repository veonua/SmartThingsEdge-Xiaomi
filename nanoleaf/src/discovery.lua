local socket = require('socket')
local cosock = require "cosock"
local http = cosock.asyncify "socket.http"
local ltn12 = require('ltn12')
local log = require('log')
local config = require('config')
local json = require('dkjson')

local function parse_ssdp(data)
  local res = {}
  log.debug("Parsing SSDP response")
  res.status = data:sub(0, data:find('\r\n'))
  for k, v in data:gmatch('([%w-]+): ([%a+-: _/=]+)') do
    res[k:lower()] = v
    --log.debug(tostring(k) .. ': ' .. tostring(v))
  end
  return res
end

local function find_device()
  local upnp = socket.udp()
  upnp:setsockname('*', 0)
  upnp:setoption('broadcast', true)
  upnp:settimeout(config.MC_TIMEOUT)

  --- log.info('===== SCANNING NETWORK...')
  upnp:sendto(config.MSEARCH, config.MC_ADDRESS, config.MC_PORT)
  local res = upnp:receivefrom()
  upnp:close()
  return res
end

local function try_get_token(device)
  local device_location = device['location'].."/api/v1/new"
  
  local res_body = {}
  local _, code = http.request(
    {
      url = device_location,
      method = 'POST',
      sink   = ltn12.sink.table(res_body),
      headers = {
        ['Accept'] = 'application/json',
        ['Content-Type'] = 'application/json'
      }
    }
  )

  log.debug("POST " .. device_location.. ": " .. tostring(code))
  if code / 100 == 2 then
    return json.decode(table.concat(res_body))['auth_token']
  end
  return nil
end

local function create_device(driver, token, device)
-- ST: nanoleaf_aurora:light
-- USN: uuid:77b0da8f-ea1a-464a-a279-6383afd2d6f4
-- Location: http://192.168.0.155:16021
-- nl-deviceid: 9A:77:69:B5:3E:0B
-- nl-devicename: Light Panels 51:f8:29

  local st  = device['st']
  st = st:sub(0, st:find(':')-1)
  local del = st:find('_')
  local manufacturer = st:sub(1, del-1)
  local model        = st:sub(del+1)
  
  local location = device['location'] .. "/api/v1/" .. token
  
  log.info('===== DEVICE : '..manufacturer..' '..model ..' @ '..location)
  
  -- device metadata table
  local metadata = {
    type = config.DEVICE_TYPE,
    device_network_id = location,--device['location'],
    label = device['nl-devicename'],
    profile = config.DEVICE_PROFILE,
    manufacturer = manufacturer,
    model = model,
    vendor_provided_label = device['nl-deviceid'],
  }
  return driver:try_create_device(metadata)
end

local disco = {}
function disco.start(driver, opts, cons)
  local iterations = 20
  while iterations > 0 do
    iterations = iterations - 1
    local device_res = find_device()

    if device_res ~= nil then
      device_res = parse_ssdp(device_res)
      token = try_get_token(device_res)
      if token ~= nil then
        local device = create_device(driver, token, device_res)
        disco.token = token

        --local device_list = driver:get_devices()
        -- device = device_list[device]
        --log.info('dev: '..tostring( json.encode(device) ))
        log.info('>token: '..token)
        return device
      end
    else
      ---log.warn('===== DEVICE NOT FOUND IN NETWORK')
    end
  end
end

return disco