local permission = JAAS.Permission()

local noclip = permission.registerPermission("Noclip", "Player will be able to use the noclip command to activate noclip")
hook.Add("PlayerNoClip", "JAAS_noclipPermission", function (ply, desiredNoClipState)
    return noclip:codeCheck(ply:getJAASCode()) or !desiredNoClipState
end)

local pickup = permission.registerPermission("Pickup", "Player will be able to pick up objects")
hook.Add("AllowPlayerPickup", "JAAS_pickupPermission", function (ply)
    return pickup:codeCheck(ply:getJAASCode())
end)

local editVariables = permission.registerPermission("Can Edit Variables", "Player will be able to edit entity variables")
hook.Add("CanEditVariable", "JAAS_canEditVariablesPermission", function (ent, ply, key, val, editor)
    return editVariables:codeCheck(ply:getJAASCode())
end)

local physgunPickupAllow = permission.registerPermission("Physgun Player Pickup Allow", "Player will be able to pickup other players that they are able to target")
hook.Add("PhysgunPickup", "JAAS_physgunPickupAllowPermission", function (ply, ent)
    local user = ply:getJAASObject()
    if ent:IsPlayer() then
        if physgunPickupAllow:codeCheck(user:getCode()) and user:canTarget(ent:getJAASCode()) then
            return true
        end
    elseif ent:IsBot() then
        if physgunPickupAllow:codeCheck(user:getCode()) then
            return true
        end
    end
end)

local canPlayerTaunt = permission.registerPermission("Can Player Taunt", "Player will be able to taunt")
hook.Add("PlayerShouldTaunt", "JAAS_canPlayerTauntPermission", function (ply, act)
    return canPlayerTaunt:codeCheck(ply:getJAASCode())
end)

local canPlayerSpray = permission.registerPermission("Can Player Spray", "Player will be able to spray")
hook.Add("PlayerSpray", "JAAS_canPlayerSprayPermission", function (ply)
    return canPlayerSpray:codeCheck(ply:getJAASCode())
end)

local canPickupItem = permission.registerPermission("Can Pickup Item", "Player will be able to pickup items")
hook.Add("PlayerCanPickupItem", "JAAS_canPickupItemPermission", function (ply, item)
    return canPickupItem:codeCheck(ply:getJAASCode())
end)

local canPickupWeapon = permission.registerPermission("Can Pickup Weapon", "Player will be able to pickup weapons")
hook.Add("PlayerCanPickupWeapon", "JAAS_canPickupWeaponPermission", function (ply, wep)
    return canPickupWeapon:codeCheck(ply:getJAASCode())
end)

local meta = FindMetaTable("Player")
local isAdmin = permission.registerPermission("Is Admin", "Player will be apart of the admin usergroup")
function meta:IsAdmin()
    return isAdmin:codeCheck(self:getJAASCode())
end

local isSuperadmin = permission.registerPermission("Is Superadmin", "Player be apart of the superadmin usergroup")
function meta:IsSuperAdmin()
    return isSuperadmin:codeCheck(self:getJAASCode())
end