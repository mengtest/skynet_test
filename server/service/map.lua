local skynet = require "skynet"
local log = require "syslog"

local CMD = {}
local onlinecharacter = {}
local pendingcharacter = {}
local aoi

local world = tonumber(...)
local config

local temp = 1

function CMD.characterenter(agent, uuid,aoiobj)
  log.debug("uuid(%d) enter map(%s)",uuid,config.name)
  assert(aoi)
  aoiobj.tempid = temp
  temp = temp + 1
  pendingcharacter[agent] = uuid
  skynet.call (agent, "lua", "mapenter", skynet.self (),aoiobj.tempid)
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
    log.debug("uuid(%d) post load map ready,BUT not find in pendingcharacter",uuid)
    return false
  end
  onlinecharacter[agent] = pendingcharacter[agent]
  pendingcharacter[agent] = nil
  log.debug("uuid(%d) load map ready",uuid)
  skynet.call(aoi,"lua","characterenter",agent,aoiobj)
  return true
end

function CMD.moveto(agent,aoiobj)
  if onlinecharacter[agent] == nil then
    log.debug("uuid(%d) post load map ready,BUT not find in pendingcharacter",uuid)
    return false
  end
  --TODO 这边应该检查pos的合法性
  skynet.call(aoi,"lua","characterenter",agent,aoiobj)
  return true, aoiobj.pos
end

function CMD.open(conf)
  config = conf
  aoi = skynet.newservice("aoi")
  skynet.call(aoi,"lua","open",config)
  log.debug("map(%s) open",config.name)
end

function CMD.close()
  log.debug("map(%s) close",config.name)
end

skynet.start (function ()
	skynet.dispatch ("lua", function (_, _, command, ...)
		local f = assert (CMD[command])
		skynet.retpack (f (...))
	end)
end)
