local dev = JAAS.Dev()
local log = JAAS.Log("Command Module")
local command = JAAS.Command()
local argTable = command.argumentTableBuilder()

command:setCategory("Test")

command:registerCommand("Bacon", function (ply)
	if IsValid(ply) then
		ply:Say "Bacon"
	end
	print "Bacon"
end)

command:registerCommand("Add", function (ply, a, b)
	print(a + b)
	return a + b
end, argTable:add("Num_1", "INT", true, 0):add("Num_2", "INT", true, 0):dispense())

command:registerCommand("God", function(ply)
	if IsValid(ply) then
		if ply:HasGodMode() then
			ply:GodDisable()
			log:chatLog(ply:Nick().." no longer has Godmode")
		else
			ply:GodEnable()
			log:chatLog(ply:Nick().." has Godmode")
		end
	end
end, nil, 1)

command:registerCommand("Kill", function (ply, target)
	if IsValid(target) and target:Alive() then
		target:Kill()
	elseif ply:Alive() then
		ply:Kill()
	end
end, argTable:add("Target", "PLAYER"):dispense(), 2)

local listBots = {}
command:registerCommand("CreateBot", function (ply)
	if ( !game.SinglePlayer() && player.GetCount() < game.MaxPlayers() ) then
        local num = #listBots
        listBots[ num ] = player.CreateNextBot("Bot_" .. ( num + 1 ) )
    else
	    print( "Can't create bot!" )
    end
end, nil, 1)

command:registerCommand("SetRunSpeed", function (ply, speed, target)
	if IsValid(target) then
		target:SetRunSpeed(speed)
	end
end, argTable:add("Speed", "INT"):add("Target", "PLAYER"):dispense(), 1)