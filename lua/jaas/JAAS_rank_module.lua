local command = JAAS.Command()
local arg = command.argumentTableBuilder()

command:setCategory "User"

local ModifyUser_ArgTable = arg:add("Rank", "RANK", true):add("Target", "PLAYER"):dispense()
command:registerCommand("Add", function (ply, rank_object, target)
    local user = JAAS.Player(ply)
    if target and IsValid(target) then -- Apply rank change on target
        local target_object = target:getJAASObject()
        if !IsValid(ply) or ply == target or user:validPowerTarget(target_object) then
            local rank_code = rank_object:getCode()
            if bit.band(target_object:getCode(), rank_code) == 0 then
                target_object:xorCode(rank_code)
            else
                return target:Nick().." already has that rank"
            end
        else
            return "Cannot Target "..target:Nick()
        end
    else
        if IsValid(ply) then -- Apply rank change on caller
            local rank_code = rank_object:getCode()
            if bit.band(user:getCode(), rank_code) == 0 then
                user:xorCode(rank_code)
            else
                return "You already have this rank"
            end
        else
            return "Target must be valid to change rank" -- Can't change server's rank
        end
    end
end, ModifyUser_ArgTable)

command:registerCommand("Remove", function (ply, rank_object, target)
    local user = JAAS.Player(ply)
    if target and IsValid(target) then -- Apply rank change on target
        local target_object = target:getJAASObject()
        if !IsValid(ply) or ply == target or user:validPowerTarget(target_object) then
            local rank_code = rank_object:getCode()
            if bit.band(target_object:getCode(), rank_code) > 0 then
                target_object:xorCode(rank_code)
            else
                return target:Nick().." already has that rank"
            end
        else
            return "Cannot Target "..target:Nick()
        end
    else
        if IsValid(ply) then -- Apply rank change on caller
            local rank_code = rank_code:getCode()
            if bit.band(user:getCode(), rank_code) > 0 then
                user:xorCode(rank_code)
            else
                return "You already have this rank"
            end
        else
            return "Target must be valid to change rank" -- Can't change server's rank
        end
    end
end, ModifyUser_ArgTable)

command:setCategory "Utility"

command:registerCommand("Toggle_Flight", function (ply, target)
    if target then
        target_object,user = target:getJAASObject(),ply:getJAASObject()
        if user:validPowerTarget(target_object) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_FLY)
            else
                target:SetMoveType(MOVETYPE_WALK)
            end
        end
    end
end, arg:add("Target", "PLAYER", true):dispense())

command:registerCommand("Toggle_Gravity_Flight", function (ply, target)
    if target then
        target_object,user = target:getJAASObject(),ply:getJAASObject()
        if user:validPowerTarget(target_object) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_FLYGRAVITY)
            else
                target:SetMoveType(MOVETYPE_WALK)
            end
        end
    end
end, arg:add("Target", "PLAYER", true):dispense())

command:registerCommand("Toggle_Noclip", function (ply, target)
    if target then
        target_object,user = target:getJAASObject(),ply:getJAASObject()
        if user:validPowerTarget(target_object) then
            if target:GetMoveType() == MOVETYPE_WALK then
                target:SetMoveType(MOVETYPE_NOCLIP)
            else
                target:SetMoveType(MOVETYPE_WALK)
            end
        end
    end
end, arg:add("Target", "PLAYER", true):dispense())