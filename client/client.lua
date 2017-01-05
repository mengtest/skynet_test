local skynet_root = "./3rd/skynet/"
local common = "./common/"
package.cpath = skynet_root.."luaclib/?.so;"
package.path = skynet_root.."lualib/?.lua;"..common.."?.lua"

local socket = require "clientsocket"
local crypt = require "crypt"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
require "luaext"
--加载解析proto文件
local f = io.open("./common/proto/clientproto.lua")
if f == nil then
	print("proto open faild")
	return
end
local t = f:read "a"
f:close()
sprotoloader.save(sprotoparser.parse(t),0)
f = io.open("./common/proto/serverproto.lua")
if f == nil then
	print("proto open faild")
	return
end
t = f:read "a"
f:close()
sprotoloader.save(sprotoparser.parse(t),1)

--[[
--proto消息解析测试
local hostclient = sprotoloader.load(1):host "package"
local requestclient = hostclient:attach(sprotoloader.load(0))

local hostserver = sprotoloader.load(0):host "package"
local requestserver = hostserver:attach(sprotoloader.load(1))

--client发送
local str = requestclient("ping",{userid = 123456},99)
--server解析
local type, session, args,response = hostserver:dispatch(str)
print(type, session, args,response)
--server返回response
local str2 = response({ok = true})
--client解析
local type, session, args,response = hostclient:dispatch(str2)
print(type, session, args,response)

--server发送
local str3 = requestserver("heartbeat")
--client解析
local type, session, args,response = hostclient:dispatch(str3)
print(type, session, args,response)

]]

--host用来解析接受到的消息
local host = sprotoloader.load(1):host "package"
--request用来发送消息
local request = host:attach(sprotoloader.load(0))

local session = {}
local session_id = 0

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

--与loginserver建立连接
local fd = assert(socket.connect("127.0.0.1", 8101))

--发送proto协议封装的消息
local function send_request(name, args)
	session_id = session_id + 1
	local str = request(name, args, session_id)
	local size = #str + 4
	local package = string.pack(">I2", size)..str..string.pack(">I4", session_id)
	socket.send(fd, package)
	session[session_id] = {name = name ,args = args}
	--print( session_id,"REQUEST",name)
end

--1.给login服务器发送clientkey
local clientkey = crypt.randomkey()
send_request("handshake",{clientkey = crypt.base64encode(crypt.dhexchange(clientkey))})

local RESPONSE = {}
local challenge
local serverkey
local secret
function RESPONSE:handshake(args)
	challenge = crypt.base64decode(args.challenge)
	serverkey = crypt.base64decode(args.serverkey)

	--根据获取的serverkey 和 clientkey计算出secret
	secret = crypt.dhsecret(serverkey, clientkey)
	print("sceret is ", crypt.hexencode(secret))

	--回应服务器第一步握手的挑战码，确认握手正常。
	hmac = crypt.hmac64(challenge, secret)
	send_request("challenge",{hmac = crypt.base64encode(hmac)})
end

local token = {
	server = "sample",
	user = "hello",
	pass = "password",
}

local function encode_token(token)
	return string.format("%s@%s:%s",
		crypt.base64encode(token.user),
		crypt.base64encode(token.server),
		crypt.base64encode(token.pass))
end

function RESPONSE:challenge(args)
	print(args.result)

	--使用DES算法，以secret做key，加密传输token串
	local etoken = crypt.desencode(secret, encode_token(token))
	send_request("auth",{etokens = crypt.base64encode(etoken)})
end

local subid

local index = 1

local function login()
	--连接到gameserver
	print("connect index:"..index)
	fd = assert(socket.connect("127.0.0.1", 8547))
	local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
	local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)
	send_request("login",{handshake = handshake .. ":" .. crypt.base64encode(hmac)})
end

function RESPONSE:login(args)
	print("send ping")
	send_request("ping",{userid = "hahaha"})
end

local function getcharacterlist()
	print("send getcharacterlist")
	send_request("getcharacterlist")
end

local function charactercreate()
	print("send charactercreate")
	local character_create = {
		name = "dingdalong",
		job = 1,
		sex = 1,
	}
	print(character_create)
	send_request("charactercreate",character_create)
end

local function characterpick(uuid)
	print("send characterpick")
	send_request("characterpick",{uuid = uuid})
end

function RESPONSE:ping( args )
	print("ping:"..tostring(args.ok))

	index = index + 1
	if index > 3 then
		getcharacterlist()
		return
	end
	--断开连接
	print("disconnect")
	socket.close(fd)

	--再次连接到gameserver
	login()
end

function RESPONSE:getcharacterlist(args)
	print("getcharacterlist:")
	if(table.size(args.character) < 3) then
		charactercreate()
	else
		local uuid = 0
		for k,_ in pairs(args.character)do
			uuid = k
			break
		end
		characterpick(uuid)
	end
end


function RESPONSE:charactercreate(args)
	print("charactercreate:")
	print(args)
end

function RESPONSE:characterpick(args)
	print("characterpick:")
	print(args.ok)
	--getcharacterlist()
end

local REQUEST = {}

function REQUEST.subid(args)
	print("subid")
	--收到服务器发来的确认信息
	local result = args.result
	local code = tonumber(string.sub(result, 1, 3))
	--当确认成功的时候，断开与服务器的连接
	assert(code == 200)
	socket.close(fd)

	--通过确认信息获取subid
	subid = crypt.base64decode(string.sub(result, 5))

	print("login ok, subid=", subid)

	login()
end

----- connect to game server
--连接至gameserver

--接受并解析proto协议封装的消息
local last = ""

local function unpack_f(f)
	local function try_recv(fd, last)
		local result
		result, last = f(last)
		if result then
			return result, last
		end
		local r = socket.recv(fd)
		if not r then
			return nil, last
		end
		if r == "" then
			error "Server closed"
		end
		return f(last .. r)
	end

	--每秒尝试接受来自服务器的消息
	return function()
		while true do
			local result
			result, last = try_recv(fd, last)
			if result then
				return result
			end
			socket.usleep(100)
		end
	end
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end
	return text:sub(3,2+s - 4), text:sub(3+s)
end

local readpackage = unpack_f(unpack_package)

local function dispatch_message()
	local type, id, args, response = host:dispatch(readpackage())
	--print("<===",type, id, args, response)
	if type == "RESPONSE" then
		local s = assert(session[id])
		session[id] = nil
		local f = RESPONSE[s.name]
		if f then
			f (s.args, args)
		else
			print "response"
		end
	elseif type == "REQUEST" then
		local f = REQUEST[id]
		if f then
			f(args)
		else
			print "response"
		end
	end
end

while true do
	dispatch_message()
end

print("disconnect")
socket.close(fd)
