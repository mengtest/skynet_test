local skynet = require "skynet"
local handler = require "agent.handler"
local log = require "base.syslog"
local uuid = require "uuid"
local sharedata = require "sharedata"

local user
local dbmgr
local namecheck
local job = {}

local REQUEST = {}

_handler = handler.new (REQUEST)

_handler:init (function (u)
	user = u
  dbmgr = skynet.uniqueservice ("dbmgr")
	namecheck = skynet.uniqueservice ("namecheck")
	local obj = sharedata.query "gdd"
	job = obj["job"]
end)

local function load_list ()
	local list = skynet.call (dbmgr, "lua", "playerdate", "getlist", user.uid)
	if not list then
		list = {}
	end
	return list
end

local function check_character (args)

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
	local character = {}
	character.uid = user.uid
	character.name = name
	character.job = job
	character.sex = sex
	character.uuid = uuid.gen()
	character.level = 1
	character.createtime = os.time()
	character.logintime = os.time()
	character.nx = 0
	character.ny = 0
	character.nz = 0
	return character
end

--创建角色
function REQUEST.charactercreate (args)
	if table.size(user.characterlist) >= 3 then
		log.debug("%s create character failed, character num >= 3!",user.uid)
		return
	end
	local result = skynet.call(namecheck,"lua","playernamecheck",args.name)
	if not result then
		log.debug("%s create character failed, name repeat!",user.uid)
		return
	end
	if job[args.job] == nil then
		log.debug("%s create character failed, job error!",user.uid)
		return
	end
	local character = create(args.name, args.job, args.sex)
	if _handler.save(character) then
		user.characterlist[character.uuid] = true
		log.debug("%s create character succ!",user.uid)
	end
	return { character = character}
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
		return {ok = true}
	else
		return {ok = false}
	end
end

--初始化角色信息
function _handler.init (character)

end

--保存角色信息
function _handler.save (character)

	skynet.call (dbmgr, "lua", "playerdate", "save", user.uid,character)
end


return _handler