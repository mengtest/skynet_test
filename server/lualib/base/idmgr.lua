--[[===================================
local _idmgr = {
  id = 1,
  max = 1,
  pool = {},
}

--设置最大id
function _idmgr:setmaxid(id)
  self.max = id
end

--分配一个id
function _idmgr:createid()
  local tempid = self.id
  self.id = self.id + 1
  if self.pool[tempid] then
    for i = 1,self.max do
      tempid = nil
      if self.pool[i] == nil then
        tempid = i
        break
      end
    end
    assert(tempid)
  end
  self.id = tempid + 1
  if self.id >= self.max then
    self.id = 1
  end
  self.pool[tempid] = true
  return tempid
end

--释放一个id
function _idmgr:releaseid(id)
  self.pool[id] = nil
end

return _idmgr
]] --[[===============================
local _idmgr = {}

local max = 1
local id = 1
local pool = {}

--设置最大id
function _idmgr:setmaxid(id)
  max = id
end

--分配一个id
function _idmgr:createid()
  local tempid = id
  id = id + 1
  if pool[id] then
    for i = 1,max do
      tempid = nil
      if pool[i] == nil then
        tempid = i
        break
      end
    end
    assert(tempid)
  end
  id = tempid + 1
  if id >= max then
    id = 1
  end
  return tempid
end

--释放一个id
function _idmgr:releaseid(id)
  pool[id] = nil
end

return _idmgr

local _idmgr = {
    id = 1,
    max = 1,
    pool = {}
}

local s_method = {
    __index = {}
}

local function init_method(func)
    -- 设置最大id
    function func:setmaxid(id)
        self.max = id
    end

    -- 分配一个id
    function func:createid()
        local tempid = self.id
        self.id = self.id + 1
        if self.pool[tempid] then
            for i = 1, self.max do
                tempid = nil
                if self.pool[i] == nil then
                    tempid = i
                    break
                end
            end
            assert(tempid)
        end
        self.id = tempid + 1
        if self.id >= self.max then
            self.id = 1
        end
        self.pool[tempid] = true
        return tempid
    end

    -- 释放一个id
    function func:releaseid(id)
        self.pool[id] = nil
    end
end

init_method(s_method.__index)

return setmetatable(_idmgr, s_method)

]] -- ================================
local idmgr = {}

local id = 1
local max = 1
local pool = {}
-- 设置最大id
function idmgr.setmaxid(_id)
    max = _id
end

-- 分配一个id
function idmgr.createid()
    local tempid = id
    id = id + 1
    if pool[tempid] then
        for i = 1, max do
            tempid = nil
            if pool[i] == nil then
                tempid = i
                break
            end
        end
        assert(tempid)
    end
    id = tempid + 1
    if id >= max then
        id = 1
    end
    pool[tempid] = true
    return tempid
end

-- 释放一个id
function idmgr.releaseid(_id)
    pool[_id] = nil
end

return idmgr
