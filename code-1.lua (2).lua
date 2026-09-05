

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetServiceRunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

local EggState = require(ReplicatedStorage.Client.EggState)
local Mutations = ReplicatedStorage:WaitForChild("Mutations")
local CarryRemote =licatedStorage.Packages.NetworkingRF/EggWorld/FieldEggCar"]

local DROP_OFF_POSITION = Vector3.new(501.24, 70.49, -368.58)
local ARRIVE_DISTANCE = 3

local TweenSpeed = 700local OriginalWalkSpeed = 16

local Lll = false
localFarm = false
local NeedInitialDropOff = false

local lastCarryData = nil
local ActiveSession = nil
local FarmThread = nil
local currentBodyVelocity = nil
local SpawnPosition = nil

local AutoFarmToggle = nil

local ZoneDropdown
local NameDropdown
local MutationDropdown

local SelectedEggZones = {}
local SelectedEggNames = {}
local SelectedMutations = {}


local CurrentHumanoid = nil

local JumpHeld = false
local Jumping = false

local function ReplaceHumanoid(character)
	local old = character:WaitForChild("Humanoid", 5)
	if not old then return end

	local saved = {}
	for _, prop in ipairs({
		"WalkSpeed", "JumpPower", "JumpHeight", "Rotate",
		"PlatformStand", "HipHeight", "UseJumpPower", "Health", "MaxHealth"
	}) do
		saved[prop] old[prop]
	end
	local animate = character:FindFirstChild("Animate")

	if animate and animate:IsA("LocalScript") then
		animate.Disabled = true
	end

	local oldAnimator = old:FindFirstChildOfClass("Animator")

	if oldAnimator then
		for _, track in ipairs(oldAnimator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end

	local rootPart = old.RootPart
		or character:FindFirstChild("HumanoidPart")

	old.BreakJointsOnDeath = false
	old.Archivable = true

	local new = old:Clone()
	for _, obj in ipairs(new:GetChildren()) do
		if obj:IsA("Animator") then
			obj:Destroy()
		end
	end

	old:Destroy()
	new.Parent = character
	new.BreakJointsOnDeath = false

	RunService.Heartbeat:Wait()

	if rootPart then
		character.PrimaryPart = rootPart
	end
	for _, prop in ipairs({
		"WalkSpeed", "JumpPower", "JumpHeight", "UseJumpPower",
		"AutoRotate", "PlatformStand", "HipHeight", "MaxHealth"
	}) do
		new[prop] = saved[prop]
	end

	new.Health = math.min(
		saved.Health or 100,
		saved.MaxHealth or 100
	)

	CurrentHumanoid =

	local camera = Workspace.CurrentCamera

	if camera then
		camera.CameraSubject = new
	end
 newAnimator = Instance.new("Animator")
	newAnimator = new

	
	new:SetStateEnabled(Enum.HumanoidType.Jumping, true)
	new:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	new:SetStateEnabled(Enum.HumanStateType.Running, true)
	new:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
	new:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)


	new:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
	new:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	new:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	if animate and animate:IsA("LocalScript") then
		task.wait()
		animate.Disabled = false
		task.defer(function()
			if animate.Parent then
			animate.Disabled = true
				task.wait()
				animate.Disabled = false
			end
		end)
	end

	new:ChangeState(Enum.HumanoidStateType.GettingUp)

	RunService.Heartbeat:Wait()

	new:ChangeState(Enum.HumanoidStateType.Running)
	new.Died:Connect(function()
		if ResetStateOnDeath then
			ResetStateOnDeath()
		end
	end)

	return new
end
local function UnlockCharacter(humanoid, root)
	if not humanoid or not root then return end
	if humanoid.SeatPart then
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
	if root.Anchored then
		root.Anchored = false
	end
	for _, obj in ipairs(root:GetChildren()) do
		if obj:IsA("BodyPosition")
			or obj:IsA("BodyGyro")
			or obj:IsA("AlignPosition")
			or obj:IsA("AlignOrientation")
			or obj:IsA("BodyVelocity")
			or obj:IsA("BodyThrust")
			or obj:IsA("LinearVelocity")
			or obj:IsA("AngularVelocity") then

			obj:Destroy()
		end
	end
	for _, obj in ipairs(root:GetChildren()) do
		if obj:IsA("Weld") or obj:IsA("Motor") then
			if obj.Part1 and (
				obj.Part1:IsA("Seat")
				or obj.Part1:IsA("VehicleSeat")
			) then

				obj:Destroy()
			end
		end
	end
	if humanoid.SeatPart then
		root:BreakJoints()
	end
end

local function DoJump()
	if Jumping then return end
	local humanoid = CurrentHumanoid
	if not humanoid
		or not humanoid.Parent
		or humanoid.Health <= 0 then
		return
	end

	local character = humanoid.Parent

	local root = humanoid.RootPart
		or character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	UnlockCharacter(humanoid, root)

	if root.Anchored then
		root.CFrame += Vector3.new(0, 0.5, 0)
		RunService.Heartbeat:Wait()
		root.Anchored = false
	end

	local power
	if humanoid.UseJumpPower then
		power = humanoid.JumpPower > 0
			and humanoid.JumpPower
			or 50
	else
		local height = humanoid.JumpHeight > 0
			and humanoid.JumpHeight
			or 7.2

		power = math.sqrt(
			2 * Workspace.Gravity * height
		)
	end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(
		velocity.X,
		power,
		velocity.Z
	)

	humanoid.Jump = true

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	Jumping = true
end
RunService.Heartbeat:Connect(function()
	local humanoid = CurrentHumanoid

	if not humanoid
		or not humanoid.Parent
		or humanoid.Health <= 0 then

		Jumping = false
		return
	end

	if not Jumping then return end

	local state = humanoid:GetState()

	if state == Enum.HumanoidStateType.Landed
		or state == Enum.HumanoidStateType.Running then

		Jumping = false
		humanoid.Jump = false

		--// ถ้ายังกดค้าง ให้กระโดดรอบใหม่
		if JumpHeld then
			task.defer(function()
				if JumpHeld then
					DoJump()
				end
			end)
		end
	end
end)
UIS.JumpRequest:Connect(function()
	JumpHeld = true

	if not Jumping then
		DoJump()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		JumpHeld = false
		if CurrentHumanoid and CurrentHumanoid.Parent then
			CurrentHumanoid.Jump = false
		end
	end
end)

local function SetupMobileJump()
	local pg = Player:WaitForChild("PlayerGui")
	local touchGui = pg:WaitForChild("TouchGui", 5)
	if not touchGui then return end
	local frame = touchGui:WaitForChild("TouchControlFrame", 5)
	if not frame then return end
	local btn = frame:WaitForChild("JumpButton", 5)
	if not btn then return end
	btn:GetPropertyChangedSignal("GuiState"):Connect(function()
		if btn.GuiState == Enum.GuiState.Press then
			JumpHeld = true
			if not Jumping then
				DoJump()
			end
		else
			JumpHeld = false
			if CurrentHumanoid
				and CurrentHumanoid.Parent then
				CurrentHumanoid.Jump = false
			end
		end
	end)
end
task.spawn(function()
	if Player:FindFirstChild("PlayerGui then
		SetupMobileJump()
	else
		Player.ChildAdded:Connect(function(child)
			if child.Name == "PlayerGui" then
				SetupMobileJump()
			end
		end)
	end
end)


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
	if CurrentHumanoid and CurrentHumanoid.Parent == character then
		return CurrentHumanoid
	end

	return character:FindFirstChildOfClass("Humanoid")
end
 function CleanupTween()
	if currentBodyVelocity then
		pcall(function()
			currentBodyVelocity:Destroy()
		end)

		currentBodyVelocity = nil
	end

	local root = GetRoot()

	if root and root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function StopTween()
	CleanupTween()
end

local function TweenTo(targetPosition, speedOverride)
	if typeof(targetPosition) ~= "Vector3" then
		return false
	end

	local character = GetCharacter()

	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = GetHumanoid()

	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if CurrentHumanoid == nil
		or CurrentHumanoid.Parent ~= character then

		humanoid = ReplaceHumanoid(character)

		if not humanoid then
			return false
		end

		character = GetCharacter()

		if not character then
			return false
		end

		root = character:FindFirstChild("HumanoidRootPart")

		if not root then
			return false
		end
	end

	local speed = speedOverride or TweenSpeed
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

		local currentHumanoid = GetHumanoid()

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
			math.max(, distance * 8)
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
		local currentHumanoid = GetHumanoid()
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

	for _, folder in ipairs(Mutations:GetChildren()) do
		if folder:IsA("Folder")
			and not seen[folder.Name]

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

	table.sort(zones)
	table.sort(names)

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
		and IsSelected(SelectedMutations, mutation) then

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

	local records = GetFilteredEggs()

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

local zones, names = GetEggFilterData()
local mutationNames = GetMutationNames()

ZoneDropdown = FilterGroup:AddDropdown({
	Title = "Zone",
	Values = zones,
	Default = {},
	Multi = true,
	Flag = "EggZones	Callback = function(Value)
		SelectedEggZones = Value or {}
	end,
})

NameDropdown = FilterGroup:AddDropdown({
	Title = " Name",
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
		local newZones, newNames = GetEggFilterData()
		local newMutations = GetMutationNames()

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


local StatusParagraph = FarmGroup:AddParagraph({
	Title = "Egg Filter Status",
	Content = "quantity Eggs: 0\nFarming: none",
	TextWrapped = true,
})

task.spawn(function()
	while task.wait(0.5) do
		local filtered = GetFilteredEggs()

		if StatusParagraph then
			local statusText = "Farming: none"

			if Lll then
				statusText = "Farming: Stealing Egg"

			elseif AutoFarm and NeedInitialDropOff then
				statusText = "Farming: ..."

			elseif AutoFarm then
				statusText = "Farming: Running"
			end

			StatusParagraph:SetDesc(
				"quantity Eggs: "
				.. tostring(#filtered)
				.. "\n"
				.. statusText
			)
		end
	end
end)
local function GetCurrentTarget(uid)
	if not uid then
		return nil
	end
	local target = GetEggByUid(uid)

	if not target then
		return nil
	end

	if not EggRecordExists(uid) then
		return
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

	target = GetCurrentTarget(uid)

	return target ~= nil
end
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
	task.spawn(function()
		while sessionActive do
			if IsOwnedByMe(uid) then
				success = true
				sessionActive = false
				break
			end

			if not EggRecordExists(uid) then
				sessionActive = false
				break
			end

			pcall(function()
				CarryRemote:InvokeServer({
					Uid = uid,
					FirstAreaSlotKey = nil,
				})
			end)

			task.wait(0.2)
		end
	end)
	task.spawn(function()
		local wasCarrying = false

		while sessionActive do
			local targetPos

			if IsCarryingUid(uid) then
				wasCarrying = true
				targetPos = DROP_OFF_POSITION
			else
				if wasCarrying then
					wasCarrying = false
					local egg = GetEggByUid(uid)
					if egg and EggRecordExists(uid) then
						TweenTo(egg.Position + Vector3.new(0, 2, 0))
						task.wait(0.1)
					end
				end

				local egg = GetEggByUid(uid)

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

local function FarmOneEgg()
	if Lll then
		return
	end
	if NeedInitialDropOff then
		local arrived = TweenTo(DROP_OFF_POSITION)
		if arrived then
			NeedInitialDropOff = false
			StopTween()
			task.wait(0.3)
		else
			return
		end
	end

	if ActiveSession then
		local currentUid = ActiveSession.GetUid and ActiveSession.GetUid()
		if currentUid then
			local target = GetCurrentTarget(currentUid)
		 not target then
				ActiveSession.Stop()
				ActiveSession = nil
				task.wait(0.3)
			else
				return
			end
		end
	end

	local egg, uid = GetNearestFilteredEgg()

	if not egg or not uid then
		task.wait(0.5)
		return
	end

	RunEggSession(uid)
end
local function StartFarmLoop()
	if FarmThread then
		return
	end
	FarmThread = task.spawn(function()
		while AutoFarm do
			local character = GetCharacter()
			local humanoid = GetHumanoid()
			if character
				and humanoid
				and humanoid.Health > 0 then
				if notll then
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



EggState.CarryChanged:Connect(function(data)
	lastCarryData = data
end)
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


AutoFarmToggle = FarmGroup:AddToggle({
	Title = "Auto Steal egg",
	Default = false,
	Flag = "AutoStealegg",
	Callback = function(Value)
		AutoFarm = Value

		if Value then
			NeedInitialDropOff = true

			StartFarmLoop()

		else
			AutoFarm = false
			NeedInitialDropOff = false

			if ActiveSession then
				ActiveSession.Stop()
				ActiveSession = nil
			end

			Lll = false

			StopTween()
		end
	end,
})

function ResetStateOnDeath()
	if ActiveSession then
		ActiveSession.Stop()
		ActiveSession nil
	end

	Lll = false
	lastCarryData = nil

	StopTween()

	if AutoFarm then
		NeedInitialDropOff = true
	end
end

local function SetupCharacter(character)
	if not character then
		return
	end

	StopTween()

	lastCarryData = nil
	Lll = false
	CurrentHumanoid = nil
	Jumping = false
	JumpHeld = false

	local root = character:WaitForChild("HumanoidRootPart", 15)

	if not character.Parent then
		return
	end

	if root then
		SpawnPosition = root.Position
	end
	task.spawn(function()
		local humanoid = ReplaceHumanoid(character)

		if humanoid then
			humanoid.Died:Connect(function()
				ResetStateOnDeath()
			end)
		end
	end)

	if AutoFarm then
		NeedInitialDropOff = true

		task.delay(1.5, function()
			if not AutoFarm then
				return
			end

			if Player.Character ~= then
				return
			end

			local currentHumanoid = GetHumanoid()
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
Player.CharacterAdded:Connect(function(character)
ResetStateOnDeath()

	if AutoFarm then
		NeedInitialDropOff = true
	end

	SetupCharacter(character)
end)
if Player.Character then
	task.spawn(function()
		SetupCharacter(Player.Character)
	end)
end




getgenv().AntiRagdoll = false 



local PlayerTab = Window:Tab("Player", "shield")
local PlayerPage = PlayerTab:SubTab("Anti-Ragdoll")
local PlayerGroup = Page:Groupbox("Anti-Ragdoll", "Left")

local Player = Players.LocalPlayer

local Remote = ReplicatedStorage:FindFirstChild("Packages")
    and ReplicatedStorage.Packages:FindFirstChild("Networking")
    and ReplicatedStorage.Packages.Networking:FindFirstChild("RE/RigSync/Refresh")

local function AntiKnockback()
    if not getgenv().AntiRagdoll or not Remote then return end
    if not getconnections then return end

    local s, conns = pcall(function()
        return getconnections(Remote.OnClientEvent)
    end)
    if s and conns then
        task.spawn(function()
            for _, conn in next, conns do
                pcall(conn.Disconnect, conn)
            end
        end)
    end
end

local function Fix(Character)
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end

    if not Humanoid.PlatformStand and Humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
        return
    end

    Humanoid.PlatformStand = false
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

    for _, Object in ipairs(Character:GetDescendants()) do
        if Object:IsA("Motor6D") then
            Object.Enabled = true
        elseif Object:GetAttribute("RagdollConstraint") then
            Object:Destroy()
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if getgenv().AntiRagdoll and Player.Character then
            Fix(Player.Character)
        end
    end
end)

Player.CharacterAdded:Connect(function(Character)
    if Character:WaitForChild("Humanoid", 5) and getgenv().AntiRagdoll then
        Fix(Character)
    end
end)

task.spawn(function()
    while true do
        task.wait(10)
        AntiKnockback()
    end
end)

PlayerGroup:AddToggle({
    Title = "Anti Ragdoll",
    Default = getgenv().AntiRagdoll,
    Flag = "AntiRagdoll",
    Callback = function(Value)
        getgenv().AntiRagdoll = Value
        if Value then
            AntiKnockback()
        end
    end
})
