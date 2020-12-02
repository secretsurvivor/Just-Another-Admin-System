local query, format, type = sql.Query, string.format, type
local ipairs, gmatch, net = ipairs, string.gmatch, net
local log = JAAS.Log("Developer")
local dev = {["fQuery"] = true, ["verifyFilepath"] = true, ["verifyFilepath_table"] = true, ["sharedSync"] = true, ["mergeSort"] = true}

function dev.fQuery(s, ...)
	if {...} == nil then
		return query(s)
	end
	return query(format(s, ...))
end

function dev.verifyFilepath(filepath, verify_str)
	-- Verify String example: addons/*/lua/jaas/*
	if filepath and verify_str then
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
					count = 1 + count
				end
				if count == (#verify_str) + 1 then
					verified = true
				end
			else
				if f_c == v_c then
				elseif v_c == "*" then
					wild_card = true
				else
					incorrect = true
				end
				v_c = verify_func()
				count = 1 + count
			end
			f_c = filepath_func()
			if f_c == nil then
				incorrect = true
			end
		end
		return verified
	end
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

if SERVER then
	function dev.sharedSync(networkString, server_func)
		util.AddNetworkString(networkString)
		local receive_func = function (_, ply)
			local table_ = server_func(_, ply)
			if table_ then
				net.Start(networkString)
				net.WriteTable(table_)
				net.Send(ply)
			end
		end
		net.Receive(networkString, receive_func)
		return receive_func
	end
elseif CLIENT then
	function dev.sharedSync(networkString, _, hook_identifier, client_func)
		net.Receive(networkString, function (_, ply)
			client_func(_, ply, net.ReadTable())
		end)
		hook.Add("InitPostEntity", hook_identifier, function ()
			net.Start(networkString)
			net.SendToServer()
		end)
	end
end

function dev.mergeSort(table) -- Acc
	local function sort(table, lower, upper)
		if lower < upper then
			local mid = math.ceil((lower + upper)/2)
			sort(table, lower, mid)
			sort(table, mid + 1, upper)
			do
				local sub1_l, sub2_l = mid - lower + 1, upper - mid
				local left, right = {}, {}
				for i=1, sub1_l do
					left[i] = table[lower + i]
				end
				for i=0, sub2_l do
					right[i] = table[1 + mid + i]
				end
				local i,j,k = 0,0,l
				while(i < sub1_l && j < sub2_l) do
					if left[i] <= right[j] then
						table[k] = left[i]
						i = 1 + i
					else
						table[k] = right[j]
						j = 1 + j
					end
				end
				while i < sub1_l do
					table[k] = left[i]
					i = 1 + i
					k = 1 + k
				end
				while j < sub2_l do
					table[k] = right[j]
					j = 1 + j
					k = 1 + k
				end
			end
		end
	end
	return sort(table, 1, (#table) - 1)
end

function dev.quickSort()

end

function dev.isRankObject(var) return getmetatable(var) == "jaas_rank_object" end
function dev.isPermissionObject(var) return getmetatable(var) == "jaas_permission_object" end
function dev.isCommandObject(var) return getmetatable(var) == "jaas_command_object" end
function dev.isPlayerObject(var) return getmetatable(var) == "jaas_player_object" end
function dev.isRankLibrary(var) return getmetatable(var) == "jaas_rank_library" end
function dev.isCommandLibrary(var) return getmetatable(var) == "jaas_command_library" end
function dev.isPermissionLibrary(var) return getmetatable(var) == "jaas_permission_library" end
function dev.isPlayerLibrary(var) return getmetatable(var) == "jaas_player_library" end
function dev.isLogLibrary(var) return getmetatable(var) == "jaas_log_library" end
function dev.isDevLibrary(var) return getmetatable(var) == "jaas_developer_library" end

function JAAS.Dev()
	local f_str, id = log:executionTraceLog()
	if f_str and !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
		return log:removeTraceLog(id)
	end
	return setmetatable({}, {
		__index = dev,
		__newindex = function () end,
		__metatable = "jaas_developer_library"
	})
end

log:printLog "Module Loaded"