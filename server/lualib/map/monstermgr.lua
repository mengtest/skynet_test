local monsterobj = require "obj.monster"
local basemap = require "map.basemap"
local idmgr = require "idmgr"
local enumtype = require "enumtype"
local msgsender = require "msgsender"

local CMD = basemap.cmd()
local monstermgr = {CMD = CMD}

local monsterlist = {}

-- 添加对象到怪物的aoilist中
-- aoi callback
function CMD.addaoiobj(monstertempid, aoiobj)
    assert(monstertempid)
    assert(aoiobj)
    local monster = monstermgr.getmonster(monstertempid)
    if monster:getfromaoilist(aoiobj.tempid) == nil then
        monster:addtoaoilist(aoiobj)
        if aoiobj.type == enumtype.CHAR_TYPE_PLAYER then
            local info = {
                name = monster:getname(),
                tempid = monster:gettempid(),
                pos = monster:getpos()
            }
            -- 将我的信息发送给对方
            msgsender.sendrequest(
                "characterupdate",
                {
                    info = info
                },
                aoiobj.info
            )
        end
    end
end

-- 玩家移动的时候，对周围怪物的广播
function CMD.updatemonsteraoiinfo(enterlist, leavelist, movelist)
    local monster
    -- 进入怪物视野
    for _, v in pairs(enterlist.monsterlist) do
        monster = monstermgr.getmonster(v.tempid)
        if monster:getfromaoilist(enterlist.obj.tempid) == nil then
            monster:addtoaoilist(enterlist.obj)
            local info = {
                name = monster:getname(),
                tempid = monster:gettempid(),
                pos = monster:getpos()
            }
            -- 将我的信息发送给对方
            msgsender.sendrequest(
                "characterupdate",
                {
                    info = info
                },
                enterlist.obj.info
            )
        end
    end
    -- 离开怪物视野
    for _, v in pairs(leavelist.monsterlist) do
        monster = monstermgr.getmonster(v.tempid)
        monster:delfromaoilist(leavelist.tempid)
    end
    -- 更新怪物视野
    for _, v in pairs(movelist.monsterlist) do
        monster = monstermgr.getmonster(v.tempid)
        monster:updateaoiobj(movelist.obj)
    end
end

-- 怪物自己移动的时候，aoi更新
function CMD.updateaoilist(monstertempid, enterlist, leavelist)
    assert(monstertempid)
    assert(enterlist)
    assert(leavelist)
    local monster = monstermgr.getmonster(monstertempid)
    for _, v in pairs(enterlist) do
        monster:addtoaoilist(v)
        local info = {
            name = monster:getname(),
            tempid = monster:gettempid(),
            pos = monster:getpos()
        }
        -- 将我的信息发送给对方
        msgsender.sendrequest(
            "characterupdate",
            {
                info = info
            },
            v.info
        )
    end
    for _, v in pairs(leavelist) do
        monster:delfromaoilist(v.tempid)
    end
end

-- 怪物run
function monstermgr.monsterrun()
    for _, v in pairs(monsterlist) do
        v:run(basemap)
    end
end

-- 获取一个怪物
function monstermgr.getmonster(tempid)
    assert(monsterlist[tempid], tempid)
    return monsterlist[tempid]
end

-- 创建一个怪物
function monstermgr.createmonster(monsterid, x, y, z)
    local tempid = idmgr.createid()
    local obj = monsterobj.create(monsterid, x, y, z)
    obj:settempid(tempid)
    assert(monsterlist[tempid] == nil)
    monsterlist[tempid] = obj
    CMD.characterenter(obj:getaoiobj())
end

return monstermgr
