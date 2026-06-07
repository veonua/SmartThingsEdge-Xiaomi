local data_types = require "st.zigbee.data_types"
local cluster_base = require "st.zigbee.cluster_base"

local driver_utils = {}

function driver_utils.get_divisor(device, key, default_value)
  local divisor = device:get_field(key)
  if divisor == nil or divisor == 0 then
    return default_value or 1
  end
  return divisor
end

function driver_utils.send_mfg_attribute(device, cluster_id, attr_id, payload, mfg_code)
  local message = cluster_base.write_attribute(
    device,
    data_types.ClusterId(cluster_id),
    data_types.AttributeId(attr_id),
    payload
  )
  message.body.zcl_header.frame_ctrl:set_mfg_specific()
  message.body.zcl_header.mfg_code = data_types.validate_or_build_type(mfg_code, data_types.Uint16, "mfg_code")
  device:send(message)
end

function driver_utils.setpoint_limit_handler_factory(capabilities, min_or_max, heat_or_cool)
  local field = "setpoint_" .. min_or_max .. "_" .. heat_or_cool
  local paired_field = "setpoint_min_" .. heat_or_cool
  if min_or_max == "min" then
    paired_field = "setpoint_max_" .. heat_or_cool
  end

  return function(_driver, device, setpoint)
    local celsius_value = setpoint.value / 100.0
    device:set_field(field, celsius_value)
    if device:get_field(field) and device:get_field(paired_field) then
      local event_constructor = (heat_or_cool == "cool")
        and capabilities.thermostatCoolingSetpoint.coolingSetpointRange
        or capabilities.thermostatHeatingSetpoint.heatingSetpointRange

      device:emit_event(event_constructor(
        {
          unit = "C",
          value = {
            minimum = device:get_field("setpoint_min_" .. heat_or_cool),
            maximum = device:get_field("setpoint_max_" .. heat_or_cool)
          }
        }
      ))

      device:set_field(field, nil)
      device:set_field(paired_field, nil)
    end
  end
end

function driver_utils.set_setpoint_factory(utils, setpoint_attribute)
  return function(_driver, device, command)
    local value = command.args.setpoint
    if value >= 40 then
      value = utils.f_to_c(value)
    end
    device:send_to_component(command.component, setpoint_attribute:write(device, utils.round(value * 100)))

    device.thread:call_with_delay(2, function(_d)
      device:send_to_component(command.component, setpoint_attribute:read(device))
    end)
  end
end

function driver_utils.temperature_measurement_min_max_attr_handler(capabilities, temperature_measurement_defaults, min_or_max)
  return function(_driver, device, value, zb_rx)
    local raw_temp = value.value
    local celc_temp = raw_temp / 100.0
    local temp_scale = "C"

    device:set_field(string.format("%s", min_or_max), celc_temp)

    local min = device:get_field(temperature_measurement_defaults.MIN_TEMP)
    local max = device:get_field(temperature_measurement_defaults.MAX_TEMP)

    if min ~= nil and max ~= nil then
      if min < max then
        device:emit_event_for_endpoint(
          zb_rx.address_header.src_endpoint.value,
          capabilities.temperatureMeasurement.temperatureRange({ value = { minimum = min, maximum = max }, unit = temp_scale })
        )
        device:set_field(temperature_measurement_defaults.MIN_TEMP, nil)
        device:set_field(temperature_measurement_defaults.MAX_TEMP, nil)
      else
        device.log.warn_with({ hub_logs = true }, string.format(
          "Device reported a min temperature %d that is not lower than the reported max temperature %d",
          min,
          max
        ))
      end
    end
  end
end

return driver_utils
