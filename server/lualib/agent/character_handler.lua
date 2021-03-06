local skynet = require "skynet"
local cluster = require "skynet.cluster"
local handler = require "agent.handler"
local log = require "base.syslog"
local uuid = require "uuid"
local datasheet = require "skynet.datasheet"
local packer = require "db.packer"
local player = require "obj.player"

local map_handler = require "agent.map_handler"
local aoi_handler = require "agent.aoi_handler"
local move_handler = require "agent.move_handler"

local user
local dbmgr
local mapmgr

local REQUEST = {}

local _handler = handler.new(REQUEST)

_handler:init(
    function(u)
        user = u
        dbmgr = skynet.uniqueservice("dbmgr")
        mapmgr = skynet.uniqueservice("mapmgr")
    end
)

_handler:release(
    function()
        user = nil
        dbmgr = nil
        mapmgr = nil
    end
)

local function loadlist()
    local list = skynet.call(dbmgr, "lua", "playerdate", "getlist", user.uid)
    if not list then
        list = {}
    end
    return list
end

-- 获取角色列表
function REQUEST.getcharacterlist()
    local character = loadlist()
    user.characterlist = {}
    for k, _ in pairs(character) do
        user.characterlist[k] = true
    end
    return {
        character = character
    }
end

local function create(name, job, sex)
    local character = {
        uid = user.uid,
        name = name,
        job = job,
        sex = sex,
        uuid = uuid.gen(),
        level = 1,
        createtime = os.time(),
        logintime = os.time(),
        mapid = 1,
        x = 0,
        y = 0,
        z = 0,
        data = packer.pack({})
    }

    return character
end

-- 创建角色
function REQUEST.charactercreate(args)
    if table.size(loadlist()) >= 3 then
        log.debug("%s create character failed, character num >= 3!", user.uid)
        return {
            character = nil
        }
    end
    -- TODO 检查名称的合法性
    local namecheck = cluster.proxy "login@namecheck"
    local result = skynet.call(namecheck, "lua", "playernamecheck", args.name)
    if not result then
        log.debug("%s create character failed, name repeat!", user.uid)
        return {
            character = nil
        }
    end
    local obj = datasheet.query "gamedata"
    local jobdata = obj["job"]
    if jobdata[args.job] == nil then
        log.debug("%s create character failed, job error!", user.uid)
        return {
            character = nil
        }
    end
    local character = create(args.name, args.job, args.sex)
    if skynet.call(dbmgr, "lua", "playerdate", "create", character) then
        user.characterlist[character.uuid] = true
        log.debug("%s create character succ!", user.uid)
    else
        log.debug("%s create character failed, save date failed!", user.uid)
    end
    return {
        character = character
    }
end

-- 初始化角色信息
local function initUserData(dbdata)
    user.character = player.create()
    user.character:setmapid(dbdata.mapid)
    -- aoi对象，主要用于广播相关
    local aoiobj = {
        movement = {
            mode = "w",
            pos = {
                x = dbdata.x,
                y = dbdata.y,
                z = dbdata.z
            },
            map = dbdata.mapid
        },
        info = {
            fd = user.fd
        }
    }
    user.character:setaoiobj(aoiobj)
    -- 角色信息
    local playerinfo = {
        name = dbdata.name,
        job = dbdata.job,
        sex = dbdata.sex,
        level = dbdata.level,
        uuid = dbdata.uuid,
        uid = dbdata.uid,
        createtime = dbdata.createtime,
        logintime = dbdata.logintime
    }
    user.character:setobjinfo(playerinfo)
    user.character:setdata(dbdata.data)
end

-- 选择角色
function REQUEST.characterpick(args)
    if user.characterlist[args.uuid] == nil then
        log.debug("%s pick character failed!", user.uid)
        return
    end
    local ret = false
    local list = skynet.call(dbmgr, "lua", "playerdate", "load", user.uid, args.uuid)
    if list.uuid then
        log.debug("%s pick character[%s] succ!", user.uid, list.name)
        user.characterlist = nil
        initUserData(list)
        local mapaddress = skynet.call(mapmgr, "lua", "getmapaddressbyid", user.character:getmapid())
        local tempid
        if mapaddress ~= nil then
            tempid = skynet.call(mapaddress, "lua", "gettempid")
            if tempid > 0 then
                user.character:setaoimode("w")
                user.character:setmapaddress(mapaddress)
                user.character:settempid(tempid)
                map_handler:register(user)
                aoi_handler:register(user)
                move_handler:register(user)
                log.debug("enter map and set tempid:" .. user.character:gettempid())
                _handler:unregister(user)
            else
                log.debug("player enter map failed:" .. user.character:getmapid())
            end
        else
            log.debug("player get map address failed:" .. user.character:getmapid())
        end
        return {
            ok = ret,
            tempid = tempid
        }
    else
        return {
            ok = ret
        }
    end
end

return _handler
