local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"

local function xiaomi_attr_handler(driver, device, value, zb_rx)
  local buff = value.value
  log.warn(">>> xiaomi_attr_handler " .. buff)
  
  if buff:byte(0) ~= 0x01 then
    log.warn("wrong cmd")
    return
  end

  --- "\x01\x21\xBD\x0B\x03\x28\x1C\x04\x21\xA8\x31\x05\x21\xAC\x00\x06\x24\x01\x00\x00\x00\x00\x0A\x21\x00\x00\x64\x10\x00\x0B\x21\xC8\x01"
  local i = 1
  repeat
    local lbl  = buff:byte(i)
    local kind = buff:byte(i+1)
    
    if kind == types.Boolean.ID then
      -- device:emit_event(capabilities.battery.battery(value))
      i = i + 3
    elseif kind == types.Int8.ID or kind == types.Uint8.ID then
      local value = buff:byte(i + 2)
      log.debug("Int8 " .. tostring(value))
      i = i + 3
    elseif kind == types.Int16.ID or kind == types.Uint16.ID then
      local value = buff:byte(i + 2) + (buff:byte(i + 3) << 8)
      log.debug("Int16 " .. tostring(value))
      i = i + 4
    elseif kind == types.Int32.ID or kind == types.Uint32.ID then
      local value = buff:byte(i + 2) + (buff:byte(i + 3) << 8)  + (buff:byte(i + 4) << 16) + (buff:byte(i + 5) << 24)
      log.debug("Int32 " .. tostring(value))
      i = i + 6
    elseif kind == types.Int40.ID then
      local value = buff:byte(i + 2) + (buff:byte(i + 3) << 8)  + (buff:byte(i + 4) << 16) + (buff:byte(i + 5) << 24) + (buff:byte(i + 6) << 32)
      log.debug("Int40 " .. tostring(value))
      i = i + 7
    elseif kind == types.Int64.ID or kind == types.Uint64.ID then
      log.debug("Int64 " .. tostring(value))
      i = i + 10
    else
      log.debug("wrong kind")
    end
  until buff:len() <= i + 1
end

local lumi_water_sensor = {
  NAME = "Aqara Water Leak Sensor",
  
  zigbee_handlers = {
    use_defaults = false ,
    attr = {
      [clusters.Basic.ID] = {
        [0x0005] = xiaomi_attr_handler,
        [0xFF01] = xiaomi_attr_handler
      }
    }
  },
  can_handle = function(opts, driver, device, ...)
    return true
  end
}

return lumi_water_sensor
