JAAS = {}

local command = {}

/*
    if typ == "BOOL" then
        return bool
    elseif typ = "INT" then
        return int
    elseif typ = "FLOAT" then
        return float
    elseif typ = "STRING" then
        return string
    elseif typ = "PLAYER" then
        return string
    elseif typ = "PLAYERS" then
        return table
    end
*/
function command.executeCommand(category, name, argumentTable, ...)
    if #argumentTable == #{...} then
        net.Start("JAAS_ClientCommand")
        net.WriteString(category)
        net.WriteString(name)
        local varArgs = {...}
        for i,v in ipairs(varArgs) do
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