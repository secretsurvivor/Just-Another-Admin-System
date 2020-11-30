local log = {["getLogFile"] = true, ["writeToLogFile"] = true, ["printLog"] = true, ["silentLog"] = true}

function log.getLogFile(date)
end

function log.writeToLogFile(...)
    if SERVER and file.Exists("", "DATA") then
    elseif SERVER then
    end
end

function log:printLog(str)
    local str = "[JAAS] ["..self.label.."] - "..str
    print(str)
    log.writeToLogFile(str)
end

function log:silentLog(str)
    log.writeToLogFile(str)
end

function log:chatLog(str)
    local str = "[JAAS] - "..str
    PrintMessage(HUD_PRINTTALK, str)
    log.writeToLogFile(str)
end

function log:gameLog(action, str)
end

local executionTrace = executionTrace or {} -- [label][id] = {file path, line}
local refusedTrace = refusedTrace or {} -- [label] = {id*}

function log:executionTraceLog()
    if !JAAS.Var.TraceExecution then
        return
    end
    local info = debug.getinfo(3)
    if executionTrace[self.label] ~= nil then
        for _,v in ipairs(executionTrace[self.label]) do
            if v[1] == filepath and v[2] == line then
                return
            end
        end
        table.insert(executionTrace[self.label], {info.short_src, info.currentline})
    else
        executionTrace[self.label] = {{info.short_src, info.currentline}}
    end
    return info.short_src, #executionTrace[self.label] -- file path, id
end

function log:removeTraceLog(id)
    if !JAAS.Var.TraceExecution then
        return false
    end
    if refusedTrace[self.label] ~= nil then
        for _,v in ipairs(refusedTrace[self.label]) do
            if v == id then
                return
            end
        end
        table.insert(refusedTrace[self.label], id)
    else
        refusedTrace[self.label] = {id}
    end
    return true
end

local function verifyFilepath_table(filepath, verify_str_table) -- From Developer Module
    function verifyFilepath(filepath, verify_str)
        local filepath_func = string.gmatch(filepath, ".")
        local verify_func = string.gmatch(verify_str, ".")
        local count = 0
        local wild_card,verified,incorrect = false, false, false
        local f_c, v_c = filepath_func(), verify_func()
        while !verified and !incorrect do
            if wild_card then
                if v_c == "*" then
                    v_c = verify_func()
                    count = 1 + count
                end
                if v_c == nil then
                    verified = true
                end
                if f_c == "/" then
                    wild_card = false
                    v_c = verify_func()
                end
                if count == (#verify_str) + 1 then
                    verified = true
                end
                f_c = filepath_func()
            else
                if f_c == v_c then
                elseif v_c == "*" then
                    wild_card = true
                else
                    incorrect = true
                end
                f_c = filepath_func()
                v_c = verify_func()
                count = 1 + count
            end
            if f_c == nil then
                incorrect = true
            end
        end
        return verified
    end
	for _, v_str in ipairs(verify_str_table) do
		if verifyFilepath(filepath, v_str) then
			return true
		end
	end
	return false
end

function JAAS.Log(label)
    local f_str, id = log.executionTraceLog({label = "Log"})
    if f_str and !verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
        return log.removeTraceLog({label = "Log"}, id)
    end
    return setmetatable({label = label}, {
        __index = log,
        __newindex = function () end,
        __metatable = "jaas_log_library"
    })
end

concommand.Add("JAAS_readTraceLogs", function ()
    PrintTable(executionTrace)
end)

concommand.Add("JAAS_readRefusedTraceLogs", function ()
    local last_label = ""
    for k,v in pairs(refusedTrace) do
        if k != last_label then
            print(k)
            last_label = k
        end
        for _, id in ipairs(v) do
            print("\t"..executionTrace[k][id][1])
        end
    end
end)

log.printLog({label = "Log"}, "Module Loaded")