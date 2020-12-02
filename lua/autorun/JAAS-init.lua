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
function include.server(_) if SERVER then include(_) end end
function include.client(_) AddCSLuaFile(_) if CLIENT then include(_) end end
function include.shared(_) AddCSLuaFile(_) include(_) end

local stageMeta = {__call = function (self, _) rawset(self, #self + 1, _) end, __index = function () end, __newindex = function () end, __metatable = "JAAS_include_stage"}
JAAS.include = setmetatable({
    shared = setmetatable({
        pre = setmetatable({}, stageMeta),
        init = setmetatable({}, stageMeta),
        post = setmetatable({}, stageMeta)
    }, {__call = function (self, _) self.init(_) end, __metatable = "JAAS_include_state_shared"}),
    server = setmetatable({
        pre = setmetatable({}, stageMeta),
        init = setmetatable({}, stageMeta),
        post = setmetatable({}, stageMeta)
    }, {__call = function (self, _) self.init(_) end, __metatable = "JAAS_include_state_server"}),
    client = setmetatable({
        pre = setmetatable({}, stageMeta),
        init = setmetatable({}, stageMeta),
        post = setmetatable({}, stageMeta)
    }, {__call = function (self, _) self.init(_) end, __metatable = "JAAS_include_state_client"}),
}, {__call = function (self, _) self.shared.init(_) end, __metatable = "JAAS_include_table"})

local hook_func = {}
JAAS.Hook = setmetatable({
    Add = setmetatable({
        Permission = function (name) -- JAAS.Hook.Add ["Permission"] name identifier (function () end)
            return function (identifier)
                return function (func)
                    if isfunction(func) then
                        if hook_func.permission == nil then
                            hook_func.permission = {[name] = {[identifier] = func}}
                        elseif hook_func.permission[name] == nil then
                            hook_func.permission[name] = {[identifier] = func}
                        else
                            hook_func.permission[name][identifier] = func
                        end
                        return true
                    else
                        return false
                    end
                end
            end
        end,
        Command = function (category) -- JAAS.Hook.Add ["Command"] category name identifier (function () end)
            return function (name)
                return function (identifier)
                    return function (func)
                        if isfunction(func) then
                            if hook_func.command == nil then
                                hook_func.command = {[category] = {[name] = {[identifier] = func}}}
                            elseif hook_func.command[category] == nil then
                                hook_func.command[category] = {[name] = {[identifier] = func}}
                            elseif hook_func.command[category][name] == nil then
                                hook_func.command[category][name] = {[identifier] = func}
                            else
                                hook_func.command[category][name][identifier] = func
                            end
                            return true
                        else
                            return false
                        end
                    end
                end
            end
        end,
        GlobalVar = function (category) -- JAAS.Hook.Add ["GlobalVar"] category name identifier (function () end)
            return function (name)
                return function (identifier)
                    return function (func)
                        if isfunction(func) then
                            if hook_func.globalvar == nil then
                                hook_func.globalvar = {[category] = {[name] = {[identifier] = func}}}
                            elseif hook_func.globalvar[category] == nil then
                                hook_func.globalvar[category] = {[name] = {[identifier] = func}}
                            elseif hook_func.globalvar[category][name] == nil then
                                hook_func.globalvar[category][name] = {[identifier] = func}
                            else
                                hook_func.globalvar[category][name][identifier] = func
                            end
                            return true
                        else
                            return false
                        end
                    end
                end
            end
        end
    }, {__call = function (self, category) -- JAAS.Hook.Add category name identifier (function () end)
        return function (name)
            return function (identifier)
                return function (func)
                    if isfunction(func) then
                        if hook_func.other == nil then
                            hook_func.other = {[category] = {[name] = {[identifier] = func}}}
                        elseif hook_func.other[category] == nil then
                            hook_func.other[category] = {[name] = {[identifier] = func}}
                        elseif hook_func.other[category][name] == nil then
                            hook_func.other[category][name] = {[identifier] = func}
                        else
                            hook_func.other[category][name][identifier] = func
                        end
                        return true
                    else
                        return false
                    end
                end
            end
        end
    end, __newindex = function () end}),
    Run = setmetatable({
        Permission = function (name) -- JAAS.Hook.Run ["Permission"] name (...)
            return function (...)
                local varArgs = ...
                if hook_func.permission != nil and hook_func.permission[name] != nil then
                    coroutine.create(function ()
                        for _,v in pairs(hook_func.permission[name]) do
                            v(varArgs)
                        end
                    end).resume()
                end
            end
        end,
        Command = function (category) -- JAAS.Hook.Run ["Command"] category name (...)
            return function (name)
                return function (...)
                    local varArgs = ...
                    if hook_func.command != nil and hook_func.command[category] != nil and hook_func.command[category][name] != nil then
                        coroutine.create(function ()
                            for _,v in pairs(hook_func.command[category][name]) do
                                v(varArgs)
                            end
                        end).resume()
                    end
                end
            end
        end,
        GlobalVar = function (category) -- JAAS.Hook.Run ["GlobalVar"] category name (...)
            return function (name)
                return function (...)
                    local varArgs = ...
                    if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil then
                        coroutine.create(function ()
                            for _,v in pairs(hook_func.other[category][name]) do
                                v(varArgs)
                            end
                        end).resume()
                    end
                end
            end
        end
    }, {__call = function (self, category) -- JAAS.Hook.Run category name (...)
        return function (name)
            return function (...)
                local varArgs = ...
                if hook_func.other != nil and hook_func.other[category] != nil and hook_func.other[category][name] != nil then
                    coroutine.create(function ()
                        for _,v in pairs(hook_func.other[category][name]) do
                            v(varArgs)
                        end
                    end).resume()
                end
            end
        end
    end, __newindex = function () end}),
    Remove = setmetatable({
        Permission = function (name) -- JAAS.Hook.Remove ["Permission"] name identifier
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
        Command = function (category) -- JAAS.Hook.Remove ["Command"] category name identifier
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
        GlobalVar = function (category) -- JAAS.Hook.Remove ["GlobalVar"] category name identifier
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
}, {})

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
    for _,v in ipairs{"pre", "init", "post"} do
        local a = 0
        if CLIENT then
            a = (#table_.shared[v]) + (#table_.client[v])
        else
            a = (#table_.shared[v]) + (#table_.server[v]) + (#table_.client[v])
        end
        if a > 0 then
            if !message then print "-------- JAAS Autorun --------" message = true end
            for _, file_ in ipairs(table_.shared[v]) do
                include.shared(file_)
                print("  [shared] "..file_)
            end
            if SERVER then
                for _, file_ in ipairs(table_.server[v]) do
                    include.server(file_)
                    print("  [server] "..file_)
                end
            end
            for _, file_ in ipairs(table_.client[v]) do
                include.client(file_)
                print("  [client] "..file_)
            end
        end
    end
    print "------------------------------"
end

for _, file_ in ipairs(file.Find("jaas/autorun/*.lua", "lsv")) do
    include.server("jaas/autorun/"..file_)
end

print "-------- JAAS Modules --------"

include ["shared"] {
    "JAAS_variables.lua",
    "jaas-core/JAAS-log.lua",
    "jaas-core/JAAS-developer.lua"
}

include ["server"] {
    "jaas-core/JAAS-player.lua",
    "jaas-core/JAAS-rank.lua",
    "jaas-core/JAAS-permission.lua"
}

include ["shared"] "jaas-core/JAAS-command.lua"

include ["client"] "jaas-core/JAAS-panel.lua"

if CLIENT then print "------------------------------" end

local dev = JAAS.Dev()
local RefreshClientInclude = dev.sharedSync("JAAS_InitTableSync", function (_, ply)
    local includeTable, count = {
        shared = {pre = {}, init = {}, post = {}},
        client = {pre = {}, init = {}, post = {}}
    }, 0
    for _, key1 in ipairs{"shared", "client"} do
        for _, key2 in ipairs{"pre", "init", "post"} do
            includeTable[key1][key2] = JAAS.include[key1][key2]
            count = count + (#JAAS.include[key1][key2])
        end
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