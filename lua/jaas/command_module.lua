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
end)