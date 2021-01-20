local log = JAAS.Log("Game")

/*
    :print(str)
    :Log(type_, t) -- {rank=, player=, entity=, data=, string=}
    :chatLog(str)
    :adminChatLog(str)
    :superadminChatLog(str)
*/

log:registerLog {1, "was", 6, "killed", "by", 1, "using", 3} -- [1] secret_survivor was killed by Dempsy40 using AK-47
log:registerLog {1, "committed", 6, "suicide"} -- [2] Dempsy40 committed suicide

hook.Add("PlayerDeath", "JAAS-Log_PlayerDeath", function (victim, inflictor, attacker)
    if victim == attacker then
        log:Log(2, {player = {victim}})
    elseif attacker:IsPlayer() then
        log:Log(1, {player = {victim, attacker}, entity = {inflictor}})
    end
end)

log:registerLog {1, 6, "said", 5} -- [3] secret_survivor said “Ey' Bitches”
log:registerLog {1, 6, " said team only", 5} -- [4] Dempsy40 said team only “I want to kill secret”

hook.Add("PlayerSay", "JAAS-Log_PlayerSay", function (ply, text, teamOnly)
    if teamOnly then
        log:Log(4, {player = {ply}, string = {text}})
    else
        log:Log(3, {player = {ply}, string = {text}})
    end
end)

log:registerLog {1, 6, "joined"} -- [5] Dempsy40 joined
log:registerLog {1, 6, "joined", "from", 3} -- [6] Dempsy40 joined from 127.0.0.1

hook.Add("PlayerInitialSpawn", "JAAS-Log_PlayerInitialSpawn", function (ply, transition)
    if !transition then
        log:Log(6, {player = {ply}, entity = {ply:IPAddress()}})
        for k,v in ipairs(player.GetAll()) do
            if v:IsSuperAdmin() then
                log:chatText(v, "%p joined from %e", {ply:Nick(), ply:IPAddress()})
            else
                log:chatText(v, "%p joined", {ply:Nick()})
            end
        end
        log:print(ply:Nick().." joined from "..ply:IPAddress())
    end
end)

log:registerLog {1, 6, "spawned"} -- [7] secret_survivor spawned

hook.Add("PlayerSpawn", "JAAS-Log_PlayerSpawn", function (ply, transition)
    log:Log(7, {player = {ply}})
    log:adminChat(ply:Nick().." spawned")
end)

log:registerLog {1, "was", 6, "silently killed"} -- [8] Dempsy40 was silently killed

hook.Add("PlayerSilentDeath", "JAAS-Log_PlayerSilentDeath", function (ply)
    log:Log(8, {player = {ply}})
end)

log:registerLog {6, "Cleaned Up", "map"} -- [9] Cleaned Up map

hook.Add("PostCleanupMap", "JAAS-Log_PostCleanupMap", function ()
    log:Log(9)
    log:print("Map was cleaned")
    log:adminChat("Cleaned Up map")
end)

log:registerLog {3, "was", 6, "edited", "by", 1, ":", 5, "->", 5} -- [10] edit_sky was edited by secret_survivor: m_vDirection -> 1 3 0

hook.Add("VariableEdited", "JAAS-Log_VariableEdited", function (ent, ply, key, val, editor)
    log:Log(10, {player = {ply}, entity = {ent}, string = {key, val}})
    log:print(ent:GetName().." was edited by "..ply:Nick()..": "..key.." -> "..val)
    log:superadminChat("%e was edited by %p: %s -> %s", ent:GetName(), ply:Nick(), key, val)
end)

log:registerLog {"Lua Environment has", 6, "shutdown"} -- [11] Lua Environment has shutdown

hook.Add("ShutDown", "JAAS-Log_ShutDown", function ()
    log:print("Lua Environment has shutdown")
    log:Log(11, {})
end)

log:registerLog {1, 6, "disconnected"} -- [12] secret_survivor disconnected

hook.Add("PlayerDisconnected", "JAAS-Log_PlayerDisconnected", function (ply)
    log:Log(12, {player = {ply}})
    log:chat("%s left", ply:Nick())
end)

log:registerLog {1, 6, "changed team", "from", 3, "to", 3} -- [13] secret_survivor changed team from Terrorist to Innocent

hook.Add("PlayerChangedTeam", "JAAS-Log_PlayerChangedTeam", function (ply, oldTeam, newTeam)
    oldTeam,newTeam = team.GetName(oldTeam),team.GetName(newTeam)
    if oldTeam != "" or newTeam != "" then
        log:Log(13, {player = {ply}, entity = {oldTeam, newTeam}})
        log:print(ply:Nick().." changed team from "..oldTeam.." to "..newTeam)
        log:chat("%p changed team from %e to %e", ply:Nick(), oldTeam, newTeam)
    end
end)

log:registerLog {6, "Lua_run", "entity was executed with", 5} -- [14] Lua_run entity was executed with “print("Hello World")”

hook.Add("AcceptInput", "JAAS-Log_AcceptInput", function (ent, input, activator, caller, value)
    if ent:GetClass() == "lua_run" then
        if value then
            log:Log(14, {string = {value}})
            log:print("Lua_run entity was executed with "..value)
            log:superadminChat("Lua_run entity was executed with %s", value)
        else
            log:Log(14, {string = {ent:GetDefaultCode()}})
            log:print("Lua_run entity was executed with "..ent:GetDefaultCode())
            log:superadminChat("Lua_run entity was executed with %s", ent:GetDefaultCode())
        end
    end
end)