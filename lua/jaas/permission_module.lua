local permission = JAAS.Permission()

local noclip = permission.registerPermission("Noclip")
hook.Add("PlayerNoClip", "JAAS_noclipPermission", function (ply, desiredNoClipState)
    if noclip:codeCheck(ply:getJAASCode()) or !desiredNoClipState then
        return true
    end
    return false
end)

local pickup = permission.registerPermission("Pickup")
hook.Add("AllowPlayerPickup", "JAAS_pickupPermission", function (ply)
    if pickup:codeCheck(ply:getJAASCode()) then
        return true
    end
    return false
end)

local editVariables = permission.registerPermission("Can Edit Variables")
hook.Add("CanEditVariable", "JAAS_canEditVariablesPermission", function (ent, ply, key, val, editor)
    if editVariables:codeCheck(ply:getJAASCode()) then
        return true
    end
    return false
end)

local physgunPickupAllow = permission.registerPermission("Physgun Player Pickup Allow")
local rank = JAAS.Rank()
hook.Add("PhysgunPickup", "JAAS_physgunPickupAllowPermission", function (ply, ent)
    local user = ply:getJAASObject()
    if ent:IsPlayer() then
        if physgunPickupAllow:codeCheck(user:getCode()) and user:canTarget(ent:getJAASCode(), rank) then
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
    if canPlayerTaunt:codeCheck(ply:getJAASCode()) then
        return true
    end
    return false
end)

local canPlayerSpray = permission.registerPermission("Can Player Spray")
hook.Add("PlayerSpray", "JAAS_canPlayerSprayPermission", function (ply)
    if canPlayerSpray:codeCheck(ply:getJAASCode()) then
        return true
    end
    return false
end)

local canPickupItem = permission.registerPermission("Can Pickup Item")
hook.Add("PlayerCanPickupItem", "JAAS_canPickupItemPermission", function (ply, item)
    if canPickupItem:codeCheck(ply:getJAASCode()) then
        return true
    end
    return false
end)

local canPickupWeapon = permission.registerPermission("Can Pickup Weapon")
hook.Add("PlayerCanPickupWeapon", "JAAS_canPickupWeaponPermission", function (ply, wep)
    if canPickupWeapon:codeCheck(ply:getJAASCode()) then
        return true
    end
    return false
end)

local meta = FindMetaTable("Player")
local isAdmin = permission.registerPermission("Is Admin")
function meta:IsAdmin()
    return isAdmin:codeCheck(self:getJAASCode()) and true
end

local isSuperadmin = permission.registerPermission("Is Superadmin")
function meta:IsSuperAdmin()
    return isSuperadmin:codeCheck(self:getJAASCode()) and true
end