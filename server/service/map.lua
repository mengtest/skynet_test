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
local function maprun()
  monstermgr:monsterrun()
  aoimgr:update()
	update_thread = settimeout (10, maprun)
end

function CMD.addaoiobj(monstertempid,aoiobj)
  --return monstermgr:addaoiobj(monstertempid,aoiobj)
end

function CMD.updatemonsteraoiinfo(enterlist,leavelist,movelist)
  --return monstermgr:updatemonsteraoiinfo(enterlist,leavelist,movelist)
end

function CMD.updateaoilist(monstertempid,enterlist,leavelist)
  --return monstermgr:updateaoilist(monstertempid,enterlist,leavelist)
end

--获取临时id
function CMD.gettempid()
  return map_info:createtempid()
end

--角色请求进入地图
function CMD.characterenter(aoiobj)
  aoimgr:characterenter(aoiobj)
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
  map_info = basemap.create(conf.id, conf.type, conf)
  aoimgr = aoimgr.create(assert(skynet.launch("caoi", conf.name)),map_info)
  map_info.CMD = CMD
  map_info.msgsender = msgsender
  map_info.aoimgr = aoimgr
  map_info:loadmapinfo()
  monstermgr = monstermgr.create(msgsender, conf.monster_list, aoimgr, map_info)
  monstermgr:createmonster()
  map_info.monstermgr = monstermgr
  
  skynet.fork(maprun)
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
    local f = assert (CMD[t[1]],"["..cmd.."]")
    f(tonumber(t[2]),tonumber(t[3]))
  end)
  
	skynet.dispatch ("lua", function (_, _, command, ...)
		local f = assert (CMD[command],command)
		skynet.retpack (f (...))
	end)
end)
