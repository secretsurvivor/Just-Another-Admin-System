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
    if SQL.UPDATE {name = name} {rowid = self.id} then
        JAAS.Hook.Run "Rank" "GlobalChange" ()
        return true
    end
    return false
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
    if SQL.UPDATE {power = power} {rowid = self.id} then
        JAAS.Hook.Run "Rank" "GlobalChange" ()
        JAAS.Hook.Run "Rank" "GlobalPowerChange" ()
        return true
    end
    return false
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
    if SQL.UPDATE {invisible = invis} {rowid = self.id} then
        JAAS.Hook.Run "Rank" "GlobalChange" ()
        return true
    end
    return false
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
    if SQL.UPDATE {access_group = value} {rowid = self.id} then
        JAAS.Hook.Run "Rank" "GlobalChange" ()
        return true
    end
    return false
end

MODULE.Handle.Server(function (jaas)
    local access = jaas.AccessGroup()

    function local_rank:accessCheck(code)
        if isnumber(code) then
            return access.codeCheck(access.RANK, self:getAccess(), code)
        elseif dev.isPlayerObject(code) then
            return access.codeCheck(access.RANK, self:getAccess(), code:getCode())
        elseif dev.isPlayer(code) then
            return access.codeCheck(access.RANK, self:getAccess(), code:getJAASCode())
        end
    end
end)

local AND = bit.band
function local_rank:codeCheck(code)
    if isnumber(code) then
        return AND(self:getCode(), code) > 0
    elseif dev.isPlayerObject(code) or dev.isCommandObject(code) or dev.isPermissionObject(code) then
        return AND(self:getCode(), code:getCode()) > 0
    elseif dev.isPlayer(code) then
        return AND(self:getCode(), code:getJAASCode()) > 0
    end
end

setmetatable(local_rank, {
    __call = function(self, rank_name)
        if isstring(rank_name) then
            local a = SQL.SELECT "rowid" {name = rank_name}
            if a then
                return setmetatable({id = a["rowid"]}, {__index = local_rank, __metatable = "jaas_rank_object"})
            end
        elseif isnumber(rank_name) then
            if SQL.SELECT "rowid" {rowid = rank_name} then
                return setmetatable({id = rank_name}, {__index = local_rank, __metatable = "jaas_rank_object"})
            end
        end
        return false
    end,
    __newindex = function() end,
	__metatable = "jaas_rank_object"
})

local rank = {["addRank"] = true, ["rankIterator"] = true, ["getMaxPower"] = true, ["codeIterator"] = true} -- Used for global functions, for rank table
local rank_count = rank_count or SQL.SELECT "COUNT(rowid)" () ["COUNT(rowid)"]

function rank.addRank(name, power, invis)
    if rank_count < 64 then
        local t = SQL.SELECT "MAX(position)"()
        if t then
            local next_position = t["MAX(position)"]
            if next_position == "NULL" then next_position = 0 end
            if SQL.INSERT {name = name, position = 1 + next_position, power = power, invisible = invis} then
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
                i = 1 + i
                if i <= #a then
                    return a[i][key]
                end
            end
        end
        return function ()
            i = 1 + i
            if i <= #a then
                return a[i]
            end
        end
    end
end

local bit = bit
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
    elseif isnumber(name) then
        rank_position = tonumber(SQL.SELECT "position" {rowid = name}["position"])
        q = SQL.DELETE {rowid = name}
    elseif dev.isRankObject(var) then
        rank_position = tonumber(SQL.SELECT "position" {rowid = name.id}["position"])
        q = SQL.DELETE {rowid = name.id}
    end
    if q then
        rank_count = rank_count - 1
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
                    return shifted_bits + bit_code
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
    end
    return q
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
                rankPositions[1 + rank_code_count] = rank_position
                if k > 1 + rank_code_count then
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
                        return shifted_bits + bit_code
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
end)

dev:isTypeFunc("RankObject","jaas_rank_object")
dev:isTypeFunc("RankLibrary","jaas_rank_library")

MODULE.Handle.Server(function (jaas)
    local perm = jaas.Permission()
    local modify_rank = perm.registerPermission("Can Modify Rank Table", "Player will be able to modify the rank table - this is required to add, remove, and modify existing ranks")

    util.AddNetworkString "JAAS_ModifyRank_Channel"
    /*
        0 :: Modify Successful
        1 :: Could not modify
        2 :: Invalid Rank Identifier
        3 :: Unknown modify code
    */
    local sendFeedback = dev.sendUInt("JAAS_ModifyRankTable_Channel", 2)
    net.Receive("JAAS_ModifyRank_Channel", function (len, ply)
        if modify_rank:codeCheck(ply) then
            local sendCode = sendFeedback(ply)
            local modifyCase = dev.SwitchCase()
            modifyCase:case(0, function () -- Add Rank
                local name = SQL.ESCAPE(net.ReadString())
                local power = net.ReadUInt(8)
                local invis = net.ReadBool()
                if rank.addRank(name, power, invis) then
                    return 0
                else
                    return 1
                end
            end)
            modifyCase:case(1, function () -- Remove Rank
                local name = SQL.ESCAPE(net.ReadString())
                if rank.removeRank(name) then
                    return 0
                else
                    return 1
                end
            end)
            modifyCase:case(2, function () -- Remove Ranks
                local len,t = net.ReadUInt(64),{}
                for i=1,len do
                    t[i] = net.ReadString()
                end
                if rank.removeRanks(unpack(t)) then
                    return 0
                else
                    return 1
                end
            end)
            modifyCase:case(3, function () -- Set Power
                local name = SQL.ESCAPE(net.ReadString())
                local power = net.ReadUInt(8)
                local rnk = jaas.Rank(name)
                if dev.isRankObject(rnk) then
                    if rnk:setPower(power) then
                        return 0
                    else
                        return 1
                    end
                else
                    return 2
                end
            end)
            modifyCase:case(4, function () -- Set Invisible
                local name = SQL.ESCAPE(net.ReadString())
                local invis = net.ReadBool()
                local rnk = jaas.Rank(name)
                if dev.isRankObject(rnk) then
                    if rnk:setInvis(invis) then
                        return 0
                    else
                        return 1
                    end
                else
                    return 2
                end
            end)
            modifyCase:default(3)
            sendCode(modifyCase:switch(net.ReadUInt(3)))
        end
    end)

    local showInvisibleRanks = perm.registerPermission("Show Invisible Ranks", "This permission will show invisible ranks clientside")

    concommand.Add("JAAS_RefreshRankTableSync", function ()
        refreshRankTable()
    end)
end)

log:print "Module Loaded"