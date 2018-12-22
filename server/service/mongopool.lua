local service = require"service"
local mongo = require"skynet.db.mongo"
local config = require"config.mongoconf"
local log = require"syslog"

local CMD = {}
local center
local group = {}
local ngroup
local index = 1

-- 获取db
local function getconn(write)
    local db
    if write then
        db = center
    else
        if ngroup > 0 then
            db = group[index]
            index = index + 1
            if index > ngroup then
                index = 1
            end
        else
            db = center
        end
    end
    assert(db)
    return db
end

function CMD.open()
    center = mongo.client(config.center)
    ngroup = #config.group
    for _, c in ipairs(config.group) do
        local db = mongo.client(c)
        table.insert(group, db)
    end
end

-- 执行sql语句
function CMD.execute(sql, write)
    local db = getconn(write)
    return db:query(sql)
end

function CMD.close()
    log.notice("close mongopoll...")
    center:logout()
    center = nil
    for _, db in pairs(group) do
        db:logout()
    end
    group = {}
end

service.init{
    command = CMD,
}
