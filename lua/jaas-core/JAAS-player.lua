local MODULE, log, dev, SQL = JAAS:RegisterModule "Player"
SQL = SQL"JAAS_player"

if !SQL.EXIST and SERVER then
	SQL.CREATE.TABLE {steamid = "UNSIGNED BIG INT UNIQUE PRIMARY KEY", code = "UNSIGNED BIG INT DEFAULT 0"}
end

local user = {["userIterator"] = true}
local user_local = {["getCode"] = true, ["setCode"] = true, ["xorCode"] = true, ["canTarget"] = true}

local u_cache = dev.Cache()
JAAS.Hook "Player" "GlobalRankChange" ["Player_module_cache"] = function ()
	u_cache()
end

local function add_to_cache(steamid)
	if u_cache[steamid] ~= nil then
		return true
	elseif steamid then
		local a = SQL.SELECT "code" {steamid = steamid}
		if a then
			u_cache[steamid] = tonumber(a["code"])
			return true
		end
	end
	return false
end

local function get_from_cache(steamid)
	if u_cache[steamid] == nil then
		if !add_to_cache(steamid) then
			local ply = player.GetBySteamID64(steamid)
			if ply then
				u_cache[steamid] = 0
				SQL.INSERT {steamid = ply:SteamID64()}
				return 0
			else
				error("Invalid SteamID", 3)
			end
		end
	end
	return u_cache[steamid]
end

if SERVER then
	hook.Add("PlayerInitialSpawn", "JAAS-player-registration", function(ply, transition) -- 914 players at max can be registered
		if !transition and ply:IsPlayer() then
			SQL.INSERT {steamid = ply:SteamID64()}
		end
	end)

	function user_local:getCode()
		return get_from_cache(self.steamid)
	end

	function user_local:setCode(code)
		if SQL.UPDATE {code = code} {steamid = self.steamid} then
			JAAS.Hook.Run "Player" "GlobalRankChange" (self.steamid, self:getCode(), code)
			local player_update = player.GetBySteamID64(self.steamid)
			if player_update then
				net.Start "JAAS_PlayerCodeReturn"
				net.WriteFloat(code)
				net.Send(player_update)
			end
			return true
		end
		return false
	end

	function user_local:xorCode(code)
		if dev.isRankObject(code) then
			code = code:getCode()
		end
		if SQL.UPDATE ("code = (code | " .. code .. ") & (~code | ~" .. code .. ")") {steamid = self.steamid} then
			JAAS.Hook.Run "Player" "GlobalRankChange" (self.steamid, self:getCode(), bit.bxor(self:getCode(), code))
			local player_update = player.GetBySteamID64(self.steamid)
			if player_update then
				net.Start "JAAS_PlayerCodeReturn"
				net.WriteFloat(bit.bxor(self:getCode(), code))
				net.Send(player_update)
			end
			return true
		end
		return false
	end

	MODULE.Handle.Server(function (jaas)
		local rank = jaas.Rank()

		function user_local:canTarget(code)
			if isnumber(code) then
				if self:getCode() > 0 and code > 0 then
					return rank.getMaxPower(self:getCode()) > rank.getMaxPower(code)
				elseif self:getCode() > 0 then
					return rank.getMaxPower(self:getCode()) > 0
				end
			elseif dev.isCommandObject(code) or dev.isPermissionObject(code) or dev.isPlayerObject(code) then
				if self:getCode() > 0 and code:getCode() > 0 then
					return rank.getMaxPower(self:getCode()) > rank.getMaxPower(code:getCode())
				elseif self:getCode() > 0 then
					return rank.getMaxPower(self:getCode()) > 0
				end
			elseif dev.isPlayer(code) then
				if self:getCode() > 0 and code:getJAASCode() > 0 then
					return rank.getMaxPower(self:getCode()) > rank.getMaxPower(code:getJAASCode())
				elseif self:getCode() > 0 then
					return rank.getMaxPower(self:getCode()) > 0
				end
			end
		end
	end)

	function user_local:defaultAccess()
		if self:getCode() == 0 then
			return true
		end
	end

	local meta = FindMetaTable "Player"
	function meta:getJAASObject()
		if not MODULE.ExecutionTrace() then
			return
		end
		if add_to_cache(steamid) then
			return setmetatable({steamid = self:SteamID64()}, {__index = user_local, __newindex = function () end, __metatable = "jaas_player_object"})
		end
	end

	function meta:getJAASCode()
		return get_from_cache(self:SteamID64())
	end

	MODULE.Handle.Server(function (jaas)
		local rank = jaas.Rank()

		function meta:canTarget(code)
			if isnumber(code) then
				if self:getJAASCode() > 0 and code > 0 then
					return rank.getMaxPower(self:getJAASCode()) > rank.getMaxPower(code)
				elseif self:getJAASCode() > 0 then
					return rank.getMaxPower(self:getJAASCode()) > 0
				end
			elseif dev.isCommandObject(code) or dev.isPermissionObject(code) or dev.isPlayerObject(code) then
				if self:getJAASCode() > 0 and code:getCode() > 0 then
					return rank.getMaxPower(self:getJAASCode()) > rank.getMaxPower(code:getCode())
				elseif self:getJAASCode() > 0 then
					return rank.getMaxPower(self:getJAASCode()) > 0
				end
			elseif IsValid(code) then
				if code:IsBot() then
					return rank.getMaxPower(self:getJAASCode()) > 0
				elseif code:IsPlayer() then
					if self:getJAASCode() > 0 and code:getJAASCode() > 0 then
						return rank.getMaxPower(self:getJAASCode()) > rank.getMaxPower(code:getJAASCode())
					elseif self:getJAASCode() > 0 then
						return rank.getMaxPower(self:getJAASCode()) > 0
					end
				end
			end
		end
	end)

	function user.playerIterator(key)
		local a = SQL.SELECT()
		local i = 0
		if key then
			return function ()
				i = 1 + i
				if i <= #a then
					return a[i][key]
				end
			end
		end
		return function ()
			i = 1 + i
			if i <= #a then
				return a[i].steamid, a[i].code
			end
		end
	end

	JAAS.Hook "Rank" "RemovePosition" ["Player_module"] = function (func)
		sql.Begin()
		for steamid, code in user.playerIterator() do
			SQL.UPDATE {code = func(tonumber(code))} {steamid = steamid}
		end
		sql.Commit()
	end

	util.AddNetworkString "JAAS_PlayerCodeReturn"
	net.Receive("JAAS_PlayerCodeReturn", function (len, ply)
		net.Start "JAAS_PlayerCodeReturn"
		net.WriteFloat(ply:getJAASCode() or 0)
		net.Send(ply)
	end)
else -- Client
	local local_RC = 0

	hook.Add("InitPostEntity", "JAAS_InitialCodePull", function ()
		net.Start "JAAS_PlayerCodeReturn"
		net.SendToServer()
	end)

	net.Receive("JAAS_PlayerCodeReturn", function (len)
		local_RC = net.ReadFloat()
	end)

	local saved_codes = {}

	net.Receive("JAAS_ViewPlayerInfo", function ()
		local target = net.ReadEntity()
		saved_codes[target:Nick()](net.ReadFloat())
	end)

	user = {
		GetLocalCode = function ()
			return local_RC
		end,
		GetCode = function (ply, func)
			if IsValid(ply) and ply:IsPlayer() then
				net.Start"JAAS_ViewPlayerInfo"
				net.WriteEntity(ply)
				net.SendToServer()
				saved_codes[ply:Nick()] = func
			end
		end
	}
end

MODULE.Access(function (steamid)
	if dev.isPlayer(steamid) then
		steamid = steamid:SteamID64()
	end
	if SERVER and add_to_cache(steamid) then
		return setmetatable({steamid = steamid}, {__index = user_local, __newindex = function () end, __metatable = "jaas_player_object"})
	else
		return setmetatable({}, {__index = user, __newindex = function () end, __metatable = "jaas_player_library"})
	end
end)

dev:isTypeFunc("PlayerObject","jaas_player_object")
dev:isTypeFunc("PlayerLibrary","jaas_player_library")

log:registerLog {1, "was", 6, "added", "to", 2, "by", 1} -- [1] secret_survivor was added to Donator by secret_survivor
log:registerLog {1, "was", 6, "removed", "from", 2, "by", 1} -- [2] Dempsy40 was removed from T-Mod by secret_survivor
log:registerLog {1, "has", 6, "default access", "by", 1} -- [3] Dempsy40 has default access by secret_survivor
log:registerLog {1, 6, "attempted", "to add/remove a player to", 2} -- [4] Dempsy40 attempted to add/remove a player to Superadmin
MODULE.Handle.Server(function (jaas)
	local modify_player = jaas.Permission().registerPermission("Can Modify Player", "Player will be able to modify what ranks players are in")
	util.AddNetworkString("JAAS_PlayerModify_Channel")
    /* Player feedback codes :: 2 Bits
        0 :: Player Change was a success
        1 :: Player could not be changed
        2 :: Unknown Rank identifier
        3 :: Not part of Access Group
    */
	local sendFeedback = dev.sendUInt("JAAS_PlayerModify_Channel", 2)
	net.Receive("JAAS_PlayerModify_Channel", function (len, ply)
		if modify_player:codeCheck(ply:getJAASCode()) then
			local rank = jaas.Rank(net.ReadString())
			local entity = net.ReadEntity()
			local target = jaas.Player(entity)
			local sendCode = sendFeedback(ply)
			if dev.isRankObject(rank) then
				if rank:accessCheck(ply) then
					if target:xorCode(rank) then
						sendCode(0)
						if target:getCode() == 0 then -- Default Access
							log:Log(3, {player = {entity, ply}})
							log:adminChat("%p made %p a default user", ply:Nick(), entity:Nick())
						elseif bit.band(target:getCode(), rank:getCode()) > 0 then -- Added
							log:Log(1, {player = {entity, ply}, rank = {rank}})
							log:adminChat("%p added %p to %r", ply:Nick(), entity:Nick(), rank:getName())
						else -- Removed
							log:Log(2, {player = {entity, ply}, rank = {rank}})
							log:adminChat("%p removed %p from %r", ply:Nick(), entity:Nick(), rank:getName())
						end
					else
						sendCode(1)
					end
				else
					sendCode(3)
				end
			else
				sendCode(2)
			end
		else
			local rank = jaas.Rank(net.ReadString())
			if dev.isRankObject(rank) then
				log:Log(4, {player = {ply}, rank = {rank:getName()}})
				log:superadminChat("%p attempted to add/remove a player to %r", ply:Nick(), rank:getName())
			end
		end
	end)

	util.AddNetworkString "JAAS_PlayerView_Channel"
	net.Receive("JAAS_PlayerView_Channel", function (len, ply) -- If developers want this to have its own Permission, just ask!
		if modify_player:codeCheck(ply:getJAASCode()) then
			local r = {}
			for steamid,code in user.playerIterator() do
				r[1 +#r] = {steamid, code}
			end
			net.Start "JAAS_PlayerView_Channel"
			net.WriteTable(r)
			net.Send(ply)
		end
	end)

	util.AddNetworkString"JAAS_ViewPlayerInfo"
	net.Receive("JAAS_ViewPlayerInfo", function (_, ply)
		if modify_player:codeCheck(ply:getJAASCode()) then
			local target = net.ReadEntity()
			local object = jaas.Player(target)
			if dev.isPlayerObject(object) and IsValid(target) and target:IsPlayer() then
				net.Start"JAAS_ViewPlayerInfo"
				net.WriteEntity(target)
				net.WriteFloat(object:getCode() or 0)
				net.Send(ply)
			end
		end
	end)

	util.AddNetworkString"JAAS_PlayerClientUpdate"
	JAAS.Hook "Player" "GlobalRankChange" ["PlayerClientUpdate"] = function (steamid, old, new)
		local target = player.GetBySteamID64(steamid)
		if IsValid(target) then
			for k,ply in ipairs(player.GetAll()) do
				if modify_player:codeCheck(ply:getJAASCode()) then
					net.Start"JAAS_PlayerClientUpdate"
					net.WriteEntity(target)
					net.WriteFloat(new)
					net.Send(ply)
				end
			end
		end
	end
end)

MODULE.Handle.Server(function (jaas)
	local command = jaas.Command()
	local arg = command.argumentTableBuilder()

	command:setCategory "User"

	local ModifyUser_ArgTable = arg:add("Rank", "RANK", true):add("Target", "PLAYER"):dispense()
	command:registerCommand("Add", function (ply, rank_object, target)
		if IsValid(target) and target:IsPlayer() then -- Apply rank change on target
			local target_object = target:getJAASObject()
			if !IsValid(ply) or ply == target or ply:validPowerTarget(target:getJAASCode()) then
				if !IsValid(ply) or rank_object:accessCheck(ply:getJAASCode()) then
					if rank_object:codeCheck(target:getJAASCode()) then
						target_object:xorCode(rank_object)
						log:Log(1, {player = {target, ply}, rank = rank_object})
						log:adminChat("%p added %p to %r", ply:Nick(), target:Nick(), rank_object:getName())
					else
						return target:Nick().." already has that rank"
					end
				else
					return "Cannot add target to " .. rank_object:getName()
				end
			else
				return "Cannot Target "..target:Nick()
			end
		else
			if IsValid(ply) then -- Apply rank change on caller
				local user = JAAS.Player(ply)
				if rank_object:accessCheck(user) then
					if rank_object:codeCheck(ply:getJAASCode()) then
						user:xorCode(rank_object)
						log:Log(1, {player = {ply, ply}, rank = rank_object})
						log:adminChat("%p added %p to %r", ply:Nick(), ply:Nick(), rank_object:getName())
					else
						return "You already have this rank"
					end
				else
					return "Cannot add yourself to " .. rank_object:getName()
				end
			else
				return "Target must be valid to change rank" -- Can't change server's rank
			end
		end
	end, ModifyUser_ArgTable, "Player will be able to add another to a rank within their Access Group")

	command:registerCommand("Remove", function (ply, rank_object, target)
		if dev.isPlayer(target) then -- Apply rank change on target
			local target_object = target:getJAASObject()
			if !IsValid(ply) or ply == target or ply:validPowerTarget(target:getJAASCode()) then
				if !IsValid(ply) or rank_object:accessCheck(ply:getJAASCode()) then
					if rank_object:codeCheck(target:getJAASCode()) then
						target_object:xorCode(rank_object)
						log:Log(2, {player = {target, ply}, rank = {rank_object}})
						log:adminChat("%p removed %p from %r", ply:Nick(), target:Nick(), rank_object:getName())
					else
						return target:Nick().." already does not have rank"
					end
				else
					return "Cannot remove target from "..rank_object:getName()
				end
			else
				return "Cannot Target "..target:Nick()
			end
		else
			if IsValid(ply) then -- Apply rank change on caller
				local user = JAAS.Player(ply)
				if rank_object:accessCheck(user) then
					if rank_object:codeCheck(ply:getJAASCode()) then
						user:xorCode(rank_object)
						log:Log(2, {player = {ply, ply}, rank = {rank_object}})
						log:adminChat("%p removed %p from %r", ply:Nick(), ply:Nick(), rank_object:getName())
					else
						return "You already have this rank"
					end
				else
					return "Cannot remove yourself from " .. rank_object:getName()
				end
			else
				return "Target must be valid to change rank" -- Can't change server's rank
			end
		end
	end, ModifyUser_ArgTable, "Player will be able to remove another from a rank within their Access Group")
end)

log:print "Module Loaded"