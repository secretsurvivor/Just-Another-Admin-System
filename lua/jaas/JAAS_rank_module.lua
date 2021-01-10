local command = JAAS.Command()
local arg = command.argumentTableBuilder()

command:setCategory "User"

local ModifyUser_ArgTable = arg:add("Rank", "RANK", true):add("Target", "PLAYER"):dispense()
command:registerCommand("Add", function (ply, rank_object, target)
    if dev.isPlayer(target) then -- Apply rank change on target
        local target_object = target:getJAASObject()
        if !IsValid(ply) or ply == target or ply:validPowerTarget(target:getJAASCode()) then
            if !IsValid(ply) or rank_object:accessCheck(ply:getJAASCode()) then
                if rank_object:codeCheck(target:getJAASCode()) then
                    target_object:xorCode(rank_object)
                else
                    return target:Nick().." already has that rank"
                end
            else
                return "Cannot add target to " .. rank_object:getName()
            end
        else
            return "Cannot Target "..target:Nick()
        end
    else
        if IsValid(ply) then -- Apply rank change on caller
            local user = JAAS.Player(ply)
            if rank_object:accessCheck(user) then
                if rank_object:codeCheck(ply:getJAASCode()) then
                    user:xorCode(rank_object)
                else
                    return "You already have this rank"
                end
            else
                return "Cannot add yourself to " .. rank_object:getName()
            end
        else
            return "Target must be valid to change rank" -- Can't change server's rank
        end
    end
end, ModifyUser_ArgTable)

command:registerCommand("Remove", function (ply, rank_object, target)
    if dev.isPlayer(target) then -- Apply rank change on target
        local target_object = target:getJAASObject()
        if !IsValid(ply) or ply == target or ply:validPowerTarget(target:getJAASCode()) then
            if !IsValid(ply) or rank_object:accessCheck(ply:getJAASCode()) then
                if rank_object:codeCheck(target:getJAASCode()) then
                    target_object:xorCode(rank_object)
                else
                    return target:Nick().." already does not have rank"
                end
            else
                return "Cannot remove target from "..rank_object:getName()
            end
        else
            return "Cannot Target "..target:Nick()
        end
    else
        if IsValid(ply) then -- Apply rank change on caller
            local user = JAAS.Player(ply)
            if rank_object:accessCheck(user) then
                if rank_object:codeCheck(ply:getJAASCode()) then
                    user:xorCode(rank_object)
                else
                    return "You already have this rank"
                end
            else
                return "Cannot remove yourself from " .. rank_object:getName()
            end
        else
            return "Target must be valid to change rank" -- Can't change server's rank
        end
    end
end, ModifyUser_ArgTable)

command:setCategory "Utility"

command:registerCommand("Toggle_Flight", function (ply, target)
    if dev.isPlayer(target) then
        if !IsValid(ply) or ply:validPowerTarget(target:getJAASCode()) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_FLY)
            else
                target:SetMoveType(MOVETYPE_WALK)
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
            else
                target:SetMoveType(MOVETYPE_WALK)
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
            else
                target:SetMoveType(MOVETYPE_WALK)
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true))

command:registerCommand("Kick", function (ply, target, reason)
    if dev.isPlayer(target) then
        if !IsValid(ply) or ply:validPowerTarget(target:getJAASCode()) then
            if reason then
                ply:Kick(string.format(":: JAAS ::\n%s\n%s kicked you", reason, ply:Nick()))
            else
                ply:Kick(":: JAAS ::\n"..ply:Nick().." kicked you")
            end
        else
            return "Cannot target "..target:Nick()
        end
    else
        return "Invalid target"
    end
end, arg:add("Target", "PLAYER", true):add("Reason", "STRING", false))