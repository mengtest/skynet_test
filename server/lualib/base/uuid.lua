local core = require "uuid.core"
local skynet = require "skynet"
local skynet_timeout = skynet.timeout

-- [[uuid format : (33bits timestamp)(6bits harbor)(15bits service)(10bits sequence)]]
local uuid = {}

local timestamp
local service
local sequence
function uuid.gen()
    if not service then
        local sid = core.sid() or error("init uuid failed")
        local harbor = skynet.harbor(skynet.self())
        service = ((harbor & 0x3f) << 25) | ((sid & 0xffff) << 10)
    end
    if not timestamp then
        timestamp = (os.time() << 31) | service
        sequence = 0
        skynet_timeout(
            100,
            function()
                timestamp = nil
            end
        )
    end

    sequence = sequence + 1
    assert(sequence < 1024)

    return (timestamp | sequence)
end

function uuid.split(id)
    local _timestamp = id >> 31
    local _harbor = (id & 0x7fffffff) >> 25
    local _service = (id & 0x1ffffff) >> 10
    local _sequence = id & 0x3ff
    return _timestamp, _harbor, _service, _sequence
end

return uuid
