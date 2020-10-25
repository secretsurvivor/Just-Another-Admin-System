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
function include.shared(_) include.server(_) include.client(_) end

print "-------- JAAS Modules --------"

include ["shared"] "jaas-core/JAAS-developer.lua"

include ["server"] {
    "jaas-core/JAAS-user.lua",
    "jaas-core/JAAS-rank.lua",
    "jaas-core/JAAS-command.lua"
}

include ["client"] "jaas-core/JAAS-client-command.lua"

if SERVER then
    local files = file.Find("JAAS/autorun/*.lua", "LUA")
    if #files > 0 then
        print "-------- JAAS Autorun --------"

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

        for _, file_ in ipairs(files) do
            include.server("JAAS/autorun/"..file_)
        end

        if ((#JAAS.include.shared.pre) + (#JAAS.include.server.pre) + (#JAAS.include.client.pre)) > 0 then
            print "Pre-Initialisation"
            for _,file_ in ipairs(JAAS.include.shared.pre) do
                print("  [Shared] - " .. file_)
                include.shared(file_)
            end
            for _,file_ in ipairs(JAAS.include.server.pre) do
                print("  [Server] - " .. file_)
                include.server(file_)
            end
            for _,file_ in ipairs(JAAS.include.client.pre) do
                print("  [Client] - " .. file_)
                include.client(file_)
            end
        end

        if ((#JAAS.include.shared.init) + (#JAAS.include.server.init) + (#JAAS.include.client.init)) > 0 then
            print "Initialisation"
            for _,file_ in ipairs(JAAS.include.shared.init) do
                print("  [Shared] - " .. file_)
                include.shared(file_)
            end
            for _,file_ in ipairs(JAAS.include.server.init) do
                print("  [Server] - " .. file_)
                include.server(file_)
            end
            for _,file_ in ipairs(JAAS.include.client.init) do
                print("  [Client] - " .. file_)
                include.client(file_)
            end
        end

        if ((#JAAS.include.shared.post) + (#JAAS.include.server.post) + (#JAAS.include.client.post)) > 0 then
            print "Post-Initialisation"
            for _,file_ in ipairs(JAAS.include.shared.post) do
                print("  [Shared] - " .. file_)
                include.shared(file_)
            end
            for _,file_ in ipairs(JAAS.include.server.post) do
                print("  [Server] - " .. file_)
                include.server(file_)
            end
            for _,file_ in ipairs(JAAS.include.client.post) do
                print("  [Client] - " .. file_)
                include.client(file_)
            end
        end
    end
end

print "------------------------------"