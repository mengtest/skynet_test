local skynet = require "skynet"
local service = require "service"
local log = require "syslog"

local queue = {}
local CMD = {}
local run = false
local mysqlpool

local function sync_impl()
    while true do
        for k, v in pairs(queue) do
            local ret = skynet.call(mysqlpool, "lua", "execute", v, true)
            if ret.badresult then
                log.debug("errno:"..ret.errno.." sqlstate:"..ret.sqlstate.." err:"..ret.err.."\nsql:"..v)
            end
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
    table.insert(queue, sql)
end

service.init {
    command = CMD,
}