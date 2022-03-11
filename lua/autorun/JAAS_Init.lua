_G.JAAS = {}

local i,c = include,AddCSLuaFile

local include = setmetatable({}, {__call = function (self, _)
    if !istable(_) then return i(_) end
    for __,_ in ipairs(_) do
        i(_)
    end
end})

local function AddCSLuaFile(_)
    if !istable(_) then return c(_) end
    for __,_ in ipairs(_) do
        c(_)
    end
end

do -- Include Functions
	function include.Server(_)
		if SERVER then
			include(_)
		end
	end

	function include.Client(_)
		AddCSLuaFile(_)
		if CLIENT then
			include(_)
		end
	end

	function include.Shared(_)
		AddCSLuaFile(_)
		include(_)
	end
end

local hook_func = hook_func or {}

do -- Hook Function
	local function ReadOnlyFunc()
		error("Cannot be modified", 2)
	end

	local function hookNewFunction(table)
		return setmetatable({},{
			__call = function (self, k, v)
				if isfunction(v) then
					table[k] = v
					return true
				end
				return false
			end,
			__index = function (self, v)
				if table[v] ~= nil then
					return table[v]
				end
			end,
			__newindex = function (self, k, v)
				if isfunction(v) then
					table[k] = v
				end
				return false
			end,
			__metatable = "jaas_hook_add"
		})
	end

	JAAS.Hook = setmetatable({
		Permission = function (name) -- JAAS.Hook.Permission name [identifier] = function () end
			if hook_func.permission == nil then
				hook_func.permission = {[name] = {}}
			elseif hook_func.permission[name] == nil then
				hook_func.permission[name] = {}
			end
			return hookNewFunction(hook_func.permission[name])
		end,
		Command = function (category) -- JAAS.Hook.Command category name [identifier] = function () end
			return function (name)
				if hook_func.command == nil then
					hook_func.command = {[category] = {[name] = {}}}
				elseif hook_func.command[category] == nil then
					hook_func.command[category] = {[name] = {}}
				elseif hook_func.command[category][name] == nil then
					hook_func.command[category][name] = {}
				end
				return hookNewFunction(hook_func.command[category][name])
			end
		end,
		GlobalVar = function (category) -- JAAS.Hook.GlobalVar category name [identifier] = function () end
			return function (name)
				if hook_func.globalvar == nil then
					hook_func.globalvar = {[category] = {[name] = {}}}
				elseif hook_func.globalvar[category] == nil then
					hook_func.globalvar[category] = {[name] = {}}
				elseif hook_func.globalvar[category][name] == nil then
					hook_func.globalvar[category][name] = {}
				end
				return hookNewFunction(hook_func.globalvar[category][name])
			end
		end,
		Run = setmetatable({
			Permission = function (name) -- JAAS.Hook.Run.Permission name (...)
				return function (...)
					local varArgs = {...}
					if hook_func.permission != nil and hook_func.permission[name] != nil then
						local err,message = coroutine.resume(coroutine.create(function ()
							for _,v in pairs(hook_func.permission[name]) do
								v(unpack(varArgs))
							end
						end))
						if !err then
							ErrorNoHalt(message)
						end
					end
				end
			end,
			Command = function (category) -- JAAS.Hook.Run.Command category name (...)
				return function (name)
					return function (...)
						local varArgs = {...}
						if hook_func.command != nil and hook_func.command[category] != nil and hook_func.command[category][name] != nil then
							local err,message = coroutine.resume(coroutine.create(function ()
								for _,v in pairs(hook_func.command[category][name]) do
									v(unpack(varArgs))
								end
							end))
							if !err then
								ErrorNoHalt(message)
							end
						end
					end
				end
			end,
			GlobalVar = function (category) -- JAAS.Hook.Run.GlobalVar category name (...)
				return function (name)
					return function (...)
						local varArgs = {...}
						if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil then
							local err,message = coroutine.resume(coroutine.create(function ()
								for _,v in pairs(hook_func.other[category][name]) do
									v(unpack(varArgs))
								end
							end))
							if !err then
								ErrorNoHalt(message)
							end
						end
					end
				end
			end
		}, {__call = function (self, category) -- JAAS.Hook.Run category name (...)
			return function (name, final)
				return function (...)
					local varArgs = {...}
					if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil then
						local err,message = coroutine.resume(coroutine.create(function ()
							for _,v in pairs(hook_func.other[category][name]) do
								v(unpack(varArgs))
							end
							if final != nil then
								final()
							end
						end))
						if !err then
							ErrorNoHalt(message)
						end
					end
				end
			end
		end, __newindex = ReadOnlyFunc, __metatable = "jaas_hook_run"}),
		Remove = setmetatable({
			Permission = function (name) -- JAAS.Hook.Remove.Permission name identifier
				return function (identifier)
					if hook_func.permission != nil and hook_func.permission[name] != nil and hook_func.permission[name][identifier] != nil then
						local r = hook_func.permission[name][identifier]
						hook_func.permission[name][identifier]
						return r
					end
				end
			end,
			Command = function (category) -- JAAS.Hook.Remove.Command category name identifier
				return function (name)
					return function (identifier)
						if hook_func.command != nil and hook_func.command[category] != nil and hook_func.command[category][name] != nil and hook_func.command[category][name][identifier] != nil then
							local r = hook_func.command[category][name][identifier]
							hook_func.command[category][name][identifier]
							return r
						end
					end
				end
			end,
			GlobalVar = function (category) -- JAAS.Hook.Remove.GlobalVar category name identifier
				return function (name)
					return function (identifier)
						if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil and hook_func.other[category][name][identifier] != nil then
							local r = hook_func.other[category][name][identifier]
							hook_func.other[category][name][identifier] = nil
							return r
						end
					end
				end
			end
		}, {__call = function (self, category) -- JAAS.Hook.Remove category name identifier
			return function (name)
				return function (identifier)
					if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil and hook_func.other[category][name][identifier] != nil then
						local r = hook_func.other[category][name][identifier]
						hook_func.other[category][name][identifier] = nil
						return r
					end
				end
			end
		end, __newindex = ReadOnlyFunc, __metatable = "jaas_hook_remove"})
	}, {__call = function (self, category) -- JAAS.Hook category name [identifier] = function () end
		return function (name)
			if hook_func.other == nil then
				hook_func.other = {[category] = {[name] = {}}}
			elseif hook_func.other[category] == nil then
				hook_func.other[category] = {[name] = {}}
			elseif hook_func.other[category][name] == nil then
				hook_func.other[category][name] = {}
			end
			return hookNewFunction(hook_func.other[category][name])
		end
	end, __newindex = ReadOnlyFunc, __metatable = "jaas_hook"})

	local globalvar_table = {}
	JAAS.GlobalVar = setmetatable({
		Set = function (category) -- JAAS.GlobalVar.Set category name (var)
			return function (name)
				return function (var)
					local before
					if globalvar_table[category] == nil then
						globalvar_table[category] = {[name] = var}
					else
						before = globalvar_table[category][name]
						globalvar_table[category][name] = var
					end
					JAAS.Hook.Run.GlobalVar(category)(name)(before, var)
					return var
				end
			end
		end,
		Get = function (category) -- JAAS.GlobalVar.Get category name
			return function (name)
				if globalvar_table[category] != nil then
					return globalvar_table[category][name]
				end
			end
		end
	}, {__newindex = ReadOnlyFunc, __metatable = "jaas_globalvar"})
end

include.Shared {
	"jaas-core/JAAS_Base.lua",
	"jaas-core/JAAS_Rank.lua",
	"jaas-core/JAAS_Permission.lua",
	"jaas-core/JAAS_Command.lua",
	"jaas-core/JAAS_AccessGroup.lua",
	"jaas-core/JAAS_GUI.lua",
	"jaas-core/JAAS_Player.lua"
}

JAAS:ExecuteModulesPost()