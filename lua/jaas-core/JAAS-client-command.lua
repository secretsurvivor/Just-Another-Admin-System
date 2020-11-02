local log = JAAS.Log("Command")

local command = {}

local command_table = {}

function command.executeCommand(category, name, argumentTable, t)
    if #argumentTable == #t then
        net.Start("JAAS_ClientCommand")
        net.WriteString(category)
        net.WriteString(name)
        for i,v in ipairs(t) do
            local a = argumentTable[i][2]
            if a == 1 then
                net.WriteBool(v)
            elseif a == 2 then
                net.WriteInt(v, 64)
            elseif a == 3 then
                net.WriteFloat(v)
            elseif a == 4 then
                net.WriteString(v)
            elseif a == 5 then
                net.WriteString(v)
            elseif a == 6 then
                net.WriteTable(v)
            end
        end
        net.SendToServer()
    end
end

net.Receive("JAAS_ClientCommand", function()
    local code = net.ReadInt(3)
    local category, name, message = net.ReadString(), net.ReadString()
    if code == 4 then
        message = net.ReadString()
    end
    hook.Run("JAAS_CommandFeedback", code, category, name, message)
end)

hook.Add("JAAS_CommandFeedback", "JAAS_CommandFeedback_ConsoleEcho", function(code, category, name, message) -- ToDo Use Log Module
    if code == 0 then -- Successful Command Execution
    elseif code == 1 then -- Invalid Command Category or Name
    elseif code == 2 then -- Invalid Player Access
    elseif code == 3 then -- Invalid Passed Argument
    elseif code == 4 then -- Function Feedback
    else -- Unknown Error Code
    end
end)

concommand.Add("JAAS", function(ply, cmd, args, argStr)
    local category, name = args[1], args[2]
    if command_table[category] ~= nil and command_table[category][name] ~= nil then

    end
end)

JAAS.Command = setmetatable({}, {
    __call = function ()
        local f_str, id = log:executionTraceLog("Command")
        if !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
            log:removeTraceLog(id)
            return
        end
        return setmetatable({}, {
            __index = command,
            __newindex = function () end,
            __metatable = nil
        })
    end,
    __index = function () end,
    __newindex = function () end,
    __metatable = nil
})

log:printLog "Module Loaded"