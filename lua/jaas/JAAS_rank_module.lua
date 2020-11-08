local command = JAAS.Command()
local rank = CLIENT or JAAS.Rank()
local arg = command.argumentTableBuilder()

command:setCategory "User"

local ModifyUser_ArgTable = arg:add("Rank", "RANK", true):add("Target", "PLAYER"):dispense()
command:registerCommand("AddUser", function (ply, rank_object, target)
    local user = JAAS.Player(ply)
    local target_object = JAAS.Player(target)
    if IsValid(ply) then
        if IsValid(target) then -- Apply rank change on target
            if ply == target or rank.getMaxPower(user:getCode()) > rank.getMaxPower(target_object:getCode()) then
                local rank_code = rank_object:getCode()
                if bit.band(target_object:getCode(), rank_code) == 0 then
                    target_object:xorCode(rank_code)
                else
                    return target:Nick().." already has that rank"
                end
            else
                return "Cannot Target "..target:Nick()
            end
        else -- Apply rank change on caller
            local rank_code = rank_object:getCode()
            if bit.band(user:getCode(), rank_code) == 0 then
                user:xorCode(rank_code)
            else
                return "You already have this rank"
            end
        end
    else -- Server is caller
        if IsValid(target) then
            local rank_code = rank_object:getCode()
            if bit.band(target_object:getCode(), rank_code) == 0 then
                target_object:xorCode(rank_code)
            else
                return target:Nick().." already has that rank"
            end
        else
            return "Target must be valid to change rank" -- Can't change server's rank
        end
    end
end, ModifyUser_ArgTable)

command:registerCommand("RemoveUser", function (ply, rank_object, target)
    local user = JAAS.Player(ply)
    local target_object = JAAS.Player(target)
    if IsValid(ply) then
        if IsValid(target) then
            if ply == target or rank.getMaxPower(user:getCode()) > rank.getMaxPower(target_object:getCode()) then
                local rank_code = rank_object:getCode()
                if bit.band(target_object:getCode(), rank_code) > 0 then
                    target_object:xorCode(rank_code)
                else
                    return target:Nick().." already has that rank"
                end
            else
                return "Cannot Target "..target:Nick()
            end
        else -- Apply rank change on caller
            local rank_code = rank_code:getCode()
            if bit.band(user:getCode(), rank_code) > 0 then
                user:xorCode(rank_code)
            else
                return "You already have this rank"
            end
        end
    else -- Server is caller
        if IsValid(target) then
            local rank_code = rank_object:getCode()
            if bit.band(target_object:getCode(), rank_code) > 0 then
                target_object:xorCode(rank_code)
            else
                return target:Nick().." already has that rank"
            end
        else
            return "Target must be valid to change rank" -- Can't change server's rank
        end
    end
end, ModifyUser_ArgTable)

command:setCategory "Rank"

command:registerCommand("AddRank", function (ply, name, power, invis)
    rank.addRank(name, power, invis)
end, arg:add("Name", "STRING", true):add("Power", "INT", false, 0):add("Invisible", "BOOL", false, false):dispense())

command:registerCommand("RemoveRank", function (ply, rank_object)
    if !rank.removeRank(rank_object) then
        return "Unknown Rank"
    end
end, arg:add("Rank", "RANK", true):dispense())

command:registerCommand("RemoveRanks", function (ply, rank_table)
    if !rank.removeRanks(rank_table) then
        return "All Ranks Unknown"
    end
end, arg:add("Ranks", "RANKS", true):dispense())

command:registerCommand("SetPower", function (ply, rank_object, power)
    rank_object:setPower(power)
end, arg:add("Rank", "RANK", true):add("Power", "INT", true, 0):dispense())

command:registerCommand("PrintRanks", function (ply)
    local f_str = "Ranks:\n"
    for name in rank.rankIterator("name") do
        f_str = f_str..name.."\n"
    end
    return f_str
end)