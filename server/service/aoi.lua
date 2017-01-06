local skynet = require "skynet"
local service = require "service"
local aoi = require "aoi.core"
local log = require "syslog"

local CMD = {}
local config
local OBJ = {
  {1,"w",40,0,0},
  {2,"wm",42,100,0},
  {3,"w",0,40,0},
  {4,"wm",100,45,0}
}

local datle = {
  {0,1,0},
  {0,-1,0},
  {1,0,0},
  {-1,0,0},
}

function aoicallback(w,m)
  print(w,OBJ[w][3],OBJ[w][4],"=>",m,OBJ[m][3],OBJ[m][4])
end

local function update(n)
  for i = 1,3 do
    OBJ[n][i + 2] = OBJ[n][i + 2] + datle[n][i]
    if OBJ[n][i + 2] < 0 then
      OBJ[n][i + 2]  = OBJ[n][i + 2]  + 100
    elseif OBJ[n][i + 2] > 100 then
      OBJ[n][i + 2]  = OBJ[n][i + 2]  - 100
    end
  end
  aoi.update(table.unpack(OBJ[n]))
end

local function test()
  for i = 0,99 do
    if i < 50 then
      for j = 1,4 do
        update(j)
      end
    elseif i == 50 then
      OBJ[4][2] = "d"
      aoi.update(table.unpack(OBJ[4]))
    else
      for j = 1,3 do
        update(j)
      end
    end
    aoi.message()
  end
end

function CMD.open(conf)
  config = conf
  log.debug("aoi open")
  aoi.init()
  test()
end

function CMD.close()
  aoi.release()
end

service.init {
    command = CMD,
}
