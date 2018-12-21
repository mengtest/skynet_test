local skynet = require "skynet"
local log = require "syslog"
local sharedata = require "skynet.sharedata"

local CMD = {}
local mapinstance = {}
local onlinecharacter = {}
local gate

--获取地图地址
function CMD.getmapaddressbyid(source, mapname)
	return mapinstance[mapname]
end

function CMD.open(source)
	gate = source
  local obj = sharedata.query "gdd"
  local mapdata = obj["map"]
	local n = 1
	while n > 0 do
	  for _, conf in pairs (mapdata) do
			local name = conf.name
			local m = skynet.newservice ("map", name)
			skynet.call (m, "lua", "open", conf)
			mapinstance[name] = m
		end
		n = n - 1
	end
end

function CMD.close()
  log.notice("close mapmgr...")
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
