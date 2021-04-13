local function ThreadEx(func, ...)
	coroutine.resume(coroutine.create(func), ...)
end

local function ExFunction(preFunc, postFunc)
	return function (...)
		return postFunc(preFunc(...))
	end
end

if CLIENT then
	function util.AddNetworkString(str)
	end
end

local writeType = {
	[TYPE_STRING] = function (v)
		return net.WriteString(v)
	end,
	[TYPE_NUMBER] = function (v)
		return net.WriteDouble(v)
	end,
	[TYPE_TABLE] = function (v)
		return net.WriteTable(v)
	end,
	[TYPE_BOOL] = function (v)
		return net.WriteBool(v)
	end,
	[TYPE_ENTITY] = function (v)
		return net.WriteEntity(v)
	end,
	[TYPE_VECTOR] = function (v)
		return net.WriteVector(v)
	end,
	[TYPE_ANGLE] = function (v)
		return net.WriteAngle(v)
	end,
	[TYPE_MATRIX] = function (v)
		return net.WriteMatrix(v)
	end,
	[TYPE_COLOR] = function (v)
		return net.WriteColor(v)
	end
}

local function ExNET(object_structure)
	/*
		{
			TYPE_STRING, or name = TYPE_STRING
			TYPE_NUMBER -- code
		}
	*/
	return function (netString)
		local function writeLoop(...)
			local args = {...}
			net.Start(netString)
			for k,v in ipairs(args) do
				writeType[v](args[k])
			end
		end
		return setmetatable({}, {
			__index = {
				Send = function (ply, ...)
					writeLoop(...)
					if CLIENT then
						net.SendToServer()
					else
						net.Send(ply)
					end
				end,
				Broadcast = function (...)
					writeLoop(...)
					if CLIENT then
						net.SendToServer()
					else
						net.Broadcast()
					end
				end,
				SendOmit = function (ply, ...)
					writeLoop(...)
					if CLIENT then
						net.SendToServer()
					else
						net.SendOmit(ply)
					end
				end,
				SendPAS = function (position, ...)
					writeLoop(...)
					if CLIENT then
						net.SendToServer()
					else
						net.SendPAS(position)
					end
				end,
				SendPVS = function (position, ...)
					writeLoop(...)
					if CLIENT then
						net.SendToServer()
					else
						net.SendPVS(position)
					end
				end
			}
			__call = function (ply, ...)
				writeLoop(...)
				if CLIENT then
					net.SendToServer()
				else
					net.Send(ply)
				end
			end
		})
	end,
	function (netString, func) -- Receive
		net.Receive(netString, function (len, ply)
			local object_arguments = {}
			for k,v in pairs(object_structure) do
				object_arguments[k] = net.ReadVars[v]()
			end
			func(len, ply, object_arguments)
		end)
	end
end

local function SharedTable(tableName, t)
	local local_table = t or {}
	if CLIENT then
		net.Receive(tableName.."::sync", function ()
			local index = net.ReadTable()
			if #index > 1 then
				local modifiedTable = local_table
				for i=1, #index - 1 do
					modifiedTable = modifiedTable[index[i]]
				end
				modifiedTable[index[#index]] = net.ReadTable()
			elseif #index == 1 then
				local_table[index[1]] = net.ReadTable()[1]
			end
		end)
		return setmetatable({}, {__index = local_table})
	else
		return setmetatable({}, {
			__index = function (self, k)
				local v = local_table[k]
				if istable(v) and #v > 0 then
					local index = {k}
					local modifiedTable = local_table
					local function index_func(self, k)
						v = local_table[k]
						modifiedTable = modifiedTable[k]
						if istable(v) and #v > 0 then
							index[1 + #index] = k
							return setmetatable({}, {
								__index = index_func,
								__newindex = function ()
									index[1 + #index] = k
									modifiedTable[k] = v
									net.Start(tableName.."::sync")
									net.WriteTable(index)
									net.WriteTable({v})
									net.SendOmit({})
								end
							})
						elseif v then
							return v
						end
					end
					return setmetatable({}, {
						__index = index_func,
						__newindex = function (self, k, v)
							index[1 + #index] = k
							modifiedTable[k] = v
							net.Start(tableName.."::sync")
							net.WriteTable(index)
							net.WriteTable({v})
							net.SendOmit({})
						end
					})
				elseif v then
					return v
				end
			end,
			__newindex = function (self, k, v)
				local_table[k] = v
				net.Start(tableName.."::sync")
				net.WriteTable({k})
				net.WriteTable({v})
				net.SendOmit({})
			end
		})
	end
end