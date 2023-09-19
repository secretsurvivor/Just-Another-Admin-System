local MODULE, LOG, NET, SQL = JAAS.RegisterModule("Rank")

// Instead of having an automatically updating
local Rank_List = Rank_List or {} // [ID] = {1 = Name, 2 = Position, 3 = Power, 4 = Invisible, 5 = Group}
local List_Functions = {}

SQL:Create([[
	ID UNSIGNED INTEGER PRIMARY KEY,
	Name TEXT NOT NULL UNIQUE,
	Position UNSIGNED TINYINT NOT NULL UNIQUE CHECK (position > 0 AND position <= 32),
	Power UNSIGNED TINYINT DEFAULT 0,
	Invisible BOOL DEFAULT FALSE,
	Group UNSIGNED INT DEFAULT 0
]])

do // Rank List Code
	local List_Sync_Net = NET:RegisterNet("LIST__SYNC")

	function List_Functions:ModifyName(ID, name)
		if SQL:Update("Name = " .. name, "ID = " .. ID) then
			Rank_List[ID][1] = name

			List_Sync_Net:Broadcast(function ()
				net.WriteUInt(4, 4)
				net.WriteUInt(ID, 32)

				net.WriteTable{
					Name = name
				}
			end)

			JAAS.Hook.Rank.Call(ID, "Name", name)

			return true
		end

		return false
	end

	function List_Functions:ModifyPower(ID, power)
		if SQL:Update("Power = " .. power, "ID = " .. ID) then
			Rank_List[ID][3] = power

			List_Sync_Net:Broadcast(function ()
				net.WriteUInt(5, 4)
				net.WriteUInt(ID, 32)

				net.WriteTable{
					Power = power
				}
			end)

			JAAS.Hook.Rank.Call(ID, "Power", power)

			return true
		end

		return false
	end

	function List_Functions:ModifyInvisible(ID, invis)
		if SQL:Update("Invisible = " .. invis, "ID = " .. ID) then
			Rank_List[ID][4] = invis

			List_Sync_Net:Broadcast(function ()
				net.WriteUInt(6, 4)
				net.WriteUInt(ID, 32)

				net.WriteTable{
					Invisible = invis
				}
			end)

			JAAS.Hook.Rank.Call(ID, "Invisible", invis)

			return true
		end

		return false
	end

	function List_Functions:ModifyGroup(ID, group)
		if SQL:Update("Group = " .. group, "ID = " .. ID) then
			Rank_List[ID][5] = group

			List_Sync_Net:Broadcast(function ()
				net.WriteUInt(7, 4)
				net.WriteUInt(ID, 32)

				net.WriteTable{
					Group = group
				}
			end)

			JAAS.Hook.Rank.Call(ID, "Group", group)

			return true
		end

		return false
	end

	function List_Functions:AddRank(name, position, power, invisible)
		local count = SQL:SelectScalar("count(Name)")

		if count >= 32 then
			return false
		end

		// Max Position + 1
		//position = SQL:SelectScalar("max(Position)") + 1
		local ID = os.time()

		local c,v = "",""

		if power != nil then
			c = ", Power"
			v = ", " .. power
		end

		if invisible != nil then
			c = c .. ", Invisible"
			v = v .. ", " .. invisible
		end

		if SQL:Insert("ID, Name, Position" .. c, ID .. ", " .. name .. ", " .. position .. v) then
			Rank_List[ID] = {name, position, power or 0, invisible or false, 0}

			List_Sync_Net:Broadcast(function ()
				net.WriteUInt(1, 4)
				net.WriteUInt(ID, 32)

				net.WriteTable{
					Name = name,
					Position = position,
					Power = power,
					Invisible = invisible,
					Group = 0
				}
			end)

			MODULE.Hook("Add", ID, name, position, power or 0, invisible or false, 0)

			return true, ID
		end

		return false
	end

	function List_Functions:RemoveRank(ID)
		if Rank_List[ID] != nil then
			local position = Rank_List[ID][2]

			if SQL:Delete("ID = " .. ID) then
				Rank_List[ID] = nil

				for k,v in pairs(Rank_List) do
					if v[2] > position then
						Rank_List[k][2] = v[2] - 1
					end
				end

				List_Sync_Net:Broadcast(function ()
					net.WriteUInt(2, 4)
					net.WriteUInt(ID, 32)

					net.WriteTable{
						Position = position
					}
				end)

				local rshift, band, bxor = bit.rshift, bit.band, bit.bxor

				MODULE.Hook("Remove", function(code)
					if code == nil or code == 0 then
						return 0, false
					end

					// Position of the further left Bit
					local length = math.ceil(math.log(code, 2))

					// If the position is further left than the furthest left bit,
					// we don't need to modify it
					if position > length then
						return code, false
					end

					local mask = band(code, rshift(1, position - 1))

					if mask > 0 then
						return bxor(mask, code), true
					else
						return code, false
					end
				end)

				return true
			end
		end

		return false
	end

	function List_Functions:RemoveRanks(IDs)
		if !istable(IDs) then
			error("IDs must be in a table", 2)
		elseif !(#IDs < 1) then
			error("Table must be indexed", 2)
		end

		// An extra If statement will save resources as this will be slightly more
		// resource intensive compared with RemoveRank with a single Rank ID.
		// This should be less resource intensive when removing multiple Ranks
		// rather than using RemoveRank multiple times.
		if #IDs == 1 then
			return List_Functions:RemoveRank(IDs[1])
		end

		local valid_IDs = {}
		local invalid_IDs = {}
		local collective_bits = 0

		for k,ID in ipairs(IDs) do
			if Rank_List[ID] != nil and SQL:DeleteRank(ID, Rank_List[ID][2]) then
				local position = Rank_List[ID][2]

				valid_IDs[1 + #valid_IDs] = {
					ID = ID,
					position = position,
					code = bit.rshift(1, position - 1)
				}

				collective_bits = collective_bits + code

				Rank_List[ID] = nil

				// O(n^2)
				// I hate it, but I can't be bothered to improve it
				for k,v in pairs(Rank_List) do
					if v[2] > position then
						Rank_List[k][2] = v[2] - 1
					end
				end
			else
				invalid_IDs[1 + #invalid_IDs] = ID
			end
		end

		if #valid_IDs == 0 then
			return false, invalid_IDs
		end

		List_Sync_Net:Broadcast(function ()
			net.WriteUInt(3, 4)
			net.WriteUInt(0, 32)

			net.WriteTable({
				IDs = valid_IDs,
				Code = collective_bits
			})
		end)

		table.SortByMember(valid_IDs, "position")

		MODULE.Hook("Remove", function(code)
			if code == nil or code == 0 then
				return 0, false
			end

			local length = math.ceil(math.log(code, 2))

			if valid_IDs[#valid_IDs].position > length then
				return code, false
			end

			local mask = bit.band(code, collective_bits)

			if mask > 0 then
				return bit.bxor(code, mask), true
			else
				return code, true
			end
		end)

		return true
	end

	if CLIENT then // List Sync Receive Code
		List_Sync_Net:ReplaceReceiveParams(function (len, ply)
			local typ = net.ReadUInt(4)
			// 1 = Add {Name, Position, Power, Invisible, Group}
			// 2 = Remove {Position}
			// 3 = Multi-Remove {IDs}
			// 4 = Name {Name}
			// 5 = Power {Power}
			// 6 = Invisible {Invisible}
			// 7 = Group {Group}
			local ID = net.ReadUInt(32)

			return typ, ID, net.ReadTable()
		end)

		List_Sync_Net:Receive(function (typ, ID, data)
			if typ == 1 then // Add
				Rank_List[ID] = {data.Name, data.Position, data.Power, data.Invisible, data.Group}

				MODULE.Hook("Add", ID, data.Name, data.Position, data.Power, data.Invisible, data.Group)
			elseif typ == 2 then // Remove
				Rank_List[ID] = nil

				MODULE.Hook("Remove", false, ID)
			elseif typ == 3 then // Multi-Remove
				for k,v in ipairs(data.IDs) do
					Rank_List[v.ID] = nil
				end

				MODULE.Hook("Remove", true, data.IDs)
			elseif typ == 4 then // Name
				Rank_List[ID][1] = data.Name

				JAAS.Hook.Rank.Call(ID, "Name", data.Name)
			elseif typ == 5 then // Power
				Rank_List[ID][3] = data.Power

				JAAS.Hook.Rank.Call(ID, "Power", data.Power)
			elseif typ == 6 then // Invisible
				Rank_List[ID][4] = data.Invisible

				JAAS.Hook.Rank.Call(ID, "Invisible", data.Invisible)
			elseif typ == 7 then // Group
				Rank_List[ID][5] = data.Group

				JAAS.Hook.Rank.Call(ID, "Group", data.Group)
			end
		end)
	end

	do // Initial List Sync
		if SERVER then
			// Populate list with Database
			local Select_All = SQL:Select("*")

			for k,v in ipairs(Select_All) do
				Rank_List[v.ID] = {
					v.Name,
					v.Position,
					v.Power,
					v.Invisible,
					v.Group
				}
			end
		end

		local Init_Tbl_Sync_Net = NET:RegisterNet("INIT_TBL__SYNC")
		local Init_Tbl_Methods = {}

		function Init_Tbl_Methods.Write() // Server
			net.WriteCompressedTable(Rank_List)
		end

		function Init_Tbl_Methods.Read() // Client
			Rank_List = net.ReadCompressedTable()
		end

		Init_Tbl_Sync_Net:InitialSyncTable("RANK__LIST", Init_Tbl_Methods)
	end
end

local Rank_Structure = {}

do // Rank Object Code
	function Rank_Structure:GetID()
		return self.ID
	end

	function Rank_Structure:GetName()
		return Rank_List[self:GetID()][1]
	end

	function Rank_Structure:GetPosition()
		return Rank_List[self:GetID()][2]
	end

	function Rank_Structure:GetCode()
		return bit.rshift(1, self:GetPosition() - 1)
	end

	function Rank_Structure:GetPower()
		return Rank_List[self:GetID()][3]
	end

	function Rank_Structure:GetInvisible()
		return Rank_List[self:GetID()][4]
	end

	function Rank_Structure:GetGroup()
		return Rank_List[self:GetID()][5]
	end

	if SERVER then
		function Rank_Structure:SetName(name)
			return List_Functions:ModifyName(self.ID, name)
		end

		function Rank_Structure:SetPower(power)
			return List_Functions:ModifyPower(self.ID, power)
		end

		function Rank_Structure:SetInvisible(invis)
			return List_Functions:ModifyInvisible(self.ID, invis)
		end

		function Rank_Structure:SetGroup(group)
			return List_Functions:ModifyGroup(self.ID, group)
		end
	end

	function MODULE.Shared.Post(accessor)
		local Permission = accessor:GetModule("Permission")
		local Group = accessor:GetModule("Group")
		local Modify_Rank_Net = NET:RegisterNet("MODIFY__RANK")

		local CanModifyRank = Permission:RegisterPermission("Can Modify Rank")

		if CLIENT then
			function Rank_Structure:SetName(name)
				Modify_Rank_Net:SendToServer(function ()
					net.WriteUInt(1, 4)
					net.WriteUInt(self:GetID(), 32)
					net.WriteString(name)
				end)
			end

			function Rank_Structure:SetPower(power)
				Modify_Rank_Net:SendToServer(function ()
					net.WriteUInt(2, 4)
					net.WriteUInt(power, 16)
				end)
			end

			function Rank_Structure:SetInvisible(invis)
				Modify_Rank_Net:SendToServer(function ()
					net.WriteUInt(3, 4)
					net.WriteBool(invis)
				end)
			end

			function Rank_Structure:SetGroup(group)
				Modify_Rank_Net:SendToServer(function ()
					net.WriteUInt(4, 4)
					net.WriteUInt(group, 16)
				end)
			end
		end

		if SERVER then
			Modify_Rank_Net:Receive(function (len, ply)
				if CanModifyRank:Check(ply:GetCode()) then
					local typ = net.ReadUInt(4)
					local ID = net.ReadUInt(32)

					if typ == 1 then
						List_Functions:ModifyName(ID, net.ReadString())
					elseif typ == 2 then
						List_Functions:ModifyPower(ID, net.ReadUInt(16))
					elseif typ == 3 then
						List_Functions:ModifyInvisible(ID, net.ReadBool())
					elseif typ == 4 then
						List_Functions:ModifyGroup(ID, net.ReadUInt(16))
					end
				else
					MODULE:SendColouredConsole(ply, "^1JAAS : Rank^0 -> ^2Failed^0 modifying rank ^3(Missing [Can Modify Rank] permission)", Color(112, 48, 160), Color(228, 78, 78), Color(111, 111, 111))
				end
			end)
		end

		function Rank_Structure:GroupCheck(code)
			return Group:CheckValue("Rank", self:GetGroup(), code)
		end
	end

	function Rank_Structure:Remove()
		MODULE:RemoveRank(self.ID)
	end

	local o = {}

	function o.Constructor(ID)
		self.ID = ID
	end

	Rank_Structure = RegisterObject("Rank", o)
end

do // Rank Module Code
	if SERVER then
		function MODULE:AddRank(name, position, power, invisible)
			local r,ID = List_Functions:AddRank(name, position, power, invisible)

			if r then
				return Rank_Structure(ID)
			end

			error("Invalid Rank Parameters", 2)
		end

		function MODULE:RemoveRank(ID)
			return List_Functions:RemoveRank(ID)
		end

		function MODULE:RemoveRanks(IDs)
			return List_Functions:RemoveRanks(IDs)
		end
	end

	function MODULE.Shared.Post(accessor)
		local Permission = accessor:GetModule("Permission")
		local AddRemove_Net = NET:RegisterNet("ADD_REMOVE__RANK")

		local CanAddRemoveRanks = Permission:RegisterPermission("Can Add/Remove Rank")

		if CLIENT then
			function MODULE:AddRank(name, position, power, invisible)
				AddRemove_Net:SendToServer(function ()
					net.WriteUInt(1, 4)
					net.WriteString(name)
					net.WriteUInt(position, 6)
					net.WriteUInt(power, 16)
					net.WriteBool(invisible)
				end)
			end

			function MODULE:RemoveRank(ID)
				AddRemove_Net:SendToServer(function ()
					net.WriteUInt(2, 4)
					net.WriteUInt(ID, 32)
				end)
			end

			function MODULE:RemoveRanks(list_of_IDs)
				AddRemove_Net:SendToServer(function ()
					net.WriteUInt(3, 4)
					net.WriteTable(list_of_IDs)
				end)
			end
		end

		if SERVER then
			AddRemove_Net:Receive(function (len, ply)
				local typ = net.ReadUInt(4)

				if CanAddRemoveRanks:Check(ply:GetCode()) then
					if typ == 1 then
						List_Functions:AddRank(
							net.ReadString(),
							net.ReadUInt(6),
							net.ReadUInt(16),
							net.ReadBool()
						)
					elseif typ == 2 then
						List_Functions:RemoveRank(net.ReadUInt(32))
					elseif typ == 3 then
						List_Functions:RemoveRanks(net.ReadTable())
					end
				else
					local modifier = ""

					if typ == 1 then
						modifier = "adding"
					else
						modifier = "removing"
					end

					MODULE:SendColouredConsole(ply, "^1JAAS : Rank^0 -> ^2Failed^0 " .. modifier .. " rank ^3(Missing [Can Add/Remove Rank] permission)", Color(112, 48, 160), Color(228, 78, 78), Color(111, 111, 111))
				end
			end)
		end
	end

	function MODULE:GetRank(id)
		if Rank_List[id] == nil then
			error("Unknown Rank ID", 2)
		end

		return Rank_Structure(id)
	end

	// This is slower than GetRank, highly recommend you use that
	function MODULE:GetRankByName(name)
		local ID

		for k,v in pairs(Rank_List) do
			if v[1] == name then
				ID = k
				break
			end
		end

		if ID == nil then
			error("Unknown Name", 2)
		else
			return Rank_Structure(ID)
		end
	end

	function MODULE:IterateRank()
		local last_key

		return function ()
			last_key = next(Rank_List, last_key)

			if last_key != nil then
				return Rank_Structure(last_key)
			end
		end
	end

	function MODULE:IterateRankCode(code)
		if code == 0 then
			return function ()
				return
			end
		end

		local last_key

		return function ()
			while true do
				last_key = next(Rank_List, last_key)

				if last_key != nil then
					return
				end

				if bit.band(code, bit.rshift(1, Rank_List[last_key][2] - 1)) > 0 then
					return Rank_Structure(last_key)
				end
			end
		end
	end
end