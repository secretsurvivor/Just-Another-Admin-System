--if JAAS then return end
JAAS = {["Command"] = false, ["Rank"] = false, ["Permission"] = false, ["Player"] = false}

local include = setmetatable({}, {__call = function (self, _)
    if !istable(_) then include(_) return end
    for __,_ in ipairs(_) do
        include(_)
    end
end})
local AddCSLuaFile = setmetatable({}, {__call = function (self, _)
    if !istable(_) then AddCSLuaFile(_) return end
    for __,_ in ipairs(_) do
        AddCSLuaFile(_)
    end
end})
function include.Server(_) if SERVER then include(_) end end
function include.Client(_) AddCSLuaFile(_) if CLIENT then include(_) end end
function include.Shared(_) AddCSLuaFile(_) include(_) end

local function registerAdd(t, state, stage, f)
    if istable(f) then
        for k,v in ipairs(f) do
            registerAdd(t, state, stage, v)
        end
    elseif file.Exists(f, "LUA") then
        if t[state] == nil then
            t[state] = {[stage] = {f}}
        elseif t[state][stage] == nil then
            t[state][stage] = {f}
        else
            table.insert(t[state][stage], f)
        end
        return true
    else
        error("File " .. f .. " does not exist", 2)
    end
end

JAAS.include = setmetatable({}, {
    __call = function (self, state)
        if state == "Client" or state == "Server" or state == "Shared" then
            return function (stage)
                if stage == "Pre" or stage == "Init" or stage == "Post" then
                    return function (f)
                        return registerAdd(self, state, stage, f)
                    end
                end
            end
        end
    end
})

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

local hook_func = {}
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
                local varArgs = ...
                if hook_func.permission != nil and hook_func.permission[name] != nil then
                    coroutine.resume(coroutine.create(function ()
                        for _,v in pairs(hook_func.permission[name]) do
                            v(varArgs)
                        end
                    end))
                end
            end
        end,
        Command = function (category) -- JAAS.Hook.Run.Command category name (...)
            return function (name)
                return function (...)
                    local varArgs = ...
                    if hook_func.command != nil and hook_func.command[category] != nil and hook_func.command[category][name] != nil then
                        coroutine.resume(coroutine.create(function ()
                            for _,v in pairs(hook_func.command[category][name]) do
                                v(varArgs)
                            end
                        end))
                    end
                end
            end
        end,
        GlobalVar = function (category) -- JAAS.Hook.Run.GlobalVar category name (...)
            return function (name)
                return function (...)
                    local varArgs = ...
                    if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil then
                        coroutine.resume(coroutine.create(function ()
                            for _,v in pairs(hook_func.other[category][name]) do
                                v(varArgs)
                            end
                        end))
                    end
                end
            end
        end
    }, {__call = function (self, category) -- JAAS.Hook.Run category name (...)
        return function (name)
            return function (...)
                local varArgs = ...
                if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil then
                    coroutine.resume(coroutine.create(function ()
                        for _,v in pairs(hook_func.other[category][name]) do
                            v(varArgs)
                        end
                    end))
                end
            end
        end
    end, __newindex = function () end}),
    Remove = setmetatable({
        Permission = function (name) -- JAAS.Hook.Remove.Permission name identifier
            return function (identifier)
                if hook_func.permission != nil and hook_func.permission[name] != nil and hook_func.permission[name][identifier] != nil then
                    local r = hook_func.permission[name][identifier]
                    if #hook_func.permission[name] == 1 then
                        if #hook_func.permission == 1 then
                            hook_func.permission = nil
                        else
                            hook_func.permission[name] = nil
                        end
                    else
                        hook_func.permission[name][identifier] = nil
                    end
                    return r
                end
            end
        end,
        Command = function (category) -- JAAS.Hook.Remove.Command category name identifier
            return function (name)
                return function (identifier)
                    if hook_func.command != nil and hook_func.command[category] != nil and hook_func.command[category][name] != nil and hook_func.command[category][name][identifier] != nil then
                        local r = hook_func.command[category][name][identifier]
                        if #hook_func.command[category][name] == 1 then
                            if #hook_func.command[category] == 1 then
                                if #hook_func.command == 1 then
                                    hook_func.command = nil
                                else
                                    hook_func.command[category] = nil
                                end
                            else
                                hook_func.command[category][name] = nil
                            end
                        else
                            hook_func.command[category][name][identifier] = nil
                        end
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
                        if #hook_func.other[category][name] == 1 then
                            if #hook_func.other[category] == 1 then
                                if #hook_func.other == 1 then
                                    hook_func.other = nil
                                else
                                    hook_func.other[category] = nil
                                end
                            else
                                hook_func.other[category][name] = nil
                            end
                        else
                            hook_func.other[category][name][identifier] = nil
                        end
                        return r
                    end
                end
            end
        end
    }, {__call = function (self, category) -- JAAS.Hook.Remove category name identifier
        return function (name)
            return function (identifier)
                if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil and hook_func.other[category][name][identifier] != nil then
                    if #hook_func.other[category][name] == 1 then
                        if #hook_func.other[category] == 1 then
                            if #hook_func.other == 1 then
                                hook_func.other = nil
                            else
                                hook_func.other[category] = nil
                            end
                        else
                            hook_func.other[category][name] = nil
                        end
                    else
                        hook_func.other[category][name][identifier] = nil
                    end
                end
            end
        end
    end, __newindex = function () end})
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
end, __newindex = function () end})

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
}, {})

local function includeLoop(table_)
    local message = false
    local function stateInclude(state)
        if table_[state] ~= nil then
            if table_[state].Pre ~= nil then
                if !message then print "-------- JAAS Register --------" message = true end
                for k,v in ipairs(table_[state].Pre) do
                    print("  [".. state .."] "..v)
                    include[state](v)
                end
            end
            if table_[state].Init ~= nil then
                if !message then print "-------- JAAS Register --------" message = true end
                for k,v in ipairs(table_[state].Init) do
                    print("  [".. state .."] "..v)
                    include[state](v)
                end
            end
            if table_[state].Post ~= nil then
                if !message then print "-------- JAAS Register --------" message = true end
                for k,v in ipairs(table_[state].Post) do
                    print("  [".. state .."] "..v)
                    include[state](v)
                end
            end
        end
    end
    stateInclude("Shared")
    if SERVER then
        stateInclude("Server")
    else
        stateInclude("Client")
    end
    if CLIENT and message then
        print "-------------------------------"
    elseif !CLIENT then
        print "-------------------------------"
    end
end

for _, file_ in ipairs(file.Find("jaas/autorun/*.lua", "lsv")) do
    include.Server("jaas/autorun/"..file_)
end

print "-------- JAAS Modules --------"

include.Shared {
    "JAAS_variables.lua",
    "jaas-core/JAAS-module.lua",
    "jaas-core/JAAS-command.lua"
}

include.Server {
    "jaas-core/JAAS-player.lua",
    "jaas-core/JAAS-rank.lua",
    "jaas-core/JAAS-permission.lua"
}

include.Client "jaas-core/JAAS-panel.lua"

JAAS:PostInitialise()

if CLIENT then print "------------------------------" end

local dev = JAAS.Dev()
local RefreshClientInclude = dev.sharedSync("JAAS_InitTableSync", function (_, ply)
    local includeTable, count = {}, 0
    for state,stage in pairs(JAAS.include) do
        includeTable[state] = stage
    end
    if count > 0 then
        return includeTable
    end
end, "JAAS_ClientInit", function (_, ply, table)
    includeLoop(table)
end)

if SERVER then
    includeLoop(JAAS.include)

    concommand.Add("JAAS_RefreshClientFiles", function ()
        for _,ply in ipairs(player.GetAll()) do
            RefreshClientInclude(nil,ply)
        end
    end)
end