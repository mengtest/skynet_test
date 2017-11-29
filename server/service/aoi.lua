local skynet = require "skynet"
local log = require "syslog"
local util = require "util"
local enumtype = require "enumtype"
local queue = require "skynet.queue"
require "skynet.manager"
local set_timeout = util.set_timeout

local luaqueue = queue()
local CMD = {}
local OBJ = {}
local OBJVIEWE = {}
local aoi
local update_thread
local need_update
local map_name = ...

local AOI_RADIS = 200
local AOI_RADIS2 = AOI_RADIS * AOI_RADIS
local LEAVE_AOI_RADIS2 = AOI_RADIS2 * 4

local function DIST2(p1,p2)
	return ((p1.x - p2.x) * (p1.x  - p2.x) + (p1.y  - p2.y) * (p1.y  - p2.y) + (p1.z  - p2.z) * (p1.z  - p2.z))
end

skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	pack = function(text) return text end,
	unpack = function(buf, sz) return skynet.tostring(buf,sz) end,
}

local function inserttotablebytype(t,v,type)
	if type ~= enumtype.CHAR_TYPE_PLAYER then
		table.insert(t.monsterlist,v)
	else
		table.insert(t.playerlist,v)
	end
end

--观看者坐标更新的时候
--根据距离情况通知他人自己的信息
local function updateview(viewertempid)
	if OBJVIEWE[viewertempid] == nil then return end
	local myobj = OBJ[viewertempid]
	local mypos = myobj.movement.pos

	--离开他人视野
	local leavelist = {
		playerlist = {},
		monsterlist = {},
	}
	--进入他人视野
	local enterlist = {
		playerlist = {},
		monsterlist = {},
	}
	--通知他人自己移动
	local movelist = {
		playerlist = {},
		monsterlist = {},
	}

	local othertempid
	local otherpos
	local othertype
	local otherobj
	for k,v in pairs(OBJVIEWE[viewertempid]) do
		if OBJ[k] == nil then
			--print(OBJVIEWE[viewertempid])
			--print(OBJ)
			--print("========:"..k)
		end
		othertempid = OBJ[k].tempid
		otherpos = OBJ[k].movement.pos
		othertype = OBJ[k].type
		otherobj = {
			tempid = othertempid,
			agent = OBJ[k].agent,
		}
		local distance = DIST2(mypos,otherpos)
		if distance <= AOI_RADIS2 then
			if not v then
				OBJVIEWE[viewertempid][k] = true
				OBJVIEWE[k][viewertempid] = true
				inserttotablebytype(enterlist,OBJ[k],othertype)
			else
				inserttotablebytype(movelist,otherobj,othertype)
			end
		elseif distance > AOI_RADIS2 and distance <= LEAVE_AOI_RADIS2 then
			if v then
				OBJVIEWE[viewertempid][k] = false
				OBJVIEWE[k][viewertempid] = false
				inserttotablebytype(leavelist,otherobj,othertype)
			end
		else
			if v then
				inserttotablebytype(leavelist,otherobj,othertype)
			end
			OBJVIEWE[viewertempid][k] = nil
			OBJVIEWE[k][viewertempid] = nil
		end
	end
	local mapagent = skynet.self() - 1
	--离开他人视野
	for _,v in pairs(leavelist.playerlist) do
		skynet.send(v.agent,"lua","delaoiobj",viewertempid)
	end

	--重新进入视野
	for _,v in pairs(enterlist.playerlist) do
		skynet.send(v.agent,"lua","addaoiobj",myobj)
	end

	--视野范围内移动
	for _,v in pairs(movelist.playerlist) do
		skynet.send(v.agent,"lua","updateaoiobj",myobj)
	end

	--怪物的更新合并一起发送
	if not table.empty(leavelist.monsterlist) or
	not table.empty(enterlist.monsterlist) or
	not table.empty(movelist.monsterlist) then
		local monsterenterlist = {
			obj = myobj,
			monsterlist = enterlist.monsterlist,
		}
		local monsterleavelist = {
			tempid = viewertempid,
			monsterlist = leavelist.monsterlist,
		}
		local monstermovelist = {
			obj = myobj,
			monsterlist = movelist.monsterlist,
		}
		skynet.send(mapagent,"lua","updateaoiinfo",monsterenterlist,monsterleavelist,monstermovelist)
	end

	--通知自己
	if myobj.type ~= enumtype.CHAR_TYPE_PLAYER then
		skynet.send(myobj.agent,"lua","updateaoilist",myobj.tempid,enterlist,leavelist)
	else
		skynet.send(myobj.agent,"lua","updateaoilist",enterlist,leavelist)
	end
end

--aoi回调
function CMD.aoicallback(w,m)
	assert(OBJ[w],w)
	assert(OBJ[m],m)

	if OBJVIEWE[OBJ[w].tempid] == nil then
		OBJVIEWE[OBJ[w].tempid] = {}
	end
	OBJVIEWE[OBJ[w].tempid][OBJ[m].tempid] = true

	--通知agent
	if OBJ[w].type ~= enumtype.CHAR_TYPE_PLAYER then
		skynet.send(OBJ[w].agent,"lua","addaoiobj",OBJ[w].tempid,OBJ[m])
	else
		skynet.send(OBJ[w].agent,"lua","addaoiobj",OBJ[m])
	end
end

--添加到aoi
function CMD.characterenter(obj)
  assert(obj)
	assert(obj.agent)
  assert(obj.movement)
	assert(obj.movement.mode)
	assert(obj.movement.pos.x)
	assert(obj.movement.pos.y)
	assert(obj.movement.pos.z)
  --log.debug("AOI ENTER %d %s %d %d %d",obj.tempid,obj.movement.mode,obj.movement.pos.x,obj.movement.pos.y,obj.movement.pos.z)
	OBJ[obj.tempid] = obj
	updateview(obj.tempid)
	assert(pcall(skynet.send,aoi, "text", "update "..obj.tempid.." "..obj.movement.mode.." "..obj.movement.pos.x.." "..obj.movement.pos.y.." "..obj.movement.pos.z))
	need_update = true
end

--从aoi中移除
function CMD.characterleave(obj)
	assert(obj)
	log.debug("%d leave aoi",obj.tempid)
	assert(pcall(skynet.send,aoi, "text", "update "..obj.tempid.." d "..obj.movement.pos.x.." "..obj.movement.pos.y.." "..obj.movement.pos.z))
	OBJ[obj.tempid] = nil
	for k,v in pairs(OBJVIEWE[obj.tempid]) do
		OBJVIEWE[k][obj.tempid] = nil
	end
	OBJVIEWE[obj.tempid] = nil
	need_update = true
end

--0.1秒更新一次
local function message_update ()
	if need_update then
		need_update = false
		assert(pcall(skynet.send,aoi, "text", "message "))
	end
	update_thread = set_timeout (10, message_update)
end

function CMD.open()
  aoi = assert(skynet.launch("caoi", map_name))
	assert(aoi == (skynet.self() + 1))
	message_update()
end

function CMD.close(name)
  log.notice("close aoi(%s)...",name)
	update_thread()
end

skynet.start(function()
	skynet.dispatch("text", function (_, _, cmd)
		local t = cmd:split(" ")
		local f = CMD[t[1]]
		if f then
			f(tonumber(t[2]),tonumber(t[3]))
		else
			log.notice("Unknown command : [%s]", cmd)
		end
	end)

	skynet.dispatch("lua", function (_,_, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log.notice("Unknown command : [%s]", cmd)
			skynet.response()(false)
		end
	end)
end)
