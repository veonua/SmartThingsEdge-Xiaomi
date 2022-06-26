local log = require('log')
local json = require('dkjson')
local Array = require("lockbox.util.array")
local Stream = require("lockbox.util.stream")
local CBCMode = require("lockbox.cipher.mode.cbc")
local ZeroPadding = require("lockbox.padding.zero")
local AES128Cipher = require("lockbox.cipher.aes128")

local Digest = require("lockbox.digest.md5")
local buf_lib = require("st.buf")

local zeroTerm = Array.fromHex("00")

local OFFSET = 2
local packet = {
    msgCounter = 0
    _stampDelta = 0,
    handshake = Array.fromHex("21310020ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"),
    deviceId = 260426251
}

function packet.init(deviceId, token)
    packet.deviceId = deviceId
    packet.token = Array.fromHex(token);
    local key = Digest().update(Stream.fromArray(token))
                        .finish()
    packet.iv = Digest().update(Stream.fromArray(key))
                        .finish()
            
    packet.cipher = CBCMode.Cipher()
                .setKey(key)
                .setBlockCipher(AES128Cipher)
                .setPadding(ZeroPadding)
                .init();

    packet.decipher = CBCMode.Decipher()
                .setKey(key)
                .setBlockCipher(AES128Cipher)
                .setPadding(ZeroPadding)
                .init();

end

function packet.encode(micom)
    command['id'] = packet:msgCounter
    packet:msgCounter = packet:msgCounter + 1
    local send_ts = os.time() + this._stampDelta + OFFSET

    local plaintext = json.encode(micom) --.replace('"method":{"', '"').replace(']"}}', ']"}').replace('"},"', '","');
    log.info("jrequest: " .. plaintext)

    local encrypted = packet.cipher
                        .init()
                        .update(Stream.fromArray(packet.iv))
                        .update(Stream.fromString(plaintext))
                        .update(Stream.fromArray(zeroTerm))
                        .finish()

    local writer = buf.Writer()
    writer:write_be_u16(0x2131)
    writer:write_be_u16(32 + encrypted.length)
    writer:write_be_u32(0)
    writer:write_be_u32(deviceId)
    writer:write_be_u32(ts)
    local header = writer.buf

    local digest = Digest()
                .update(Stream.fromArray(header))
                .update(Stream.fromArray(token))
                .update(Stream.fromArray(encrypted))
                .finish()

    writer:write_bytes(digest).write_bytes(encrypted)
    local buf = writer.buf
    log.info(">>",writer:pretty_print())
    return buf
end

function packet.decode(value)
    local msg = value[0]
    packet.lastResponse = os.time()
    local mi_ts =  msg.read_be_u32()
    packet._stampDelta = mi_ts - packet.lastResponse
    log.info("mi - st time delta " .. (packet._stampDelta) .. "s")
    if (mi_ts == 0) then
        packet._stampDelta = 0
    end

    local encrypted = msg.slice(32)
    if (#encrypted == 0) then -- Handshake packet
        return {
            id = 0,
            result = ['']
        }
    end

    local data = packet.decipher.update(encrypted).finish()
    if (data == nil) then
        log.err("can't decode packet, reset session")
        return nil
    end
    
    local data_str = String.fromArray(data)
    --data_str = data_str.substring(0, data_str.lastIndexOf("}")+1)
    log.info("decoded response " .. data_str)
    return json.decode(data_str)
end

function packet.needsHandshake()
    local res = (os.time() - packet.lastResponse) > 10 * 60
    if (res) then
        log.info("need handshake lastResponse:" .. packet.lastResponse .. " now:" .. os.time())
    end
    return res
end

return packet