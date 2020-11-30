local command = JAAS.Command()
local rank = CLIENT or JAAS.Rank()
local arg = command.argumentTableBuilder()

command:setCategory "User"

local ModifyUser_ArgTable = arg:add("Rank", "RANK", true):add("Target", "PLAYER"):dispense()
command:registerCommand("Add", function (ply, rank_object, target)
    local user = JAAS.Player(ply)
    if target and IsValid(target) then -- Apply rank change on target
        local target_object = target:getJAASObject()
        if !IsValid(ply) or ply == target or user:validPowerTarget(target_object, rank) then
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
        if !IsValid(ply) or ply == target or user:validPowerTarget(target_object, rank) then
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

command:setCategory "Rank"

command:registerCommand("Add", function (ply, name, power, invis)
    name = sql.SQLStr(name)
    rank.addRank(name, power, invis)
end, arg:add("Name", "STRING", true):add("Power", "INT", false, 0):add("Invisible", "BOOL", false, false):dispense())

command:registerCommand("Remove", function (ply, rank_object)
    if !rank.removeRank(rank_object) then
        return "Unknown Rank"
    end
end, arg:add("Rank", "RANK", true):dispense())

command:registerCommand("Remove_Ranks", function (ply, rank_table)
    if !rank.removeRanks(rank_table) then
        return "All Ranks Unknown"
    end
end, arg:add("Ranks", "RANKS", true):dispense())

command:registerCommand("Set_Power", function (ply, rank_object, power)
    rank_object:setPower(power)
end, arg:add("Rank", "RANK", true):add("Power", "INT", true, 0):dispense())

command:registerCommand("PrintRanks", function (ply)
    local f_str = "Ranks:\n"
    for name in rank.rankIterator("name") do
        f_str = f_str..name.."\n"
    end
    return f_str
end)