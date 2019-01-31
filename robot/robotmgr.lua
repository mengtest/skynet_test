local skynet = require "skynet"
local r = require "robot.robot"

local CMD = {}
local robot = {}

function CMD.init(index, count, server, ip, port)
    for i = 1, count do
        table.insert(robot, r.create(index, server, ip, port, index * count + i))
    end
end

function CMD.start()
    for _, v in pairs(robot) do
        v:start()
    end
end

function CMD.close()
    for _, v in pairs(robot) do
        v:close()
    end
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(_, source, command, ...)
                local f = assert(CMD[command], command)
                skynet.ret(skynet.pack(f(...)))
            end
        )
    end
)
