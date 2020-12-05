local MODULE, log, dev, SQL = JAAS:RegisterModule "Rank"
SQL = SQL"JAAS_rank"

if !SQL.EXIST and SERVER then
    SQL.CREATE.TABLE {
        name = "TEXT NOT NULL UNIQUE",
        position = "UNSIGNED TINYINT NOT NULL UNIQUE CHECK (position != 0 AND position <= 64)",
        power = "UNSIGNED TINYINT DEFAULT 0",
        invisible = "BOOL DEFAULT FALSE",
        access_group = "UNSIGNED INT DEFAULT 0"
    }
end

local local_rank = {["getName"] = true, ["setName"] = true, ["getCodePosition"] = true, ["getCode"] = true} -- Used for local functions, for rank data

local r_cache = dev.Cache()
JAAS.Hook "Rank" "GlobalChange" ["Rank_module_cache"] = function ()
    r_cache()
end

function local_rank:getName()
    if r_cache[self.id] ~= nil and r_cache[self.id].name ~= nil then
        return r_cache[self.id].name
    else
        local name = SQL.SELECT "name" {rowid = self.id}
        if name then
            if r_cache[self.id] == nil then
                r_cache[self.id] = {}
            end
            r_cache[self.id].name = name["name"]
            return name["name"]
        end
    end
end

function local_rank:setName(name)
    local q = SQL.UPDATE {name = name} {rowid = self.id}
    if q then
        JAAS.Hook.Run "Rank" "GlobalChange" ()
    end
    return q
end

function local_rank:getCodePosition()
    if r_cache[self.id] ~= nil and r_cache[self.id].position ~= nil then
        return r_cache[self.id].position
    else
        local position = SQL.SELECT "position" {rowid = self.id}
        if position then
            if r_cache[self.id] == nil then
                r_cache[self.id] = {}
            end
            r_cache[self.id].position = position["position"]
            return position["position"]
        end
    end
end

function local_rank:getCode()
    if r_cache[self.id] ~= nil and r_cache[self.id].code ~= nil then
        return r_cache[self.id].code
    else
        local position = SQL.SELECT "1 << (position - 1)" {rowid = self.id}
        if position then
            if r_cache[self.id] == nil then
                r_cache[self.id] = {}
            end
            r_cache[self.id].code = position["position"]
            return position["position"]
        end
    end
end

function local_rank:getPower()
    if r_cache[self.id] ~= nil and r_cache[self.id].power ~= nil then
        return r_cache[self.id].power
    else
        local power = SQL.SELECT "power" {rowid = self.id}
        if power then
            if r_cache[self.id] == nil then
                r_cache[self.id] = {}
            end
            r_cache[self.id].power = power["power"]
            return power["power"]
        end
    end
end

function local_rank:setPower(power)
    local a = SQL.UPDATE {power = power} {rowid = self.id}
    if a then
        JAAS.Hook.Run "Rank" "GlobalChange" ()
        JAAS.Hook.Run "Rank" "GlobalPowerChange" ()
        return a
    end
end

function local_rank:getInvis()
    if r_cache[self.id] ~= nil and r_cache[self.id].invis ~= nil then
        return r_cache[self.id].invis
    else
        local invis = SQL.SELECT "invisible" {rowid = self.id}
        if invis then
            if r_cache[self.id] == nil then
                r_cache[self.id] = {}
            end
            r_cache[self.id].invis = invis["invisible"]
            return invis["invisible"]
        end
    end
end

function local_rank:setInvis(invis)
    local q = SQL.UPDATE {invisible = invis} {rowid = self.id}
    if q then
        JAAS.Hook.Run "Rank" "GlobalChange" ()
    end
    return q
end

function local_rank:getAccess()
    if r_cache[self.id] ~= nil and r_cache[self.id].access ~= nil then
        return r_cache[self.id].access
    else
        local access = SQL.SELECT "access_group" {rowid = self.id}
        if access then
            if r_cache[self.id] == nil then
                r_cache[self.id] = {}
            end
            r_cache[self.id].access = access["access_group"]
            return access["access_group"]
        end
    end
end

function local_rank:setAccess(value)
    local q = SQL.UPDATE {access_group = value} {rowid = self.id}
    if q then
        JAAS.Hook.Run "Rank" "GlobalChange" ()
    end
    return q
end

MODULE.Handle.Server(function (jaas)
    local access = jaas.AccessGroup()

    function local_rank:accessCheck(code)
        return access.codeCheck(access.RANK, self:getAccess(), code)
    end
end)

function local_rank:codeCheck(code)
    if isnumber(code) then
        return bit.band(self:getCode(), code) > 0
    elseif dev.isPlayerObject(code) or dev.isCommandObject(code) or dev.isPermissionObject(code) then
        return bit.band(self:getCode(), code:getCode()) > 0
    elseif dev.isPlayer(code) then
        return bit.band(self:getCode(), code:getJAASCode()) > 0
    end
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
local rank_count = rank_count or SQL.SELECT "COUNT(rowid)"() or 0
if istable(rank_count) then
    rank_count = rank_count["COUNT(rowid)"]
end

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
                elseif dev.isRankObject(v) then
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

local p_cache = dev.Cache()

JAAS.Hook "Rank" "GlobalPowerChange" ["MaxPowerCacheClean"] = function()
    p_cache()
end

function rank.getMaxPower(code)
    if code == 0 then
        return 0
    end
    if p_cache[code] ~= nil then
        return p_cache[code]
    else
        local q,max = SQL.SELECT "MAX(power)" "code & ".. code .." > 0",0
        if q then
            max = q["MAX(power)"]
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

    local refreshRankTable = dev.SharedSync("JAAS_RankTableSync", function (_, ply)
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
    dev.SharedSync("JAAS_RankTableSync", _, "JAAS_RankSyncClient", function (_, ply, table) -- TODO
    end)
end)

log:printLog "Module Loaded"