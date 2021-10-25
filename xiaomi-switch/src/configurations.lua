local log = require "log"
local json = require "dkjson"

local devices = {
  GROUP1 = {
    MATCHING_MODELS = {
      "lumi.ctrl_neutral1", "lumi.ctrl_neutral2", "lumi.switch.b1lacn02", "lumi.switch.b2lacn02",
    },
    CONFIGS = {
      first_button_ep = 0x0004,
      supported_button_values = {"pushed", "double", "held"}
    }
  },
  GROUP2 = {
    MATCHING_MODELS = {
      "lumi.switch.b1nacn02", "lumi.switch.b2nacn02", "lumi.switch.n3acn3", "lumi.ctrl_ln1.aq1", "lumi.ctrl_ln2.aq1", "lumi.switch.l3acn3", "lumi.switch.n3acn3",
    },
    CONFIGS = {
      first_button_ep = 0x0005,
      supported_button_values = {"pushed", "double"}
    }
  },
  GROUP3 = {
    MATCHING_MODELS = {
      "lumi.switch.l1aeu1", "lumi.switch.l2aeu1", 
    },
    CONFIGS = {
      first_button_ep = 0x0029,
      supported_button_values = {"pushed", "double"}
    }
  },
  GROUP4 = { 
    MATCHING_MODELS = {
      "lumi.sensor_86sw1", "lumi.sensor_86sw2", "lumi.remote.b286opcn01", "lumi.remote.b286acn01"
    },
    CONFIGS = {
      first_button_ep = 0x0001,
      supported_button_values = {"pushed", "double"}
    }
  },
}

local configs = {}

function find_first_ep(eps, cluster)
  local tkeys = {}
  for k in pairs(eps) do table.insert(tkeys, k) end
  table.sort(tkeys)
  
  for _, k in ipairs(tkeys) do 
    local ep = eps[k]
    for _, clus in ipairs(ep.server_clusters) do
      if clus == cluster then
        return ep.id
      end
    end
  end

  return 0
end

configs.get_device_parameters = function(zb_device)
  local eps = zb_device.zigbee_endpoints
  log.info(json.encode(eps))
  
  local first_switch_ep = find_first_ep(eps, 0x0006)
  local first_button_ep = find_first_ep(eps, 0x0012)
  
  for _, device in pairs(devices) do
    for _, model in pairs(device.MATCHING_MODELS) do
      if zb_device:get_model() == model then
        log.info( "Found config for device: " .. model .. " " .. json.encode(device.CONFIGS) )
        
        if first_button_ep ~= device.CONFIGS.first_button_ep then
          log.warn( "First button endpoint is not correct: " .. first_button_ep .. " " .. device.CONFIGS.first_button_ep )
        end

        device.CONFIGS["first_switch_ep"] = first_switch_ep
        return device.CONFIGS
      end
    end
  end
  
  log.warn("Did not found config for device: " .. tostring( zb_device:get_model() ) )
        
  return {
    first_switch_ep = first_switch_ep,
    first_button_ep = first_button_ep,
    supported_button_values = {"pushed"}
  }
end

return configs