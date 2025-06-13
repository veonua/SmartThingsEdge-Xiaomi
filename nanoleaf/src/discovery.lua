local socket = require('socket')
local cosock = require "cosock"
local http = cosock.asyncify "socket.http"
local ltn12 = require('ltn12')
local log = require('log')
local config = require('config')
local json = require('dkjson')
local mdns = require("st.mdns")

local function parse_ssdp(data)
  local res = {}
  log.debug("Parsing SSDP response")
  res.status = data:sub(0, data:find('\r\n'))
  for k, v in data:gmatch('([%w-]+): ([%a+-: _/=]+)') do
    res[k:lower()] = v
    log.debug(tostring(k) .. ': ' .. tostring(v))
  end
  
  return res
end

local function decode_text(ascii_array)
  local str = ""
  for _, ascii_val in ipairs(ascii_array) do
    str = str .. string.char(ascii_val)
  end
  
  local key, value = string.match(str, "([^=]+)=([^=]+)")
  return key, value
end

local function scanNetwork()
  local discover_responses = mdns.discover("_nanoleafapi._tcp", "local") or {}
  --log.debug("Found mdns devices: " .. json.encode(discover_responses))

  if discover_responses == nil then
    return {}
  end

  -- Example response:
  -- [{
  --  "service_info":{
  --     "name":"Light Panels 51:F8:29",
  --     "domain":"local",
  --     "service_type":"_nanoleafapi._tcp"
  --  },
  --  "host_info":{
  --     "name":"Light-Panels-51-f8-29.local",
  --     "address":"192.168.0.155",
  --     "port":16021
  --  },
  --  "iface_info":{
  --     "name":"eth0",
  --     "idx":2
  --  }
  -- }]

  local res = discover_responses.found or {}

  -- decode txt.text
  for _, row in ipairs(res) do
    row.extra = {}
    if row.txt and row.txt.text then
      for i, text_array in ipairs(row.txt.text) do
        local key, value = decode_text(text_array)
        row.extra[key] = value
      end
    end
  end

  return res
end

local function try_get_token(device_url)
  local url = device_url.."new"
  local res_body = {}
  local _, code = http.request(
    {
      url = device_url.."new", 
      method = 'POST',
      sink   = ltn12.sink.table(res_body),
      headers = {
        ['Accept'] = 'application/json',
        ['Content-Type'] = 'application/json'
      }
    }
  )

  if code == nil then
    return nil
  end

  log.debug("POST " .. url.. ": " .. tostring(code))
  if  code / 100 == 2 then
     local decoded_body = json.decode(table.concat(res_body))
     if decoded_body and decoded_body['auth_token'] then
       return decoded_body['auth_token']
     end
     return nil
  end
  return nil
end

local function create_device(driver, device_network_id, scan_result)
  local manufacturer = "Nanoleaf"
  
  service_info = scan_result['service_info']
  extra = scan_result['extra']
  local model = extra['md']
  

  log.info('===== DEVICE : '..manufacturer..' '..model ..' @ '..device_network_id)
  
  -- device metadata table
  local metadata = {
    type = config.DEVICE_TYPE,
    device_network_id = device_network_id,
    label = service_info['name'],
    profile = config.DEVICE_PROFILE,
    manufacturer = manufacturer,
    model = model,
    vendor_provided_label = extra['id'],
  }
  return driver:try_create_device(metadata)
end

local disco = {}
function disco.start(driver, opts, cons)
  local iterations = 10
  while iterations > 0 do
    iterations = iterations - 1
    local scan_results = scanNetwork()

    for _, scan in ipairs(scan_results) do
      local host_info = scan['host_info']
      local device_url = "http://" .. host_info['name'] .. ":" .. host_info['port']  .."/api/v1/"

      log.debug("scan: " .. json.encode(scan))

      token = try_get_token(device_url)
      if token ~= nil then
        device_network_id = device_url .. token
        local device = create_device(driver, device_network_id, scan)
        disco.token = token

        --local device_list = driver:get_devices()
        -- device = device_list[device]
        --log.info('dev: '..tostring( json.encode(device) ))
        --log.info('>token: '..token)
        return device
      end
    end
    -- Wait for a while before trying again
    cosock.socket.sleep(1)
  end
end

return disco