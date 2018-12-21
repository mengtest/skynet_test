local skynet = require "skynet"
local msgsender = require "msgsender"
require "skynet.manager"
local util = require "util"
local settimeout = util.settimeout

local log = require "syslog"
local basemap = require "map.basemap"
local aoimgr = require "map.aoimgr"
local monstermgr = require "map.monstermgr"

local CMD = {}
local onlinecharacter = {}
local pendingcharacter = {}
local update_thread
local map_info
local config

skynet.register_protocol {
  name = "text",
  id = skynet.PTYPE_TEXT,
  pack = function(text) return text end,
  unpack = function(buf, sz) return skynet.tostring(buf,sz) end,
}

--0.1秒更新一次
local function message_update ()
  aoimgr:update()
	update_thread = settimeout (10, message_update)
end

--角色请求进入地图
function CMD.characterenter(uuid,aoiobj)
  return map_info:createtempid()
end

--角色离开地图
function CMD.characterleave(aoiobj)
  aoimgr:characterleave(aoiobj)
  map_info:releasetempid(aoiobj.tempid)
end

--角色加载地图完成，正式进入地图
function CMD.characterready(uuid,aoiobj)
  aoimgr:characterenter(aoiobj)
  return true
end

--角色移动
function CMD.moveto(aoiobj)
  --TODO 这边应该检查pos的合法性
  aoimgr:characterenter(aoiobj)
  return true, aoiobj.movement.pos
end

function CMD.aoicallback(w,m)
  aoimgr:aoicallback(w,m)
end

function CMD.open(conf)
  config = conf
	msgsender = msgsender.create()
  msgsender:init()
  aoimgr = aoimgr.create(assert(skynet.launch("caoi", config.name)))
  message_update ()
  map_info = basemap.create(conf.id, conf.type, conf)
  map_info.CMD = CMD
	map_info.msgsender = msgsender
  map_info:loadmapinfo()
  monstermgr = monstermgr.create(msgsender)
end

function CMD.close()
  log.notice("close map(%s)...",config.name)
  update_thread()
  for k,_ in pairs(onlinecharacter) do
    skynet.call(k,"lua","close")
  end
end

local function merge (dest, t)
	if not dest or not t then return end
	for k, v in pairs (t) do
		dest[k] = v
	end
end

--skynet.memlimit(10 * 1024 * 1024)

skynet.init(function()
  
end)

skynet.start (function ()
  skynet.dispatch("text", function (_, _, cmd)
		local t = cmd:split(" ")
    local f = assert (CMD[t[1]],t[1])
    f(tonumber(t[2]),tonumber(t[3]))
  end)
  
	skynet.dispatch ("lua", function (_, _, command, ...)
		local f = assert (CMD[command],command)
		skynet.retpack (f (...))
	end)
end)
