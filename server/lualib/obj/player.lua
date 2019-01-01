local basechar = require "obj.basechar"
local enumtype = require "enumtype"
local msgsender = require "msgsender"

local _player = {}
local s_method = {
    __index = {}
}

local function init_method(player)
    -- 给自己客户端发消息
    function player:sendrequest(name, args)
        msgsender.sendrequest(name, args, self.aoiobj.info)
    end

    -- 设置地图地址
    function player:setmapaddress(address)
        self.mapaddress = address
    end

    -- 获取地图地址
    function player:getmapaddress()
        return self.mapaddress
    end

    -- 设置玩家所在地图id
    function player:setmapid(mapid)
        self.mapid = mapid
    end

    -- 获取玩家当前所在地图id
    function player:getmapid()
        return self.mapid
    end

    -- 设置玩家uuid
    function player:setuuid(uuid)
        assert(self.playerinfo)
        assert(uuid > 0)
        self.playerinfo.uuid = uuid
    end

    -- 获取玩家uuid
    function player:getuuid()
        assert(self.playerinfo)
        return self.playerinfo.uuid
    end

    -- 获取角色职业
    function player:getjob()
        assert(self.playerinfo)
        return self.playerinfo.job
    end

    -- 获取角色性别
    function player:getsex()
        assert(self.playerinfo)
        return self.playerinfo.sex
    end

    -- 设置角色名称
    function player:setname(name)
        assert(self.playerinfo)
        assert(#name > 0)
        self.playerinfo.name = name
    end

    -- 获取角色名称
    function player:getname()
        assert(self.playerinfo)
        return self.playerinfo.name
    end

    -- 设置角色等级
    function player:setlevel(level)
        assert(self.playerinfo)
        assert(level > 0)
        self.playerinfo.level = level
    end

    -- 获取角色等级
    function player:getlevel()
        assert(self.playerinfo)
        return self.playerinfo.level
    end

    -- 获取账号
    function player:getuid()
        assert(self.playerinfo)
        return self.playerinfo.uid
    end

    -- 获取创建时间
    function player:getcreatetime()
        assert(self.playerinfo)
        return self.playerinfo.createtime
    end
    
    -- 获取登陆时间
    function player:getlogintime()
        assert(self.playerinfo)
        return self.playerinfo.logintime
    end

    -- 设置角色信息
    function player:setobjinfo(info)
        assert(info)
        self.playerinfo = info
    end

    -- 获取角色信息
    function player:getobjinfo()
        return self.playerinfo
    end

    -- 设置玩家数据
    function player:setdata(data)
        self.data = data
    end

    function player:getdata()
        assert(self.data)
        return self.data
    end

    -- 获取玩家指定类型的数据
    function player:getdatabytype(ntype)
        assert(self.data)
        return self.data[ntype]
    end

    basechar.expandmethod(player)
end
init_method(s_method.__index)

-- 创建player
function _player.create()
    local player = basechar.create(enumtype.CHAR_TYPE_PLAYER)
    -- player 特有属性

    -- 所在地图地址
    player.mapaddress = nil
    -- 所在地图
    player.mapid = 0
    -- 玩家数据
    player.data = {}
    -- 玩家信息
    player.playerinfo = {}

    player = setmetatable(player, s_method)

    return player
end

return _player
