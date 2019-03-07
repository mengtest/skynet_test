local handler = require "agent.handler"
local socket = require "skynet.socket"
local skynet = require "skynet"
local crypt = require "skynet.crypt"
local log = require "base.syslog"
local random = math.random

local REQUEST = {}
local RESPONSE = {}

local _handler = handler.new(REQUEST, RESPONSE, nil)

_handler:init(
    function(o)
    end
)

_handler:release(
    function()
    end
)

function RESPONSE:handshake(args)
    self.challenge = crypt.base64decode(args.challenge)
    self.serverkey = crypt.base64decode(args.serverkey)

    -- 根据获取的serverkey 和 clientkey计算出secret
    self.secret = crypt.dhsecret(self.serverkey, self.clientkey)
    log.err("sceret is "..crypt.hexencode(self.secret))
    -- 回应服务器第一步握手的挑战码，确认握手正常。
    self.hmac = crypt.hmac64(self.challenge, self.secret)
    self:send_request(
        "challenge",
        {
            hmac = crypt.base64encode(self.hmac)
        }
    )
end

local function encode_token(token)
    return string.format(
        "%s@%s:%s",
        crypt.base64encode(token.user),
        crypt.base64encode(token.server),
        crypt.base64encode(token.pass)
    )
end

function RESPONSE:challenge(args)
    log.err(args.result)

    -- 使用DES算法，以secret做key，加密传输token串
    local etoken = crypt.desencode(self.secret, encode_token(self.token))
    self:send_request(
        "auth",
        {
            etokens = crypt.base64encode(etoken)
        }
    )
end

local function login(self)
    -- 连接到gameserver
    self.fd = assert(socket.open(self.gateip, self.gateport))
    --if true then return end
    local handshake =
        string.format(
        "%s@%s#%s:%d",
        crypt.base64encode(self.token.user),
        crypt.base64encode(self.token.server),
        crypt.base64encode(self.subid),
        self.index
    )
    local hmac = crypt.hmac64(crypt.hashkey(handshake), self.secret)
    self:send_request(
        "login",
        {
            handshake = handshake .. ":" .. crypt.base64encode(hmac)
        }
    )
end

function RESPONSE:login(args)
    log.err("send ping")
    self:send_request(
        "ping",
        {
            userid = "hahaha"
        }
    )
end

local function getcharacterlist(self)
    log.err("send getcharacterlist")
    self:send_request("getcharacterlist")
end

local function charactercreate(self)
    log.err("send charactercreate")
    local character_create = {
        name = self.name,
        job = 1,
        sex = 1
    }
    self:send_request("charactercreate", character_create)
end

local function characterpick(self, uuid)
    log.err("send characterpick :" .. uuid)
    self:send_request(
        "characterpick",
        {
            uuid = uuid
        }
    )
end

local function mapready(self)
    log.err("send mapready")
    self:send_request("mapready")
end

local function moveto(self, pos)
    --log.err("send moveto")
    self:send_request(
        "moveto",
        {
            pos = pos
        }
    )
end

local function changemap(self)
    log.err("send changemap")
    self:send_request(
        "changemap",
        {
            mapid = self.mapid
        }
    )
end

local function quitgame(self)
    self:send_request("quitgame")
end

function RESPONSE:ping(args)
    log.err("ping:" .. tostring(args.ok))

    self.index = self.index + 1
    if self.index > 0 then
        getcharacterlist(self)
        return
    end
    -- 断开连接
    log.err("disconnect")
    socket.close(self.fd)

    -- 再次连接到gameserver
    login(self)
end

function RESPONSE:getcharacterlist(args)
    log.err("getcharacterlist size:" .. table.size(args.character))
    if (table.size(args.character) < 1) then
        charactercreate(self)
    else
        local uuid = 0
        local bpick = false
        for k, v in pairs(args.character) do
            if v.name == self.name then
                uuid = k
                characterpick(self, uuid)
                bpick = true
                break
            end
        end
        if not bpick then
            for k, v in pairs(args.character) do
                log.err(self.name.." "..v.name)
            end
            
            --charactercreate(self)
        end
    end
end

function RESPONSE:charactercreate(args)
    log.err("charactercreate:")
    getcharacterlist(self)
end

function RESPONSE:characterpick(args)
    log.debug("characterpick ret:" .. args.tempid)
    mapready(self)
end

function RESPONSE:mapready(args)
    log.err("mapready:")
    local pos = {
        x = 1,
        y = 2,
        z = 3
    }
    moveto(self, pos)
end

local bchangemap = false
function RESPONSE:moveto(args)
    --log.err("moveto:")
    if not bchangemap then
        changemap(self)
    else
        local pos = args.pos
        local n = random(10000)
        local datlex
        if n > 5000 then
            datlex = 10
        else
            datlex = -10
        end
        local y = random(10000)
        local datley
        if y > 5000 then
            datley = 10
        else
            datley = -10
        end
        pos.x = pos.x + datlex
        if pos.x > 300 then
            pos.x = 300
        elseif pos.x < -300 then
            pos.x = -300
        end
        pos.z = pos.z + datley
        if pos.z > 300 then
            pos.z = 300
        elseif pos.z < -300 then
            pos.z = -300
        end
        moveto(self, pos)
        skynet.sleep(10)
    end
    -- quitgame(self)
end

function RESPONSE:changemap(args)
    log.err("changemap:")
    bchangemap = true
    if args.ok then
        log.debug("changemap:" .. args.tempid)
        mapready(self)
    else
        local pos = {
            x = 1,
            y = 2,
            z = 3
        }
        moveto(self, pos)
    end
end

function RESPONSE:quitgame(args)
    log.err("quitgame:")
    log.err(args.ok)
end

function REQUEST:subid(args)
    -- 收到服务器发来的确认信息
    local result = args.result
    local code = tonumber(string.sub(result, 1, 3))
    log.err("login subid result " .. result)
    -- 当确认成功的时候，断开与服务器的连接
    assert(code == 200)
    socket.close(self.fd)

    -- 通过确认信息获取subid
    self.subid = crypt.base64decode(string.sub(result, 5))

    --log.err("login ok, subid=" .. self.subid)
    self.gateip = args.gateip
    self.gateport = args.gateport
    login(self)
end

function REQUEST:heartbeat()
    log.err("===heartbeat===")
end

function REQUEST:characterupdate(args)
    -- log.err("characterupdate:")
end

function REQUEST:characterleave(args)
    -- log.err("characterleave:")
end

function REQUEST:delaytest(args)
    log.err("delaytest")
    -- log.err(args)
    return {
        time = args.time
    }
end

function REQUEST:delayresult(args)
    log.err("delayresult:" .. args.time)
end

function REQUEST:moveto(args)
    local move = args.move
    -- for _,v in pairs(move) do
    --	log.err(v)
    -- end
end

return _handler
