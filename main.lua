--[[
    SEARCH FOR THE NEEDLE - ULTIMATE AUTOMATION HUB v5.5 PRO
    Forensically Engineered from Luau Decompiler Bytecode Dump
    - Exact Multi-Grab Batching using LocalPlayer:GetAttribute("HayGrabCount") & getGrabCandidates
    - Rainbow / RGB Straw Priority via Neon, Material, and Config.isRainbow(hayId)
    - Auto Collect Gems via workspace.GemsClient & CollectGem(GemId)
    - Auto-Win Needle via PickHay("Objective"), slot equip, and Farmer hand-in
    - Full Autonomous Sell-Cycle at CollectionService:GetTagged("SellPart")
    - Fixed Smooth Window Dragging, Minimize Button, Floating Menu Toggle & Unload Button
    - 3rd Person Camera & Right-Click 360 Orbiting
    - Zero Emojis - 100% Safe Execution
]]

-- SECTION 1: CORE INFRASTRUCTURE & SAFETY SHIELD
local successLoaded, _ = pcall(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
end)

local function safeService(serviceName)
    local service = nil
    pcall(function()
        if cloneref then
            service = cloneref(game:GetService(serviceName))
        else
            service = game:GetService(serviceName)
        end
    end)
    if not service then
        pcall(function()
            service = game:GetService(serviceName)
        end)
    end
    return service
end

local Players = safeService("Players")
local ReplicatedStorage = safeService("ReplicatedStorage")
local RunService = safeService("RunService")
local UserInputService = safeService("UserInputService")
local TweenService = safeService("TweenService")
local TeleportService = safeService("TeleportService")
local CollectionService = safeService("CollectionService")
local CoreGui = safeService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local startClock = os.clock()
    while not LocalPlayer and (os.clock() - startClock) < 10 do
        task.wait(0.2)
        LocalPlayer = Players.LocalPlayer
    end
end

if not LocalPlayer then
    warn("[Hub Error]: Failed to locate LocalPlayer.")
    return
end

local HubConnections = {}
local HubThreads = {}
local IsHubLoaded = true
local GlobalScreenGui = nil
local FloatingButtonGui = nil

-- SECTION 2: PLACE CONTEXT & CONFIG
local CURRENT_PLACE_ID = game.PlaceId
local LOBBY_PLACE_ID = 77108422251420
local FARMHOUSE_PLACE_ID = 108628039999641
local BASEMENT_PLACE_ID = 83445806734780

local IS_GAMEPLAY = (CURRENT_PLACE_ID == FARMHOUSE_PLACE_ID or CURRENT_PLACE_ID == BASEMENT_PLACE_ID)
local IS_LOBBY = (CURRENT_PLACE_ID == LOBBY_PLACE_ID)

local GAME_MODE_NAME = "Unknown"
if IS_LOBBY then
    GAME_MODE_NAME = "Lobby"
elseif CURRENT_PLACE_ID == FARMHOUSE_PLACE_ID then
    GAME_MODE_NAME = "Farmhouse"
elseif CURRENT_PLACE_ID == BASEMENT_PLACE_ID then
    GAME_MODE_NAME = "Basement"
else
    GAME_MODE_NAME = "Place " .. tostring(CURRENT_PLACE_ID)
end
local CURRENT_PLACE_NAME = GAME_MODE_NAME
local SCRIPT_VERSION = "5.5"
local CurrentContextMode = IS_LOBBY and "Lobby" or "Match"

-- Require game Config if available for exact mathematical rainbow calculations
local HaystackConfig = nil
pcall(function()
    local nh = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if nh and nh:FindFirstChild("Config") then
        HaystackConfig = require(nh.Config)
    end
end)

local GemConfig = nil
pcall(function()
    local nh = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if nh and nh:FindFirstChild("GemConfig") then
        GemConfig = require(nh.GemConfig)
    end
end)

-- SECTION 3: LOGGING SYSTEM
local LogEntries = {}
local MAX_LOGS = 100

local function addLog(level, message)
    if not IsHubLoaded then return end
    local timestamp = os.date("%H:%M:%S")
    local formatted = string.format("[%s] [%s] %s", timestamp, string.upper(level), tostring(message))
    table.insert(LogEntries, formatted)
    if #LogEntries > MAX_LOGS then
        table.remove(LogEntries, 1)
    end
    print("[NeedleHub] " .. formatted)
end

addLog("info", "Initialized Hub v5.0 on " .. GAME_MODE_NAME)

-- SECTION 4: CHARACTER & MOVEMENT HELPERS
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    if char then
        return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 4)
    end
    return nil
end

local function getHumanoid()
    local char = getCharacter()
    if char then
        return char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 4)
    end
    return nil
end

local function teleportTo(targetCFrame)
    local hrp = getHRP()
    if hrp and targetCFrame then
        if typeof(targetCFrame) == "Vector3" then
            hrp.CFrame = CFrame.new(targetCFrame + Vector3.new(0, 3.0, 0))
        elseif typeof(targetCFrame) == "CFrame" then
            hrp.CFrame = targetCFrame + Vector3.new(0, 3.0, 0)
        end
        return true
    end
    return false
end

-- SECTION 5: REMOTE REPOSITORIES
local Remotes = {
    PickHay = nil,
    PickDroppedHay = nil,
    DropHay = nil,
    SellHay = nil,
    HaySold = nil,
    BuyUpgrade = nil,
    UpgradeChanged = nil,
    PitchforkDig = nil,
    PitchforkDug = nil,
    TntAction = nil,
    TntExploded = nil,
    VacuumAction = nil,
    VacuumHarvested = nil,
    DeployDrone = nil,
    DroneHarvested = nil,
    DroneSold = nil,
    CollectGem = nil,
    GemSpawned = nil,
    GemCollected = nil,
    NeedleFound = nil,
    NeedleHandIn = nil,
    NeedleTargetChanged = nil,
    NeedleRoundCompleted = nil,
    BuyShopItem = nil,
    ShopPurchaseResult = nil,
    HeldToolState = nil,
    ClassEffect = nil,
    IntroCutsceneFinished = nil,
    TutorialCompleted = nil,
    ReturnToLobby = nil,
    GetHayState = nil,
    GetUpgradeState = nil,

    RedeemCode = nil,
    OpenChest = nil,
    EquipPet = nil,
    EquipSkin = nil,
    RollClass = nil,
    SelectClassSlot = nil,
}

local function findRemoteRecursive(name)
    if not ReplicatedStorage then return nil end
    local direct = ReplicatedStorage:FindFirstChild(name, true)
    if direct and (direct:IsA("RemoteEvent") or direct:IsA("RemoteFunction")) then
        return direct
    end
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if (desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction")) and desc.Name:lower() == name:lower() then
            return desc
        end
    end
    return nil
end

local function bindRemotes()
    if ReplicatedStorage then
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
                Remotes[desc.Name] = desc
            end
        end
    end

    for key, _ in pairs(Remotes) do
        if not Remotes[key] then
            Remotes[key] = findRemoteRecursive(key)
        end
    end
end

bindRemotes()

-- SECTION 6: WORKSPACE LANDMARKS & SELL DETECTION
local Landmarks = {
    SellCow = Vector3.new(-163.37, 5.0, 52.0),
    FarmerNPC = Vector3.new(-161.05, 5.0, 18.3),
    HayCenter = Vector3.new(-190.0, 4.0, 45.0),
    NeedleCFrame = nil,
    TargetNeedleHayId = nil,
}

local function scanExactLandmarks()
    -- Farmer NPC
    local npcFolder = workspace:FindFirstChild("NPC")
    if npcFolder and npcFolder:FindFirstChild("Farmer_NPC") then
        local root = npcFolder.Farmer_NPC:FindFirstChild("HumanoidRootPart") or npcFolder.Farmer_NPC:FindFirstChildWhichIsA("BasePart")
        if root then Landmarks.FarmerNPC = root.Position end
    end

    -- Real Sell Part via CollectionService Tag "SellPart"
    local sellParts = CollectionService:GetTagged("SellPart")
    if #sellParts > 0 then
        for _, sp in ipairs(sellParts) do
            if sp:IsA("BasePart") and sp:IsDescendantOf(workspace) then
                Landmarks.SellCow = sp.Position
                break
            end
        end
    else
        local sellModel = workspace:FindFirstChild("SellModel")
        if sellModel then
            local sp = sellModel:FindFirstChild("SellPart") or sellModel:FindFirstChild("HayPile") or sellModel:FindFirstChildWhichIsA("BasePart")
            if sp then
                Landmarks.SellCow = sp.Position
            end
        end
    end

    -- Hay Center
    local haystack = workspace:FindFirstChild("HaystackClient")
    if haystack then
        local firstPart = haystack:FindFirstChildWhichIsA("BasePart")
        if firstPart then
            Landmarks.HayCenter = firstPart.Position
        end
    end

    -- Needle object in workspace
    local needleObj = workspace:FindFirstChild("The Needle") or workspace:FindFirstChild("HiddenNeedleClient")
    if needleObj then
        if needleObj:IsA("BasePart") then
            Landmarks.NeedleCFrame = needleObj.CFrame
        elseif needleObj:IsA("Model") then
            local p = needleObj.PrimaryPart or needleObj:FindFirstChildWhichIsA("BasePart")
            if p then Landmarks.NeedleCFrame = p.CFrame end
        end
    end
end

scanExactLandmarks()

if Remotes.NeedleTargetChanged then
    local conn = Remotes.NeedleTargetChanged.OnClientEvent:Connect(function(targetArg)
        if typeof(targetArg) == "number" then
            Landmarks.TargetNeedleHayId = targetArg
            addLog("info", "Needle target HayId: " .. tostring(targetArg))
        elseif typeof(targetArg) == "CFrame" then
            Landmarks.NeedleCFrame = targetArg
            addLog("info", "Needle target CFrame updated")
        end
    end)
    table.insert(HubConnections, conn)
end

if Remotes.NeedleFound then
    local conn = Remotes.NeedleFound.OnClientEvent:Connect(function(finderUserId, finderName, ...)
        if finderUserId == LocalPlayer.UserId then
            addLog("warn", "YOU FOUND THE NEEDLE! Delivering to farmer...")
        else
            addLog("info", tostring(finderName) .. " found the needle!")
        end
    end)
    table.insert(HubConnections, conn)
end

-- SECTION 7: GLOBAL HUB STATE
local HubState = {
    -- Auto Farm
    AutoFarmHay = false,
    PrioritizeRGB = true,
    BatchMultiGrab = true,
    AutoSell = true,
    AutoCollectGems = true,
    AutoWinNeedle = true,
    AutoDeployDrone = true,
    AutoBuyTools = false,
    AutoBuyUpgrades = false,
    AutoEquipBestTool = true,
    AutoUseTnt = true,
    TntInterval = 11,
    ForcedToolSlot = 0,
    FarmCooldown = 0.35,

    -- Player Mods
    FreeMouse = true,
    UnlockCamera = true,
    CameraZoomDistance = 22,
    WalkSpeedEnabled = false,
    WalkSpeed = 16,
    JumpHeightEnabled = false,
    JumpHeight = 7.2,
    FlyEnabled = false,
    FlySpeed = 80,
    NoclipEnabled = false,
    InfiniteJump = false,

    -- Visuals & ESP
    NeedleESP = true,
    RgbESP = true,
    GemESP = true,
    PlayerESP = false,
    SellESP = true,

    -- Lobby
    AutoRollClass = false,
    TargetClass = "Ultimate Farmer",
}

-- TOOL SLOTS & INTELLIGENT RECOGNITION SYSTEM
local SLOT_HAND = 1
local SLOT_TNT = 2
local SLOT_PITCHFORK = 3
local SLOT_DRONE = 4
local SLOT_VACUUM = 5
local SLOT_NEEDLE = 6

local ToolNames = {
    [1] = "Hand",
    [2] = "TNT",
    [3] = "Pitchfork",
    [4] = "Drone",
    [5] = "Vacuum",
    [6] = "The Needle"
}

local CachedHotbarSlots = nil
local function getHotbarSlots()
    if CachedHotbarSlots then return CachedHotbarSlots end
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if ps then
        local mod = ps:FindFirstChild("HotbarSlots")
        if mod and mod:IsA("ModuleScript") then
            local ok, res = pcall(require, mod)
            if ok and type(res) == "table" then
                CachedHotbarSlots = res
                return res
            end
        end
    end
    local nh = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if nh then
        local mod = nh:FindFirstChild("HotbarSlots")
        if mod and mod:IsA("ModuleScript") then
            local ok, res = pcall(require, mod)
            if ok and type(res) == "table" then
                CachedHotbarSlots = res
                return res
            end
        end
    end
    return nil
end

local function getCurrentEquippedSlot()
    local hotbar = getHotbarSlots()
    if hotbar and type(hotbar.getEquipped) == "function" then
        local ok, slot = pcall(hotbar.getEquipped)
        if ok and type(slot) == "number" then
            return slot
        end
    end
    local attr = LocalPlayer:GetAttribute("NeedleEquippedSlot")
    if type(attr) == "number" then
        return attr
    end
    return SLOT_HAND
end

local function isToolOwned(toolName)
    if toolName == "Needle" then
        return LocalPlayer:GetAttribute("NeedleOwned") == true or LocalPlayer:GetAttribute("HasNeedle") == true
    elseif toolName == "Vacuum" then
        return (LocalPlayer:GetAttribute("VacuumOwned") == true
            or LocalPlayer:GetAttribute("PermanentVacuumOwned") == true
            or (LocalPlayer:GetAttribute("VacuumHeatTime") and LocalPlayer:GetAttribute("VacuumHeatTime") > 0)
            or (LocalPlayer:GetAttribute("VacuumGrabCount") and LocalPlayer:GetAttribute("VacuumGrabCount") > 0))
    elseif toolName == "Pitchfork" then
        return (LocalPlayer:GetAttribute("PitchforkOwned") == true
            or LocalPlayer:GetAttribute("PermanentPitchforkOwned") == true
            or (LocalPlayer:GetAttribute("PitchforkReach") and LocalPlayer:GetAttribute("PitchforkReach") > 0)
            or (LocalPlayer:GetAttribute("PitchforkScoop") and LocalPlayer:GetAttribute("PitchforkScoop") > 0))
    elseif toolName == "Tnt" then
        return (LocalPlayer:GetAttribute("TntOwned") == true
            or LocalPlayer:GetAttribute("PermanentTntOwned") == true
            or (LocalPlayer:GetAttribute("TntBlastRadius") and LocalPlayer:GetAttribute("TntBlastRadius") > 0)
            or (LocalPlayer:GetAttribute("TntCooldown") and LocalPlayer:GetAttribute("TntCooldown") > 0))
    elseif toolName == "Drone" then
        return (LocalPlayer:GetAttribute("DroneOwned") == true
            or LocalPlayer:GetAttribute("PermanentDroneOwned") == true
            or (LocalPlayer:GetAttribute("DroneCapacity") and LocalPlayer:GetAttribute("DroneCapacity") > 0))
    elseif toolName == "Hand" then
        return true
    end
    return false
end

local function isVacuumReady()
    if not isToolOwned("Vacuum") then return false end
    local overheated = LocalPlayer:GetAttribute("VacuumOverheated") == true
    local state = tostring(LocalPlayer:GetAttribute("VacuumState") or "")
    if overheated or state:lower():find("overheat") then
        return false
    end
    return true
end

local function getBestAvailableToolSlot()
    -- Priority 1: The Needle (Slot 6) - Win condition!
    if isToolOwned("Needle") then
        return SLOT_NEEDLE, "The Needle"
    end

    -- Manual Override
    if HubState.ForcedToolSlot and HubState.ForcedToolSlot > 0 then
        local forced = HubState.ForcedToolSlot
        return forced, ToolNames[forced] or ("Slot " .. tostring(forced))
    end

    -- Priority 2: Vacuum (Slot 5) - Top tier harvester (5 batch + rapid suction)
    if isVacuumReady() then
        return SLOT_VACUUM, "Vacuum"
    end

    -- Priority 3: Pitchfork (Slot 3) - High power scoop & reach
    if isToolOwned("Pitchfork") then
        return SLOT_PITCHFORK, "Pitchfork"
    end

    -- Priority 4: Hand (Slot 1) - Default fallback
    return SLOT_HAND, "Hand"
end

local lastEquippedSlotLogged = -1
local function equipToolSlot(slotIndex, silent)
    if not slotIndex or type(slotIndex) ~= "number" then return end

    -- 1. Game State Attributes
    pcall(function()
        LocalPlayer:SetAttribute("NeedleEquippedSlot", slotIndex)
    end)

    -- 2. Client Hotbar Module
    local hotbar = getHotbarSlots()
    if hotbar and type(hotbar.setEquipped) == "function" then
        pcall(function()
            hotbar.setEquipped(slotIndex, false)
        end)
    end

    -- 3. Virtual Input Keypress Simulation (Keys 1 to 6)
    pcall(function()
        local vim = safeService("VirtualInputManager")
        local keyMap = {
            [1] = Enum.KeyCode.One,
            [2] = Enum.KeyCode.Two,
            [3] = Enum.KeyCode.Three,
            [4] = Enum.KeyCode.Four,
            [5] = Enum.KeyCode.Five,
            [6] = Enum.KeyCode.Six,
        }
        if vim and keyMap[slotIndex] then
            vim:SendKeyEvent(true, keyMap[slotIndex], false, game)
            task.wait(0.015)
            vim:SendKeyEvent(false, keyMap[slotIndex], false, game)
        end
    end)

    -- 4. PlayerGui Hotbar Button Interaction
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if (desc:IsA("ImageButton") or desc:IsA("TextButton")) and desc.Visible then
                            if desc.Name == tostring(slotIndex) or desc.Name == ("Slot" .. tostring(slotIndex)) or desc:GetAttribute("Slot") == slotIndex then
                                desc.Selectable = true
                                if firesignal then
                                    firesignal(desc.MouseButton1Click)
                                elseif desc.Activate then
                                    desc:Activate()
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    if not silent and lastEquippedSlotLogged ~= slotIndex then
        lastEquippedSlotLogged = slotIndex
        local tName = ToolNames[slotIndex] or ("Slot " .. tostring(slotIndex))
        addLog("info", "Equipped Tool: " .. tName .. " (Slot " .. slotIndex .. ")")
    end
end

-- Dedicated Autonomous TNT Thrower
local function throwTntAt(targetPos)
    if not isToolOwned("Tnt") then
        addLog("warn", "TNT is not owned. Purchase it from the Barn shop!")
        return false
    end
    local hrp = getHRP()
    if not hrp then return false end

    local tntAction = Remotes.TntAction or (ReplicatedStorage:FindFirstChild("NeedleHaystack") and ReplicatedStorage.NeedleHaystack:FindFirstChild("TntAction"))
    if not tntAction then
        addLog("warn", "TntAction remote not found in game!")
        return false
    end

    local prevSlot = getCurrentEquippedSlot()
    equipToolSlot(SLOT_TNT, true)
    task.wait(0.06)

    pcall(function()
        tntAction:FireServer("light")
    end)
    addLog("info", "TNT: Lit fuse match! Aiming at hay...")

    task.wait(0.48) -- Exact light duration from Config.TNT_LIGHT_TIME

    local hrpPos = hrp.Position
    local target = targetPos or Landmarks.HayCenter or (hrpPos + hrp.CFrame.LookVector * 20)
    local origin = hrpPos + Vector3.new(0, 2.5, 0)
    local dir = (target - origin).Unit
    local vel = dir * 44 + Vector3.new(0, 14, 0)
    local throwCF = CFrame.new(origin, target)

    pcall(function()
        tntAction:FireServer("throw", throwCF, vel)
    end)
    addLog("info", "TNT: THROWN into hay mound! Massive explosive harvest pending!")

    task.wait(0.2)
    if HubState.AutoEquipBestTool then
        local bestSlot = getBestAvailableToolSlot()
        equipToolSlot(bestSlot, true)
    else
        equipToolSlot(prevSlot > 0 and prevSlot or SLOT_HAND, true)
    end
    return true
end

local function getToolStatusSummary()
    local curSlot = getCurrentEquippedSlot()
    local curName = ToolNames[curSlot] or ("Slot " .. tostring(curSlot))
    local bestSlot, bestName = getBestAvailableToolSlot()

    local vOwned = isToolOwned("Vacuum") and (isVacuumReady() and "YES" or "OVERHEATED") or "NO"
    local pOwned = isToolOwned("Pitchfork") and "YES" or "NO"
    local tOwned = isToolOwned("Tnt") and "YES" or "NO"
    local dOwned = isToolOwned("Drone") and (LocalPlayer:GetAttribute("DroneDeployed") == true and "DEPLOYED" or "YES") or "NO"

    return string.format("Active: [%s] (Slot %d) | Best: [%s]\nOwned: Vacuum: %s | Pitchfork: %s | TNT: %s | Drone: %s",
        curName, curSlot, bestName, vOwned, pOwned, tOwned, dOwned)
end

local function getHayHeld()
    local val = LocalPlayer:GetAttribute("HayHeld")
    if val and type(val) == "number" then return val end
    return 0
end

local function getHayCapacity()
    local val = LocalPlayer:GetAttribute("HayCapacity")
    if val and type(val) == "number" then return val end
    return 25
end

local function getGrabCount()
    local val = LocalPlayer:GetAttribute("HayGrabCount")
    if val and type(val) == "number" and val > 0 then return val end
    return 4 -- Default high grab
end

local function getGrabRadius()
    local val = LocalPlayer:GetAttribute("HayGrabRadius")
    if val and type(val) == "number" and val > 0 then return val end
    return 2.5
end

local function getPickCooldown()
    local val = LocalPlayer:GetAttribute("HayPickCooldown")
    if val and type(val) == "number" and val > 0 then return val end
    return 0.35
end

-- Snap camera to 3rd person
local function forceSnap3rdPerson(distance)
    pcall(function()
        local dist = distance or HubState.CameraZoomDistance
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = 350
        LocalPlayer.CameraMinZoomDistance = dist
        task.wait(0.05)
        LocalPlayer.CameraMinZoomDistance = 0.5
        addLog("info", "Camera zoomed to 3rd person (" .. dist .. " studs)")
    end)
end

-- Exact Rainbow / RGB Detector
local function isRainbowStrand(part)
    if not part or not part:IsA("BasePart") then return false end

    -- Check direct Rainbow / Mutation attributes (v1068 Hay Index updates)
    if part:GetAttribute("Rainbow") == true then return true end
    local mutation = part:GetAttribute("Mutation") or part:GetAttribute("HayType")
    if mutation and type(mutation) == "string" then
        local mLower = mutation:lower()
        if mLower:find("void") or mLower:find("rainbow") or mLower:find("electric") or mLower:find("gold") or mLower:find("glass") or mLower:find("burnt") then
            return true
        end
    end

    -- Check Neon material (Special straw mutations in NeedleHaystackClient are Neon / ForceField)
    if part.Material == Enum.Material.Neon or part.Material == Enum.Material.ForceField then
        return true
    end

    -- Mathematical check via Config.isRainbow(hayId)
    local hayId = part:GetAttribute("HayId")
    if hayId and HaystackConfig and HaystackConfig.isRainbow then
        local s, res = pcall(HaystackConfig.isRainbow, hayId)
        if s and res == true then return true end
    end

    -- Color check: Normal hay is tan/yellow (Hue 0.08..0.17). Rare straws have Hue outside yellow with saturation
    local h, s, v = part.Color:ToHSV()
    if s > 0.35 and (h < 0.08 or h > 0.17) then
        return true
    end

    return false
end

-- Exact Candidate Gathering (replicated from NeedleHaystackClient getGrabCandidates)
local function getGrabCandidates(primaryPart)
    local grabCount = getGrabCount()
    local grabRadius = getGrabRadius()

    if grabCount <= 1 or grabRadius <= 0 then
        return {}
    end

    local haystack = workspace:FindFirstChild("HaystackClient")
    if not haystack then return {} end

    local pos = primaryPart.Position
    local candidateList = {}

    -- Use GetPartBoundsInRadius for efficient cluster lookup
    local parts = workspace:GetPartBoundsInRadius(pos, grabRadius)
    for _, p in ipairs(parts) do
        if p ~= primaryPart and p.Parent == haystack and p:IsA("BasePart") then
            local hayId = p:GetAttribute("HayId")
            if hayId then
                local dist = (p.Position - pos).Magnitude
                if dist <= grabRadius then
                    table.insert(candidateList, {id = hayId, dist = dist})
                end
            end
        end
    end

    table.sort(candidateList, function(a, b) return a.dist < b.dist end)

    local candidateIds = {}
    local maxCandidates = math.min(grabCount - 1, #candidateList)
    for i = 1, maxCandidates do
        table.insert(candidateIds, candidateList[i].id)
    end

    return candidateIds
end

-- SECTION 8: AUTOMATION ENGINES

-- 8.1 FAST BATCH AUTO-FARM ENGINE (FULL RGB HUNTING + MULTI-GRAB + AUTO-SELL)
local isCurrentlySelling = false
local recentlyAttemptedStrands = {}

-- Function to find ALL active Rainbow / RGB strands across the entire map
local function getAllRainbowStrands()
    local haystack = workspace:FindFirstChild("HaystackClient")
    local rgbList = {}
    local now = os.clock()

    -- 1. Check all strands in HaystackClient (no limits / full map scan)
    if haystack then
        for _, p in ipairs(haystack:GetChildren()) do
            if p:IsA("BasePart") and p.Parent == haystack then
                local hayId = p:GetAttribute("HayId")
                if hayId then
                    local attempt = recentlyAttemptedStrands[hayId]
                    if not attempt or (now - attempt.time) > 2.5 or attempt.count < 3 then
                        if isRainbowStrand(p) then
                            table.insert(rgbList, p)
                        end
                    end
                end
            end
        end
    end

    -- 2. Check all strands in DroppedHay for rainbow pieces
    local dropped = workspace:FindFirstChild("DroppedHay")
    if dropped then
        for _, d in ipairs(dropped:GetChildren()) do
            if d:IsA("BasePart") and isRainbowStrand(d) then
                table.insert(rgbList, d)
            end
        end
    end

    return rgbList
end

local farmThread = task.spawn(function()
    while IsHubLoaded do
        local cooldown = getPickCooldown()
        task.wait(cooldown)

        if HubState.AutoFarmHay and IS_GAMEPLAY and not isCurrentlySelling then
            local hrp = getHRP()
            local char = getCharacter()

            if hrp and char then
                local currentHay = getHayHeld()
                local maxCap = getHayCapacity()

                -- FULL BAG CHECK -> COMPLETE AUTONOMOUS SELL CYCLE
                if currentHay >= maxCap and maxCap > 0 and HubState.AutoSell then
                    isCurrentlySelling = true
                    addLog("info", "Bag full (" .. currentHay .. "/" .. maxCap .. "). Travelling to Sell Cow...")

                    local farmReturnCFrame = hrp.CFrame
                    scanExactLandmarks()

                    -- Teleport to Cow / Sell Part
                    teleportTo(Landmarks.SellCow)
                    task.wait(0.2)

                    -- Fire Sell Remote
                    if Remotes.SellHay then
                        pcall(function() Remotes.SellHay:FireServer() end)
                    end

                    -- Wait until confirmed sold
                    local sellTimeout = os.clock()
                    while getHayHeld() > 0 and (os.clock() - sellTimeout) < 0.6 do
                        task.wait(0.06)
                        if Remotes.SellHay then pcall(function() Remotes.SellHay:FireServer() end) end
                    end

                    addLog("info", "Hay sold! Returning to harvest...")

                    -- Teleport back to hay pile
                    teleportTo(farmReturnCFrame)
                    task.wait(0.12)

                    isCurrentlySelling = false
                else
                    -- 0. Auto Deploy Drone if owned and not deployed
                    if HubState.AutoDeployDrone and isToolOwned("Drone") and LocalPlayer:GetAttribute("DroneDeployed") ~= true then
                        if Remotes.DeployDrone then
                            pcall(function() Remotes.DeployDrone:FireServer() end)
                        end
                    end

                    -- 1. Intelligent Tool Recognition & Auto-Equip
                    local activeSlot = getCurrentEquippedSlot()
                    if HubState.AutoEquipBestTool then
                        local bestSlot, bestName = getBestAvailableToolSlot()
                        if activeSlot ~= bestSlot then
                            equipToolSlot(bestSlot)
                            activeSlot = bestSlot
                        end
                    end

                    local myPos = hrp.Position
                    local haystack = workspace:FindFirstChild("HaystackClient")

                    -- 2. FULL RAINBOW HUNTING
                    local rgbStrands = {}
                    if HubState.PrioritizeRGB then
                        rgbStrands = getAllRainbowStrands()
                    end

                    if #rgbStrands > 0 then
                        -- Sort by distance to player: harvest closest RGB first
                        table.sort(rgbStrands, function(a, b)
                            return (a.Position - myPos).Magnitude < (b.Position - myPos).Magnitude
                        end)

                        local targetRgb = rgbStrands[1]
                        local targetPos = targetRgb.Position
                        local rId = targetRgb:GetAttribute("HayId")

                        -- Teleport player directly ON TOP of the RGB strand
                        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.6, 0))
                        task.wait(0.04)

                        if targetRgb.Parent and targetRgb.Parent.Name == "DroppedHay" then
                            if Remotes.PickDroppedHay then
                                pcall(function() Remotes.PickDroppedHay:FireServer(targetRgb) end)
                            end
                        elseif rId and Remotes.PickHay then
                            LocalPlayer:SetAttribute("HoveredHayId", rId)
                            local candidates = getGrabCandidates(targetRgb)

                            -- Track attempt
                            local now = os.clock()
                            if not recentlyAttemptedStrands[rId] then
                                recentlyAttemptedStrands[rId] = {time = now, count = 1}
                            else
                                recentlyAttemptedStrands[rId].time = now
                                recentlyAttemptedStrands[rId].count = recentlyAttemptedStrands[rId].count + 1
                            end

                            -- Tool-specific action trigger
                            if activeSlot == SLOT_PITCHFORK then
                                if Remotes.PitchforkDig then
                                    pcall(function() Remotes.PitchforkDig:FireServer(rId) end)
                                end
                                if Remotes.HeldToolState then
                                    pcall(function() Remotes.HeldToolState:FireServer("Pitchfork", "dig") end)
                                end
                                pcall(function() LocalPlayer:SetAttribute("PitchforkPhase", "strike") end)
                            elseif activeSlot == SLOT_VACUUM then
                                pcall(function() LocalPlayer:SetAttribute("VacuumActive", true) end)
                                if Remotes.VacuumAction then
                                    pcall(function() Remotes.VacuumAction:FireServer(targetPos, hrp.CFrame.LookVector) end)
                                end
                                if Remotes.VacuumHarvest then
                                    pcall(function() Remotes.VacuumHarvest:FireServer(targetPos, candidates) end)
                                end
                                if Remotes.VacuumDig then
                                    pcall(function() Remotes.VacuumDig:FireServer(rId) end)
                                end
                            end

                            pcall(function()
                                Remotes.PickHay:FireServer(rId, candidates)
                            end)
                            addLog("info", string.format("FOCUSED RGB straw [%s] using [%s] (+%d batch) | %d RGBs remaining",
                                tostring(rId), ToolNames[activeSlot] or "Hand", #candidates, #rgbStrands))
                        end
                    else
                        -- 3. NORMAL HAY HARVESTING (when 0 RGB straws remain on field)
                        if haystack then
                            local children = haystack:GetChildren()
                            local primaryPart = nil
                            local minDistance = 9999

                            -- First check if a strand is already right next to the player (fast O(1))
                            for _, p in ipairs(children) do
                                if p:IsA("BasePart") and p.Parent == haystack then
                                    local dist = (p.Position - myPos).Magnitude
                                    if dist < 4.5 then
                                        primaryPart = p
                                        minDistance = dist
                                        break
                                    elseif dist < minDistance then
                                        minDistance = dist
                                        primaryPart = p
                                    end
                                end
                            end

                            if primaryPart then
                                -- If more than 8 studs away, teleport directly onto it
                                if minDistance > 8 then
                                    hrp.CFrame = CFrame.new(primaryPart.Position + Vector3.new(0, 0.6, 0))
                                    task.wait(0.04)
                                end

                                local pId = primaryPart:GetAttribute("HayId")
                                if pId and Remotes.PickHay then
                                    LocalPlayer:SetAttribute("HoveredHayId", pId)
                                    local candidates = getGrabCandidates(primaryPart)

                                    -- Tool-specific action trigger
                                    if activeSlot == SLOT_PITCHFORK then
                                        if Remotes.PitchforkDig then
                                            pcall(function() Remotes.PitchforkDig:FireServer(pId) end)
                                        end
                                        if Remotes.HeldToolState then
                                            pcall(function() Remotes.HeldToolState:FireServer("Pitchfork", "dig") end)
                                        end
                                        pcall(function() LocalPlayer:SetAttribute("PitchforkPhase", "strike") end)
                                    elseif activeSlot == SLOT_VACUUM then
                                        pcall(function() LocalPlayer:SetAttribute("VacuumActive", true) end)
                                        if Remotes.VacuumAction then
                                            pcall(function() Remotes.VacuumAction:FireServer(primaryPart.Position, hrp.CFrame.LookVector) end)
                                        end
                                        if Remotes.VacuumHarvest then
                                            pcall(function() Remotes.VacuumHarvest:FireServer(primaryPart.Position, candidates) end)
                                        end
                                        if Remotes.VacuumDig then
                                            pcall(function() Remotes.VacuumDig:FireServer(pId) end)
                                        end
                                    end

                                    pcall(function()
                                        Remotes.PickHay:FireServer(pId, candidates)
                                    end)
                                end
                            end
                        end

                        if Remotes.PickDroppedHay then
                            local dropped = workspace:FindFirstChild("DroppedHay")
                            if dropped then
                                for _, d in ipairs(dropped:GetChildren()) do
                                    if d:IsA("BasePart") and (d.Position - myPos).Magnitude <= 20 then
                                        pcall(function() Remotes.PickDroppedHay:FireServer(d) end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
table.insert(HubThreads, farmThread)

-- 8.1b AUTONOMOUS TNT RECURRING CLEAVER ENGINE
local lastAutoTntThrow = 0
local tntThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(1)
        if HubState.AutoUseTnt and IS_GAMEPLAY and not isCurrentlySelling then
            local hrp = getHRP()
            if hrp and isToolOwned("Tnt") then
                local currentHay = getHayHeld()
                local maxCap = getHayCapacity()
                local now = os.clock()
                local cd = LocalPlayer:GetAttribute("TntCooldown") or HubState.TntInterval or 11
                if (now - lastAutoTntThrow) >= cd and (maxCap - currentHay) >= 10 then
                    lastAutoTntThrow = now
                    local target = nil
                    local rgbStrands = getAllRainbowStrands()
                    if #rgbStrands > 0 then
                        target = rgbStrands[1].Position
                    else
                        target = Landmarks.HayCenter or (hrp.Position + hrp.CFrame.LookVector * 18)
                    end
                    throwTntAt(target)
                end
            end
        end
    end
end)
table.insert(HubThreads, tntThread)

-- 8.2 AUTO COLLECT GEMS ENGINE
local gemThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(0.8)
        if HubState.AutoCollectGems and IS_GAMEPLAY and Remotes.CollectGem then
            local gemsFolder = workspace:FindFirstChild("GemsClient")
            local hrp = getHRP()
            if gemsFolder and hrp then
                local myPos = hrp.Position
                for _, g in ipairs(gemsFolder:GetChildren()) do
                    local gemId = g:GetAttribute("GemId")
                    if not gemId and g:IsA("Model") then
                        for _, kid in ipairs(g:GetDescendants()) do
                            if kid:GetAttribute("GemId") then
                                gemId = kid:GetAttribute("GemId")
                                break
                            end
                        end
                    end

                    if gemId then
                        local gemPos = g:IsA("BasePart") and g.Position or (g:IsA("Model") and g:GetPivot().Position or nil)
                        if gemPos then
                            local dist = (gemPos - myPos).Magnitude
                            -- Server COLLECT_DISTANCE is 30 studs
                            if dist <= 28 then
                                pcall(function() Remotes.CollectGem:FireServer(gemId) end)
                                addLog("info", "Collected Gem [" .. tostring(gemId) .. "] within reach")
                            elseif HubState.AutoFarmHay and dist <= 45 then
                                -- Quick hop to grab gem
                                local prev = hrp.CFrame
                                teleportTo(gemPos + Vector3.new(0, 1.5, 0))
                                task.wait(0.05)
                                pcall(function() Remotes.CollectGem:FireServer(gemId) end)
                                teleportTo(prev)
                            end
                        else
                            pcall(function() Remotes.CollectGem:FireServer(gemId) end)
                        end
                    end
                end
            end
        end
    end
end)
table.insert(HubThreads, gemThread)

if Remotes.GemSpawned then
    local conn = Remotes.GemSpawned.OnClientEvent:Connect(function(gemId)
        if HubState.AutoCollectGems and Remotes.CollectGem and gemId then
            pcall(function() Remotes.CollectGem:FireServer(gemId) end)
        end
    end)
    table.insert(HubConnections, conn)
end

-- 8.3 AUTO-WIN NEEDLE ENGINE
local needleThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(0.4)
        if HubState.AutoWinNeedle and IS_GAMEPLAY then
            local needleOwned = LocalPlayer:GetAttribute("NeedleOwned")

            if needleOwned then
                addLog("warn", "Needle is in your hands! Equipping Slot 6 and teleporting to Farmer NPC...")
                equipToolSlot(SLOT_NEEDLE)
                scanExactLandmarks()
                teleportTo(Landmarks.FarmerNPC)
                task.wait(0.2)

                -- Fire hand-in remote
                if Remotes.NeedleHandIn then
                    pcall(function() Remotes.NeedleHandIn:FireServer() end)
                end

                -- Trigger any proximity prompts on farmer
                local farmer = workspace:FindFirstChild("NPC") and workspace.NPC:FindFirstChild("Farmer_NPC")
                if farmer then
                    for _, prompt in ipairs(farmer:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") then
                            pcall(function() fireproximityprompt(prompt) end)
                        end
                    end
                end
                addLog("info", "Handed in needle to Farmer NPC! Match Won!")
                task.wait(2)
            else
                -- Scan for Needle Part in workspace or target HayId
                local needlePart = nil
                local targetHayId = Landmarks.TargetNeedleHayId

                if targetHayId then
                    local haystack = workspace:FindFirstChild("HaystackClient")
                    if haystack then
                        for _, p in ipairs(haystack:GetChildren()) do
                            if p:IsA("BasePart") and p:GetAttribute("HayId") == targetHayId then
                                needlePart = p
                                break
                            end
                        end
                    end
                end

                if not needlePart then
                    -- Scan for IsNeedleObjective attribute or name
                    for _, obj in ipairs(workspace:GetChildren()) do
                        if obj:GetAttribute("IsNeedleObjective") == true or string.find(string.lower(obj.Name), "needle") then
                            if obj:IsA("BasePart") then needlePart = obj
                            elseif obj:IsA("Model") then needlePart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart") end
                            break
                        end
                    end
                end

                if needlePart then
                    addLog("info", "Needle detected! Teleporting to pick it up...")
                    teleportTo(needlePart.Position + Vector3.new(0, 1.2, 0))
                    task.wait(0.08)

                    -- Game fires PickHay with "Objective" to grab the needle
                    if Remotes.PickHay then
                        pcall(function() Remotes.PickHay:FireServer("Objective") end)
                    end
                    if Remotes.PickHay and needlePart:GetAttribute("HayId") then
                        pcall(function() Remotes.PickHay:FireServer(needlePart:GetAttribute("HayId")) end)
                    end
                end
            end
        end
    end
end)
table.insert(HubThreads, needleThread)

-- 8.4 AUTO DEPLOY DRONE
local droneThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(2.5)
        if HubState.AutoDeployDrone and IS_GAMEPLAY and Remotes.DeployDrone then
            if isToolOwned("Drone") and LocalPlayer:GetAttribute("DroneDeployed") ~= true then
                pcall(function() Remotes.DeployDrone:FireServer() end)
                addLog("info", "Auto-deployed Hay Drone companion!")
            end
        end
    end
end)
table.insert(HubThreads, droneThread)

-- 8.5 AUTO-BUY TOOLS & UPGRADES
local barnToolNames = {"Pitchfork", "Tnt", "Drone", "Vacuum"}
local barnToolAttributes = {
    Pitchfork = "PitchforkOwned",
    Tnt = "TntOwned",
    Drone = "DroneOwned",
    Vacuum = "VacuumOwned"
}

local upgradeTracks = {
    "Capacity", "Grab", "Speed", "VacuumPower", "VacuumRuntime",
    "VacuumCooling", "PitchforkCooldown", "PitchforkHold", "DroneGrab",
    "DroneSpeed", "DroneCapacity", "TntLuck", "TntPower", "TntCooldown"
}

task.spawn(function()
    while IsHubLoaded do
        task.wait(2.0)
        if IS_GAMEPLAY then
            -- 1. Auto Buy Barn Tools if enabled (free in-game hay currency)
            if HubState.AutoBuyTools and Remotes.BuyShopItem then
                for _, toolName in ipairs(barnToolNames) do
                    local attr = barnToolAttributes[toolName]
                    if attr and LocalPlayer:GetAttribute(attr) ~= true then
                        pcall(function()
                            Remotes.BuyShopItem:FireServer(toolName)
                        end)
                        task.wait(0.12)
                    end
                end
            end
            -- 2. Auto Buy Match Upgrades if enabled (free in-game hay currency)
            if HubState.AutoBuyUpgrades and Remotes.BuyUpgrade then
                for _, track in ipairs(upgradeTracks) do
                    pcall(function()
                        Remotes.BuyUpgrade:FireServer(track)
                    end)
                    task.wait(0.08)
                end
            end
        end
    end
end)

-- 8.6 CAMERA 3RD PERSON & MOUSE FREEDOM CONTROLLER
local function applyCameraAndMouse()
    if HubState.UnlockCamera then
        if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
        end
        if LocalPlayer.CameraMaxZoomDistance < 100 then
            LocalPlayer.CameraMaxZoomDistance = 350
            LocalPlayer.CameraMinZoomDistance = 0.5
        end
    end

    if HubState.FreeMouse then
        -- If RMB is held down, lock mouse so user can rotate camera 360 degrees
        local isHoldingRMB = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if isHoldingRMB then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        UserInputService.MouseIconEnabled = true
    end
end

-- Hotkey: LeftAlt or Insert to toggle mouse freedom
local hotkeyConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and (input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.Insert) then
        HubState.FreeMouse = not HubState.FreeMouse
        addLog("info", "Mouse Mode: " .. (HubState.FreeMouse and "FREE (Click UI / Hold RMB to look)" or "LOCKED"))
    end
end)
table.insert(HubConnections, hotkeyConn)

-- 8.7 FLY SYSTEM
local flyBodyVelocity = nil
local flyBodyGyro = nil

local function toggleFly(enable)
    local hrp = getHRP()
    if not hrp then return end

    if enable then
        if not flyBodyVelocity then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = hrp
        end
        if not flyBodyGyro then
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            flyBodyGyro.CFrame = hrp.CFrame
            flyBodyGyro.Parent = hrp
        end
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    end
end

local renderConn = RunService.RenderStepped:Connect(function()
    if not IsHubLoaded then return end
    applyCameraAndMouse()

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    if hum and HubState.WalkSpeedEnabled then
        hum.WalkSpeed = HubState.WalkSpeed
    end

    if hum and HubState.JumpHeightEnabled then
        hum.JumpHeight = HubState.JumpHeight
    end

    if HubState.FlyEnabled and hrp and flyBodyVelocity and flyBodyGyro then
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.new(0, 0, 0)

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        if moveDir.Magnitude > 0 then
            flyBodyVelocity.Velocity = moveDir.Unit * HubState.FlySpeed
        else
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
        flyBodyGyro.CFrame = cam.CFrame
    end
end)
table.insert(HubConnections, renderConn)

-- Noclip loop
local noclipConn = RunService.Stepped:Connect(function()
    if not IsHubLoaded then return end
    if HubState.NoclipEnabled or HubState.FlyEnabled then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)
table.insert(HubConnections, noclipConn)

-- Infinite Jump
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if not IsHubLoaded then return end
    if HubState.InfiniteJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
table.insert(HubConnections, jumpConn)

-- 8.8 ESP SYSTEM
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "NeedleHub_ESP"
pcall(function() ESPFolder.Parent = CoreGui or workspace end)
if not ESPFolder.Parent then ESPFolder.Parent = workspace end

local activeBillboards = {}

local function updateBillboard(key, targetPart, text, color)
    if not targetPart or not targetPart:IsDescendantOf(workspace) then
        if activeBillboards[key] then
            activeBillboards[key]:Destroy()
            activeBillboards[key] = nil
        end
        return
    end

    local bb = activeBillboards[key]
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Name = "ESP_" .. key
        bb.Size = UDim2.new(0, 160, 0, 26)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = ESPFolder

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color
        lbl.TextStrokeTransparency = 0.2
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.Parent = bb

        activeBillboards[key] = bb
    end

    bb.Adornee = targetPart
    local lbl = bb:FindFirstChild("Label")
    if lbl then lbl.Text = text end
end

local function removeBillboard(key)
    if activeBillboards[key] then
        activeBillboards[key]:Destroy()
        activeBillboards[key] = nil
    end
end

local sellAnchorPart = Instance.new("Part")
sellAnchorPart.Name = "SellAnchorPart"
sellAnchorPart.Size = Vector3.new(2, 2, 2)
sellAnchorPart.Position = Landmarks.SellCow
sellAnchorPart.Transparency = 1
sellAnchorPart.Anchored = true
sellAnchorPart.CanCollide = false
sellAnchorPart.Parent = ESPFolder

local espThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(0.5)
        local myHRP = getHRP()
        local myPos = myHRP and myHRP.Position or Vector3.new(0, 0, 0)

        -- 1. Sell Zone ESP
        if HubState.SellESP and IS_GAMEPLAY then
            local dist = math.floor((myPos - Landmarks.SellCow).Magnitude)
            updateBillboard("SellZone", sellAnchorPart, "SELL COW [" .. dist .. "m]", Color3.fromRGB(50, 220, 255))
        else
            removeBillboard("SellZone")
        end

        -- 2. Needle ESP
        if HubState.NeedleESP and IS_GAMEPLAY then
            local needle = workspace:FindFirstChild("The Needle") or workspace:FindFirstChild("HiddenNeedleClient")
            local targetHayId = Landmarks.TargetNeedleHayId

            if needle then
                local p = needle:IsA("BasePart") and needle or (needle:IsA("Model") and (needle.PrimaryPart or needle:FindFirstChildWhichIsA("BasePart")))
                if p then
                    local dist = math.floor((myPos - p.Position).Magnitude)
                    updateBillboard("Needle", p, "THE NEEDLE [" .. dist .. "m]", Color3.fromRGB(255, 230, 0))
                end
            elseif targetHayId then
                local haystack = workspace:FindFirstChild("HaystackClient")
                if haystack then
                    for _, p in ipairs(haystack:GetChildren()) do
                        if p:IsA("BasePart") and p:GetAttribute("HayId") == targetHayId then
                            local dist = math.floor((myPos - p.Position).Magnitude)
                            updateBillboard("Needle", p, "THE NEEDLE [" .. dist .. "m]", Color3.fromRGB(255, 230, 0))
                            break
                        end
                    end
                end
            else
                removeBillboard("Needle")
            end
        else
            removeBillboard("Needle")
        end

        -- 3. Gem ESP
        if HubState.GemESP and IS_GAMEPLAY then
            local gemsFolder = workspace:FindFirstChild("GemsClient")
            if gemsFolder then
                for _, gem in ipairs(gemsFolder:GetChildren()) do
                    if gem:IsA("BasePart") then
                        local dist = math.floor((myPos - gem.Position).Magnitude)
                        updateBillboard("Gem_" .. gem.Name, gem, "GEM [" .. dist .. "m]", Color3.fromRGB(120, 255, 120))
                    elseif gem:IsA("Model") then
                        local p = gem.PrimaryPart or gem:FindFirstChildWhichIsA("BasePart")
                        if p then
                            local dist = math.floor((myPos - p.Position).Magnitude)
                            updateBillboard("Gem_" .. gem.Name, p, "GEM [" .. dist .. "m]", Color3.fromRGB(120, 255, 120))
                        end
                    end
                end
            end
        end

        -- 4. RGB Straw ESP
        if HubState.RgbESP and IS_GAMEPLAY then
            local haystack = workspace:FindFirstChild("HaystackClient")
            if haystack then
                local count = 0
                for _, p in ipairs(haystack:GetChildren()) do
                    if p:IsA("BasePart") and isRainbowStrand(p) then
                        count = count + 1
                        if count <= 25 then
                            local dist = math.floor((myPos - p.Position).Magnitude)
                            updateBillboard("RGB_" .. tostring(p:GetAttribute("HayId") or count), p, "RGB STRAW [" .. dist .. "m]", Color3.fromRGB(255, 100, 255))
                        end
                    end
                end
            end
        end

        -- 5. Player ESP
        if HubState.PlayerESP then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local pRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                    if pRoot then
                        local dist = math.floor((myPos - pRoot.Position).Magnitude)
                        updateBillboard("Player_" .. plr.Name, pRoot, plr.DisplayName .. " [" .. dist .. "m]", Color3.fromRGB(255, 255, 255))
                    end
                end
            end
        end
    end
end)
table.insert(HubThreads, espThread)

-- 8.9 LOBBY AUTOMATION & CODE REDEMPTION INVESTIGATION
local KNOWN_CODES = {
    "RELEASE", "Release", "UPDATE", "Update", "NEEDLE", "Needle",
    "HAYSTACK", "Haystack", "LUCKY", "Lucky", "WIN", "Win",
    "FARM", "Farm", "10KLIKES", "10KLikes", "50KLIKES", "50KLikes",
    "100KVISITS", "100KVisits", "GARAGE", "COW"
}

local LastCodeStatusMessage = "Nenhum codigo resgatado ainda"

local function redeemSingleCode(code)
    if not code or type(code) ~= "string" or code:match("^%s*$") then
        LastCodeStatusMessage = "Codigo invalido ou vazio"
        return false, "Vazio"
    end
    code = code:gsub("%s+", "")
    if not IS_LOBBY or not Remotes.RedeemCode then
        local msg = "Codigos so funcionam no LOBBY! No mapa de jogo nao ha sistema de codigos."
        addLog("warn", msg)
        LastCodeStatusMessage = msg
        return false, msg
    end
    
    addLog("info", "Testando codigo no servidor: [" .. code .. "]...")
    local ok, res, extra = pcall(function()
        return Remotes.RedeemCode:InvokeServer(code)
    end)
    
    local respStr = tostring(res)
    if extra ~= nil then
        respStr = respStr .. " (" .. tostring(extra) .. ")"
    end
    
    if ok then
        addLog("info", "Codigo [" .. code .. "] -> Resposta do Servidor: " .. respStr)
        LastCodeStatusMessage = "[" .. code .. "]: " .. respStr
        
        -- Check PlayerGui notification
        pcall(function()
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            if pGui then
                local codeUi = pGui:FindFirstChild("CodeUi")
                if codeUi then
                    local notif = codeUi:FindFirstChild("Notification")
                    if notif and notif:IsA("TextLabel") and notif.Text ~= "" then
                        addLog("info", "Notificacao do Jogo: " .. notif.Text)
                        LastCodeStatusMessage = "[" .. code .. "]: " .. notif.Text
                    end
                end
            end
        end)
        return true, respStr
    else
        addLog("error", "Codigo [" .. code .. "] -> Erro RPC: " .. respStr)
        LastCodeStatusMessage = "Erro ao enviar: " .. respStr
        return false, respStr
    end
end

local function redeemAllCodes(userCode)
    if not IS_LOBBY or not Remotes.RedeemCode then
        local msg = "Codigos funcionam APENAS no LOBBY! Teleporte para o Lobby antes de resgatar."
        addLog("warn", msg)
        LastCodeStatusMessage = msg
        return
    end
    
    task.spawn(function()
        addLog("info", "Iniciando lote de teste de codigos no Lobby...")
        local count = 0
        for _, code in ipairs(KNOWN_CODES) do
            count = count + 1
            redeemSingleCode(code)
            task.wait(0.3)
        end
        if userCode and userCode ~= "" then
            redeemSingleCode(userCode)
        end
        addLog("info", string.format("Lote de codigos finalizado! Testados: %d codigos.", count))
    end)
end

-- Robux Marketplace Prompt Helper (Explicitly tagged)
local function promptRobuxPurchase(kind, id, itemName)
    local numId = tonumber(id)
    if not numId or numId <= 0 then
        -- If no direct ID, try finding and clicking in-game GUI button
        addLog("warn", "[ROBUX] Tentando abrir compra de " .. tostring(itemName) .. " via interface...")
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui then
            local gpUi = pGui:FindFirstChild("GamepassUI")
            if gpUi then
                local btn = gpUi:FindFirstChild("DoubleGemsButton", true)
                if btn and firesignal then
                    firesignal(btn.Activated)
                    return
                end
            end
        end
        addLog("warn", "[ROBUX] ID numerico nao configurado para: " .. tostring(itemName))
        return
    end
    addLog("warn", "[ROBUX] Solicitando confirmacao oficial da Roblox para: " .. tostring(itemName) .. " (ID " .. tostring(numId) .. ")")
    pcall(function()
        local MarketplaceService = safeService("MarketplaceService")
        if kind == "GamePass" then
            MarketplaceService:PromptGamePassPurchase(LocalPlayer, numId)
        else
            MarketplaceService:PromptProductPurchase(LocalPlayer, numId)
        end
    end)
end

-- 8.10 UNLOAD / DESTROY HUB
local function unloadHub()
    addLog("warn", "Unloading Needle Hub completely...")
    IsHubLoaded = false

    for _, thread in ipairs(HubThreads) do
        pcall(function() task.cancel(thread) end)
    end
    for _, conn in ipairs(HubConnections) do
        pcall(function()
            if typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            elseif type(conn) == "table" and conn.Disconnect then
                conn:Disconnect()
            end
        end)
    end

    toggleFly(false)

    pcall(function() if ESPFolder then ESPFolder:Destroy() end end)
    pcall(function() if GlobalScreenGui then GlobalScreenGui:Destroy() end end)
    pcall(function() if FloatingButtonGui then FloatingButtonGui:Destroy() end end)

    -- Reset camera & mouse
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = 350
        LocalPlayer.CameraMinZoomDistance = 0.5
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)

    addLog("info", "Needle Hub unloaded cleanly.")
end

---- SECTION 9: USER INTERFACE (CYBER GLASS ADAPTIVE HUD v5.5 PRO)

-- Helper: Smooth Tweening
local function tweenGui(obj, props, duration, style, direction)
    local info = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

-- Floating Toggle Pill on Screen
local function createFloatingToggleButton(toggleCallback)
    if FloatingButtonGui then FloatingButtonGui:Destroy() end

    local floatGui = Instance.new("ScreenGui")
    floatGui.Name = "NeedleHubFloatingBtn"
    floatGui.ResetOnSpawn = false
    floatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() floatGui.Parent = CoreGui end)
    if not floatGui.Parent then floatGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    FloatingButtonGui = floatGui

    local floatBtn = Instance.new("TextButton")
    floatBtn.Name = "MenuToggle"
    floatBtn.Size = UDim2.fromOffset(130, 36)
    floatBtn.Position = UDim2.new(0, 16, 0.45, 0)
    floatBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
    floatBtn.Text = ""
    floatBtn.AutoButtonColor = false
    floatBtn.Parent = floatGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent = floatBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(99, 102, 241)
    stroke.Thickness = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = floatBtn

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 29, 44)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 18, 26))
    })
    grad.Parent = floatBtn

    -- Glowing Dot Indicator
    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(8, 8)
    dot.Position = UDim2.new(0, 12, 0.5, -4)
    dot.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
    dot.BorderSizePixel = 0
    dot.Parent = floatBtn
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    -- Text Label
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -28, 1, 0)
    lbl.Position = UDim2.fromOffset(26, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "NEEDLE HUB"
    lbl.TextColor3 = Color3.fromRGB(240, 245, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = floatBtn

    -- Hover effect
    floatBtn.MouseEnter:Connect(function()
        tweenGui(floatBtn, {BackgroundColor3 = Color3.fromRGB(28, 32, 50)}, 0.18)
        tweenGui(stroke, {Color = Color3.fromRGB(129, 140, 248), Thickness = 2.0}, 0.18)
    end)
    floatBtn.MouseLeave:Connect(function()
        tweenGui(floatBtn, {BackgroundColor3 = Color3.fromRGB(18, 20, 30)}, 0.18)
        tweenGui(stroke, {Color = Color3.fromRGB(99, 102, 241), Thickness = 1.5}, 0.18)
    end)

    -- Draggable Floating Pill
    local dragging = false
    local dragStart, startPos

    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = floatBtn.Position
        end
    end)

    local dragEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    table.insert(HubConnections, dragEndConn)

    local dragMoveConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            floatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    table.insert(HubConnections, dragMoveConn)

    floatBtn.MouseButton1Click:Connect(toggleCallback)
end

-- Version & GitHub Update Status Store
local RemoteScriptVersion = SCRIPT_VERSION
local ScriptUpdateAvailable = false
local ScriptUpdateNotice = "Verificando versao no GitHub..."

local function checkForScriptUpdates(onFinished)
    task.spawn(function()
        local success, res = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/victorcxzk/search-for-the-needle-script/master/version.json")
        end)
        if success and res and #res > 0 then
            local HttpService = safeService("HttpService")
            local parsed = nil
            pcall(function()
                if HttpService then parsed = HttpService:JSONDecode(res) end
            end)
            if parsed and parsed.version then
                RemoteScriptVersion = tostring(parsed.version)
                if RemoteScriptVersion ~= SCRIPT_VERSION then
                    ScriptUpdateAvailable = true
                    ScriptUpdateNotice = "Nova versao disponivel! (v" .. RemoteScriptVersion .. ")"
                    addLog("warn", "ATUALIZACAO DISPONIVEL: v" .. RemoteScriptVersion .. " no GitHub! (Versao atual: v" .. SCRIPT_VERSION .. ")")
                else
                    ScriptUpdateAvailable = false
                    ScriptUpdateNotice = "Script 100% Atualizado (v" .. SCRIPT_VERSION .. " PRO)"
                    addLog("info", "Script esta na versao mais recente (v" .. SCRIPT_VERSION .. ")")
                end
            end
        else
            ScriptUpdateNotice = "v" .. SCRIPT_VERSION .. " (Nao foi possivel conectar ao GitHub)"
        end
        if onFinished then pcall(onFinished, ScriptUpdateNotice, ScriptUpdateAvailable) end
    end)
end

-- Primary Modern Native UI Builder (Context-Aware: Lobby vs Match)
local function buildNativeUI()
    local isLobbyMode = (CurrentContextMode == "Lobby")
    addLog("info", "Construindo UI Cyber Glass (" .. (isLobbyMode and "MODO LOBBY" or "MODO JOGO") .. ")...")

    if GlobalScreenGui then GlobalScreenGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NeedleHubNative"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    GlobalScreenGui = screenGui

    -- Window Geometry (Compact & Adaptive for all resolutions)
    local WIN_WIDTH = 550
    local WIN_HEIGHT = 370
    local TITLE_HEIGHT = 38
    local SIDEBAR_WIDTH = 140

    -- Main Window Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.fromOffset(WIN_WIDTH, WIN_HEIGHT)
    mainFrame.Position = UDim2.fromScale(0.5, 0.5)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(13, 14, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(48, 52, 74)
    mainStroke.Thickness = 1.5
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mainStroke.Parent = mainFrame

    local mainGrad = Instance.new("UIGradient")
    mainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 18, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 12, 17))
    })
    mainGrad.Rotation = 45
    mainGrad.Parent = mainFrame

    -- Title Bar (Header)
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
    titleBar.BackgroundColor3 = Color3.fromRGB(19, 21, 31)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar

    -- Bottom border line on Title Bar with accent gradient
    local headerLine = Instance.new("Frame")
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.Position = UDim2.new(0, 0, 1, -1)
    headerLine.BorderSizePixel = 0
    headerLine.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    headerLine.Parent = titleBar

    local headerLineGrad = Instance.new("UIGradient")
    headerLineGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(99, 102, 241)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(168, 85, 247)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(56, 189, 248))
    })
    headerLineGrad.Parent = headerLine

    -- Logo Badge Icon
    local logoIcon = Instance.new("Frame")
    logoIcon.Size = UDim2.fromOffset(24, 24)
    logoIcon.Position = UDim2.new(0, 10, 0.5, -12)
    logoIcon.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    logoIcon.BorderSizePixel = 0
    logoIcon.Parent = titleBar
    local logoCorner = Instance.new("UICorner") logoCorner.CornerRadius = UDim.new(0, 6) logoCorner.Parent = logoIcon
    local logoGrad = Instance.new("UIGradient")
    logoGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(99, 102, 241)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 85, 247))
    })
    logoGrad.Parent = logoIcon
    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.fromScale(1, 1)
    logoText.BackgroundTransparency = 1
    logoText.Text = "N"
    logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoText.Font = Enum.Font.GothamBold
    logoText.TextSize = 13
    logoText.Parent = logoIcon

    -- Title Text
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.fromOffset(95, 24)
    titleLabel.Position = UDim2.new(0, 40, 0.5, -12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "NEEDLE HUB"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    -- Version Tag Pill
    local verPill = Instance.new("Frame")
    verPill.Size = UDim2.fromOffset(60, 18)
    verPill.Position = UDim2.new(0, 140, 0.5, -9)
    verPill.BackgroundColor3 = Color3.fromRGB(30, 34, 52)
    verPill.BorderSizePixel = 0
    verPill.Parent = titleBar
    local verCorner = Instance.new("UICorner") verCorner.CornerRadius = UDim.new(0, 9) verCorner.Parent = verPill
    local verStroke = Instance.new("UIStroke") verStroke.Color = Color3.fromRGB(80, 85, 125) verStroke.Thickness = 1 verStroke.Parent = verPill
    local verLbl = Instance.new("TextLabel")
    verLbl.Size = UDim2.fromScale(1, 1)
    verLbl.BackgroundTransparency = 1
    verLbl.Text = "v" .. tostring(SCRIPT_VERSION) .. " PRO"
    verLbl.TextColor3 = Color3.fromRGB(165, 180, 252)
    verLbl.Font = Enum.Font.GothamBold
    verLbl.TextSize = 9
    verLbl.Parent = verPill

    -- Status Pill (Match vs Lobby Context)
    local statusPill = Instance.new("Frame")
    statusPill.Size = UDim2.fromOffset(105, 18)
    statusPill.Position = UDim2.new(0, 206, 0.5, -9)
    statusPill.BackgroundColor3 = Color3.fromRGB(20, 26, 36)
    statusPill.BorderSizePixel = 0
    statusPill.Parent = titleBar
    local statusCorner = Instance.new("UICorner") statusCorner.CornerRadius = UDim.new(0, 9) statusCorner.Parent = statusPill
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.fromOffset(6, 6)
    statusDot.Position = UDim2.new(0, 7, 0.5, -3)
    statusDot.BackgroundColor3 = (CurrentContextMode == "Match") and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(56, 189, 248)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = statusPill
    local sdc = Instance.new("UICorner") sdc.CornerRadius = UDim.new(1, 0) sdc.Parent = statusDot
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -16, 1, 0)
    statusLbl.Position = UDim2.fromOffset(16, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = (CurrentContextMode == "Match") and "MATCH MODE" or "LOBBY MODE"
    statusLbl.TextColor3 = Color3.fromRGB(200, 210, 230)
    statusLbl.Font = Enum.Font.GothamMedium
    statusLbl.TextSize = 9
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = statusPill

    -- Re-center / Reset Position Button
    local centerBtn = Instance.new("TextButton")
    centerBtn.Size = UDim2.fromOffset(24, 24)
    centerBtn.Position = UDim2.new(1, -86, 0.5, -12)
    centerBtn.BackgroundColor3 = Color3.fromRGB(28, 31, 46)
    centerBtn.Text = "O"
    centerBtn.TextColor3 = Color3.fromRGB(165, 180, 252)
    centerBtn.Font = Enum.Font.GothamBold
    centerBtn.TextSize = 11
    centerBtn.AutoButtonColor = false
    centerBtn.Parent = titleBar
    local ccCorner = Instance.new("UICorner") ccCorner.CornerRadius = UDim.new(0, 6) ccCorner.Parent = centerBtn
    centerBtn.MouseButton1Click:Connect(function()
        mainFrame.Position = UDim2.fromScale(0.5, 0.5)
        addLog("info", "Janela recentralizada na tela.")
    end)

    -- Minimize Button
    local isMinimized = false
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.fromOffset(24, 24)
    minBtn.Position = UDim2.new(1, -58, 0.5, -12)
    minBtn.BackgroundColor3 = Color3.fromRGB(28, 31, 46)
    minBtn.Text = "-"
    minBtn.TextColor3 = Color3.fromRGB(220, 225, 240)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 13
    minBtn.AutoButtonColor = false
    minBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner") minCorner.CornerRadius = UDim.new(0, 6) minCorner.Parent = minBtn

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(24, 24)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -12)
    closeBtn.BackgroundColor3 = Color3.fromRGB(38, 22, 28)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 120, 130)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 11
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner") closeCorner.CornerRadius = UDim.new(0, 6) closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        unloadHub()
    end)

    -- Container for Tabs & Content
    local bodyContainer = Instance.new("Frame")
    bodyContainer.Name = "BodyContainer"
    bodyContainer.Size = UDim2.new(1, 0, 1, -TITLE_HEIGHT)
    bodyContainer.Position = UDim2.fromOffset(0, TITLE_HEIGHT)
    bodyContainer.BackgroundTransparency = 1
    bodyContainer.Parent = mainFrame

    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        minBtn.Text = isMinimized and "+" or "-"
        if isMinimized then
            tweenGui(mainFrame, {Size = UDim2.fromOffset(WIN_WIDTH, TITLE_HEIGHT)}, 0.2, Enum.EasingStyle.Quart)
            bodyContainer.Visible = false
        else
            bodyContainer.Visible = true
            tweenGui(mainFrame, {Size = UDim2.fromOffset(WIN_WIDTH, WIN_HEIGHT)}, 0.2, Enum.EasingStyle.Quart)
        end
    end)

    -- Viewport Clamped Window Dragging
    local isDraggingMain = false
    local dragStartPos, frameStartPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingMain = true
            dragStartPos = input.Position
            frameStartPos = mainFrame.Position
        end
    end)

    local dragTitleEnd = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingMain = false
        end
    end)
    table.insert(HubConnections, dragTitleEnd)

    local dragTitleMove = UserInputService.InputChanged:Connect(function(input)
        if isDraggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartPos
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1024, 600)
            local halfW = WIN_WIDTH / 2
            local halfH = WIN_HEIGHT / 2
            
            local rawCenterX = (vp.X * frameStartPos.X.Scale) + frameStartPos.X.Offset + delta.X
            local rawCenterY = (vp.Y * frameStartPos.Y.Scale) + frameStartPos.Y.Offset + delta.Y
            
            -- Clamp strictly within visible screen margins
            local clampedCenterX = math.clamp(rawCenterX, halfW + 8, vp.X - halfW - 8)
            local clampedCenterY = math.clamp(rawCenterY, halfH + 8, vp.Y - halfH - 8)
            
            local finalOffsetX = clampedCenterX - (vp.X * 0.5)
            local finalOffsetY = clampedCenterY - (vp.Y * 0.5)
            
            mainFrame.Position = UDim2.new(0.5, finalOffsetX, 0.5, finalOffsetY)
        end
    end)
    table.insert(HubConnections, dragTitleMove)

    -- Sidebar for Tabs
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(15, 16, 24)
    sidebar.BorderSizePixel = 0
    sidebar.ClipsDescendants = false
    sidebar.Parent = bodyContainer

    -- Separator line between sidebar and content area
    local sidebarSep = Instance.new("Frame")
    sidebarSep.Name = "SidebarDivider"
    sidebarSep.Size = UDim2.new(0, 1, 1, 0)
    sidebarSep.Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0)
    sidebarSep.BackgroundColor3 = Color3.fromRGB(32, 35, 48)
    sidebarSep.BorderSizePixel = 0
    sidebarSep.Parent = bodyContainer

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Parent = sidebar

    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingTop = UDim.new(0, 8)
    sidebarPadding.Parent = sidebar

    -- Content Area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -SIDEBAR_WIDTH - 1, 1, 0)
    contentArea.Position = UDim2.fromOffset(SIDEBAR_WIDTH + 1, 0)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = bodyContainer

    local tabFrames = {}
    local tabButtons = {}
    local tabIndicators = {}
    local tabOrderCounter = 0

    local function selectTab(tabName)
        for name, frame in pairs(tabFrames) do
            local isTarget = (name == tabName)
            frame.Visible = isTarget
            if isTarget and frame:IsA("ScrollingFrame") then
                pcall(function() frame.CanvasPosition = Vector2.new(0, 0) end)
            end
        end
        for name, btn in pairs(tabButtons) do
            local ind = tabIndicators[name]
            if name == tabName then
                tweenGui(btn, {BackgroundColor3 = Color3.fromRGB(79, 70, 229), TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.16)
                if ind then ind.Visible = true end
            else
                tweenGui(btn, {BackgroundColor3 = Color3.fromRGB(20, 22, 32), TextColor3 = Color3.fromRGB(155, 160, 180)}, 0.16)
                if ind then ind.Visible = false end
            end
        end
    end

    local function createTab(tabName, badgeTag)
        tabOrderCounter = tabOrderCounter + 1
        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. tabName
        btn.Size = UDim2.new(0.92, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
        btn.Text = "  " .. tabName
        btn.TextColor3 = Color3.fromRGB(155, 160, 180)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.LayoutOrder = tabOrderCounter
        btn.Parent = sidebar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        -- Left Active Indicator Pill
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 3, 0.6, 0)
        indicator.Position = UDim2.new(0, 2, 0.2, 0)
        indicator.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
        indicator.BorderSizePixel = 0
        indicator.Visible = false
        indicator.Parent = btn
        local ic = Instance.new("UICorner") ic.CornerRadius = UDim.new(1, 0) ic.Parent = indicator

        -- Optional small badge on right
        if badgeTag then
            local b = Instance.new("TextLabel")
            b.Size = UDim2.fromOffset(40, 16)
            b.Position = UDim2.new(1, -44, 0.5, -8)
            b.BackgroundTransparency = 1
            b.Text = badgeTag
            b.TextColor3 = Color3.fromRGB(130, 140, 175)
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 9
            b.TextXAlignment = Enum.TextXAlignment.Right
            b.Parent = btn
        end

        btn.MouseEnter:Connect(function()
            if tabFrames[tabName] and not tabFrames[tabName].Visible then
                tweenGui(btn, {BackgroundColor3 = Color3.fromRGB(28, 30, 44), TextColor3 = Color3.fromRGB(220, 225, 245)}, 0.15)
            end
        end)
        btn.MouseLeave:Connect(function()
            if tabFrames[tabName] and not tabFrames[tabName].Visible then
                tweenGui(btn, {BackgroundColor3 = Color3.fromRGB(20, 22, 32), TextColor3 = Color3.fromRGB(155, 160, 180)}, 0.15)
            end
        end)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "TabContent_" .. tabName
        scroll.Size = UDim2.new(1, -16, 1, -12)
        scroll.Position = UDim2.fromOffset(8, 6)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 85, 120)
        scroll.CanvasPosition = Vector2.new(0, 0)
        scroll.Visible = false
        scroll.Parent = contentArea

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 6)
        list.HorizontalAlignment = Enum.HorizontalAlignment.Center
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = scroll

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingBottom = UDim.new(0, 12)
        pad.Parent = scroll

        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 24)
        end)

        tabFrames[tabName] = scroll
        tabButtons[tabName] = btn
        tabIndicators[tabName] = indicator

        btn.MouseButton1Click:Connect(function()
            selectTab(tabName)
        end)

        return scroll
    end

    -- UI Component: Section Header (Context-Colored)
    local function addNativeSection(parent, title, customAccentColor)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.96, 0, 0, 22)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local accent = customAccentColor or Color3.fromRGB(99, 102, 241)

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 0.7, 0)
        bar.Position = UDim2.new(0, 2, 0.15, 0)
        bar.BackgroundColor3 = accent
        bar.BorderSizePixel = 0
        bar.Parent = frame
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = bar

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 1, 0)
        lbl.Position = UDim2.fromOffset(12, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.upper(title)
        lbl.TextColor3 = accent
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, -130, 0, 1)
        line.Position = UDim2.new(0, 120, 0.5, 0)
        line.BackgroundColor3 = Color3.fromRGB(38, 41, 58)
        line.BorderSizePixel = 0
        line.Parent = frame
    end

    -- UI Component: Animated Switch Toggle
    local function addNativeToggle(parent, title, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.96, 0, 0, 34)
        frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = frame
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(36, 40, 58)
        s.Thickness = 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = frame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 1, 0)
        lbl.Position = UDim2.fromOffset(12, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = title
        lbl.TextColor3 = Color3.fromRGB(230, 235, 245)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        -- Switch Pill Track
        local track = Instance.new("TextButton")
        track.Size = UDim2.fromOffset(40, 20)
        track.Position = UDim2.new(1, -48, 0.5, -10)
        track.BackgroundColor3 = default and Color3.fromRGB(79, 70, 229) or Color3.fromRGB(34, 37, 52)
        track.Text = ""
        track.AutoButtonColor = false
        track.Parent = frame

        local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(1, 0) tc.Parent = track
        local ts = Instance.new("UIStroke") ts.Color = Color3.fromRGB(60, 65, 90) ts.Thickness = 1 ts.Parent = track

        -- Thumb knob
        local thumb = Instance.new("Frame")
        thumb.Size = UDim2.fromOffset(14, 14)
        thumb.Position = default and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
        thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        thumb.BorderSizePixel = 0
        thumb.Parent = track
        local thumbC = Instance.new("UICorner") thumbC.CornerRadius = UDim.new(1, 0) thumbC.Parent = thumb

        local state = default
        local function toggleState()
            state = not state
            if state then
                tweenGui(track, {BackgroundColor3 = Color3.fromRGB(79, 70, 229)}, 0.18)
                tweenGui(thumb, {Position = UDim2.new(1, -17, 0.5, -7)}, 0.18)
            else
                tweenGui(track, {BackgroundColor3 = Color3.fromRGB(34, 37, 52)}, 0.18)
                tweenGui(thumb, {Position = UDim2.new(0, 3, 0.5, -7)}, 0.18)
            end
            callback(state)
        end

        track.MouseButton1Click:Connect(toggleState)
        return frame
    end

    -- UI Component: Button (Supports Robux Gold, Gem Green, Primary Indigo)
    local function addNativeButton(parent, title, callback, isPrimary, buttonStyle)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.96, 0, 0, 30)
        btn.Text = title
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.AutoButtonColor = false
        btn.Parent = parent

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
        local s = Instance.new("UIStroke")
        s.Thickness = 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = btn

        local bgCol = Color3.fromRGB(24, 26, 38)
        local textCol = Color3.fromRGB(225, 230, 245)
        local strokeCol = Color3.fromRGB(44, 48, 70)
        local hoverCol = Color3.fromRGB(34, 37, 54)

        if buttonStyle == "robux" then
            bgCol = Color3.fromRGB(44, 32, 14)
            textCol = Color3.fromRGB(251, 191, 36)
            strokeCol = Color3.fromRGB(217, 119, 6)
            hoverCol = Color3.fromRGB(60, 44, 18)
        elseif buttonStyle == "gem" then
            bgCol = Color3.fromRGB(14, 38, 26)
            textCol = Color3.fromRGB(52, 211, 153)
            strokeCol = Color3.fromRGB(16, 185, 129)
            hoverCol = Color3.fromRGB(20, 54, 36)
        elseif isPrimary then
            bgCol = Color3.fromRGB(79, 70, 229)
            textCol = Color3.fromRGB(255, 255, 255)
            strokeCol = Color3.fromRGB(129, 140, 248)
            hoverCol = Color3.fromRGB(99, 102, 241)
        end

        btn.BackgroundColor3 = bgCol
        btn.TextColor3 = textCol
        s.Color = strokeCol

        btn.MouseEnter:Connect(function()
            tweenGui(btn, {BackgroundColor3 = hoverCol}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            tweenGui(btn, {BackgroundColor3 = bgCol}, 0.15)
        end)
        btn.MouseButton1Click:Connect(function()
            tweenGui(btn, {Size = UDim2.new(0.94, 0, 0, 28)}, 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
            task.wait(0.08)
            tweenGui(btn, {Size = UDim2.new(0.96, 0, 0, 30)}, 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
            callback()
        end)
        return btn
    end

    -- UI Component: Interactive Slider
    local function addNativeSlider(parent, title, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.96, 0, 0, 42)
        frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = frame
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(36, 40, 58)
        s.Thickness = 1
        s.Parent = frame

        local tLbl = Instance.new("TextLabel")
        tLbl.Size = UDim2.new(1, -60, 0, 18)
        tLbl.Position = UDim2.fromOffset(12, 4)
        tLbl.BackgroundTransparency = 1
        tLbl.Text = title
        tLbl.TextColor3 = Color3.fromRGB(220, 225, 240)
        tLbl.Font = Enum.Font.GothamMedium
        tLbl.TextSize = 10
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.Parent = frame

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.fromOffset(45, 18)
        valLbl.Position = UDim2.new(1, -55, 0, 4)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(default)
        valLbl.TextColor3 = Color3.fromRGB(129, 140, 248)
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 10
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = frame

        local barBg = Instance.new("TextButton")
        barBg.Size = UDim2.new(1, -24, 0, 8)
        barBg.Position = UDim2.fromOffset(12, 26)
        barBg.BackgroundColor3 = Color3.fromRGB(32, 35, 50)
        barBg.Text = ""
        barBg.AutoButtonColor = false
        barBg.Parent = frame
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = barBg

        local fill = Instance.new("Frame")
        local startFrac = math.clamp((default - min) / (max - min), 0, 1)
        fill.Size = UDim2.fromScale(startFrac, 1)
        fill.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
        fill.BorderSizePixel = 0
        fill.Parent = barBg
        local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = fill

        local isDraggingSlider = false
        local function updateVal(input)
            local frac = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
            local result = math.floor(min + (max - min) * frac)
            fill.Size = UDim2.fromScale(frac, 1)
            valLbl.Text = tostring(result)
            callback(result)
        end

        barBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDraggingSlider = true
                updateVal(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDraggingSlider = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateVal(input)
            end
        end)
    end

    -- UI Component: Modern Info / Status Card (Context-Colored)
    local function addNativeParagraph(parent, title, content, customAccentColor)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.96, 0, 0, 52)
        frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local accentCol = customAccentColor or Color3.fromRGB(99, 102, 241)

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = frame
        local s = Instance.new("UIStroke")
        s.Color = customAccentColor and Color3.fromRGB(math.floor(accentCol.R * 120), math.floor(accentCol.G * 120), math.floor(accentCol.B * 120)) or Color3.fromRGB(36, 40, 58)
        s.Thickness = 1
        s.Parent = frame

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(0, 3, 0.7, 0)
        accent.Position = UDim2.new(0, 4, 0.15, 0)
        accent.BackgroundColor3 = accentCol
        accent.BorderSizePixel = 0
        accent.Parent = frame
        local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(1, 0) ac.Parent = accent

        local tLbl = Instance.new("TextLabel")
        tLbl.Size = UDim2.new(1, -24, 0, 18)
        tLbl.Position = UDim2.fromOffset(12, 4)
        tLbl.BackgroundTransparency = 1
        tLbl.Text = title
        tLbl.TextColor3 = accentCol
        tLbl.Font = Enum.Font.GothamBold
        tLbl.TextSize = 10
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.Parent = frame

        local cLbl = Instance.new("TextLabel")
        cLbl.Size = UDim2.new(1, -24, 0, 26)
        cLbl.Position = UDim2.fromOffset(12, 22)
        cLbl.BackgroundTransparency = 1
        cLbl.Text = content
        cLbl.TextColor3 = Color3.fromRGB(205, 210, 225)
        cLbl.Font = Enum.Font.Gotham
        cLbl.TextSize = 10
        cLbl.TextWrapped = true
        cLbl.TextXAlignment = Enum.TextXAlignment.Left
        cLbl.TextYAlignment = Enum.TextYAlignment.Top
        cLbl.Parent = frame

        return cLbl
    end

    -- UI Component: Modern Text Input Box with Action Button
    local function addNativeInput(parent, placeholder, btnText, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.96, 0, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = frame
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(36, 40, 58)
        s.Thickness = 1
        s.Parent = frame

        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(1, -80, 1, -8)
        textBox.Position = UDim2.fromOffset(8, 4)
        textBox.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
        textBox.Text = ""
        textBox.PlaceholderText = placeholder
        textBox.TextColor3 = Color3.fromRGB(240, 245, 255)
        textBox.PlaceholderColor3 = Color3.fromRGB(120, 125, 145)
        textBox.Font = Enum.Font.GothamMedium
        textBox.TextSize = 10
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.ClearTextOnFocus = false
        textBox.Active = false
        textBox.Parent = frame
        local tbc = Instance.new("UICorner") tbc.CornerRadius = UDim.new(0, 4) tbc.Parent = textBox

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(60, 26)
        btn.Position = UDim2.new(1, -66, 0.5, -13)
        btn.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
        btn.Text = btnText or "Submit"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.AutoButtonColor = false
        btn.Parent = frame
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = btn

        btn.MouseButton1Click:Connect(function()
            callback(textBox.Text)
        end)
    end

    ----------------------------------------------------------------------
    -- ADAPTIVE CONTEXT TABS CONSTRUCTION
    ----------------------------------------------------------------------

    if isLobbyMode then
        -- ==================================================================
        -- LOBBY MODE (ONLY LOBBY FEATURES SHOWN)
        -- ==================================================================
        local lobbyTab = createTab("Lobby Hub", "HUB")
        local lobbyShopTab = createTab("Lobby Shop", "SHOP")
        local codesTab = createTab("Codigos", "CODE")
        local playerTab = createTab("Player", "HERO")
        local warpTab = createTab("Match Warp", "WARP")
        local consoleTab = createTab("Console", "LOGS")
        local setTab = createTab("Settings", "CFG")

        -- 1. Lobby Hub Tab
        addNativeSection(lobbyTab, "Class System & Spins", Color3.fromRGB(99, 102, 241))
        local classStatusCard = addNativeParagraph(lobbyTab, "Active Class & Gems",
            string.format("Class: [%s] | Gems: %s | Target: [%s]",
                tostring(LocalPlayer:GetAttribute("ActiveClass") or "Starter"),
                tostring(LocalPlayer:GetAttribute("Gems") or 0),
                HubState.TargetClass), Color3.fromRGB(99, 102, 241))

        task.spawn(function()
            while IsHubLoaded do
                task.wait(1.5)
                pcall(function()
                    if classStatusCard and classStatusCard.Parent then
                        classStatusCard.Text = string.format("Class: [%s] | Gems: %s | Target: [%s]",
                            tostring(LocalPlayer:GetAttribute("ActiveClass") or "Starter"),
                            tostring(LocalPlayer:GetAttribute("Gems") or 0),
                            HubState.TargetClass)
                    end
                end)
            end
        end)

        addNativeToggle(lobbyTab, "Auto-Roll Class (Stops on Target)", HubState.AutoRollClass, function(val)
            HubState.AutoRollClass = val
            addLog("info", "Auto-Roll Class: " .. tostring(val))
            if val then
                task.spawn(function()
                    while IsHubLoaded and HubState.AutoRollClass do
                        task.wait(0.6)
                        if Remotes.RollClass and IS_LOBBY then
                            local gems = LocalPlayer:GetAttribute("Gems") or 0
                            if gems < 40 then
                                HubState.AutoRollClass = false
                                addLog("warn", "Gemas insuficientes para rolar classe (Gemas: " .. gems .. " / 40). Auto-Roll pausado.")
                                break
                            end
                            local ok, res = pcall(function() return Remotes.RollClass:InvokeServer() end)
                            local curClass = tostring(LocalPlayer:GetAttribute("ActiveClass") or res or "")
                            addLog("info", "Rerolled Class: " .. curClass)
                            if curClass:lower():find(HubState.TargetClass:lower()) then
                                addLog("info", "CLASSE ALVO OBTIDA: " .. curClass .. "! Auto-Roll encerrado com sucesso.")
                                HubState.AutoRollClass = false
                                break
                            end
                        else
                            addLog("warn", "Remotes.RollClass nao encontrado no Lobby!")
                            HubState.AutoRollClass = false
                            break
                        end
                    end
                end)
            end
        end)

        addNativeButton(lobbyTab, "Roll Class Once (Manual - 40 Gems)", function()
            if Remotes.RollClass then
                local s, res = pcall(function() return Remotes.RollClass:InvokeServer() end)
                addLog("info", "Manual Class Roll Result: " .. tostring(res or LocalPlayer:GetAttribute("ActiveClass")))
            else
                addLog("warn", "Remotes.RollClass nao encontrado!")
            end
        end)

        addNativeSection(lobbyTab, "Target Class Quick-Pick", Color3.fromRGB(99, 102, 241))
        addNativeButton(lobbyTab, "Target: Ultimate Farmer (0.1% Mythic)", function()
            HubState.TargetClass = "Ultimate Farmer"
            addLog("info", "Target Class definida como: Ultimate Farmer")
        end)
        addNativeButton(lobbyTab, "Target: Drone Specialist (1% Legendary)", function()
            HubState.TargetClass = "Drone Specialist"
            addLog("info", "Target Class definida como: Drone Specialist")
        end)
        addNativeButton(lobbyTab, "Target: Prospector (3.9% Epic)", function()
            HubState.TargetClass = "Prospector"
            addLog("info", "Target Class definida como: Prospector")
        end)
        addNativeButton(lobbyTab, "Target: Demolitionist (7% Rare)", function()
            HubState.TargetClass = "Demolitionist"
            addLog("info", "Target Class definida como: Demolitionist")
        end)
        addNativeButton(lobbyTab, "Target: Forkmaster (9% Rare)", function()
            HubState.TargetClass = "Forkmaster"
            addLog("info", "Target Class definida como: Forkmaster")
        end)
        addNativeButton(lobbyTab, "Target: Hay Merchant (14% Uncommon)", function()
            HubState.TargetClass = "Hay Merchant"
            addLog("info", "Target Class definida como: Hay Merchant")
        end)
        addNativeButton(lobbyTab, "Target: Pack Mule (25% Common)", function()
            HubState.TargetClass = "Pack Mule"
            addLog("info", "Target Class definida como: Pack Mule")
        end)

        addNativeSection(lobbyTab, "Class Slots", Color3.fromRGB(99, 102, 241))
        addNativeButton(lobbyTab, "Equip Class Slot 1", function()
            if Remotes.SelectClassSlot then
                local s, res = pcall(function() return Remotes.SelectClassSlot:InvokeServer(1) end)
                addLog("info", "Equipped Class Slot 1 (Result: " .. tostring(res) .. ")")
            end
        end)
        addNativeButton(lobbyTab, "Equip Class Slot 2", function()
            if Remotes.SelectClassSlot then
                local s, res = pcall(function() return Remotes.SelectClassSlot:InvokeServer(2) end)
                addLog("info", "Equipped Class Slot 2 (Result: " .. tostring(res) .. ")")
            end
        end)
        addNativeButton(lobbyTab, "Equip Class Slot 3", function()
            if Remotes.SelectClassSlot then
                local s, res = pcall(function() return Remotes.SelectClassSlot:InvokeServer(3) end)
                addLog("info", "Equipped Class Slot 3 (Result: " .. tostring(res) .. ")")
            end
        end)

        addNativeSection(lobbyTab, "Pets & Companions", Color3.fromRGB(99, 102, 241))
        addNativeButton(lobbyTab, "Equip Cow Pet (Sells in Place + 120 Cap)", function()
            if Remotes.EquipPet then
                local s, res = pcall(function() return Remotes.EquipPet:InvokeServer("Cow") end)
                addLog("info", "Equipar Vaca: " .. tostring(res or "Enviado"))
            else
                addLog("warn", "Remotes.EquipPet nao encontrado!")
            end
        end)
        addNativeButton(lobbyTab, "Equip Chicken Pet (30 Cap + 6 Take)", function()
            if Remotes.EquipPet then
                local s, res = pcall(function() return Remotes.EquipPet:InvokeServer("Chicken") end)
                addLog("info", "Equipar Galinha: " .. tostring(res or "Enviado"))
            else
                addLog("warn", "Remotes.EquipPet nao encontrado!")
            end
        end)

        addNativeSection(lobbyTab, "Chests & Event Rewards", Color3.fromRGB(99, 102, 241))
        addNativeButton(lobbyTab, "Open All Event Chests (Batch x10)", function()
            if Remotes.OpenChest then
                addLog("info", "Iniciando abertura de baus de evento...")
                for i = 1, 10 do
                    pcall(function() Remotes.OpenChest:InvokeServer() end)
                    task.wait(0.2)
                end
                addLog("info", "Lote de baus finalizado.")
            else
                addLog("warn", "Remotes.OpenChest nao encontrado!")
            end
        end)

        addNativeSection(lobbyTab, "Lobby Navigation & Portals", Color3.fromRGB(99, 102, 241))
        addNativeButton(lobbyTab, "Teleport to Match Circle (Join Game)", function()
            local hrp = getHRP()
            if hrp then
                local found = false
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and (obj.Name:lower():find("portal") or obj.Name:lower():find("circle") or obj.Name:lower():find("teleport") or obj.Name:lower():find("pad")) then
                        hrp.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                        addLog("info", "Teleported to Match Circle: " .. obj.Name)
                        found = true
                        break
                    end
                end
                if not found then
                    hrp.CFrame = CFrame.new(-38, 5, -8)
                    addLog("info", "Teleported to default Match Circle area.")
                end
            end
        end)
        addNativeButton(lobbyTab, "Teleport to Pet Shop", function()
            local hrp = getHRP()
            if hrp then hrp.CFrame = CFrame.new(20, 5, -30) addLog("info", "Teleported to Pet Shop area.") end
        end)
        addNativeButton(lobbyTab, "Teleport to Class Pedestal", function()
            local hrp = getHRP()
            if hrp then hrp.CFrame = CFrame.new(-10, 5, 25) addLog("info", "Teleported to Class Pedestal area.") end
        end)

        -- 2. Lobby Shop Tab (Dedicated Store with Clear Separation)
        addNativeSection(lobbyShopTab, "Melhorias Permanentes (Moeda: Gemas)", Color3.fromRGB(52, 211, 153))
        local lobbyGemsCard = addNativeParagraph(lobbyShopTab, "Gemas da Conta", "Gemas Atuais: " .. tostring(LocalPlayer:GetAttribute("Gems") or 0) .. " | Melhorias permanentes de conta.", Color3.fromRGB(52, 211, 153))
        task.spawn(function()
            while IsHubLoaded do
                task.wait(1.5)
                pcall(function()
                    if lobbyGemsCard and lobbyGemsCard.Parent then
                        lobbyGemsCard.Text = "Gemas Atuais: " .. tostring(LocalPlayer:GetAttribute("Gems") or 0) .. " | Melhorias permanentes de conta."
                    end
                end)
            end
        end)
        
        addNativeButton(lobbyShopTab, "Upgrade Permanente: +5 Capacidade (ExtraHoldAmount)", function()
            if Remotes.BuyUpgrade then
                pcall(function() Remotes.BuyUpgrade:FireServer("ExtraHoldAmount") end)
                addLog("info", "Comprado upgrade de Gemas: ExtraHoldAmount")
            end
        end, false, "gem")
        addNativeButton(lobbyShopTab, "Upgrade Permanente: +1 Pegada (ExtraTakeAmount)", function()
            if Remotes.BuyUpgrade then
                pcall(function() Remotes.BuyUpgrade:FireServer("ExtraTakeAmount") end)
                addLog("info", "Comprado upgrade de Gemas: ExtraTakeAmount")
            end
        end, false, "gem")
        addNativeButton(lobbyShopTab, "Upgrade Permanente: +1 Multiplicador de Gema (GemValue)", function()
            if Remotes.BuyUpgrade then
                pcall(function() Remotes.BuyUpgrade:FireServer("GemValue") end)
                addLog("info", "Comprado upgrade de Gemas: GemValue")
            end
        end, false, "gem")
        addNativeButton(lobbyShopTab, "Upgrade Permanente: +10% Valor do Feno (ExtraHayValue)", function()
            if Remotes.BuyUpgrade then
                pcall(function() Remotes.BuyUpgrade:FireServer("ExtraHayValuePercentage") end)
                addLog("info", "Comprado upgrade de Gemas: ExtraHayValuePercentage")
            end
        end, false, "gem")

        addNativeSection(lobbyShopTab, "Mercado do Lobby & Skins (Moeda do Jogo)", Color3.fromRGB(99, 102, 241))
        addNativeButton(lobbyShopTab, "Abrir Interface do Mercador (Merchant)", function()
            pcall(function()
                local ms = ReplicatedStorage:FindFirstChild("MerchantSystem")
                if ms and ms:FindFirstChild("OpenMerchant") then
                    ms.OpenMerchant:Fire()
                    addLog("info", "Disparado evento OpenMerchant")
                end
            end)
        end)

        addNativeSection(lobbyShopTab, "Loja Robux (Pago com Robux Real)", Color3.fromRGB(245, 158, 11))
        addNativeParagraph(lobbyShopTab, "ATENCAO - PRODUTO PAGO COM ROBUX", "Os itens abaixo custam ROBUX reais da sua conta Roblox! Clicar em qualquer opcao abrira a confirmacao oficial da Roblox.", Color3.fromRGB(245, 158, 11))
        
        addNativeButton(lobbyShopTab, "[ROBUX] 2x Gemas Permanente (Gamepass 99 R$)", function()
            promptRobuxPurchase("GamePass", 0, "2x Gemas")
        end, false, "robux")
        addNativeButton(lobbyShopTab, "[ROBUX] Mochila Infinita (Infinite Bag Gamepass)", function()
            promptRobuxPurchase("GamePass", 0, "Mochila Infinita")
        end, false, "robux")
        addNativeButton(lobbyShopTab, "[ROBUX] Forquilha Permanente (Permanent Pitchfork)", function()
            promptRobuxPurchase("GamePass", 0, "Permanent Pitchfork")
        end, false, "robux")
        addNativeButton(lobbyShopTab, "[ROBUX] Aspirador Permanente (Permanent Vacuum)", function()
            promptRobuxPurchase("GamePass", 0, "Permanent Vacuum")
        end, false, "robux")
        addNativeButton(lobbyShopTab, "[ROBUX] TNT Permanente (Permanent TNT)", function()
            promptRobuxPurchase("GamePass", 0, "Permanent TNT")
        end, false, "robux")
        addNativeButton(lobbyShopTab, "[ROBUX] Drone Permanente (Permanent Drone)", function()
            promptRobuxPurchase("GamePass", 0, "Permanent Drone")
        end, false, "robux")

        -- 3. Dedicated Promo Codes Tab
        addNativeSection(codesTab, "Sistema de Codigos Promocionais", Color3.fromRGB(99, 102, 241))
        addNativeParagraph(codesTab, "Resgate de Recompensas", "Resgate codigos promocionais oficiais do jogo para obter Gemas, Moedas e bonus gratuitos no Lobby!", Color3.fromRGB(99, 102, 241))

        addNativeSection(codesTab, "Status do Ultimo Resgate", Color3.fromRGB(56, 189, 248))
        local codeStatusCard = addNativeParagraph(codesTab, "Resposta do Servidor", LastCodeStatusMessage, Color3.fromRGB(56, 189, 248))
        task.spawn(function()
            while IsHubLoaded do
                task.wait(0.5)
                pcall(function()
                    if codeStatusCard and codeStatusCard.Parent then
                        codeStatusCard.Text = LastCodeStatusMessage
                    end
                end)
            end
        end)

        addNativeSection(codesTab, "Acoes de Resgate", Color3.fromRGB(99, 102, 241))
        addNativeButton(codesTab, "Resgatar Todos os Codigos (Lote de 20 Codigos)", function()
            redeemAllCodes("")
        end, true)

        addNativeInput(codesTab, "Insira codigo customizado...", "Resgatar", function(txt)
            if txt and txt ~= "" then
                redeemSingleCode(txt)
            end
        end)

        addNativeSection(codesTab, "Interface Oficial do Jogo", Color3.fromRGB(156, 163, 175))
        addNativeButton(codesTab, "Abrir Interface Nativa de Codigos do Jogo", function()
            pcall(function()
                local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                if pGui then
                    local codeUi = pGui:FindFirstChild("CodeUi")
                    if codeUi then
                        local codeFrame = codeUi:FindFirstChild("CodeFrame")
                        if codeFrame then
                            codeFrame.Visible = not codeFrame.Visible
                            addLog("info", "Toggled native CodeFrame visibility: " .. tostring(codeFrame.Visible))
                        end
                    end
                end
            end)
        end)

        -- 4. Match Warp Tab
        addNativeSection(warpTab, "Direct Match Teleports", Color3.fromRGB(99, 102, 241))
        addNativeButton(warpTab, "Direct Teleport to Farmhouse Match (ID 108628039999641)", function()
            addLog("info", "Teleporting to Farmhouse Match...")
            TeleportService:Teleport(FARMHOUSE_PLACE_ID, LocalPlayer)
        end, true)
        addNativeButton(warpTab, "Direct Teleport to Basement Match (ID 83445806734780)", function()
            addLog("info", "Teleporting to Basement Match...")
            TeleportService:Teleport(BASEMENT_PLACE_ID, LocalPlayer)
        end)

        addNativeSection(warpTab, "Server Routing", Color3.fromRGB(99, 102, 241))
        addNativeButton(warpTab, "Server Hop (Find New Lobby)", function()
            addLog("info", "Searching for alternate Lobby server...")
            TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
        end)
        addNativeButton(warpTab, "Rejoin Current Lobby Server", function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)

        -- Default Lobby Tab Selection
        selectTab("Lobby Hub")

    else
        -- ==================================================================
        -- MATCH MODE (ONLY GAMEPLAY FARMING & COMBAT FEATURES SHOWN)
        -- ==================================================================
        local farmTab = createTab("Auto Farm", "FARM")
        local shopTab = createTab("Barn Shop", "SHOP")
        local playerTab = createTab("Player", "HERO")
        local teleTab = createTab("Teleport", "WARP")
        local espTab = createTab("Visuals ESP", "ESP")
        local consoleTab = createTab("Console", "LOGS")
        local setTab = createTab("Settings", "CFG")

        -- 1. Auto Farm Tab
        addNativeSection(farmTab, "Harvest Automation", Color3.fromRGB(99, 102, 241))
        addNativeToggle(farmTab, "Auto Collect Hay (Multi-Grab)", HubState.AutoFarmHay, function(val)
            HubState.AutoFarmHay = val
            addLog("info", "Auto Farm Hay: " .. tostring(val))
        end)
        addNativeToggle(farmTab, "Auto-Equip Best Tool (Vacuum/Pitchfork)", HubState.AutoEquipBestTool, function(val)
            HubState.AutoEquipBestTool = val
            if val then
                local bestSlot = getBestAvailableToolSlot()
                equipToolSlot(bestSlot)
            end
            addLog("info", "Auto-Equip Best Tool: " .. tostring(val))
        end)
        addNativeToggle(farmTab, "Auto-Use TNT (Explosive Cleaver)", HubState.AutoUseTnt, function(val)
            HubState.AutoUseTnt = val
            addLog("info", "Auto-Use TNT: " .. tostring(val))
        end)
        addNativeSlider(farmTab, "Auto-TNT Interval (Seconds)", 8, 30, HubState.TntInterval, function(val)
            HubState.TntInterval = val
        end)
        addNativeToggle(farmTab, "Prioritize Rare / RGB / Void (20x Value)", HubState.PrioritizeRGB, function(val)
            HubState.PrioritizeRGB = val
            addLog("info", "Prioritize Rare Straws: " .. tostring(val))
        end)
        addNativeToggle(farmTab, "Auto Collect Gems", HubState.AutoCollectGems, function(val)
            HubState.AutoCollectGems = val
            addLog("info", "Auto Collect Gems: " .. tostring(val))
        end)
        addNativeToggle(farmTab, "Auto Sell when Bag is Full", HubState.AutoSell, function(val)
            HubState.AutoSell = val
            addLog("info", "Auto Sell: " .. tostring(val))
        end)
        addNativeToggle(farmTab, "Auto-Win Needle (Farmer Hand-In)", HubState.AutoWinNeedle, function(val)
            HubState.AutoWinNeedle = val
            addLog("info", "Auto-Win Needle: " .. tostring(val))
        end)
        addNativeToggle(farmTab, "Auto Deploy Drone", HubState.AutoDeployDrone, function(val)
            HubState.AutoDeployDrone = val
        end)

        addNativeSection(farmTab, "Tool Recognition Status", Color3.fromRGB(99, 102, 241))
        local toolStatusLbl = addNativeParagraph(farmTab, "Dynamic Tool Recognition", getToolStatusSummary(), Color3.fromRGB(99, 102, 241))
        task.spawn(function()
            while IsHubLoaded do
                task.wait(1.2)
                pcall(function()
                    if toolStatusLbl and toolStatusLbl.Parent then
                        toolStatusLbl.Text = getToolStatusSummary()
                    end
                end)
            end
        end)

        addNativeSection(farmTab, "Manual Tool Overrides", Color3.fromRGB(99, 102, 241))
        addNativeButton(farmTab, "Auto-Select Best Available Tool", function()
            HubState.ForcedToolSlot = 0
            local bestSlot = getBestAvailableToolSlot()
            equipToolSlot(bestSlot)
            addLog("info", "Reset tool selection to Auto: Equipped Slot " .. bestSlot)
        end)
        addNativeButton(farmTab, "Throw TNT Now (Instant Blast)", function()
            local hrp = getHRP()
            if hrp then
                local target = nil
                local rgbStrands = getAllRainbowStrands()
                if #rgbStrands > 0 then
                    target = rgbStrands[1].Position
                else
                    target = Landmarks.HayCenter or (hrp.Position + hrp.CFrame.LookVector * 18)
                end
                throwTntAt(target)
            end
        end, true)
        addNativeButton(farmTab, "Equip Vacuum (Slot 5)", function()
            HubState.ForcedToolSlot = SLOT_VACUUM
            equipToolSlot(SLOT_VACUUM)
        end)
        addNativeButton(farmTab, "Equip Pitchfork (Slot 3)", function()
            HubState.ForcedToolSlot = SLOT_PITCHFORK
            equipToolSlot(SLOT_PITCHFORK)
        end)
        addNativeButton(farmTab, "Equip TNT (Slot 2)", function()
            HubState.ForcedToolSlot = SLOT_TNT
            equipToolSlot(SLOT_TNT)
        end)
        addNativeButton(farmTab, "Equip Hand (Slot 1)", function()
            HubState.ForcedToolSlot = SLOT_HAND
            equipToolSlot(SLOT_HAND)
        end)
        addNativeButton(farmTab, "Deploy Drone Now (Slot 4)", function()
            if Remotes.DeployDrone then
                pcall(function() Remotes.DeployDrone:FireServer() end)
                addLog("info", "Fired DeployDrone command")
            end
        end)

        addNativeSection(farmTab, "Quick Actions", Color3.fromRGB(99, 102, 241))
        addNativeButton(farmTab, "Sell Hay Now (Instant Teleport)", function()
            teleportTo(Landmarks.SellCow)
            task.wait(0.2)
            if Remotes.SellHay then Remotes.SellHay:FireServer() end
            addLog("info", "Executed instant sell.")
        end, true)

        -- 2. Barn Shop Tab (Dedicated Store with Robux vs In-Game Separation)
        addNativeSection(shopTab, "Ferramentas do Celeiro (Moeda: Hay / Feno)", Color3.fromRGB(99, 102, 241))
        addNativeParagraph(shopTab, "Sobre as Ferramentas", "Compre ferramentas usando o Feno/Dinheiro da partida. Desbloqueia novas mecanicas de colheita.", Color3.fromRGB(99, 102, 241))
        
        addNativeToggle(shopTab, "Auto Buy Barn Tools (Feno)", HubState.AutoBuyTools, function(val)
            HubState.AutoBuyTools = val
            addLog("info", "Auto-Buy Barn Tools: " .. tostring(val))
        end)
        
        addNativeButton(shopTab, "Comprar Aspirador (Vacuum) - Moeda de Feno", function()
            if Remotes.BuyShopItem then
                pcall(function() Remotes.BuyShopItem:FireServer("Vacuum") end)
                addLog("info", "Solicitada compra de: Vacuum")
            end
        end)
        addNativeButton(shopTab, "Comprar Forquilha (Pitchfork) - Moeda de Feno", function()
            if Remotes.BuyShopItem then
                pcall(function() Remotes.BuyShopItem:FireServer("Pitchfork") end)
                addLog("info", "Solicitada compra de: Pitchfork")
            end
        end)
        addNativeButton(shopTab, "Comprar Dinamite (TNT) - Moeda de Feno", function()
            if Remotes.BuyShopItem then
                pcall(function() Remotes.BuyShopItem:FireServer("Tnt") end)
                addLog("info", "Solicitada compra de: TNT")
            end
        end)
        addNativeButton(shopTab, "Comprar Drone (Drone Agricola) - Moeda de Feno", function()
            if Remotes.BuyShopItem then
                pcall(function() Remotes.BuyShopItem:FireServer("Drone") end)
                addLog("info", "Solicitada compra de: Drone")
            end
        end)

        addNativeSection(shopTab, "Melhorias da Partida (Moeda: Hay / Feno)", Color3.fromRGB(99, 102, 241))
        addNativeParagraph(shopTab, "Upgrades de Sessao", "Melhorias que duram a rodada atual. Custam o dinheiro ganho colhendo feno.", Color3.fromRGB(99, 102, 241))
        
        addNativeToggle(shopTab, "Auto Buy Session Upgrades (Feno)", HubState.AutoBuyUpgrades, function(val)
            HubState.AutoBuyUpgrades = val
            addLog("info", "Auto-Buy Session Upgrades: " .. tostring(val))
        end)
        
        addNativeButton(shopTab, "Upgrade: Capacidade da Mochila (Capacity)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("Capacity") end) end
        end)
        addNativeButton(shopTab, "Upgrade: Quantidade por Pegada (Grab)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("Grab") end) end
        end)
        addNativeButton(shopTab, "Upgrade: Velocidade de Coleta (Speed)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("Speed") end) end
        end)
        addNativeButton(shopTab, "Upgrade: Aspirador Potencia (VacuumPower)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("VacuumPower") end) end
        end)
        addNativeButton(shopTab, "Upgrade: Aspirador Resfriamento (VacuumCooling)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("VacuumCooling") end) end
        end)
        addNativeButton(shopTab, "Upgrade: TNT Sorte Arco-Iris (TntLuck)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("TntLuck") end) end
        end)
        addNativeButton(shopTab, "Upgrade: TNT Cooldown (TntCooldown)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("TntCooldown") end) end
        end)
        addNativeButton(shopTab, "Upgrade: Drone Capacidade (DroneCapacity)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("DroneCapacity") end) end
        end)
        addNativeButton(shopTab, "Upgrade: Drone Pegada (DroneGrab)", function()
            if Remotes.BuyUpgrade then pcall(function() Remotes.BuyUpgrade:FireServer("DroneGrab") end) end
        end)

        addNativeSection(shopTab, "Melhorias Permanentes (Moeda: Gemas)", Color3.fromRGB(52, 211, 153))
        local matchGemsCard = addNativeParagraph(shopTab, "Gemas da Conta", "Gemas Atuais: " .. tostring(LocalPlayer:GetAttribute("Gems") or 0) .. " | Melhorias permanentes de conta.", Color3.fromRGB(52, 211, 153))
        task.spawn(function()
            while IsHubLoaded do
                task.wait(1.5)
                pcall(function()
                    if matchGemsCard and matchGemsCard.Parent then
                        matchGemsCard.Text = "Gemas Atuais: " .. tostring(LocalPlayer:GetAttribute("Gems") or 0) .. " | Melhorias permanentes de conta."
                    end
                end)
            end
        end)
        
        addNativeButton(shopTab, "Upgrade Permanente: +5 Capacidade (ExtraHoldAmount)", function()
            if Remotes.BuyUpgrade then
                pcall(function() Remotes.BuyUpgrade:FireServer("ExtraHoldAmount") end)
                addLog("info", "Comprado upgrade de Gemas: ExtraHoldAmount")
            end
        end, false, "gem")
        addNativeButton(shopTab, "Upgrade Permanente: +1 Pegada (ExtraTakeAmount)", function()
            if Remotes.BuyUpgrade then
                pcall(function() Remotes.BuyUpgrade:FireServer("ExtraTakeAmount") end)
                addLog("info", "Comprado upgrade de Gemas: ExtraTakeAmount")
            end
        end, false, "gem")
        addNativeButton(shopTab, "Upgrade Permanente: +1 Multiplicador de Gema (GemValue)", function()
            if Remotes.BuyUpgrade then
                pcall(function() Remotes.BuyUpgrade:FireServer("GemValue") end)
                addLog("info", "Comprado upgrade de Gemas: GemValue")
            end
        end, false, "gem")
        addNativeButton(shopTab, "Upgrade Permanente: +10% Valor do Feno (ExtraHayValue)", function()
            if Remotes.BuyUpgrade then
                pcall(function() Remotes.BuyUpgrade:FireServer("ExtraHayValuePercentage") end)
                addLog("info", "Comprado upgrade de Gemas: ExtraHayValuePercentage")
            end
        end, false, "gem")

        addNativeSection(shopTab, "Loja Robux (Pago com Robux Real)", Color3.fromRGB(245, 158, 11))
        addNativeParagraph(shopTab, "ATENCAO - PRODUTO PAGO COM ROBUX", "Os itens abaixo custam ROBUX reais da sua conta Roblox! Clicar em qualquer opcao abrira a confirmacao oficial da Roblox.", Color3.fromRGB(245, 158, 11))
        
        addNativeButton(shopTab, "[ROBUX] 2x Gemas Permanente (Gamepass 99 R$)", function()
            promptRobuxPurchase("GamePass", 0, "2x Gemas")
        end, false, "robux")
        addNativeButton(shopTab, "[ROBUX] Mochila Infinita (Infinite Bag Gamepass)", function()
            promptRobuxPurchase("GamePass", 0, "Mochila Infinita")
        end, false, "robux")
        addNativeButton(shopTab, "[ROBUX] Forquilha Permanente (Permanent Pitchfork)", function()
            promptRobuxPurchase("GamePass", 0, "Permanent Pitchfork")
        end, false, "robux")
        addNativeButton(shopTab, "[ROBUX] Aspirador Permanente (Permanent Vacuum)", function()
            promptRobuxPurchase("GamePass", 0, "Permanent Vacuum")
        end, false, "robux")
        addNativeButton(shopTab, "[ROBUX] TNT Permanente (Permanent TNT)", function()
            promptRobuxPurchase("GamePass", 0, "Permanent TNT")
        end, false, "robux")
        addNativeButton(shopTab, "[ROBUX] Drone Permanente (Permanent Drone)", function()
            promptRobuxPurchase("GamePass", 0, "Permanent Drone")
        end, false, "robux")

        addNativeSection(shopTab, "Aviso sobre Codigos", Color3.fromRGB(156, 163, 175))
        addNativeParagraph(shopTab, "Codigos Promocionais", "O sistema de codigos funciona exclusivamente no LOBBY! Use a aba Teleport -> Return to Lobby para resgatar codigos.", Color3.fromRGB(156, 163, 175))

        -- 3. Teleport Tab
        addNativeSection(teleTab, "Map Landmarks", Color3.fromRGB(99, 102, 241))
        addNativeButton(teleTab, "Teleport to Hay Mound", function()
            teleportTo(Landmarks.HayCenter)
            addLog("info", "Teleported to Hay Mound")
        end)
        addNativeButton(teleTab, "Teleport to Sell Cow", function()
            teleportTo(Landmarks.SellCow)
            addLog("info", "Teleported to Sell Cow")
        end)
        addNativeButton(teleTab, "Teleport to Farmer NPC", function()
            teleportTo(Landmarks.FarmerNPC)
            addLog("info", "Teleported to Farmer NPC")
        end)
        addNativeButton(teleTab, "Teleport to Needle", function()
            local needle = findNeedle()
            if needle then
                local pos = needle:IsA("BasePart") and needle.Position or (needle:IsA("Model") and needle:GetPivot().Position)
                if pos then
                    teleportTo(pos + Vector3.new(0, 3, 0))
                    addLog("info", "Teleported directly to Needle!")
                end
            else
                addLog("warn", "Needle not currently revealed!")
            end
        end)

        addNativeSection(teleTab, "Server Routing", Color3.fromRGB(99, 102, 241))
        addNativeButton(teleTab, "Return to Lobby Server", function()
            if Remotes.ReturnToLobby then Remotes.ReturnToLobby:FireServer() end
            TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
        end)
        addNativeButton(teleTab, "Rejoin Current Server", function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)

        -- 4. Visuals ESP Tab
        addNativeSection(espTab, "Visual ESP Trackers", Color3.fromRGB(99, 102, 241))
        addNativeToggle(espTab, "Needle ESP (Bright Yellow)", HubState.NeedleESP, function(val) HubState.NeedleESP = val end)
        addNativeToggle(espTab, "Rare / RGB / Void Straw ESP (Magenta)", HubState.RgbESP, function(val) HubState.RgbESP = val end)
        addNativeToggle(espTab, "Gems ESP (Emerald Green)", HubState.GemESP, function(val) HubState.GemESP = val end)
        addNativeToggle(espTab, "Sell Cow ESP (Electric Blue)", HubState.SellESP, function(val) HubState.SellESP = val end)
        addNativeToggle(espTab, "Player ESP (White)", HubState.PlayerESP, function(val) HubState.PlayerESP = val end)

        -- Default Match Tab Selection
        selectTab("Auto Farm")
    end

    -- ==================================================================
    -- COMMON TABS (BUILT IN BOTH LOBBY AND MATCH)
    -- ==================================================================

    -- Common: Player Tab
    local playerTab = tabFrames["Player"]
    if playerTab then
        addNativeSection(playerTab, "Camera & Mouse Freedom")
        addNativeToggle(playerTab, "Unlock Camera (3rd Person)", HubState.UnlockCamera, function(val)
            HubState.UnlockCamera = val
            applyCameraAndMouse()
        end)
        addNativeToggle(playerTab, "Free Mouse (Hold RMB to Look)", HubState.FreeMouse, function(val)
            HubState.FreeMouse = val
            applyCameraAndMouse()
        end)
        addNativeButton(playerTab, "Snap 3rd Person Camera (Zoom Out)", function()
            forceSnap3rdPerson(22)
            addLog("info", "Snapped 3rd Person Camera to 22 studs.")
        end)

        addNativeSection(playerTab, "Movement & Speed")
        addNativeToggle(playerTab, "Custom WalkSpeed", HubState.WalkSpeedEnabled, function(val)
            HubState.WalkSpeedEnabled = val
            if not val then
                local hum = getHumanoid()
                if hum then hum.WalkSpeed = IS_LOBBY and 20 or 16 end
            end
        end)
        addNativeSlider(playerTab, "WalkSpeed Value", 16, 250, math.floor(HubState.WalkSpeed), function(val)
            HubState.WalkSpeed = val
        end)

        addNativeToggle(playerTab, "Custom JumpHeight", HubState.JumpHeightEnabled, function(val)
            HubState.JumpHeightEnabled = val
            if not val then
                local hum = getHumanoid()
                if hum then hum.JumpHeight = 7.2 end
            end
        end)
        addNativeSlider(playerTab, "JumpHeight Value", 7, 100, math.floor(HubState.JumpHeight), function(val)
            HubState.JumpHeight = val
        end)

        addNativeSection(playerTab, "Physics & Flight")
        addNativeToggle(playerTab, "Fly (WASD + Space/Shift)", HubState.FlyEnabled, function(val)
            HubState.FlyEnabled = val
            toggleFly(val)
        end)
        addNativeSlider(playerTab, "Fly Speed", 20, 250, HubState.FlySpeed, function(val)
            HubState.FlySpeed = val
        end)
        addNativeToggle(playerTab, "Noclip", HubState.NoclipEnabled, function(val)
            HubState.NoclipEnabled = val
        end)
        addNativeToggle(playerTab, "Infinite Jump", HubState.InfiniteJump, function(val)
            HubState.InfiniteJump = val
        end)
    end

    -- Common: Console Tab
    local consoleTab = tabFrames["Console"]
    if consoleTab then
        addNativeSection(consoleTab, "Real-Time Activity Log")
        local consoleBox = Instance.new("TextBox")
        consoleBox.Size = UDim2.new(0.96, 0, 0, 220)
        consoleBox.BackgroundColor3 = Color3.fromRGB(12, 13, 19)
        consoleBox.TextColor3 = Color3.fromRGB(165, 243, 180)
        consoleBox.Font = Enum.Font.Code
        consoleBox.TextSize = 10
        consoleBox.ClearTextOnFocus = false
        consoleBox.TextEditable = false
        consoleBox.TextXAlignment = Enum.TextXAlignment.Left
        consoleBox.TextYAlignment = Enum.TextYAlignment.Top
        consoleBox.MultiLine = true
        consoleBox.Active = false
        consoleBox.Text = table.concat(LogEntries, "\n")
        consoleBox.Parent = consoleTab
        local cbCorner = Instance.new("UICorner") cbCorner.CornerRadius = UDim.new(0, 6) cbCorner.Parent = consoleBox
        local cbStroke = Instance.new("UIStroke") cbStroke.Color = Color3.fromRGB(36, 40, 58) cbStroke.Thickness = 1 cbStroke.Parent = consoleBox

        local consoleRefreshThread = task.spawn(function()
            while IsHubLoaded do
                task.wait(1)
                pcall(function()
                    if consoleBox and consoleBox.Parent then
                        consoleBox.Text = table.concat(LogEntries, "\n")
                    end
                end)
            end
        end)
        table.insert(HubThreads, consoleRefreshThread)

        addNativeButton(consoleTab, "Limpar Logs", function()
            LogEntries = {}
            if consoleBox then consoleBox.Text = "" end
            addLog("info", "Logs limpos.")
        end)

        addNativeButton(consoleTab, "Dump Remote List (Imprimir Remotos no Log)", function()
            addLog("info", "--- Lista de Remotos Detectados ---")
            for name, r in pairs(Remotes) do
                if r then
                    addLog("info", "  [OK] " .. name .. " -> " .. r:GetFullName())
                else
                    addLog("warn", "  [NIL] " .. name)
                end
            end
        end)
    end

    -- Common: Settings Tab
    local setTab = tabFrames["Settings"]
    if setTab then
        addNativeSection(setTab, "Game & Script Update Watcher")

        local gameWatcherCard = addNativeParagraph(setTab, "Live Game Watcher",
            string.format("Place: %s | PlaceId: %s\nGame Version: v%s | Servidor Ativo",
                tostring(GAME_MODE_NAME), tostring(game.PlaceId), tostring(game.PlaceVersion)))

        local scriptVerCard = addNativeParagraph(setTab, "Script Version Status",
            string.format("Versao Instalada: v%s PRO\nStatus GitHub: %s", SCRIPT_VERSION, ScriptUpdateNotice))

        addNativeButton(setTab, "Verificar Atualizacoes no GitHub", function()
            scriptVerCard.Text = "Conectando ao GitHub para verificar versao..."
            checkForScriptUpdates(function(notice, available)
                if scriptVerCard and scriptVerCard.Parent then
                    scriptVerCard.Text = string.format("Versao Instalada: v%s PRO\nStatus GitHub: %s", SCRIPT_VERSION, notice)
                end
            end)
        end)

        addNativeButton(setTab, "Atualizar / Recarregar Script (Auto-Download)", function()
            addLog("info", "Recarregando script diretamente do GitHub...")
            unloadHub()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/victorcxzk/search-for-the-needle-script/master/main.lua"))()
        end, true)

        addNativeSection(setTab, "Modo de Exibicao da Interface")
        addNativeButton(setTab, "Alternar Contexto (Atualmente: " .. (isLobbyMode and "LOBBY" or "MATCH") .. ")", function()
            CurrentContextMode = (CurrentContextMode == "Lobby") and "Match" or "Lobby"
            addLog("info", "Contexto alternado manualmente para: " .. CurrentContextMode)
            buildNativeUI()
        end)
        addNativeButton(setTab, "Recentralizar Janela no Meio da Tela", function()
            mainFrame.Position = UDim2.fromScale(0.5, 0.5)
            addLog("info", "Janela recentralizada no centro da tela.")
        end)

        addNativeSection(setTab, "Forensic Tools")
        addNativeButton(setTab, "Executar Dumper Forense v3.1 (Salvar Jogo)", function()
            addLog("info", "Iniciando Dumper Forense v3.1...")
            task.spawn(function()
                local code = nil
                pcall(function()
                    if readfile and isfile and isfile("dumper.lua") then
                        code = readfile("dumper.lua")
                    end
                end)
                if not code or #code == 0 then
                    pcall(function()
                        code = game:HttpGet("https://raw.githubusercontent.com/victorcxzk/search-for-the-needle-script/master/dumper.lua")
                    end)
                end
                if not code or #code == 0 then
                    addLog("error", "Nao foi possivel carregar o codigo do dumper.")
                    return
                end
                local fn, err = loadstring(code)
                if not fn then
                    addLog("error", "Erro ao compilar dumper: " .. tostring(err))
                    return
                end
                local ok, runErr = pcall(fn)
                if not ok then
                    addLog("error", "Erro na execucao do dumper: " .. tostring(runErr))
                else
                    addLog("info", "Dumper Forense v3.1 executado com sucesso!")
                end
            end)
        end)

        addNativeSection(setTab, "Hub Information")
        addNativeParagraph(setTab, "Needle Hub v5.5 Ultimate", "Modern Cyber Glass Architecture | Fully Autonomous AI Automation Engine.")

        addNativeSection(setTab, "Session Management")
        addNativeButton(setTab, "UNLOAD / DESTROY SCRIPT", function()
            unloadHub()
        end, true)
    end

    -- Setup Floating Button to toggle main frame visibility
    createFloatingToggleButton(function()
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1024, 600)
            if mainFrame.AbsolutePosition.Y < 10 or mainFrame.AbsolutePosition.Y > vp.Y - 40 or
               mainFrame.AbsolutePosition.X < 10 or mainFrame.AbsolutePosition.X > vp.X - 50 then
                mainFrame.Position = UDim2.fromScale(0.5, 0.5)
            end
        end
    end)
end

-- Background Watcher: Game PlaceVersion Update Detection
pcall(function()
    local initialPlaceVersion = game.PlaceVersion
    game:GetPropertyChangedSignal("PlaceVersion"):Connect(function()
        local newVer = game.PlaceVersion
        addLog("warn", string.format("AVISO: O jogo Search For The Needle acabou de atualizar! (v%s -> v%s)", tostring(initialPlaceVersion), tostring(newVer)))
        pcall(function()
            local StarterGui = safeService("StarterGui")
            if StarterGui then
                StarterGui:SetCore("SendNotification", {
                    Title = "Needle Hub - Jogo Atualizado!",
                    Text = "O jogo foi atualizado para v" .. tostring(newVer) .. "! Verifique se o script precisa de atualizacao.",
                    Duration = 10
                })
            end
        end)
    end)
end)

-- Background Watcher: Place Transition (Lobby <-> Match)
task.spawn(function()
    while IsHubLoaded do
        task.wait(2.5)
        local detectedGameplay = (game.PlaceId == FARMHOUSE_PLACE_ID or game.PlaceId == BASEMENT_PLACE_ID)
        local detectedLobby = (game.PlaceId == LOBBY_PLACE_ID)
        local expected = detectedLobby and "Lobby" or (detectedGameplay and "Match" or CurrentContextMode)
        if expected ~= CurrentContextMode then
            CurrentContextMode = expected
            addLog("info", "Mudanca de local detectada! Alternando interface para modo: " .. CurrentContextMode)
            pcall(buildNativeUI)
        end
    end
end)

-- Check GitHub script updates on load
checkForScriptUpdates()

-- Initialize UI & Apply Camera Snap
local okUi, errUi = pcall(buildNativeUI)
if not okUi then
    warn("[Needle Hub Error]: Failed to construct UI: " .. tostring(errUi))
    addLog("error", "UI Construct Error: " .. tostring(errUi))
end
forceSnap3rdPerson(22)
addLog("info", "Needle Hub v5.5 loaded successfully! Press LeftAlt to toggle mouse, hold RMB to rotate camera.")
