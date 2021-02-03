local permission = JAAS.Permission()
local log = JAAS.Log "Core Permissions"

local noclip = permission.registerPermission("Noclip", "Player will be able to use the noclip command to activate noclip")
hook.Add("PlayerNoClip", "JAAS_noclipPermission", function (ply, desiredNoClipState)
    return noclip:codeCheck(ply:getJAASCode()) or !desiredNoClipState
end)

local pickup = permission.registerPermission("Pickup", "Player will be able to pick up objects with +USE")
hook.Add("AllowPlayerPickup", "JAAS_pickupPermission", function (ply, ent)
    if ent:IsPlayer() then
        return false
    end
    return pickup:codeCheck(ply:getJAASCode())
end)

local editVariables = permission.registerPermission("Can Edit Variables", "Player will be able to edit entity variables")
hook.Add("CanEditVariable", "JAAS_canEditVariablesPermission", function (_, ply)
    return editVariables:codeCheck(ply:getJAASCode())
end)

local physgunPickupAllow = permission.registerPermission("Physgun Player Pickup Allow", "Player will be able to pickup other players that they are able to target")
local physgunMapEntityPickupAllow = permission.registerPermission("Physgun Map Entity Pickup Allow", "Player will be able to pickup map created entities")
local globalPhysgunPickupAllow = permission.registerPermission("Physgun Pickup Allow", "Player will be able to pickup entities with Physgun")
hook.Add("PhysgunPickup", "JAAS_physgunPickupAllowPermission", function (ply, ent)
    if ent:IsPlayer() then
        if ent:IsBot() then
            return physgunPickupAllow:codeCheck(ply:getJAASCode())
        else
            return physgunPickupAllow:codeCheck(ply:getJAASCode()) and ply:canTarget(ent:getJAASCode())
        end
    else
        if ent:CreatedByMap() then
            return physgunMapEntityPickupAllow:codeCheck(ply:getJAASCode())
        else
            return globalPhysgunPickupAllow:codeCheck(ply:getJAASCode())
        end
    end
end)

local canPlayerTaunt = permission.registerPermission("Can Player Taunt", "Player will be able to taunt")
hook.Add("PlayerShouldTaunt", "JAAS_canPlayerTauntPermission", function (ply)
    return canPlayerTaunt:codeCheck(ply:getJAASCode())
end)

local canPlayerSpray = permission.registerPermission("Can Player Spray", "Player will be able to spray")
hook.Add("PlayerSpray", "JAAS_canPlayerSprayPermission", function (ply)
    return canPlayerSpray:codeCheck(ply:getJAASCode())
end)

local canPickupItem = permission.registerPermission("Can Pickup Item", "Player will be able to pickup items")
hook.Add("PlayerCanPickupItem", "JAAS_canPickupItemPermission", function (ply)
    return canPickupItem:codeCheck(ply:getJAASCode())
end)

local canPickupWeapon = permission.registerPermission("Can Pickup Weapon", "Player will be able to pickup weapons")
hook.Add("PlayerCanPickupWeapon", "JAAS_canPickupWeaponPermission", function (ply)
    return canPickupWeapon:codeCheck(ply:getJAASCode())
end)

local canSeeAllChatMessages = permission.registerPermission("Listen to Other Player's Chat", "Player will be able to see all chats be it team only or not.")
hook.Add("PlayerCanSeePlayersChat", "JAAS_canSeeAllChatMessages", function (text, teamOnly, listener, speaker)
    for k,ply in ipairs(player.GetAll()) do
        if canSeeAllChatMessages:codeCheck(ply:getJAASCode()) and listener != ply and speaker:IsValid() and ply:canTarget(listener:getJAASCode()) and ply:canTarget(speaker:getJAASCode()) then
            log:chatText(v, "%p to %p: %e", speaker:Nick(), listener:Nick(), text) -- secret_survivor to Dempsy40: Can you stop killing me!
        end
    end
end)

local ignoreDamage = permission.registerPermission("Ignore Damage", "Player won't be able to take damage")
hook.Add("PlayerShouldTakeDamage", "JAAS_allowDamage", function (ply)
    return !ignoreDamage:codeCheck(ply:getJAASCode())
end)

local ignoreFallDamage = permission.registerPermission("Ignore Fall Damage", "Player will ignore all fall damage")
hook.Add("GetFallDamage", "JAAS_ignoreFallDamage", function (ply)
    if ignoreFallDamage:codeCheck(ply:getJAASCode()) then
        return 0
    end
end)

local canSuicide = permission.registerPermission("Can Suicide", "Player will be able to kill themself")
hook.Add("CanPlayerSuicide", "JAAS_canSuicide", function (ply)
    return canSuicide:codeCheck(ply:getJAASCode())
end)

local canFlashlight = permission.registerPermission("Can Use Flashlight", "Player will be able to use their flashlight")
hook.Add("PlayerSwitchFlashlight", "JAAS_CanUseFlashlight", function (ply, enabled)
    return canFlashlight:codeCheck(ply:getJAASCode())
end)

local gravGunPickup = permission.registerPermission("Gravity Gun Pickup", "Player will be able to pick up entities with the Gravity Gun")
local gravGunPlayerPickup = permission.registerPermission("Gravity Gun Player Pickup", "Player will be able to pickup players with Gravity Gun")
hook.Add("GravGunPickupAllowed", "JAAS_gravGunPickup", function (ply, ent)
    if ent:IsPlayer() then
        if ent:IsBot() then
            return gravGunPlayerPickup:codeCheck(ply:getJAASCode())
        else
            return gravGunPlayerPickup:codeCheck(ply:getJAASCode()) and ply:canTarget(ent:getJAASCode())
        end
    else
        if !ent:CreatedByMap() then
            return gravGunPickup:codeCheck(ply:getJAASCode())
        end
    end
end)

local canGravGunPunt = permission.registerPermission("Can Gravity Gun Punt", "Player will be able to punt entities with the Gravity Gun (Primary Fire)")
hook.Add("GravGunPunt", "JAAS_canGravGunPunt", function (ply, ent)
    if !ent:CreatedByMap() then
        return canGravGunPunt:codeCheck(ply:getJAASCode())
    end
end)

local canUndo = permission.registerPermission("Can Undo", "Player will be able to undo spawned entities")
hook.Add("CanUndo", "JAAS_CanUndo", function (ply)
    return canUndo:codeCheck(ply:getJAASCode())
end)

local meta = FindMetaTable("Player")

local isSuperadmin = permission.registerPermission("Is Superadmin", "Player be apart of the superadmin usergroup")
function meta:IsSuperAdmin()
    return isSuperadmin:codeCheck(self:getJAASCode())
end

local isAdmin = permission.registerPermission("Is Admin", "Player will be apart of the admin usergroup")
function meta:IsAdmin()
    return isAdmin:codeCheck(self:getJAASCode()) or isSuperadmin:codeCheck(self:getJAASCode())
end