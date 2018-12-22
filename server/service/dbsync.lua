local skynet = require"skynet"
local service = require"service"
local log = require"syslog"

local queue = {}
local CMD = {}
local mysqlpool

local traceback = debug.traceback

-- 将queue中的sql语句写入mysql中
local function sync_impl()
    while true do
        for k, v in pairs(queue) do
            local ok, ret = xpcall(skynet.call, traceback, mysqlpool, "lua", "execute", v, true)
            if not ok then
                log.warning("execute sql failed : %s", v)
            elseif ret.badresult then
                log.debug("errno:" .. ret.errno .. " sqlstate:" .. ret.sqlstate .. " err:" .. ret.err .. "\nsql:" .. v)
            end
            queue[k] = nil
        end
        skynet.sleep(500)
    end
end

function CMD.open()
    skynet.fork(sync_impl)
    mysqlpool = skynet.uniqueservice("mysqlpool")
end

function CMD.close() log.notice("close dbsync...") end

function CMD.sync(sql, now)
    if not now then
        table.insert(queue, sql)
    else
        local ret = skynet.call(mysqlpool, "lua", "execute", sql, true)
        if ret.badresult then
            log.debug("errno:" .. ret.errno .. " sqlstate:" .. ret.sqlstate .. " err:" .. ret.err .. "\nsql:" .. sql)
            return false
        end
    end
    return true
end

service.init{
    command = CMD,
}
