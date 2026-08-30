-- =========================================================
-- EGG FARM + FILTER UI
-- Zone / Egg Name / Mutation
-- =========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

local EggState = require(ReplicatedStorage.Client.EggState)

local Mutations = ReplicatedStorage:WaitForChild("Mutations")

local CarryRemote =
ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]

-- =========================================================
-- CONFIG
-- =========================================================

local DROP_OFF_POSITION = Vector3.new(
501.24,
70.49,
-368.58
)

local ARRIVE_DISTANCE = 2

local Lll = false
local lastCarryData = nil

-- =========================================================
-- LOAD BONK HUB UI
-- =========================================================

local LibraryUrl =
"https://bonkhub.online/LibraryStandaloneLoader.lua"

local Success, Library = pcall(function()
return loadstring(game:HttpGet(LibraryUrl))()
end)

if not Success or not Library then
warn("Failed to load BONK HUB UI Library")
return
end

local Window = Library:Window({
Title = "BONK HUB | 009.exe is cool",
Subtitle = "V1.0.0",
Icon = "rbxassetid://11262159835",
ToggleIcon = "rbxassetid://11262159835",
Watermark = "BONK HUB ",
WatermarkEnabled = true,
ToggleUiKey = Enum.KeyCode.RightControl,

Size = {  
    Width = 550,  
    Height = 400  
},  

SidebarWidth = 170,  

Splash = {  
    Subtitle = "Loading Egg Farm...",  
    MinDuration = 1.2  
},  

ConfigFile = "BonkHub",  
Theme = "Forest",  

KeySystem = {  
    Enabled = false  
}

})

Window:Section("Egg Farm")

local MainTab =
Window:Tab(
"Main",
"user"
)

local GeneralPage =
MainTab:SubTab("General")

local FarmGroup =
GeneralPage:Groupbox(
"Egg Farming",
"Left",
"7733774602",
"true"
)

local FilterGroup =
GeneralPage:Groupbox(
"Egg Filters",
"Right",
"eye"
)

-- =========================================================
-- ROOT
-- =========================================================

local function GetRoot()

local Character =  
    Player.Character  
    or Player.CharacterAdded:Wait()  

return Character:FindFirstChild(  
    "HumanoidRootPart"  
)

end

-- =========================================================
-- EGG STATE
-- =========================================================

local function EggRecordExists(uid)

if not uid then  
    return false  
end  

return EggState.ReadFieldEgg(uid) ~= nil

end

local function IsCarryingUid(uid)

if not uid then  
    return false  
end  

return  
    lastCarryData ~= nil  
    and tostring(lastCarryData.Uid)  
        == tostring(uid)

end

local function IsOwnedByMe(uid)

if not uid then  
    return false  
end  

return  
    EggState.ReadOwnedEgg(  
        Player.UserId,  
        uid  
    ) ~= nil

end

-- =========================================================
-- FIND EGG INSTANCE
-- =========================================================

local function GetEggByUid(uid)

if not uid then  
    return nil  
end  

local egg =  
    Workspace:FindFirstChild(  
        tostring(uid),  
        true  
    )  

if not egg then  
    return nil  
end  

if egg:IsA("BasePart") then  

    return egg  

elseif egg:IsA("Model") then  

    return  
        egg.PrimaryPart  
        or egg:FindFirstChildWhichIsA(  
            "BasePart",  
            true  
        )  
end  

return nil

end

-- =========================================================
-- FILTER DATA
-- =========================================================

local SelectedEggZones = {}
local SelectedEggNames = {}
local SelectedMutations = {}

-- =========================================================
-- CHECK SELECTION
-- =========================================================

local function IsSelected(selection, value)

-- ไม่เลือกอะไร = ไม่กรอง  
if next(selection) == nil then  
    return true  
end  

return selection[tostring(value)] == true

end

-- =========================================================
-- GET MUTATION FROM EGG RECORD
-- =========================================================

local function GetEggMutation(record)

if not record then  
    return "Unknown"  
end  

-- รองรับชื่อที่อาจถูกเก็บไว้ใน Record  
local mutation =  
    record.Mutation  
    or record.MutationName  
    or record.MutationId  
    or record.MutationType  

if mutation ~= nil then  
    return tostring(mutation)  
end  

-- ถ้าไม่มีข้อมูล Mutation ใน Record  
return "None"

end

-- =========================================================
-- GET MUTATION NAMES
-- จาก ReplicatedStorage.Mutations
-- =========================================================

local function GetMutationNames()

local mutations = {}  
local seen = {}  

print("===== มิวเทชั่นทั้งหมด =====")  
print(  
    "จำนวนมิวเทชั่น:",  
    #Mutations:GetChildren()  
)  
print("")  

for _, folder in  
    ipairs(Mutations:GetChildren()) do  

    if folder:IsA("Folder") then  

        print(  
            "🧬",  
            folder.Name  
        )  

        if not seen[folder.Name] then  

            seen[folder.Name] = true  

            table.insert(  
                mutations,  
                folder.Name  
            )  
        end  
    end  
end  

table.sort(  
    mutations,  
    function(a, b)  
        return tostring(a)  
            < tostring(b)  
    end  
)  

return mutations

end

-- =========================================================
-- GET ALL FILTER VALUES
-- =========================================================

local function GetEggFilterData()

local zones = {}  
local names = {}  

local zoneSet = {}  
local nameSet = {}  

local fieldData =  
    EggState.ReadFieldEggs()  

if not fieldData  
    or not fieldData.Records then  

    return  
        zones,  
        names  
end  

for _, record in  
    ipairs(fieldData.Records) do  

    -- Zone  
    local zone =  
        tostring(  
            record.AreaId  
            or "Unknown"  
        )  

    if not zoneSet[zone] then  

        zoneSet[zone] = true  

        table.insert(  
            zones,  
            zone  
        )  
    end  

    -- Egg Name  
    local name =  
        tostring(  
            record.AssetCategory  
            or "Unknown"  
        )  

    if not nameSet[name] then  

        nameSet[name] = true  

        table.insert(  
            names,  
            name  
        )  
    end  
end  

table.sort(  
    zones,  
    function(a, b)  
        return tostring(a)  
            < tostring(b)  
    end  
)  

table.sort(  
    names,  
    function(a, b)  
        return tostring(a)  
            < tostring(b)  
    end  
)  

return  
    zones,  
    names

end

-- =========================================================
-- GET FILTERED EGGS
-- =========================================================

local function GetFilteredEggs()

local fieldData =  
    EggState.ReadFieldEggs()  

if not fieldData  
    or not fieldData.Records then  

    return {}  
end  

local result = {}  

for _, record in  
    ipairs(fieldData.Records) do  

    local zone =  
        tostring(  
            record.AreaId  
            or "Unknown"  
        )  

    local name =  
        tostring(  
            record.AssetCategory  
            or "Unknown"  
        )  

    local mutation =  
        GetEggMutation(record)  

    if  
        IsSelected(  
            SelectedEggZones,  
            zone  
        )  
        and  
        IsSelected(  
            SelectedEggNames,  
            name  
        )  
        and  
        IsSelected(  
            SelectedMutations,  
            mutation  
        )  
    then  

        table.insert(  
            result,  
            record  
        )  
    end  
end  

return result

end

-- =========================================================
-- FIND NEAREST FILTERED EGG
-- =========================================================

local function GetNearestFilteredEgg()

local Root =  
    GetRoot()  

if not Root then  
    return nil, nil  
end  

local records =  
    GetFilteredEggs()  

local nearestPart = nil  
local nearestUid = nil  
local nearestDistance =  
    math.huge  

for _, record in  
    ipairs(records) do  

    local uid =  
        tostring(  
            record.Uid  
        )  

    local egg =  
        Workspace:FindFirstChild(  
            uid,  
            true  
        )  

    if egg then  

        local part  

        if egg:IsA("BasePart") then  

            part = egg  

        elseif egg:IsA("Model") then  

            part =  
                egg.PrimaryPart  
                or egg:FindFirstChildWhichIsA(  
                    "BasePart",  
                    true  
                )  
        end  

        if part then  

            local distance =  
                (  
                    Root.Position  
                    - part.Position  
                ).Magnitude  

            if distance  
                < nearestDistance then  

                nearestDistance =  
                    distance  

                nearestPart =  
                    part  

                nearestUid =  
                    uid  
            end  
        end  
    end  
end  

return  
    nearestPart,  
    nearestUid

end

-- =========================================================
-- LOAD FILTER VALUES
-- =========================================================

local zones,
names =
GetEggFilterData()

local mutationNames =
GetMutationNames()

-- =========================================================
-- ZONE DROPDOWN
-- =========================================================

local ZoneDropdown =
FilterGroup:AddDropdown({

Title = "Zone",  

    Values = zones,  

    Default = {},  

    Multi = true,  

    Flag = "EggZones",  

    Callback = function(Value)  

        SelectedEggZones =  
            Value or {}  

        print(  
            "[Egg Filter] Zones changed"  
        )  

        for name, enabled in  
            pairs(  
                SelectedEggZones  
            ) do  

            if enabled then  

                print(  
                    "Zone:",  
                    name  
                )  
            end  
        end  
    end  
})

-- =========================================================
-- EGG NAME DROPDOWN
-- =========================================================

local NameDropdown =
FilterGroup:AddDropdown({

Title = "Egg Name",  

    Values = names,  

    Default = {},  

    Multi = true,  

    Flag = "EggNames",  

    Callback = function(Value)  

        SelectedEggNames =  
            Value or {}  

        print(  
            "[Egg Filter] Egg Names changed"  
        )  

        for name, enabled in  
            pairs(  
                SelectedEggNames  
            ) do  

            if enabled then  

                print(  
                    "Egg:",  
                    name  
                )  
            end  
        end  
    end  
})

-- =========================================================
-- MUTATION DROPDOWN
-- =========================================================

local MutationDropdown =
FilterGroup:AddDropdown({

Title = "Mutation",  

    Values = mutationNames,  

    Default = {},  

    Multi = true,  

    Flag = "EggMutations",  

    Callback = function(Value)  

        SelectedMutations =  
            Value or {}  

        print(  
            "[Egg Filter] Mutations changed"  
        )  

        for name, enabled in  
            pairs(  
                SelectedMutations  
            ) do  

            if enabled then  

                print(  
                    "🧬 Mutation:",  
                    name  
                )  
            end  
        end  
    end  
})

-- =========================================================
-- REFRESH FILTER
-- =========================================================

FilterGroup:AddButton({

Title = "Refresh Egg List",  

Callback = function()  

    local newZones,  
        newNames =  
            GetEggFilterData()  

    local newMutations =  
        GetMutationNames()  

    ZoneDropdown.Refresh(  
        newZones  
    )  

    NameDropdown.Refresh(  
        newNames  
    )  

    MutationDropdown.Refresh(  
        newMutations  
    )  

    Library:Notify(  
        "Egg Filter",  
        "Egg list refreshed!",  
        2  
    )  
end

})

-- =========================================================
-- CLEAR FILTER
-- =========================================================

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
end

})

-- =========================================================
-- STATUS
-- =========================================================

local StatusParagraph =
FarmGroup:AddParagraph({

Title = "Egg Filter Status",  

    Content =  
        "Matching Eggs: 0\n"  
        .. "Farming: Idle",  

    TextWrapped = true  
})

task.spawn(function()

while task.wait(0.5) do  

    local filtered =  
        GetFilteredEggs()  

    if StatusParagraph then  

        StatusParagraph:SetDesc(  
            "Matching Eggs: "  
            .. tostring(  
                #filtered  
            )  
            .. "\nFarming: "  
            .. (  
                Lll  
                and "Running"  
                or "Idle"  
            )  
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
    character:WaitForChild(  
        "HumanoidRootPart"  
    )  

local humanoid =  
    character:WaitForChild(  
        "Humanoid"  
    )  

local maxSpeed =  
    humanoid.WalkSpeed  

Lll = true  

-- Disable collision  
for _, part in  
    ipairs(  
        character:GetDescendants()  
    ) do  

    if part:IsA("BasePart") then  
        part.CanCollide = false  
    end  
end  

-- Remove old velocity  
local oldVelocity =  
    rootPart:FindFirstChild(  
        "SmoothBodyVelocity"  
    )  

if oldVelocity then  
    oldVelocity:Destroy()  
end  

-- BodyVelocity  
local bodyVelocity =  
    Instance.new(  
        "BodyVelocity"  
    )  

bodyVelocity.Name =  
    "SmoothBodyVelocity"  

bodyVelocity.MaxForce =  
    Vector3.new(  
        math.huge,  
        math.huge,  
        math.huge  
    )  

bodyVelocity.P = 10000  

bodyVelocity.Parent =  
    rootPart  

local sessionActive = true  
local success = false  

-- =====================================================  
-- CARRY REMOTE LOOP  
-- =====================================================  

task.spawn(function()  

    while sessionActive do  

        if IsOwnedByMe(uid) then  

            print(  
                "[RunEggSession] เป็นเจ้าของไข่แล้ว:",  
                uid  
            )  

            success = true  
            sessionActive = false  

            break  
        end  

        if not EggRecordExists(uid) then  

            print(  
                "[RunEggSession] ไข่หายไป:",  
                uid  
            )  

            success = false  
            sessionActive = false  

            break  
        end  

        pcall(function()  

            CarryRemote:InvokeServer({  

                Uid = uid,  

                FirstAreaSlotKey = nil  
            })  

        end)  

        task.wait()  
    end  
end)  

-- =====================================================  
-- MOVEMENT  
-- =====================================================  

local moveConn  

moveConn =  
    RunService.Heartbeat:Connect(  
        function(dt)  

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

            -- ถือไข่แล้ว -> Drop Off  
            if IsCarryingUid(uid) then  

                targetPosition =  
                    DROP_OFF_POSITION  

            else  

                -- ยังไม่ถือ -> ไปหาไข่  
                local eggPart =  
                    GetEggByUid(uid)  

                if eggPart then  

                    targetPosition =  
                        eggPart.Position  
                        + Vector3.new(  
                            0,  
                            3,  
                            0  
                        )  

                else  

                    bodyVelocity.Velocity =  
                        Vector3.zero  

                    return  
                end  
            end  

            local offset =  
                targetPosition  
                - rootPart.Position  

            local distance =  
                offset.Magnitude  

            if distance  
                <= ARRIVE_DISTANCE then  

                bodyVelocity.Velocity =  
                    Vector3.zero  

                return  
            end  

            local maxTravelThisFrame =  
                distance  
                / math.max(  
                    dt,  
                    1 / 240  
                )  

            local speed =  
                math.min(  
                    maxSpeed,  
                    maxTravelThisFrame  
                )  

            if distance < maxSpeed then  

                speed =  
                    math.min(  
                        speed,  
                        math.max(  
                            distance * 4,  
                            4  
                        )  
                    )  
            end  

            bodyVelocity.Velocity =  
                offset.Unit * speed  
        end  
    )  

    -- =====================================================  
-- WAIT  
-- =====================================================  

while sessionActive do  
    task.wait()  
end  

-- =====================================================  
-- CLEANUP  
-- =====================================================  

if moveConn then  
    moveConn:Disconnect()  
end  

if bodyVelocity then  

    bodyVelocity.Velocity =  
        Vector3.zero  

    bodyVelocity:Destroy()  
end  

Lll = false  

-- Restore collision  
if character then  

    for _, part in  
        ipairs(  
            character:GetDescendants()  
        ) do  

        if part:IsA("BasePart") then  
            part.CanCollide = true  
        end  
    end  
end  

return success

end

-- =========================================================
-- FARM ONE FILTERED EGG
-- =========================================================

local function FarmOneEgg()

if Lll then  

    print(  
        "[FarmOneEgg] Already farming"  
    )  

    return  
end  

local Egg, EggUid =  
    GetNearestFilteredEgg()  

if not Egg or not EggUid then  

    print(  
        "[FarmOneEgg] ไม่พบไข่ที่ตรง Filter"  
    )  

    task.wait(1)  

    return  
end  

print(  
    "[FarmOneEgg] เลือกไข่:",  
    EggUid  
)  

local success =
    RunEggSession(EggUid)

if success then

    print(
        "[FarmOneEgg] ได้ไข่แล้ว ->",
        EggUid
    )

else

    print(
        "[FarmOneEgg] พลาดไข่ ->",
        EggUid
    )

end

-- =========================================================
-- CARRY STATE
-- =========================================================

EggState.CarryChanged:Connect(
    function(data)

        lastCarryData = data

        if data == nil then

            print(
                "[CarryChanged] ไม่ได้ถือไข่แล้ว"
            )

        else

            print(
                "[CarryChanged] กำลังถือไข่ Uid:",
                data.Uid
            )

        end
    end
)

-- =========================================================
-- AUTO FARM TOGGLE
-- =========================================================

local AutoFarm = false
local FarmThread = nil

FarmGroup:AddToggle({

    Title = "Auto Farm Eggs",

    Default = false,

    Flag = "AutoFarmEggs",

    Callback = function(Value)

        AutoFarm = Value

        if Value then

            if FarmThread then
                return
            end

            FarmThread =
                task.spawn(function()

                    while AutoFarm do

                        if not Lll then

                            local egg =
                                GetNearestFilteredEgg()

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
    end
})

-- =========================================================
-- START
-- =========================================================

print(
    "===== BONK HUB EGG FARM LOADED ====="
)

print(
    "Zone / Egg Name / Mutation Filter Ready"
  )
