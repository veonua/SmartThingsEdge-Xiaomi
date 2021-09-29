local log = require "log"

local devices = {
  GROUP1 = {
    MATCHING_MODELS = {
      "lumi.ctrl_neutral1", "lumi.ctrl_neutral2", "lumi.switch.b1lacn02", "lumi.switch.b2lacn02",
    },
    CONFIGS = {
      first_switch_ep = 0x0002,
      first_button_ep = 0x0004,
      supported_button_values = {"pushed", "double", "held"}
    }
  },
  GROUP2 = {
    MATCHING_MODELS = {
      "lumi.switch.n3acn3", "lumi.switch.b1nacn02", "lumi.switch.b2nacn02", "lumi.ctrl_ln1.aq1", "lumi.ctrl_ln2.aq1", "lumi.switch.l3acn3", "lumi.switch.n3acn3",
    },
    CONFIGS = {
      first_switch_ep = 0x0001,
      first_button_ep = 0x0005,
      supported_button_values = {"pushed", "double"}
    }
  },
  GROUP3 = {
    MATCHING_MODELS = {
      "lumi.switch.l1aeu1",
    },
    CONFIGS = {
      first_switch_ep = 0x0001,
      first_button_ep = 0x0005,
      supported_button_values = {"pushed"}
    }
  }
}

local configs = {}

configs.get_device_parameters = function(zb_device)
  for _, device in pairs(devices) do
    for _, model in pairs(device.MATCHING_MODELS) do
      if zb_device:get_model() == model then
        log.info("Found config for device: " .. model)
        return device.CONFIGS
      end
    end
  end
  
  return {
    first_switch_ep = 0x0001,
    first_button_ep = 0x0005,
    supported_button_values = {"pushed"}
  }
end

return configs