local permission = JAAS.Permission()

local noclip = permission.registerPermission("noclip"):getCode()

hook.Add("PlayerNoClip", "JAAS_noclipPermission", function (ply, desiredNoClipState)
    local code = JAAS.Player(ply):getCode()
    if bit.band(code, noclip) > 0 or !desiredNoClipState then
        return true
    end
    return false
end)