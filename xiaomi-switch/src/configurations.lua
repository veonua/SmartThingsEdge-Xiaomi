local log = require "log"
local json = require "dkjson"
local zigbee_utils = require "zigbee_utils"

-- TODO: split it to drivers
local devices = {
  WXKGX1LM = {
    MATCHING_MODELS = {
      "lumi.sensor_switch", "lumi.sensor_switch.aq2"
    },
    CONFIGS = {
      first_button_ep = 0x0004,
      supported_button_values = {"pushed", "held", "pushed_2x", "pushed_3x", "pushed_4x", "pushed_5x"}
    }
  },
  GROUP1 = {
    MATCHING_MODELS = {
      "lumi.ctrl_neutral1", "lumi.ctrl_neutral2", "lumi.switch.b1lacn02", "lumi.switch.b2lacn02",
    },
    CONFIGS = {
      first_button_ep = 0x0004,
      supported_button_values = {"pushed", "held"}
    }
  },
  GROUP2 = {
    MATCHING_MODELS = {
      "lumi.switch.b1nacn02", "lumi.switch.b2nacn02", "lumi.switch.b3n01", "lumi.switch.n3acn3", 
      "lumi.ctrl_ln1.aq1", "lumi.ctrl_ln2.aq1", "lumi.switch.l3acn3", "lumi.switch.n3acn3",
    },
    CONFIGS = {
      first_button_ep = 0x0005,
      supported_button_values = {"pushed", "pushed_2x"}
    }
  },
  GROUP3 = {
    MATCHING_MODELS = {
      "lumi.switch.l1aeu1", "lumi.switch.l2aeu1", 
    },
    CONFIGS = {
      first_button_ep = 0x0029,
      supported_button_values = {"pushed", "pushed_2x"}
    }
  },
  GROUP4 = { 
    MATCHING_MODELS = {
      "lumi.sensor_86sw1", "lumi.sensor_86sw2",
    },
    CONFIGS = {
      first_button_ep = 0x0001,
      supported_button_values = {"pushed", "pushed_2x", "pushed_3x"}
    }
  },
  GROUP5 = { 
    MATCHING_MODELS = {
      "lumi.remote.b286opcn01", "lumi.remote.b486opcn01", "lumi.remote.b686opcn01", 
      "lumi.sensor_switch.aq3",
      "lumi.remote.b28ac1",
      "lumi.remote.b1acn01",
      "lumi.remote.b186acn01", "lumi.remote.b286acn01",
      "lumi.remote.b186acn02", "lumi.remote.b286acn02",
      "lumi.switch.b1laus01", "lumi.switch.b2laus01",
      "lumi.switch.b1naus01", "lumi.switch.b2naus01",
    },
    CONFIGS = {
      first_button_ep = 0x0001,
      supported_button_values = {"pushed", "pushed_2x", "held"}
    }
  },
}

local configs = {}

configs.get_device_parameters = function(zb_device)
  zigbee_utils.print_clusters(zb_device)
  local eps = zb_device.zigbee_endpoints
  local first_switch_ep = zigbee_utils.find_first_ep(eps, 0x0006) or 0
  
  for _, device in pairs(devices) do
    for _, model in pairs(device.MATCHING_MODELS) do
      if zb_device:get_model() == model then
        log.info( "Found config for device: " .. model .. " " .. json.encode(device.CONFIGS) )
        
        device.CONFIGS["first_switch_ep"] = first_switch_ep
        return device.CONFIGS
      end
    end
  end
  
  log.warn("No configuration found for device: " .. zb_device:get_model() )
  local first_button_ep = zigbee_utils.find_first_ep(eps, 0x0012)
  if first_button_ep == nil then
    log.warn("No Multistate Input for device: " .. zb_device:get_model() )
    first_button_ep = 100
  end

  return {
    first_switch_ep = first_switch_ep,
    first_button_ep = first_button_ep,
    supported_button_values = {"pushed"}
  }
end

return configs