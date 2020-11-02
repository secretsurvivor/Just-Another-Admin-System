--if JAAS then return end
JAAS = {}

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
local stageMeta, stateMeta = 
    {__call = function (self, _) rawset(self, #self + 1, _) end, __index = function () end, __newindex = function () end},
    {__call = function (self, _) self.init(_) end}
JAAS.include = setmetatable({
    shared = setmetatable({
        pre = setmetatable({}, stageMeta),
        init = setmetatable({}, stageMeta),
        post = setmetatable({}, stageMeta)
    }, {__call = function (self, _) self.init(_) end}),
    server = setmetatable({
        pre = setmetatable({}, stageMeta),
        init = setmetatable({}, stageMeta),
        post = setmetatable({}, stageMeta)
    }, {__call = function (self, _) self.init(_) end}),
    client = setmetatable({
        pre = setmetatable({}, stageMeta),
        init = setmetatable({}, stageMeta),
        post = setmetatable({}, stageMeta)
    }, {__call = function (self, _) self.init(_) end}),
}, {__call = function (self, _) self.shared.init(_) end})

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
    "jaas-core/JAAS-user.lua",
    "jaas-core/JAAS-rank.lua",
    "jaas-core/JAAS-command.lua",
    "jaas-core/JAAS-permission.lua"
}

include ["client"] "jaas-core/JAAS-client-command.lua"

if CLIENT then print "------------------------------" end

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

if SERVER then
    includeLoop(JAAS.include)

    util.AddNetworkString "JAAS_InitTableSync" 
    net.Receive("JAAS_InitTableSync", function (_, ply)
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
            net.Start("JAAS_InitTableSync")
            net.WriteTable(includeTable)
            net.Send(ply)
        end
    end)
elseif CLIENT then
    net.Receive("JAAS_InitTableSync", function (_, ply)
        includeLoop(net.ReadTable())
    end)

    hook.Add("InitPostEntity", "JAAS_ClientInit", function()
        net.Start "JAAS_InitTableSync" 
        net.SendToServer()
    end)
end