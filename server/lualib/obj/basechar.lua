local skynet = require "skynet"
local aoifun = require "obj.aoifunc"
local enumtype = require "enumtype"

local _basechar = {}

function _basechar.create(type)
    local obj = {
        -- 初始化函數
        init_func = {},
        -- 释放函数
        release_func = {},
        -- aoi对象
        aoiobj = {
            agent = skynet.self(),
            tempid = 0,
            type = enumtype.CHAR_TYPE_UNKNOW,
            movement = {
                mode = "wm",
                pos = {
                    x = 0,
                    y = 0,
                    z = 0
                },
                map = 0
            }
        },
        -- 角色信息
        objinfo = {},
        -- 视野内的角色
        aoilist = {}
    }
    assert(type and type > enumtype.CHAR_TYPE_UNKNOW and type < enumtype.CHAR_TYPE_MAX)

    obj.aoiobj.type = type
    return obj
end

-- 扩展方法表
function _basechar.expandmethod(obj)
    -- 获取角色类型
    function obj:gettype()
        return self.aoiobj.type
    end

    -- 是否玩家
    function obj:isplayer()
        return self.aoiobj.type == enumtype.CHAR_TYPE_PLAYER
    end

    -- 是否玩家
    function obj:isnpc()
        return self.aoiobj.type == enumtype.CHAR_TYPE_NPC
    end

    -- 是否玩家
    function obj:ismonster()
        return self.aoiobj.type == enumtype.CHAR_TYPE_MONSTER
    end

    -- 设置角色信息
    function obj:setobjinfo(info)
        assert(info)
        self.objinfo = info
    end

    -- 获取角色信息
    function obj:getobjinfo()
        return self.objinfo
    end

    -- 设置角色名称
    function obj:setname(name)
        assert(self.objinfo)
        assert(#name > 0)
        self.objinfo.name = name
    end

    -- 获取角色名称
    function obj:getname()
        assert(self.objinfo)
        return self.objinfo.name
    end

    -- 设置角色等级
    function obj:setlevel(level)
        assert(self.objinfo)
        assert(level > 0)
        self.objinfo.level = level
    end

    -- 获取角色等级
    function obj:getlevel()
        assert(self.objinfo)
        return self.objinfo.level
    end

    -- 添加到初始化函数中
    function obj:addinitfunc(f)
        table.insert(self.init_func, f)
    end

    -- 调用初始化函数
    function obj:init()
        for _, f in pairs(self.init_func) do
            f()
        end
    end

    -- 添加到输出化函数中
    function obj:addreleasefunc(f)
        table.insert(self.release_func, f)
    end

    -- 调用初始化函数
    function obj:release()
        for _, f in pairs(self.release_func) do
            f()
        end
    end

    -- 添加aoifunc
    aoifun.expandmethod(obj)
end

return _basechar
