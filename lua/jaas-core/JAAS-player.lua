local MODULE, log, dev, SQL = JAAS:RegisterModule "Player"
SQL = SQL"JAAS_player"

if SERVER then
	SQL.CREATE.TABLE {steamid = "TEXT NOT NULL UNIQUE", code = "UNSIGNED BIG INT DEFAULT 0"}
	SQL.CREATE.INDEX "JAAS_player_steamid" "steamid"
end

gameevent.Listen("player_connect")
hook.Add("player_connect", "JAAS-player-registration", function(data) -- To be logged
	if data.bot == 0 then
		SQL.INSERT {steamid = data.networkid}
	end
end)

local user = {["userIterator"] = true}
local user_local = {["getCode"] = true, ["setCode"] = true, ["xorCode"] = true, ["canTarget"] = true}

local u_cache = {}
local u_cache_dirty = true

JAAS.Hook.Add "Player" "GlobalRankChange" "Player_module_cache" (function()
	u_cache_dirty = true
end)

local function add_to_cache(steamid)
	if steamid then
		local a = SQL.SELECT "code" {steamid = steamid}
		if a then
			u_cache[steamid] = a["code"]
			return true
		end
	end
	return false
end

local function get_from_cache(steamid)
	if steamid then
		if u_cache_dirty then
			u_cache = {}
			u_cache_dirty = false
			add_to_cache(steamid)
		end
		if u_cache[steamid] ~= nil then
			if !add_to_cache(steamid) then
				error("SteamID must have been removed from database", 3)
			end
		end
		return u_cache[steamid]
	end
end

function user_local:getCode()
	return get_from_cache(self.steamid)
end

function user_local:setCode(code)
	local a = SQL.UPDATE {code = code} {steamid = self.steamid}
	if a then
		JAAS.Hook.Run "Player" "GlobalRankChange" ()
		return a
	end
end

function user_local:xorCode(code)
	local current_code = SQL.SELECT "code" {steamid = self.steamid}
	if current_code then
		current_code = current_code["code"]
		local xor_code = bit.bxor(current_code, code)
		local a = SQL.UPDATE {code = xor_code} {steamid = self.steamid}
		if a then
			JAAS.Hook.Run "Player" "GlobalRankChange" ()
			return a
		end
	end
end

function user_local:canTarget(code, rank_library)
	if dev.isRankLibrary(rank_library) then
		if isnumber(code) then
			if self:getCode() > 0 and code > 0 then
				return rank_library.getMaxPower(self:getCode()) > rank_library.getMaxPower(code)
			elseif self:getCode() > 0 then
				return rank_library.getMaxPower(self:getCode()) > 0
			end
		elseif dev.isCommandObject(code) or dev.isPermissionObject(code) or dev.isPlayerObject(code) then
			if self:getCode() > 0 and code:getCode() > 0 then
				return rank_library.getMaxPower(self:getCode()) > rank_library.getMaxPower(code:getCode())
			elseif self:getCode() > 0 then
				return rank_library.getMaxPower(self:getCode()) > 0
			end
		end
	end
end

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
			i = i + 1
			if i <= #a then
				return a[i][key]
			end
		end
	end
	return function ()
		i = i + 1
		if i <= #a then
			return a[i]["steamid"], a[i]["code"]
		end
	end
end

JAAS.Hook.Add "Rank" "RemovePosition" "Player_module" (function (func)
	sql.Begin()
	for steamid, code in user.userIterator() do
		SQL.UPDATE {code = func(tonumber(code))} {steamid = steamid}
	end
	sql.Commit()
end)

MODULE.Access(function (steamid)
	if u_cache_dirty then
		u_cache = {}
		u_cache_dirty = false
	end
	if isentity(steamid) and IsValid(steamid) and steamid:IsPlayer() then
		steamid = steamid:SteamID()
	end
	if add_to_cache(steamid) then
		return setmetatable({steamid = steamid}, {__index = user_local, __newindex = function () end, __metatable = "jaas_player_object"})
	else
		return setmetatable({}, {__index = user, __newindex = function () end, __metatable = "jaas_player_library"})
	end
end, true)

local meta = FindMetaTable("Player")
function meta:getJAASObject()
	local f_str, id = log:executionTraceLog()
	if f_str and !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
		return log:removeTraceLog(id)
	end
	if add_to_cache(steamid) then
		return setmetatable({steamid = self:SteamID()}, {__index = user_local, __newindex = function () end, __metatable = "jaas_player_object"})
	end
end

function meta:getJAASCode()
	return get_from_cache(self.SteamID())
end

log:printLog "Module Loaded"