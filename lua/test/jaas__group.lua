local MODULE, LOG, NET, SQL = JAAS.RegisterModule("Group")

local Group_List = Group_List or {} // [Type] = {[Name] = {1 = Code, 2 = Value}}
local List_Functions = {}

SQL:Create([[
	Name TEXT NOT NULL,
	Type TEXT NOT NULL,
	Code UNSIGNED BIG INT DEFAULT 0,
	Value UNSIGNED INT DEFAULT 0,
	PRIMARY KEY (Name, Type)
]])

if !SQL:Exists() then
	SQL:CreateUniqueIndex("Key", "Name, Type")
end

do // List Function Code
	function List_Functions:ModifyCode(type, name, code)
	end

	function List_Functions:ModifyValue(type, name, value)
	end

	function List_Functions:AddGroup(type, name)
	end

	function List_Functions:RemoveGroup(type, name)
	end

	if CLIENT then // Update Client

	end

	do // Initial Tbl Sync

	end
end

local Group_Object = {}

do // Group Object Code
	function Group_Object:GetType()
		return self.type
	end

	function Group_Object:GetName()
		return self.name
	end

	function Group_Object:GetKey()
		return self:GetType(), self:GetName()
	end

	function Group_Object:GetCode()
		return Group_List[self:GetType()][self:GetName()][1]
	end

	function Group_Object:GetValue()
		return Group_List[self:GetType()][self:GetName()][2]
	end

	if SERVER then
		function Group_Object:SetCode(code)
			return List_Functions:ModifyCode(self:GetKey(), code)
		end

		function Group_Object:SetValue(value)
			return List_Functions:ModifyValue(self:GetKey(), value)
		end
	end

	function MODULE.Shared.Post(accessor)
		local Permission = accessor:GetModule("Permission")
		local Modify_Net = NET:RegisterNet("MODIFY__GROUP")

		local CanModifyGroup = Permission:RegisterPermission("Can Modify Group")

		if CLIENT then
			function Group_Object:SetCode(code)
			end

			function Group_Object:SetValue(value)
			end
		end

		if SERVER then
			Modify_Net:Receive(function (len, ply)
				if CanModifyGroup:Check(ply:GetCode()) then

				else

				end
			end)
		end
	end

	function Group_Object:XorCode(code)
		return self:SetCode(bit.bxor(code, self:GetCode()))
	end

	function Group_Object:Check(code)
		return self:GetCode() == 0 or bit.band(code, self:GetCode()) > 0
	end

	local o = {}

	function o:Constructor(typ, name)
		self.type = typ
		self.name = name
	end

	Group_Object = RegisterObject("Group", o)
end

do // Group Module Code
	function MODULE:AddGroup(type, name)

	end

	function MODULE:RemoveGroup(type, name)
	end

	function MODULE:IterateType(type)
		local last_key

		return function ()
			last_key = next(Group_List[type], last_key)

			if last_key != nil then
				return Group_Object(type, last_key)
			end
		end
	end

	function MODULE:IterateByValue(type, value)
		local last_key

		return function ()
			while true do
				last_key = next(Group_List[type], last_key)

				if last_key != nil then
					return
				end

				if Group_List[type][last_key][2] >= value then
					return Group_Object(type, last_key)
				end
			end
		end
	end

	function MODULE:GetTypeCount(type)
		local count = 0

		for group in self:IterateType(type) do
			count = 1 + count
		end

		return count
	end

	function MODULE:CheckValue(type, value, code)
		if Group_List[type] == nil then
			return true
		end

		local no_groups = true

		for group in self:IterateType(type) do
			if group:GetValue() > value and group:Check(code) then
				return true
			end

			no_groups = false
		end

		return false or no_groups
	end
end