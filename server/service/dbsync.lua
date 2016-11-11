local skynet = require "skynet"
local service = require "service"

local queue = {}
local CMD = {}
local run = false
local mysqlpool

local function sync_impl()
    while true do
        for k, v in pairs(queue) do
            skynet.call(mysqlpool, "lua", "execute", v.sql, v.write)
            queue[k] = nil
        end
        skynet.sleep(500)
    end
end

function CMD.open()
    skynet.fork(sync_impl)
    mysqlpool = skynet.uniqueservice("mysqlpool")
    run = true
end

function CMD.stop()
    run = false
end

function CMD.sync(sql,write)
    local v = { sql = sql, write = write}
    table.insert(queue, v)
end

service.init {
    command = CMD,
}