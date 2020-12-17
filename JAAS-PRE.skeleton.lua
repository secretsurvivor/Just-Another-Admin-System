if not JAAS then
    local onFailure = {}

    JAAS_PRE_HOOK = {
        onFailed = function (v)
            if isfunction(v) then
                onFailure[1 + #onFailure] = v
            end
        end,
        Active = false
    }

    hook.Add("PostGamemodeLoaded", "JAAS_PRE_HOOK_CLEANUP", function ()
        for k,v in ipairs(onFailure) do
            v()
        end
        onFailure = nil
        JAAS_PRE_HOOK = nil
    end)

    JAAS = {Command = function ()
            return setmetatable({category = "default"}, {__index = {
                setCategory = function (self, name)
                    if isstring(name) and !string.find(name, " ") then
                        self.category = name
                        return true
                    end
                end,
                clearCategory = function (self)
                    self.category = "default"
                end,
                argumentTableBuilder = function ()
                    return setmetatable({internal = {}}, {__index = {
                        typeMap = function (typ)
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
                        end,
                        add = function (self, name, dataType, required, default)
                            if isstring(dataType) then
                                dataType = self.typeMap(dataType)
                            end
                            if isstring(name) and isnumber(dataType) then
                                if dataType == 0x9 or dataType == 0xA then
                                    local option_list = {}
                                    for k,v in ipairs(default) do
                                        option_list[v] = k
                                    end
                                    default = option_list
                                end
                                self.internal[1 + #self.internal] = {name, dataType, required and true, default}
                                return self
                            end
                        end,
                        dispense = function (self)
                            local old = self.internal
                            self.internal = {}
                            return old
                        end
                    }})
                end,
                registerCommand = function (self, name, func, funcArgs, description, code, access)
                    if !string.find(name, " ") then
                        if JAAS_PRE_HOOK.Command == nil then
                            JAAS_PRE_HOOK.Command = {[self.category] = {{name, func, funcArgs, description, code, access}}}
                        elseif JAAS_PRE_HOOK.Command[self.category] == nil then
                            JAAS_PRE_HOOK.Command[self.category] = {{name, func, funcArgs, description, code, access}}
                        else
                            JAAS_PRE_HOOK.Command[self.category][1 + #JAAS_PRE_HOOK.Command[self.category]] = {name, func, funcArgs, description, code, access}
                        end
                    end
                end
            }})
        end,
        Permission = function ()
            return setmetatable({}, {__index = {registerPermission = function (name, description, code, access)
                if JAAS_PRE_HOOK.Permission == nil then
                    JAAS_PRE_HOOK.Permission = {{name, code, description, access}}
                else
                    JAAS_PRE_HOOK.Permission[1 + #JAAS_PRE_HOOK.Permission] = {name, code, description, access}
                end
            end}})
        end
    }
end