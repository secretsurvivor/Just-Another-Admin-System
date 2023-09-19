local MODULE, LOG, NET, SQL = JAAS.RegisterModule("Player")

local Player_List = Player_List or {} // [SteamID64] = {1 = Code, 2 = LastConnected}
local List_Function = {}

SQL:Create([[
	SteamID64 TEXT NOT NULL PRIMARY KEY,
	Code UNSIGNED BIG INT DEFAULT 0,
	LastConnected INTEGER NOT NULL DEFAULT 0
]])

if !SQL:Exists() then
	SQL:CreateUniqueIndex("Key", "SteamID64")
end

do // List Function Code
	local Sync_net = NET:RegisterNet("SYNC__LIST")

	function List_Function:ModifyCode(steamid64, code)
		if SQL:Update("Code = " .. code, "SteamID64 = " .. steamid64) then
			local before = Player_List[steamid64][1]
			Player_List[steamid64][1] = code

			Sync_net:Broadcast(function ()
				net.WriteUInt(1, 4)
				net.WriteString(steamid64)
				net.WriteUInt(code, 32)
			end)

			MODULE.Hook("Code", steamid64, code)

			return true, not bit.band(code, before) > 0
		end

		return false
	end

	function List_Function:SetLastConnected(steamid64)
		local lastconnected = os.time()

		if SQL:Update("LastConnected = " .. lastconnected, "SteamID64 = " .. steamid64) then
			Player_List[steamid64][2] = lastconnected

			Sync_net:Broadcast(function ()
				net.WriteUInt(2, 4)
				net.WriteString(steamid64)
				net.WriteUInt(lastconnected, 32)
			end)

			MODULE.Hook("LastConnected", steamid64, lastconnected)

			return true
		end

		return false
	end

	if CLIENT then
		Sync_net:Receive(function (len, ply)
			local typ = net.ReadUInt(4)
			local steamid64 = net.ReadString()
			local data = net.ReadUInt(32)

			Player_List[steamid64][typ] = data

			if typ == 1 then
				MODULE.Hook("Code", steamid64, data)
			elseif typ == 2 then
				MODULE.Hook("LastConnected", steamid64, data)
			end
		end)
	end

	local Connect_Disconnect_Net = NET:RegisterNet("CONNECT_DISCONNECT__SYNC")

	if SERVER then
		gameevent.Listen("player_connect")
		hook.Add("player_connect", "__JAAS_PLAYER__MODULE__CONNECT", function (data)
			local ply = player.GetByID(data.userid)
			local data = SQL:SelectRow("Code, LastConnected", "SteamID64 = " .. ply:SteamID64())

			if data == nil then
				SQl:Insert("SteamID64", ply:SteamID64())
				data = {
					Code = 0,
					LastConnected = 0
				}
			end

			Connect_Disconnect_Net:Broadcast(function ()
				net.WriteUInt(1, 4)
				net.WriteEntity(ply)
				net.WriteUInt(data.Code, 32)
				net.WriteUInt(data.LastConnected, 32)
			end)

			Player_List[ply:SteamID64()] = {data.Code, data.LastConnected}
			JAAS.Hook.Call("System", "Connect", ply)
		end)

		gameevent.Listen("player_disconnect")
		hook.Add("player_disconnect", "__JAAS_PLAYER__MODULE__DISCONNECT", function (data)
			local ply = player.GetByID(data.userid)

			if !List_Function:SetLastConnected(steamid64) then
				ErrorNoHalt("Unable to set LastConnected attribute to '" .. ply:SteamID() .. "::" .. ply:Nick() .. "'")
			end

			Connect_Disconnect_Net:Broadcast(function ()
				net.WriteUInt(2, 4)
				net.WriteEntity(ply)
			end)

			JAAS.Hook.Call("System", "Disconnect", ply)
			Player_List[ply:SteamID64()] = {}
		end)
	end

	if CLIENT then
		Connect_Disconnect_Net:Receive(function (len, ply)
			local typ = net.ReadUInt(4)
			local ply = net.ReadEntity()

			if typ == 1 then
				Player_List[ply:SteamID64()] = {
					net.ReadUInt(32),
					net.ReadUInt(32)
				}

				JAAS.Hook.Call("System", "Connect", ply)
			elseif typ == 2 then
				JAAS.Hook.Call("System", "Disconnect", ply)

				Player_List[ply:SteamID64()] = nil
			end
		end)
	end

	do // Initial List Sync
		local Init_Sync_Net = NET:RegisterNet("INIT_SYNC__LIST")
		local InitMethods = {}

		function InitMethods.Write() // Server
			net.WriteCompressedTable(Player_List)
		end

		function InitMethods.Read() // Client
			Player_List = net.ReadCompressedTable()
		end

		Init_Sync_Net:InitialSyncTable("PLAYER__LIST", InitMethods)
	end

	do // Rank Removal Code
		local Remove_Sync = NET:RegisterNet("REMOVE__SYNC")

		if SERVER then
			JAAS.Hook.Register("Rank", "Remove", "PLAYER_MODULE__UPDATE_CODE", function (func)
				sql.Begin()
				local changed_IDs = {}

				for steamid64,v in pairs(Player_List) do
					local code,changed = func(v[1])

					if changed then
						Player_List[steamid64][1] = code
						SQL:Update("Code = " .. code, "SteamID64 = " .. steamid64)
						changed_IDs[steamid64] = code
						MODULE.Hook("Code", steamid64, code)
					end
				end

				sql.Commit()

				Remove_Sync:BroadcastCompressedTable(changed_IDs)
			end)
		end

		if CLIENT then
			Remove_Sync:ReceiveCompressedTable(function (tbl, len, ply)
				for steamid64,code in pairs(tbl) do
					Player_List[steamid64][1] = code
					MODULE.Hook("Code", steamid64, code)
				end
			end)
		end
	end
end

local PlayerMetaTable = FindMetaTable("Player")

do // Player Metatable Code
	// Instead of creating a player object, we're just going to reuse the Player object

	function PlayerMetaTable:GetCode()
		return Player_List[self:SteamID64()][1]
	end

	function PlayerMetaTable:GetLastConnected()
		return Player_List[self:SteamID64()][2]
	end

	function PlayerMetaTable:IsDefaultUser()
		return self:GetCode() == 0
	end

	function MODULE.Shared.Post(accessor)
		local Rank = accessor:GetModule("Rank")
		local Group = accessor:GetModule("Group")

		function PlayerMetaTable:GetPower()
			if self:IsDefaultUser() then
				return 0
			end

			local power = 0

			for rank in Rank:IterateRankCode(self:GetCode()) do
				if rank:GetPower() > power then
					power = rank:GetPower()
				end
			end

			return power
		end

		function PlayerMetaTable:CanTarget(ply)
			return ply:IsDefaultUser() or !self:IsDefaultUser() or self:GetPower() > ply:GetPower()
		end
	end
end

do // Player Module Code
	if SERVER then
		function MODULE:SetPlayerCode(ply, code)
			return List_Function:ModifyCode(ply:SteamID64(), code)
		end
	end

	function MODULE.Shared.Post(accessor)
		local Permission = accessor:GetModule("Permission")
		local Rank = accessor:GetModule("Rank")
		local Modify_Net = NET:RegisterNet("MODIFY__PLAYER")

		local CanModifyPlayer = Permission:RegisterPermission("Can Modify Player")
		local NotifyMajor = Permission:RegisterPermission("Receive Major Player Chat Updates")
		local NotifyMinor = Permission:RegisterPermission("Receive Minor Player Chat Updates")
		local ConsoleNotify = Permission:RegisterPermission("Receive Player Console Updates")

		local GivenRank = LOG:RegisterLog("%P %*set% %P as %r") // secret_survivor has given Admin to Dempsy
		local Gavethemself = LOG:RegisterLog("") // secret_survivor has taken Admin away from Dempsy
		// secret_survivor has given Admin to themself
		// secret_survivor has taken Admin away from themself
		// secret_survivor failed to give Admin to Dempsy
		// secret_survivor failed to take away Admin from Dempsy
		// secret_survivor failed to give Admin to themself

		if CLIENT then
			function MODULE:SetPlayerCode(ply, rank_id)
				Modify_Net:Broadcast(function ()
					net.WriteEntity(ply)
					net.WriteUInt(rank_id, 32)
				end)
			end
		end

		if SERVER then
			Modify_Net:Receive(function (len, ply)
				local target_ply = net.ReadEntity()
				local rank_id = net.ReadUInt(32)
				local same_ply = ply:SteamID64() == target_ply:SteamID64()

				local rank = Rank:GetRank(rank_id)

				if CanModifyPlayer:Check(ply:GetCode()) then
					if same_ply or ply:CanTarget(target_ply) then
						if rank:GroupCheck(ply:GetCode()) then
							local changed, added = List_Function:ModifyCode(target_ply:SteamID64(), rank:GetCode())

							if changed then
								if added then
									if same_ply then
									else
									end
								else
									if same_ply then
									else
									end
								end
							else
								MODULE:SendColouredConsole(ply, "^1JAAS : Player^0 -> ^2Failed^0 modifying permission ^3(Unknown)", Color(68, 84, 106), Color(228, 78, 78), Color(111, 111, 111))
							end
						else
							MODULE:SendColouredConsole(ply, "^1JAAS : Player^0 -> ^2Failed^0 modifying permission ^3(Missing group access)", Color(68, 84, 106), Color(228, 78, 78), Color(111, 111, 111))
						end
					else
						MODULE:SendColouredConsole(ply, "^1JAAS : Player^0 -> ^2Failed^0 modifying permission ^3(Cannot target Player)", Color(68, 84, 106), Color(228, 78, 78), Color(111, 111, 111))
					end
				else
					MODULE:SendColouredConsole(ply, "^1JAAS : Player^0 -> ^2Failed^0 modifying permission ^3(Missing [Can Modify Player] permission)", Color(68, 84, 106), Color(228, 78, 78), Color(111, 111, 111))
				end
			end)
		end
	end

	function MODULE:XorPlayerCode(ply, code)
		return MODULE:SetPlayerCode(ply, bit.bxor(ply:GetCode(), code))
	end

	if SERVER then
		local Steam_API = JAAS.Config("SteamAPIKey")

		function MODULE:GetUserData(steamid64, func)
			if Steam_API == nil then
				return ErrorNoHaltWithStack("Steam API Key needs to be added to configs to unlock features; SERVER SteamAPIKey : ******-***-***-***-******")
			end

			if func == nil then
				local function HttpFetchPlayerData(url, ...)
					url = string.format(url, ...)
					local running = coroutine.running()

					local function OnSuccess(body, size, headers, code)
						coroutine.resume(running, true, util.JSONToTable(body))
					end

					local function OnError(err)
						coroutine.resume(running, false, err)
					end

					http.Fetch(url, OnSuccess, OnError)

					return coroutine.yield()
				end

				return coroutine.wrap(function ()
					local state, data = HttpFetchPlayerData("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s", Steam_API, steamid64)

					if state then
						local player_info = response_table.response.players and response_table.response.players[1] or false

						if player_info == false then
							return false, "Invalid SteamID"
						else
							return true, player_info
						end
					else
						return false, data
					end
				end)()
			end

			http.Fetch(
				string.format("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s", Steam_API, steamid64), -- URL

				function (body, size, headers, code) -- On Success
					local response_table = util.JSONToTable(body)
					local player_info = response_table.response.players and response_table.response.players[1] or false

					if player_info == false then
						func(false, "invalid steamid")
					else
						func(true, player_info)
					end
				end,

				function (err) -- On Failure
					func(false, err)
				end
			)
		end
	end
end