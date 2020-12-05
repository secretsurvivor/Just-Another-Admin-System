if JAAS then return end

local onFailure = {}

JAAS_PRE_HOOK = setmetatable({}, {
    __index = function (self, k)
        if k == "Command" or k == "Permission" then
            return rawget(self, k)
        end
    end,
    __newindex = function (self, k, v)
        if k == "onFailure" and isfunction(v) then
            table.insert(onFailure, v)
        end
    end
})

hook.Add("PostGamemodeLoaded", "JAAS_PRE_HOOK_CLEANUP", function ()
    if JAAS.PRE then
        for k,v in ipairs(onFailure) do
            v()
        end
        onFailure = nil
        JAAS_PRE_HOOK = nil
    end
end)

JAAS = {
    PRE = true,
    Command = function ()
        local t = {}

        function t:setCategory(name)
            if isstring(name) then
                self.category = name
                return true
            end
        end

        function t:clearCategory()
            self.category = "default"
        end

        local argTable = {}

        local function typeMap(typ)
            if        typ == "BOOL" then return    0x1
            elseif     typ == "INT" then return    0x2
            elseif   typ == "FLOAT" then return    0x3
            elseif  typ == "STRING" then return    0x4
            elseif  typ == "PLAYER" then return    0x5
            elseif typ == "PLAYERS" then return    0x6
            elseif    typ == "RANK" then return    0x7
            elseif   typ == "RANKS" then return    0x8
            elseif  typ == "OPTION" then return    0x9
            elseif typ == "OPTIONS" then return    0xA
            else error("Unknown Datatype", 2)
            end
        end

        function argTable:add(name, dataType, required, default)
            if isstring(dataType) then
                dataType = typeMap(dataType)
            end
            if isstring(name) and isnumber(dataType) then
                if dataType == 0x9 or dataType == 0xA then
                    local option_list = {}
                    for k,v in ipairs(default) do
                        option_list[v] = k
                    end
                    default = option_list
                end
                table.insert(self.internal, {name, dataType, required and true, default})
                return self
            end
        end

        function argTable.typeMap(typeStr)
            return typeMap(typeStr)
        end

        function argTable:dispense()
            local old = self.internal
            self.internal = {} -- {Name, Datatype, Required, Default} -- If OPTION or OPTIONS then {Name, Datatype, Required, {List_of_options}}
            return old
        end

        function t.argumentTableBuilder()
            return setmetatable({internal = {}}, {__index = argTable})
        end

        function t:registerCommand(name, func, funcArgs, description, code, access)
            if JAAS_PRE_HOOK.Command == nil then
                JAAS_PRE_HOOK.Command = {[self.category] = {{name, func, funcArgs, description, code, access}}}
            elseif JAAS_PRE_HOOK.Command[self.category] == nil then
                JAAS_PRE_HOOK.Command[self.category] = {{name, func, funcArgs, description, code, access}}
            else
                table.insert(JAAS_PRE_HOOK.Command[self.category], {name, func, funcArgs, description, code, access})
            end
        end

        return setmetatable({category = "default"}, {__index = t})
    end,
    Permission = function ()
        local t = {}

        function t.registerPermission(name, description, code, access)
            if JAAS_PRE_HOOK.Permission == nil then
                JAAS_PRE_HOOK.Permission = {{name, code, description, access}}
            else
                table.insert(JAAS_PRE_HOOK.Permission, {name, code, description, access})
            end
        end

        return setmetatable({}, {__index = t})
    end
}