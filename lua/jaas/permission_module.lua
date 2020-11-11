local permission = JAAS.Permission()

local noclip = permission.registerPermission("Noclip")
hook.Add("PlayerNoClip", "JAAS_noclipPermission", function (ply, desiredNoClipState)
    local code = JAAS.Player(ply):getCode()
    if noclip:codeCheck(code) or !desiredNoClipState then
        return true
    end
    return false
end)

local pickup = permission.registerPermission("Pickup")
hook.Add("AllowPlayerPickup", "JAAS_pickupPermission", function (ply)
    local code = JAAS.Player(ply):getCode()
    if pickup:codeCheck(code) then
        return true
    end
    return false
end)

local editVariables = permission.registerPermission("Can Edit Variables")
hook.Add("CanEditVariable", "JAAS_canEditVariablesPermission", function (ent, ply, key, val, editor)
    local code = JAAS.Player(ply):getCode()

end)

local gravGunPickup = permission.registerPermission("Gravity Gun Pickup")
hook.Add("GravGunPickupAllowed", "JAAS_gravGunPickupPermission", function (ply, ent)
end)

local physgunPickupAllow = permission.registerPermission("Physgun Player Pickup Allow")
local rank = JAAS.Rank()
hook.Add("PhysgunPickup", "JAAS_physgunPickupAllowPermission", function (ply, ent)
    local user = JAAS.Player(ply)
    if ent:IsPlayer() then
        local target = JAAS.Player(ent)
        if physgunPickupAllow:codeCheck(user:getCode()) and user:canTarget(target:getCode(), rank) then
            return true
        end
    elseif ent:IsBot() then
        if physgunPickupAllow:codeCheck(user:getCode()) then
            return true
        end
    end
end)

local canPlayerTaunt = permission.registerPermission("Can Player Taunt")
hook.Add("PlayerShouldTaunt", "JAAS_canPlayerTauntPermission", function (ply, act)
end)

local canPlayerSpray = permission.registerPermission("Can Player Spray")
hook.Add("PlayerSpray", "JAAS_canPlayerSprayPermission", function (ply)
end)

local canPickupItem = permission.registerPermission("Can Pickup Item")
hook.Add("PlayerCanPickupItem", "JAAS_canPickupItemPermission", function (ply, item)
end)

local canPickupWeapon = permission.registerPermission("Can Pickup Weapon")
hook.Add("PlayerCanPickupWeapon", "JAAS_canPickupWeaponPermission", function (ply, wep)
end)

local isAdmin = permission.registerPermission("Is Admin")
local isSuperadmin = permission.registerPermission("Is Superadmin")
