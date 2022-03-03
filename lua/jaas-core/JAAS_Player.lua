local MODULE,LOG,J_NET = JAAS:Module("Player")

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

local Player_Hook = JAAS.Hook("Player")
local Player_Hook_Run = JAAS.Hook.Run("Player")

local player_table = {} -- [SteamID] = {1 = Code, 2 = LastConnected}

local PlayerMetaTable = FindMetaTable("Player")

function PlayerMetaTable:GetCode()
	return player_table[self:SteamID64()][1]
end

function PlayerMetaTable:GetLastConnected()
	return player_table[self:SteamID64()][2]
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
			Player_Hook_Run("OnModifiedCode")(ply, old_value)
		end
		return true
	end
	return false
end

function MODULE:XorPlayerCode(ply, code) -- Should be the primary method of modifying a player's code
	return MODULE:SetPlayerCode(ply, bit.bxor(ply:GetCode(), code))
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
	local Player_Net_Sync = MODULE:RegisterNetworkType("Sync")
	local Sync_OnConnect = Player_Net_Sync("OnConnect")

	local Player_Net_Update = MODULE:RegisterNetworkType("Update")
	local Update_OnConnect = Player_Net_Update("OnConnect")
	local Update_OnDisconnect = Player_Net_Update("OnDisconnect")
	local Update_Modify = Player_Net_Update("Modify")

	if SERVER then
		hook.Add("PlayerAuthed", J_NET:GetNetworkString(Update_OnConnect), function (ply)
			local found_player = PlayerTable:Select(ply:SteamID64())

			if found_player then
				player_table[ply:SteamID64()] = {found_player.Code, found_player.LastConnected}
			else
				if PlayerTable:Insert(ply:SteamID64()) then
					player_table[ply:SteamID64()] = {0, 0}
				else
					error("An error occurred whilst inserting new player")
				end
			end

			Player_Hook_Run("OnConnect")(ply, player_table[ply:SteamID64()])
		end)

		hook.Add("PlayerDisconnected", J_NET:GetNetworkString(Update_OnDisconnect), function (ply)
			PlayerTable:UpdateLastConnected(ply:SteamID64())
			player_table[ply:SteamID64()][2] = os.time()
			Player_Hook_Run("OnDisconnect", function () player_table[ply:SteamID64()] = nil end)(ply, player_table[ply:SteamID64()])
		end)

		function Player_Hook.OnConnect["PlayerModule::Sync::OnConnect"](ply, info)
			J_NET:Start(Sync_OnConnect)
			net.WriteUInt(player.GetCount(), 8)
			for k,v in pairs(player_table) do
				net.WriteString(k)
				net.WriteUInt(k[1], 32)
				net.WriteUInt(k[2], 32)
			end
			net.Send(ply)
		end

		function Player_Hook.OnConnect["PlayerModule::Update::OnConnect"](ply, info)
			J_NET:Start(Update_OnConnect)
			net.WriteString(ply:SteamID64())
			net.WriteUInt(info[1], 32)
			net.WriteUInt(info[2], 32)
			net.SendOmit(ply)
		end

		function Player_Hook.OnDisconnect["PlayerModule::Update::OnDisconnect"](ply, info)
			J_NET:Start(Update_OnDisconnect)
			net.WriteString(ply:SteamID64())
			net.Broadcast()
		end

		function MODULE.Server:Post()
			local PermissionModule = JAAS:GetModule("Permission")

			local CanModifyCode = PermissionModule:RegisterPermission("Can Modify Player Code")

			J_NET:Receive(Update_Modify, function (len, ply)
				local msg = ModificationMessage():NetRead()

				if CanModifyCode:Check(ply:GetCode()) then
					local target = msg:GetPlayer()
					if ply:CanTarget(target) then
						if MODULE:XorPlayerCode(target, msg:GetRank():GetCode()) then
						else
						end
					else
					end
				else
				end
			end)
		end
	elseif CLIENT then
		function MODULE:SetPlayerCode(ply, rank_object)
			ModificationMessage():ModifyPlayerCode(ply, rank_object):SendToServer()
		end

		local function readPlayerInfo()
			local ply = net.ReadString()
			local code = net.ReadUInt(32)
			local last = net.ReadUInt(32)

			player_table[ply] = {code, last}
		end

		J_NET:Receive(Sync_OnConnect, function ()
			local player_amount = net.ReadUInt(8)
			local index = 1
			repeat
				readPlayerInfo()

				index = 1 + index
			until (index <= player_amount)
		end)

		J_NET:Receive(Update_OnConnect, function ()
			readPlayerInfo()
		end)

		J_NET:Receive(Update_OnDisconnect, function ()
			player_table[net.ReadString()] = nil
		end)
	end
end