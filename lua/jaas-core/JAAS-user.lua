local fQuery, dataTypeCheck, keyExists = unpack( JAAS.Dev .. (QUERY + TYPECHECK + KEYEXIST) )
if !sql.TableExists("JAAS_user") then
	fQuery("CREATE TABLE JAAS_user(steamid TEXT NOT NULL, code UNSIGNED BIG INT DEFAULT 0, PRIMARY KEY (steamid))")
end

gameevent.Listen("player_connect")
hook.Add("player_connect", "JAAS-player-registration", function(data) -- To be logged
	if data.bot == 0 then
		fQuery("INSERT INTO JAAS_user(steamid) VALUES ('%s') WHERE NOT (SELECT * FROM JAAS_user WHERE steamid='%s)'", data.networkid, data.networkid)
	end
end)

local user = {["getCode"] = true, ["setCode"] = true}

local u_cache = {}
local u_cache_dirty = true

hook.Add("JAAS-userRank-dirty", "JAAS-userObjectCache", function()
	u_cache_dirty = true
end)

local add_to_cache = function(steamid)
	local a = fQuery("SELECT code FROM JAAS_user WHERE steamid='%s'", steamid)
	if a then
		u_cache[steamid] = a[1]["code"]
		return true
	end
end

function user:getCode()
	return u_cache[self.steamid]
end

function user:setCode(code)
	local a = fQuery("UPDATE JAAS_user SET code=%u WHERE steamid='%s'", code, self.steamid)
	if a then
		hook.Run("JAAS-userRank-dirty")
		return a
	end
end

function user:xorCode(code)
	local current_code = fQuery("SELECT code FROM JAAS_user WHERE steamid='%s'", self.steamid)
	if current_code then
		current_code = current_code[1]["code"]
		local xor_code = bit.bxor(current_code, code)
		local a = fQuery("UPDATE JAAS_user SET code=%u WHERE steamid='%s'", xor_code, self.steamid)
		if a then
			hook.Run("JAAS-userRank-dirty")
			return a
		end
	end
end

function user.userIterator(key)
	local a = fQuery("SELECT * FROM JAAS_user")
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

setmetatable(user, {
	__index = function () end,
	__newindex = function () end,
	__metatable = nil
})
JAAS.player = setmetatable({}, {
	__call = function(self, steamid)
		--ToDo: Add file trace
		if u_cache_dirty then
			u_cache = {}
			u_cache_dirty = true
		end
		if add_to_cache(steamid) then
			return setmetatable({steamid = steamid}, {__index = user, __newindex = function() end})
		end
	end,
	__newindex = function () end,
	__metatable = nil
})

print "JAAS User Module - Loaded" 