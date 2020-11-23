local dev = JAAS.Dev()
local log = JAAS.Log("Player")
if !sql.TableExists("JAAS_player") and SERVER then
	dev.fQuery("CREATE TABLE JAAS_player(steamid TEXT NOT NULL UNIQUE, code UNSIGNED BIG INT DEFAULT 0)")
	dev.fQuery("CREATE INDEX JAAS_player_steamid ON JAAS_player (steamid)")
end

gameevent.Listen("player_connect")
hook.Add("player_connect", "JAAS-player-registration", function(data) -- To be logged
	if data.bot == 0 then
		dev.fQuery("INSERT INTO JAAS_player(steamid) VALUES ('%s') WHERE NOT (SELECT * FROM JAAS_player WHERE steamid='%s)'", data.networkid, data.networkid)
	end
end)

local user = {["userIterator"] = true}
local user_local = {["getCode"] = true, ["setCode"] = true}

local u_cache = {}
local u_cache_dirty = true

JAAS.hook.add "Player" "GlobalRankChange" "Player_module_cache" (function()
	u_cache_dirty = true
end)

local add_to_cache = function(steamid)
	if steamid then
		local a = dev.fQuery("SELECT code FROM JAAS_player WHERE steamid='%s'", steamid)
		if a then
			u_cache[steamid] = a[1]["code"]
			return true
		end
	end
end

function user_local:getCode()
	return u_cache[self.steamid]
end

function user_local:setCode(code)
	local a = dev.fQuery("UPDATE JAAS_player SET code=%u WHERE steamid='%s'", code, self.steamid)
	if a then
		JAAS.Hook.Run "Player" "GlobalRankChange" ()
		return a
	end
end

function user_local:xorCode(code)
	local current_code = dev.fQuery("SELECT code FROM JAAS_player WHERE steamid='%s'", self.steamid)
	if current_code then
		current_code = current_code[1]["code"]
		local xor_code = bit.bxor(current_code, code)
		local a = dev.fQuery("UPDATE JAAS_player SET code=%u WHERE steamid='%s'", xor_code, self.steamid)
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
	local a = dev.fQuery("SELECT * FROM JAAS_player")
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
		dev.fQuery("UPDATE JAAS_player SET code=%u WHERE steamid='%s'", func(tonumber(code)), steamid)
	end
	sql.Commit()
end)

JAAS.Player = setmetatable({}, {
	__call = function(self, steamid)
		local f_str, id = log:executionTraceLog("Player")
		if f_str and !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
			return log:removeTraceLog(id)
		end
		if u_cache_dirty then
			u_cache = {}
			u_cache_dirty = true
		end
		if !isstring(steamid) and IsValid(steamid) then
			steamid = steamid:SteamID()
		end
		if add_to_cache(steamid) then
			return setmetatable({steamid = steamid}, {__index = user_local, __newindex = function () end, __metatable = "jaas_player_object"})
		else
			return setmetatable({}, {__index = user, __newindex = function () end, __metatable = "jaas_player_library"})
		end
	end,
	__newindex = function () end,
	__metatable = nil
})

local meta = FindMetaTable("Player")
function meta:getJAASObject()
	local f_str, id = log:executionTraceLog("Player")
	if f_str and !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
		return log:removeTraceLog(id)
	end
	if add_to_cache(steamid) then
		return setmetatable({steamid = self:SteamID()}, {__index = user_local, __newindex = function () end, __metatable = "jaas_player_object"})
	end
end

function meta:getJAASCode()
	if add_to_cache(steamid) then
		return u_cache[self.SteamID()]
	end
end

log:printLog "Module Loaded"