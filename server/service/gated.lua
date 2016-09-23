local msgserver = require "snax.msgserver"
local crypt = require "crypt"
local skynet = require "skynet"

local loginservice = tonumber(...)

local server = {}
local users = {}
local username_map = {}
local internal_id = 0

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
--login server通知用户登陆game server
function server.login_handler(uid, secret)
	if users[uid] then
		error(string.format("%s is already login", uid))
	end

	internal_id = internal_id + 1
	local id = internal_id	-- don't use internal_id directly
	local username = msgserver.username(uid, id, servername)

	-- you can use a pool to alloc new agent
	local agent = skynet.newservice "msgagent"
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
	end
end

-- call by login server
function server.kick_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		-- NOTICE: logout may call skynet.exit, so you should use pcall.
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
function server.request_handler(username, msg)
	local u = username_map[username]
	return skynet.tostring(skynet.rawcall(u.agent, "client", msg))
end

-- call by self (when gate open)
--注册自己，当服务启动的时候
--通过对gate发送open请求的时候
--在msgserver的open中调用了
function server.register_handler(name)
	servername = name
	--向logind发送请求
	--将自己注册到server_list
	skynet.call(loginservice, "lua", "register_gate", servername, skynet.self())
end

--向msgserver注册前面server中定义的方法
msgserver.start(server)

