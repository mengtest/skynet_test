local skynet = require "skynet"
local log = require "syslog"

local CMD = {}
local onlinecharacter = {}
local aoi

local world = tonumber(...)
local config

local temp = 1

function CMD.characterenter(agent, uuid,aoiobj)
  if onlinecharacter[uuid] then
    log.debug("uuid(%d) alreday in map(%s)",uuid,config.name)
    return
  end
  log.debug("uuid(%d) enter map(%s)",uuid,config.name)
  onlinecharacter[uuid] = agent
  assert(aoi)
  aoiobj.tempid = temp
  temp = temp + 1
  skynet.call (agent, "lua", "mapenter", skynet.self (),aoiobj.tempid)
  skynet.call(aoi,"lua","characterenter",agent,aoiobj)
end

function CMD.characterleave(uuid,aoiobj)
  log.debug("uuid(%d) leave map(%s)",uuid,config.name)
  skynet.call(aoi,"lua","characterleave",aoiobj)
  onlinecharacter[uuid] = nil
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
