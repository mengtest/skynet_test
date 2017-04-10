local _basechar = {}

function _basechar.create()
	local obj = {
		--aoi对象
		aoiobj = {},
		--角色信息
		objinfo = {},
	}

	return obj
end

--扩展方法表
function _basechar.expandmethod(obj)
	--设置角色临时id
	function obj:settempid(id)
		assert(self.aoiobj)
		assert(id > 0)
		self.aoiobj.tempid = id
	end

	--获取角色临时id
	function obj:gettempid()
		assert(self.aoiobj)
		return self.aoiobj.tempid
	end

	--设置aoi对象
	function obj:setaoiobj(aoiobj)
		assert(aoiobj)
		self.aoiobj = aoiobj
	end

	--获取aoi对象
	function obj:getaoiobj()
		return self.aoiobj
	end

	--设置角色信息
	function obj:setobjinfo(info)
		assert(info)
		self.objinfo = info
	end

	--获取角色信息
	function obj:getobjinfo()
		return self.objinfo
	end

	--设置角色名称
	function obj:setname(name)
		assert(self.objinfo)
		assert(#name > 0)
		self.objinfo.name = name
	end

	--获取角色名称
	function obj:getname()
		assert(self.objinfo)
		return self.objinfo.name
	end

	--设置角色等级
	function obj:setlevel(level)
		assert(self.objinfo)
		assert(level > 0)
		self.objinfo.level = level
	end

	--获取角色等级
	function obj:getlevel()
		assert(self.objinfo)
		return self.objinfo.level
	end

	--设置角色所在坐标点
	function obj:setpos(pos)
		assert(self.aoiobj)
		assert(pos)
		self.aoiobj.movement.pos = pos
	end

	--获取角色所在坐标点
	function obj:getpos()
		assert(self.aoiobj)
		return self.aoiobj.movement.pos
	end

	--获取移动相关数据
	function obj:getmovement()
		assert(self.aoiobj)
		return self.aoiobj.movement
	end
end

return _basechar
