local MODULE, log, dev, SQL = JAAS:RegisterModule "Rank"
SQL = SQL"JAAS_rank"
local RankHook = JAAS.Hook.Run "Rank"
local RankHookAdd = JAAS.Hook "Rank"

if !SQL.EXIST and SERVER then
    SQL.CREATE.TABLE {
        name = "TEXT NOT NULL UNIQUE",
        position = "UNSIGNED TINYINT NOT NULL UNIQUE CHECK (position != 0 AND position <= 64)",
        power = "UNSIGNED TINYINT DEFAULT 0",
        invisible = "BOOL DEFAULT FALSE",
        access_group = "UNSIGNED INT DEFAULT 0"
    }
end

local local_rank = {["getName"] = true, ["setName"] = true, ["getCodePosition"] = true, ["getCode"] = true, ["accessCheck"] = true} -- Used for local functions, for rank data

local r_cache = dev.Cache()
RankHookAdd "GlobalChange" ["Rank_module_cache"] = function ()
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

local HookGlobalChange = RankHook "GlobalChange"

function local_rank:setName(name)
    if SQL.UPDATE {name = name} {rowid = self.id} then
        HookGlobalChange()
        RankHook "GlobalNameChange" (self.id, name)
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
            r_cache[self.id].position = tonumber(position["position"])
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
            r_cache[self.id].code = tonumber(position["1 << (position - 1)"])
            return position["1 << (position - 1)"]
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

            r_cache[self.id].power = tonumber(power["power"])
            return power["power"]
        end
    end
end

function local_rank:setPower(power)
    if SQL.UPDATE {power = power} {rowid = self.id} then
        HookGlobalChange()
        RankHook "GlobalPowerChange" (self.id, power)
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
        HookGlobalChange()
        RankHook "GlobalInvisChange" (self.id, invis)
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
            r_cache[self.id].access = tonumber(access["access_group"])
            return r_cache[self.id].access
        end
    end
end


function local_rank:setAccess(value)
    if dev.isAccessObject(value) then
        value = value:getValue()
    end
    if SQL.UPDATE {access_group = value} {rowid = self.id} then
        HookGlobalChange()
        RankHook "GlobalAccessChange" (self.id, value)
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
        elseif isnumber(rank_name) and SQL.SELECT "rowid" {rowid = rank_name} then
            return setmetatable({id = rank_name}, {__index = local_rank, __metatable = "jaas_rank_object"})
        end
        return false
    end,
    __newindex = function()
    end,
	__metatable = "jaas_rank_object"
})

local rank = {["addRank"] = true, ["rankIterator"] = true, ["getMaxPower"] = true, ["codeIterator"] = true} -- Used for global functions, for rank table
local rank_count = tonumber(SQL.SELECT "COUNT(rowid)" () ["COUNT(rowid)"])

function rank.addRank(name, power, invis)
    if rank_count < 32 then
        local t = SQL.SELECT "MAX(position)"()
        if t then
            local next_position = t["MAX(position)"]
            if next_position == "NULL" then
                next_position = 0
            end
            power = power or 0
            invis = invis or false
            if SQL.INSERT {name = name, position = 1 + next_position, power = power, invisible = invis} then
                rank_count = 1 + rank_count
                local rank_object = local_rank(name)
                RankHook "Added" (rank_object.id, name, power, invis, 1 + next_position)
                return rank_object
            end
        end
    end

end

function rank.rankIterator(key)
    local a = SQL.SELECT "rowid, name, position, power, invisible, access_group" ()
    if istable(a) and #a == 0 then
        a = {a}
    end
    local i = 0
    if a then
        if key then
            return function ()
                i = 1 + i
                if a[i] then
                    return a[i][key]
                end
            end
        end
        return function ()
            i = 1 + i
            if a[i] then
                return a[i]
            end
        end
    end
    return function ()
        return nil
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
                    e = !e
                    return SQL.SELECT "*" {position = max_bits}
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
        local rank_object = local_rank(name)
        if rank_object then
            rank_position = tonumber(rank_object:getCodePosition())
            q = SQL.DELETE {name = name}
            if q then
                RankHook "Removed" (rank_object.id)
            end
        end
    elseif isnumber(name) then
        rank_position = tonumber(SQL.SELECT "position" {rowid = name}["position"])
        q = SQL.DELETE {rowid = name}
        if q then
            RankHook "Removed" (name)
        end
    elseif dev.isRankObject(name) then
        rank_position = tonumber(name:getCodePosition())
        q = SQL.DELETE {rowid = name.id}
        if q then
            RankHook "Removed" (name.id)
        end
    end
    if q then
        rank_count = rank_count - 1
        local rank_code = bit.lshift(1, rank_position - 1)
        local error, message = RankHook "RemovePosition" (function (bit_code)
            if bit_code > 0 then
                local bit_length = math.ceil(math.log(bit_code, 2))
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
        if !error then
            print(message)
        end
        SQL.UPDATE "position = position - 1" ("position > "..tostring(rank_position))
        sql.Commit()
        HookGlobalChange()
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
                    local rank_object = local_rank(v)
                    if rank_object then
                        rank_position = rank_object:getCodePosition()
                        if SQL.DELETE {name = v} then
                            code_to_remove = code_to_remove + bit.lshift(1, v[2])
                            rank_code_count = 1 + rank_code_count
                            rank_count = rank_count - 1
                            RankHook "Removed" (rank_object.id)
                        end
                    end
                elseif isnumber(v) then
                    rank_position = tonumber(SQL.SELECT "position" {rowid = v}["position"])
                    if rank_position and SQL.DELETE {id = v} then
                        code_to_remove = code_to_remove + bit.lshift(1, v[2])
                        rank_code_count = 1 + rank_code_count
                        rank_count = rank_count - 1
                        RankHook "Removed" (v)
                    end
                elseif dev.isRankObject(v) then
                    rank_position = v:getCodePosition()
                    if SQL.DELETE {rowid = v.id} then
                        code_to_remove = code_to_remove + bit.lshift(1, v[2])
                        rank_code_count = 1 + rank_code_count
                        rank_count = rank_count - 1
                        RankHook "Removed" (v.id)
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
            HookGlobalChange()
            return true
        end
    else
        return rank.removeRank(rankPositions[1])
    end
end

local p_cache = dev.Cache()

RankHookAdd "GlobalPowerChange" ["MaxPowerCacheClean"] = function()
    p_cache()
end

function rank.getMaxPower(code)
    if code == 0 then
        return 0
    end
    if p_cache[code] ~= nil then
        return p_cache[code]
    else
        local q,max = SQL.SELECT "MAX(power)" ("code & ".. code .." > 0"),0

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
    rank_name = string.Trim(SQL.ESCAPE(rank_name), "'")
    if rank_name then
        local a = SQL.SELECT "rowid" {name = rank_name}
        if a then
            return local_rank(tonumber(a["rowid"]))
        else
            return false
        end
    end
    return setmetatable({}, {__index = rank, __newindex = function () end, __metatable = "jaas_rank_library"})
end)

dev:isTypeFunc("RankObject","jaas_rank_object")
dev:isTypeFunc("RankLibrary","jaas_rank_library")

util.AddNetworkString "JAAS_RankUpdate"

RankHookAdd "Removed" ["PlayerUpdateRemove"] = function (id)
    net.Start "JAAS_RankUpdate"
    net.WriteUInt(1, 3)
    net.WriteFloat(id)
    net.Broadcast()
end

RankHookAdd "GlobalNameChange" ["PlayerUpdateName"] = function (id, name)
    net.Start "JAAS_RankUpdate"
    net.WriteUInt(2, 3)
    net.WriteFloat(id)
    net.WriteString(name)
    net.Broadcast()
end

RankHookAdd "GlobalPowerChange" ["PlayerUpdatePower"] = function (id, power)
    net.Start "JAAS_RankUpdate"
    net.WriteUInt(3, 3)
    net.WriteFloat(id)
    net.WriteUInt(power, 8)
    net.Broadcast()
end

RankHookAdd "GlobalInvisChange" ["PlayerUpdateInvis"] = function (id, invis)
    net.Start "JAAS_RankUpdate"
    net.WriteUInt(4, 3)
    net.WriteFloat(id)
    net.WriteBool(invis)
    net.Broadcast()
end

RankHookAdd "GlobalAccessChange" ["PlayerUpdateAccess"] = function (id, access)
    net.Start "JAAS_RankUpdate"
    net.WriteUInt(5, 3)
    net.WriteFloat(id)
    net.WriteFloat(access)
    net.Broadcast()
end

log:registerLog {1, 6, "created", 2} -- [1] secret_survivor created Moderator
log:registerLog {1, 6, "deleted", 2} -- [2] secret_survivor deleted T-Mod
log:registerLog {1, 6, "set", "power to", 4, "on", 2} -- [3] secret_survivor set power to 3 on Moderator
log:registerLog {1, 6, "set", "invisible to", 5, "on", 2} -- [4] secret_survivor set invisible to true on Trusted
log:registerLog {1, 6, "set", "access value to", 4, "on", 2} -- [5] secret_survivor set access value to 2 on Manager
log:registerLog {1, 6, "attempted", "to modify a rank"} -- [6] Dempsy40 attempted to modify a rank

MODULE.Handle.Server(function (jaas)

    local perm = jaas.Permission()
    local modify_rank = perm.registerPermission("Can Modify Rank Table", "Player will be able to modify the rank table - this is required to add, remove, and modify existing ranks")
    local showInvisibleRanks = perm.registerPermission("Show Invisible Ranks", "This permission will show invisible ranks clientside")

    util.AddNetworkString "JAAS_ModifyRank_Channel"
    /*
        0 :: Modify Successful
        1 :: Could not modify
        2 :: Invalid Rank Identifier
        3 :: Unknown modify code
    */
    local sendFeedback = dev.sendUInt("JAAS_ModifyRank_Channel", 2)

    net.Receive("JAAS_ModifyRank_Channel", function (len, ply)
        if modify_rank:codeCheck(ply) then
            local sendCode = sendFeedback(ply)
            local modifyCase = dev.SwitchCase()
            modifyCase:case(0, function () -- Add Rank
                local name = sql.SQLStr(net.ReadString(), true)
                local power = net.ReadUInt(8)
                local invis = net.ReadBool()
                if rank.addRank(name, power, invis) then
                    log:superadminChat("%p created %r", ply:Nick(), name)
                    log:Log(1, {player = {ply}, rank = {name}})
                    return 0
                end
                return 1
            end)
            modifyCase:case(1, function () -- Remove Rank
                local name = string.Trim(SQL.ESCAPE(net.ReadString()), "'")
                if rank.removeRank(name) then
                    log:Log(2, {player = {ply}, rank = {name}})
                    log:superadminChat("%p removed %r", ply:Nick(), name)
                    return 0
                end
                return 1
            end)
            modifyCase:case(2, function () -- Remove Ranks
                local len,t = net.ReadUInt(32),{}
                for i=1,len do
                    t[i] = net.ReadString()
                end
                if rank.removeRanks(unpack(t)) then
                    for k,v in ipairs(t) do
                        log:Log(2, {player = {ply}, rank = {v}})
                        log:superadminChat("%p removed %r", ply:Nick(), v)
                    end
                    return 0
                end
                return 1
            end)
            modifyCase:case(3, function () -- Set Power
                local rnk = jaas.Rank(net.ReadString())
                local power = net.ReadUInt(8)
                if dev.isRankObject(rnk) then
                    if rnk:setPower(power) then
                        log:Log(3, {player = {ply}, rank = {rnk}, data = {power}})
                        log:superadminChat("%p set %r's power to %d", ply:Nick(), rnk:getName(), power)
                        return 0
                    end
                    return 1
                end
                return 2
            end)
            modifyCase:case(4, function () -- Set Invisible
                if showInvisibleRanks:codeCheck(ply) then
                    local rnk = jaas.Rank(net.ReadString())
                    local invis = net.ReadBool()
                    if dev.isRankObject(rnk) then
                        if rnk:setInvis(invis) then
                            log:Log(4, {player = {ply}, rank = {rnk}, string = {invis}})
                            if invis then
                                log:superadminChat("%p made %r invisible", ply:Nick(), rnk:getName())
                            else
                                log:superadminChat("%p made %r not invisible", ply:Nick(), rnk:getName())
                            end
                            return 0
                        end
                        return 1
                    end
                    return 2
                end
            end)
            modifyCase:case(5, function () -- Set Access Value
                local rnk = jaas.Rank(net.ReadString())
                local value = net.ReadUInt(16)
                if dev.isRankObject(rnk) then
                    if rnk:setAccess(value) then
                        log:Log(5, {player = {ply}, rank = {rnk}, data = {value}})
                        log:superadminChat("%p set %r's access value to %d", ply:Nick(), rnk:getName(), value)
                        return 0
                    end
                    return 1
                end
                return 2
            end)
            modifyCase:default(3)
            local channel_type = net.ReadUInt(3)
            sendCode(modifyCase:switch(channel_type))
        else
            log:Log(6, {player = {ply}})
            log:superadminChat("%p attempted to modify a rank", ply:Nick())
        end
    end)

    util.AddNetworkString "JAAS_RankPullChannel"

    net.Receive("JAAS_RankPullChannel", function (len, ply)
        local r = {}
        local canSee = showInvisibleRanks:codeCheck(ply)
        for t in rank.rankIterator() do
            if !t.invisible or canSee then
                r[tonumber(t.rowid)] = t
            end
        end
        net.Start "JAAS_RankPullChannel"
            net.WriteTable(r)
        net.Send(ply)
    end)

    RankHookAdd "Added" ["PlayerUpdateAdd"] = function (id, name, power, invis, position)
        for k,ply in ipairs(player.GetAll()) do
            if showInvisibleRanks:codeCheck(ply) then
                net.Start "JAAS_RankUpdate"
                net.WriteUInt(0, 3)
                net.WriteFloat(id)
                net.WriteTable({rowid = id, name = name, power = power, invisible = invis, position = position, access_group = 0})
                net.Send(ply)
            end
        end
    end
end)

log:print "Module Loaded"