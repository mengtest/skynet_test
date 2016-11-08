local skynet = require "skynet"
local service = require "service"

local queue = {}
local CMD = {}
local run = false

local function sync_impl()
    while true do
        for k, v in pairs(queue) do
            skynet.call("mysqlpool", "lua", "execute", v.sql, v.write)
            queue[k] = nil
        end
        skynet.sleep(500)
    end
end

function CMD.open()
    skynet.fork(sync_impl)
    run = false
end

function CMD.stop()
    run = false
end

function CMD.sync(sql)
    table.insert(queue, sql)
end

service.init {
    command = CMD,
}