local command = JAAS.Command()
local log = JAAS.Log "Core Commands"
local arg = command.argumentTableBuilder()

command:setCategory "Utility"

log:registerLog {1, 6, "set", "move type on", 1, "to", 5} -- [1] secret_survivor set move type on Dempsy40 to "MOVETYPE_NOCLIP"
command:registerCommand("Toggle_Flight", function (ply, target)
    if dev.isPlayer(target) then
        if !IsValid(ply) or ply:validPowerTarget(target:getJAASCode()) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_FLY)
                log:adminChat("%p activated Flight on %p", ply:Nick(), target:Nick())
                log:Log(1, {player = {ply, target}, string = {"MOVETYPE_FLY"}})
            else
                target:SetMoveType(MOVETYPE_WALK)
                log:adminChat("%p deactivated Flight on %p", ply:Nick(), target:Nick())
                log:Log(1, {player = {ply, target}, string = {"MOVETYPE_WALK"}})
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true))

command:registerCommand("Toggle_Gravity_Flight", function (ply, target)
    if dev.isPlayer(target) then
        if !IsValid(ply) or ply:validPowerTarget(target:getJAASCode()) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_FLYGRAVITY)
                log:adminChat("%p activated Gravity Flight on %p", ply:Nick(), target:Nick())
                log:Log(1, {player = {ply, target}, string = {"MOVETYPE_FLYGRAVITY"}})
            else
                target:SetMoveType(MOVETYPE_WALK)
                log:adminChat("%p deactivated Gravity Flight on %p", ply:Nick(), target:Nick())
                log:Log(1, {player = {ply, target}, string = {"MOVETYPE_WALK"}})
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true))

command:registerCommand("Toggle_Noclip", function (ply, target)
    if dev.isPlayer(target) then
        if !IsValid(ply) or ply:validPowerTarget(target:getJAASCode()) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_NOCLIP)
                log:adminChat("%p activated Noclip on %p", ply:Nick(), target:Nick())
                log:Log(1, {player = {ply, target}, string = {"MOVETYPE_NOCLIP"}})
            else
                target:SetMoveType(MOVETYPE_WALK)
                log:adminChat("%p deactivated Noclip on %p", ply:Nick(), target:Nick())
                log:Log(1, {player = {ply, target}, string = {"MOVETYPE_WALK"}})
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true))

log:registerLog {1, 6, "kicked", 1, "for", 5} -- [2] secret_survivor kicked Dempsy40 for "RDM"
command:registerCommand("Kick", function (ply, target, reason)
    if dev.isPlayer(target) then
        if !IsValid(ply) or ply:validPowerTarget(target:getJAASCode()) then
            if reason then
                ply:Kick(string.format(":: JAAS ::\n%s\n%s kicked you", reason, ply:Nick()))
            else
                ply:Kick(":: JAAS ::\n"..ply:Nick().." kicked you")
            end
            log:chat("%p was kicked for %s", target:Nick(), reason)
            log:Log(2, {player = {ply, target}, string = {reason}})
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true):add("Reason", "STRING", false))

log:registerLog {1, 6, "activated", "Godmode"} -- [3] secret_survivor activated Godmode
log:registerLog {1, 6, "deactivated", "Godmode"} -- [4] secret_survivor deactivated Godmode
command:registerCommand("God", function(ply)
	if IsValid(ply) then
		if ply:HasGodMode() then
			ply:GodDisable()
			log:chat("%p no longer has Godmode", ply:Nick())
            log:Log(4, {player = {ply}})
		else
			ply:GodEnable()
			log:chat("%p has Godmode", ply:Nick())
            log:Log(3, {player = {ply}})
		end
	end
end)

log:registerLog {1, 6, "killed", 1} -- [5] secret_survivor killed Dempsy40
log:registerLog {1, 6, "killed", "themself"} -- [6] secret_survivor killed themself
command:registerCommand("Kill", function (ply, target)
	if IsValid(target) and target:Alive() and ply:canTarget(target) then
		target:Kill()
        log:Log(5, {player = {ply, target}})
        log:adminChat("%p killed %p", ply:Nick(), ply:Nick())
	elseif ply:Alive() then
		ply:Kill()
        log:Log(6, {player = {ply}})
        log:adminChat("%p killed themself", ply:Nick())
	end
end, arg:add("Target", "PLAYER"))

log:registerLog {1, 6, "changed level", "to", 3, "with gamemode", 3} -- [7] secret_survivor changed level to gm_construct with gamemode darkrp
command:registerCommand("Map", function (ply, map_name, gamemode)
    log:Log(7, {player = {ply}, entity = {map_name, gamemode}})
    log:adminChat("%p changed level to %e with gamemode %e", ply:Nick(), map_name, gamemode)
    game.ConsoleCommand("gamemode "..gamemode.."\n")
    game.ConsoleCommand("changelevel "..map_name.."\n")
end, arg:add("Map", "STRING", false, "gm_construct"):add("Gamemode", "STRING", false, "sandbox"))

log:registerLog {1, 6, "created", "bot"} -- [8] secret_survivor created bot
command:registerCommand("Create_Bot", function (ply)
	if (!game.SinglePlayer() and player.GetCount() < game.MaxPlayers()) then
        player.CreateNextBot("Bot_"..((#player.GetBots()) + 1))
        log:Log(7, {player = {ply}})
    else
	    return "Cannot create bot"
    end
end)

log:registerLog {1, 6, "set", 1, "speed to", 4} -- [9] secret_survivor set Dempsy40 speed to 1700
log:registerLog {1, 6, "set", "their speed to", 4} -- [10] secret_survivor set their speed to 1700
command:registerCommand("SetRunSpeed", function (ply, speed, target)
	if IsValid(target) then
		target:SetRunSpeed(speed)
	else
		if IsValid(ply) then
			ply:SetRunSpeed(speed)
		else
			return "Target must be specified"
		end
	end
end, arg:add("Speed", "INT"):add("Target", "PLAYER"))

command:setCategory "Test"

command:registerCommand("Add", function (ply, a, b)
	print(a + b)
	return a + b
end, arg:add("Num_1", "INT", true, 0):add("Num_2", "INT", true, 0))

command:registerCommand("Bacon", function (ply)
	if IsValid(ply) then
		ply:Say "Bacon"
	end
	print "Bacon"
    log:superadminChat("%a", "Bacon")
end)