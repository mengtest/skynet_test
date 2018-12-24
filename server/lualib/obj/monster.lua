local skynet = require "skynet"
local basechar = require "obj.basechar"
local enumtype = require "enumtype"
local random = math.random
local _monster = {}
local s_method = {
    __index = {}
}

local function init_method(monster)
    -- 获取npcid
    function monster:getid()
        return self.id
    end

    function monster:run(basemap)
        if skynet.time() >= self.nextruntime then
            self.nextruntime = skynet.time() + random(100) * 0.01
            local pos = self:getpos()
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
            self:setpos(pos)
            basemap.CMD.characterenter(self:getaoiobj())
        end
    end

    basechar.expandmethod(monster)
end
init_method(s_method.__index)

-- 创建monster
function _monster.create(id, x, y, z)
    local monster = basechar.create(enumtype.CHAR_TYPE_MONSTER)
    monster = setmetatable(monster, s_method)

    -- monster特有属性
    monster.nextruntime = 0
    -- 设置怪物的id
    monster.id = id

    -- 设置怪物的aoi对象
    local aoiobj = {
        movement = {
            mode = "m",
            pos = {
                x = x,
                y = y,
                z = z
            }
        }
    }
    monster:setaoiobj(aoiobj)
    return monster
end

return _monster
