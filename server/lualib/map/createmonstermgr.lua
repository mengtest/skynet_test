local monstermgr = require "map.monstermgr"
local sharedata = require "skynet.sharedata"

local createmonstermgr = {}
local n = 5

local monsterlist

-- 获取怪物列表
function createmonstermgr.getmonsterlist()
    return monsterlist
end

function createmonstermgr.createmonster()
    while n > 0 do
        for _, v in pairs(monsterlist) do
            monstermgr.createmonster(v.id, v.x, v.y, v.z)
        end
        n = n - 1
    end
end

function createmonstermgr.init(mapname)
    local obj = sharedata.query "gdd"
    monsterlist = obj["createmonster"][mapname]
    if mapname == "main" then
        n = 10
    end
end

return createmonstermgr
