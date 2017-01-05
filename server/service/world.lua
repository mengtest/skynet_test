local skynet = require "skynet"
local log = require "syslog"
local sharedata = require "sharedata"

local CMD = {}
local mapinstance = {}
local onlinecharacter = {}

function CMD.kick (uuid)
	local a = onlinecharacter[uuid]
	if a then
		skynet.call (a, "lua", "logout")
		onlinecharacter[uuid] = nil
    log.debug("kick uuid(%d) out of world",uuid)
	end
end

function CMD.characterenter(agent, uuid)
  if onlinecharacter[uuid] ~= nil then
		log.notice ("multiple login detected, uuid %d", uuid)
		CMD.kick (uuid)
	end

	onlinecharacter[uuid] = agent
	log.notice ("uuid(%d) enter world ,agent(%d)", uuid,agent)
  --获取玩家需要去的地图和坐标
	local map, pos = skynet.call (agent, "lua", "worldenter", skynet.self ())

	local m = mapinstance[map]
	if not m then
    log.debug("uuid(%d) error map :"..map,uuid)
		CMD.kick (uuid)
		return
	end

	skynet.call (m, "lua", "characterenter", agent, uuid, pos)
end

function CMD.characterlevel(agent,uuid)
  log.notice ("uuid(%d) level world ,agent(%d)", uuid,agent)
  onlinecharacter[uuid] = nil
end

function CMD.open()
  log.debug("world open")
  local obj = sharedata.query "gdd"
  local mapdata = obj["map"]
  for _, conf in pairs (mapdata) do
		local name = conf.name
		local m = skynet.newservice ("map", skynet.self ())
		skynet.call (m, "lua", "open", conf)
		mapinstance[name] = m
	end
end

function CMD.close()
  log.debug("world close")
  for name, map in pairs (mapinstance) do
    skynet.call (map, "lua", "close")
    mapinstance[name] = nil
  end
end

skynet.start (function ()
	skynet.dispatch ("lua", function (_, source, command, ...)
		local f = assert (CMD[command])
		skynet.retpack (f (source, ...))
	end)
end)
