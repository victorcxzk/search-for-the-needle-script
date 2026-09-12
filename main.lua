--[[
    SEARCH FOR THE NEEDLE - ULTIMATE AUTOMATION HUB
    Engineered via Forensic Dump Analysis
    Compatibility: Project Real, Solara, Wave, Synapse Z, MacSploit, etc.
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

-- Safe LocalPlayer fetch with timeout
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local startClock = os.clock()
    while not LocalPlayer and (os.clock() - startClock) < 10 do
        task.wait(0.2)
        LocalPlayer = Players.LocalPlayer
    end
end

if not LocalPlayer then
    warn("[Hub Error]: Failed to locate LocalPlayer within 10s.")
    return
end

-- SECTION 2: GAME CONTEXT DETECTION
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
    GAME_MODE_NAME = "Farmhouse (Gameplay)"
elseif CURRENT_PLACE_ID == BASEMENT_PLACE_ID then
    GAME_MODE_NAME = "Basement (Gameplay)"
else
    GAME_MODE_NAME = "Place " .. tostring(CURRENT_PLACE_ID)
end

-- SECTION 3: LOGGING SYSTEM
local LogEntries = {}
local MAX_LOGS = 60

local function addLog(level, message)
    local timestamp = os.date("%H:%M:%S")
    local formatted = string.format("[%s] [%s] %s", timestamp, string.upper(level), tostring(message))
    table.insert(LogEntries, formatted)
    if #LogEntries > MAX_LOGS then
        table.remove(LogEntries, 1)
    end
    print("[NeedleHub] " .. formatted)
end

addLog("info", "Starting Hub on " .. GAME_MODE_NAME)

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
            hrp.CFrame = CFrame.new(targetCFrame + Vector3.new(0, 3, 0))
        elseif typeof(targetCFrame) == "CFrame" then
            hrp.CFrame = targetCFrame + Vector3.new(0, 3, 0)
        end
        return true
    end
    return false
end

-- SECTION 5: REMOTE REPOSITORIES (FORENSIC DUMP BINDINGS)
local Remotes = {
    -- Gameplay Remotes (under NeedleHaystack)
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
    -- Bind Gameplay remotes
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

    -- Bind Lobby remotes
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

-- SECTION 6: CLIENT DATA READER
local ClientData = nil
pcall(function()
    local sharedServices = ReplicatedStorage:FindFirstChild("Shared")
    if sharedServices then
        local services = sharedServices:FindFirstChild("Services")
        if services and services:FindFirstChild("Data") then
            local dataMod = require(services.Data)
            if dataMod and dataMod.client then
                ClientData = dataMod.client
            end
        end
    end
end)

local function getPlayerStat(statName)
    if ClientData and ClientData[statName] then
        local ok, val = pcall(function() return ClientData[statName]() end)
        if ok then return val end
    end
    local attr = LocalPlayer:GetAttribute(statName)
    if attr ~= nil then return attr end
    return 0
end

-- SECTION 7: WORKSPACE SCANNER & LANDMARKS
local LandmarkPositions = {
    SellZone = nil,
    HayCenter = nil,
    FarmerNPC = nil,
    Needle = nil,
}

local function scanLandmarks()
    -- Find Farmer NPC
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Model") and string.lower(desc.Name) == "farmer" then
            local root = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChildWhichIsA("BasePart")
            if root then
                LandmarkPositions.FarmerNPC = root.CFrame
                break
            end
        end
    end

    -- Find Sell Zone / Hand-in Point
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("BasePart") then
            local lowerName = string.lower(desc.Name)
            if string.find(lowerName, "sell") or string.find(lowerName, "deposit") or string.find(lowerName, "dropoff") then
                LandmarkPositions.SellZone = desc.CFrame
                break
            end
        end
    end

    -- If sell zone not found by name, scan for touch transmitters or nearby farmer
    if not LandmarkPositions.SellZone and LandmarkPositions.FarmerNPC then
        LandmarkPositions.SellZone = LandmarkPositions.FarmerNPC + Vector3.new(0, 0, 5)
    end

    -- Find Haystack / Hay Pile
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Model") or desc:IsA("BasePart") then
            local lowerName = string.lower(desc.Name)
            if string.find(lowerName, "haystack") or string.find(lowerName, "haypile") or string.find(lowerName, "hay_pile") then
                if desc:IsA("Model") then
                    local primary = desc.PrimaryPart or desc:FindFirstChildWhichIsA("BasePart")
                    if primary then LandmarkPositions.HayCenter = primary.CFrame end
                else
                    LandmarkPositions.HayCenter = desc.CFrame
                end
                break
            end
        end
    end

    -- Find Needle
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("BasePart") and string.find(string.lower(desc.Name), "needle") then
            LandmarkPositions.Needle = desc.CFrame
            break
        end
    end
end

scanLandmarks()

-- Dynamic landmark updates via events
if Remotes.NeedleTargetChanged then
    Remotes.NeedleTargetChanged.OnClientEvent:Connect(function(targetCFrame)
        if typeof(targetCFrame) == "CFrame" then
            LandmarkPositions.Needle = targetCFrame
            addLog("info", "Needle position updated by server event")
        end
    end)
end

if Remotes.NeedleFound then
    Remotes.NeedleFound.OnClientEvent:Connect(function(...)
        addLog("info", "Needle found event received from server")
    end)
end

-- SECTION 8: FEATURE CONTROLLERS

-- Global State Flags
local HubState = {
    AutoFarmHay = false,
    AutoSell = true,
    AutoCollectGems = false,
    AutoDeployDrone = false,
    AutoFindNeedle = false,
    WalkSpeed = 16,
    WalkSpeedEnabled = false,
    JumpHeight = 7.2,
    JumpHeightEnabled = false,
    FlyEnabled = false,
    FlySpeed = 80,
    NoclipEnabled = false,
    InfiniteJump = false,
    NeedleESP = false,
    GemESP = false,
    PlayerESP = false,
    SellESP = false,
    AutoRollClass = false,
    TargetClass = "Ultimate Farmer",
    FarmDelay = 0.12,
    FreeMouse = true,
    UnlockCamera = true,
}

-- 8.1 AUTO-FARM STATE MACHINE
local FarmState = "IDLE"
local currentHayInBag = 0
local maxHayCapacity = 30

-- Keep track of capacity via attributes
LocalPlayer:GetAttributeChangedSignal("HayCapacity"):Connect(function()
    local cap = LocalPlayer:GetAttribute("HayCapacity")
    if cap and type(cap) == "number" then maxHayCapacity = cap end
end)

LocalPlayer:GetAttributeChangedSignal("HayCount"):Connect(function()
    local count = LocalPlayer:GetAttribute("HayCount")
    if count and type(count) == "number" then currentHayInBag = count end
end)

if Remotes.HaySold then
    Remotes.HaySold.OnClientEvent:Connect(function(...)
        currentHayInBag = 0
        addLog("info", "Hay sold confirmation received")
    end)
end

task.spawn(function()
    while true do
        task.wait(HubState.FarmDelay)
        if HubState.AutoFarmHay and IS_GAMEPLAY then
            local hrp = getHRP()
            if hrp then
                -- Check bag capacity
                local isBagFull = (currentHayInBag >= maxHayCapacity and maxHayCapacity > 0)

                if isBagFull and HubState.AutoSell then
                    FarmState = "SELLING"
                    if LandmarkPositions.SellZone and Remotes.SellHay then
                        local returnPos = hrp.CFrame
                        teleportTo(LandmarkPositions.SellZone)
                        task.wait(0.3)
                        pcall(function()
                            Remotes.SellHay:FireServer()
                        end)
                        task.wait(0.5)
                        currentHayInBag = 0
                        -- Return to hay field
                        teleportTo(returnPos)
                    else
                        pcall(function()
                            if Remotes.SellHay then Remotes.SellHay:FireServer() end
                        end)
                    end
                    FarmState = "COLLECTING"
                else
                    FarmState = "COLLECTING"
                    -- Position check: if too far from hay, move closer if hay center is known
                    if LandmarkPositions.HayCenter then
                        local dist = (hrp.Position - LandmarkPositions.HayCenter.Position).Magnitude
                        if dist > 45 then
                            teleportTo(LandmarkPositions.HayCenter)
                            task.wait(0.2)
                        end
                    end

                    -- Fire PickHay remote at current position
                    if Remotes.PickHay then
                        pcall(function()
                            Remotes.PickHay:FireServer(hrp.Position)
                        end)
                        currentHayInBag = currentHayInBag + 1
                    end

                    -- Also pick dropped hay if any
                    if Remotes.PickDroppedHay then
                        pcall(function()
                            Remotes.PickDroppedHay:FireServer()
                        end)
                    end
                end
            end
        else
            FarmState = "IDLE"
        end
    end
end)

-- 8.2 AUTO-DEPLOY DRONE
task.spawn(function()
    while true do
        task.wait(5)
        if HubState.AutoDeployDrone and IS_GAMEPLAY and Remotes.DeployDrone then
            pcall(function()
                Remotes.DeployDrone:FireServer()
            end)
        end
    end
end)

-- 8.3 AUTO-COLLECT GEMS
local function scanAndCollectGems()
    if not Remotes.CollectGem then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "gem") then
            local hrp = getHRP()
            if hrp then
                local dist = (hrp.Position - obj.Position).Magnitude
                if dist <= 30 then
                    pcall(function()
                        Remotes.CollectGem:FireServer(obj)
                    end)
                end
            end
        end
    end
end

if Remotes.GemSpawned then
    Remotes.GemSpawned.OnClientEvent:Connect(function(gemObj)
        if HubState.AutoCollectGems and Remotes.CollectGem then
            pcall(function()
                Remotes.CollectGem:FireServer(gemObj)
            end)
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(1.5)
        if HubState.AutoCollectGems and IS_GAMEPLAY then
            scanAndCollectGems()
        end
    end
end)

-- 8.4 AUTO-FIND NEEDLE & HAND IN
task.spawn(function()
    while true do
        task.wait(1)
        if HubState.AutoFindNeedle and IS_GAMEPLAY then
            -- Scan workspace for needle part
            local needlePart = nil
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "needle") then
                    needlePart = obj
                    LandmarkPositions.Needle = obj.CFrame
                    break
                end
            end

            if needlePart then
                addLog("info", "Needle located in workspace! Teleporting...")
                teleportTo(needlePart.CFrame)
                task.wait(0.3)
                if Remotes.NeedleHandIn then
                    pcall(function()
                        Remotes.NeedleHandIn:FireServer()
                    end)
                    addLog("info", "Fired NeedleHandIn remote")
                end
            end
        end
    end
end)

-- 8.5 PLAYER MODIFICATIONS (Speed, Jump, Fly, Noclip, Infinite Jump)
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
        if flyBodyVelocity then
            flyBodyVelocity:Destroy()
            flyBodyVelocity = nil
        end
        if flyBodyGyro then
            flyBodyGyro:Destroy()
            flyBodyGyro = nil
        end
    end
end

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")

    -- Unlock 3rd Person Camera & Zoom Limits
    if HubState.UnlockCamera then
        if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
        end
        if LocalPlayer.CameraMaxZoomDistance < 100 then
            LocalPlayer.CameraMaxZoomDistance = 200
            LocalPlayer.CameraMinZoomDistance = 0.5
        end
    end

    -- Free Mouse Cursor Override (Allows clicking UI in 1st person games)
    if HubState.FreeMouse then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end

    -- Speed modifier
    if hum and HubState.WalkSpeedEnabled then
        hum.WalkSpeed = HubState.WalkSpeed
    end

    -- Jump modifier
    if hum and HubState.JumpHeightEnabled then
        hum.JumpHeight = HubState.JumpHeight
    end

    -- Fly movement
    if HubState.FlyEnabled and hrp and flyBodyVelocity and flyBodyGyro then
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.new(0, 0, 0)

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end

        if moveDir.Magnitude > 0 then
            flyBodyVelocity.Velocity = moveDir.Unit * HubState.FlySpeed
        else
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
        flyBodyGyro.CFrame = cam.CFrame
    end
end)

-- Key listener to quickly toggle Free Mouse (LeftAlt, RightControl, or Insert)
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.Insert then
        HubState.FreeMouse = not HubState.FreeMouse
        addLog("info", "Free Mouse Cursor toggled: " .. (HubState.FreeMouse and "UNLOCKED" or "LOCKED"))
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
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- 8.6 ESP SYSTEM (Needle, Gems, Players, Sell Zone)
local ESPFolders = {
    Needle = Instance.new("Folder"),
    Gems = Instance.new("Folder"),
    Players = Instance.new("Folder"),
    Sell = Instance.new("Folder"),
}

for name, folder in pairs(ESPFolders) do
    folder.Name = "ESP_" .. name
    pcall(function()
        folder.Parent = CoreGui or workspace
    end)
    if not folder.Parent then
        folder.Parent = workspace
    end
end

local function clearESPFolder(folder)
    for _, child in ipairs(folder:GetChildren()) do
        child:Destroy()
    end
end

local function createBillboard(adornPart, text, color, parentFolder)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESPBillboard"
    bb.Adornee = adornPart
    bb.Size = UDim2.new(0, 160, 0, 30)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = parentFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.2
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Parent = bb

    return bb
end

task.spawn(function()
    while true do
        task.wait(1)
        -- Needle ESP
        clearESPFolder(ESPFolders.Needle)
        if HubState.NeedleESP and LandmarkPositions.Needle then
            -- Find actual needle part
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc:IsA("BasePart") and string.find(string.lower(desc.Name), "needle") then
                    createBillboard(desc, "NEEDLE", Color3.fromRGB(255, 230, 0), ESPFolders.Needle)
                    break
                end
            end
        end

        -- Sell Zone ESP
        clearESPFolder(ESPFolders.Sell)
        if HubState.SellESP and LandmarkPositions.SellZone then
            local part = Instance.new("Part")
            part.Size = Vector3.new(4, 1, 4)
            part.CFrame = LandmarkPositions.SellZone
            part.Transparency = 1
            part.Anchored = true
            part.CanCollide = false
            part.Parent = ESPFolders.Sell
            createBillboard(part, "SELL ZONE", Color3.fromRGB(50, 200, 255), ESPFolders.Sell)
        end

        -- Player ESP
        clearESPFolder(ESPFolders.Players)
        if HubState.PlayerESP then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local myHRP = getHRP()
                        local dist = myHRP and math.floor((myHRP.Position - hrp.Position).Magnitude) or 0
                        createBillboard(hrp, p.DisplayName .. " [" .. dist .. "m]", Color3.fromRGB(255, 255, 255), ESPFolders.Players)
                    end
                end
            end
        end

        -- Gem ESP
        clearESPFolder(ESPFolders.Gems)
        if HubState.GemESP then
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc:IsA("BasePart") and string.find(string.lower(desc.Name), "gem") then
                    createBillboard(desc, "GEM", Color3.fromRGB(50, 255, 100), ESPFolders.Gems)
                end
            end
        end
    end
end)

-- 8.7 LOBBY AUTOMATION (Codes, Class Rolls, Pets, Chests)
local KNOWN_CODES = {
    "Launch", "Release", "Update", "1KLikes", "5KLikes",
    "10KLikes", "100KVisits", "GEMS", "NEEDLE", "HAY"
}

local function redeemAllCodes(customCode)
    if not Remotes.RedeemCode then
        addLog("warn", "RedeemCode remote not available in this place")
        return
    end

    local list = {}
    for _, c in ipairs(KNOWN_CODES) do table.insert(list, c) end
    if customCode and customCode ~= "" then table.insert(list, customCode) end

    task.spawn(function()
        for _, code in ipairs(list) do
            pcall(function()
                local res = Remotes.RedeemCode:InvokeServer(code)
                addLog("info", "Redeemed code [" .. code .. "]: " .. tostring(res))
            end)
            task.wait(0.5)
        end
    end)
end

local function autoRollClassLoop()
    task.spawn(function()
        while HubState.AutoRollClass do
            if not Remotes.RollClass then
                addLog("warn", "RollClass remote not available in this place")
                break
            end

            local ok, result = pcall(function()
                return Remotes.RollClass:InvokeServer()
            end)

            if ok and result then
                addLog("info", "Rolled class: " .. tostring(result))
                if tostring(result) == HubState.TargetClass then
                    addLog("info", "Target class obtained: " .. HubState.TargetClass)
                    HubState.AutoRollClass = false
                    break
                end
            else
                addLog("warn", "Roll failed (not enough gems or error)")
                task.wait(2)
            end
            task.wait(0.8)
        end
    end)
end

-- SECTION 9: USER INTERFACE (FLUENT + NATIVE FALLBACK)
local function buildNativeUI()
    addLog("info", "Loading Native Fallback UI...")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NeedleHubNative"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

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
    titleLabel.Text = "Search For The Needle - Automation Hub [" .. GAME_MODE_NAME .. "]"
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
    closeBtn.MouseButton1Click:Connect(function()
        screenGui.Enabled = not screenGui.Enabled
    end)

    -- Sidebar for Tabs
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
        sf.CanvasSize = UDim2.fromOffset(0, 600)
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

    local tabs = {"AutoFarm", "Player", "Teleport", "Automation", "ESP", "Console"}
    for _, tName in ipairs(tabs) do
        createTabContent(tName)
    end

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

        btn.MouseButton1Click:Connect(function()
            switchTab(tName)
        end)
    end

    -- UI Component Helpers
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
        addLog("info", "AutoFarmHay set to " .. tostring(val))
    end)
    addNativeToggle(farmTab, "Auto Sell (Full Bag)", HubState.AutoSell, function(val)
        HubState.AutoSell = val
    end)
    addNativeToggle(farmTab, "Auto Collect Gems", HubState.AutoCollectGems, function(val)
        HubState.AutoCollectGems = val
    end)
    addNativeToggle(farmTab, "Auto Deploy Drone", HubState.AutoDeployDrone, function(val)
        HubState.AutoDeployDrone = val
    end)
    addNativeToggle(farmTab, "Auto Locate Needle", HubState.AutoFindNeedle, function(val)
        HubState.AutoFindNeedle = val
    end)
    addNativeButton(farmTab, "Skip Intro & Tutorial", function()
        if Remotes.IntroCutsceneFinished then Remotes.IntroCutsceneFinished:FireServer() end
        if Remotes.TutorialCompleted then Remotes.TutorialCompleted:FireServer() end
        addLog("info", "Fired Intro & Tutorial skips")
    end)
    addNativeButton(farmTab, "Return To Lobby", function()
        if Remotes.ReturnToLobby then Remotes.ReturnToLobby:FireServer() end
    end)

    -- Tab 2: Player
    local playerTab = tabContainers.Player
    addNativeToggle(playerTab, "Free Mouse Cursor [LeftAlt]", HubState.FreeMouse, function(val)
        HubState.FreeMouse = val
    end)
    addNativeToggle(playerTab, "Unlock 3rd Person Zoom", HubState.UnlockCamera, function(val)
        HubState.UnlockCamera = val
        if not val then
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        end
    end)
    addNativeToggle(playerTab, "Enable Speed Modifier", HubState.WalkSpeedEnabled, function(val)
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
    addNativeButton(playerTab, "Speed Preset (50)", function()
        HubState.WalkSpeed = 50
        HubState.WalkSpeedEnabled = true
    end)
    addNativeButton(playerTab, "Speed Reset (16)", function()
        HubState.WalkSpeed = 16
        HubState.WalkSpeedEnabled = false
        local hum = getHumanoid()
        if hum then hum.WalkSpeed = 16 end
    end)

    -- Tab 3: Teleport
    local tpTab = tabContainers.Teleport
    addNativeButton(tpTab, "Teleport to Hay Pile", function()
        if LandmarkPositions.HayCenter then teleportTo(LandmarkPositions.HayCenter) end
    end)
    addNativeButton(tpTab, "Teleport to Sell Zone", function()
        if LandmarkPositions.SellZone then teleportTo(LandmarkPositions.SellZone) end
    end)
    addNativeButton(tpTab, "Teleport to Farmer NPC", function()
        if LandmarkPositions.FarmerNPC then teleportTo(LandmarkPositions.FarmerNPC) end
    end)
    addNativeButton(tpTab, "Teleport to Needle", function()
        if LandmarkPositions.Needle then
            teleportTo(LandmarkPositions.Needle)
        else
            addLog("warn", "Needle location not yet found")
        end
    end)

    -- Tab 4: Automation
    local autoTab = tabContainers.Automation
    addNativeButton(autoTab, "Redeem All Codes", function()
        redeemAllCodes()
    end)
    addNativeButton(autoTab, "Equip Cow Pet", function()
        if Remotes.EquipPet then Remotes.EquipPet:InvokeServer("Cow") end
    end)
    addNativeButton(autoTab, "Equip Chicken Pet", function()
        if Remotes.EquipPet then Remotes.EquipPet:InvokeServer("Chicken") end
    end)
    addNativeButton(autoTab, "Open Event Chest", function()
        if Remotes.OpenChest then Remotes.OpenChest:InvokeServer() end
    end)
    addNativeToggle(autoTab, "Auto Roll Class", HubState.AutoRollClass, function(val)
        HubState.AutoRollClass = val
        if val then autoRollClassLoop() end
    end)

    -- Tab 5: ESP
    local espTab = tabContainers.ESP
    addNativeToggle(espTab, "Needle ESP", HubState.NeedleESP, function(val) HubState.NeedleESP = val end)
    addNativeToggle(espTab, "Gem ESP", HubState.GemESP, function(val) HubState.GemESP = val end)
    addNativeToggle(espTab, "Player ESP", HubState.PlayerESP, function(val) HubState.PlayerESP = val end)
    addNativeToggle(espTab, "Sell Zone ESP", HubState.SellESP, function(val) HubState.SellESP = val end)

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
            local startIndex = math.max(1, count - 12)
            for i = startIndex, count do
                table.insert(recent, LogEntries[i])
            end
            logBox.Text = table.concat(recent, "\n")
        end
    end)

    addNativeButton(conTab, "Clear Logs", function()
        table.clear(LogEntries)
        logBox.Text = ""
    end)

    switchTab("AutoFarm")
    addLog("info", "Native Fallback UI successfully initialized")
end

-- Try loading Fluent UI first
local function initializeFluentUI()
    local Fluent = nil
    local loadSuccess, _ = pcall(function()
        Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Fluent.luau"))()
    end)

    if not loadSuccess or not Fluent then
        addLog("warn", "Fluent UI failed to load. Initiating Native Fallback.")
        buildNativeUI()
        return
    end

    local Window = Fluent:CreateWindow({
        Title = "Search For The Needle",
        SubTitle = "Native Hub [" .. GAME_MODE_NAME .. "]",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightControl
    })

    -- TAB 1: AutoFarm
    local TabFarm = Window:AddTab({Title = "Auto Farm", Icon = "bot"})

    TabFarm:AddToggle("AutoFarmHay", {Title = "Auto Collect Hay", Default = HubState.AutoFarmHay}):OnChanged(function(val)
        HubState.AutoFarmHay = val
        addLog("info", "Auto Farm Hay: " .. tostring(val))
    end)

    TabFarm:AddToggle("AutoSell", {Title = "Auto Sell on Bag Full", Default = HubState.AutoSell}):OnChanged(function(val)
        HubState.AutoSell = val
    end)

    TabFarm:AddToggle("AutoGems", {Title = "Auto Collect Gems", Default = HubState.AutoCollectGems}):OnChanged(function(val)
        HubState.AutoCollectGems = val
    end)

    TabFarm:AddToggle("AutoDrone", {Title = "Auto Deploy Drone", Default = HubState.AutoDeployDrone}):OnChanged(function(val)
        HubState.AutoDeployDrone = val
    end)

    TabFarm:AddToggle("AutoNeedle", {Title = "Auto Locate & Hand-in Needle", Default = HubState.AutoFindNeedle}):OnChanged(function(val)
        HubState.AutoFindNeedle = val
    end)

    TabFarm:AddButton({
        Title = "Skip Cutscene & Tutorial",
        Description = "Instantly skips game intro",
        Callback = function()
            if Remotes.IntroCutsceneFinished then Remotes.IntroCutsceneFinished:FireServer() end
            if Remotes.TutorialCompleted then Remotes.TutorialCompleted:FireServer() end
            addLog("info", "Skipped cutscene and tutorial")
        end
    })

    TabFarm:AddButton({
        Title = "Return to Lobby",
        Description = "Teleport back to the game lobby",
        Callback = function()
            if Remotes.ReturnToLobby then Remotes.ReturnToLobby:FireServer() end
        end
    })

    -- TAB 2: Player
    local TabPlayer = Window:AddTab({Title = "Player", Icon = "user"})

    TabPlayer:AddToggle("FreeMouseToggle", {Title = "Free Mouse Cursor [LeftAlt]", Default = true}):OnChanged(function(val)
        HubState.FreeMouse = val
    end)

    TabPlayer:AddToggle("UnlockCamToggle", {Title = "Unlock 3rd Person Zoom", Default = true}):OnChanged(function(val)
        HubState.UnlockCamera = val
        if not val then
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        end
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
        Callback = function(val)
            HubState.WalkSpeed = val
        end
    })

    TabPlayer:AddToggle("JumpToggle", {Title = "Enable Jump Modifier", Default = false}):OnChanged(function(val)
        HubState.JumpHeightEnabled = val
    end)

    TabPlayer:AddSlider("JumpHeight", {
        Title = "Jump Height",
        Default = 7.2,
        Min = 7.2,
        Max = 150,
        Rounding = 1,
        Callback = function(val)
            HubState.JumpHeight = val
        end
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
        Callback = function(val)
            HubState.FlySpeed = val
        end
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
        Title = "Teleport to Hay Pile",
        Callback = function()
            if LandmarkPositions.HayCenter then teleportTo(LandmarkPositions.HayCenter) end
        end
    })

    TabTP:AddButton({
        Title = "Teleport to Sell Zone",
        Callback = function()
            if LandmarkPositions.SellZone then teleportTo(LandmarkPositions.SellZone) end
        end
    })

    TabTP:AddButton({
        Title = "Teleport to Farmer NPC",
        Callback = function()
            if LandmarkPositions.FarmerNPC then teleportTo(LandmarkPositions.FarmerNPC) end
        end
    })

    TabTP:AddButton({
        Title = "Teleport to Needle",
        Callback = function()
            if LandmarkPositions.Needle then
                teleportTo(LandmarkPositions.Needle)
            else
                addLog("warn", "Needle not found yet")
            end
        end
    })

    -- TAB 4: Automation
    local TabAuto = Window:AddTab({Title = "Automation", Icon = "zap"})

    TabAuto:AddButton({
        Title = "Redeem All Promo Codes",
        Description = "Redeems all known game codes",
        Callback = function()
            redeemAllCodes()
        end
    })

    TabAuto:AddButton({
        Title = "Equip Cow Pet (Highest Capacity)",
        Callback = function()
            if Remotes.EquipPet then Remotes.EquipPet:InvokeServer("Cow") end
        end
    })

    TabAuto:AddButton({
        Title = "Equip Chicken Pet",
        Callback = function()
            if Remotes.EquipPet then Remotes.EquipPet:InvokeServer("Chicken") end
        end
    })

    TabAuto:AddButton({
        Title = "Open Alien Chest",
        Callback = function()
            if Remotes.OpenChest then Remotes.OpenChest:InvokeServer() end
        end
    })

    TabAuto:AddDropdown("TargetClassDrop", {
        Title = "Target Class to Roll",
        Values = {
            "Starter", "Pack Mule", "Hay Merchant", "Forkmaster",
            "Demolitionist", "Prospector", "Drone Specialist", "Ultimate Farmer"
        },
        Multi = false,
        Default = 8,
    }):OnChanged(function(val)
        HubState.TargetClass = val
    end)

    TabAuto:AddToggle("RollToggle", {Title = "Auto Roll for Target Class", Default = false}):OnChanged(function(val)
        HubState.AutoRollClass = val
        if val then autoRollClassLoop() end
    end)

    -- TAB 5: ESP
    local TabESP = Window:AddTab({Title = "ESP & Visuals", Icon = "eye"})

    TabESP:AddToggle("NeedleESP", {Title = "Needle ESP", Default = false}):OnChanged(function(val)
        HubState.NeedleESP = val
    end)

    TabESP:AddToggle("GemESP", {Title = "Gem ESP", Default = false}):OnChanged(function(val)
        HubState.GemESP = val
    end)

    TabESP:AddToggle("PlayerESP", {Title = "Player ESP", Default = false}):OnChanged(function(val)
        HubState.PlayerESP = val
    end)

    TabESP:AddToggle("SellESP", {Title = "Sell Zone ESP", Default = false}):OnChanged(function(val)
        HubState.SellESP = val
    end)

    -- TAB 6: Console
    local TabCon = Window:AddTab({Title = "Console", Icon = "terminal"})

    local logParagraph = TabCon:AddParagraph({
        Title = "Event Logs",
        Content = "Initializing..."
    })

    task.spawn(function()
        while true do
            task.wait(1.5)
            local recent = {}
            local count = #LogEntries
            local startIndex = math.max(1, count - 15)
            for i = startIndex, count do
                table.insert(recent, LogEntries[i])
            end
            logParagraph:SetDesc(table.concat(recent, "\n"))
        end
    end)

    TabCon:AddButton({
        Title = "Clear Event Logs",
        Callback = function()
            table.clear(LogEntries)
            logParagraph:SetDesc("Logs cleared.")
        end
    })

    Window:SelectTab(1)
    addLog("info", "Fluent UI successfully loaded and rendered")
end

-- SECTION 10: INITIALIZATION
task.spawn(function()
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMaxZoomDistance = 200
        LocalPlayer.CameraMinZoomDistance = 0.5
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
    initializeFluentUI()
end)
