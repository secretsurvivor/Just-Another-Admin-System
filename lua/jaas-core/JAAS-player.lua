local MODULE, log, dev, SQL = JAAS:RegisterModule "Player"
SQL = SQL"JAAS_player"

if !SQL.EXIST and SERVER then
	SQL.CREATE.TABLE {steamid = "UNSIGNED BIG INT UNIQUE PRIMARY KEY", code = "UNSIGNED BIG INT DEFAULT 0"}
end

hook.Add("PlayerInitialSpawn", "JAAS-player-registration", function(ply, transition) -- To be logged
	if !transition then
		SQL.INSERT {steamid = ply:SteamID64()}
	end
end)

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
			u_cache[steamid] = a["code"]
			return true
		end
	end
	return false
end

local function get_from_cache(steamid)
	if u_cache[steamid] ~= nil then
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

function user_local:getCode()
	return get_from_cache(self.steamid)
end

function user_local:setCode(code)
	if SQL.UPDATE {code = code} {steamid = self.steamid} then
		JAAS.Hook.Run "Player" "GlobalRankChange" (self:getCode(), code)
		return true
	end
	return false
end

function user_local:xorCode(code)
	if dev.isRankObject(code) then
		code = code:getCode()
	end
	if SQL.UPDATE ("code = (code | " .. code .. ") & (~code | ~" .. code .. ")") {steamid = self.steamid} then
		JAAS.Hook.Run "Player" "GlobalRankChange" (self:getCode(), bit.bxor(self:getCode(), code))
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
			return a[i]["steamid"], a[i]["code"]
		end
	end
end

JAAS.Hook "Rank" "RemovePosition" ["Player_module"] = function (func)
	sql.Begin()
	for steamid, code in user.userIterator() do
		SQL.UPDATE {code = func(tonumber(code))} {steamid = steamid}
	end
	sql.Commit()
end

MODULE.Access(function (steamid)
	if dev.isPlayer(steamid) then
		steamid = steamid:SteamID64()
	end
	if add_to_cache(steamid) then
		return setmetatable({steamid = steamid}, {__index = user_local, __newindex = function () end, __metatable = "jaas_player_object"})
	else
		return setmetatable({}, {__index = user, __newindex = function () end, __metatable = "jaas_player_library"})
	end
end)

dev:isTypeFunc("PlayerObject","jaas_player_object")
dev:isTypeFunc("PlayerLibrary","jaas_player_library")

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
		if dev.isRankLibrary(rank) then
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
			elseif dev.isPlayer(code) then
				if self:getJAASCode() > 0 and code:getJAASCode() > 0 then
					return rank.getMaxPower(self:getJAASCode()) > rank.getMaxPower(code:getJAASCode())
				elseif self:getJAASCode() > 0 then
					return rank.getMaxPower(self:getJAASCode()) > 0
				end
			end
		end
	end
end)

log:print "Module Loaded"