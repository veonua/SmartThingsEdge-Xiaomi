-- for reference see https://github.com/zigpy/zha-device-handlers/tree/dev/zhaquirks/xiaomi
-- and https://github.com/Koenkk/zigbee-herdsman-converters/blob/master/devices/xiaomi.js

local data_types = require "st.zigbee.data_types"
local capabilities = require "st.capabilities"
local buf = require "st.buf"
local utils = require "st.utils"
local cluster_base = require "st.zigbee.cluster_base"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local log = require "log"

local ENERGY_RESET_OFFSET_FIELD = "energyResetOffsetWh"
local ENERGY_LAST_RAW_FIELD = "energyLastRawWh"

local xiaomi_key_map = {
                   --                 Large   Kitchen Bed1    Corrid  Bed2                Charger  AndrewB      Bathroom     LMotion          Cube Smoke
  [0x01] = "battery_mV",
  [0x02] = "battery_??",
  [0x03] = "device_temperature",
  [0x04] = "0x04", -- Uint16: 0x??A8                                                               0x43 A8                   0x31 A8-> 13 A8  43A8  43A8
  [0x05] = "RSSI_dB",
  [0x06] = "LQI",
  [0x07] = "0x07", -- Uint64: 0                               0000000                  507C5D84BA
  [0x08] = "0x08", -- Uint16: 0x0204, 0x2612, 0x2616, 0x2616, 0x103D, 0x103D,              0x1320                                                   0204
  [0x09] = "0x09", -- Uint16: 0x1308  ------, ------,         0x150A, 0x(13|12|11)[08],0x(0A|0B)00
  [0x0a] = "router_id",
  [0x0b] = "illuminance/?switch", -- Uint8: 0
  [0x0c] = "0x0c",
  [0x0d] = "0x0d", -- Utint32:                                                                                  0x00000E0B
  [0x0e] = "0x0e", -- Utint32:                                                                                           0
  [0x64] = "user1", -- switch/temp/open/position/gas_density
  [0x65] = "user2", -- switch2/humidity/brightness
  [0x66] = "user3", -- pressure/color_temp
  [0x6e] = "button1",
  [0x6f] = "button2",
  [0x95] = "consumption", -- Wh           (must do round(f * 1000) )
  [0x96] = "voltage",     -- V            (must do round(f / 10) )
  [0x97] = "consumption/current in mA",               --  0
  [0x98] = "power/gestureCounter",    -- power in Watts, counter increasing by 4                                                           0x0557
  [0x99] = "gestureCounter3/?switch", -- Uint8: 0x1A/0x00                                                                                  0x048F
  [0x9a] = "cubeSide/?switch",        -- Uint8: 0x04/0x00
  [0x9b] = "0x9b",                -- 0x00
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
  local raw_bat_volt = (battery_record.value / 1000)
  local raw_bat_perc = (raw_bat_volt - 2.5) * 100 / (3.0 - 2.5)
  local bat_perc = utils.round( utils.clamp_value(raw_bat_perc, 0, 100) )

  if device:supports_capability(capabilities.battery, "main") then
    device:emit_event(capabilities.battery.battery(bat_perc))
  end

  if device:supports_capability(capabilities.batteryLevel, "main") then
    local batteryLevel = "normal"

    if raw_bat_perc < 20 then
      batteryLevel = "critical"
    elseif raw_bat_perc < 40 then
      batteryLevel = "warning"
    end
    device:emit_event(capabilities.batteryLevel(batteryLevel))
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

  local latest = device:get_latest_state("main", capabilities.temperatureAlarm.ID, capabilities.temperatureAlarm.temperatureAlarm.NAME)
  if latest == alarm.value.value then
    return
  end

  device:emit_event(alarm)
end

local LAST_REPORT_TIME = "LAST_REPORT_TIME"

local function emit_power_consumption_report_event(device, kWh_value)
  -- powerConsumptionReport report interval
  local current_time = os.time()
  local last_time = device:get_field(LAST_REPORT_TIME) or 0
  local next_time = last_time + 60 * 15 -- 15 mins, the minimum interval allowed between reports
  if current_time < next_time then
    return
  end
  device:set_field(LAST_REPORT_TIME, current_time, { persist = true })
  local raw_value = kWh_value.value * 1000 -- 'Wh'

  local delta_energy = 0.0
  local current_power_consumption = device:get_latest_state('main', capabilities.powerConsumptionReport.ID,
    capabilities.powerConsumptionReport.powerConsumption.NAME)
  if current_power_consumption ~= nil then
    delta_energy = math.max(raw_value - current_power_consumption.energy, 0.0)
  end
  device:emit_event(capabilities.powerConsumptionReport.powerConsumption({
    energy = raw_value,
    deltaEnergy = delta_energy
  }))
end


local function emit_consumption_event(device, e_value)
  local value = utils.round(e_value.value * 10)/10.0
  local latest = device:get_field(ENERGY_LAST_RAW_FIELD)

  if latest ~= nil and value - latest < 0.01 then
    return
  end

  device:set_field(ENERGY_LAST_RAW_FIELD, value, {persist = true})
  local offset = device:get_field(ENERGY_RESET_OFFSET_FIELD) or 0
  local adjusted = value - offset
  if adjusted < 0 then
    adjusted = 0
  end
  log.info("Setting energy " .. tostring(value) .. " - " .. tostring(offset) .. " = " .. tostring(adjusted))
  device:emit_event( capabilities.energyMeter.energy({value=adjusted, unit="kWh"}) )
  emit_power_consumption_report_event(device, e_value)
end

local function emit_voltage_event(device, value)
  device:emit_event( capabilities.voltageMeasurement.voltage({value=value.value//10, unit="V"}) )
end

local function emit_current_event(_device, value)
  log.info("Current mA:", value.value)
end

local function emit_power_event(device, e_value)
  local value = utils.round(e_value.value * 100)/100.0

  local latest = device:get_latest_state("main", capabilities.powerMeter.ID, capabilities.powerMeter.power.NAME)
  if latest ~= nil and value - latest < 1 then
    return
  end
  device:emit_event( capabilities.powerMeter.power({value=value, unit="W"}) )
end

local xiaomi_utils = {
  events = {
    [0x01] = emit_battery_event,
    [0x03] = emit_temperature_event,
    [0x95] = emit_consumption_event,
    [0x96] = emit_voltage_event,
    [0x97] = emit_current_event,
    [0x98] = emit_power_event
  }
}

local ignore_events = {
  [0x05] = "RSSI_dB",
  [0x06] = "LQI",
  [0x0a] = "router_id",
  [0x64] = "user1",
  [0x65] = "user2",
  [0x6e] = "button1",
  [0x6f] = "button2",
}

function xiaomi_utils.get_energy_offset(device)
  return device:get_field(ENERGY_RESET_OFFSET_FIELD) or 0
end

function xiaomi_utils.set_energy_offset(device, offset)
  log.info("Setting energy offset to " .. tostring(offset))
  device:set_field(ENERGY_RESET_OFFSET_FIELD, offset, {persist = true})
end

function xiaomi_utils.energy_reset_handler(_driver, device, _command)
  local offset = xiaomi_utils.get_energy_offset(device)
  local raw = device:get_field(ENERGY_LAST_RAW_FIELD)
  if raw == nil then
    local latest = device:get_latest_state("main", capabilities.energyMeter.ID, capabilities.energyMeter.energy.NAME)
    log.info("No cached raw energy value, using latest event value: " .. tostring(latest) .. " with offset " .. tostring(offset))
    if latest ~= nil then
      raw = latest + offset
    end
  end

  log.info("Resetting energy meter, current offset " .. tostring(offset) .. " raw value " .. tostring(raw))
  raw = raw or 0
  xiaomi_utils.set_energy_offset(device, raw)
  device:emit_event( capabilities.energyMeter.energy({value=0.0, unit="Wh"}) )
end


function xiaomi_utils.emit_battery_event(_driver, device, value, _zb_rx)
  emit_battery_event(device, value)
end

function xiaomi_utils.emit_voltage_event(_driver, device, value, _zb_rx)
  emit_voltage_event(device, value)
end

function xiaomi_utils.handler(_driver, device, value, _zb_rx)
  if value.ID ~= data_types.CharString.ID and value.ID ~= data_types.OctetString.ID then
    log.warn("xiaomi_utils.handler: unknown data type: " .. tostring (value) )
    return
  end

  local bytes = value.value
  local message_buf = buf.Reader(bytes)

  local xiaomi_data_type = deserialize(message_buf)
  for key, item in pairs(xiaomi_data_type.items) do
    local event = xiaomi_utils.events[key]
    if event ~= nil then
      event(device, item)
    elseif ignore_events[key] == nil then
      local skey = "xi"..tostring(key)
      local name = xiaomi_key_map[key] or skey
      local prev = device:get_field(skey)
      if prev ~= nil and prev.value ~= item.value then
        log.warn(name, "prev:", prev, "new:", item)
      else
        log.debug(name, item) -- unhandled event
      end
      device:set_field(skey, item)
    end
  end

  local rssi_db = xiaomi_data_type.items[0x05]
  local lqi = xiaomi_data_type.items[0x06]
  if rssi_db ~= nil and lqi ~= nil then
    emit_signal_event(device, rssi_db.value, lqi.value)
    -- emit_signal_event(device, xiaomi_data_type.items[0x05].value, xiaomi_data_type.items[0x06].value)
  end
end

function xiaomi_utils.handlerFF02(_driver, device, svalue, _zb_rx)
  if svalue.ID ~= data_types.Structure.ID then
    log.error("FF02 unknown data type: ", svalue)
    return
  end

  local elements = svalue.elements

  local battery = elements[0x02]
  log.info("battery:", battery)
  if battery ~= nil then
    emit_battery_event(device, battery.data)
  end
  -- https://github.com/dresden-elektronik/deconz-rest-plugin/issues/1069
  -- Xiaomi Motion Sensor  xiaomi_utils.handlerFF02: Structure:
  --        on/off         battery    0x04  0x??A8          ????          DEV_ID?         Signal?% [85-98]
  --[Boolean: true, Uint16: 0x0BC7, Uint16: 0x13A8, Uint40: 0x0000000001, Uint16: 0x002C, Uint8: 0x5A]
  --[Boolean: true, Uint16: 0x0BC7, Uint16: 0x43A8, Uint40: 0x0000000001, Uint16: 0x002C, Uint8: 0x59]
  --[Boolean: true, Uint16: 0x0BC7, Uint16: 0x13A8, Uint40: 0x0000000003, Uint16: 0x002C, Uint8: 0x59]
  --[Boolean: true, Uint16: 0x0BD8, Uint16: 0x43A8, Uint40: 0x0000000001, Uint16: 0x01AD, Uint8: 0x58]
  --[Boolean: true, Uint16: 0x0BD1, Uint16: 0x13A8, Uint40: 0x0000000001, Uint16: 0x0014, Uint8: 0x5B]
  --[Boolean: true, Uint16: 0x0BD1, Uint16: 0x13A8, Uint40: 0x0000000011, Uint16: 0x0015, Uint8: 0x5B]
  --[Boolean: true, Uint16: 0x0BD1, Uint16: 0x13A8, Uint40: 0x0000000001, Uint16: 0x0015, Uint8: 0x5B]
  --[Boolean: true, Uint16: 0x0BD1, Uint16: 0x13A8, Uint40: 0x0000000007, Uint16: 0x0015, Uint8: 0x5B]


  log.debug("FF02: " .. tostring(svalue))
  -- if (elements[3].data.value % 0xFF ~= 0xA8) then
  --   log.error("elements[3]", elements[3].data.value)
  -- end
  if (elements[4].data.value > 2) then
    log.error("elements[4]", elements[4].data.value)
  end
  if (elements[6].data.value > 100) then
    log.error("elements[6]", elements[6].data.value)
  end
end

local function bytes_starts_with(raw, prefix)
    if raw == nil then return false end

    if type(raw) == "string" then
        if #raw < #prefix then return false end
        for i = 1, #prefix do
            if string.byte(raw, i) ~= prefix[i] then return false end
        end
        return true
    end

    if type(raw) == "table" then
        if #raw < #prefix then return false end
        for i = 1, #prefix do
            if raw[i] ~= prefix[i] then return false end
        end
        return true
    end

    return false
end

function xiaomi_utils.prevent_reset_handler(_driver, device, value, _zb_rx)
  local incoming = value.value
  local prefix = {0xAA, 0x10, 0x05, 0x41, 0x87}

  if not bytes_starts_with(incoming, prefix) then
      return
  end

  log.info("xiaomi_utils.prevent_reset_handler: sending write to prevent reset")
  local payload = data_types.OctetString( {0xAA, 0x10, 0x05, 0x41, 0x47, 0x01, 0x01, 0x10, 0x01} )
  device:send(cluster_base.write_manufacturer_specific_attribute(device, zcl_clusters.basic_id, 0xFFF0, 0x115F, payload) )
end

xiaomi_utils.basic_id = {
  [0xFF00] = xiaomi_utils.prevent_reset_handler,
  [0xFF01] = xiaomi_utils.handler,
  [0xFF02] = xiaomi_utils.handlerFF02
}

xiaomi_utils.OppleCluster = 0xFCC0
xiaomi_utils.opple_id = {
  [0x00F7] = xiaomi_utils.handler,
}

return xiaomi_utils
