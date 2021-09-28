local FloatABC = require "st.zigbee.data_types.base_defs.FloatABC"

--- @class st.zigbee.data_types.SinglePrecisionFloat: st.zigbee.data_types.FloatABC
--- @field public ID number 0x39
--- @field public NAME string "SinglePrecision"
--- @field public byte_length number 4
--- @field public mantissa_bit_length number 23
--- @field public exponent_bit_length number 8
local SinglePrecisionFloat = {}
setmetatable(SinglePrecisionFloat, FloatABC.new_mt({ NAME = "SinglePrecisionFloat", ID = 0x39 }, 4, 23, 8))

return SinglePrecisionFloat