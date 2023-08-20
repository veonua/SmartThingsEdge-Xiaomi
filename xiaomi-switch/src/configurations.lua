local log = require "log"
local json = require "dkjson"
local zigbee_utils = require "zigbee_utils"

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
  WXKG11LM_2 = {
    MATCHING_MODELS = {
      "lumi.remote.b1acn01"
    },
    CONFIGS = {
      first_button_ep = 0x0001,
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
      "lumi.ctrl_ln1", "lumi.ctrl_ln2", "lumi.ctrl_ln1.aq1", "lumi.ctrl_ln2.aq1",
    },
    CONFIGS = {
      first_button_ep = 0x0005,
      supported_button_values = {"pushed", "held"}
    }
  },
  GROUP3 = {
    MATCHING_MODELS = {
      "lumi.switch.b1nacn02", "lumi.switch.b2nacn02", "lumi.switch.b3n01",
      "lumi.switch.l3acn3", "lumi.switch.n3acn3",
    },
    CONFIGS = {
      first_button_ep = 0x0005,
      supported_button_values = {"pushed", "pushed_2x"}
    }
  },
  GROUP4 = {
    MATCHING_MODELS = {
      "lumi.switch.l1aeu1", "lumi.switch.l2aeu1", 
      "lumi.switch.l3acn1", "lumi.switch.n3acn1",
      "lumi.switch.n1aeu1", "lumi.switch.n2aeu1", 
    },
    CONFIGS = {
      first_button_ep = 0x0029,
      supported_button_values = {"pushed", "pushed_2x"}
    }
  },
  GROUP5 = { 
    MATCHING_MODELS = {
      "lumi.sensor_86sw1", "lumi.sensor_86sw2",
    },
    CONFIGS = {
      first_button_ep = 0x0001,
      supported_button_values = {"pushed", "pushed_2x", "pushed_3x"}
    }
  },
  GROUP6 = { 
    MATCHING_MODELS = {
      "lumi.remote.b286opcn01", "lumi.remote.b486opcn01", "lumi.remote.b686opcn01", 
      "lumi.sensor_swit", "lumi.sensor_switch.aq3",
      "lumi.remote.b28ac1",
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


local function find_config(model)
  for _, device in pairs(devices) do
    for _, d_model in pairs(device.MATCHING_MODELS) do
      if model == d_model then
        log.info( "Found config for: " .. model .. " " .. json.encode(device.CONFIGS) )
  
        return device.CONFIGS
      end
    end
  end
  return nil
end

configs.get_device_parameters = function(zb_device)
  zigbee_utils.print_clusters(zb_device)
  local eps = zb_device.zigbee_endpoints
  local first_switch_ep = zigbee_utils.find_first_ep(eps, 0x0006) or 0
  
  local model = zb_device:get_model()
  local number_of_channels = 1
  local neutral_wire = false
  local switch = false

  local _, _, m = string.find(model, "^lumi%.switch%.[ln](%d)")
  if m ~= nil then
    switch = true
    number_of_channels = tonumber(m)
    neutral_wire = model:sub(12, 12) == "n"
  else
    _, _, m = string.find(model, "^lumi%.switch%.b(%d)[ln]")
    if m ~= nil then
      switch = true
      number_of_channels = tonumber(m)
      neutral_wire = model:sub(16, 16) == "n"
    else
      _, _, m = string.find(model, "^lumi%.ctrl_ln(%d)")
      if m ~= nil then
        switch = true
        number_of_channels = tonumber(m)
        neutral_wire = true
      else
        _, _, m = string.find(model, "^lumi%.ctrl_neutral(%d)")
        if m ~= nil then
          switch = true
          number_of_channels = tonumber(m)
          neutral_wire = false
        end
      end  
    end
  end

  
  res = find_config(model)
  if res == nil then
    local first_button_ep = zigbee_utils.find_first_ep(eps, 0x0012)
    if first_button_ep == nil then
      log.warn("No Multistate Input for: " .. zb_device:get_model() )
      first_button_ep = 100
    end

    log.warn("No configuration found for: " .. model )
    res = {
      first_button_ep = first_button_ep,
      supported_button_values = {"pushed", "pushed_2x"}
    }
  end

  --- append
  -- first_switch_ep
  -- number_of_channels
  -- neutral_wire

  return {
    first_switch_ep = first_switch_ep,
    number_of_channels = number_of_channels,
    neutral_wire = neutral_wire,
    first_button_ep = res.first_button_ep,
    supported_button_values = res.supported_button_values
  }
end

return configs