local MODULE, log, dev, SQL = JAAS:RegisterModule "Ban"
SQL = SQL"JAAS_bans"

if SERVER and !SQL.EXIST then
    SQL.CREATE.TABLE {steamid = "UNSIGNED BIG INT", date = "UNSIGNED INTEGER", message = "TEXT"}
end

hook.Add("CheckPassword", "JAAS_BanCheck", function (steamid64, ipAddress, svPassword, clPassword, name)
	local results = SQL.SELECT "MAX(date),message" {steamid = steamid64}
	if results then
		if results["MAX(date)"] == 0 and os.time() < results.date then
			return false,results.message
		end
	end
end)

local ban_header, default_ban_message, ban_footer =
"--- JAAS Banning Module ---\n",
"Seems you've been a bad boy",
"\n-Love from JAAS xx"

local HookBanRun = JAAS.Hook "Ban"

local ban = {
	BanSteamID = function (ply, length, message, kick)
		if IsValid(ply) and ply:IsPlayer() then
			if istable(length) then
				length = os.time(length)
			end
			if length == 0 then
				if SQL.INSERT {steamid = ply:SteamID64(), date = 0, message = ban_header..(message or default_ban_message)..ban_footer} then
					HookBanRun "SteamIDBanned" (ply, 0, message or default_ban_message, kick)
					if kick then
						ply:Kick(ban_header..(message or default_ban_message)..ban_footer)
					end
					return true
				end
			else
				if SQL.INSERT {steamid = ply:SteamID64(), date = os.time() + length, message = ban_header..(message or default_ban_message)..ban_footer} then
					HookBanRun "SteamIDBanned" (ply, length, message or default_ban_message, kick)
					if kick then
						ply:Kick(ban_header..(message or default_ban_message)..ban_footer)
					end
					return true
				end
			end
		end
		return false
	end,
	GetBan = function (rowid)
		if isnumber(rowid) then
			return SQL.SELECT "steamid,date,message" {rowid = rowid}
		end
	end,
	GetBans = function (ply)
		if IsValid(ply) and ply:IsPlayer() then
			return SQL.SELECT "rowid,date,message" {steamid = ply:SteamID64()}
		end
		ErrorNoHalt("Argument must be a valid player entity\n")
	end,
	ModifyBanLength = function (rowid, new_date)
		return SQL.UPDATE {date = new_date} {rowid = rowid}
	end,
	ModifyBanMessage = function (rowid, message)
		return SQL.UPDATE {message = message} {rowid = rowid}
	end,
	UnBanSteamID = function (steamid64)
		if isentity(steamid64) and IsValid(steamid64) and steamid64:IsPlayer() then
			steamid64 = steamid64:SteamID64()
		end
		if SQL.DELETE {steamid = steamid64} then
			HookBanRun "SteamIDUnBanned" (steamid64)
			return true
		end
		return false
	end,
	GetBanList = function ()
		return SQL.SELECT ()
	end
}

dev:isTypeFunc("BanLibrary", "jaas_ban_library")

MODULE.Access(MODULE.Class(ban, "jaas_ban_library"))

local HookBan = JAAS.Hook "Ban"

local ban_logs = {
	BannedFor = log:registerLog {1, "has been", 6, "banned", "for", 4, "seconds with", 5}, -- Dempsy40 has been banned for 100 seconds with "RDM"
	BannedForBy = log:registerLog {1, "has been", 6, "banned", "by", 1, "for", 4, "seconds with", 5}, -- Dempsy40 has been banned by secret_survivor for 2 seconds with "RDM"
	BannedPerm = log:registerLog {1, "has been", 6, "banned", "permanently with", 5}, -- Dempsy40 has been banned permanently with "RDM"
	BannedPermBy = log:registerLog {1, "has been", 6, "banned", "permanently by", 1, "with", 5}, -- Dempsy40 has been banned permanently by secret_survivor with "RDM"
	Unbanned = log:registerLog {1, "has been", 6, "unbanned"}, -- Dempsy40 has been unbanned
	UnbannedBy = log:registerLog {1, "has been", 6, "unbanned", "by", 1} -- Dempsy40 has been unbanned by secret_survivor
}

MODULE.Handle.Server(function (jaas)
	local PERMISSION = jaas.Permission()
	local canBan = PERMISSION.registerPermission("Can Ban", "Player will be able to Ban other players")
	local canUnBan = PERMISSION.registerPermission("Can UnBan", "Player will be able to un-Ban other players")
	local canModifyBans = PERMISSION.registerPermission("Can Modify Bans", "Player will be able to modify current ban lengths and messages")

	util.AddNetworkString"JAAS_BanModificationChannel"
	/* ---- Ban Modification Channel Opcodes
		0 : Ban Target
		1 : UnBan Target
		2 : Modify Ban Length
		3 : Modify Ban Message
	*/
	local sendFeedback = dev.sendUInt("JAAS_BanModificationChannel", 3)
	/* ---- Ban Modification Channel Feedback Codes ----
		0 - Ban Successful
		1 - UnBan Successful
		2 - Length Modification Successful
		3 - Message Modification Successful
		4 - Ban/UnBan failed
		5 - Modification failed
		6 - Incorrect Permission Access
		7 - Unknown Opcode
	*/
	net.Receive("JAAS_BanModificationChannel", function (_, ply)
		local c_code = net.ReadUInt(2)
		local sendCode = sendFeedback(ply)
		if c_code == 0 then
			if canBan:codeCheck(ply) then
				local target = net.ReadEntity()
				local length = net.ReadFloat()
				local message = net.ReadString()
				local kick = net.ReadBool()
				if ban.BanSteamID(target, length, message, kick) then
					log:Log(ban_logs.BannedForBy, {player = {target, ply}, data = {length}, string = {message}})
					log:adminChat("%p has banned %p for %d with %s", ply:Nick(), target:Nick(), length, message)
					net.Start"JAAS_BanModificationChannel"
					net.WriteUInt(0, 3)
					net.WriteEntity(target)
					net.WriteFloat(length)
					net.WriteString(message)
					net.Send(ply)
				else
					sendCode(4)
				end
			else
				sendCode(6)
			end
		elseif c_code == 1 then
			if canUnBan:codeCheck(ply) then
				local target = net.ReadEntity()
				if ban.UnBanSteamID(target:SteamID64()) then
					log:Log(ban_logs.UnbannedBy, {player = {target, ply}})
					log:adminChat("%p has unbanned %p", ply:Nick(), target:Nick())
					net.Start"JAAS_BanModificationChannel"
					net.WriteUInt(1, 3)
					net.WriteEntity(target)
					net.Send(ply)
				else
					sendCode(4)
				end
			else
				sendCode(6)
			end
		elseif c_code == 2 then
			if canModifyBans:codeCheck(ply) then
				local rowid = net.ReadFloat()
				local new_length = net.ReadFloat()
				if ban.ModifyBanLength(rowid, new_length) then
					net.Start"JAAS_BanModificationChannel"
					net.WriteUInt(2, 3)
					net.WriteFloat(rowid)
					net.WriteFloat(new_length)
					net.Send(ply)
				else
					sendCode(5)
				end
			else
				sendCode(6)
			end
		elseif c_code == 3 then
			if canModifyBans:codeCheck(ply) then
				local rowid = net.ReadFloat()
				local message = net.ReadString()
				if ban.ModifyBanMessage(rowid, message) then
					net.Start"JAAS_BanModificationChannel"
					net.WriteUInt(3, 3)
					net.WriteFloat(rowid)
					net.WriteString(message)
					net.Send(ply)
				else
					sendCode(5)
				end
			else
				sendCode(6)
			end
		else
			sendCode(7)
		end
	end)
end)