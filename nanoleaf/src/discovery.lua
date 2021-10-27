local socket = require('socket')
local http = require('socket.http')
local ltn12 = require('ltn12')
local log = require('log')
local config = require('config')

-----------------------
-- SSDP Response parser
local function parse_ssdp(data)
  local res = {}
  log.debug("Parsing SSDP response" .. tostring(data))
  res.status = data:sub(0, data:find('\r\n'))
  for k, v in data:gmatch('([%w-]+): ([%a+-: _/=]+)') do
    res[k:lower()] = v
    log.debug(tostring(k) .. ': ' .. tostring(v))
  end
  return res
end

-- This function enables a UDP
-- Socket and broadcast a single
-- M-SEARCH request, i.e., it
-- must be looped appart.
local function find_device()
  -- UDP socket initialization
  local upnp = socket.udp()
  upnp:setsockname('*', 0)
  upnp:setoption('broadcast', true)
  upnp:settimeout(config.MC_TIMEOUT)

  -- broadcasting request
  log.info('===== SCANNING NETWORK...')
  upnp:sendto(config.MSEARCH, config.MC_ADDRESS, config.MC_PORT)

  -- Socket will wait n seconds
  -- based on the s:setoption(n)
  -- to receive a response back.
  local res = upnp:receivefrom()

  -- close udp socket
  upnp:close()

  if res ~= nil then
    return res
  end
  return nil
end

local function create_device(driver, device)
  log.info('===== CREATING DEVICE...')
  log.info('===== DEVICE DESTINATION ADDRESS: '..device['location'])
  
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
  
  local location = device['location']
  location = location:sub(7,-1)
  
  log.info('===== DEVICE : '..manufacturer..' '..model ..' @ '..location)
  
  -- device metadata table
  local metadata = {
    type = config.DEVICE_TYPE,
    device_network_id = device['location'],
    label = device['nl-devicename'],
    profile = config.DEVICE_PROFILE,
    manufacturer = manufacturer,
    model = model,
    vendor_provided_label = device['nl-deviceid'],
  }
  return driver:try_create_device(metadata)
end

-- Discovery service which will
-- invoke the above private functions.
--    - find_device
--    - parse_ssdp
--    - create_device
--
-- This resource is linked to
-- driver.discovery and it is
-- automatically called when
-- user scan devices from the
-- SmartThings App.
local disco = {}
function disco.start(driver, opts, cons)
  while true do
    local device_res = find_device()

    if device_res ~= nil then
      device_res = parse_ssdp(device_res)
      log.info('===== DEVICE FOUND IN NETWORK...')
      return  create_device(driver, device_res)
    else
      log.warn('===== DEVICE NOT FOUND IN NETWORK')
    end
  end
end

return disco