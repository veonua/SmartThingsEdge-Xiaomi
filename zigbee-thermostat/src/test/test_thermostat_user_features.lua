local test = require "integration_test"
local t_utils = require "integration_test.utils"
local capabilities = require "st.capabilities"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"
local clusters = require "st.zigbee.zcl.clusters"
local cluster_base = require "st.zigbee.cluster_base"
local xiaomi_utils = require "xiaomi_utils"

local Thermostat = clusters.Thermostat
local TemperatureMeasurement = clusters.TemperatureMeasurement
local RelativeHumidity = clusters.RelativeHumidity
local ElectricalMeasurement = clusters.ElectricalMeasurement
local SimpleMetering = clusters.SimpleMetering

local mock_device = test.mock_device.build_test_zigbee_device({
  profile = t_utils.get_profile_definition("floor-thermostat-w500.yml"),
  zigbee_endpoints = {
    [1] = {
      id = 1,
      manufacturer = "LUMI",
      model = "lumi.airrtc.agl001",
      server_clusters = {
        TemperatureMeasurement.ID,
        Thermostat.ID,
        RelativeHumidity.ID,
        ElectricalMeasurement.ID,
        SimpleMetering.ID
      }
    }
  }
})

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device)
  zigbee_test_utils.init_noop_health_check_timer()
end
test.set_test_init_function(test_init)

test.register_message_test(
  "Thermostat running state should show heating when the relay is on",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, Thermostat.attributes.ThermostatRunningState:build_test_attr_report(mock_device, 0x0001) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.thermostatOperatingState.thermostatOperatingState.heating())
    }
  }
)

test.register_message_test(
  "Humidity reports should appear in the thermostat device view",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, RelativeHumidity.attributes.MeasuredValue:build_test_attr_report(mock_device, 4300) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.relativeHumidityMeasurement.humidity({ value = 43 }))
    }
  }
)

test.register_message_test(
  "Active power reports should surface the current load",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, ElectricalMeasurement.attributes.ActivePower:build_test_attr_report(mock_device, 275) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.powerMeter.power({ value = 27.5, unit = "W" }))
    }
  }
)

test.register_message_test(
  "Energy reports should be converted into kWh for the user",
  {
    {
      channel = "zigbee",
      direction = "receive",
      message = { mock_device.id, SimpleMetering.attributes.CurrentSummationDelivered:build_test_attr_report(mock_device, 3456) }
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message("main", capabilities.energyMeter.energy({ value = 3.456, unit = "kWh" }))
    }
  }
)

test.register_coroutine_test(
  "Adding the thermostat should request the user-visible state it needs",
  function()
    test.socket.zigbee:__set_channel_ordering("relaxed")
    test.socket.device_lifecycle:__queue_receive({ mock_device.id, "added" })
    test.socket.zigbee:__expect_send({ mock_device.id, TemperatureMeasurement.attributes.MinMeasuredValue:read(mock_device) })
    test.socket.zigbee:__expect_send({ mock_device.id, TemperatureMeasurement.attributes.MaxMeasuredValue:read(mock_device) })
    test.socket.zigbee:__expect_send({ mock_device.id, Thermostat.attributes.OccupiedHeatingSetpoint:read(mock_device) })
    test.socket.zigbee:__expect_send({ mock_device.id, Thermostat.attributes.LocalTemperature:read(mock_device) })
    test.socket.zigbee:__expect_send({ mock_device.id, ElectricalMeasurement.attributes.ActivePower:read(mock_device) })
    test.socket.zigbee:__expect_send({ mock_device.id, SimpleMetering.attributes.CurrentSummationDelivered:read(mock_device) })
    test.socket.zigbee:__expect_send({
      mock_device.id,
      cluster_base.read_manufacturer_specific_attribute(mock_device, xiaomi_utils.OppleCluster, 0x0311, 0x115F)
    })
  end
)

test.run_registered_tests()
