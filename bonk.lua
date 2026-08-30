
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

local EggState = require(ReplicatedStorage.Client.EggState)
local Mutations = ReplicatedStorage:WaitForChild("Mutations")
local CarryRemote =
	ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]



local DROP_OFF_POSITION = Vector3.new(501.24, 70.49, -368.58)
local ARRIVE_DISTANCE = 2
local Lll = false
local lastCarryData = nil
local ActiveSession = nil


local LibraryUrl = "https://bonkhub.online/LibraryStandaloneLoader.lua"

local Success, Library = pcall(function()
	return loadstring(game:HttpGet(LibraryUrl))()
end)

if not Success or not Library then
	warn("Failed to load BONK HUB UI Library")
	return
end

local Window = Library:Window({
	Title = "BONK HUB",
	Subtitle = "V1.0.0 | 009.exe is cool",
	Icon = "rbxassetid://11262159835",
	ToggleIcon = "rbxassetid://11262159835",
	Watermark = "BONK HUB ",
	WatermarkEnabled = true,
	ToggleUiKey = Enum.KeyCode.RightControl,
	Size = { Width = 550, Height = 400 },
	SidebarWidth = 170,
	Splash = { Subtitle = "Loading ...", MinDuration = 1.2 },
	ConfigFile = "BonkHub",
	Theme = "Forest",
	KeySystem = { Enabled = false },
})

Window:Section("Egg Farm")

local MainTab = Window:Tab("Main", "user")
local GeneralPage = MainTab:SubTab("General")

local FarmGroup = GeneralPage:Groupbox("Egg Farming", "Left", "7733774602", "true")
local FilterGroup = GeneralPage:Groupbox("Egg Filters", "Right", "eye")


local function GetRoot()
	local Character = Player.Character or Player.CharacterAdded:Wait()
	return Character:FindFirstChild("HumanoidRootPart")
end

local function EggRecordExists(uid)
	if not uid then return false end
	return EggState.ReadFieldEgg(uid) ~= nil
end

local function IsCarryingUid(uid)
	if not uid then return false end
	return lastCarryData ~= nil
		and tostring(lastCarryData.Uid) == tostring(uid)
end

local function IsOwnedByMe(uid)
	if not uid then return false end
	return EggState.ReadOwnedEgg(Player.UserId, uid) ~= nil
end

local function GetEggByUid(uid)
	if not uid then return nil end

	local egg = Workspace:FindFirstChild(tostring(uid), true)
	if not egg then return nil end

	if egg:IsA("BasePart") then
		return egg
	elseif egg:IsA("Model") then
		return egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end


local SelectedEggZones = {}
local SelectedEggNames = {}
local SelectedMutations = {}

local function IsSelected(selection, value)
	if next(selection) == nil then return true end
	return selection[tostring(value)] == true
end

local function GetEggMutation(record)
	if not record then return "Unknown" end

	local mutation = record.Mutation
		or record.MutationName
		or record.MutationId
		or record.MutationType

	if mutation ~= nil then return tostring(mutation) end

	return "None"
end

local function GetMutationNames()
	local mutations = {}
	local seen = {}

	for _, folder in ipairs(Mutations:GetChildren()) do
		if folder:IsA("Folder") and not seen[folder.Name] then
			seen[folder.Name] = true
			table.insert(mutations, folder.Name)
		end
	end

	table.sort(mutations, function(a, b) return tostring(a) < tostring(b) end)
	return mutations
end

local function GetEggFilterData()
	local zones, names = {}, {}
	local zoneSet, nameSet = {}, {}

	local fieldData = EggState.ReadFieldEggs()

	if not fieldData or not fieldData.Records then
		return zones, names
	end

	for _, record in ipairs(fieldData.Records) do
		local zone = tostring(record.AreaId or "Unknown")
		local name = tostring(record.AssetCategory or "Unknown")

		if not zoneSet[zone] then
			zoneSet[zone] = true
			table.insert(zones, zone)
		end
		if not nameSet[name] then
			nameSet[name] = true
			table.insert(names, name)
		end
	end

	table.sort(zones, function(a, b) return tostring(a) < tostring(b) end)
	table.sort(names, function(a, b) return tostring(a) < tostring(b) end)

	return zones, names
end

local function GetFilteredEggs()
	local fieldData = EggState.ReadFieldEggs()

	if not fieldData or not fieldData.Records then
		return {}
	end

	local result = {}

	for _, record in ipairs(fieldData.Records) do
		local zone = tostring(record.AreaId or "Unknown")
		local name = tostring(record.AssetCategory or "Unknown")
		local mutation = GetEggMutation(record)

		if IsSelected(SelectedEggZones, zone)
			and IsSelected(SelectedEggNames, name)
			and IsSelected(SelectedMutations, mutation)
		then
			table.insert(result, record)
		end
	end

	return result
end

local function GetNearestFilteredEgg()
	local Root = GetRoot()
	if not Root then return nil, nil end

	local records = GetFilteredEggs()

	local nearestPart, nearestUid = nil, nil
	local nearestDistance = math.huge

	for _, record in ipairs(records) do
		local uid = tostring(record.Uid)
		local egg = Workspace:FindFirstChild(uid, true)

		if egg then
			local part = nil
			if egg:IsA("BasePart") then
				part = egg
			elseif egg:IsA("Model") then
				part = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
			end

			if part then
				local distance = (Root.Position - part.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestPart = part
					nearestUid = uid
				end
			end
		end
	end

	return nearestPart, nearestUid
end


local zones, names = GetEggFilterData()
local mutationNames = GetMutationNames()

local ZoneDropdown = FilterGroup:AddDropdown({
	Title = "Zone", Values = zones, Default = {}, Multi = true, Flag = "EggZones",
	Callback = function(Value) SelectedEggZones = Value or {} end,
})

local NameDropdown = FilterGroup:AddDropdown({
	Title = "Egg Name", Values = names, Default = {}, Multi = true, Flag = "EggNames",
	Callback = function(Value) SelectedEggNames = Value or {} end,
})

local MutationDropdown = FilterGroup:AddDropdown({
	Title = "Mutation", Values = mutationNames, Default = {}, Multi = true, Flag = "EggMutations",
	Callback = function(Value) SelectedMutations = Value or {} end,
})

FilterGroup:AddButton({
	Title = "Refresh Egg List",
	Callback = function()
		local newZones, newNames = GetEggFilterData()
		local newMutations = GetMutationNames()

		ZoneDropdown.Refresh(newZones)
		NameDropdown.Refresh(newNames)
		MutationDropdown.Refresh(newMutations)

		Library:Notify("Egg Filter", "Egg list refreshed!", 2)
	end,
})

FilterGroup:AddButton({
	Title = "Clear All Filters",
	Callback = function()
		SelectedEggZones = {}
		SelectedEggNames = {}
		SelectedMutations = {}

		ZoneDropdown.Set({})
		NameDropdown.Set({})
		MutationDropdown.Set({})

		Library:Notify("Egg Filter", "All filters cleared", 2)
	end,
})

local StatusParagraph = FarmGroup:AddParagraph({
	Title = "Egg Filter Status",
	Content = "Matching Eggs: 0\nFarming: Idle",
	TextWrapped = true,
})

task.spawn(function()
	while task.wait(0.5) do
		local filtered = GetFilteredEggs()
		if StatusParagraph then
			StatusParagraph:SetDesc(
				"Matching Eggs: " .. tostring(#filtered)
				.. "\nFarming: " .. (Lll and "Running" or "Idle")
			)
		end
	end
end)

-- =========================================================
-- RUN EGG SESSION
-- =========================================================

local function RunEggSession(uid)

	if not uid then
		return false
	end

	local character =
		Player.Character
		or Player.CharacterAdded:Wait()

	local rootPart =
		character:WaitForChild("HumanoidRootPart")

	local humanoid =
		character:WaitForChild("Humanoid")

	local maxSpeed = humanoid.WalkSpeed

	Lll = true

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	local oldVelocity = rootPart:FindFirstChild("SmoothBodyVelocity")
	if oldVelocity then
		oldVelocity:Destroy()
	end

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = "SmoothBodyVelocity"
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.P = 10000
	bodyVelocity.Parent = rootPart

	local sessionActive = true
	local success = false

	ActiveSession = {
		Stop = function()
			sessionActive = false
		end,
	}

	task.spawn(function()

		while sessionActive do

			if IsOwnedByMe(uid) then

				print("[RunEggSession] เป็นเจ้าของไข่แล้ว:", uid)

				success = true
				sessionActive = false

				break
			end

			if not EggRecordExists(uid) then

				print("[RunEggSession] ไข่หายไป:", uid)

				success = false
				sessionActive = false

				break
			end

			pcall(function()
				CarryRemote:InvokeServer({
					Uid = uid,
					FirstAreaSlotKey = nil,
				})
			end)

			task.wait()
		end
	end)

	local moveConn

	moveConn = RunService.Heartbeat:Connect(function(dt)

		if not sessionActive then
			moveConn:Disconnect()
			return
		end

		if not rootPart.Parent then
			sessionActive = false
			moveConn:Disconnect()
			return
		end

		local targetPosition

		if IsCarryingUid(uid) then
			targetPosition = DROP_OFF_POSITION
		else
			local eggPart = GetEggByUid(uid)
			if eggPart then
				targetPosition = eggPart.Position + Vector3.new(0, 3, 0)
			else
				bodyVelocity.Velocity = Vector3.zero
				return
			end
		end

		local offset = targetPosition - rootPart.Position
		local distance = offset.Magnitude

		if distance <= ARRIVE_DISTANCE then
			bodyVelocity.Velocity = Vector3.zero
			return
		end

		local maxTravelThisFrame =
			distance / math.max(dt, 1 / 240)

		local speed = math.min(maxSpeed, maxTravelThisFrame)

		if distance < maxSpeed then
			speed = math.min(speed, math.max(distance * 4, 4))
		end

		bodyVelocity.Velocity = offset.Unit * speed
	end)

	while sessionActive do
		task.wait()
	end

	if moveConn then
		moveConn:Disconnect()
	end

	if bodyVelocity then
		bodyVelocity.Velocity = Vector3.zero
		bodyVelocity:Destroy()
	end

	Lll = false

	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end

	ActiveSession = nil

	return success
end
local function FarmOneEgg()

	if Lll then
		print("[FarmOneEgg] Already farming")
		return
	end

	local Egg, EggUid = GetNearestFilteredEgg()

	if not Egg or not EggUid then
		print("[FarmOneEgg] ไม่พบไข่ที่ตรง Filter")
		task.wait(1)
		return
	end

	print("[FarmOneEgg] เลือกไข่:", EggUid)

	local success = RunEggSession(EggUid)

	if success then
		print("[FarmOneEgg] ได้ไข่แล้ว ->", EggUid)
	else
		print("[FarmOneEgg] พลาดไข่ ->", EggUid)
	end
end

-- =========================================================
-- CARRY STATE
-- =========================================================

EggState.CarryChanged:Connect(function(data)

	lastCarryData = data

	if data == nil then
		print("[CarryChanged] ไม่ได้ถือไข่แล้ว")
	else
		print("[CarryChanged] กำลังถือไข่ Uid:", data.Uid)
	end
end)

-- =========================================================
-- AUTO FARM TOGGLE
-- =========================================================

local AutoFarm = false
local FarmThread = nil

FarmGroup:AddToggle({
	Title = "Auto Steal egg ",
	Default = false,
	Flag = "AutoStealegg",

	Callback = function(Value)

		AutoFarm = Value

		if Value then

			if FarmThread then
				return
			end

			FarmThread = task.spawn(function()

				while AutoFarm do

					if not Lll then

						local egg = GetNearestFilteredEgg()

						if egg then
							FarmOneEgg()
						else
							task.wait(1)
						end

					else
						task.wait()
					end
				end

				FarmThread = nil
			end)

		else
			AutoFarm = false
		end
	end,
})

local function OnCharacterDied()

	if ActiveSession then
		ActiveSession.Stop()
	end

	Lll = false
end
local function HookDeath(character)

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(OnCharacterDied)
end

Player.CharacterAdded:Connect(function(newCharacter)
	OnCharacterDied()
	HookDeath(newCharacter)
end)
if Player.Character then
	HookDeath(Player.Character)
end
