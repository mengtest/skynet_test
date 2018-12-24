local CMD = {}
local basemap = {CMD = CMD}

local mapid
local maptype
local dungeonid
local dungeoninstanceid
local width
local height
local playerlist = {}
local npclist = {}

function basemap.cmd()
    return CMD
end

-- 获取地图id
function basemap.getmapid()
    return mapid
end

-- 获取副本id
function basemap.getdungonid()
    return dungeonid
end

-- 获取副本实例id
function basemap.getdungoninstanceid()
    return dungeoninstanceid
end

-- 获取地图的宽
function basemap.getwidth()
    return width
end

-- 获取地图的高
function basemap.getheight()
    return height
end

function basemap.init(mapinfo)
    mapid = mapinfo.id
end

return basemap
