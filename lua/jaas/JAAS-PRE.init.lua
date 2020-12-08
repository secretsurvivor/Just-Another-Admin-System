if JAAS_PRE_HOOK.Command then
    local cmd = JAAS.Command()
    for k,v in pairs(JAAS_PRE_HOOK.Command) do
        cmd:setCategory(k)
        for _,c in ipairs(v) do
            cmd:registerCommand(c[1], c[2], c[3], c[4], c[5], c[6])
        end
    end
    JAAS_PRE_HOOK.Command = nil
end

if JAAS_PRE_HOOK.Permission and SERVER then
    local perm = JAAS.Permission()
    for k,v in ipairs(JAAS_PRE_HOOK.Permission) do
        perm.registerPermission(v[1], v[2], v[3], v[4])
    end
    JAAS_PRE_HOOK.Permission = nil
end

JAAS_PRE_HOOK = {Active = true}
hook.Remove("PostGamemodeLoaded", "JAAS_PRE_HOOK_CLEANUP")