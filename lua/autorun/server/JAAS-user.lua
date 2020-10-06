include("testDev.lua") -- Will be removed
JAAS = {}

if !sql.TableExists("JAAS_user") then
	sql.Query("CREATE TABLE JAAS_user(steamid TEXT NOT NULL, code UNSIGNED BIG INT DEFAULT 0, PRIMARY KEY (steamid))")
end

gameevent.Listen("player_connect")
hook.Add("player_connect", "JAAS-player-registration", function(data) -- To be loggged
	if data.bot == 0 then
		local a = fQuery("SELECT * FROM JAAS_user WHERE steamid='%s'", data.networkid) -- Could all be changed into a single SQL query
		if not a then
			fQuery("INSERT INTO JAAS_user(steamid) VALUES ('%s')", data.networkid)
		end
	end
end)

local user = {["getCode"]=true, ["setCode"]=true}

function user:getCode()
	return fQuery("SELECT code FROM JAAS_user WHERE steamid='%s'", self.steamid)
end

function user:setCode(code)
	return fQuery("UPDATE JAAS_user SET code=%u WHERE steamid='%s'", code, self.steamid)
end

function user:xorCode(code)
	local current_code = fQuery("SELECT code FROM JAAS_user WHERE steamid='%s'", self.steamid)
	return fQuery("UPDATE JAAS_user SET code=%u WHERE steamid='%s'", bit.bxor(current_code, code), self.steamid)
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
		local usr = {}
		usr.steamid = steamid
		setmetatable(usr, {__index = user, __newindex = function() end})
		return usr
	end,
	__newindex = function() end,
	__metatable = nil
})