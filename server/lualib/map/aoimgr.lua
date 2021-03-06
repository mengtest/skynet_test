local skynet = require "skynet"
local basemap = require "map.basemap"
local idmgr = require "idmgr"
local log = require "syslog"
local enumtype = require "enumtype"
local table = table

local CMD = basemap.cmd()
local aoimgr = {}

local aoi
local need_update
local OBJ = {}
local playerview = {}
local monsterview = {}

local AOI_RADIS = 200
local AOI_RADIS2 = AOI_RADIS * AOI_RADIS
local LEAVE_AOI_RADIS2 = AOI_RADIS2 * 4

local function DIST2(p1, p2)
    return ((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y) + (p1.z - p2.z) * (p1.z - p2.z))
end

-- 根据对象类型插入table
local function inserttotablebytype(t, v, type)
    if type ~= enumtype.CHAR_TYPE_PLAYER then
        table.insert(t.monsterlist, v)
    else
        table.insert(t.playerlist, v)
    end
end

-- 观看者坐标更新的时候
-- 根据距离情况通知他人自己的信息
local function updateviewplayer(viewertempid)
    if playerview[viewertempid] == nil then
        return
    end
    local myobj = OBJ[viewertempid]
    local mypos = myobj.movement.pos

    -- 离开他人视野
    local leavelist = {
        playerlist = {},
        monsterlist = {}
    }
    -- 进入他人视野
    local enterlist = {
        playerlist = {},
        monsterlist = {}
    }
    -- 通知他人自己移动
    local movelist = {
        playerlist = {},
        monsterlist = {}
    }

    local othertempid
    local otherpos
    local othertype
    local otherobj
    -- 遍历视野中的对象
    for k, v in pairs(playerview[viewertempid]) do
        othertempid = OBJ[k].tempid
        otherpos = OBJ[k].movement.pos
        othertype = OBJ[k].type
        otherobj = {
            tempid = othertempid,
            agent = OBJ[k].agent
        }
        -- 计算对象之间的距离
        local distance = DIST2(mypos, otherpos)
        if distance <= AOI_RADIS2 then
            -- 在视野范围内的时候
            if not v then
                -- 之前不在视野内，加入进入视野列表
                playerview[viewertempid][k] = true
                if othertype ~= enumtype.CHAR_TYPE_PLAYER then
                    monsterview[k][viewertempid] = true
                    table.insert(enterlist.monsterlist, OBJ[k])
                else
                    playerview[k][viewertempid] = true
                    table.insert(enterlist.playerlist, OBJ[k])
                end
            else
                -- 在视野内，更新坐标
                inserttotablebytype(movelist, otherobj, othertype)
            end
        elseif distance > AOI_RADIS2 and distance <= LEAVE_AOI_RADIS2 then
            -- 视野范围外，但是还在aoi控制内
            if v then
                -- 之前在视野内的话，加入离开视野列表
                playerview[viewertempid][k] = false
                if othertype ~= enumtype.CHAR_TYPE_PLAYER then
                    monsterview[k][viewertempid] = false
                    table.insert(leavelist.monsterlist, otherobj)
                else
                    playerview[k][viewertempid] = false
                    table.insert(leavelist.playerlist, otherobj)
                end
            end
        else
            -- aoi控制外
            if v then
                -- 之前在视野内的话，加入离开视野列表
                inserttotablebytype(leavelist, otherobj, othertype)
            end
            playerview[viewertempid][k] = nil
            -- 从对方视野中移除自己
            if othertype ~= enumtype.CHAR_TYPE_PLAYER then
                monsterview[k][viewertempid] = nil
            else
                playerview[k][viewertempid] = nil
            end
        end
    end

    -- 离开他人视野
    for _, v in pairs(leavelist.playerlist) do
        skynet.send(v.agent, "lua", "delaoiobj", viewertempid)
    end

    -- 重新进入视野
    for _, v in pairs(enterlist.playerlist) do
        skynet.send(v.agent, "lua", "addaoiobj", myobj)
    end

    -- 视野范围内移动
    for _, v in pairs(movelist.playerlist) do
        skynet.send(v.agent, "lua", "updateaoiobj", myobj)
    end

    -- 怪物的更新合并一起发送
    if
        not table.empty(leavelist.monsterlist) or not table.empty(enterlist.monsterlist) or
            not table.empty(movelist.monsterlist)
     then
        local monsterenterlist = {
            obj = myobj,
            monsterlist = enterlist.monsterlist
        }
        local monsterleavelist = {
            tempid = viewertempid,
            monsterlist = leavelist.monsterlist
        }
        local monstermovelist = {
            obj = myobj,
            monsterlist = movelist.monsterlist
        }
        CMD.updatemonsteraoiinfo(monsterenterlist, monsterleavelist, monstermovelist)
    end

    -- 通知自己
    skynet.send(myobj.agent, "lua", "updateaoilist", enterlist, leavelist)
end

-- 怪物移动的时候通知玩家信息
-- 怪物视野内只有玩家
local function updateviewmonster(monstertempid)
    if monsterview[monstertempid] == nil then
        return
    end
    local myobj = OBJ[monstertempid]
    local mypos = myobj.movement.pos
    -- 离开他人视野
    local leavelist = {}
    -- 进入他人视野
    local enterlist = {}
    -- 通知他人自己移动
    local movelist = {}

    local othertempid
    local otherpos
    local otheragent
    local otherobj
    for k, v in pairs(monsterview[monstertempid]) do
        othertempid = OBJ[k].tempid
        otherpos = OBJ[k].movement.pos
        otheragent = OBJ[k].agent
        otherobj = {
            tempid = othertempid,
            agent = OBJ[k].agent
        }
        local distance = DIST2(mypos, otherpos)
        if distance <= AOI_RADIS2 then
            if not v then
                monsterview[monstertempid][k] = true
                playerview[k][monstertempid] = true
                table.insert(enterlist, OBJ[k])
            else
                table.insert(movelist, otheragent)
            end
        elseif distance > AOI_RADIS2 and distance <= LEAVE_AOI_RADIS2 then
            if v then
                monsterview[monstertempid][k] = false
                playerview[k][monstertempid] = false
                table.insert(leavelist, otherobj)
            end
        else
            if v then
                table.insert(leavelist, otherobj)
            end
            monsterview[monstertempid][k] = nil
            playerview[k][monstertempid] = nil
        end
    end

    -- 离开他人视野
    for _, v in pairs(leavelist) do
        skynet.send(v.agent, "lua", "delaoiobj", myobj.tempid)
    end

    -- 重新进入视野
    for _, v in pairs(enterlist) do
        skynet.send(v.agent, "lua", "addaoiobj", myobj)
    end

    -- 视野范围内移动
    for _, v in pairs(movelist) do
        skynet.send(v, "lua", "updateaoiobj", myobj)
    end

    skynet.send(myobj.agent, "lua", "updateaoilist", myobj.tempid, enterlist, leavelist)
end

-- aoi回调
function CMD.aoicallback(w, m)
    assert(OBJ[w], w)
    assert(OBJ[m], m)

    if playerview[OBJ[w].tempid] == nil then
        playerview[OBJ[w].tempid] = {}
    end
    playerview[OBJ[w].tempid][OBJ[m].tempid] = true

    -- 怪物视野内的玩家
    if OBJ[m].type ~= enumtype.CHAR_TYPE_PLAYER then
        if monsterview[OBJ[m].tempid] == nil then
            monsterview[OBJ[m].tempid] = {}
        end
        monsterview[OBJ[m].tempid][OBJ[w].tempid] = true
    end

    -- 通知agent
    skynet.send(OBJ[w].agent, "lua", "addaoiobj", OBJ[m])

    -- 被看到的是怪物时，添加player到怪物视野中
    if OBJ[m].type ~= enumtype.CHAR_TYPE_PLAYER then
        skynet.send(OBJ[m].agent, "lua", "addaoiobj", OBJ[m].tempid, OBJ[w])
    end
end

-- 添加到aoi
function CMD.characterenter(obj)
    assert(obj)
    assert(obj.agent)
    assert(obj.movement)
    assert(obj.movement.mode)
    assert(obj.movement.pos.x)
    assert(obj.movement.pos.y)
    assert(obj.movement.pos.z)
    -- log.debug("AOI ENTER %d %s %d %d %d",obj.tempid,obj.movement.mode,obj.movement.pos.x,obj.movement.pos.y,obj.movement.pos.z)
    OBJ[obj.tempid] = obj
    if obj.type ~= enumtype.CHAR_TYPE_PLAYER then
        updateviewmonster(obj.tempid)
    else
        updateviewplayer(obj.tempid)
    end
    assert(
        pcall(
            skynet.send,
            aoi,
            "text",
            "update " ..
                obj.tempid ..
                    " " ..
                        obj.movement.mode ..
                            " " .. obj.movement.pos.x .. " " .. obj.movement.pos.y .. " " .. obj.movement.pos.z
        )
    )
    need_update = true
end

-- 从aoi中移除
function CMD.characterleave(obj)
    assert(obj)
    log.debug("%d leave aoi", obj.tempid)
    assert(
        pcall(
            skynet.send,
            aoi,
            "text",
            "update " ..
                obj.tempid .. " d " .. obj.movement.pos.x .. " " .. obj.movement.pos.y .. " " .. obj.movement.pos.z
        )
    )
    OBJ[obj.tempid] = nil
    if playerview[obj.tempid] then
        -- 玩家离开地图
        local monsterleavelist = {
            tempid = obj.tempid,
            monsterlist = {}
        }
        for k, _ in pairs(playerview[obj.tempid]) do
            if playerview[k] then
                -- 视野内的玩家，一个一个的发送
                if playerview[k][obj.tempid] then
                    -- 视野内需要通知
                    skynet.send(OBJ[k].agent, "lua", "delaoiobj", obj.tempid)
                end
                playerview[k][obj.tempid] = nil
            elseif monsterview[k] then
                -- 视野内的怪物，先插入到table中，后面一起发送
                if monsterview[k][obj.tempid] then
                    -- 视野内需要通知
                    table.insert(
                        monsterleavelist.monsterlist,
                        {
                            tempid = k
                        }
                    )
                end
                monsterview[k][obj.tempid] = nil
            end
        end
        -- 通知视野内的怪物移除自己
        if not table.empty(monsterleavelist.monsterlist) then
            CMD.updatemonsteraoiinfo(
                {
                    monsterlist = {}
                },
                monsterleavelist,
                {
                    monsterlist = {}
                }
            )
        end
        playerview[obj.tempid] = nil
    elseif monsterview[obj.tempid] then
        -- 怪物离开地图
        local monsterleavelist = {
            tempid = obj.tempid,
            monsterlist = {}
        }
        for k, _ in pairs(monsterview[obj.tempid]) do
            if playerview[k] then
                -- 视野内的玩家
                if playerview[k][obj.tempid] then
                    -- 视野内需要通知
                    skynet.send(OBJ[k].agent, "lua", "delaoiobj", obj.tempid)
                end
                playerview[k][obj.tempid] = nil
            end
        end
        monsterview[obj.tempid] = nil
    end
    idmgr.releaseid(obj.tempid)
    need_update = true
end

function aoimgr.update()
    if need_update then
        need_update = false
        assert(pcall(skynet.send, aoi, "text", "message "))
    end
end

function aoimgr.init(_aoi)
    aoi = _aoi
end

return aoimgr
