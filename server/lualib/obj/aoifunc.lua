local enumtype = require "enumtype"
local math_sqrt = math.sqrt

local _aoifun = {}

local function DIST2(p1,p2)
	return ((p1.x - p2.x) * (p1.x  - p2.x) + (p1.y  - p2.y) * (p1.y  - p2.y) + (p1.z  - p2.z) * (p1.z  - p2.z))
end

--根据对象类型插入table
local function inserttotablebytype(t,v,type)
	if type ~= enumtype.CHAR_TYPE_PLAYER then
		table.insert(t.monsterlist,v)
	else
		table.insert(t.playerlist,v)
	end
end


--扩展方法表
function _aoifun.expandmethod(obj)

	--对象自己移动的时候，将自己的变动信息同步到视野内其他对象
	function obj:updateaoiobj()
		local aoilist = self.aoilist
		if aoilist == nil then return end
		local myobj = self.aoiobj
		local mypos = myobj.movement.pos
	
		--离开他人视野
		local leavelist = {
			playerlist = {},
			monsterlist = {},
		}
		--进入他人视野
		local enterlist = {
			playerlist = {},
			monsterlist = {},
		}
		--通知他人自己移动
		local movelist = {
			playerlist = {},
			monsterlist = {},
		}
	
		local othertempid
		local otherpos
		local othertype
		local otherobj
		--遍历视野中的对象
		for k,v in pairs(aoilist) do
			othertempid = v.tempid
			otherpos = v.movement.pos
			othertype = v.type
			otherobj = {
				tempid = othertempid,
				agent = v.agent,
			}
			--计算对象之间的距离
			local distance = DIST2(mypos,otherpos)
			if distance <= AOI_RADIS2 then
				--在视野范围内的时候
				if not v.inview then
					--之前不在视野内，加入进入视野列表
					v.inview  = true
					inserttotablebytype(enterlist,otherobj,othertype)
				else
					--在视野内，更新坐标
					inserttotablebytype(movelist,otherobj,othertype)
				end
			elseif distance > AOI_RADIS2 and distance <= LEAVE_AOI_RADIS2 then
				--视野范围外，但是还在aoi控制内
				if v.inview then
					v.inview = false
					--之前在视野内的话，加入离开视野列表
					inserttotablebytype(leavelist,otherobj,othertype)
				end
			else
				--aoi控制外
				if v.inview then
					--之前在视野内的话，加入离开视野列表
					inserttotablebytype(leavelist,otherobj,othertype)
				end
				aoilist[k] = nil
			end
		end
	
		--离开他人视野
		for _,v in pairs(leavelist.playerlist) do
			skynet.send(v.agent,"lua","delaoiobj",self:gettempid())
		end
	
		--重新进入视野
		for _,v in pairs(enterlist.playerlist) do
			skynet.send(v.agent,"lua","addaoiobj",myobj)
		end
	
		--视野范围内移动
		for _,v in pairs(movelist.playerlist) do
			skynet.send(v.agent,"lua","updateaoiobj",myobj)
		end
	
		--怪物的更新合并一起发送
		if not table.empty(leavelist.monsterlist) or
		not table.empty(enterlist.monsterlist) or
		not table.empty(movelist.monsterlist) then
			local monsterenterlist = {
				obj = myobj,
				monsterlist = enterlist.monsterlist,
			}
			local monsterleavelist = {
				tempid = viewertempid,
				monsterlist = leavelist.monsterlist,
			}
			local monstermovelist = {
				obj = myobj,
				monsterlist = movelist.monsterlist,
			}
			skynet.send(mapagent,"lua","updateaoiinfo",monsterenterlist,monsterleavelist,monstermovelist)
		end
	
		--通知自己
		skynet.send(myobj.agent,"lua","updateaoilist",enterlist,leavelist)	
	end
	--获取obj的agent
	function obj:getagentid()
		assert(self.aoiobj)
		return self.aoiobj.agent
	end

	--更新对象的aoiobj信息
	function obj:updateaoiobj(aoiobj)
		assert(self.aoilist[aoiobj.tempid], aoiobj.tempid)
		self.aoilist[aoiobj.tempid] = aoiobj
	end

	--添加对象到aoilist
	function obj:addtoaoilist(aoiobj)
		assert(self.aoilist[aoiobj.tempid] == nil, aoiobj.tempid)
		self.aoilist[aoiobj.tempid] = aoiobj
	end

	--从aoilist中获取对象
	function obj:getfromaoilist(tempid)
		return self.aoilist[tempid]
	end

	--从aoilist中移除对象
	function obj:delfromaoilist(tempid)
		assert(self.aoilist[tempid],self.aoilist)
		self.aoilist[tempid] = nil
	end

	--清空aoilist
	function obj:cleanaoilist()
		self.aoilist = {}
	end

	--获取aoilist
	function obj:getaoilist()
		return self.aoilist
	end

	--获取可以发送信息的给前段的aoilist
	function obj:getsend2clientaoilist()
		local fdlist = {}
		for _,v in pairs(self.aoilist) do
			if v.type == enumtype.CHAR_TYPE_PLAYER then
				table.insert(fdlist,v.info)
			end
		end
		return fdlist
	end

	--设置aoi mode
	function obj:setaoimode(mode)
		assert(type(mode) == "string")
		self.aoiobj.mode = mode
	end

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

	--获取角色posdata key
	--agent-tempid
	function obj:getposdatakey()
		assert(self.aoiobj)
		assert(self.aoiobj.agent)
		assert(self.aoiobj.tempid)
		return self.aoiobj.agent.."-"..self.aoiobj.tempid
	end

	--设置aoi对象
	function obj:setaoiobj(aoiobj)
		assert(aoiobj)
		for k,v in pairs(aoiobj) do
			for kk,vv in pairs(v) do
				if self.aoiobj[k] == nil then
					self.aoiobj[k] = { kk }
				end
				self.aoiobj[k][kk] = vv
			end
		end
	end

	--获取aoi对象
	function obj:getaoiobj()
		return self.aoiobj
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

	--获取两个角色之间的距离
	function obj:getdistance(o)
		return math_sqrt(DIST2(self:getpos(),o:getpos()))
	end

	--获取两个角色之间的距离的平方
	function obj:getdistancesquare(o)
		return DIST2(self:getpos(),o:getpos())
	end
end

return _aoifun
