local command = JAAS.Command()
local log = JAAS.Log "Core Commands"
local dev = JAAS.Dev()
local arg = command.argumentTableBuilder()

command:setCategory "Utility"

log:registerLog {1, 6, "set", "move type on", 1, "to", 5} -- [1] secret_survivor set move type on Dempsy40 to "MOVETYPE_NOCLIP"
command:registerCommand("Toggle_Flight", function (ply, target)
    if dev.isPlayer(target) then
        if !IsValid(ply) or ply == target or ply:canTarget(target:getJAASCode()) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_FLY)
                log:adminChat("%p activated Flight on %p", ply:Nick(), target:Nick())
                if ply:IsPlayer() and target:IsPlayer() then
                    log:Log(1, {player = {ply, target}, string = {"MOVETYPE_FLY"}})
                end
            else
                target:SetMoveType(MOVETYPE_WALK)
                log:adminChat("%p deactivated Flight on %p", ply:Nick(), target:Nick())
                if ply:IsPlayer() and target:IsPlayer() then
                    log:Log(1, {player = {ply, target}, string = {"MOVETYPE_WALK"}})
                end
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true), "Allows a player to activate flight on themselves or others")

command:registerCommand("Toggle_Gravity_Flight", function (ply, target)
    if dev.isPlayer(target) then
        if !IsValid(ply)  or ply == target or ply:canTarget(target:getJAASCode()) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_FLYGRAVITY)
                log:adminChat("%p activated Gravity Flight on %p", ply:Nick(), target:Nick())
                if ply:IsPlayer() and target:IsPlayer() then
                    log:Log(1, {player = {ply, target}, string = {"MOVETYPE_FLYGRAVITY"}})
                end
            else
                target:SetMoveType(MOVETYPE_WALK)
                log:adminChat("%p deactivated Gravity Flight on %p", ply:Nick(), target:Nick())
                if ply:IsPlayer() and target:IsPlayer() then
                    log:Log(1, {player = {ply, target}, string = {"MOVETYPE_WALK"}})
                end
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true), "Allows a player to activate gravity flight on themselves or others")

command:registerCommand("Toggle_Noclip", function (ply, target)
    if dev.isPlayer(target) then
        if !IsValid(ply)  or ply == target or ply:canTarget(target:getJAASCode()) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_NOCLIP)
                log:adminChat("%p activated Noclip on %p", ply:Nick(), target:Nick())
                if ply:IsPlayer() and target:IsPlayer() then
                    log:Log(1, {player = {ply, target}, string = {"MOVETYPE_NOCLIP"}})
                end
            else
                target:SetMoveType(MOVETYPE_WALK)
                log:adminChat("%p deactivated Noclip on %p", ply:Nick(), target:Nick())
                if ply:IsPlayer() and target:IsPlayer() then
                    log:Log(1, {player = {ply, target}, string = {"MOVETYPE_WALK"}})
                end
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true), "Allows a player to activate noclip on themselves or others")

log:registerLog {1, 6, "kicked", 1, "for", 5} -- [2] secret_survivor kicked Dempsy40 for "RDM"
command:registerCommand("Kick", function (ply, target, reason)
    if dev.isPlayer(target) then
        if !IsValid(ply)  or ply == target or ply:canTarget(target:getJAASCode()) then
            if reason then
                ply:Kick(string.format(":: JAAS ::\n%s\n%s kicked you", reason, ply:Nick()))
            else
                ply:Kick(":: JAAS ::\n"..ply:Nick().." kicked you")
            end
            log:chat("%p was kicked for %s", target:Nick(), reason)
            if ply:IsPlayer() and target:IsPlayer() then
                log:Log(2, {player = {ply, target}, string = {reason}})
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true):add("Reason", "STRING", false), "Allows a player to kick players that they can target")

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
end,nil, "Allows a player to activate Godmode on themselves or others")

log:registerLog {1, 6, "killed", 1} -- [5] secret_survivor killed Dempsy40
log:registerLog {1, 6, "killed", "themself"} -- [6] secret_survivor killed themself
command:registerCommand("Kill", function (ply, target)
	if IsValid(target) and target:Alive() then
        if target:IsPlayer() and ply:canTarget(target) then
            log:Log(5, {player = {ply, target}})
            log:adminChat("%p killed %p", ply:Nick(), target:Nick())
            target:Kill()
        elseif target:IsBot() then
            log:adminChat("%p killed %p", ply:Nick(), target:Nick())
            target:Kill()
        end
	elseif ply:Alive() then
		ply:Kill()
        log:Log(6, {player = {ply}})
        log:adminChat("%p killed themself", ply:Nick())
	end
end, arg:add("Target", "PLAYER"), "Allows a player to activate death on themselves or others")

log:registerLog {1, 6, "changed level", "to", 3, "with gamemode", 3} -- [7] secret_survivor changed level to gm_construct with gamemode darkrp
command:registerCommand("Map", function (ply, map_name, gamemode)
    print(map_name, gamemode)
    if map_name and gamemode then
        log:Log(7, {player = {ply}, entity = {map_name, gamemode}})
        log:adminChat("%p changed level to %e with gamemode %e", ply:Nick(), map_name, gamemode)
        game.ConsoleCommand("gamemode "..gamemode.."\n")
        game.ConsoleCommand("changelevel "..map_name.."\n")
    elseif !map_name then
        return "Map Name is required"
    else
        return "Gamemode is required"
    end
end, arg:add("Map", "STRING", false, "gm_construct"):add("Gamemode", "STRING", false, "sandbox"), "Allows a player to change the current level and gamemode")

log:registerLog {1, 6, "created", "bot"} -- [8] secret_survivor created bot
command:registerCommand("Create_Bot", function (ply)
	if (!game.SinglePlayer() and player.GetCount() < game.MaxPlayers()) then
        player.CreateNextBot("Bot_"..((#player.GetBots()) + 1))
        log:Log(8, {player = {ply}})
    else
	    return "Cannot create bot"
    end
end,nil, "Allows a player to create a bot and connect them to the server")

log:registerLog {1, 6, "set", 1, "speed to", 4} -- [9] secret_survivor set Dempsy40 speed to 1700
log:registerLog {1, 6, "set", "their speed to", 4} -- [10] secret_survivor set their speed to 1700
command:registerCommand("Set_Run_Speed", function (ply, speed, target)
	if IsValid(target) then
		target:SetRunSpeed(speed)
	else
		if IsValid(ply) then
			ply:SetRunSpeed(speed)
		else
			return "Target must be specified"
		end
	end
end, arg:add("Speed", "INT"):add("Target", "PLAYER"), "Allows a player to change the run speed of themselves or others")

command:setCategory "Test"

command:registerCommand("Add", function (ply, a, b)
	print(a + b)
	return a + b
end, arg:add("Num_1", "INT", true, 0):add("Num_2", "INT", true, 0), "Allows a player to accomplish complicated mathematics without leaving their game")

command:registerCommand("Bacon", function (ply)
	if IsValid(ply) then
		ply:Say "Bacon"
	end
	print "Bacon"
    log:superadminChat("%a", "Bacon")
end,nil, "Considered to be one of the most dangerous commands on planet Earth, no one truly understands the full extend of this command")