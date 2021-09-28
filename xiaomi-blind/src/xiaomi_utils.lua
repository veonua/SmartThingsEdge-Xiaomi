local data_types = require "st.zigbee.data_types"
local capabilities = require "st.capabilities"
local buf = require "st.buf"

local battery_defaults = require "st.zigbee.defaults.battery_defaults"
local log = require "log"

local xiaomi_key_map = {
  [0x01] = "battery_mV",
  [0x03] = "deviceTemperature",
  [0x04] = "unknown1",
  [0x05] = "RSSI_dB",
  [0x06] = "LQI",
  [0x07] = "unknown2",
  [0x08] = "unknown3",
  [0x09] = "unknown4",
  [0x0a] = "routerid",
  [0x0b] = "unknown5",
  [0x0c] = "unknown6",
  [0x64] = "switch1",
  [0x65] = "switch2",
  [0x66] = "pressure",
  [0x6e] = "button1",
  [0x6f] = "button2",
  [0x95] = "consumption",
  [0x96] = "voltage",
  [0x97] = "??",               --  0
  [0x98] = "power/gestureCounter", -- counter increasing by 4
  [0x99] = "gestureCounter3", -- 0x1A
  [0x9a] = "cudeSide",        -- 0x04
  [0x9b] = "unknown9",
}

local function deserialize(data_buf)
  local out = {
    items = {}
  }
  while data_buf:remain() > 0 do
    local index = data_types.Uint8.deserialize(data_buf)
    local data_type = data_types.ZigbeeDataType.deserialize(data_buf)
    local data = data_types.parse_data_type(data_type.value, data_buf)
    out.items[index.value] = data
    log.debug(xiaomi_key_map[index.value] .. " value:" .. tostring(data))
  end

  return out
end

local function emit_battery_event(device, battery_record)
  local raw_bat_volt = (battery_record.value / 1000)
  local raw_bat_perc = (raw_bat_volt - 2.5) * 100 / (3.0 - 2.5)
  local bat_perc = math.floor(math.max(math.min(raw_bat_perc, 100), 0))
  device:emit_event(capabilities.battery.battery(bat_perc))
end

local function emit_temperature_event(device, temperature_record)
  local temperature = temperature_record.value
  local alarm = "cleared"
  if temperature > 60 then
    alarm = "heat"
  elseif temperature < -20 then
    alarm = "freeze"
  end
  device:emit_event(capabilities.temperatureAlarm.temperatureAlarm(alarm))
end

local xiaomi_utils = {
  attr_id = 0xFF01,
  xiami_events = {
    [0x01] = emit_battery_event,
    [0x03] = emit_temperature_event,
  }
}

function xiaomi_utils.handler(driver, device, value, zb_rx)
  local buff = value.value
  if value.ID == data_types.CharString.ID then
    local bytes = value.value
    local message_buf = buf.Reader(bytes)
    
    local xiaomi_data_type = deserialize(message_buf)
    for key, value in pairs(xiaomi_data_type.items) do
      local event = xiaomi_utils.xiami_events[key]
      if event ~= nil then
        event(device, value)
      end
    end
  end
end

return xiaomi_utils