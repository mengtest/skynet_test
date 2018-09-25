local skynet = require "skynet"
local queue = require "skynet.queue"
local log = require "syslog"
local msgsender = require "msgsender"
local timer = require "timer"

local testhandler = require "agent.testhandler"
local character_handler = require "agent.character_handler"
local map_handler = require "agent.map_handler"
local aoi_handler = require "agent.aoi_handler"
local move_handler = require "agent.move_handler"

local gate = tonumber(...)
local requestqueue = queue()
local responsequeue = queue()
local luaqueue = queue()
local CMD = {}
local InitCMD = {}
local sender = {}

local agentstatus = {
	AGENT_INIT = 1,
	AGENT_RUNNING = 2,
	AGENT_QUIT = 3,
}

local user
local host

local running = {
	status = agentstatus.AGENT_INIT
}

--玩家的run
local function playerrun()
	while (true) do
		if running.status == agentstatus.AGENT_RUNNING then
			local nowtime = timer.gettime()
			--玩家延迟检测
			user.character.moveobj:delayrun(nowtime)
			skynet.sleep(10)
		else
			break
		end
	end
end

--当请求退出和被T出的时候
--因为请求消息在requestqueue，而被T的消息在luaqueue中
--这边可能重入
local function logout(type)
	if not user or running.status ~= agentstatus.AGENT_RUNNING then return end
	running.status = agentstatus.AGENT_QUIT
	log.notice("logout, agent(:%08X) type(%d) subid(%d)",skynet.self(),type,user.subid)

	skynet.send(gate, "lua", "logout", user.uid, user.subid)

	if user.map then
		local map = user.map
		user.map = nil
		if map then
			skynet.call(map, "lua", "characterleave", user.character:getaoiobj())
			--在玩家被挤下线的时候，这边可能还没有init
			--所以要放在这边release
			map_handler:unregister(user)
			aoi_handler:unregister(user)
			move_handler:unregister(user)
		end
	end
	if user.world then
		local world = user.world
		user.world = nil
		if world then
			skynet.call(world, "lua", "characterleave", user.character:getuuid())
		end
	end

	testhandler:unregister(user)
	character_handler:unregister (user)
	user = nil
	skynet.send(gate, "lua", "addtoagentpool", skynet.self())
	running.status = agentstatus.AGENT_INIT
	--不退出，在这里清理agent的数据就行了
	--会在gated里面将该agent加到agentpool中
	--skynet.exit()
end

--心跳检测
local last_heartbeat_time = 0
local HEARTBEAT_TIME_MAX = 0 * 100
local function heartbeatcheck ()
	if HEARTBEAT_TIME_MAX <= 0 or running.status ~= agentstatus.AGENT_RUNNING then return end

	local t = last_heartbeat_time + HEARTBEAT_TIME_MAX - skynet.now ()
	if t <= 0 then
		log.warning ("heatbeat check failed")
		logout(1)
	else
		skynet.timeout (t, heartbeatcheck)
	end
end

local traceback = debug.traceback
--接受到的请求
local REQUEST = {}
local function handlerequest (name, args, response)
	--log.warning ("get handle_request from client: %s", name)
	local f = REQUEST[name]
	if f then
		local ok, ret = xpcall (f, traceback, args)
		if not ok then
			log.warning ("handle message(%s) failed : %s", name, ret)
			logout(2)
		else
			last_heartbeat_time = skynet.now ()
			if response and ret then
				return response (ret)
			end
		end
	else
		log.warning ("unhandled message : %s", name)
		logout(3)
	end
end

--接受到的回应
--现在不应该收到回应
local RESPONSE = {}
local function handle_response (id, args)
	log.warning ("handle_response : %d", id)
end

--处理client发来的消息
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return host:dispatch (msg, sz)
	end,
	dispatch = function (_, _, type, ...)
		if type == "REQUEST" then
			local result = luaqueue(handlerequest, ...)
			if result then
				skynet.ret(result)
			end
		elseif type == "RESPONSE" then
			luaqueue(handle_response, ...)
		else
			log.warning("invalid message type : %s", type)
			logout(7)
		end
		skynet.sleep(10)
	end,
}

--通知agent进入world
function InitCMD.worldenter(_,world)
	user.world = world
	character_handler:unregister (user)
	user.character:setaoimode("w")
end

--通知agent进入地图
function InitCMD.mapenter(_,map,tempid)
	user.map = map
	user.character:settempid(tempid)

	log.debug("enter map and set tempid:"..user.character:gettempid())
	map_handler:register(user)
	aoi_handler:register(user)
	move_handler:register(user)
	running.status = agentstatus.AGENT_RUNNING
	heartbeatcheck ()
	skynet.fork(playerrun)
end

--gate 通知 agent 有玩家正在认证
function InitCMD.login(source, uid, sid, secret, fd)
	-- you may use secret to make a encrypted data stream
	log.notice("%s is login",uid)
	user = {
		uid = uid,
		subid = sid,
		REQUEST = {},
		RESPONSE = {},
		CMD = CMD,
		sendrequest = sender.sendrequest,
		msgsender = msgsender,
		running = running,
	}
end

--gate 通知 agent 认证成功
function InitCMD.auth(source, fd)
	user.fd = fd
	
	REQUEST = user.REQUEST
	RESPONSE = user.RESPONSE
	msgsender:init()
	host = msgsender:gethost()
	-- you may load user data from database
	testhandler:register(user)
	character_handler:register(user)
	--心跳检测
	last_heartbeat_time = skynet.now ()
end

function CMD.logout(_)
	--下线
	-- NOTICE: The logout MAY be reentry
	logout(0)
end

function InitCMD.logout(_)
	--下线
	-- NOTICE: The logout MAY be reentry
	logout(0)
end

function CMD.afk(_)
	-- the connection is broken, but the user may back
	log.notice("%s AFK",user.uid)
end

function InitCMD.afk(_)
	-- the connection is broken, but the user may back
	log.notice("%s AFK",user.uid)
end

function InitCMD.close()
	log.notice("close agent(:%08X)",skynet.self())
	logout(8)
	skynet.exit()
end

skynet.memlimit(1 * 1024 * 1024)

--发送广播消息给client
--消息名，参数列表，是否发送给指定对象，是否广播，广播时是否排除自己
function sender.sendrequest(name, args, ref, not_send_to_me, fdlist)
	if fdlist then
		--广播给指定列表中的对象
		user.character:sendboardrequest(name, args, fdlist)
	else
		if ref then
			if not_send_to_me then
				--广播消息不发送给自己
				user.character:sendboardrequest(name, args, user.character:getaoilist())
			else
				--广播消息发送给自己
				fdlist = user.character:getaoilist()
				table.insert(fdlist,user.character:getaoiobj())
				user.character:sendboardrequest(name, args, fdlist)
			end
		else
			--发送消息给自己
			user.character:sendrequest(name, args)
		end
	end
end

skynet.start(function()
	-- If you want to fork a work thread , you MUST do it in CMD.login
	--加载proto
	msgsender = msgsender.create()

	skynet.dispatch("lua", function(_, source, command, ...)
		local docmd
		if running.status == agentstatus.AGENT_INIT then
			local f = assert(InitCMD[command],command)
			docmd =  function (f,source, ...)
						if running.status == agentstatus.AGENT_INIT then
							return f(source, ...)
						end
					end
			skynet.ret(skynet.pack(luaqueue(docmd,f,source, ...)))
		elseif running.status == agentstatus.AGENT_RUNNING then
			local f = assert(CMD[command],command)
			docmd =  function (f,source, ...)
						if running.status == agentstatus.AGENT_RUNNING then
							return f(source, ...)
						end
					end
			skynet.ret(skynet.pack(luaqueue(docmd,f,source, ...)))
		end
	end)
end)
