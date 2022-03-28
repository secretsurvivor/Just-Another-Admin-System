local MODULE,LOG,J_NET = JAAS:Module("Permission")

local PermissionTable = JAAS.SQLTableObject()

do -- SQL Permission Table Code
	PermissionTable:SetSQLTable("JAAS_Permission")

	PermissionTable:CreateTable {
		Name = "TEXT NOT NULL PRIMARY KEY",
		Code = "UNSIGNED BIG INT DEFAULT 0",
		AccessGroup = "UNSIGNED INT DEFAULT 0"
	}

	function PermissionTable:Select(name)
		return self:SelectResults(self:Query("select Code,AccessGroup from JAAS_Permission where Name='%s'", name))
	end

	function PermissionTable:Insert(name)
		return self:Query("insert into JAAS_Permission (Name) values ('%s')", name) == nil
	end

	function PermissionTable:UpdateCode(name, code)
		return self:Query("update JAAS_Permission set Code=%s where Name='%s'", code, name) == nil
	end

	function PermissionTable:UpdateAccessGroup(name, access_group)
		return self:Query("update JAAS_Permission set AccessGroup where Name='%s'", access_group, name) == nil
	end
end

local Permission_Hook = JAAS.Hook("Permission")

local Permission_OnCodeUpdate = Permission_Hook("OnCodeUpdate")
local Permission_OnAccessUpdate = Permission_Hook("OnAccessUpdate")

local Permission_Hook_Run = JAAS.Hook.Run("Permission")

local Rank_Hook_OnRemove = JAAS.Hook("Rank")("OnRemove")
local Player_Hook_OnConnect = JAAS.Hook("Player")("OnConnect")

local PermissionDataManipulation_NetType = MODULE:RegisterNetworkType("Modify")
local Modify_PushChange = PermissionDataManipulation_NetType("ClientPush")

local permission_table = permission_table or {} -- [Name] = {1 = Code, 2 = AccessGroup}

function Rank_Hook_OnRemove.PermissionModule_RankCodeUpdate(isMulti, rank_name, remove_func)
	for k,v in pairs(permission_table) do
		permission_table[k][1] = remove_func(permission_table[k][1])
		PermissionTable:UpdateCode(k, permission_table[k][1])
	end
end

local PermissionObject = {name = ""}

do -- Permission Object Code
	function PermissionObject:GetName()
		return self.name
	end

	function PermissionObject:GetCode()
		return permission_table[self:GetName()][1]
	end

	function PermissionObject:SetCode(code)
		if PermissionTable:UpdateCode(self:GetName(), code) then
			local old_value = self:GetCode()
			permission_table[self:GetName()][1] = code
			Permission_Hook_Run("OnCodeUpdate")(self, code, old_value)
			return true
		end
		return false
	end

	function PermissionObject:XorCode(code)
		return self:SetCode(bit.bxor(self:GetCode(), code))
	end

	function PermissionObject:GetAccessCode()
		return permission_table[self:GetName()][2]
	end

	function PermissionObject:IsGlobalAccess()
		return self:GetCode() == 0
	end

	function PermissionObject:SetAccessCode(access_group)
		if PermissionTable:UpdateAccessGroup(self:GetName(), access_group) then
			local old_value = self:GetAccessCode()
			permission_table[self:GetName()][2] = access_group
			Permission_Hook_Run("OnAccessUpdate")(self, access_group, old_value)
			return true
		end
		return true
	end

	function PermissionObject:Check(code)
		if !isnumber(code) then
			error("Wrong data type", 2)
		end
		return bit.band(self:GetCode(), code) > 0
	end

	function MODULE.Shared:Post()
		local AccessModule = JAAS:GetModule("AccessGroup")

		function PermissionObject:AccessCheck(code)
			return AccessModule:Check("Permission", self:GetAccessCode(), code)
		end
	end

	function PermissionObject:GetPlayers() -- Get All Players that have this permission
		local playersWithPermission = {}

		for k,v in ipairs(player.GetAll()) do
			if self:Check(v:GetCode()) then
				playersWithPermission[1 + #playersWithPermission] = v
			end
		end

		return playersWithPermission
	end

	function PermissionObject:NetWrite()
		net.WriteString(self:GetName())
		net.WriteUInt(self:GetCode(), 32)
		net.WriteUInt(self:GetAccessCode(), 16)
		return self
	end

	function PermissionObject:NetRead()
		self.name = net.ReadString()
		self.Code = net.ReadUInt(32)
		self.AccessGroup = net.ReadUInt(16)
		return self
	end

	function PermissionObject:SaveLocal()
		permission_table[self.name] = {self.Code, self.AccessGroup}
	end

	if CLIENT then
		function PermissionObject:SetCode(code)
			permission_table[self:GetName()][1] = code
		end

		function PermissionObject:SetAccessCode(access_group)
			permission_table[self:GetName()][2] = access_group
		end
	end
end

local function CreatePermissionObject(name)
	return Object(PermissionObject, {name = name})
end

JAAS.PermissionObject = CreatePermissionObject

function MODULE:RegisterPermission(name)
	local found_data = PermissionTable:Select(name)

	if found_data then
		found_data = found_data[1]
		permission_table[name] = {[1] = found_data.Code, [2] = found_data.AccessGroup}
		return CreatePermissionObject(name)
	else
		if PermissionTable:Insert(name) then
			permission_table[name] = {[1] = 0, [2] = 0}
			return CreatePermissionObject(name)
		else
			error("Invalid Permission Name", 2)
		end
	end
end

if CLIENT then
	function MODULE:RegisterPermission(name)
		if permission_table[name] == nil then
			permission_table[name] = {[1] = 0, [2] = 0}
			return CreatePermissionObject(name)
		else
			error("Permission already exists; use GetPermission function to get already registered functions", 2)
		end
	end
end

function MODULE:GetPermission(name)
	if permission_table[name] then
		return CreatePermissionObject(name)
	else
		error("Permission does not exist", 2)
	end
end

local net_modification_message = {}

do -- Modification Net Message
	function net_modification_message:ModifyCode(permission_object, rank_object)
		self.opcode = 1
		self.permission = permission_object
		self.rank = rank_object
	end

	function net_modification_message:ModifyAccessValue(permission_object, access_group_object)
		self.opcode = 2
		self.permission = permission_object
		self.access_group_object = access_group_object
	end

	function net_modification_message:IsModifyCode()
		return self.opcode == 1
	end

	function net_modification_message:IsModifyAccessGroup()
		return self.opcode == 2
	end

	function net_modification_message:GetPermissionObject()
		return self.permission
	end

	function net_modification_message:GetRankObject()
		return self.rank
	end

	function net_modification_message:GetAccessGroup()
		return self.access_group_object
	end

	function net_modification_message:NetWrite()
		net.WriteUInt(self.opcode, 2)
		self.permission:NetWrite()

		if self.opcode == 1 then
			self.rank:NetWrite()
		elseif self.opcode == 2 then
			self.access_group_object:NetWrite()
		end
	end

	function net_modification_message:NetRead()
		self.code = net.ReadUInt(2)
		self.permission = JAAS.PermissionObject():NetRead()

		if self.opcode == 1 then
			self.rank = JAAS.RankObject():NetRead()
		elseif self.opcode == 2 then
			self.access_group_object = JAAS.AccessGroupObject():NetRead()
		end
	end

	function net_modification_message:SendToServer(index)
		J_NET:Start(index)
		self:NetWrite()
		net.SendToServer()
	end
end

local function ModificationMessage(tab)
	return Object(net_modification_message, tab)
end

MODULE.ModificationMessage = ModificationMessage

local Permission_Net_Sync = MODULE:RegisterNetworkType("Sync")
local Sync_OnConnect = Permission_Net_Sync("OnConnect")

local Permission_Net_Client = MODULE:RegisterNetworkType("Client")
local Client_Modify = Permission_Net_Client("Modify")

local Permission_Net_Update = MODULE:RegisterNetworkType("Update")
local Update_Code = Permission_Net_Update("Code")
local Update_AccessGroup = Permission_Net_Update("AccessGroup")

local CanModifyPermission = MODULE:RegisterPermission("Can Modify Permission Code")
local CanModifyPermissionValue = MODULE:RegisterPermission("Can Modify Permission Access Group")

local CanReceiveMinorPermissionChatLogs = MODULE:RegisterPermission("Receive Minor Permission Chat Logs")
local CanReceiveMajorPermissionChatLogs = MODULE:RegisterPermission("Receive Major Permission Chat Logs")
local CanReceivePermissionUpdatesOnConsole = MODULE:RegisterPermission("Receive Permission Updates in Console")

do -- Permission Net Code
	/*	Net Code Checklist
		(X = Not Present, O = Present)
		Server:
			On Connect Client Sync (Send) : O

			::Update on {1 = Code, 2 = AccessGroup}::
			On Code Update (Send) : O
			On Access Group Update (Send) : O

			::Support Client Modification::
			Modify Code (Receive) : O
			Modify Access Group (Receive) : O
		Client:
			On Connect Client Sync (Receive) :

			::Update on {1 = Code, 2 = AccessGroup}::
			On Code Update (Receive) : O
				Hook : O
			On Access Group Update (Receive) : O
				Hook : O

			::Support Client Modification::
			Modify Code (Send) : O
			Modify Access Group (Send) : O
	*/
	if SERVER then
		do -- On Code Update (Send)
			function Permission_OnCodeUpdate.PermissionModule_UpdateClients(permission, new_value, old_value)
				J_NET:Start(Update_Code)
				permission:NetWrite()
				net.Broadcast()
			end
		end

		do -- On Access Group Update (Send)
			function Permission_OnAccessUpdate.PermissionModule_UpdateClients(permission, new_value, old_value)
				J_NET:Start(Update_AccessGroup)
				permission:NetWrite()
				net.Broadcast()
			end
		end

		do -- On Connect Client Sync (Send)
			function Player_Hook_OnConnect.Permission_SyncClients(ply)
				J_NET:Start(Sync_OnConnect)

				local permission_amount = tonumber(PermissionTable:TopValue(PermissionTable:Query("select count(*) from JAAS_Permission"), "count(*)", 0))
				net.WriteUInt(permission_amount, 16)
				for k,v in pairs(permission_table) do
					CreatePermissionObject(k):NetWrite()
				end

				net.Send(ply)
			end
		end

		do -- Modify Code (Receive) | Modify Access Group (Receive)
			local PermissionAdded_Log = LOG:RegisterLog {"Permission", 3, "was", 6, "added", "to", 1, "by", 2} -- Permission Noclip was added to Admin by secret_survivor
			local PermissionRemoved_Log = LOG:RegisterLog {"Permission", 3, "was", 6, "removed", "from", 1, "by", 2} -- Permission Noclip was removed from Admin by secret_survivor
			local PermissionGlobalAccess_Log = LOG:RegisterLog {"Permission", 3, "was given", 6, "global access", "by", 2} -- Permission Noclip was given global access by secret_survivor
			local PermissionAttempt_Log = LOG:RegisterLog {2, 6, "attempted", "to modify Permission", 3} -- secret_survivor attempted to modify Permission Noclip

			local AccessGroupSet_Log = LOG:RegisterLog {"Permission", 3, "was", 6, "added", "to Access Group", 3, "by", 2} -- Permission Noclip was added to Access Group Admin Group by secret_survivor
			local AccessGroupRemove_Log = LOG:RegisterLog {"Permission", 3, "had its Access Value", 6, "reset", "by", 2} -- Permission Noclip has its Access Value reset by secret_survivor

			J_NET:Receive(Client_Modify, function (len, ply)
				local msg = ModificationMessage():NetRead()

				if msg:IsModifyCode() then
					local permission_object = msg:GetPermissionObject()
					if CanModifyPermission:Check(ply:GetCode()) then
						local rank_object = msg:GetRankObject()
						if permission_object:AccessCheck(ply:GetCode()) then
							if permission_object:XorCode(rank_object:GetCode()) then
								if permission_object:IsGlobalAccess() then
									LOG:ChatText(CanReceiveMajorPermissionChatLogs:GetPlayers(), "%P was given global access by %p", permission_object:GetName(), ply:Nick())
									LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%P was given global access by %p", permission_object:GetName(), ply:Nick())
									PermissionGlobalAccess_Log{Entity = {permission_object:GetName()}, Player = {ply:SteamID64()}}
								else
									if permission_object:Check(rank_object:GetCode()) then
										LOG:ChatText(CanReceiveMajorPermissionChatLogs:GetPlayers(), "%p added %P to %R", ply:Nick(), permission_object:GetName(), rank_object:GetName())
										LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p added %P to %R", ply:Nick(), permission_object:GetName(), rank_object:GetName())
										PermissionAdded_Log{Entity = {permission_object:GetName()}, Player = {ply:SteamID64()}, Rank = {rank_object:GetName()}}
									else
										LOG:ChatText(CanReceiveMajorPermissionChatLogs:GetPlayers(), "%p removed %P from %R", ply:Nick(), permission_object:GetName(), rank_object:GetName())
										LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p removed %P from %R", ply:Nick(), permission_object:GetName(), rank_object:GetName())
										PermissionRemoved_Log{Entity = {permission_object:GetName()}, Player = {ply:SteamID64()}, Rank = {rank_object:GetName()}}
									end
								end
							else
								LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p failed to modify %P's code with %R", ply:Nick(), permission_object:GetName(), rank_object:GetName())
							end
						else
							LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p failed to modify %P's code with %R", ply:Nick(), permission_object:GetName(), rank_object:GetName())
						end
					else
						PermissionAttempt_Log{Entity = {permission_object:GetName()}, Player = {ply:SteamID64()}}
					end
				elseif msg:IsModifyValue() then
					if CanModifyPermissionValue:Check(ply:GetCode()) then
						local permission_object = msg:GetPermissionObject()
						local access_group = msg:GetAccessGroup()
						if permission_object:AccessCheck(ply:GetCode()) then
							if permission_object:GetAccessCode() == access_group:GetValue() then
								if permission_object:SetAccessCode(0) then
									LOG:ChatText(CanReceiveMinorPermissionChatLogs:GetPlayers(), "%p reset %P's Access Code", ply:Nick(), permission_object:GetName())
									LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p reset %P's Access Code", ply:Nick(), permission_object:GetName())
									AccessGroupRemove_Log{Entity = {permission_object:GetName()}, Player = {ply:SteamID64()}}
								else
									LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p failed to reset %P's Access Code", ply:Nick(), permission_object:GetName())
								end
							else
								if permission_object:SetAccessCode(access_group:GetValue()) then
									LOG:ChatText(CanReceiveMinorPermissionChatLogs:GetPlayers(), "%p added %P to %A", ply:Nick(), permission_object:GetName(), access_group:GetName())
									LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p added %P to %A", ply:Nick(), permission_object:GetName(), access_group:GetName())
									AccessGroupSet_Log{Entity = {permission_object:GetName(), access_group:GetName()}, Player = {ply:SteamID64()}}
								else
									LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p failed to add %P to %A", ply:Nick(), permission_object:GetName(), access_group:GetName())
								end
							end
						else
							LOG:ConsoleText(CanReceivePermissionUpdatesOnConsole:GetPlayers(), "%p attempted to set %P's Access Group to %A", ply:Nick(), permission_object:GetName(), access_group:GetName())
						end
					else
					end
				end
			end)
		end
	end

	if CLIENT then
		do -- Modify Code (Send)
			function MODULE:ModifyCode(permission_object, rank_object)
				ModificationMessage():ModifyCode(permission_object, rank_object):SendToServer()
			end
		end

		do -- Modify Access Group (Send)
			function MODULE:ModifyAccessValue(permission_object, access_group_object)
				ModificationMessage():ModifyAccessValue(permission_object, access_group_object):SendToServer()
			end
		end

		do -- On Code Update (Receive) + Hook
			J_NET:Receive(Update_Code, function ()
				local updated_object = CreatePermissionObject():NetRead()
				Permission_Hook_Run("OnCodeUpdate")(updated_object, updated_object:GetCode())
			end)
		end

		do -- On Access Group Update (Receive) + Hook
			J_NET:Receive(Update_AccessGroup, function ()
				local updated_object = CreatePermissionObject():NetRead()
				Permission_Hook_Run("OnAccessUpdate")(updated_object, updated_object:GetCode())
			end)
		end

		do -- On Connect Client Sync (Receive)
			J_NET:Receive(Sync_OnConnect, function ()
				local permission_amount = net.ReadUInt(16)

				local index = 1
				repeat
					CreatePermissionObject():NetRead():SaveLocal()

					index = 1 + index
				until (index >= permission_amount)

				Permission_Hook_Run("PostPermissionSync")()
			end)
		end
	end
end

if CLIENT then
	local PermissionSelectElement = {}

	function PermissionSelectElement:Init()
		for k,v in pairs(permission_table) do
			self:AddChoice(k, CreatePermissionObject(k))
		end
	end

	derma.DefineControl("JPermissionComboBox", "Automatic Permission List ComboBox", PermissionSelectElement, "DComboBox")
end