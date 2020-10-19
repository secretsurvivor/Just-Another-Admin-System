if !sql.TableExists("JAAS_user") then
	fQuery("CREATE TABLE JAAS_user(steamid TEXT NOT NULL, code UNSIGNED BIG INT DEFAULT 0, PRIMARY KEY (steamid))")
end

gameevent.Listen("player_connect")
hook.Add("player_connect", "JAAS-player-registration", function(data) -- To be logged
	if data.bot == 0 then
		local a = fQuery("SELECT * FROM JAAS_user WHERE steamid='%s'", data.networkid) -- Could all be changed into a single SQL query
		if not a then
			fQuery("INSERT INTO JAAS_user(steamid) VALUES ('%s')", data.networkid)
		end
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
	if istable(a) then
		u_cache[steamid] = a[1]["code"]
		return true
	end
end

local exist_on_cache = function(steamid)
	local test, err = pcall(function(steamid) local u = u_cache[steamid] end, steamid)
	return not(err and true)
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
	if istable(current_code) then
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
		return function next()
			i += 1
			if i < #a then
				return a[i][key]
			end
		end
	else
		return function next()
			i += 1
			if i < #a then
				return a[i]["steamid"], a[i]["code"]
			end
		end
	end
end

setmetatable(user, {
	__index = function() end,
	__newindex = function() end,
	__metatable = nil
})
JAAS.player = {}
setmetatable(JAAS.player, {
	__call = function(self, steamid)
		--ToDo: Add file trace
		if u_cache_dirty then
			u_cache = {}
			u_cache_dirty = true
		end
		if add_to_cache(steamid) then
			local usr = {}
			usr.steamid = steamid
			setmetatable(usr, {__index = user, __newindex = function() end})
			return usr
		end
	end,
	__newindex = function() end,
	__metatable = nil
})

print("JAAS User Module Loaded")