-- =========================================================
-- BONK HUB | EGG FARM
-- =========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

local EggState = require(ReplicatedStorage.Client.EggState)
local Mutations = ReplicatedStorage:WaitForChild("Mutations")
local CarryRemote = ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]

local DROP_OFF_POSITION = Vector3.new(501.24, 70.49, -368.58)
local ARRIVE_DISTANCE = 3

local TweenSpeed = 700
local OriginalWalkSpeed = 16

local Lll = false
local AutoFarm = false
local NeedInitialDropOff = false

local lastCarryData = nil
local ActiveSession = nil
local FarmThread = nil
local cache = nil
local currentBodyVelocity = nil
local noclipConnection = nil
local SpawnPosition = nil

local AutoFarmToggle = nil

local ZoneDropdown
local NameDropdown
local MutationDropdown

local SelectedEggZones = {}
local SelectedEggNames = {}
local SelectedMutations = {}

-- =========================================================
-- UI
-- =========================================================

local Success, Library = pcall(function()
	return loadstring(game:HttpGet(
		"https://bonkhub.online/LibraryStandaloneLoader.lua"
	))()
end)

if not Success or not Library then
	return
end

local Window = Library:Window({
	Title = "BONK HUB",
	Subtitle = "V1.0.0 | 009.exe is cool",
	Icon = "rbxassetid://11262159835",
	ToggleIcon = "rbxassetid://11262159835",
	Watermark = "BONK HUB",
	WatermarkEnabled = true,
	ToggleUiKey = Enum.KeyCode.RightControl,

	Size = {
		Width = 550,
		Height = 400
	},

	SidebarWidth = 170,

	Splash = {
		Subtitle = "Loading ...",
		MinDuration = 1.2
	},

	ConfigFile = "BonkHub",
	Theme = "Forest",

	KeySystem = {
		Enabled = false
	},
})

Window:Section("Egg Farm")

local MainTab = Window:Tab("Main", "user")
local GeneralPage = MainTab:SubTab("General")

local FarmGroup = GeneralPage:Groupbox(
	"Egg Farming",
	"Left",
	"7733774602",
	"true"
)

local FilterGroup = GeneralPage:Groupbox(
	"Egg Filters",
	"Right",
	"eye"
)

-- =========================================================
-- CHARACTER
-- =========================================================

local function GetCharacter()
	local character = Player.Character

	if not character or not character.Parent then
		return nil
	end

	return character
end

local function GetRoot()
	local character = GetCharacter()
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
	local character = GetCharacter()
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

-- =========================================================
-- MOVEMENT CLEANUP
-- =========================================================

local function CleanupTween()
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end

	if currentBodyVelocity then
		pcall(function()
			currentBodyVelocity:Destroy()
		end)

		currentBodyVelocity = nil
	end

	local root = GetRoot()

	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function StopTween()
	CleanupTween()
end

-- =========================================================
-- HUMANOID BYPASS
-- =========================================================

local function ApplyHumanoidBypass()
	local character = GetCharacter()

	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	if humanoid.Name == "BypassedHumanoid" then
		return humanoid
	end

	if not cache or cache.Character ~= character then
		cache = {
			Character = character,
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			AutoRotate = humanoid.AutoRotate,
			PlatformStand = humanoid.PlatformStand,
		}
	end

	humanoid.Archivable = true

	local newHumanoid = humanoid:Clone()

	newHumanoid.Name = "BypassedHumanoid"
	newHumanoid.BreakJointsOnDeath = false

	humanoid:Destroy()

	newHumanoid.Parent = character

	newHumanoid.WalkSpeed =
		cache.WalkSpeed or OriginalWalkSpeed

	newHumanoid.JumpPower =
		cache.JumpPower or 50

	newHumanoid.JumpHeight =
		cache.JumpHeight or 7.2

	newHumanoid.AutoRotate =
		cache.AutoRotate ~= false

	newHumanoid.PlatformStand = false

	if not newHumanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator", newHumanoid)
	end

	newHumanoid.Died:Connect(function()
		if ResetStateOnDeath then
			ResetStateOnDeath()
		end
	end)

	return newHumanoid
end

-- =========================================================
-- TWEEN
-- =========================================================

local function TweenTo(targetPosition, speedOverride)
	if typeof(targetPosition) ~= "Vector3" then
		return false
	end

	local character = GetCharacter()

	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	-- สำคัญ: รับ Humanoid ตัวใหม่หลัง Bypass
	humanoid = ApplyHumanoidBypass()

	if not humanoid then
		return false
	end

	character = GetCharacter()

	if not character then
		return false
	end

	root = character:FindFirstChild("HumanoidRootPart")

	humanoid =
		character:FindFirstChild("BypassedHumanoid")
		or character:FindFirstChildOfClass("Humanoid")

	if not root
		or not root.Parent
		or not humanoid
		or humanoid.Health <= 0 then

		return false
	end

	local speed = speedOverride or TweenSpeed

	-- =====================================================
	-- NOCLIP
	-- =====================================================

	if not noclipConnection then
		noclipConnection = RunService.Stepped:Connect(function()
			local currentCharacter = GetCharacter()

			if not currentCharacter then
				return
			end

			for _, part in ipairs(
				currentCharacter:GetDescendants()
			) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	end

	-- =====================================================
	-- BODY VELOCITY
	-- =====================================================

	if currentBodyVelocity then
		if currentBodyVelocity.Parent ~= root then
			pcall(function()
				currentBodyVelocity:Destroy()
			end)

			currentBodyVelocity = nil
		end
	end

	if not currentBodyVelocity then
		local bv = Instance.new("BodyVelocity")

		bv.Name = "BonkMovementVelocity"
		bv.MaxForce = Vector3.new(
			math.huge,
			math.huge,
			math.huge
		)

		bv.P = 12500
		bv.Velocity = Vector3.zero
		bv.Parent = root

		currentBodyVelocity = bv
	end

	-- =====================================================
	-- TWEEN LOOP
	-- =====================================================

	local reached = false
	local stopped = false
	local connection

	connection = RunService.Heartbeat:Connect(function()
		local currentCharacter = GetCharacter()

		if not currentCharacter then
			stopped = true

			if connection then
				connection:Disconnect()
				connection = nil
			end

			return
		end

		local currentRoot =
			currentCharacter:FindFirstChild("HumanoidRootPart")

		local currentHumanoid =
			currentCharacter:FindFirstChild("BypassedHumanoid")
			or currentCharacter:FindFirstChildOfClass("Humanoid")

		if not currentRoot
			or not currentRoot.Parent
			or not currentHumanoid
			or currentHumanoid.Health <= 0 then

			stopped = true

			if connection then
				connection:Disconnect()
				connection = nil
			end

			return
		end

		-- Character เปลี่ยน = หยุด Tween เก่า
		if currentRoot ~= root then
			stopped = true

			if connection then
				connection:Disconnect()
				connection = nil
			end

			return
		end

		local currentPos = currentRoot.Position
		local offset = targetPosition - currentPos
		local distance = offset.Magnitude

		if distance <= ARRIVE_DISTANCE then
			if currentBodyVelocity
				and currentBodyVelocity.Parent == currentRoot then

				currentBodyVelocity.Velocity = Vector3.zero
			end

			reached = true

			if connection then
				connection:Disconnect()
				connection = nil
			end

			return
		end

		if distance > 0.05 then
			currentRoot.CFrame = CFrame.new(
				currentPos,
				Vector3.new(
					targetPosition.X,
					currentPos.Y,
					targetPosition.Z
				)
			)
		end

		local calculatedSpeed = math.min(
			speed,
			math.max(30, distance * 8)
		)

		if currentBodyVelocity
			and currentBodyVelocity.Parent == currentRoot then

			currentBodyVelocity.Velocity =
				offset.Unit * calculatedSpeed
		end
	end)

	while not reached
		and not stopped
		and AutoFarm do

		local currentCharacter = GetCharacter()

		if not currentCharacter then
			break
		end

		local currentHumanoid =
			currentCharacter:FindFirstChild("BypassedHumanoid")
			or currentCharacter:FindFirstChildOfClass("Humanoid")

		if not currentHumanoid
			or currentHumanoid.Health <= 0 then
			break
		end

		task.wait()
	end

	if connection then
		connection:Disconnect()
		connection = nil
	end

	if currentBodyVelocity
		and currentBodyVelocity.Parent == root then

		currentBodyVelocity.Velocity = Vector3.zero
	end

	return reached
end

-- =========================================================
-- EGG UTILITIES
-- =========================================================

local function EggRecordExists(uid)
	if not uid then
		return false
	end

	return EggState.ReadFieldEgg(uid) ~= nil
end

local function IsCarryingUid(uid)
	return uid
		and lastCarryData
		and tostring(lastCarryData.Uid) == tostring(uid)
end

local function IsOwnedByMe(uid)
	if not uid then
		return false
	end

	return EggState.ReadOwnedEgg(
		Player.UserId,
		uid
	) ~= nil
end

local function GetEggByUid(uid)
	if not uid then
		return nil
	end

	local egg = Workspace:FindFirstChild(
		tostring(uid),
		true
	)

	if not egg then
		return nil
	end

	if egg:IsA("BasePart") then
		return egg
	end

	if egg:IsA("Model") then
		return egg.PrimaryPart
			or egg:FindFirstChildWhichIsA(
				"BasePart",
				true
			)
	end

	return nil
end

-- =========================================================
-- FILTER
-- =========================================================

local function IsSelected(selection, value)
	if next(selection) == nil then
		return true
	end

	return selection[tostring(value)] == true
end

local function GetEggMutation(record)
	if not record then
		return "Unknown"
	end

	local mutation =
		record.Mutation
		or record.MutationName
		or record.MutationId
		or record.MutationType

	if mutation ~= nil then
		return tostring(mutation)
	end

	return "None"
end

local function GetMutationNames()
	local result = {}
	local seen = {}

	for _, folder in ipairs(
		Mutations:GetChildren()
	) do
		if folder:IsA("Folder")
			and not seen[folder.Name] then

			seen[folder.Name] = true
			table.insert(result, folder.Name)
		end
	end

	table.sort(result)

	return result
end

local function GetEggFilterData()
	local zones = {}
	local names = {}

	local zoneSet = {}
	local nameSet = {}

	local fieldData =
		EggState.ReadFieldEggs()

	if not fieldData
		or not fieldData.Records then

		return zones, names
	end

	for _, record in ipairs(fieldData.Records) do
		local zone =
			tostring(record.AreaId or "Unknown")

		local name =
			tostring(record.AssetCategory or "Unknown")

		if not zoneSet[zone] then
			zoneSet[zone] = true
			table.insert(zones, zone)
		end

		if not nameSet[name] then
			nameSet[name] = true
			table.insert(names, name)
		end
	end

	table.sort(zones)
	table.sort(names)

	return zones, names
end

local function GetFilteredEggs()
	local fieldData =
		EggState.ReadFieldEggs()

	if not fieldData
		or not fieldData.Records then

		return {}
	end

	local result = {}

	for _, record in ipairs(fieldData.Records) do
		local zone =
			tostring(record.AreaId or "Unknown")

		local name =
			tostring(record.AssetCategory or "Unknown")

		local mutation =
			GetEggMutation(record)

		if IsSelected(
			SelectedEggZones,
			zone
		)
		and IsSelected(
			SelectedEggNames,
			name
		)
		and IsSelected(
			SelectedMutations,
			mutation
		) then

			table.insert(result, record)
		end
	end

	return result
end

local function GetNearestFilteredEgg()
	local root = GetRoot()

	if not root then
		return nil, nil
	end

	local records =
		GetFilteredEggs()

	local nearestPart = nil
	local nearestUid = nil
	local nearestDistance = math.huge

	for _, record in ipairs(records) do
		local uid = tostring(record.Uid)
		local egg = GetEggByUid(uid)

		if egg then
			local distance =
				(root.Position - egg.Position).Magnitude

			if distance < nearestDistance then
				nearestDistance = distance
				nearestPart = egg
				nearestUid = uid
			end
		end
	end

	return nearestPart, nearestUid
end

-- =========================================================
-- FILTER UI
-- =========================================================

local zones, names = GetEggFilterData()
local mutationNames = GetMutationNames()

ZoneDropdown = FilterGroup:AddDropdown({
	Title = "Zone",
	Values = zones,
	Default = {},
	Multi = true,
	Flag = "EggZones",

	Callback = function(Value)
		SelectedEggZones = Value or {}
	end,
})

NameDropdown = FilterGroup:AddDropdown({
	Title = "Egg Name",
	Values = names,
	Default = {},
	Multi = true,
	Flag = "EggNames",

	Callback = function(Value)
		SelectedEggNames = Value or {}
	end,
})

MutationDropdown = FilterGroup:AddDropdown({
	Title = "Mutation",
	Values = mutationNames,
	Default = {},
	Multi = true,
	Flag = "EggMutations",

	Callback = function(Value)
		SelectedMutations = Value or {}
	end,
})

FilterGroup:AddButton({
	Title = "Refresh Egg List",

	Callback = function()
		local newZones, newNames =
			GetEggFilterData()

		local newMutations =
			GetMutationNames()

		ZoneDropdown.Refresh(newZones)
		NameDropdown.Refresh(newNames)
		MutationDropdown.Refresh(newMutations)

		Library:Notify(
			"Egg Filter",
			"Egg list refreshed!",
			2
		)
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

		Library:Notify(
			"Egg Filter",
			"All filters cleared",
			2
		)
	end,
})

-- =========================================================
-- STATUS
-- =========================================================

local StatusParagraph = FarmGroup:AddParagraph({
	Title = "Egg Filter Status",
	Content = "Matching Eggs: 0\nFarming: Idle",
	TextWrapped = true,
})

task.spawn(function()
	while task.wait(0.5) do
		local filtered =
			GetFilteredEggs()

		if StatusParagraph then
			local statusText = "Farming: Idle"

			if Lll then
				statusText =
					"Farming: Stealing Egg"

			elseif AutoFarm
				and NeedInitialDropOff then

				statusText =
					"Farming: Moving to Drop-off..."

			elseif AutoFarm then
				statusText =
					"Farming: Running"
			end

			StatusParagraph:SetDesc(
				"Matching Eggs: "
				.. tostring(#filtered)
				.. "\n"
				.. statusText
			)
		end
	end
end)

-- =========================================================
-- RECOVER TARGET
-- =========================================================

local function GetCurrentTarget(uid)
	if not uid then
		return nil
	end

	local target = GetEggByUid(uid)

	if not target then
		return nil
	end

	if not EggRecordExists(uid) then
		return nil
	end

	return target
end

local function RecoverTarget(uid)
	local target = GetCurrentTarget(uid)

	if not target then
		return false
	end

	local targetPosition =
		target.Position + Vector3.new(0, 2, 0)

	local reached = TweenTo(targetPosition)

	if not reached then
		return false
	end

	-- ตรวจอีกครั้งหลังถึงเป้าหมาย
	target = GetCurrentTarget(uid)

	return target ~= nil
end

-- =========================================================
-- EGG SESSION (แก้ไขแล้ว - ลูปไม่หยุดจนกว่าจะได้)
-- =========================================================

local function RunEggSession(uid)
	if not uid or Lll then
		return false
	end

	local root = GetRoot()
	local humanoid = GetHumanoid()

	if not root
		or not humanoid
		or humanoid.Health <= 0 then

		return false
	end

	Lll = true

	local sessionActive = true
	local success = false

	ActiveSession = {
		Stop = function()
			sessionActive = false
			Lll = false
			StopTween()
		end,
		GetUid = function()
			return uid
		end,
	}

	-- =====================================================
	-- STEAL LOOP (แบบไม่หยุดจนกว่าจะได้)
	-- =====================================================

	task.spawn(function()
		while sessionActive do
			-- ตรวจสอบว่าเป็นของเราแล้วหรือยัง
			if IsOwnedByMe(uid) then
				success = true
				sessionActive = false
				break
			end
			
			-- ถ้าไข่หายไป ให้ Tween ไปหา
			if not EggRecordExists(uid) then
				RecoverTarget(uid)
				task.wait(0.3)
			end
			
			-- ส่ง Remote ขโมย (พยายามต่อไปเรื่อยๆ)
			local args
			if string.find(uid, "Slot", 1, true) then
				local SlotKey = string.match(uid, "([^_]+_[^_]+)$")
					or string.match(uid, "([^_]+_Slot[^_]*)")
					or string.match(uid, "([^_]+:Slot[^_]*)")
					or string.match(uid, "(.-_Slot[^_]*)")
					or uid

				args = {
					{
						FirstAreaSlotKey = SlotKey,
						Uid = uid
					}
				}
			else
				args = {
					{
						Uid = uid
					}
				}
			end

			pcall(function()
				CarryRemote:InvokeServer(unpack(args))
			end)

			task.wait(0.2)
			
			-- ถ้าเซสชั่นถูกหยุดจากข้างนอก
			if not sessionActive then
				break
			end
		end
	end)

	-- =====================================================
	-- MOVEMENT LOOP
	-- =====================================================

	task.spawn(function()
		while sessionActive do
			local targetPos

			if IsCarryingUid(uid) then
				targetPos =
					DROP_OFF_POSITION
			else
				local egg =
					GetEggByUid(uid)

				if egg then
					targetPos =
						egg.Position
						+ Vector3.new(0, 2, 0)
				end
			end

			if targetPos then
				TweenTo(targetPos)
			end

			task.wait(0.1)
		end
	end)

	while sessionActive do
		task.wait()
	end

	Lll = false

	StopTween()

	ActiveSession = nil

	return success
end

-- =========================================================
-- FARM ONE EGG
-- =========================================================

local function FarmOneEgg()
	if Lll then
		return
	end

	-- หลังเปิด / หลัง Respawn
	if NeedInitialDropOff then
		local arrived =
			TweenTo(DROP_OFF_POSITION)

		if arrived then
			NeedInitialDropOff = false

			StopTween()

			task.wait(0.3)
		else
			return
		end
	end

	-- ตรวจสอบว่าเป้าหมายเดิมยังมีอยู่หรือไม่
	if ActiveSession then
		local currentUid = ActiveSession.GetUid and ActiveSession.GetUid()
		if currentUid then
			local target = GetCurrentTarget(currentUid)
			if not target then
				-- เป้าหมายหาย ให้หยุดเซสชั่นปัจจุบัน
				ActiveSession.Stop()
				ActiveSession = nil
				task.wait(0.3)
			else
				-- เป้าหมายยังมีอยู่ ให้ทำงานต่อไป
				return
			end
		end
	end

	local egg, uid =
		GetNearestFilteredEgg()

	if not egg or not uid then
		task.wait(0.5)
		return
	end

	RunEggSession(uid)
end

-- =========================================================
-- FARM LOOP
-- =========================================================

local function StartFarmLoop()
	if FarmThread then
		return
	end

	FarmThread = task.spawn(function()
		while AutoFarm do
			local character =
				GetCharacter()

			local humanoid =
				GetHumanoid()

			if character
				and humanoid
				and humanoid.Health > 0 then

				if not Lll then
					FarmOneEgg()
				else
					task.wait()
				end
			else
				task.wait(1)
			end
		end

		FarmThread = nil
	end)
end

-- =========================================================
-- CARRY
-- =========================================================

EggState.CarryChanged:Connect(function(data)
	lastCarryData = data
end)

-- =========================================================
-- SPEED
-- =========================================================

FarmGroup:AddSlider({
	Title = "Tween Speed",
	Min = 100,
	Max = 2000,
	Default = 700,
	Rounding = 0,
	Suffix = " studs/s",
	Flag = "TweenSpeedSlider",

	Callback = function(Value)
		TweenSpeed = Value
	end,
})

-- =========================================================
-- AUTO FARM (แก้ไขแล้ว - หยุดทุกอย่างทันที)
-- =========================================================

AutoFarmToggle = FarmGroup:AddToggle({
	Title = "Auto Steal egg",
	Default = false,
	Flag = "AutoStealegg",

	Callback = function(Value)
		AutoFarm = Value

		if Value then
			-- เปิดใหม่ต้อง Drop-off ก่อน
			NeedInitialDropOff = true

			StartFarmLoop()

		else
			-- =============================================
			-- ปิด Auto Farm -> หยุดทุกอย่างทันที
			-- =============================================
			
			AutoFarm = false
			NeedInitialDropOff = false

			-- หยุด Session
			if ActiveSession then
				ActiveSession.Stop()
				ActiveSession = nil
			end

			-- รีเซ็ตตัวแปร
			Lll = false
			lastCarryData = nil
			cache = nil

			-- หยุด Tween และ Movement ทั้งหมดทันที
			StopTween()

			-- หยุด Farm Thread
			if FarmThread then
				task.cancel(FarmThread)
				FarmThread = nil
			end
		end
	end,
})

-- =========================================================
-- RESET ON DEATH
-- =========================================================

function ResetStateOnDeath()
	if ActiveSession then
		ActiveSession.Stop()
		ActiveSession = nil
	end

	Lll = false
	lastCarryData = nil
	cache = nil

	-- ล้าง Movement ของ Character เก่า
	StopTween()

	-- ถ้า Auto Farm ยังเปิด
	-- Character ใหม่ต้องกลับ Drop-off ก่อน
	if AutoFarm then
		NeedInitialDropOff = true
	end
end

-- =========================================================
-- CHARACTER SETUP
-- =========================================================

local function SetupCharacter(character)
	if not character then
		return
	end

	-- ล้าง reference ของ Character เก่า
	StopTween()

	cache = nil
	lastCarryData = nil
	Lll = false

	local humanoid = character:WaitForChild("Humanoid", 15)
	local root = character:WaitForChild("HumanoidRootPart", 15)

	if not character.Parent then
		return
	end

	if root then
		SpawnPosition = root.Position
	end

	if humanoid then
		humanoid.Died:Connect(function()
			ResetStateOnDeath()
		end)
	end

	if AutoFarm then
		NeedInitialDropOff = true

		task.delay(1.5, function()
			if not AutoFarm then
				return
			end

			if Player.Character ~= character then
				return
			end

			local currentHumanoid =
				character:FindFirstChildOfClass("Humanoid")

			local currentRoot =
				character:FindFirstChild("HumanoidRootPart")

			if not currentHumanoid
				or currentHumanoid.Health <= 0
				or not currentRoot then
				return
			end

			StartFarmLoop()
		end)
	end
end

-- =========================================================
-- CHARACTER ADDED
-- =========================================================

Player.CharacterAdded:Connect(function(character)
	ResetStateOnDeath()

	if AutoFarm then
		NeedInitialDropOff = true
	end

	SetupCharacter(character)
end)

-- =========================================================
-- CURRENT CHARACTER
-- =========================================================

if Player.Character then
	task.spawn(function()
		SetupCharacter(Player.Character)
	end)
end