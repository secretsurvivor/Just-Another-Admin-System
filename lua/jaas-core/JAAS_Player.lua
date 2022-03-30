local MODULE,LOG,J_NET,CONFIG = JAAS:Module("Player")

local PlayerTable = JAAS.SQLTableObject()

do -- Player SQL Table
	PlayerTable:SetSQLTable("JAAS_Player")

	PlayerTable:CreateTable{
		SteamID = "TEXT NOT NULL PRIMARY KEY",
		Code = "UNSIGNED BIG INT DEFAULT 0",
		LastConnected = "INTEGER NOT NULL DEFAULT 0"
	}

	function PlayerTable:Select(steamid)
		return self:SelectResults(self:Query("select Code,LastConnected from JAAS_Player where SteamID='%s'", steamid))
	end

	function PlayerTable:Insert(steamid)
		return self:Query("insert into JAAS_Player (SteamID) values ('%s')", steamid) == nil
	end

	function PlayerTable:UpdateCode(steamid, code)
		return self:Query("update JAAS_Player set Code=%s where SteamID='%s'", code, steamid) == nil
	end

	function PlayerTable:UpdateLastConnected(steamid)
		return self:Query("update JAAS_Player set LastConnected=%s where SteamID='%s'", os.time(), steamid)
	end
end

JAAS:Configs{
	STEAM_API_KEY = nil
}

local Player_Hook = JAAS.Hook("Player")

local Player_OnConnect = Player_Hook("OnConnect")
local Player_OnDisconnect = Player_Hook("OnDisconnect")
local Player_OnModifiedCode = Player_Hook("OnModifiedCode")
local Player_LocalPlayerModifiedCode = Player_Hook("LocalPlayerModifiedCode")

local Player_Hook_Run = JAAS.Hook.Run("Player")
local Rank_Hook_OnRemove = JAAS.Hook("Rank")("OnRemove")
local Permission_Hook_OnCodeUpdate = JAAS.Hook("Permission")("OnCodeUpdate")

local player_table = {} -- [SteamID] = {1 = Code, 2 = LastConnected}

function Rank_Hook_OnRemove.PlayerModule_RankCodeUpdate(isMulti, rank_name, remove_func)
	for k,v in pairs(player_table) do
		player_table[k][1] = remove_func(player_table[k][1])
		PlayerTable:UpdateCode(k, player_table[k][1])
	end
end

local PlayerMetaTable = FindMetaTable("Player")

function PlayerMetaTable:GetCode()
	return player_table[self:SteamID64()][1]
end

function PlayerMetaTable:GetLastConnected()
	return player_table[self:SteamID64()][2]
end

function PlayerMetaTable:IsDefaultUser()
	return self:GetCode() == 0
end

function MODULE.Shared:Post()
	local RankModule = JAAS:GetModule("Rank")

	function PlayerMetaTable:CanTarget(ply)
		if self:GetCode() > 0 and ply:GetCode() > 0 then
			return RankModule:GetMaxPower(self:GetCode()) > RankModule:GetMaxPower(ply:GetCode())
		elseif self:GetCode() > 0 then
			return RankModule:GetMaxPower(self:GetCode()) > 0
		end
	end
end

function MODULE:SetPlayerCode(ply, code)
	if PlayerTable:UpdateCode(ply:SteamID64(), code) then
		local old_value = player_table[ply:SteamID64()][1]
		if ply:IsConnected() then
			player_table[ply:SteamID64()][1] = code
			Player_Hook_Run("OnModifiedCode")(ply, code, old_value)
		end
		return true
	end
	return false
end

function MODULE:XorPlayerCode(ply, code) -- Should be the primary method of modifying a player's code
	return MODULE:SetPlayerCode(ply, bit.bxor(ply:GetCode(), code))
end

function MODULE:GetSteamInfo(steam64, func) -- Requires Steam API Key to function
	if CONFIG.STEAM_API_KEY != nil then
		http.Fetch(
			string.format("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s", CONFIG.STEAM_API_KEY, steam64), -- URL

			function (body, size, headers, code) -- On Success
				local response_table = util.JSONToTable(body)
				local player_info = response_table.response.players and response_table.response.players[1] or false

				if player_info == false then
					func(false, "invalid steamid")
				else
					func(true, player_info)
				end
			end,

			function (error) -- On Failure
				func(false, error)
			end
		)
		return true
	end
	return false
end

local net_modification_message = {}

do -- Net Message
	function net_modification_message:ModifyPlayerCode(ply, rank_object)
		self.ply = ply:UserID()
		self.rank = rank_object
		return self
	end

	function net_modification_message:GetPlayer()
		return self.ply
	end

	function net_modification_message:GetRank()
		return self.rank
	end

	function net_modification_message:NetWrite()
		net.WriteUInt(self.ply, 32)
		self.rank:NetWrite()
	end

	function net_modification_message:NetRead()
		self.ply = player.GetByID(net.ReadUInt(32))
		self.rank = JAAS.RankObject():NetRead()
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

do -- Net Code
	/*	Net Code Checklist
		(X = Not Present, O = Present)
		Server:
			On Connect Sync (Send) : O
			On Connect Update Clients (Send) : O
			On Disconnect Remove from Table (Send) : 0

			::On Update {1 = Code, 2 = LastConnected}::
			On Code Update (Send) : O
			On Last Connected Update (Send) : O

			::Support Client Modification::
			Code Modify (Receive) : O
		Client:
			On Connect Sync (Receive) : O
			On Connect Update Clients (Receive) : O
				Hook : O
			On Disconnect Remove from Table (Receive) :
				Hook : O

			::On Update {1 = Code, 2 = LastConnected}::
			On Code Update (Receive) : O
				Hook : O
			On Last Connected Update (Receive) : O

			::Support Client Modification::
			Code Modify (Send) : O
	*/
	local Player_Net_Sync = MODULE:RegisterNetworkType("Sync")
	local Sync_OnConnect = Player_Net_Sync("OnConnect")

	local Player_Net_Update = MODULE:RegisterNetworkType("Update")
	local Update_OnConnect = Player_Net_Update("OnConnect")
	local Update_OnDisconnect = Player_Net_Update("OnDisconnect")
	local Update_PlayerCode = Player_Net_Update("PlayerCode")
	local Update_Modify = Player_Net_Update("Modify")

	hook.Add("PlayerDisconnected", J_NET:GetNetworkString(Update_OnDisconnect), function (ply)
		PlayerTable:UpdateLastConnected(ply:SteamID64())
		player_table[ply:SteamID64()][2] = os.time()
		Player_Hook_Run("OnDisconnect", function () player_table[ply:SteamID64()] = nil end)(ply, player_table[ply:SteamID64()])
	end)

	if SERVER then
		local function writePlayerInfo(ply, code, last_connected) -- Player NetWrite Function
			net.WriteUInt(ply:UserID(), 32)
			net.WriteUInt(code, 32)
			net.WriteUInt(last_connected, 32)
		end

		do -- On Connect Sync (Send)
			J_NET:Receive(Sync_OnConnect, function (len, ply)
				local found_player = PlayerTable:Select(ply:SteamID64())
				print("JAAS Player Connected and given Code")

				if found_player then
					found_player = found_player[1]
					player_table[ply:SteamID64()] = {tonumber(found_player.Code), tonumber(found_player.LastConnected)}
				else
					if PlayerTable:Insert(ply:SteamID64()) then
						player_table[ply:SteamID64()] = {0, 0}
					else
						error("An error occurred whilst inserting new player")
					end
				end

				Player_Hook_Run("OnConnect")(ply, player_table[ply:SteamID64()])
			end)

			function Player_OnConnect.PlayerModule_Sync_OnConnect(ply, info)
				local steamid64_to_ply = {}
				local player_amount = 0

				for k,v in ipairs(player.GetAll()) do
					player_amount = k
					steamid64_to_ply[v:SteamID64()] = v
				end

				J_NET:Start(Sync_OnConnect)
				net.WriteUInt(player_amount, 8)
				for k,v in pairs(player_table) do
					writePlayerInfo(steamid64_to_ply[k], k[1], k[2])
				end
				net.Send(ply)
			end
		end

		do -- On Connect Update Clients (Send)
			function Player_OnConnect.PlayerModule_Update_OnConnect(ply, info)
				J_NET:Start(Update_OnConnect)
				net.WriteUInt(ply:UserID(), 32)
				net.WriteUInt(info[1], 32)
				net.WriteUInt(info[2], 32)
				net.SendOmit(ply)
			end
		end

		do -- On Disconnect Remove from Table (Send) | On Last Connected Update (Send)
			function Player_OnDisconnect.PlayerModule_Update_OnDisconnect(ply, info)
				J_NET:Start(Update_OnDisconnect)
				writePlayerInfo(ply, info[1], info[2])
				net.Broadcast()
			end
		end

		do -- On Code Update (Send)
			function Player_OnModifiedCode.PlayerModule_CodeModified(ply, new_value, old_value)
				J_NET:Start(Update_PlayerCode)
				net.WriteUInt(ply:UserID(), 32)
				net.WriteUInt(new_value, 32)
				net.Broadcast()
			end
		end

		do -- Code Modify (Receive)
			function MODULE.Server:Post()
				local PermissionModule = JAAS:GetModule("Permission")

				local CanModifyCode = PermissionModule:RegisterPermission("Can Modify Player Code")

				local CanReceiveMinorPlayerChatLogs = PermissionModule:RegisterPermission("Receive Minor Player Chat Logs")
				local CanReceiveMajorPlayerChatLogs = PermissionModule:RegisterPermission("Receive Major Player Chat Logs")
				local CanReceivePlayerConsoleLogs = PermissionModule:RegisterPermission("Receive Player Updates in Console")

				local PlayerSetRank_Log = LOG:RegisterLog {2, "was", 6, "given", 1, "by", 2} -- secret_survivor was given Admin by SomeOneElse
				local PlayerRemoveRank_Log = LOG:RegisterLog {2, "had", 1, 6, "took", "by", 2} -- secret_survivor had Admin taken away by SomeOneElse
				local PlayerSetRankSelf_Log = LOG:RegisterLog {2, "had", 6, "given", "themself", 1} -- secret_survivor had given themself Admin
				local PlayerRemoveRankSelf_Log = LOG:RegisterLog {2, "had", 6, "taken", 1, "away from themself"} -- secret_survivor had taken Admin away from themself
				local PlayerMadeDefaultUser_Log = LOG:RegisterLog {2, "was made a", 6, "default user"} -- secret_survivor was made a default user

				J_NET:Receive(Update_Modify, function (len, ply)
					local msg = ModificationMessage():NetRead()

					if CanModifyCode:Check(ply:GetCode()) then
						local target = msg:GetPlayer()
						if ply:SteamID64() == target:SteamID64() or ply:CanTarget(target) then
							local rank_object = msg:GetRank()
							if rank_object:AccessCheck(ply:GetCode()) then
								if MODULE:XorPlayerCode(target:GetCode(), rank_object:GetCode()) then
									if target:IsDefaultUser() then
										LOG:ChatText(CanReceiveMajorPlayerChatLogs:GetPlayers(), "%p was made a %R", target:Nick(), "Default User")
										LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p was made a %R", target:Nick(), "Default User")
										PlayerMadeDefaultUser_Log{Player = {target:SteamID64()}}
									else
										if bit.band(target:GetCode(), rank_object:GetCode()) > 0 then
											if ply:SteamID64() == target:SteamID64() then
												LOG:ChatText(CanReceiveMajorPlayerChatLogs:GetPlayers(), "%p gave themself %R", ply:Nick(), rank_object:GetName())
												LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p gave themself %R", ply:Nick(), rank_object:GetName())
												PlayerSetRankSelf_Log{Player = {ply:SteamID64()}, Rank = {rank_object:GetName()}}
											else
												LOG:ChatTex(CanReceiveMajorPlayerChatLogs:GetPlayers(), "%p made %p a member of %R", ply:Nick(), target:Nick(), rank_object:GetName())
												LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p made %p a member of %R", ply:Nick(), target:Nick(), rank_object:GetName())
												PlayerSetRank_Log{Player = {target:SteamID64(), ply:SteamID64()}, Rank = {rank_object:GetName()}}
											end
										else
											if ply:SteamID64() == target:SteamID64() then
												LOG:ChatText(CanReceiveMajorPlayerChatLogs:GetPlayers(), "%p removed themself from %R", ply:Nick(), rank_object:GetName())
												LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p removed themself from %R", ply:Nick(), rank_object:GetName())
												PlayerRemoveRankSelf_Log{Player = {ply:SteamID64()}, Rank = {rank_object:GetName()}}
											else
												LOG:ChatText(CanReceiveMajorPlayerChatLogs:GetPlayers(), "%p removed %p from %R", ply:Nick(), target:Nick(), rank_object:GetName())
												LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p removed %p from %R", ply:Nick(), target:Nick(), rank_object:GetName())
												PlayerRemoveRank_Log{Player = {target:SteamID64(), ply:SteamID64()}, Rank = {rank_object:GetName()}}
											end
										end
									end
								else
									if ply:SteamID64() == target:SteamID64() then
										LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p failed to modify their own Rank", ply:Nick(), target:Nick())
									else
										LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p failed to modify %p's Rank", ply:Nick(), target:Nick())
									end
								end
							else
								if ply:SteamID64() == target:SteamID64() then
									LOG:ChatText(CanReceiveMinorPlayerChatLogs:GetPlayers(), "%p attempted to give themself %R", ply:Nick(), rank_object:GetName())
									LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p attempted to give themself %R", ply:Nick(), rank_object:GetName())
								else
									LOG:ChatText(CanReceiveMinorPlayerChatLogs:GetPlayers(), "%p attempted to give %p %R", ply:Nick(), target:Nick(), rank_object:GetName())
									LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p attempted to give %p %R", ply:Nick(), target:Nick(), rank_object:GetName())
								end
							end
						else
							LOG:ChatText(CanReceiveMinorPlayerChatLogs:GetPlayers(), "%p attempted to modify %p's Rank", ply:Nick(), target:Nick())
							LOG:ConsoleText(CanReceivePlayerConsoleLogs:GetPlayers(), "%p attempted to modify %p's Rank", ply:Nick(), target:Nick())
						end
					else
					end
				end)
			end
		end
	elseif CLIENT then
		do -- Code Modify (Send)
			function MODULE:SetPlayerCode(ply, rank_object)
				ModificationMessage():ModifyPlayerCode(ply, rank_object):SendToServer()
			end
		end

		local function readPlayerInfo() -- Player NetRead Function
			local ply = Player(net.ReadUInt(32))

			local code = net.ReadUInt(32)
			local last = net.ReadUInt(32)

			player_table[ply:SteamID64()] = {code, last}
			return ply
		end

		do -- On Connect Sync (Receive)
			hook.Add("InitPostEntity", "JAAS::Player::Sync", function ()
				J_NET:Request(Sync_OnConnect)
			end)

			J_NET:Receive(Sync_OnConnect, function ()
				local player_amount = net.ReadUInt(8)

				local index = 1
				repeat
					readPlayerInfo()

					index = 1 + index
				until (index >= player_amount)
			end)
		end

		do -- On Connect Update Clients (Receive) + Hook
			J_NET:Receive(Update_OnConnect, function ()
				local ply = readPlayerInfo()
				Player_Hook_Run("OnConnect")(ply, player_table[ply:SteamID64()])
			end)
		end

		do -- On Disconnect Remove from Table (Receive) + Hook | On Last Connected Update (Receive)
			J_NET:Receive(Update_OnDisconnect, function ()
				local ply = readPlayerInfo()
				Player_Hook_Run("OnDisconnect", function () player_table[ply:SteamID64()] = nil end)(ply, player_table[ply:SteamID64()])
			end)
		end

		do -- On Code Update (Receive) + Hook
			J_NET:Receive(Update_PlayerCode, function ()
				local ply = player.GetByID(net.ReadUInt(32))
				local code = net.ReadUInt(32)

				player_table[ply:SteamID64()][1] = code
				Player_Hook_Run("OnModifiedCode")(ply, code)
				if ply:SteamID64() == LocalPlayer():SteamID64() then
					Player_Hook_Run("LocalPlayerModifiedCode")(code)
				end
			end)
		end

		local permission_access_change_table = {} -- [Permission:Name] = {1 = lastAccess, 2 = func}

		function MODULE:OnLocalPermissionAccessChange(permission_object, func)
			permission_access_change_table[permission_object:GetName()] = {permission_object:Check(LocalPlayer():GetCode()), func}
		end

		function MODULE.Client:Post()
			local PermissionModule = JAAS:GetModule("Permission")

			function Player_LocalPlayerModifiedCode.PlayerModule_CheckPlayerAccess(code)
				for k,v in pairs(permission_access_change_table) do
					local access = bit.band(LocalPlayer():GetCode(), PermissionModule.PermissionObject(k):GetCode()) > 0

					if access != v[1] then
						permission_access_change_table[k][1] = access
						func(access)
					end
				end
			end

			function Permission_Hook_OnCodeUpdate.PlayerModule_CheckPlayerAccess(permission_object, new_value)
				if permission_access_change_table[permission_object:GetName()] then
					local access = permission_object:Check(LocalPlayer():GetCode())
					if access != permission_access_change_table[permission_object][1] then
						permission_access_change_table[permission_object][1] = access
						permission_access_change_table[permission_object][2](access)
					end
				end
			end
		end
	end
end

if CLIENT then
	local list_of_players = {}
	local num_of_players = 0

	for k,v in ipairs(player.GetAll()) do
		list_of_players[v:SteamID64()] = v
		num_of_players = k
	end

	function Player_OnConnect.PlayerModule_PlayerSelectPanel(ply)
		list_of_players[ply:SteamID64()] = ply
		num_of_players = 1 + num_of_players
	end

	function Player_OnDisconnect.PlayerModule_PlayerSelectPanel(ply)
		list_of_players[ply:SteamID64()] = nil
		num_of_players = num_of_players - 1
	end

	local PlayerSelectElement = {}

	function PlayerSelectElement:Init()
		self.num_of_players = num_of_players

		for k,v in pairs(list_of_players) do
			self:AddChoice(v:Nick(), v)
		end
	end

	function PlayerSelectElement:Think()
		if self.num_of_players != num_of_players then
			self:Clear()

			for k,v in pairs(list_of_players) do
				self:AddChoice(v:Nick(), v)
			end

			self.num_of_players = num_of_players
		end
	end

	derma.DefineControl("DPlayerComboBox", "Automatic Player List ComboBox", PlayerSelectElement, "DComboBox")
end