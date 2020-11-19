local dev = JAAS.Dev()
local log = JAAS.Log("Rank")
if !sql.TableExists("JAAS_rank") and SERVER then
	dev.fQuery("CREATE TABLE JAAS_rank(name TEXT NOT NULL UNIQUE, position UNSIGNED TINYINT(255) NOT NULL UNIQUE CHECK (position != 0 AND position <= 64), power UNSIGNED TINYINT(255) DEFAULT 0, invisible BOOL DEFAULT FALSE)")
end

local local_rank = {["getName"] = true, ["setName"] = true, ["getCodePosition"] = true, ["getCode"] = true} -- Used for local functions, for rank data

function local_rank:getName()
    local name = dev.fQuery("SELECT name FROM JAAS_rank WHERE rowid=%u", self.id)
    if name then
        return name[1]["name"]
    end
end

function local_rank:setName(name)
    return dev.fQuery("UPDATE JAAS_rank SET name='%s' WHERE rowid=%u", name, self.id)
end

function local_rank:getCodePosition()
    local position = dev.fQuery("SELECT position FROM JAAS_rank WHERE rowid=%u", self.id)
    if position then
        return position[1]["position"]
    end
end

function local_rank:getCode()
    local position = dev.fQuery("SELECT position FROM JAAS_rank WHERE rowid=%u", self.id)
    if position then
        position = position[1]["position"]
        return bit.lshift(1, position - 1)
    end
end

function local_rank:getPower()
    local power = dev.fQuery("SELECT power FROM JAAS_rank WHERE rowid=%u", self.id)
    if power then
        return power[1]["power"]
    end
end

function local_rank:setPower(power)
    local a = dev.fQuery("UPDATE JAAS_rank SET power=%u WHERE rowid=%u", power, self.id)
    if a then
        hook.Run("JAAS-rankPowerCache-dirty")
        return a
    end
end

function local_rank:getInvis()
    local invis = dev.fQuery("SELECT invisible FROM JAAS_rank WHERE rowid=%u", self.id)
    if invis then
        return invis[1]["invisible"]
    end
end

function local_rank:setInvis(invis)
    return dev.fQuery("UPDATE JAAS_rank SET invisible=%s WHERE rowid=%u", invis, self.id)
end

debug.getregistry()["JAAS_RankObject"] = local_rank

setmetatable(local_rank, {
    __call = function(self, rank_name)
        if isstring(rank_name) then
            local a = dev.fQuery("SELECT rowid FROM JAAS_rank WHERE name='%s'", rank_name)
            return setmetatable({id = a[1]["rowid"]}, {__index = local_rank})
        elseif isnumber(rank_name) then
            return setmetatable({id = rank_name}, {__index = local_rank})
        end
    end,
    __newindex = function() end,
	__metatable = "jaas_rank_object"
})

local rank = {["addRank"] = true, ["rankIterator"] = true, ["getMaxPower"] = true, ["codeIterator"] = true} -- Used for global functions, for rank table
local rank_count = dev.fQuery("SELECT COUNT(rowid) FROM JAAS_rank")[1]["COUNT(rowid)"]

function rank.addRank(name, power, invis)
    if rank_count < 64 then
        local t = dev.fQuery("SELECT MAX(position) FROM JAAS_rank")[1]
        if t then
            local next_position = t["MAX(position)"]
            if next_position == "NULL" then next_position = 0 end
            local a = dev.fQuery("INSERT INTO JAAS_rank(name, position, power, invisible) VALUES (%u, '%s', %u, %u, %s)", name, 1 + next_position, power, invis)
            if a != false then
                rank_count = 1 + rank_count
                return local_rank(name)
            end
        end
    end
end

function rank.rankIterator(key)
    local a = dev.fQuery("SELECT * FROM JAAS_rank")
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
                    return dev.fQuery("SELECT * FROM JAAS_rank WHERE position=%u", max_bits)[1]
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
    local rank_table = dev.fQuery("SELECT * FROM JAAS_rank WHERE "..where_str)
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
        rank_position = tonumber(dev.fQuery("SELECT position FROM JAAS_rank WHERE name='%s'", name)[1]["position"])
        q = dev.fQuery("DELETE FROM JAAS_rank WHERE name='%s'", name)
        rank_count = rank_count - 1
    elseif isnumber(name) then
        rank_position = tonumber(dev.fQuery("SELECT position FROM JAAS_rank WHERE rowid=%s", name)[1]["position"])
        q = dev.fQuery("DELETE FROM JAAS_rank WHERE rowid=%s", name)
        rank_count = rank_count - 1
    elseif dev.isRankObject(var) then
        rank_position = tonumber(dev.fQuery("SELECT position FROM JAAS_rank WHERE rowid=%s", name.id)[1]["position"])
        q = dev.fQuery("DELETE FROM JAAS_rank WHERE rowid=%s", name.id)
        rank_count = rank_count - 1
    end
    if q != false then
        local rank_code = bit.lshift(1, rank_position - 1)
        JAAS.hook.run "Rank" "RemovePosition" (function (bit_code)
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
                dev.fQuery("UPDATE JAAS_rank SET position=%u WHERE rowid=%s", t["position"]-1, t["id"])
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
                    rank_position = tonumber(dev.fQuery("SELECT position FROM JAAS_rank WHERE name='%s'", v)[1]["position"])
                    if dev.fQuery("DELETE FROM JAAS_rank WHERE name='%s'", v) then
                        code_to_remove = code_to_remove + bit.lshift(1, v[2])
                        rank_code_count = 1 + rank_code_count
                        rank_count = rank_count - 1
                    end
                elseif isnumber(v) then
                    rank_position = tonumber(dev.fQuery("SELECT position FROM JAAS_rank WHERE rowid=%s", v)[1]["position"])
                    if dev.fQuery("DELETE FROM JAAS_rank WHERE id=%s", v) then
                        code_to_remove = code_to_remove + bit.lshift(1, v[2])
                        rank_code_count = 1 + rank_code_count
                        rank_count = rank_count - 1
                    end
                elseif istable(v) and getmetatable(v) == "jaas_rank_object" then
                    rank_position = tonumber(dev.fQuery("SELECT position FROM JAAS_rank WHERE rowid=%s", v.id)[1]["position"])
                    if dev.fQuery("DELETE FROM JAAS_rank WHERE rowid=%s", v.id) then
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
            JAAS.hook.run "Rank" "RemovePosition" (function (bit_code)
                if bit_code > 0 then
                    local shifted_bits = 0
                    rankPositions = dev.mergeSort(rankPositions)
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
                    dev.fQuery("UPDATE JAAS_rank SET position=%u WHERE rowid=%s", t["position"]-i, t["id"])
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

hook.Add("JAAS-rankPowerCache-dirty", "JAAS-maxPower-function", function()
    p_cache_dirty = true
end)

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
    local a = dev.fQuery("SELECT rowid FROM JAAS_rank WHERE name='%s'", rank_name)
    if a then
        return local_rank(tonumber(a[1]["id"]))
    end
end

debug.getregistry()["JAAS_RankLibrary"] = rank

JAAS.Rank = setmetatable({}, {
    __call = function (self, rank_name)
		local f_str, id = log:executionTraceLog()
        if f_str and !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
            return log:removeTraceLog(id)
        end
        if rank_name then
            local a = dev.fQuery("SELECT rowid FROM JAAS_rank WHERE name='%s'", rank_name)
            if a then
                return local_rank(tonumber(a[1]["id"]))
            end
        else
            return setmetatable({}, {__index = rank, __newindex = function () end, __metatable = "jaas_rank_library"})
        end
    end,
    __index = function () end,
    __newindex = function () end,
    __metatable = nil
})

log:printLog "Module Loaded"