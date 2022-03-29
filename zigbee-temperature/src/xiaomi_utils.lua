-- for reference see https://github.com/zigpy/zha-device-handlers/tree/dev/zhaquirks/xiaomi
-- and https://github.com/Koenkk/zigbee-herdsman-converters/blob/master/devices/xiaomi.js

local data_types = require "st.zigbee.data_types"
local capabilities = require "st.capabilities"
local buf = require "st.buf"
local utils = require "st.utils"
local log = require "log"

local battery_defaults = require "st.zigbee.defaults.battery_defaults"

local xiaomi_key_map = {
  [0x01] = "battery_mV",
  [0x02] = "battery_??",
  [0x03] = "device_temperature",
  [0x04] = "unknown1",
  [0x05] = "RSSI_dB",
  [0x06] = "LQI",
  [0x07] = "unknown2",
  [0x08] = "unknown3",
  [0x09] = "unknown4",
  [0x0a] = "router_id",
  [0x0b] = "illuminance",
  [0x0c] = "unknown6",
  [0x64] = "user1", -- switch/temp/open/position/gas_density
  [0x65] = "user2", -- switch2/humidity/brightness
  [0x66] = "user3", -- pressure/color_temp
  [0x6e] = "button1",
  [0x6f] = "button2",
  [0x95] = "consumption", -- Wh 
  [0x96] = "voltage",     -- V            (must do round(f / 10) )
  [0x97] = "consumption/current in mA",               --  0
  [0x98] = "power/gestureCounter", -- counter increasing by 4
  [0x99] = "gestureCounter3", -- 0x1A
  [0x9a] = "cubeSide",        -- 0x04
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
  end

  return out
end

local function emit_battery_event(device, battery_record)
  if device:supports_capability(capabilities.battery, "main") then
    local raw_bat_volt = (battery_record.value / 1000)
    local raw_bat_perc = (raw_bat_volt - 2.5) * 100 / (3.0 - 2.5)
    local bat_perc = utils.round( utils.clamp_value(raw_bat_perc, 0, 100) )
    device:emit_event(capabilities.battery.battery(bat_perc))
  end
end

local function emit_signal_event(device, rssi_db, lqi)
  log.info("xiaomi_utils.lua: emit_signal_event", rssi_db, lqi)
  if device:supports_capability(capabilities.signalStrength, "main") then
    device:emit_event(capabilities.signalStrength.rssi(rssi_db))
    device:emit_event(capabilities.signalStrength.lqi(lqi))
  end
end

local function emit_temperature_event(device, temperature_record)
  if device:supports_capability(capabilities.temperatureAlarm, "main") == false then
    return
  end

  local temperature = temperature_record.value
  local alarm = capabilities.temperatureAlarm.temperatureAlarm.cleared()
  if temperature > 60 then
    alarm = capabilities.temperatureAlarm.temperatureAlarm.heat()
  elseif temperature < -20 then
    alarm = capabilities.temperatureAlarm.temperatureAlarm.freeze()
  end
  device:emit_event(alarm)
end

local xiaomi_utils = {
  attr_id  = 0xFF01,
  attr_id2 = 0xFF02,
  xiami_events = {
    [0x01] = emit_battery_event,
    [0x03] = emit_temperature_event,
  }
}

function xiaomi_utils.handler(driver, device, value, zb_rx)
  if value.ID == data_types.CharString.ID or value.ID == data_types.OctetString.ID then
    local bytes = value.value
    local message_buf = buf.Reader(bytes)
    
    local xiaomi_data_type = deserialize(message_buf)
    for key, value in pairs(xiaomi_data_type.items) do
      local event = xiaomi_utils.xiami_events[key]
      if event ~= nil then
        event(device, value)
      end
    end

    local rssi_db = xiaomi_data_type.items[0x05]
    local lqi = xiaomi_data_type.items[0x06]
    if rssi_db ~= nil and lqi ~= nil then
      emit_signal_event(device, rssi_db.value, lqi.value)
      -- emit_signal_event(device, xiaomi_data_type.items[0x05].value, xiaomi_data_type.items[0x06].value)
    end
    
    -- log.warn("xiaomi_utils.handler handled: " .. tostring(#xiaomi_data_type.items))
  else
    log.warn("xiaomi_utils.handler: unknown data type: " .. tostring (value) )
  end
end

function xiaomi_utils.handlerFF02(driver, device, value, zb_rx)
  if value.ID ~= data_types.Structure.ID then
    log.error("xiaomi_utils.handlerFF02: unknown data type: " .. tostring (value) )
    return
  end

  log.warn("xiaomi_utils.handlerFF02: " .. tostring(value))
  --[Boolean: true, Uint16: 0x0BD1 (3025), Uint16: 0x13A8(5032), Uint40: 0x0000000001, Uint16: 0x0014(20), Uint8: 0x5B(91)] > > > >
end

return xiaomi_utils

-- https://github.com/Koenkk/zigbee-herdsman-converters/blob/master/devices/xiaomi.js#L22
-- const preventReset = async (type, data, device) => {
--   if (
--       // options.allow_reset ||
--       type !== 'message' ||
--       data.type !== 'attributeReport' ||
--       data.cluster !== 'genBasic' ||
--       !data.data[0xfff0] ||
--       // eg: [0xaa, 0x10, 0x05, 0x41, 0x87, 0x01, 0x01, 0x10, 0x00]
--       !data.data[0xFFF0].slice(0, 5).equals(Buffer.from([0xaa, 0x10, 0x05, 0x41, 0x87]))
--   ) {
--       return;
--   }
--   const options = {manufacturerCode: 0x115f};
--   const payload = {[0xfff0]: {
--       value: [0xaa, 0x10, 0x05, 0x41, 0x47, 0x01, 0x01, 0x10, 0x01],
--       type: 0x41,
--   }};
--   await device.getEndpoint(1).write('genBasic', payload, options);
-- };