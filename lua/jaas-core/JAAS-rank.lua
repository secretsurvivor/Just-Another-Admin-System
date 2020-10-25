local fQuery, dataTypeCheck, keyExists = unpack( JAAS.Dev .. (QUERY + TYPECHECK + KEYEXIST) )
if !sql.TableExists("JAAS_rank") then
	fQuery("CREATE TABLE JAAS_rank(id UNSIGNED INT NOT NULL UNIQUE, name TEXT NOT NULL UNIQUE, position UNSIGNED TINYINT(255) NOT NULL UNIQUE CHECK (position != 0 AND position <= 64), power UNSIGNED TINYINT(255) DEFAULT 0, invisible BOOL DEFAULT FALSE, PRIMARY KEY (id))")
end

local local_rank = {["getName"] = true, ["setName"] = true, ["getCodePosition"] = true, ["getCode"] = true} -- Used for local functions, for rank data

function local_rank:getName()
    local name = fQuery("SELECT name FROM JAAS_rank WHERE id=%u", self.id)
    if dataTypeCheck("table", name) then
        return name[1]["name"]
    end
end

function local_rank:setName(name)
    return fQuery("UPDATE JAAS_rank SET name='%s' WHERE id=%u", name, self.id)
end

function local_rank:getCodePosition()
    local position = fQuery("SELECT position FROM JAAS_rank WHERE id=%u", self.id)
    if position then
        return position[1]["position"]
    end
end

function local_rank:getCode()
    local position = fQuery("SELECT position FROM JAAS_rank WHERE id=%u", self.id)
    if position then
        position = position[1]["position"]
        return bit.lshift(1, position)
    end
end

function local_rank:getPower()
    local power = fQuery("SELECT power FROM JAAS_rank WHERE id=%u", self.id)
    if power then
        return power[1]["power"]
    end
end

function local_rank:setPower(power)
    local a = fQuery("UPDATE JAAS_rank SET power=%u WHERE id=%u", power, self.id)
    if a then
        hook.Run("JAAS-rankPowerCache-dirty")
        return a
    end
end

function local_rank:getInvis()
    local invis = fQuery("SELECT invisible FROM JAAS_rank WHERE id=%u", self.id)
    if invis then
        return invis[1]["invisible"]
    end
end

function local_rank:setInvis(invis)
    return fQuery("UPDATE JAAS_rank SET invisible=%s WHERE id=%u", invis, self.id)
end

setmetatable(local_rank, {
    __call = function(self, rank_name)
        local a = fQuery("SELECT id FROM JAAS_rank WHERE name='%s'", rank_name)
        if a then
            return setmetatable({id = a[1]["id"]}, {__index = local_rank})
        end
    end,
    __newindex = function() end,
	__metatable = nil
})

local rank = {["addRank"] = true, ["rankIterator"] = true, ["getMaxPower"] = true} -- Used for global functions, for rank table

function rank.addRank(name, power, invis)
    local next_position = fQuery("SELECT MAX(position) FROM JAAS_rank")
    if next_position then
        next_position = next_position[1]["position"]
        local a = fQuery("INSERT INTO JAAS_rank(name, position, power, invisible) VALUES ('%s', %u, %u, %s)", name, next_position*2, power, invis)
        if a then
            return local_rank(name)
        end
    end
end

function rank.safeRemoveRank()
end

function rank.forceRankShuffle()
end

function rank.rankIterator(key)
    local a = fQuery("SELECT * FROM JAAS_rank")
    local i = 0
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
    if keyExists(p_cache, code) then
        return p_cache[code]
    else
        local max = 0
        for t in rank.rankIterator() do
            if bit.band(code, bit.lshift(1, t.position)) > 0 and t.power > max then
                max = t.power
            end
        end
        p_cache[code] = max
        return max
    end
end

print "JAAS Rank Module - Loaded"