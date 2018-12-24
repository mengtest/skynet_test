local skynet = require "skynet"
local msgsender = require "msgsender"
require "skynet.manager"
local util = require "util"
local settimeout = util.settimeout

local idmgr = require "idmgr"
local log = require "syslog"
local basemap = require "map.basemap"
local aoimgr = require "map.aoimgr"
local monstermgr = require "map.monstermgr"
local createmonstermgr = require "map.createmonstermgr"

local CMD = basemap.cmd()
local update_thread
local config

skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    pack = function(text)
        return text
    end,
    unpack = function(buf, sz)
        return skynet.tostring(buf, sz)
    end
}

-- 0.1秒更新一次
local function maprun()
    monstermgr.monsterrun()
    aoimgr.update()
    update_thread = settimeout(10, maprun)
end

-- 获取临时id
function CMD.gettempid()
    return idmgr.createid()
end

-- 角色移动
function CMD.moveto(aoiobj)
    -- TODO 这边应该检查pos的合法性
    CMD.characterenter(aoiobj)
    return true, aoiobj.movement.pos
end

function CMD.open(conf)
    config = conf
    msgsender = msgsender.create()
    msgsender:init()
    idmgr.setmaxid(conf.maxtempid)
    basemap.init(conf)
    aoimgr.init(assert(skynet.launch("caoi", conf.name)))
    monstermgr.init(msgsender)
    createmonstermgr.init(conf.name)
    basemap.msgsender = msgsender
    createmonstermgr:createmonster()
    skynet.fork(maprun)
end

function CMD.close()
    log.notice("close map(%s)...", config.name)
    update_thread()
end

-- skynet.memlimit(10 * 1024 * 1024)

skynet.init(
    function()
    end
)

skynet.start(
    function()
        skynet.dispatch(
            "text",
            function(_, _, cmd)
                local t = cmd:split(" ")
                local f = assert(CMD[t[1]], "[" .. cmd .. "]")
                f(tonumber(t[2]), tonumber(t[3]))
            end
        )

        skynet.dispatch(
            "lua",
            function(_, _, command, ...)
                local f = assert(CMD[command], command)
                skynet.retpack(f(...))
            end
        )
    end
)
