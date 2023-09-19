local MODULE, LOG, NET, SQL = JAAS.RegisterModule("Permission")

local Permission_List = Permission_List or {} // [Name] = {1 = Code, 2 = Group, 3 = Description}
local List_Functions = {}

SQL:Create([[
	Name TEXT NOT NULL PRIMARY KEY,
	Code UNSIGNED INT DEFAULT 0,
	Group UNSIGNED INT DEFAULT 0
]])

if !SQL:Exists() then
	SQL:CreateUniqueIndex("Key", "Name")
end

do // Permission List Code
	local List_Sync_Net = NET:RegisterNet("LIST__SYNC")

	if SERVER then
		function List_Functions:ModifyCode(name, code)
			if SQL:Update("Code = " .. code, "Name = " .. name) then
				local before = Permission_List[name][1]
				Permission_List[name][1] = code

				List_Sync_Net:Broadcast(function ()
					net.WriteString(name)
					net.WriteUInt(1, 4) // 1 = Code
					net.WriteUInt(code, 32)
				end)

				JAAS.Hook.Permission.Call(name, "Code", code)

				return true, not bit.band(code, before) > 0
			end

			return false
		end

		function List_Functions:ModifyGroup(name, group)
			if SQL:Update("Group = " .. group, "Name = " .. name) then
				Permission_List[name][2] = group

				List_Sync_Net:Broadcast(function ()
					net.WriteString(name)
					net.WriteUInt(2, 4) // 2 = Group
					net.WriteUInt(group, 32)
				end)

				JAAS.Hook.Permission.Call(name, "Group", group)

				return true
			end

			return false
		end
	end

	if CLIENT then // List Sync Code
		List_Sync_Net:ReplaceReceiveParams(function (len, ply)
			local name = net.ReadString()
			local typ = net.ReadUInt(4)
			local num = net.ReadUInt(32)

			return name, typ, num
		end)

		List_Sync_Net:Receive(function (name, typ, num)
			Permission_List[name][typ] = num

			if typ == 1 then
				typ = "Code"
			elseif typ == 2 then
				typ = "Group"
			end

			JAAS.Hook.Permission.Call(name, typ, group)
		end)
	end

	do // Initial List Sync Code
		local Init_List_Sync_Net = NET:RegisterNet("INIT_LIST__SYNC")
		local InitSyncMethods = {}

		function InitSyncMethods.Write() // Server
			net.WriteCompressedTable(Permission_List)
		end

		function InitSyncMethods.Read() // Client
			Permission_List = net.ReadCompressedTable()
		end

		Init_List_Sync_Net:InitialSyncTable("PERMISSION__LIST", InitSyncMethods)
	end

	do // Rank Removal Code
		local Bulk_Remove_Net = NET:RegisterNet("REMOVE__SYNC")

		if SERVER then
			JAAS.Hook.Register("Rank", "Remove", "PERMISSION_MODULE__UPDATE_CODE", function (func)
				sql.Begin()
				local changed_codes = {}

				for name,v in pairs(Permission_List) do
					// New Code
					local code,changed = func(code)

					if changed then
						Permission_List[name][1] = code
						SQL:Update("Code = " .. code, "Name = " .. name)
						changed_codes[name] = code
						JAAS.Hook.Permission.Call(name, "Code", code)
					end
				end

				sql.Commit()

				Bulk_Remove_Net:BroadcastCompressedTable(changed_codes)
			end)
		end

		if CLIENT then
			Bulk_Remove_Net:ReceiveCompressedTable(function (tbl, len, ply)
				for name, code in pairs(tbl) do
					Permission_List[name][1] = code
					JAAS.Hook.Permission.Call(name, "Code", code)
				end
			end)
		end
	end
end

local Permission_Object = {}

do // Permission Object Code
	// Getter functions
	function Permission_Object:GetName()
		return self.name
	end

	function Permission_Object:GetCode()
		return Permission_List[self:GetName()][1]
	end

	function Permission_Object:GetGroup()
		return Permission_List[self:GetName()][2]
	end

	function Permission_Object:GetDescription()
		return Permission_List[self:GetName()][3]
	end

	if SERVER then
		// Server-side Setter functions
		function Permission_Object:SetCode(code)
			return List_Functions:ModifyCode(self:GetName(), code)
		end

		function Permission_Object:SetGroup(group)
			return List_Functions:ModifyGroup(self:GetName(), group)
		end
	end

	function Permission_Object:XorCode(code)
		return self:SetCode(bit.bxor(self:GetCode(), code))
	end

	function Permission_Object:Check(code)
		return self:GetCode() == 0 or bit.band(self:GetCode(), code) > 0
	end

	function MODULE.Shared.Post(accessor)
		local Group = accessor:GetModule("Group")
		local Permission = accessor:GetModule("Permission")
		local MODIFY_PERMISSION_NET = NET:RegisterNet("MODIFY__PERMISSION")

		local CanModify = Permission:RegisterPermission("Can Modify Permission")

		if CLIENT then
			// Client-side Setter functions
			function Permission_Object:SetCode(code)
				MODIFY_PERMISSION_NET:SendToServer(function ()
					net.WriteString(self:GetName())
					net.WriteUInt(1, 4)
					net.WriteUInt(code, 32)
				end)
			end

			function Permission_Object:SetGroup(group)
				MODIFY_PERMISSION_NET:SendToServer(function ()
					net.WriteString(self:GetName())
					net.WriteUInt(2, 4)
					net.WriteUInt(group, 32)
				end)
			end
		end

		if SERVER then
			MODIFY_PERMISSION_NET:ReplaceReceiveParams(function (len, ply)
				local name = sql.SQLStr(net.ReadString())
				local typ = net.ReadUInt(4)
				local num = net.ReadUInt(32)

				return ply, name, typ, num
			end)

			MODIFY_PERMISSION_NET:Receive(function (ply, name, typ, num)
				local permission = Permission_Object(name)

				if CanModify:Check(ply:GetCode()) then
					if permission:GroupCheck(ply:GetCode()) then
						if typ == 1 then
							List_Functions:ModifyCode(name, num)
						elseif typ == 2 then
							List_Functions:ModifyGroup(name, num)
						end
					else
						MODULE:SendColouredConsole(ply, "^1JAAS : Permission^0 -> ^2Failed^0 modifying permission ^3(Missing group access)", Color(196, 149, 0), Color(228, 78, 78), Color(111, 111, 111))
					end
				else
					MODULE:SendColouredConsole(ply, "^1JAAS : Permission^0 -> ^2Failed^0 modifying permission ^3(Missing [Can Modify Permission] permission)", Color(196, 149, 0), Color(228, 78, 78), Color(111, 111, 111))
				end
			end)
		end

		function Permission_Object:GroupCheck(code)
			return Group:CheckValue("Permission", self:GetGroup(), code)
		end
	end

	function Permission_Object:RegisterHook(event, identifier, func)
		JAAS.Hook.Permission.Register(self:GetName(), event, identifier, func)
	end

	function Permission_Object:GetPlayers()
		local plys = {}

		for k,v in ipairs(player.GetHumans()) do
			if self:Check(v:GetCode()) then
				plys[1 + #plys] = v
			end
		end

		return plys
	end

	// Object related functions
	local o = {Get = Permission_Object}

	function o:Constructor(name)
		self.name = name
	end

	function o:ToString()
		return "Permission: " .. self:GetName() .. "; [" .. self:GetCode() .. ", " .. self:GetGroup() .. "]"
	end

	Permission_Object = RegisterObject("Permission", o)
end

do // Permission Module Code
	function MODULE:GetPermission(name)
		if Permission_List[name] == nil then
			error("Permission does not exist; RegisterPermission before using this function or make sure that it gets registered before this gets used", 2)
		end

		return Permission_Structure(name)
	end

	if SERVER then
		function MODULE:RegisterPermission(name, description)
			local data = SQL:SelectRow("Code, Group", "Name = " .. name)

			if data == nil then
				if SQL:Insert("Name", name) then
					data = {
						Code = 0,
						Group = 0
					}
				else
					error("Unable to register Permission; Check that the Name is valid", 2)
				end
			end

			Permission_List[name] = {data.Code, data.Group, description}

			return Permission_Structure(name)
		end
	end

	if CLIENT then
		function MODULE:RegisterPermission(name)
			if Permission_List[name] == nil then
				error("Permission does not exist; Permissions must be registered on the Server-side", 2)
			end

			return Permission_Structure(name)
		end
	end

	function MODULE:IteratePermissions()
		local last_key

		return function ()
			last_key = next(Permission_List, last_key)

			if last_key != nil then
				return CreatePermissionObject(last_key)
			end
		end
	end
end