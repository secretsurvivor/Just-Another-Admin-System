JAAS = {["Command"] = false, ["Rank"] = false, ["Permission"] = false, ["Player"] = false}

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
            t[state][stage][1 + #t[state][stage]] = f
        end
        return true
    else
        ErrorNoHalt("File " .. f .. " does not exist")
    end
end

local jaas_registry = jaas_registry or {}

JAAS.include = setmetatable({}, {
    __index = function (self, state)
        if state == "Client" or state == "Server" or state == "Shared" then
            return setmetatable({}, {
                __index = function (self, stage)
                    if stage == "Pre" or stage == "Init" or stage == "Post" then
                        return function (f)
                            return registerAdd(jaas_registry, state, stage, f)
                        end
                    end
                end
            })
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

local hook_func = hook_func or {}
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
    end, __newindex = function () end, __metatable = "jaas_hook_run"}),
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
    end, __newindex = function () end, __metatable = "jaas_hook_remove"})
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
end, __newindex = function () end, __metatable = "jaas_hook"})

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
}, {__newindex = function () end, __metatable = "jaas_globalvar"})

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
                JAAS:PostInitialise()
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
    stateInclude "Shared"
    if SERVER then
        stateInclude "Server"
    else
        stateInclude "Client"
    end
    if CLIENT and message then
        print "-------------------------------"
    elseif !CLIENT then
        print "-------------------------------"
    end
end

if JAAS_PRE_HOOK then
    JAAS.include.Shared.Init "JAAS/JAAS-PRE.init.lua"
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
    "jaas-core/JAAS-permission.lua",
    "jaas-core/JAAS-access.lua"
}

include.Client "jaas-core/JAAS-panel.lua"

JAAS:PostInitialise()

if CLIENT then print "------------------------------" end

local RefreshClientInclude = JAAS.Dev().SharedSync("JAAS_InitTableSync", function (_, ply)
    local r,count = {},0
    for k,v in ipairs({"Shared", "Client"}) do
        k = jaas_registry[v]
        r[v] = k
        count = #k + count
    end
    if count > 0 then
        return r
    end
end, "JAAS_ClientInit", function (_, ply, table)
    includeLoop(table)
end)

if SERVER then
    includeLoop(jaas_registry)

    concommand.Add("JAAS_RefreshClientFiles", function ()
        for _,ply in ipairs(player.GetAll()) do
            RefreshClientInclude(nil,ply)
        end
    end)
end