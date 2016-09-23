local login = require "snax.loginserver"
local crypt = require "crypt"
local skynet = require "skynet"

local server = {
	host = "127.0.0.1",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

--服务器列表
local server_list = {}
--在线玩家列表
local user_online = {}
--玩家登陆列表
local user_login = {}

--认证
--在这个方法内做远程调用（skynet.call）是安全的。
function server.auth_handler(token)
	print("调用server.auth_handler："..token)
	-- the token is base64(user)@base64(server):base64(password)
	local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
	user = crypt.base64decode(user)
	server = crypt.base64decode(server)
	password = crypt.base64decode(password)
	assert(password == "password", "Invalid password")
	print("user:"..user.." server:"..server.." password:"..)
	return server, user
end

--登陆到游戏服务器
function server.login_handler(server, uid, secret)
	print("调用server.login_handler:".." server:"..server.." uid:"..uid.." secret:"..secret)
	print(string.format("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret)))
	--校验要登陆的服务器是否存在
	--gate启动的时候注册到server_list了
	local gameserver = assert(server_list[server], "Unknown server")
	-- only one can login, because disallow multilogin
	local last = user_online[uid]
	--已经登陆了的话，把上次登录的踢下线
	if last then
		skynet.call(last.address, "lua", "kick", uid, last.subid)
	end
	if user_online[uid] then
		error(string.format("user %s is already online", uid))
	end
	--向服务器发送登陆请求
	local subid = tostring(skynet.call(gameserver, "lua", "login", uid, secret))
	user_online[uid] = { address = gameserver, subid = subid , server = server}
	return subid
end

local CMD = {}

--注册一个服务器
function CMD.register_gate(server, address)
	print("调用server.login_handler:".." server:"..server.." address:"..address)
	server_list[server] = address
end

--玩家下线
function CMD.logout(uid, subid)
	print("调用CMD.logout:".." uid:"..uid.." subid:"..subid)
	local u = user_online[uid]
	if u then
		print(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function server.command_handler(command, ...)
	print("调用server.command_handler".." command:"..command)
	local f = assert(CMD[command])
	return f(...)
end

login(server)
