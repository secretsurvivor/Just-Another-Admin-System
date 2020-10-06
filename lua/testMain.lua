JAAS = JAAS or {}
include("testCommand.lua")
include("testPermission.lua")
include("testDev.lua")

local cmd = JAASCommand()
local cmdb = JAASCommand()
local perm = JAASPermission()
//local rank = JAASRank()
local arg = cmd.ArgumentTable()

//local tmod = rank:add("Trial Mod", 1)
//local mod = rank:add("Moderator", 2)
//local admin = rank:add("Administrator", 3)
//local vip = rank:add("VIP")

local tmodRank = math.BinToInt("00000001")
local modRank = math.BinToInt("00000010")
local adminRank = math.BinToInt("00000100")
local mangerRank = math.BinToInt("00001000")
local ownerRank = math.BinToInt("00010000")
local allRanks = bit.bor(tmodRank, modRank, adminRank, mangerRank, ownerRank)

cmd:add("secret", function() print("Hello secret") end, {}, bit.bor(tmodRank, modRank, adminRank))
cmd:add("dempsy", function() print("Hello Dempsy") end, {}, 64)
cmd:setCategory("Admin")
cmd:add("test", function(ply, args, argStr) print(string.format("Hello %s", args[1])) end, arg:add("Name", "STRING"):dispense())
cmd:add("steamid", function(ply, args, argStr)
	print(string.format("SteamID of %s is: %s", argStr, args[1]:SteamID()))
end, arg:add("Player", "PLAYER"):dispense())
cmdb:add("add", function(ply, args, argStr)
	print(string.format("%s + %s = %s", args[1], args[2], args[1] + args[2]))
end, arg:add("Num1", 2):add("Num2", 2):dispense())
cmd.printCategories()

print(cmd.exist("vallorz"))
print(cmd.get("secret")[4])
print(cmd.get("dempsy")[4])


local noclipPerm = perm:add("noclip", function(self) print(string.format("Code: %s", self.code)) end, allRanks)
--noclipPerm:execute()

local skip = JAASPermission("noclip")
skip:execute()