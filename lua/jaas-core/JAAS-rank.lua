if !sql.TableExists("JAAS_rank") then
	sql.Query("CREATE TABLE JAAS_rank(id UNSIGNED INT NOT NULL UNIQUE, name TEXT NOT NULL UNIQUE, position UNSIGNED TINYINT(255) NOT NULL UNIQUE CHECK (position != 0), power UNSIGNED TINYINT(255) DEFAULT 0, invisible BOOL DEFAULT FALSE, PRIMARY KEY (id))")
end

local local_rank = {} -- Used for local functions, for rank data

function local_rank:getName()
    local name = fQuery("SELECT name FROM JAAS_rank WHERE id=%u", self.id)
    if istable(name) then
        return name[1]["name"]
    end
end

function local_rank:setName(name)
    return fQuery("UPDATE JAAS_rank SET name='%s' WHERE id=%u", name, self.id)
end

function local_rank:getCodePosition()
    local position = fQuery("SELECT position FROM JAAS_rank WHERE id=%u", self.id)
    if istable(position) then
        return position[1]["position"]
    end
end

function local_rank:getCode()
    local position = fQuery("SELECT position FROM JAAS_rank WHERE id=%u", self.id)
    if istable(position) then
        position = position[1]["position"]
        return bit.lshift(1, position)
    end
end

function local_rank:getPower()
    local power = fQuery("SELECT power FROM JAAS_rank WHERE id=%u", self.id)
    if istable(power) then
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
    if istable(invis) then
        return invis[1]["invisible"]
    end
end

function local_rank:setInvis(invis)
    return fQuery("UPDATE JAAS_rank SET invisible=%s WHERE id=%u", invis, self.id)
end

setmetatable(local_rank, {
    __call = function(self, rank_name)
        local rank_object = {}
        local a = fQuery("SELECT id FROM JAAS_rank WHERE name='%s'", rank_name)
        if istable(a) then
            rank_object.id = a[1]["id"]
            setmetatable(rank_object, {__index = local_rank})
            return rank_object
        end
    end,
    __newindex = function() end,
	__metatable = nil
})

local rank = {} -- Used for global functions, for rank table

function rank.addRank(name, power, invis)
    local next_position = fQuery("SELECT MAX(position) FROM JAAS_rank")
    if istable(next_position) then
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
    local test, err = pcall(function(code) local p = p_cache[code] end, code)
    if not(err and true) then
        return p_cache[code]
    else
        local a = fQuery("SELECT position, power FROM JAAS_rank")
        local max = 0
        for k,v in pairs(a) do
            if bit.band(code, bit.lshift(1, v["position"])) > 0 and v["power"] > max then
                max = v["power"]
            end
        end
        p_cache[code] = max
        return max
    end
end

print("JAAS Rank Module Loaded")