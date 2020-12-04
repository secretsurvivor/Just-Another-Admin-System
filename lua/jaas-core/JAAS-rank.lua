local MODULE, log, dev, SQL = JAAS:RegisterModule "Rank"
SQL = SQL"JAAS_rank"

if SERVER then
    SQL.CREATE.TABLE {name = "TEXT NOT NULL UNIQUE", position = "UNSIGNED TINYINT NOT NULL UNIQUE CHECK (position != 0 AND position <= 64)", power = "UNSIGNED TINYINT DEFAULT 0", invisible = "BOOL DEFAULT FALSE"}
end

local local_rank = {["getName"] = true, ["setName"] = true, ["getCodePosition"] = true, ["getCode"] = true} -- Used for local functions, for rank data

function local_rank:getName()
    local name = SQL.SELECT "name" {rowid = self.id}
    if name then
        return name["name"]
    end
end

function local_rank:setName(name)
    return SQL.UPDATE {name = name} {rowid = self.id}
end

function local_rank:getCodePosition()
    local position = SQL.SELECT "position" {rowid = self.id}
    if position then
        return position["position"]
    end
end

function local_rank:getCode()
    local position = SQL.SELECT "position" {rowid = self.id}
    if position then
        position = position[1]["position"]
        return bit.lshift(1, position - 1)
    end
end

function local_rank:getPower()
    local power = SQL.SELECT "power" {rowid = self.id}
    if power then
        return power["power"]
    end
end

function local_rank:setPower(power)
    local a = SQL.UPDATE {power = power} {rowid = self.id}
    if a then
        JAAS.Hook.Run "Rank" "GlobalPowerChange" ()
        return a
    end
end

function local_rank:getInvis()
    local invis = SQL.SELECT "invisible" {rowid = self.id}
    if invis then
        return invis["invisible"]
    end
end

function local_rank:setInvis(invis)
    return SQL.UPDATE {invisible = invis} {rowid = self.id}
end

setmetatable(local_rank, {
    __call = function(self, rank_name)
        if isstring(rank_name) then
            local a = SQL.SELECT "rowid" {name = rank_name}
            return setmetatable({id = a["rowid"]}, {__index = local_rank})
        elseif isnumber(rank_name) then
            return setmetatable({id = rank_name}, {__index = local_rank})
        end
    end,
    __newindex = function() end,
	__metatable = "jaas_rank_object"
})

local rank = {["addRank"] = true, ["rankIterator"] = true, ["getMaxPower"] = true, ["codeIterator"] = true} -- Used for global functions, for rank table
local rank_count = rank_count or SQL.SELECT "COUNT(rowid)"()["COUNT(rowid)"]

function rank.addRank(name, power, invis)
    if rank_count < 64 then
        local t = SQL.SELECT "MAX(position)"()
        if t then
            local next_position = t["MAX(position)"]
            if next_position == "NULL" then next_position = 0 end
            local a = SQL.INSERT {name = name, position = 1 + next_position, power = power, invisible = invis}
            if a != false then
                rank_count = 1 + rank_count
                return local_rank(name)
            end
        end
    end
end

function rank.rankIterator(key)
    local a = SQL.SELECT()
    local i = 0
    if a then
        if key then
            return function ()
                i = i + 1
                if i <= #a then
                    return a[i][key]
                end
            end
        end
        return function ()
            i = i + 1
            if i <= #a then
                return a[i]
            end
        end
    end
end

function rank.codeIterator(code)
    if code == 0 then
        return function () end
    end
    local max_bits = math.ceil(math.log(code, 2))
    do
        local max_shift = bit.lshift(1, max_bits - 1)
        if code < max_shift then
            max_bits = max_bits - 1
        elseif code == max_shift then
            local e = false
            return function ()
                if !e then
                    return SQL.SELECT "*" {position = max_bits}
                else
                    e = !e
                end
            end
        end
    end
    local where_str
    while max_bits >= 0 do
        local max_shift = bit.lshift(1, max_bits - 1)
        if bit.band(max_bits, max_shift) then
            if where_str == nil then
                where_str = "position="..max_bits
            else
                where_str = where_str.." OR position="..max_bits
            end
        end
        max_bits = max_bits - 1
    end
    local rank_table = SQL.SELECT "*" (where_str)
    local i = 0
    return function ()
        i = 1 + i
        if i <= (#rank_table) then
            return rank_table[i]
        end
    end
end

function rank.removeRank(name)
    local q, rank_position
    if isstring(name) then
        rank_position = tonumber(SQL.SELECT "position" {name = name}["position"])
        q = SQL.DELETE {name = name}
        rank_count = rank_count - 1
    elseif isnumber(name) then
        rank_position = tonumber(SQL.SELECT "position" {rowid = name}["position"])
        q = SQL.DELETE {rowid = name}
        rank_count = rank_count - 1
    elseif dev.isRankObject(var) then
        rank_position = tonumber(SQL.SELECT "position" {rowid = name.id}["position"])
        q = SQL.DELETE {rowid = name.id}
        rank_count = rank_count - 1
    end
    if q != false then
        local rank_code = bit.lshift(1, rank_position - 1)
        JAAS.Hook.Run "Rank" "RemovePosition" (function (bit_code)
            if bit_code > 0 then
                local bit_length = math.ceil(math.log(bits_to_be_shifted, 2))
                if bit.band(bit_code, rank_code) > 0 then
                    bit_code = bit.bxor(bit_code, rank_code)
                end
                if bit_length < rank_position then
                    return bit_code
                else
                    local shifted_bits = bit.rshift(bit_code, rank_position)
                    shifted_bits = bit.lshift(shifted_bits, rank_position - 1)
                    bit_code = bit.ror(bit_code, rank_position)
                    bit_code = bit.rshift(bit_code, bit_length - rank_position)
                    bit_code = bit.rol(bit_code, bit_length)
                    return bit.bor(shifted_bits, bit_code)
                end
            end
            return bit_code or 0
        end)
        sql.Begin()
        for t in rank.rankIterator() do
            if tonumber(t["position"]) > rank_position then
                SQL.UPDATE {position = t["position"] - 1} {rowid = t["id"]}
            end
        end
        sql.Commit()
        return true
    end
end

function rank.removeRanks(...)
    local rankPositions = {...}
    if (#rankPositions) > 1 then
        do
            local code_to_remove, rank_code_count = 0, 0
            for k,v in ipairs(rankPositions) do
                local q, rank_position
                if isstring(v) then
                    rank_position = tonumber(SQL.SELECT "position" {name = v}["position"])
                    if SQL.DELETE {name = v} then
                        code_to_remove = code_to_remove + bit.lshift(1, v[2])
                        rank_code_count = 1 + rank_code_count
                        rank_count = rank_count - 1
                    end
                elseif isnumber(v) then
                    rank_position = tonumber(SQL.SELECT "position" {rowid = v}["position"])
                    if SQL.DELETE {id = v} then
                        code_to_remove = code_to_remove + bit.lshift(1, v[2])
                        rank_code_count = 1 + rank_code_count
                        rank_count = rank_count - 1
                    end
                elseif istable(v) and getmetatable(v) == "jaas_rank_object" then
                    rank_position = tonumber(SQL.SELECT "position" {rowid = v.id}["position"])
                    if SQL.DELETE {rowid = v.id} then
                        code_to_remove = code_to_remove + bit.lshift(1, v[2])
                        rank_code_count = 1 + rank_code_count
                        rank_count = rank_count - 1
                    end
                end
                rankPositions[rank_code_count + 1] = rank_position
                if k > rank_code_count + 1 then
                    rankPositions[k] = nil
                end
            end
        end
        if (#rankPositions) > 0 then
            JAAS.Hook.Run "Rank" "RemovePosition" (function (bit_code)
                if bit_code > 0 then
                    local shifted_bits = 0
                    rankPositions = table.sort(rankPositions)
                    local bit_length = math.ceil(math.log(bit_code, 2))
                    for i=#rankPositions, 1, -1 do
                        if bit_length > rankPositions[i] then
                            local temp_bits = bit.rshift(bit_code, rankPositions[i])
                            shifted_bits = shifted_bits + bit.lshift(temp_bits, rankPositions[i] - (#rankPositions - (i - 1)))
                        end
                    end
                    if rankPositions[1] > 1 then
                        bit_code = bit.ror(bit_code, rankPositions[1])
                        bit_code = bit.rshift(bit_code, bit_length - rankPositions[1])
                        bit_code = bit.rol(bit_code, bit_length)
                        return bit.bor(shifted_bits, bit_code)
                    else
                        return shifted_bits
                    end
                end
            end)
            sql.Begin()
            local i = 1
            for t in rank.rankIterator() do
                if rankPositions[i] < tonumber(t["position"]) then
                    SQL.UPDATE {position = t["position"] - i} {rowid = t["id"]}
                    i = 1 + i
                end
            end
            sql.Commit()
            return true
        end
    end
end

local p_cache = {}
local p_cache_dirty = true

JAAS.Hook "Rank" "GlobalPowerChange" ["MaxPowerCacheClean"] = function()
    p_cache_dirty = true
end

function rank.getMaxPower(code)
    if code == 0 then
        return 0
    end
    if p_cache_dirty then
        p_cache = {}
        p_cache_dirty = false
    end
    if p_cache[code] ~= nil then
        return p_cache[code]
    else
        local max = 0
        for t in rank.codeIterator(code) do
            if t.power > max then
                max = t.power
            end
        end
        p_cache[code] = max
        return max
    end
end

function rank.getRank(name)
    local a = SQL.SELECT "rowid" {name = rank_name}
    if a then
        return local_rank(tonumber(a["id"]))
    end
end

MODULE.Access(function (rank_name)
    if rank_name then
        local a = SQL.SELECT "rowid" {name = rank_name}
        if a then
            return local_rank(tonumber(a["id"]))
        end
    else
        return setmetatable({}, {__index = rank, __newindex = function () end, __metatable = "jaas_rank_library"})
    end
end, true)

MODULE.Handle.Shared(function (jaas)
    local command = jaas.Command()
    local arg = command.argumentTableBuilder()

    command:setCategory "Rank"

    command:registerCommand("Add", function (ply, name, power, invis)
        name = sql.SQLStr(name)
        if !rank.addRank(name, power, invis) then
            return "Adding Rank has failed"
        end
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
        if !rank_object:setPower(power) then
            return "Setting power for rank " .. rank_object:getName() .. " has failed"
        end
    end, arg:add("Rank", "RANK", true):add("Power", "INT", true, 0):dispense())

    command:registerCommand("Get_Ranks", function (ply)
        local f_str = "Ranks:\n"
        for name in rank.rankIterator("name") do
            f_str = f_str..name.."\n"
        end
        return f_str
    end)
end)

MODULE.Handle.Server(function (jaas)
    local dev, perm = jaas.Dev(), jaas.Permission()
    local showInvisibleRanks = perm.registerPermission("Show Invisible Ranks", "This permission will show invisible ranks clientside")

    local refreshRankTable = dev.sharedSync("JAAS_RankTableSync", function (_, ply)
        local net_table, show_invisible_rank = {}, showInvisibleRanks:codeCheck(ply:getJAASCode())
        for t in rank.rankIterator() do
            if !t.invisible or (t.invisible and show_invisible_rank) then
                table.insert(net_table, t)
            end
        end
        if net_table then
            return net_table
        end
    end)

    concommand.Add("JAAS_RefreshRankTableSync", function ()
        refreshRankTable()
    end)
end)

MODULE.Handle.Client(function (jaas)
    local dev = jaas.Dev()
    dev.sharedSync("JAAS_RankTableSync", _, "JAAS_RankSyncClient", function (_, ply, table) -- TODO
    end)
end)

log:printLog "Module Loaded"