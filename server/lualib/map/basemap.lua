local idmgr = require "idmgr"
local _map = {}

local s_method = {
    __index = {}
}

local function init_method(map)
    -- 创建一个临时id
    function map:createtempid()
        return idmgr:createid()
    end

    -- 释放一个临时id
    function map:releasetempid(tempid)
        assert(tempid)
        idmgr:releaseid(tempid)
    end

    -- 加载地图信息
    function map:loadmapinfo()
    end

    -- 获取地图id
    function map:getmapid()
        return self.id
    end

    -- 获取副本id
    function map:getdungonid()
        return self.dungeon_id
    end

    -- 获取副本实例id
    function map:getdungoninstanceid()
        return self.dungeon_instance_id
    end

    -- 获取地图的宽
    function map:getwidth()
        return self.width
    end

    -- 获取地图的高
    function map:getheight()
        return self.height
    end
end

init_method(s_method.__index)

function _map.create(id, type, map_info)
    local map = {
        -- 地图id
        id = 0,
        -- 副本id
        dungeon_id = 0,
        -- 副本实例id
        dungeon_instance_id = 0,
        -- 地图类型
        type = 0,
        -- 地图宽、高
        width = 0,
        height = 0,
        -- 地图信息
        map_info = {},
        -- 玩家列表
        player_list = {},
        -- npc列表
        npc_list = {}
    }

    map = setmetatable(map, s_method)
    map.id = id
    map.type = type
    assert(map_info)
    map.map_info = map_info
    idmgr:setmaxid(map_info.maxtempid)
    return map
end

return _map
