local _basechar = {}

function _basechar.create()
	local obj = {
		--aoi对象
		aoiobj = nil,
	}

	return obj
end

--扩展方法表
function _basechar.expandmethod(obj)
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
end

return _basechar
