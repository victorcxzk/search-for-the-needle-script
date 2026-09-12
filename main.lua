--[[
    SEARCH FOR THE NEEDLE - ULTIMATE AUTOMATION HUB v2.0
    Forensically Engineered & Optimized
    Place Support: Lobby (77108422251420) & Farmhouse/Basement (108628039999641, 83445806734780)
    Zero Emojis - Full Defensive Programming
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
local HttpService = safeService("HttpService")
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

-- SECTION 2: PLACE CONTEXT DETECTION
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
    GAME_MODE_NAME = "Farmhouse (Match)"
elseif CURRENT_PLACE_ID == BASEMENT_PLACE_ID then
    GAME_MODE_NAME = "Basement (Match)"
else
    GAME_MODE_NAME = "Place " .. tostring(CURRENT_PLACE_ID)
end

-- SECTION 3: IN-GAME LOGGING SYSTEM
local LogEntries = {}
local MAX_LOGS = 80

local function addLog(level, message)
    local timestamp = os.date("%H:%M:%S")
    local formatted = string.format("[%s] [%s] %s", timestamp, string.upper(level), tostring(message))
    table.insert(LogEntries, formatted)
    if #LogEntries > MAX_LOGS then
        table.remove(LogEntries, 1)
    end
    print("[NeedleHub] " .. formatted)
end

addLog("info", "Initialized on " .. GAME_MODE_NAME)

-- SECTION 4: CHARACTER & MOVEMENT HELPERS
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    if char then
        return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
    end
    return nil
end

local function getHumanoid()
    local char = getCharacter()
    if char then
        return char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    end
    return nil
end

local function teleportTo(targetCFrame)
    local hrp = getHRP()
    if hrp and targetCFrame then
        if typeof(targetCFrame) == "Vector3" then
            hrp.CFrame = CFrame.new(targetCFrame + Vector3.new(0, 3.2, 0))
        elseif typeof(targetCFrame) == "CFrame" then
            hrp.CFrame = targetCFrame + Vector3.new(0, 3.2, 0)
        end
        return true
    end
    return false
end

-- SECTION 5: REMOTE REPOSITORIES (FORENSIC DUMP BINDINGS)
local Remotes = {
    -- Gameplay Remotes (NeedleHaystack)
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

    -- Lobby Remotes
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

-- SECTION 6: WORKSPACE LANDMARKS (RESOLVED VIA FORENSIC DUMP)
local Landmarks = {
    -- The Cow / FeedSign where you sell hay in Farmhouse
    SellCow = Vector3.new(-163.37, 5.0, 52.0),
    -- The Farmer NPC
    FarmerNPC = Vector3.new(-161.05, 5.0, 18.3),
    -- Center of the Hayfield
    HayCenter = Vector3.new(-190.0, 4.0, 45.0),
    -- Resolved Needle Location
    NeedleCFrame = nil,
}

local function scanExactLandmarks()
    -- Resolve Farmer NPC
    local npcFolder = workspace:FindFirstChild("NPC")
    if npcFolder and npcFolder:FindFirstChild("Farmer_NPC") then
        local root = npcFolder.Farmer_NPC:FindFirstChild("HumanoidRootPart") or npcFolder.Farmer_NPC:FindFirstChildWhichIsA("BasePart")
        if root then Landmarks.FarmerNPC = root.Position end
    end

    -- Resolve Sell Zone / Cow
    local sellModel = workspace:FindFirstChild("SellModel")
    if sellModel then
        local sign = sellModel:FindFirstChild("FeedSign") or sellModel:FindFirstChild("Sign")
        if sign then
            if sign:IsA("BasePart") then
                Landmarks.SellCow = sign.Position
            elseif sign:IsA("Model") and sign.PrimaryPart then
                Landmarks.SellCow = sign.PrimaryPart.Position
            end
        end
    end

    -- Resolve Haystack Center
    local haystack = workspace:FindFirstChild("HaystackClient")
    if haystack then
        local firstPart = haystack:FindFirstChildWhichIsA("BasePart")
        if firstPart then
            Landmarks.HayCenter = firstPart.Position
        end
    end

    -- Resolve The Needle
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

-- Listen to server events for Needle updates
if Remotes.NeedleTargetChanged then
    Remotes.NeedleTargetChanged.OnClientEvent:Connect(function(targetCFrame)
        if typeof(targetCFrame) == "CFrame" then
            Landmarks.NeedleCFrame = targetCFrame
            addLog("info", "Needle target location updated by server event")
        end
    end)
end

if Remotes.NeedleFound then
    Remotes.NeedleFound.OnClientEvent:Connect(function(...)
        addLog("info", "Needle found broadcast received!")
    end)
end

-- SECTION 7: GLOBAL HUB STATE
local HubState = {
    -- Auto Farm
    AutoFarmHay = false,
    FarmMode = "In-Place", -- "In-Place" or "Teleport"
    AutoSell = true,
    SellMethod = "Remote", -- "Remote" (no TP) or "Teleport"
    FarmDelay = 0.15,
    AutoDeployDrone = true,
    AutoCollectGems = true,
    AutoWinNeedle = false,

    -- Player Mods
    FreeMouse = true,
    UnlockCamera = true,
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
    GemESP = true,
    PlayerESP = false,
    SellESP = true,

    -- Lobby
    AutoRollClass = false,
    TargetClass = "Ultimate Farmer",
}

-- Helper to read player attributes from forensic dump:
local function getHayHeld()
    local val = LocalPlayer:GetAttribute("HayHeld")
    if val and type(val) == "number" then return val end
    return 0
end

local function getHayCapacity()
    local val = LocalPlayer:GetAttribute("HayCapacity")
    if val and type(val) == "number" then return val end
    return 30
end

local function getGems()
    local val = LocalPlayer:GetAttribute("Gems")
    if val and type(val) == "number" then return val end
    return 0
end

-- SECTION 8: FEATURE IMPLEMENTATIONS

-- 8.1 AUTO-FARM ENGINE (NO ARTIFICIAL COUNTER, NO SEIZURE TELEPORT)
local isCurrentlySelling = false

task.spawn(function()
    while true do
        task.wait(HubState.FarmDelay)

        if HubState.AutoFarmHay and IS_GAMEPLAY and not isCurrentlySelling then
            local hrp = getHRP()
            local char = getCharacter()

            if hrp and char then
                local currentHay = getHayHeld()
                local maxCap = getHayCapacity()

                -- CHECK IF BAG IS ACTUALLY FULL
                if currentHay >= maxCap and maxCap > 0 and HubState.AutoSell then
                    isCurrentlySelling = true
                    addLog("info", "Bag full (" .. currentHay .. "/" .. maxCap .. "). Selling hay...")

                    if HubState.SellMethod == "Remote" then
                        -- Method A: Remote Sell without moving
                        if Remotes.SellHay then
                            pcall(function() Remotes.SellHay:FireServer() end)
                        end
                        task.wait(0.5)

                        -- If remote sell didn't reset HayHeld, fallback to quick teleport
                        if getHayHeld() >= maxCap and Landmarks.SellCow then
                            local returnPos = hrp.CFrame
                            teleportTo(Landmarks.SellCow)
                            task.wait(0.35)
                            if Remotes.SellHay then
                                pcall(function() Remotes.SellHay:FireServer() end)
                            end
                            task.wait(0.4)
                            teleportTo(returnPos)
                        end
                    else
                        -- Method B: Teleport Sell
                        if Landmarks.SellCow then
                            local returnPos = hrp.CFrame
                            teleportTo(Landmarks.SellCow)
                            task.wait(0.35)
                            if Remotes.SellHay then
                                pcall(function() Remotes.SellHay:FireServer() end)
                            end
                            task.wait(0.4)
                            teleportTo(returnPos)
                        end
                    end

                    isCurrentlySelling = false
                else
                    -- HARVEST HAY
                    -- If Teleport mode enabled, ensure player is near hay field
                    if HubState.FarmMode == "Teleport" and Landmarks.HayCenter then
                        local dist = (hrp.Position - Landmarks.HayCenter).Magnitude
                        if dist > 35 then
                            teleportTo(Landmarks.HayCenter)
                            task.wait(0.2)
                        end
                    end

                    -- Multi-Method Harvest:
                    -- 1. Swing Pitchfork tool if equipped or in character
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool then
                        pcall(function() tool:Activate() end)
                    end

                    -- 2. Read HoveredHayId if raycaster hovered over a strand
                    local hoveredId = LocalPlayer:GetAttribute("HoveredHayId")
                    if hoveredId and type(hoveredId) == "number" and hoveredId > 0 then
                        if Remotes.PickHay then
                            pcall(function() Remotes.PickHay:FireServer(hoveredId) end)
                        end
                    end

                    -- 3. PitchforkDig at ground level
                    if Remotes.PitchforkDig then
                        pcall(function()
                            Remotes.PitchforkDig:FireServer(hrp.Position - Vector3.new(0, 2.5, 0))
                        end)
                    end

                    -- 4. Pick dropped hay
                    if Remotes.PickDroppedHay then
                        pcall(function() Remotes.PickDroppedHay:FireServer() end)
                    end

                    -- 5. Set tool state to dig
                    if Remotes.HeldToolState then
                        pcall(function() Remotes.HeldToolState:FireServer("Pitchfork", "dig") end)
                    end
                end
            end
        end
    end
end)

-- 8.2 AUTO DEPLOY DRONE
task.spawn(function()
    while true do
        task.wait(4)
        if HubState.AutoDeployDrone and IS_GAMEPLAY and Remotes.DeployDrone then
            local deployed = LocalPlayer:GetAttribute("DroneDeployed")
            if not deployed then
                pcall(function() Remotes.DeployDrone:FireServer() end)
            end
        end
    end
end)

-- 8.3 AUTO COLLECT GEMS
task.spawn(function()
    while true do
        task.wait(1.2)
        if HubState.AutoCollectGems and IS_GAMEPLAY and Remotes.CollectGem then
            local hrp = getHRP()
            if hrp then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "gem") then
                        local dist = (hrp.Position - obj.Position).Magnitude
                        if dist <= 40 then
                            pcall(function() Remotes.CollectGem:FireServer(obj) end)
                        end
                    end
                end
            end
        end
    end
end)

if Remotes.GemSpawned then
    Remotes.GemSpawned.OnClientEvent:Connect(function(gemObj)
        if HubState.AutoCollectGems and Remotes.CollectGem and gemObj then
            pcall(function() Remotes.CollectGem:FireServer(gemObj) end)
        end
    end)
end

-- 8.4 AUTO-WIN NEEDLE (Locate -> Teleport -> HandIn)
task.spawn(function()
    while true do
        task.wait(1)
        if HubState.AutoWinNeedle and IS_GAMEPLAY then
            local needleOwned = LocalPlayer:GetAttribute("NeedleOwned")

            if needleOwned then
                -- Player has the needle! Deliver it to the farmer!
                addLog("info", "Needle is in your inventory! Delivering to Farmer...")
                teleportTo(Landmarks.FarmerNPC)
                task.wait(0.4)
                if Remotes.NeedleHandIn then
                    pcall(function() Remotes.NeedleHandIn:FireServer() end)
                    addLog("info", "Delivered needle to Farmer! Victory!")
                end
            else
                -- Find needle in workspace
                local needle = workspace:FindFirstChild("The Needle") or workspace:FindFirstChild("HiddenNeedleClient")
                if needle then
                    local pos = nil
                    if needle:IsA("BasePart") then pos = needle.Position
                    elseif needle:IsA("Model") and needle.PrimaryPart then pos = needle.PrimaryPart.Position
                    else
                        local p = needle:FindFirstChildWhichIsA("BasePart")
                        if p then pos = p.Position end
                    end

                    if pos then
                        addLog("info", "Needle found in map! Teleporting to it...")
                        teleportTo(pos)
                        task.wait(0.3)
                        -- Try grabbing needle
                        if Remotes.PickHay then pcall(function() Remotes.PickHay:FireServer(pos) end) end
                    end
                elseif Landmarks.NeedleCFrame then
                    addLog("info", "Teleporting to broadcasted Needle position...")
                    teleportTo(Landmarks.NeedleCFrame)
                end
            end
        end
    end
end)

-- 8.5 CAMERA & MOUSE UNLOCKER (Continuous First-Person Breaker)
local function applyCameraAndMouse()
    if HubState.UnlockCamera then
        if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
        end
        if LocalPlayer.CameraMaxZoomDistance < 100 then
            LocalPlayer.CameraMaxZoomDistance = 250
            LocalPlayer.CameraMinZoomDistance = 0.5
        end
    end

    if HubState.FreeMouse then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end

-- Hotkey: LeftAlt or Insert to toggle Free Mouse
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and (input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.Insert) then
        HubState.FreeMouse = not HubState.FreeMouse
        addLog("info", "Free Mouse toggled: " .. (HubState.FreeMouse and "ON (Unlocked)" or "OFF (Locked)"))
    end
end)

-- 8.6 FLY SYSTEM (Smooth Directional Physics)
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

RunService.RenderStepped:Connect(function()
    applyCameraAndMouse()

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    -- Speed Modifier
    if hum and HubState.WalkSpeedEnabled then
        hum.WalkSpeed = HubState.WalkSpeed
    end

    -- Jump Modifier
    if hum and HubState.JumpHeightEnabled then
        hum.JumpHeight = HubState.JumpHeight
    end

    -- Fly Mechanics
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

-- Noclip loop
RunService.Stepped:Connect(function()
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

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if HubState.InfiniteJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- 8.7 ESP SYSTEM (Needle, Gems, Players, Sell Zone)
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

-- Persistent Sell Target Part
local sellAnchorPart = Instance.new("Part")
sellAnchorPart.Name = "SellAnchorPart"
sellAnchorPart.Size = Vector3.new(2, 2, 2)
sellAnchorPart.Position = Landmarks.SellCow
sellAnchorPart.Transparency = 1
sellAnchorPart.Anchored = true
sellAnchorPart.CanCollide = false
sellAnchorPart.Parent = ESPFolder

task.spawn(function()
    while true do
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
            local needlePart = nil
            if needle then
                if needle:IsA("BasePart") then needlePart = needle
                elseif needle:IsA("Model") then needlePart = needle.PrimaryPart or needle:FindFirstChildWhichIsA("BasePart") end
            end

            if needlePart then
                local dist = math.floor((myPos - needlePart.Position).Magnitude)
                updateBillboard("Needle", needlePart, "NEEDLE HERE! [" .. dist .. "m]", Color3.fromRGB(255, 230, 0))
            else
                removeBillboard("Needle")
            end
        else
            removeBillboard("Needle")
        end

        -- 3. Gem ESP
        if HubState.GemESP and IS_GAMEPLAY then
            local gemIndex = 1
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "gem") then
                    local dist = math.floor((myPos - obj.Position).Magnitude)
                    updateBillboard("Gem_" .. gemIndex, obj, "GEM [" .. dist .. "m]", Color3.fromRGB(60, 255, 120))
                    gemIndex = gemIndex + 1
                    if gemIndex > 10 then break end
                end
            end
        else
            for k in pairs(activeBillboards) do
                if string.find(k, "Gem_") then removeBillboard(k) end
            end
        end

        -- 4. Player ESP
        if HubState.PlayerESP then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dist = math.floor((myPos - hrp.Position).Magnitude)
                        updateBillboard("Player_" .. p.UserId, hrp, p.DisplayName .. " [" .. dist .. "m]", Color3.fromRGB(240, 240, 255))
                    end
                end
            end
        else
            for k in pairs(activeBillboards) do
                if string.find(k, "Player_") then removeBillboard(k) end
            end
        end
    end
end)

-- 8.8 LOBBY AUTOMATION
local KNOWN_CODES = {
    "Launch", "Release", "Update", "1KLikes", "5KLikes",
    "10KLikes", "100KVisits", "GEMS", "NEEDLE", "HAY"
}

local function redeemAllCodes()
    if not Remotes.RedeemCode then
        addLog("warn", "Code redemption is only available in the Lobby!")
        return
    end

    task.spawn(function()
        for _, code in ipairs(KNOWN_CODES) do
            pcall(function()
                local res = Remotes.RedeemCode:InvokeServer(code)
                addLog("info", "Code [" .. code .. "]: " .. tostring(res))
            end)
            task.wait(0.5)
        end
    end)
end

local function autoRollClassLoop()
    task.spawn(function()
        while HubState.AutoRollClass do
            if not Remotes.RollClass then
                addLog("warn", "RollClass is only available in the Lobby!")
                break
            end

            local ok, result = pcall(function() return Remotes.RollClass:InvokeServer() end)
            if ok and result then
                addLog("info", "Rolled: " .. tostring(result))
                if tostring(result) == HubState.TargetClass then
                    addLog("info", "Target class obtained: " .. HubState.TargetClass)
                    HubState.AutoRollClass = false
                    break
                end
            else
                addLog("warn", "Roll stopped (insufficient gems or error)")
                task.wait(2)
            end
            task.wait(0.8)
        end
    end)
end

-- SECTION 9: USER INTERFACE (FLUENT UI + NATIVE FALLBACK)
local function buildNativeUI()
    addLog("info", "Loading Fallback Native ScreenGui...")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NeedleHubNative"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.fromOffset(560, 420)
    mainFrame.Position = UDim2.fromScale(0.5, 0.5)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(45, 45, 60)
    stroke.Thickness = 1.5
    stroke.Parent = mainFrame

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 1, 0)
    titleLabel.Position = UDim2.fromOffset(14, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Search For The Needle - Hub v2.0 [" .. GAME_MODE_NAME .. "]"
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(26, 26)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -13)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = not screenGui.Enabled end)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 130, 1, -36)
    sidebar.Position = UDim2.fromOffset(0, 36)
    sidebar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame

    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 4)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Parent = sidebar

    local sidePadding = Instance.new("UIPadding")
    sidePadding.PaddingTop = UDim.new(0, 8)
    sidePadding.PaddingLeft = UDim.new(0, 8)
    sidePadding.PaddingRight = UDim.new(0, 8)
    sidePadding.Parent = sidebar

    -- Content Area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(1, -130, 1, -36)
    contentArea.Position = UDim2.fromOffset(130, 36)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame

    local tabContainers = {}

    local function createTabContent(name)
        local sf = Instance.new("ScrollingFrame")
        sf.Name = name .. "Tab"
        sf.Size = UDim2.fromScale(1, 1)
        sf.BackgroundTransparency = 1
        sf.BorderSizePixel = 0
        sf.CanvasSize = UDim2.fromOffset(0, 650)
        sf.ScrollBarThickness = 4
        sf.Visible = false
        sf.Parent = contentArea

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = sf

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 10)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = sf

        tabContainers[name] = sf
        return sf
    end

    local tabs = {"AutoFarm", "Player", "Teleport", "LobbyAuto", "ESP", "Console"}
    for _, tName in ipairs(tabs) do createTabContent(tName) end

    local function switchTab(tabName)
        for name, container in pairs(tabContainers) do
            container.Visible = (name == tabName)
        end
    end

    for idx, tName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        btn.Text = tName
        btn.TextColor3 = Color3.fromRGB(200, 200, 220)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.LayoutOrder = idx
        btn.Parent = sidebar
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = btn
        btn.MouseButton1Click:Connect(function() switchTab(tName) end)
    end

    local function addNativeToggle(parent, title, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local fCorner = Instance.new("UICorner")
        fCorner.CornerRadius = UDim.new(0, 6)
        fCorner.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -60, 1, 0)
        label.Position = UDim2.fromOffset(10, 0)
        label.BackgroundTransparency = 1
        label.Text = title
        label.TextColor3 = Color3.fromRGB(220, 220, 230)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local tBtn = Instance.new("TextButton")
        tBtn.Size = UDim2.fromOffset(42, 22)
        tBtn.Position = UDim2.new(1, -50, 0.5, -11)
        tBtn.BackgroundColor3 = default and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(60, 60, 75)
        tBtn.Text = default and "ON" or "OFF"
        tBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tBtn.Font = Enum.Font.GothamBold
        tBtn.TextSize = 10
        tBtn.Parent = frame
        local tbCorner = Instance.new("UICorner")
        tbCorner.CornerRadius = UDim.new(0, 6)
        tbCorner.Parent = tBtn

        local state = default
        tBtn.MouseButton1Click:Connect(function()
            state = not state
            tBtn.Text = state and "ON" or "OFF"
            tBtn.BackgroundColor3 = state and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(60, 60, 75)
            callback(state)
        end)
    end

    local function addNativeButton(parent, title, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        btn.Text = title
        btn.TextColor3 = Color3.fromRGB(240, 240, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Parent = parent
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = btn
        btn.MouseButton1Click:Connect(callback)
    end

    -- POPULATE TABS
    -- Tab 1: AutoFarm
    local farmTab = tabContainers.AutoFarm
    addNativeToggle(farmTab, "Auto Collect Hay", HubState.AutoFarmHay, function(val)
        HubState.AutoFarmHay = val
        addLog("info", "Auto Farm Hay: " .. tostring(val))
    end)
    addNativeToggle(farmTab, "Teleport to Hay (Off = In-Place)", false, function(val)
        HubState.FarmMode = val and "Teleport" or "In-Place"
        addLog("info", "Farm mode: " .. HubState.FarmMode)
    end)
    addNativeToggle(farmTab, "Auto Sell (Full Bag)", HubState.AutoSell, function(val)
        HubState.AutoSell = val
    end)
    addNativeToggle(farmTab, "Remote Sell (Off = Teleport to Cow)", true, function(val)
        HubState.SellMethod = val and "Remote" or "Teleport"
        addLog("info", "Sell method: " .. HubState.SellMethod)
    end)
    addNativeToggle(farmTab, "Auto Collect Gems", HubState.AutoCollectGems, function(val)
        HubState.AutoCollectGems = val
    end)
    addNativeToggle(farmTab, "Auto Deploy Drone", HubState.AutoDeployDrone, function(val)
        HubState.AutoDeployDrone = val
    end)
    addNativeToggle(farmTab, "Auto Win / Deliver Needle", HubState.AutoWinNeedle, function(val)
        HubState.AutoWinNeedle = val
        addLog("info", "Auto Win Needle: " .. tostring(val))
    end)
    addNativeButton(farmTab, "Instant Sell Now (Fire Remote)", function()
        if Remotes.SellHay then
            Remotes.SellHay:FireServer()
            addLog("info", "Fired SellHay remote")
        end
    end)

    -- Tab 2: Player
    local playerTab = tabContainers.Player
    addNativeToggle(playerTab, "Free Mouse Cursor [LeftAlt]", HubState.FreeMouse, function(val)
        HubState.FreeMouse = val
    end)
    addNativeToggle(playerTab, "Unlock 3rd Person Zoom", HubState.UnlockCamera, function(val)
        HubState.UnlockCamera = val
        if not val then LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson end
    end)
    addNativeToggle(playerTab, "Enable Speed Modifier (50)", HubState.WalkSpeedEnabled, function(val)
        HubState.WalkSpeed = 50
        HubState.WalkSpeedEnabled = val
    end)
    addNativeToggle(playerTab, "Fly (WASD + Space/Shift)", HubState.FlyEnabled, function(val)
        HubState.FlyEnabled = val
        toggleFly(val)
    end)
    addNativeToggle(playerTab, "Noclip", HubState.NoclipEnabled, function(val)
        HubState.NoclipEnabled = val
    end)
    addNativeToggle(playerTab, "Infinite Jump", HubState.InfiniteJump, function(val)
        HubState.InfiniteJump = val
    end)

    -- Tab 3: Teleport
    local tpTab = tabContainers.Teleport
    addNativeButton(tpTab, "Teleport to Hay Field", function()
        teleportTo(Landmarks.HayCenter)
    end)
    addNativeButton(tpTab, "Teleport to Sell Cow", function()
        teleportTo(Landmarks.SellCow)
    end)
    addNativeButton(tpTab, "Teleport to Farmer NPC", function()
        teleportTo(Landmarks.FarmerNPC)
    end)
    addNativeButton(tpTab, "Teleport to Needle", function()
        if Landmarks.NeedleCFrame then
            teleportTo(Landmarks.NeedleCFrame)
        else
            addLog("warn", "Needle location not yet identified")
        end
    end)

    -- Tab 4: Lobby Automation
    local autoTab = tabContainers.LobbyAuto
    addNativeButton(autoTab, "Redeem All Promo Codes (Lobby)", function()
        redeemAllCodes()
    end)
    addNativeButton(autoTab, "Equip Cow Pet (Highest Capacity)", function()
        if Remotes.EquipPet then Remotes.EquipPet:InvokeServer("Cow") end
    end)
    addNativeButton(autoTab, "Open Alien Chest", function()
        if Remotes.OpenChest then Remotes.OpenChest:InvokeServer() end
    end)
    addNativeToggle(autoTab, "Auto Roll Ultimate Farmer", HubState.AutoRollClass, function(val)
        HubState.AutoRollClass = val
        if val then autoRollClassLoop() end
    end)

    -- Tab 5: ESP
    local espTab = tabContainers.ESP
    addNativeToggle(espTab, "Needle ESP", HubState.NeedleESP, function(val) HubState.NeedleESP = val end)
    addNativeToggle(espTab, "Sell Cow ESP", HubState.SellESP, function(val) HubState.SellESP = val end)
    addNativeToggle(espTab, "Gem ESP", HubState.GemESP, function(val) HubState.GemESP = val end)
    addNativeToggle(espTab, "Player ESP", HubState.PlayerESP, function(val) HubState.PlayerESP = val end)

    -- Tab 6: Console
    local conTab = tabContainers.Console
    local logBox = Instance.new("TextLabel")
    logBox.Size = UDim2.new(1, 0, 0, 240)
    logBox.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    logBox.TextColor3 = Color3.fromRGB(160, 255, 160)
    logBox.Font = Enum.Font.Code
    logBox.TextSize = 11
    logBox.TextXAlignment = Enum.TextXAlignment.Left
    logBox.TextYAlignment = Enum.TextYAlignment.Top
    logBox.TextWrapped = true
    logBox.Parent = conTab
    local lbCorner = Instance.new("UICorner")
    lbCorner.CornerRadius = UDim.new(0, 6)
    lbCorner.Parent = logBox

    task.spawn(function()
        while true do
            task.wait(1)
            local recent = {}
            local count = #LogEntries
            local startIndex = math.max(1, count - 14)
            for i = startIndex, count do table.insert(recent, LogEntries[i]) end
            logBox.Text = table.concat(recent, "\n")
        end
    end)

    addNativeButton(conTab, "Clear Logs", function()
        table.clear(LogEntries)
        logBox.Text = ""
    end)

    switchTab("AutoFarm")
    addLog("info", "Native GUI ready")
end

-- Try loading Fluent UI first
local function initializeFluentUI()
    local Fluent = nil
    local loadSuccess, _ = pcall(function()
        Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Fluent.luau"))()
    end)

    if not loadSuccess or not Fluent then
        addLog("warn", "Fluent UI failed to load. Loading Native GUI.")
        buildNativeUI()
        return
    end

    local Window = Fluent:CreateWindow({
        Title = "Search For The Needle",
        SubTitle = "Hub v2.0 [" .. GAME_MODE_NAME .. "]",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightControl
    })

    -- TAB 1: Auto Farm
    local TabFarm = Window:AddTab({Title = "Auto Farm", Icon = "bot"})

    TabFarm:AddToggle("AutoFarmHay", {Title = "Auto Collect Hay", Default = HubState.AutoFarmHay}):OnChanged(function(val)
        HubState.AutoFarmHay = val
        addLog("info", "Auto Farm Hay: " .. tostring(val))
    end)

    TabFarm:AddDropdown("FarmModeDrop", {
        Title = "Harvest Positioning",
        Values = {"In-Place (Stay Put)", "Teleport (Hayfield Center)"},
        Multi = false,
        Default = 1,
    }):OnChanged(function(val)
        HubState.FarmMode = string.find(val, "In-Place") and "In-Place" or "Teleport"
        addLog("info", "Farm Mode set to: " .. HubState.FarmMode)
    end)

    TabFarm:AddToggle("AutoSell", {Title = "Auto Sell (Full Bag)", Default = HubState.AutoSell}):OnChanged(function(val)
        HubState.AutoSell = val
    end)

    TabFarm:AddDropdown("SellMethodDrop", {
        Title = "Sell Execution Method",
        Values = {"Remote (No Teleport)", "Teleport (To Sell Cow)"},
        Multi = false,
        Default = 1,
    }):OnChanged(function(val)
        HubState.SellMethod = string.find(val, "Remote") and "Remote" or "Teleport"
        addLog("info", "Sell Method: " .. HubState.SellMethod)
    end)

    TabFarm:AddToggle("AutoGems", {Title = "Auto Collect Nearby Gems", Default = HubState.AutoCollectGems}):OnChanged(function(val)
        HubState.AutoCollectGems = val
    end)

    TabFarm:AddToggle("AutoDrone", {Title = "Auto Deploy Drone", Default = HubState.AutoDeployDrone}):OnChanged(function(val)
        HubState.AutoDeployDrone = val
    end)

    TabFarm:AddToggle("AutoWinNeedle", {Title = "Auto Win Needle (TP & Hand-In)", Default = HubState.AutoWinNeedle}):OnChanged(function(val)
        HubState.AutoWinNeedle = val
        addLog("info", "Auto Win Needle: " .. tostring(val))
    end)

    TabFarm:AddButton({
        Title = "Instant Sell Hay Now",
        Description = "Manually triggers SellHay remote immediately",
        Callback = function()
            if Remotes.SellHay then
                Remotes.SellHay:FireServer()
                addLog("info", "Fired SellHay remote")
            end
        end
    })

    TabFarm:AddButton({
        Title = "Skip Cutscene & Tutorial",
        Callback = function()
            if Remotes.IntroCutsceneFinished then Remotes.IntroCutsceneFinished:FireServer() end
            if Remotes.TutorialCompleted then Remotes.TutorialCompleted:FireServer() end
            addLog("info", "Skipped cutscene and tutorial")
        end
    })

    -- TAB 2: Player Mods
    local TabPlayer = Window:AddTab({Title = "Player", Icon = "user"})

    TabPlayer:AddToggle("FreeMouseToggle", {Title = "Free Mouse Cursor [LeftAlt / Insert]", Default = true}):OnChanged(function(val)
        HubState.FreeMouse = val
    end)

    TabPlayer:AddToggle("UnlockCamToggle", {Title = "Unlock 3rd Person Zoom", Default = true}):OnChanged(function(val)
        HubState.UnlockCamera = val
        if not val then LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson end
    end)

    TabPlayer:AddToggle("SpeedToggle", {Title = "Enable Speed Modifier", Default = false}):OnChanged(function(val)
        HubState.WalkSpeedEnabled = val
    end)

    TabPlayer:AddSlider("WalkSpeed", {
        Title = "Walk Speed",
        Default = 16,
        Min = 16,
        Max = 250,
        Rounding = 0,
        Callback = function(val) HubState.WalkSpeed = val end
    })

    TabPlayer:AddToggle("FlyToggle", {Title = "Fly (WASD + Space/Shift)", Default = false}):OnChanged(function(val)
        HubState.FlyEnabled = val
        toggleFly(val)
    end)

    TabPlayer:AddSlider("FlySpeed", {
        Title = "Fly Speed",
        Default = 80,
        Min = 20,
        Max = 300,
        Rounding = 0,
        Callback = function(val) HubState.FlySpeed = val end
    })

    TabPlayer:AddToggle("NoclipToggle", {Title = "Noclip", Default = false}):OnChanged(function(val)
        HubState.NoclipEnabled = val
    end)

    TabPlayer:AddToggle("InfJump", {Title = "Infinite Jump", Default = false}):OnChanged(function(val)
        HubState.InfiniteJump = val
    end)

    -- TAB 3: Teleports
    local TabTP = Window:AddTab({Title = "Teleports", Icon = "map-pin"})

    TabTP:AddButton({
        Title = "Teleport to Hayfield",
        Callback = function() teleportTo(Landmarks.HayCenter) end
    })

    TabTP:AddButton({
        Title = "Teleport to Sell Cow",
        Callback = function() teleportTo(Landmarks.SellCow) end
    })

    TabTP:AddButton({
        Title = "Teleport to Farmer NPC",
        Callback = function() teleportTo(Landmarks.FarmerNPC) end
    })

    TabTP:AddButton({
        Title = "Teleport to The Needle",
        Callback = function()
            if Landmarks.NeedleCFrame then
                teleportTo(Landmarks.NeedleCFrame)
            else
                addLog("warn", "Needle position not yet detected")
            end
        end
    })

    -- TAB 4: Lobby Automation
    local TabAuto = Window:AddTab({Title = "Lobby Auto", Icon = "zap"})

    TabAuto:AddParagraph({
        Title = "Lobby Systems Info",
        Content = IS_LOBBY and "You are in the Lobby. All functions below are available." or "Notice: You are currently in a Match. Codes, Chests and Class Roll require the Lobby."
    })

    TabAuto:AddButton({
        Title = "Redeem All Promo Codes",
        Description = "Redeems all known game codes (Lobby Only)",
        Callback = function() redeemAllCodes() end
    })

    TabAuto:AddButton({
        Title = "Equip Cow Pet (Highest Capacity: 120)",
        Callback = function()
            if Remotes.EquipPet then Remotes.EquipPet:InvokeServer("Cow") end
        end
    })

    TabAuto:AddButton({
        Title = "Open Alien Chest",
        Callback = function()
            if Remotes.OpenChest then Remotes.OpenChest:InvokeServer() end
        end
    })

    TabAuto:AddDropdown("TargetClassDrop", {
        Title = "Target Class",
        Values = {
            "Starter", "Pack Mule", "Hay Merchant", "Forkmaster",
            "Demolitionist", "Prospector", "Drone Specialist", "Ultimate Farmer"
        },
        Multi = false,
        Default = 8,
    }):OnChanged(function(val) HubState.TargetClass = val end)

    TabAuto:AddToggle("RollToggle", {Title = "Auto Roll for Class (Costs 40 Gems)", Default = false}):OnChanged(function(val)
        HubState.AutoRollClass = val
        if val then autoRollClassLoop() end
    end)

    -- TAB 5: ESP
    local TabESP = Window:AddTab({Title = "ESP & Visuals", Icon = "eye"})

    TabESP:AddToggle("NeedleESP", {Title = "Needle ESP (Yellow)", Default = true}):OnChanged(function(val)
        HubState.NeedleESP = val
    end)

    TabESP:AddToggle("SellESP", {Title = "Sell Cow ESP (Cyan)", Default = true}):OnChanged(function(val)
        HubState.SellESP = val
    end)

    TabESP:AddToggle("GemESP", {Title = "Gem ESP (Green)", Default = true}):OnChanged(function(val)
        HubState.GemESP = val
    end)

    TabESP:AddToggle("PlayerESP", {Title = "Player ESP", Default = false}):OnChanged(function(val)
        HubState.PlayerESP = val
    end)

    -- TAB 6: Console
    local TabCon = Window:AddTab({Title = "Console", Icon = "terminal"})

    local logParagraph = TabCon:AddParagraph({
        Title = "Live Event Log",
        Content = "Initializing..."
    })

    task.spawn(function()
        while true do
            task.wait(1.5)
            local recent = {}
            local count = #LogEntries
            local startIndex = math.max(1, count - 15)
            for i = startIndex, count do table.insert(recent, LogEntries[i]) end
            logParagraph:SetDesc(table.concat(recent, "\n"))
        end
    end)

    TabCon:AddButton({
        Title = "Clear Event Log",
        Callback = function()
            table.clear(LogEntries)
            logParagraph:SetDesc("Logs cleared.")
        end
    })

    Window:SelectTab(1)
    addLog("info", "Fluent UI ready")
end

-- SECTION 10: INITIALIZATION
task.spawn(function()
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = 250
        LocalPlayer.CameraMinZoomDistance = 0.5
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
    initializeFluentUI()
end)
