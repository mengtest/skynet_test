local skynet = require "skynet"
local log = require "syslog"
local mapfun = require "map.map_handle"

local CMD = {}
local onlinecharacter = {}
local pendingcharacter = {}
local aoi

local world = ...
world = tonumber(world)
local config

local temp = 1

function CMD.characterenter(agent, uuid,aoiobj)
  log.debug("uuid(%d) enter map(%s)",uuid,config.name)
  assert(aoi)
  aoiobj.tempid = temp
  temp = temp + 1
  pendingcharacter[agent] = uuid
  skynet.send (agent, "lua", "mapenter", skynet.self (),aoiobj.tempid)
  aoiobj.movement.mode = "w"
  skynet.call(aoi,"lua","characterenter",agent,aoiobj)
  return true
end

function CMD.characterleave(agent, aoiobj)
  local uuid = onlinecharacter[agent] or pendingcharacter[agent]
  if uuid ~=nil then
    log.debug("uuid(%d) leave map(%s)",uuid,config.name)
    skynet.call(aoi,"lua","characterleave",aoiobj)
  else
    log.debug("uuid(%d) leave map(%s) BUT cannot find !",uuid,config.name)
  end
  onlinecharacter[agent] = nil
  pendingcharacter[agent] = nil
end

function CMD.characterready(agent,uuid,aoiobj)
  if pendingcharacter[agent] == nil then
    log.debug("user(%s) post load map ready,BUT not find in pendingcharacter",aoiobj.info.uid)
    return false
  end
  onlinecharacter[agent] = pendingcharacter[agent]
  pendingcharacter[agent] = nil
  log.debug("uuid(%d) load map ready",uuid)
  aoiobj.movement.mode = "wm"
  skynet.call(aoi,"lua","characterenter",agent,aoiobj)
  --skynet.call(agent,"lua","updateinfo")
  return true
end

function CMD.moveto(agent,aoiobj)
  if onlinecharacter[agent] == nil then
    log.debug("user(%d) post load map ready,BUT not find in pendingcharacter",aoiobj.info.uid)
    return false
  end
  --TODO 这边应该检查pos的合法性
  skynet.call(aoi,"lua","characterenter",agent,aoiobj)
  return true, aoiobj.movement.pos
end

function CMD.open(conf)
  config = conf
  aoi = skynet.newservice("aoi")
  skynet.call(aoi,"lua","open",config.name)
  mapfun.init(conf,aoi)
end

function CMD.close()
  log.notice("close map(%s)...",config.name)
  skynet.call(aoi,"lua","close",config.name)
  for k,_ in pairs(onlinecharacter) do
    skynet.call(k,"lua","close")
  end
end

skynet.start (function ()
	skynet.dispatch ("lua", function (_, _, command, ...)
		local f = assert (CMD[command])
		skynet.retpack (f (...))
	end)
end)
