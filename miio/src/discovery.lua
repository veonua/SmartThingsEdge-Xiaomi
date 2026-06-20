local log = require('log')
local json = require('dkjson')
local mdns = require('mdns')


local function parse_ssdp(_data)
  return {}
end

local function find_device()
  local res = mdns.query("_miio._udp.local") --"_googlecast._tcp.local") --- "_googlerpc._tcp", 2)
  log.debug("Found devices: " .. json.encode(res))

  return res
end

local function create_device(driver, id, device)
  local manufacturer = "Xiaomi"
  local model        = device['model']

  local location = device['location']

  log.info('===== DEVICE : '..manufacturer..' '..model ..' @ '..location)

  -- device metadata table
  local metadata = {
    type = "LAN",
    device_network_id = location,--device['location'],
    label = model,
    profile = device['profile'],
    manufacturer = manufacturer,
    model = model,
    vendor_provided_label = id,
  }
  return driver:try_create_device(metadata)
end

local disco = {}
function disco.start(driver, _opts, _cons)
  local iterations = 100
  while iterations>0 do
    iterations = iterations - 1
    local device_res = find_device()

    if device_res ~= nil then
      device_res = parse_ssdp(device_res)
      for id, device in pairs(device_res) do
        create_device(driver, id, device)
      end
      return
    else
      log.warn('===== DEVICE NOT FOUND IN NETWORK')
    end
  end
end

return disco
