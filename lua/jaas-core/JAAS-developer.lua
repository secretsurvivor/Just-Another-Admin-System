local query, format, type = sql.Query, string.format, type
local ipairs, gmatch, net = ipairs, string.gmatch, net
local log = JAAS.Log("Developer")
local dev = {}

function dev.fQuery(s, ...)
	return query(format(s, ...))
end

function dev.verifyFilepath(filepath, verify_str)
	-- Verify String example: addons/*/lua/jaas/*
	local filepath_func = gmatch(filepath, ".")
	local verify_func = gmatch(verify_str, ".")
	local count = 0
	local wild_card,verified,incorrect = false, false, false
	local f_c, v_c = filepath_func(), verify_func()
	while !verified and !incorrect do
		if wild_card then
			if v_c == "*" then
				v_c = verify_func()
				count = 1 + count
			end
			if v_c == nil then
				verified = true
			end
			if f_c == "/" then
				wild_card = false
				v_c = verify_func()
			end
			if count == (#verify_str) + 1 then
				verified = true
			end
			f_c = filepath_func()
		else
			if f_c == v_c then
			elseif v_c == "*" then
				wild_card = true
			else
				incorrect = true
			end
			f_c = filepath_func()
			v_c = verify_func()
			count = 1 + count
		end
		if f_c == nil then
			incorrect = true
		end
	end
	return verified
end

/*function dev.verifyFilepath2(filepath, verify_pattern)
	if istable(verify_pattern) then
		for _,v in ipairs(verify_pattern)
			if filepath == string.match(filepath, v)
		end
		return false
	else
		return filepath == string.match(filepath, verify_pattern)
	end
end*/

function dev.verifyFilepath_table(filepath, verify_str_table)
	for _, v_str in ipairs(verify_str_table) do
		if verifyFilepath(filepath, v_str) then
			return true
		end
	end
	return false
end

function dev.sharedSync(networkString, server_func, hook_identifier, client_func)
	if SERVER then
		util.AddNetworkString(networkString)
		net.Receive(networkString, server_func)
	elseif CLIENT then
		net.Receive(networkString, client_func)
		hook.Add("InitPostEntity", hook_identifier, function ()
			net.Start(networkString)
        	net.SendToServer()
		end)
	end
end

JAAS.Dev = setmetatable({}, {
	__call = function ()
		local f_str, id = log:executionTraceLog()
		if !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
			log:removeTraceLog(id)
			return
		end
		return setmetatable({}, {
			__index = dev,
			__newindex = function () end,
			__metatable = nil
		})
	end
})

log:printLog "Module Loaded"