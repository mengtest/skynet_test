local skynet = require "skynet"
local handler = require "agent.handler"
local log = require "base.syslog"
local uuid = require "uuid"
local sharedata = require "skynet.sharedata"
local packer = require "db.packer"
local player = require "obj.player"

local user
local dbmgr
local namecheck
local jobdata
local mapdata
local world

local REQUEST = {}

local _handler = handler.new (REQUEST)

_handler:init (function (u)
	user = u
  dbmgr = skynet.uniqueservice ("dbmgr")
	namecheck = skynet.uniqueservice ("namecheck")
	world = skynet.uniqueservice ("world")
	local obj = sharedata.query "gdd"
	jobdata = obj["job"]
	mapdata = obj["map"]
end)

_handler:release (function ()
	user = nil
	dbmgr = nil
	namecheck = nil
	jobdata = nil
	mapdata = nil
	world = nil
end)

local function load_list ()
	local list = skynet.call (dbmgr, "lua", "playerdate", "getlist", user.uid)
	if not list then
		list = {}
	end
	return list
end

--获取角色列表
function REQUEST.getcharacterlist ()
	local character = load_list()
	user.characterlist = {}
	for k,_ in pairs(character) do
		user.characterlist[k] = true
	end
	return { character = character }
end

local function create (name, job, sex)
	local character = {
		uid = user.uid,
		name = name,
		job = job,
		sex = sex,
		uuid = uuid.gen(),
		level = 1,
		createtime = os.time(),
		logintime = os.time(),
		mapid = 0,
		x = 0,
		y = 0,
		z = 0,
		data = {
		}
	}

	return character
end

--创建角色
function REQUEST.charactercreate (args)
	if table.size(load_list ()) >= 3 then
		log.debug("%s create character failed, character num >= 3!",user.uid)
		return
	end
	--TODO 检查名称的合法性
	local result = skynet.call(namecheck,"lua","playernamecheck",args.name)
	if not result then
		log.debug("%s create character failed, name repeat!",user.uid)
		return
	end
	if jobdata[args.job] == nil then
		log.debug("%s create character failed, job error!",user.uid)
		return
	end
	local character = create(args.name, args.job, args.sex)
	if _handler.save(character) then
		user.characterlist[character.uuid] = true
		log.debug("%s create character succ!",user.uid)
	else
		log.debug("%s create character failed, save date failed!",user.uid)
	end
	return { character = character}
end

--初始化角色信息
local function initUserData(dbdata)
	assert(mapdata[dbdata.mapid])
	user.character = player.create()
	user.character:setmapid(mapdata[dbdata.mapid].name)
	--aoi对象，主要用于广播相关
	local aoiobj = {
		movement = {
			mode = "wm",
			pos = {
				x = dbdata.x,
				y = dbdata.y,
				z = dbdata.z,
			},
			map = dbdata.mapid,
		},
		info = {
			fd = user.fd,
		},
	}
	user.character:setaoiobj(aoiobj)
	--角色信息
	local playerinfo = {
		name = dbdata.name,
		job = dbdata.job,
		sex = dbdata.sex,
		level = dbdata.level,
		uuid = dbdata.uuid,
	}
	user.character:setobjinfo(playerinfo)
	user.character:setdata(dbdata.data)
	user.character:set_msgsender(user.msgsender)
end

--选择角色
function REQUEST.characterpick (args)
	if user.characterlist[args.uuid] == nil then
		log.debug("%s pick character failed!",user.uid)
		return
	end
	local list = skynet.call (dbmgr, "lua", "playerdate", "load", user.uid,args.uuid)
	if list.uuid then
		log.debug("%s pick character[%s] succ!",user.uid,list.name)
		user.characterlist = nil
		initUserData(list)
		local ret = skynet.call (world, "lua", "characterenter", list.uuid, user.character:getmapid(), user.character:getaoiobj())
		return {ok = ret}
	else
		return {ok = false}
	end
end

--保存角色信息
function _handler.save (character)
	if not character then
		log.debug("save character failed,not character.")
		return
	end
	character.data = packer.pack(character.data)
	return skynet.call (dbmgr, "lua", "playerdate", "save", character)
end


return _handler
