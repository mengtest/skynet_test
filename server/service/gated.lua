local msgserver = require "snax.msgserver"
local skynet = require "skynet"
local sharemap = require "sharemap"
local log = require "syslog"

local loginservice = tonumber(...)

local server = {}
local users = {}
local username_map = {}
local internal_id = 0
local agentpool = {}
local servername
local world

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
--login server通知用户登陆game server
function server.login_handler(uid, secret)
	if users[uid] then
		log.warning("%s is already login", uid)
	end

	internal_id = internal_id + 1
	local id = internal_id	-- don't use internal_id directly
	local username = msgserver.username(uid, id, servername)
	-- agent pool
	local agent
	if #agentpool == 0 then
		agent = skynet.newservice "msgagent"
		log.debug("pool is empty, new agent(:%08X) created", agent)
	else
		agent = table.remove(agentpool,1)
		log.debug("agent(:%08X) assigned, %d remain in pool", agent, #agentpool)
	end

	local u = {
		username = username,
		agent = agent,
		uid = uid,
		subid = id,
	}

	-- trash subid (no used)
	--msgagent记录
	skynet.call(agent, "lua", "login", uid, id, secret)

	users[uid] = u
	username_map[username] = u

	--将用户信息记录到msgserver
	--用户在与msgseerver连接的时候，这里用于验证
	msgserver.login(username, secret)

	-- you should return unique subid
	return id
end

-- call by agent
function server.logout_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		msgserver.logout(u.username)
		users[uid] = nil
		username_map[u.username] = nil
		skynet.call(loginservice, "lua", "logout",uid, subid)
		--table.insert(agentpool,u.agent)
	end
end

-- call by login server
function server.kick_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		-- NOTICE: logout may call skynet.exit, so you should use pcall.
		log.debug("kick %s ",uid)
		pcall(skynet.call, u.agent, "lua", "logout")
	end
end

-- call by self (when socket disconnect)
function server.disconnect_handler(username)
	local u = username_map[username]
	if u then
		skynet.call(u.agent, "lua", "afk")
	end
end

-- call by self (when recv a request from client)
-- 从client收到消息的时候，调用这里去call agent
function server.request_handler(username, msg)
	local u = username_map[username]
	return skynet.tostring(skynet.rawcall(u.agent, "client", msg))
end

-- call by self (when gate open)
--注册自己，当服务启动的时候
--通过对gate发送open请求的时候
--在msgserver的open中调用了
function server.register_handler(conf)
	servername = assert(conf.servername)
	--向logind发送请求
	--将自己注册到server_list
	skynet.call(loginservice, "lua", "register_gate", servername, skynet.self())
	skynet.uniqueservice ("gdd")
	world = skynet.uniqueservice ("world")
	sharemap.register("./common/sharemap/sharemap.sp")
	skynet.call(world, "lua", "open")

	local n = assert(conf.agentpool) or 0
	for _ = 1, n do
		table.insert(agentpool,skynet.newservice("msgagent"))
	end
	log.notice("create %d agent",n)
end

--call by msgagent(server send request)
function server.send_request_handler(uid, subid, msg)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		msgserver.request(u.username,msg)
	end
end

--发送同一条消息给多个user
function server.send_board_request_handler(msg,userlist)
	for _,v in pairs(userlist) do
		if v.cansend then
			local u = users[v.info.uid]
			if u then
				local username = msgserver.username(v.info.uid, v.info.subid, servername)
				assert(u.username == username)
				msgserver.request(u.username,msg)
			end
		end
	end
end

-- call by agent
function server.addtoagentpool_handler(agent)
	log.debug("!!!add old agent(:%08X) to pool",agent)
	table.insert(agentpool,agent)
end

-- 退出服务
function server.close_handler()
	log.notice("close gated...")
	--这边通知所有服务退出
	skynet.call(world, "lua", "close")
	local dbmgr = skynet.uniqueservice "dbmgr"
	skynet.call(dbmgr, "lua", "system", "close")
end

--向msgserver注册前面server中定义的方法
msgserver.start(server)
