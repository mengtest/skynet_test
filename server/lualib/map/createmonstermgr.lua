--所在地图的刷怪信息
local _createmonstermgr = {}

local s_method = {
    __index = {}
}

local function init_method(mgr)
    -- 获取怪物列表
    function mgr:getmonsterlist()
        return self.monsterlist
    end

    function mgr:createmonster()
        local n = 5
        while n > 0 do
            for _, v in pairs(self.monsterlist) do
                self.basemap.monstermgr:createmonster(v.id, v.x, v.y, v.z)
            end
            n = n - 1
        end
    end
end

init_method(s_method.__index)

function _createmonstermgr.create(basemap, monsterlist)
    local createmonstermgr = {
        basemap = basemap,
        monsterlist = monsterlist
    }

    setmetatable(createmonstermgr, s_method)

    return createmonstermgr
end

return _createmonstermgr
