--[[
    SEARCH FOR THE NEEDLE - ULTIMATE AUTOMATION HUB v5.0
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

local function bindRemotes()
    local needleHaystack = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if needleHaystack then
        local names = {
            "PickHay", "PickDroppedHay", "DropHay", "SellHay", "HaySold",
            "BuyUpgrade", "UpgradeChanged", "PitchforkDig", "PitchforkDug",
            "TntAction", "TntExploded", "VacuumAction", "VacuumHarvested",
            "DeployDrone", "DroneHarvested", "DroneSold", "CollectGem",
            "GemSpawned", "GemCollected", "NeedleFound", "NeedleHandIn",
            "NeedleTargetChanged", "NeedleRoundCompleted", "BuyShopItem",
            "ShopPurchaseResult", "HeldToolState", "ClassEffect",
            "IntroCutsceneFinished", "TutorialCompleted", "ReturnToLobby",
            "GetHayState", "GetUpgradeState"
        }
        for _, remoteName in ipairs(names) do
            local obj = needleHaystack:FindFirstChild(remoteName)
            if obj then
                Remotes[remoteName] = obj
            end
        end
    end

    local codeSys = ReplicatedStorage:FindFirstChild("CodeSystem")
    if codeSys then Remotes.RedeemCode = codeSys:FindFirstChild("RedeemCode") end

    local eventChest = ReplicatedStorage:FindFirstChild("EventChest")
    if eventChest then Remotes.OpenChest = eventChest:FindFirstChild("OpenChest") end

    local petSys = ReplicatedStorage:FindFirstChild("PetSystem")
    if petSys then Remotes.EquipPet = petSys:FindFirstChild("EquipPet") end

    local skinSys = ReplicatedStorage:FindFirstChild("SkinSystem")
    if skinSys then Remotes.EquipSkin = skinSys:FindFirstChild("EquipSkin") end

    local classSys = ReplicatedStorage:FindFirstChild("ClassSystem")
    if classSys then
        Remotes.RollClass = classSys:FindFirstChild("RollClass")
        Remotes.SelectClassSlot = classSys:FindFirstChild("SelectClassSlot")
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
    AutoBuyUpgrades = false,
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

    -- Check direct Rainbow attribute
    if part:GetAttribute("Rainbow") == true then return true end

    -- Check Neon material (Rainbow strands in NeedleHaystackClient are Neon)
    if part.Material == Enum.Material.Neon or part.Material == Enum.Material.ForceField then
        return true
    end

    -- Mathematical check via Config.isRainbow(hayId)
    local hayId = part:GetAttribute("HayId")
    if hayId and HaystackConfig and HaystackConfig.isRainbow then
        local s, res = pcall(HaystackConfig.isRainbow, hayId)
        if s and res == true then return true end
    end

    -- Color check: Normal hay is tan/yellow (Hue 0.08..0.17). Rainbow has Hue outside yellow with saturation
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
                    local myPos = hrp.Position
                    local haystack = workspace:FindFirstChild("HaystackClient")

                    -- 1. FULL RAINBOW HUNTING
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

                            pcall(function()
                                Remotes.PickHay:FireServer(rId, candidates)
                            end)
                            addLog("info", string.format("FOCUSED RGB straw [%s] (+%d batch) | %d RGBs remaining on field",
                                tostring(rId), #candidates, #rgbStrands))
                        end

                        if Remotes.PitchforkDig then
                            pcall(function() Remotes.PitchforkDig:FireServer(targetPos) end)
                        end
                    else
                        -- 2. NORMAL HAY HARVESTING (when 0 RGB straws remain on field)
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
                                    pcall(function()
                                        Remotes.PickHay:FireServer(pId, candidates)
                                    end)
                                end
                            end
                        end

                        -- Pitchfork Burst
                        if Remotes.PitchforkDig then
                            pcall(function() Remotes.PitchforkDig:FireServer(myPos - Vector3.new(0, 2.0, 0)) end)
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
                addLog("warn", "Needle is in your hands! Teleporting to Farmer NPC for victory...")
                scanExactLandmarks()
                teleportTo(Landmarks.FarmerNPC)
                task.wait(0.2)

                -- Equip needle tool if in Backpack
                local char = getCharacter()
                local bp = LocalPlayer:FindFirstChild("Backpack")
                if bp and char then
                    for _, tool in ipairs(bp:GetChildren()) do
                        if tool:IsA("Tool") and string.find(string.lower(tool.Name), "needle") then
                            tool.Parent = char
                            break
                        end
                    end
                end

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
        task.wait(4)
        if HubState.AutoDeployDrone and IS_GAMEPLAY and Remotes.DeployDrone then
            local deployed = LocalPlayer:GetAttribute("DroneDeployed")
            if not deployed then
                pcall(function() Remotes.DeployDrone:FireServer() end)
            end
        end
    end
end)
table.insert(HubThreads, droneThread)

-- 8.5 AUTO-BUY UPGRADES
task.spawn(function()
    while IsHubLoaded do
        task.wait(3)
        if HubState.AutoBuyUpgrades and IS_GAMEPLAY and Remotes.BuyUpgrade then
            pcall(function()
                Remotes.BuyUpgrade:FireServer("ExtraTakeAmount")
                task.wait(0.2)
                Remotes.BuyUpgrade:FireServer("ExtraHoldAmount")
                task.wait(0.2)
                Remotes.BuyUpgrade:FireServer("ExtraHayValuePercentage")
            end)
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

-- 8.9 LOBBY AUTOMATION
local KNOWN_CODES = {
    "Launch", "Release", "Update", "1KLikes", "5KLikes", "10KLikes",
    "100KVisits", "Needle", "Haystack", "Lucky", "Win"
}

local function redeemAllCodes(userCode)
    if not Remotes.RedeemCode then
        addLog("warn", "RedeemCode remote not found in current place")
        return
    end
    addLog("info", "Redeeming known codes...")
    for _, code in ipairs(KNOWN_CODES) do
        pcall(function()
            Remotes.RedeemCode:InvokeServer(code)
            task.wait(0.25)
        end)
    end
    if userCode and userCode ~= "" then
        pcall(function()
            Remotes.RedeemCode:InvokeServer(userCode)
        end)
    end
    addLog("info", "Code redemption batch finished.")
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

-- SECTION 9: USER INTERFACE (NATIVE GUI & DRAGGABLE TITLE BAR)

-- Floating Toggle Button on screen
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
    floatBtn.Size = UDim2.fromOffset(115, 34)
    floatBtn.Position = UDim2.new(0, 16, 0.45, 0)
    floatBtn.BackgroundColor3 = Color3.fromRGB(30, 32, 45)
    floatBtn.Text = "Needle Hub"
    floatBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
    floatBtn.Font = Enum.Font.GothamBold
    floatBtn.TextSize = 13
    floatBtn.Parent = floatGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = floatBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90, 130, 255)
    stroke.Thickness = 1.4
    stroke.Parent = floatBtn

    -- Robust drag handler for floating button
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

-- Primary Native UI Builder
local function buildNativeUI()
    addLog("info", "Constructing Native Hub GUI v5.0...")

    if GlobalScreenGui then GlobalScreenGui:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NeedleHubNative"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    GlobalScreenGui = screenGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.fromOffset(590, 440)
    mainFrame.Position = UDim2.fromScale(0.5, 0.5)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 55, 75)
    stroke.Thickness = 1.5
    stroke.Parent = mainFrame

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 38)
    titleBar.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar

    -- Global, non-slipping Dragging Implementation
    local isDraggingMain = false
    local dragStartPos, frameStartPos

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingMain = true
            dragStartPos = input.Position
            frameStartPos = mainFrame.Position
        end
    end)

    local mainDragEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingMain = false
        end
    end)
    table.insert(HubConnections, mainDragEndConn)

    local mainDragMoveConn = UserInputService.InputChanged:Connect(function(input)
        if isDraggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartPos
            mainFrame.Position = UDim2.new(
                frameStartPos.X.Scale,
                frameStartPos.X.Offset + delta.X,
                frameStartPos.Y.Scale,
                frameStartPos.Y.Offset + delta.Y
            )
        end
    end)
    table.insert(HubConnections, mainDragMoveConn)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -110, 1, 0)
    titleLabel.Position = UDim2.fromOffset(14, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Search For The Needle - Hub v5.0 [" .. GAME_MODE_NAME .. "]"
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    -- Minimize Button (_)
    local isMinimized = false
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.fromOffset(26, 26)
    minBtn.Position = UDim2.new(1, -66, 0.5, -13)
    minBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 65)
    minBtn.Text = "_"
    minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 13
    minBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minBtn

    -- Close / Unload Button (X)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(26, 26)
    closeBtn.Position = UDim2.new(1, -34, 0.5, -13)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        unloadHub()
    end)

    -- Container for Tabs & Content
    local bodyContainer = Instance.new("Frame")
    bodyContainer.Name = "BodyContainer"
    bodyContainer.Size = UDim2.new(1, 0, 1, -38)
    bodyContainer.Position = UDim2.fromOffset(0, 38)
    bodyContainer.BackgroundTransparency = 1
    bodyContainer.Parent = mainFrame

    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        minBtn.Text = isMinimized and "+" or "_"
        if isMinimized then
            mainFrame.Size = UDim2.fromOffset(590, 38)
            bodyContainer.Visible = false
        else
            mainFrame.Size = UDim2.fromOffset(590, 440)
            bodyContainer.Visible = true
        end
    end)

    -- Sidebar for Tabs
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 140, 1, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = bodyContainer

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 4)
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Parent = sidebar

    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingTop = UDim.new(0, 10)
    sidebarPadding.Parent = sidebar

    -- Content Area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -140, 1, 0)
    contentArea.Position = UDim2.fromOffset(140, 0)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = bodyContainer

    local tabFrames = {}
    local tabButtons = {}

    local function selectTab(tabName)
        for name, frame in pairs(tabFrames) do
            frame.Visible = (name == tabName)
        end
        for name, btn in pairs(tabButtons) do
            if name == tabName then
                btn.BackgroundColor3 = Color3.fromRGB(60, 75, 140)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                btn.TextColor3 = Color3.fromRGB(180, 180, 200)
            end
        end
    end

    local function createTab(tabName)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        btn.Text = tabName
        btn.TextColor3 = Color3.fromRGB(180, 180, 200)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Parent = sidebar
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "TabContent_" .. tabName
        scroll.Size = UDim2.new(1, -16, 1, -16)
        scroll.Position = UDim2.fromOffset(8, 8)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 5
        scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 90)
        scroll.Visible = false
        scroll.Parent = contentArea

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 8)
        list.HorizontalAlignment = Enum.HorizontalAlignment.Center
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = scroll

        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 20)
        end)

        tabFrames[tabName] = scroll
        tabButtons[tabName] = btn

        btn.MouseButton1Click:Connect(function()
            selectTab(tabName)
        end)

        return scroll
    end

    -- UI Element Builders
    local function addNativeToggle(parent, title, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.96, 0, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
        frame.BorderSizePixel = 0
        frame.Parent = parent
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = frame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 1, 0)
        lbl.Position = UDim2.fromOffset(10, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = title
        lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.fromOffset(42, 22)
        toggleBtn.Position = UDim2.new(1, -52, 0.5, -11)
        toggleBtn.BackgroundColor3 = default and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(60, 60, 75)
        toggleBtn.Text = default and "ON" or "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 10
        toggleBtn.Parent = frame
        local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 6) tc.Parent = toggleBtn

        local currentVal = default
        toggleBtn.MouseButton1Click:Connect(function()
            currentVal = not currentVal
            toggleBtn.Text = currentVal and "ON" or "OFF"
            toggleBtn.BackgroundColor3 = currentVal and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(60, 60, 75)
            callback(currentVal)
        end)
    end

    local function addNativeButton(parent, title, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.96, 0, 0, 34)
        btn.BackgroundColor3 = Color3.fromRGB(40, 50, 85)
        btn.Text = title
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Parent = parent
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
        btn.MouseButton1Click:Connect(callback)
    end

    local function addNativeSlider(parent, title, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.96, 0, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
        frame.BorderSizePixel = 0
        frame.Parent = parent
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = frame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -70, 0, 22)
        lbl.Position = UDim2.fromOffset(10, 4)
        lbl.BackgroundTransparency = 1
        lbl.Text = title
        lbl.TextColor3 = Color3.fromRGB(230, 230, 240)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.fromOffset(50, 22)
        valLbl.Position = UDim2.new(1, -60, 0, 4)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(default)
        valLbl.TextColor3 = Color3.fromRGB(150, 190, 255)
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 12
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = frame

        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(1, -20, 0, 8)
        barBg.Position = UDim2.fromOffset(10, 32)
        barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
        barBg.BorderSizePixel = 0
        barBg.Parent = frame
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = barBg

        local fill = Instance.new("Frame")
        local startFrac = math.clamp((default - min) / (max - min), 0, 1)
        fill.Size = UDim2.fromScale(startFrac, 1)
        fill.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
        fill.BorderSizePixel = 0
        fill.Parent = barBg
        local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 4) fc.Parent = fill

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

    -- Construct Tabs
    local farmTab = createTab("Auto Farm")
    local playerTab = createTab("Player")
    local teleTab = createTab("Teleport")
    local espTab = createTab("ESP")
    local lobbyTab = createTab("Lobby")
    local consoleTab = createTab("Console")
    local setTab = createTab("Settings")

    -- Tab 1: Auto Farm
    addNativeToggle(farmTab, "Auto Collect Hay (Multi-Grab)", HubState.AutoFarmHay, function(val)
        HubState.AutoFarmHay = val
        addLog("info", "Auto Farm Hay: " .. tostring(val))
    end)
    addNativeToggle(farmTab, "Prioritize RGB / Rare Straws (10x Value)", HubState.PrioritizeRGB, function(val)
        HubState.PrioritizeRGB = val
        addLog("info", "Prioritize RGB: " .. tostring(val))
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
    addNativeToggle(farmTab, "Auto Buy Upgrades", HubState.AutoBuyUpgrades, function(val)
        HubState.AutoBuyUpgrades = val
    end)
    addNativeButton(farmTab, "Sell Hay Now (Instant Teleport)", function()
        teleportTo(Landmarks.SellCow)
        task.wait(0.2)
        if Remotes.SellHay then Remotes.SellHay:FireServer() end
        addLog("info", "Executed instant sell.")
    end)

    -- Tab 2: Player
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
    end)
    addNativeSlider(playerTab, "Camera Zoom Distance", 5, 80, HubState.CameraZoomDistance, function(val)
        HubState.CameraZoomDistance = val
        forceSnap3rdPerson(val)
    end)
    addNativeToggle(playerTab, "Custom WalkSpeed", HubState.WalkSpeedEnabled, function(val)
        HubState.WalkSpeedEnabled = val
        if not val then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = 16 end
        end
    end)
    addNativeSlider(playerTab, "WalkSpeed Value", 16, 150, HubState.WalkSpeed, function(val)
        HubState.WalkSpeed = val
    end)
    addNativeToggle(playerTab, "Custom JumpPower", HubState.JumpHeightEnabled, function(val)
        HubState.JumpHeightEnabled = val
        if not val then
            local hum = getHumanoid()
            if hum then hum.JumpHeight = 7.2 end
        end
    end)
    addNativeSlider(playerTab, "JumpHeight Value", 7, 100, math.floor(HubState.JumpHeight), function(val)
        HubState.JumpHeight = val
    end)
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

    -- Tab 3: Teleport
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
    addNativeButton(teleTab, "Teleport to Needle (If Found)", function()
        if Landmarks.NeedleCFrame then
            teleportTo(Landmarks.NeedleCFrame)
            addLog("info", "Teleported to Needle CFrame")
        else
            addLog("warn", "Needle location is not yet known.")
        end
    end)

    -- Tab 4: ESP
    addNativeToggle(espTab, "Needle ESP", HubState.NeedleESP, function(val) HubState.NeedleESP = val end)
    addNativeToggle(espTab, "Rainbow / RGB Straw ESP", HubState.RgbESP, function(val) HubState.RgbESP = val end)
    addNativeToggle(espTab, "Gems ESP", HubState.GemESP, function(val) HubState.GemESP = val end)
    addNativeToggle(espTab, "Sell Cow ESP", HubState.SellESP, function(val) HubState.SellESP = val end)
    addNativeToggle(espTab, "Player ESP", HubState.PlayerESP, function(val) HubState.PlayerESP = val end)

    -- Tab 5: Lobby
    addNativeButton(lobbyTab, "Redeem All Known Codes", function()
        redeemAllCodes("")
    end)
    addNativeButton(lobbyTab, "Equip Cow Pet (Lobby)", function()
        if Remotes.EquipPet then
            Remotes.EquipPet:InvokeServer("Cow")
            addLog("info", "Equipped Cow Pet")
        end
    end)
    addNativeButton(lobbyTab, "Open All Chests", function()
        if Remotes.OpenChest then
            for i = 1, 10 do
                pcall(function() Remotes.OpenChest:InvokeServer() end)
                task.wait(0.2)
            end
            addLog("info", "Batch opened chests.")
        end
    end)

    -- Tab 6: Console
    local consoleBox = Instance.new("TextBox")
    consoleBox.Size = UDim2.new(0.96, 0, 0, 300)
    consoleBox.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    consoleBox.TextColor3 = Color3.fromRGB(190, 240, 190)
    consoleBox.Font = Enum.Font.Code
    consoleBox.TextSize = 11
    consoleBox.ClearTextOnFocus = false
    consoleBox.TextEditable = false
    consoleBox.TextXAlignment = Enum.TextXAlignment.Left
    consoleBox.TextYAlignment = Enum.TextYAlignment.Top
    consoleBox.MultiLine = true
    consoleBox.Text = table.concat(LogEntries, "\n")
    consoleBox.Parent = consoleTab
    local cbCorner = Instance.new("UICorner") cbCorner.CornerRadius = UDim.new(0, 6) cbCorner.Parent = consoleBox

    local consoleRefreshThread = task.spawn(function()
        while IsHubLoaded do
            task.wait(1)
            pcall(function()
                consoleBox.Text = table.concat(LogEntries, "\n")
            end)
        end
    end)
    table.insert(HubThreads, consoleRefreshThread)

    -- Tab 7: Settings & Unload
    addNativeButton(setTab, "UNLOAD / DESTROY SCRIPT", function()
        unloadHub()
    end)

    -- Select Default Tab
    selectTab("Auto Farm")

    -- Setup Floating Button to toggle main frame visibility
    createFloatingToggleButton(function()
        mainFrame.Visible = not mainFrame.Visible
    end)
end

-- Initialize UI & Apply Camera Snap
buildNativeUI()
forceSnap3rdPerson(22)
addLog("info", "Needle Hub v5.0 loaded successfully! Press LeftAlt to toggle mouse, hold RMB to rotate camera.")
