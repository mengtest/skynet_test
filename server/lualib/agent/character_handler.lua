local skynet = require "skynet"
local handler = require "agent.handler"
local log = require "base.syslog"
local uuid = require "uuid"

local user
local dbmgr

local REQUEST = {}

_handler = handler.new (REQUEST)

_handler:init (function (u)
	user = u
  dbmgr = skynet.uniqueservice ("dbmgr")
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
	--TODO 检查name合法性
	local character = create(args.name, args.job, args.sex)
	_handler.save(character)
	return { character = character}
end

--选择角色
function REQUEST.character_pick (args)

end

--初始化角色信息
function _handler.init (character)

end

--保存角色信息
function _handler.save (character)

	skynet.call (dbmgr, "lua", "playerdate", "save", user.uid,character)
end


return _handler
