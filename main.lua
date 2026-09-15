--[[
    SEARCH FOR THE NEEDLE - ULTIMATE AUTOMATION HUB v6.25 PRO
    Forensically Engineered from Luau Decompiler Bytecode Dump
    - Exact Multi-Grab Batching using LocalPlayer:GetAttribute("HayGrabCount") & getGrabCandidates
    - Rare / RGB priority via HayMutation and the game's value multipliers
    - Auto Collect Gems via workspace.GemsClient & CollectGem(GemId)
    - Auto-Win Needle via PickHay("Objective"), slot equip, and Farmer hand-in
    - Full Autonomous Sell-Cycle at CollectionService:GetTagged("SellPart")
    - Frosted Graphite UI with viewport-safe dragging, restore, reopen, and resizing
    - Basement Auto Puzzles with server-confirmed actions and optional automatic positioning
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

-- Executor-only registry: a second load must stop the first set of loops.
local RuntimeRegistry = nil
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then RuntimeRegistry = env end
end
if RuntimeRegistry and type(RuntimeRegistry.__NeedleHubRuntime) == "table" then
    local previous = RuntimeRegistry.__NeedleHubRuntime
    if type(previous.unload) == "function" then pcall(previous.unload) end
end
local ThisRuntime = {}
if RuntimeRegistry then RuntimeRegistry.__NeedleHubRuntime = ThisRuntime end
local HadLegacyHubArtifacts = false
for _, parent in ipairs({CoreGui or workspace, LocalPlayer:FindFirstChild("PlayerGui") or workspace, workspace}) do
    if parent then
        for _, name in ipairs({"NeedleHubNative", "NeedleHubFloatingBtn", "NeedleHub_ESP"}) do
            pcall(function()
                local old = parent:FindFirstChild(name)
                if old then HadLegacyHubArtifacts = true; old:Destroy() end
            end)
        end
    end
end

local HubConnections = {}
local HubThreads = {}
local UIConnections = {}
local IsHubLoaded = true
local GlobalScreenGui = nil
local FloatingButtonGui = nil

local function trackUIConnection(connection)
    if connection then
        table.insert(UIConnections, connection)
    end
    return connection
end

local function clearUIConnections()
    for _, connection in ipairs(UIConnections) do
        pcall(function()
            if typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            elseif type(connection) == "table" and connection.Disconnect then
                connection:Disconnect()
            end
        end)
    end
    table.clear(UIConnections)
end

-- SECTION 2: PLACE CONTEXT & CONFIG
local CURRENT_PLACE_ID = game.PlaceId
local LOBBY_PLACE_ID = 77108422251420
local FARMHOUSE_PLACE_ID = 108628039999641
local BASEMENT_PLACE_ID = 83445806734780

local IS_BASEMENT = CURRENT_PLACE_ID == BASEMENT_PLACE_ID
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
local SCRIPT_VERSION = "6.25"
local CurrentContextMode = IS_LOBBY and "Lobby" or "Match"

-- Require game Config if available for exact mathematical rainbow calculations
local HaystackConfig = nil
local HaystackSurface = nil
pcall(function()
    local nh = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if nh and nh:FindFirstChild("Config") then
        HaystackConfig = require(nh.Config)
    end
    if nh and nh:FindFirstChild("Surface") then
        HaystackSurface = require(nh.Surface)
    end
end)

-- Surface is the same client-side depth grid used by the game to render dug
-- craters. It gives us an authoritative local progress value instead of using
-- time spent at a teleport as a proxy for progress.
local function getDigDepthFraction(worldPosition)
    if typeof(worldPosition) ~= "Vector3" or not HaystackSurface
        or type(HaystackSurface.digAt) ~= "function" then
        return nil
    end
    local center = HaystackConfig and HaystackConfig.PILE_CENTER
    local maxDepth = tonumber(HaystackConfig and HaystackConfig.DIG_MAX_DEPTH)
    if typeof(center) ~= "Vector3" or not maxDepth or maxDepth <= 0 then return nil end
    local ok, depth = pcall(HaystackSurface.digAt,
        worldPosition.X - center.X, worldPosition.Z - center.Z)
    if not ok or type(depth) ~= "number" then return nil end
    return math.clamp(depth / maxDepth, 0, 1)
end

local function getHayRoundProgress()
    local folder = ReplicatedStorage and ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if not folder then return nil, nil, nil end
    local remaining = tonumber(folder:GetAttribute("RemainingHay"))
    local total = tonumber(folder:GetAttribute("TotalHay"))
    if not remaining or not total or total <= 0 then return nil, remaining, total end
    return math.clamp(1 - remaining / total, 0, 1), remaining, total
end

local FarmProgressState = {
    localDepth = nil,
    target = "aguardando",
    sector = nil,
    cycle = 1,
}

-- The target strand must not be consumed before its local reveal conditions
-- are satisfied. This state lets every harvesting path protect that HayId.
local NeedleProtection = {
    targetId = nil,
    anchor = nil,
    localActions = 0,
    ready = false,
}

function NeedleProtection.isNear(position, extraRadius)
    if NeedleProtection.ready or not NeedleProtection.anchor or typeof(position) ~= "Vector3" then return false end
    local radius = (tonumber(HaystackConfig and HaystackConfig.NEEDLE_DIG_RADIUS) or 5.5) + (extraRadius or 0)
    local dx, dz = position.X - NeedleProtection.anchor.X, position.Z - NeedleProtection.anchor.Z
    return dx * dx + dz * dz <= radius * radius
end

local GemConfig = nil
pcall(function()
    local nh = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if nh and nh:FindFirstChild("GemConfig") then
        GemConfig = require(nh.GemConfig)
    end
end)

local PermanentUpgradeConfig = nil
pcall(function()
    local shared = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Shared")
    local configs = shared and shared:FindFirstChild("Configs")
    local upgradeModule = configs and configs:FindFirstChild("UpgradeConfig")
    if upgradeModule and upgradeModule:IsA("ModuleScript") then
        PermanentUpgradeConfig = require(upgradeModule)
    end
end)

-- Account data is replicated through Shared.Services.Data, not Player attributes.
-- Keep attribute/leaderstats fallbacks for compatibility with older place versions.
local AccountDataService = nil
local LastAccountDataBindAttempt = 0

local function getAccountDataRoot()
    if AccountDataService then
        local ok, client = pcall(function()
            return AccountDataService.client
        end)
        if ok and client then return client end
    end

    if LastAccountDataBindAttempt > 0 and os.clock() - LastAccountDataBindAttempt < 2 then return nil end
    LastAccountDataBindAttempt = os.clock()

    pcall(function()
        local shared = ReplicatedStorage and ReplicatedStorage:FindFirstChild("Shared")
        local services = shared and shared:FindFirstChild("Services")
        local dataModule = services and services:FindFirstChild("Data")
        if dataModule and dataModule:IsA("ModuleScript") then
            AccountDataService = require(dataModule)
        end
    end)

    if AccountDataService then
        local ok, client = pcall(function()
            return AccountDataService.client
        end)
        if ok then return client end
    end
    return nil
end

local function unwrapReactiveValue(value)
    if value == nil then return nil end
    local valueType = type(value)
    if valueType ~= "table" and valueType ~= "function" then
        return value
    end

    local ok, result = pcall(function()
        return value()
    end)
    if ok and result ~= nil then return result end

    if valueType == "table" then
        local rawValue = rawget(value, "___X")
        if rawValue ~= nil then return rawValue end
    end
    return nil
end

local function getAccountValue(key, fallback)
    local root = getAccountDataRoot()
    if root then
        local snapshot = unwrapReactiveValue(root)
        if type(snapshot) == "table" and snapshot[key] ~= nil then
            return snapshot[key]
        end

        local ok, child = pcall(function()
            return root[key]
        end)
        if ok then
            local value = unwrapReactiveValue(child)
            if value ~= nil then return value end
        end
    end

    local attributeValue = LocalPlayer:GetAttribute(key)
    if attributeValue ~= nil then return attributeValue end

    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local leaderValue = leaderstats and leaderstats:FindFirstChild(key)
    if leaderValue and leaderValue:IsA("ValueBase") then
        return leaderValue.Value
    end
    return fallback
end

local function getGemBalance()
    return math.max(0, math.floor(tonumber(getAccountValue("Gems", 0)) or 0))
end

local function getActiveClass()
    return tostring(getAccountValue("ActiveClass", "Starter") or "Starter")
end

local function formatNumber(value)
    local number = math.floor(tonumber(value) or 0)
    local sign = number < 0 and "-" or ""
    local digits = tostring(math.abs(number))
    local formatted = digits:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return sign .. formatted
end

local function getPermanentUpgradeDefinition(upgradeId)
    if type(PermanentUpgradeConfig) ~= "table" then return nil end
    if type(PermanentUpgradeConfig.getUpgrade) == "function" then
        local ok, definition = pcall(PermanentUpgradeConfig.getUpgrade, upgradeId)
        if ok and type(definition) == "table" then return definition end
    end
    if type(PermanentUpgradeConfig.Upgrades) == "table" then
        for _, definition in pairs(PermanentUpgradeConfig.Upgrades) do
            if type(definition) == "table" and definition.Id == upgradeId then
                return definition
            end
        end
    end
    return nil
end

local function getPermanentUpgradeLevel(upgradeId)
    local replicatedLevel = LocalPlayer:GetAttribute("Upgrade" .. upgradeId)
    if type(replicatedLevel) == "number" then
        return math.max(0, math.floor(replicatedLevel))
    end
    return math.max(0, math.floor(tonumber(getAccountValue(upgradeId, 0)) or 0))
end

local function readUpgradePrice(rawPrice)
    if type(rawPrice) == "number" then return rawPrice end
    if type(rawPrice) == "table" then
        return tonumber(rawPrice.Price or rawPrice.Cost or rawPrice.Amount or rawPrice.Gems)
    end
    return tonumber(rawPrice)
end

local function getPermanentUpgradeState(upgradeId)
    local definition = getPermanentUpgradeDefinition(upgradeId)
    local level = getPermanentUpgradeLevel(upgradeId)
    if not definition then
        return {id = upgradeId, level = level, currentValue = level, maxLevel = nil, nextPrice = nil, nextValue = nil}
    end
    local perLevel = tonumber(definition.ValuePerLevel) or 1
    local prices = type(definition.Prices) == "table" and definition.Prices or {}
    local maxLevel = #prices
    local nextPrice = readUpgradePrice(prices[level + 1])
    return {
        id = upgradeId,
        level = level,
        currentValue = level * perLevel,
        nextValue = nextPrice and ((level + 1) * perLevel) or nil,
        maxLevel = maxLevel > 0 and maxLevel or nil,
        nextPrice = nextPrice,
    }
end

local PermanentUpgradeUi = {
    {id = "ExtraHoldAmount", title = "Capacidade permanente", unit = " espacos"},
    {id = "ExtraTakeAmount", title = "Coleta permanente", unit = " feno por coleta"},
    {id = "GemValue", title = "Valor permanente de gemas", unit = " gemas por coleta"},
    {id = "ExtraHayValuePercentage", title = "Valor permanente do feno", unit = "%"},
}

local function formatPermanentUpgradeState(entry)
    local state = getPermanentUpgradeState(entry.id)
    local levelText = state.maxLevel and string.format("Nivel %d/%d", state.level, state.maxLevel)
        or ("Nivel " .. tostring(state.level))
    local currentText = "+" .. formatNumber(state.currentValue) .. entry.unit
    if state.nextValue and state.nextPrice then
        return string.format("%s | Atual: %s | Proximo: +%s%s por %s gemas",
            levelText, currentText, formatNumber(state.nextValue), entry.unit, formatNumber(state.nextPrice))
    end
    if state.maxLevel and state.level >= state.maxLevel then
        return levelText .. " | Atual: " .. currentText .. " | Nivel maximo"
    end
    return levelText .. " | Atual: " .. currentText .. " | Proximo preco indisponivel"
end

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

addLog("info", "Initialized Hub v" .. SCRIPT_VERSION .. " on " .. GAME_MODE_NAME)
if HadLegacyHubArtifacts then addLog("warn", "Interface antiga removida. Entre novamente na partida uma vez para encerrar loops de versoes anteriores a v6.0.") end

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
    TargetNeedleSlot = nil,
    TargetNeedleGeneration = nil,
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

    -- The static "The Needle" model is decoration, not the live objective.
    local needleFolder = workspace:FindFirstChild("HiddenNeedleClient")
    if needleFolder then
        local p = needleFolder:FindFirstChildWhichIsA("BasePart", true)
        if p then Landmarks.NeedleCFrame = p.CFrame end
    end
end

scanExactLandmarks()

local function cacheNeedleSnapshot(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.needleHayId) ~= "number" then return end
    Landmarks.TargetNeedleHayId = snapshot.needleHayId
    Landmarks.TargetNeedleSlot = nil
    Landmarks.TargetNeedleGeneration = nil
    if type(snapshot.activeIds) ~= "table" or type(snapshot.activeSlots) ~= "table" then return end
    for index, hayId in ipairs(snapshot.activeIds) do
        if hayId == snapshot.needleHayId then
            Landmarks.TargetNeedleSlot = tonumber(snapshot.activeSlots[index])
            if type(snapshot.activeGenerations) == "table" then
                Landmarks.TargetNeedleGeneration = tonumber(snapshot.activeGenerations[index]) or 0
            end
            break
        end
    end
end

if IS_GAMEPLAY and Remotes.GetHayState then
    local snapshotThread = task.spawn(function()
        local ok, snapshot = pcall(function() return Remotes.GetHayState:InvokeServer() end)
        if IsHubLoaded and ok then
            cacheNeedleSnapshot(snapshot)
        end
    end)
    table.insert(HubThreads, snapshotThread)
end

if Remotes.NeedleTargetChanged then
    local conn = Remotes.NeedleTargetChanged.OnClientEvent:Connect(function(targetArg)
        if typeof(targetArg) == "number" then
            Landmarks.TargetNeedleHayId = targetArg
            Landmarks.TargetNeedleSlot = nil
            Landmarks.TargetNeedleGeneration = nil
            addLog("info", "Needle target HayId: " .. tostring(targetArg))
            if Remotes.GetHayState then
                local refreshThread = task.spawn(function()
                    local ok, snapshot = pcall(function() return Remotes.GetHayState:InvokeServer() end)
                    if IsHubLoaded and ok then cacheNeedleSnapshot(snapshot) end
                end)
                table.insert(HubThreads, refreshThread)
            end
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
            addLog("warn", IS_BASEMENT and "Chave encontrada! Resolva os objetivos antes de abrir a saida."
                or "Agulha encontrada! Entregue ao fazendeiro.")
        else
            addLog("info", tostring(finderName) .. (IS_BASEMENT and " encontrou a chave!" or " encontrou a agulha!"))
        end
    end)
    table.insert(HubConnections, conn)
end

local BasementState = {
    folder = IS_BASEMENT and ReplicatedStorage:WaitForChild("Puzzles", 10) or nil,
    snapshot = nil,
    requiredPuzzles = {"ColorPuzzle", "PicturePuzzle", "NumberPuzzle"},
    config = nil,
    automation = {
        active = false,
        status = "Desligado",
        details = {},
        posterTaken = {},
        numberCode = nil,
        attempts = {},
        blockedUntil = {},
        nextActionAt = 0,
        lastSyncAt = 0,
        lastErrorAt = 0,
    },
}
BasementState.remote = BasementState.folder and BasementState.folder:WaitForChild("PuzzleState", 5) or nil
if IS_BASEMENT and BasementState.folder then
    local puzzleConfigModule = BasementState.folder:WaitForChild("PuzzleConfig", 5)
    if puzzleConfigModule and puzzleConfigModule:IsA("ModuleScript") then
        local ok, config = pcall(require, puzzleConfigModule)
        if ok and type(config) == "table" then BasementState.config = config end
    end
    local releaseConfigModule = BasementState.folder:WaitForChild("Chapter2ReleaseConfig", 5)
    if releaseConfigModule and releaseConfigModule:IsA("ModuleScript") then
        local ok, config = pcall(require, releaseConfigModule)
        if ok and type(config) == "table" and type(config.RequiredPuzzles) == "table" then
            BasementState.requiredPuzzles = config.RequiredPuzzles
        end
    end
    if BasementState.remote and BasementState.remote:IsA("RemoteEvent") then
        local conn = BasementState.remote.OnClientEvent:Connect(function(snapshot)
            if type(snapshot) == "table" then BasementState.snapshot = snapshot end
        end)
        table.insert(HubConnections, conn)
        local solvedRemote = BasementState.folder:FindFirstChild("PuzzleSolved")
        if solvedRemote and solvedRemote:IsA("RemoteEvent") then
            local solvedConn = solvedRemote.OnClientEvent:Connect(function(puzzleId, timing)
                local definition = BasementState.config and BasementState.config.Puzzles
                    and BasementState.config.Puzzles[puzzleId]
                if definition and definition.Reward and definition.Reward.Kind == "SlidingDoor" then
                    local animation = type(timing) == "table" and timing or {}
                    local duration = (tonumber(animation.cameraLead) or 1.25)
                        + (tonumber(animation.lampBeat) or 0.75)
                        + (tonumber(animation.slideDuration) or 3.4) + 0.55
                    BasementState.automation.doorReadyAt = os.clock() + duration
                    BasementState.automation.doorPuzzleId = puzzleId
                end
                task.delay(0.15, function()
                    if IsHubLoaded then pcall(function() BasementState.remote:FireServer() end) end
                end)
            end)
            table.insert(HubConnections, solvedConn)
        end
        task.defer(function()
            if IsHubLoaded then pcall(function() BasementState.remote:FireServer() end) end
        end)
    end
    local feedbackRemote = BasementState.folder:FindFirstChild("PuzzleFeedback")
    if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
        table.insert(HubConnections, feedbackRemote.OnClientEvent:Connect(function(puzzleId, kind, index, success, code)
            if puzzleId ~= "NumberPuzzle" then return end
            local automation = BasementState.automation
            if kind == "Poster" then
                if type(index) == "number" then automation.posterTaken[index] = true end
                if type(code) == "string" and code:match("^%d+$") then automation.numberCode = code end
            elseif kind == "Submit" and index == false then
                automation.submitRejectedAt = os.clock()
            end
        end))
    end
end

-- SECTION 7: GLOBAL HUB STATE
local HubState = {
    -- Auto Farm
    AutoFarmHay = false,
    PrioritizeRGB = true,
    BatchMultiGrab = true,
    AutoSell = false,
    AutoCollectGems = false,
    AutoWinNeedle = false,
    AutoDeployDrone = false,
    AutoBuyTools = false,
    AutoBuyUpgrades = false,
    AutoEquipBestTool = false,
    AutoUseTnt = false,
    TntInterval = 0,
    ForcedToolSlot = 0,
    FarmCooldown = 0.35,
    NoTeleportMode = true,

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
    BasementGuideESP = true,
    BasementAutoPuzzles = false,
    BasementPuzzleTeleport = true,

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
    [6] = IS_BASEMENT and "Chave" or "The Needle"
}

local SlotToolIds = {
    [SLOT_HAND] = "Hand",
    [SLOT_TNT] = "Tnt",
    [SLOT_PITCHFORK] = "Pitchfork",
    [SLOT_DRONE] = "Drone",
    [SLOT_VACUUM] = "Vacuum",
    [SLOT_NEEDLE] = "Needle",
}

local ToolOwnershipAttributes = {
    Pitchfork = {"PitchforkOwned"},
    Tnt = {"TntOwned"},
    Drone = {"DroneOwned"},
    Vacuum = {"VacuumOwned"},
    Needle = {"NeedleOwned"},
}

-- Shared state tables keep this chunk below Luau's 200-local register limit.
local ToolRuntime = {
    hotbarSlots = nil,
    lastEquippedSlotLogged = -1,
    lastEquipAttemptAt = 0,
    stopVacuumAutomation = nil,
    tntComboInProgress = false,
    lastAutoTntThrow = 0,
    vacuumAutomationActive = false,
    lastPitchforkDigAt = 0,
}
local function getHotbarSlots()
    if ToolRuntime.hotbarSlots then return ToolRuntime.hotbarSlots end
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if ps then
        local mod = ps:FindFirstChild("HotbarSlots")
        if mod and mod:IsA("ModuleScript") then
            local ok, res = pcall(require, mod)
            if ok and type(res) == "table" then
                ToolRuntime.hotbarSlots = res
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
                ToolRuntime.hotbarSlots = res
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
    if toolName == "Hand" then return true end
    local attributes = ToolOwnershipAttributes[toolName]
    if not attributes then return false end
    for _, attributeName in ipairs(attributes) do
        if LocalPlayer:GetAttribute(attributeName) == true then
            return true
        end
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
    if isToolOwned("Needle") and not IS_BASEMENT then
        return SLOT_NEEDLE, "The Needle"
    end

    -- Manual Override
    if HubState.ForcedToolSlot and HubState.ForcedToolSlot > 0 then
        local forced = HubState.ForcedToolSlot
        local forcedToolId = SlotToolIds[forced]
        if (forced == SLOT_HAND or forced == SLOT_PITCHFORK or forced == SLOT_VACUUM)
            and forcedToolId and isToolOwned(forcedToolId) then
            return forced, ToolNames[forced] or ("Slot " .. tostring(forced))
        end
        HubState.ForcedToolSlot = 0
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

local function getBestHarvestToolSlot()
    local forced = HubState.ForcedToolSlot
    if forced == SLOT_VACUUM and isVacuumReady() then return SLOT_VACUUM end
    if forced == SLOT_PITCHFORK and isToolOwned("Pitchfork") then return SLOT_PITCHFORK end
    if forced == SLOT_HAND then return SLOT_HAND end
    if isVacuumReady() then return SLOT_VACUUM end
    if isToolOwned("Pitchfork") then return SLOT_PITCHFORK end
    return SLOT_HAND
end

local function equipToolSlot(slotIndex, silent)
    if not slotIndex or type(slotIndex) ~= "number" then return false end
    local toolId = SlotToolIds[slotIndex]
    if not toolId or not isToolOwned(toolId) then
        if not silent then
            addLog("warn", (ToolNames[slotIndex] or "Ferramenta") .. " ainda nao foi comprada.")
        end
        return false
    end

    local currentSlot = getCurrentEquippedSlot()
    if currentSlot == slotIndex then return true end
    if os.clock() - ToolRuntime.lastEquipAttemptAt < 0.18 then return false end
    ToolRuntime.lastEquipAttemptAt = os.clock()
    if currentSlot == SLOT_VACUUM and slotIndex ~= SLOT_VACUUM and ToolRuntime.stopVacuumAutomation then
        ToolRuntime.stopVacuumAutomation()
    end

    -- The game's HotbarSlots module owns availability and equipped state.
    local hotbar = getHotbarSlots()
    if hotbar and type(hotbar.setEquipped) == "function" then
        local ok = pcall(function()
            hotbar.setEquipped(slotIndex, true)
        end)
        if ok and getCurrentEquippedSlot() == slotIndex then
            if not silent and ToolRuntime.lastEquippedSlotLogged ~= slotIndex then
                ToolRuntime.lastEquippedSlotLogged = slotIndex
                addLog("info", "Ferramenta equipada: " .. (ToolNames[slotIndex] or ("Slot " .. tostring(slotIndex))))
            end
            return true
        end
        return false
    end

    -- Never synthesize a hotbar key: the locked Vacuum key opens a Robux prompt.
    if not silent then addLog("warn", "HotbarSlots ainda nao esta disponivel; equipar foi adiado.") end
    return false
end

-- Dedicated Autonomous TNT Thrower
local chooseTntTarget
local function solveTntVelocity(origin, target)
    local delta = target - origin
    local gravity = math.max(tonumber(workspace.Gravity) or 196.2, 1)
    local minSpeed = tonumber(HaystackConfig and HaystackConfig.TNT_MIN_THROW_SPEED) or 26
    local maxSpeed = tonumber(HaystackConfig and HaystackConfig.TNT_MAX_THROW_SPEED) or 78
    if delta.Magnitude < 0.05 then return nil end

    local flat = Vector3.new(delta.X, 0, delta.Z)
    local horizontalDistance = flat.Magnitude
    if horizontalDistance < 0.35 then
        -- Auto Farm is usually standing directly above the selected strand.
        -- Throw into the hay instead of manufacturing an upward arc first.
        local directSpeed = math.clamp(delta.Magnitude * 8, minSpeed, maxSpeed * 0.98)
        return delta.Unit * directSpeed
    end

    -- Lowest-angle ballistic solution at near-full legal speed. Of the two
    -- possible arcs this is the flat one, so the stick travels toward the hay
    -- instead of visibly launching upward and dropping back down.
    local speed = math.max(minSpeed, maxSpeed * 0.98)
    local speedSquared = speed * speed
    local discriminant = speedSquared * speedSquared
        - gravity * (gravity * horizontalDistance * horizontalDistance
            + 2 * delta.Y * speedSquared)
    if discriminant < 0 then return nil end
    local tangent = (speedSquared - math.sqrt(discriminant))
        / (gravity * horizontalDistance)
    local horizontalSpeed = speed / math.sqrt(1 + tangent * tangent)
    local verticalSpeed = horizontalSpeed * tangent
    return flat.Unit * horizontalSpeed + Vector3.new(0, verticalSpeed, 0)
end

local function throwTntAt(targetPos)
    if ToolRuntime.tntComboInProgress then return false end
    if not isToolOwned("Tnt") then
        addLog("warn", "TNT is not owned. Purchase it from the Barn shop!")
        return false
    end
    local hrp = getHRP()
    if not hrp then return false end
    local target = targetPos or Landmarks.HayCenter
    if not target then return false end
    local origin = hrp.Position + Vector3.new(0, 2.5, 0)
    if not solveTntVelocity(origin, target) then
        addLog("info", "TNT aguardando feno dentro do alcance real de arremesso.")
        return false
    end

    local tntAction = Remotes.TntAction or (ReplicatedStorage:FindFirstChild("NeedleHaystack") and ReplicatedStorage.NeedleHaystack:FindFirstChild("TntAction"))
    if not tntAction then
        addLog("warn", "TntAction remote not found in game!")
        return false
    end

    ToolRuntime.tntComboInProgress = true
    if ToolRuntime.stopVacuumAutomation then ToolRuntime.stopVacuumAutomation() end
    if not equipToolSlot(SLOT_TNT, true) then
        ToolRuntime.tntComboInProgress = false
        return false
    end
    task.wait(0.06)

    local lightResult = nil
    local acknowledgement = tntAction.OnClientEvent:Connect(function(action)
        if action == "lit" then lightResult = true end
        if action == "denied" then lightResult = false end
    end)
    local sent = pcall(function() tntAction:FireServer("light") end)
    local waitStartedAt = os.clock()
    while sent and lightResult == nil and IsHubLoaded and os.clock() - waitStartedAt < 1.2 do
        task.wait(0.03)
    end
    acknowledgement:Disconnect()
    if lightResult ~= true then
        equipToolSlot(getBestHarvestToolSlot(), true)
        ToolRuntime.tntComboInProgress = false
        ToolRuntime.lastAutoTntThrow = os.clock()
        addLog("info", "TNT nao foi acesa pelo servidor; aguardando proximo cooldown.")
        return false
    end
    addLog("info", "TNT acesa; preparando arremesso direto ao feno.")

    task.wait(tonumber(HaystackConfig and HaystackConfig.TNT_LIGHT_TIME) or 0.48)
    if not IsHubLoaded then
        ToolRuntime.tntComboInProgress = false
        return false
    end

    origin = hrp.Position + Vector3.new(0, 2.5, 0)
    local updatedTarget = chooseTntTarget and chooseTntTarget(hrp)
    if updatedTarget then target = updatedTarget end
    local vel = solveTntVelocity(origin, target)
    if not vel then
        target = origin + hrp.CFrame.LookVector * 8
        vel = solveTntVelocity(origin, target)
        addLog("info", "Voce saiu do alcance durante a ignicao; TNT lancada em direcao segura, sem coleta garantida.")
    end
    local throwCF = CFrame.new(origin, target)

    local thrown = pcall(function()
        tntAction:FireServer("throw", throwCF, vel)
    end)
    if thrown then addLog("info", "TNT arremessada em trajetoria baixa direto ao feno.") end

    task.wait(0.2)
    equipToolSlot(getBestHarvestToolSlot(), true)
    ToolRuntime.tntComboInProgress = false
    if thrown then ToolRuntime.lastAutoTntThrow = os.clock() end
    return thrown
end

local function getToolStatusSummary()
    local curSlot = getCurrentEquippedSlot()
    local curName = ToolNames[curSlot] or ("Slot " .. tostring(curSlot))
    local bestSlot, bestName = getBestAvailableToolSlot()

    local vOwned = isToolOwned("Vacuum") and (isVacuumReady() and "sim" or "superaquecido") or "nao"
    local pOwned = isToolOwned("Pitchfork") and "sim" or "nao"
    local tOwned = isToolOwned("Tnt") and "sim" or "nao"
    local dOwned = isToolOwned("Drone") and (LocalPlayer:GetAttribute("DroneDeployed") == true and "ativo" or "sim") or "nao"

    local movementMode = HubState.NoTeleportMode and "sem teleporte" or "autonomo com teleporte"
    local cleared, remaining, total = getHayRoundProgress()
    local globalText = cleared and string.format("%.3f%% (%s/%s restantes)",
        cleared * 100, formatNumber(remaining), formatNumber(total)) or "indisponivel"
    local localText = FarmProgressState.localDepth
        and string.format("%.0f%%", FarmProgressState.localDepth * 100) or "aguardando"
    local revealPercent = math.clamp(
        tonumber(HaystackConfig and HaystackConfig.NEEDLE_REVEAL_FRACTION) or 0.75, 0.1, 1) * 100
    local targetText = FarmProgressState.target or "aguardando"
    if FarmProgressState.sector then
        targetText = targetText .. " S" .. tostring(FarmProgressState.sector)
            .. "/C" .. tostring(FarmProgressState.cycle or 1)
    end
    return string.format("Modo: %s | Em uso: %s (slot %d) | Melhor: %s\nAspirador: %s | Forquilha: %s | TNT: %s | Drone: %s\nFeno removido: %s | Profundidade: %s (meta %.0f%%) | Alvo: %s",
        movementMode, curName, curSlot, bestName, vOwned, pOwned, tOwned, dOwned,
        globalText, localText, revealPercent, targetText)
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
    return 1
end

local function getGrabRadius()
    local val = LocalPlayer:GetAttribute("HayGrabRadius")
    if type(val) == "number" and val >= 0 then return val end
    return 0
end

local function getPickCooldown()
    local val = LocalPlayer:GetAttribute("HayPickCooldown")
    if val and type(val) == "number" and val > 0 then return val end
    return tonumber(HaystackConfig and HaystackConfig.PICK_COOLDOWN) or 0.55
end

local function getToolReach(slotIndex)
    if slotIndex == SLOT_VACUUM then
        return tonumber(HaystackConfig and HaystackConfig.VACUUM_RANGE) or 11
    elseif slotIndex == SLOT_PITCHFORK then
        return tonumber(HaystackConfig and HaystackConfig.PITCHFORK_REACH) or 4.2
    end
    return tonumber(HaystackConfig and HaystackConfig.INTERACT_DISTANCE) or 20
end

local function findVisibleNeedleObjective()
    -- Only the server's collectible objective is actionable. "The Needle" is
    -- static map decoration, and a target HayId is still ordinary hay.
    for _, folderName in ipairs({"NeedleObjectiveServer", "HiddenNeedleClient"}) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("BasePart") and obj:GetAttribute("IsNeedleObjective") == true then
                    return obj
                end
            end
        end
    end
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("BasePart") and obj:GetAttribute("IsNeedleObjective") == true then
            return obj
        end
    end
    return nil
end

local function isHayWithinReach(part, origin, slotIndex)
    if not part or not origin then return false end
    return (part.Position - origin).Magnitude <= getToolReach(slotIndex)
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

-- The game writes the authoritative mutation to HayMutation when it creates
-- each strand. Visual color/material alone can also describe ordinary hay.
local MutationMultipliers = {
    Void = 20, Rainbow = 10, Electric = 8, Gold = 6, Burnt = 4,
    Glass = 3, Muddy = 2, Grassy = 1.5, Damp = 1.25,
}
if HaystackConfig and type(HaystackConfig.HAY_MUTATIONS) == "table" then
    for _, definition in pairs(HaystackConfig.HAY_MUTATIONS) do
        if type(definition) == "table" and type(definition.Name) == "string" then
            MutationMultipliers[definition.Name] = tonumber(definition.ValueMultiplier) or 1
        end
    end
end

local function getRareHayMultiplier(part)
    if not part or not part:IsA("BasePart") then return 1 end
    local mutation = part:GetAttribute("HayMutation")
        or part:GetAttribute("Mutation") or part:GetAttribute("HayType")
    if type(mutation) == "string" then
        return MutationMultipliers[mutation] or 1
    end
    if part:GetAttribute("Rainbow") == true then return MutationMultipliers.Rainbow end
    local hayId = part:GetAttribute("HayId")
    if type(hayId) == "number" and HaystackConfig and type(HaystackConfig.mutationFor) == "function" then
        local ok, inferredMutation = pcall(HaystackConfig.mutationFor, hayId)
        if ok and type(inferredMutation) == "string" then
            return MutationMultipliers[inferredMutation] or 1
        end
    end
    if type(hayId) == "number" and HaystackConfig and type(HaystackConfig.isRainbow) == "function" then
        local ok, rainbow = pcall(HaystackConfig.isRainbow, hayId)
        if ok and rainbow then return MutationMultipliers.Rainbow end
    end
    return 1
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
            if hayId and not (hayId == NeedleProtection.targetId and not NeedleProtection.ready) then
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

-- Tool-specific harvesting must mirror the live clients. Mixing PickHay with a
-- pitchfork/vacuum action makes the server resolve the same strand as a hand pick.

ToolRuntime.stopVacuumAutomation = function()
    if ToolRuntime.vacuumAutomationActive and Remotes.VacuumAction then
        pcall(function()
            Remotes.VacuumAction:FireServer("Stop")
        end)
    end
    ToolRuntime.vacuumAutomationActive = false
end

local function startVacuumAutomation()
    if ToolRuntime.vacuumAutomationActive then return true end
    if not Remotes.VacuumAction or not isVacuumReady() then return false end
    if getCurrentEquippedSlot() ~= SLOT_VACUUM then return false end
    local ok = pcall(function()
        Remotes.VacuumAction:FireServer("Start")
    end)
    ToolRuntime.vacuumAutomationActive = ok
    return ok
end

local function getVacuumCandidateIds(primaryPart)
    local ids = {}
    local seen = {}
    local function addPart(part)
        local hayId = part and part:GetAttribute("HayId")
        local protected = hayId == NeedleProtection.targetId and not NeedleProtection.ready
        if type(hayId) == "number" and not protected and not seen[hayId] and #ids < 8 then
            seen[hayId] = true
            table.insert(ids, hayId)
        end
    end

    addPart(primaryPart)
    local haystack = workspace:FindFirstChild("HaystackClient")
    if not haystack or not primaryPart or #ids >= 8 then return ids end

    local radius = tonumber(HaystackConfig and HaystackConfig.VACUUM_HARVEST_REACH) or 2.85
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {haystack}
    params.MaxParts = 96
    local nearby = workspace:GetPartBoundsInRadius(primaryPart.Position, radius, params)
    table.sort(nearby, function(a, b)
        return (a.Position - primaryPart.Position).Magnitude < (b.Position - primaryPart.Position).Magnitude
    end)
    for _, part in ipairs(nearby) do
        addPart(part)
        if #ids >= 8 then break end
    end
    return ids
end

local function harvestWithEquippedTool(primaryPart)
    if not primaryPart or not primaryPart.Parent then return false end
    local hayId = primaryPart:GetAttribute("HayId")
    if type(hayId) ~= "number" then return false end
    if hayId == NeedleProtection.targetId and not NeedleProtection.ready then return false end

    LocalPlayer:SetAttribute("HoveredHayId", hayId)
    local activeSlot = getCurrentEquippedSlot()
    if HubState.AutoEquipBestTool and NeedleProtection.isNear(primaryPart.Position, 3)
        and activeSlot ~= SLOT_HAND then
        if not equipToolSlot(SLOT_HAND, true) then return false end
        activeSlot = getCurrentEquippedSlot()
    end

    if activeSlot == SLOT_VACUUM and isVacuumReady() then
        if not startVacuumAutomation() then return false end
        local nozzle = workspace:FindFirstChild("VacuumNozzlePointClient")
        local nozzlePosition = nozzle and nozzle:IsA("BasePart") and nozzle.Position
        local hrp = getHRP()
        nozzlePosition = nozzlePosition or (hrp and (hrp.Position + Vector3.new(0, 1.5, 0))) or primaryPart.Position
        local preferredIds = getVacuumCandidateIds(primaryPart)
        return pcall(function()
            Remotes.VacuumAction:FireServer("Tick", primaryPart.Position, nozzlePosition, preferredIds)
        end)
    end

    ToolRuntime.stopVacuumAutomation()
    if activeSlot == SLOT_PITCHFORK and isToolOwned("Pitchfork") and Remotes.PitchforkDig then
        local cooldown = tonumber(LocalPlayer:GetAttribute("PitchforkCooldown"))
            or tonumber(HaystackConfig and HaystackConfig.PITCHFORK_COOLDOWN)
            or 0.85
        if os.clock() - ToolRuntime.lastPitchforkDigAt < cooldown then return false end
        ToolRuntime.lastPitchforkDigAt = os.clock()
        return pcall(function()
            Remotes.PitchforkDig:FireServer(hayId)
        end)
    end

    if activeSlot == SLOT_HAND and Remotes.PickHay then
        local candidates = HubState.BatchMultiGrab and getGrabCandidates(primaryPart) or {}
        return pcall(function()
            Remotes.PickHay:FireServer(hayId, candidates)
        end)
    end
    return false
end

-- SECTION 8: AUTOMATION ENGINES

-- 8.1 FAST BATCH AUTO-FARM ENGINE (FULL RGB HUNTING + MULTI-GRAB + AUTO-SELL)
local FarmRuntime = {
    isCurrentlySelling = false,
    cachedRainbowStrands = {},
    lastRainbowScanAt = 0,
    lastNoTeleportSellAttemptAt = 0,
    lastNoTeleportNoticeAt = 0,
    lastNoReachNoticeAt = 0,
}

-- Function to find ALL active Rainbow / RGB strands across the entire map
local function getAllRainbowStrands()
    local haystack = workspace:FindFirstChild("HaystackClient")
    local dropped = workspace:FindFirstChild("DroppedHay")
    local rgbList = {}
    local now = os.clock()

    if now - FarmRuntime.lastRainbowScanAt < 0.65 then
        for _, part in ipairs(FarmRuntime.cachedRainbowStrands) do
            if part and ((part.Parent == haystack and type(part:GetAttribute("HayId")) == "number")
                or part.Parent == dropped) and part:IsDescendantOf(workspace)
                and getRareHayMultiplier(part) > 1 then
                table.insert(rgbList, part)
            end
        end
        return rgbList
    end
    FarmRuntime.lastRainbowScanAt = now

    -- 1. Check all strands in HaystackClient (no limits / full map scan)
    if haystack then
        for _, p in ipairs(haystack:GetChildren()) do
            if p:IsA("BasePart") and p.Parent == haystack then
                local hayId = p:GetAttribute("HayId")
                if type(hayId) == "number" and getRareHayMultiplier(p) > 1 then
                    table.insert(rgbList, p)
                end
            end
        end
    end

    -- 2. Check all strands in DroppedHay for rainbow pieces
    if dropped then
        for _, d in ipairs(dropped:GetChildren()) do
            if d:IsA("BasePart") and getRareHayMultiplier(d) > 1 then
                table.insert(rgbList, d)
            end
        end
    end

    FarmRuntime.cachedRainbowStrands = rgbList
    return rgbList
end

-- Rare pieces are selected by the game's value multiplier, not by the
-- rotating edge-dig geometry used for ordinary hay.
local function chooseRareHayPart(candidates, origin, maxDistance)
    local bestPart, bestValue, bestDistance = nil, 1, math.huge
    for _, part in ipairs(candidates) do
        if part and part.Parent and part:IsA("BasePart") then
            local distance = (part.Position - origin).Magnitude
            local value = getRareHayMultiplier(part)
            local hayId = part:GetAttribute("HayId")
            local protected = type(hayId) == "number" and hayId == NeedleProtection.targetId and not NeedleProtection.ready
            if distance <= maxDistance and value > 1 and not protected
                and (value > bestValue or (value == bestValue and distance < bestDistance)) then
                bestPart, bestValue, bestDistance = part, value, distance
            end
        end
    end
    return bestPart
end

local function getNearbyHayParts(origin, radius, maxParts)
    local haystack = workspace:FindFirstChild("HaystackClient")
    if not haystack then return {} end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = {haystack}
    params.MaxParts = maxParts == nil and 256 or maxParts
    return workspace:GetPartBoundsInRadius(origin, radius, params)
end

-- Keep the chosen dig area stable while the player moves. The known needle
-- HayId identifies where to excavate; objective collection still uses the
-- server's normal reveal and PickHay("Objective") flow.
local FarmDigState = {
    cachedNeedleHayId = nil,
    cachedNeedleHayPart = nil,
    cachedNeedleTargetPosition = nil,
    lastNeedleHayLookupAt = 0,
    digSequence = 0,
    lastDigHayId = nil,
    minDwell = 2.5,
    maxDwell = 3,
    sectorCount = 16,
    targetDepth = math.clamp(
        tonumber(HaystackConfig and HaystackConfig.NEEDLE_REVEAL_FRACTION) or 0.75, 0.1, 1),
    cornerPosition = nil,
    cornerStartedAt = 0,
    cornerSector = nil,
    cornerZone = nil,
    cornerMode = nil,
    visitedSectors = {},
    hayGeometryFolder = nil,
    hayGeometryCenter = nil,
    hayGeometryMinY = nil,
    hayGeometryMaxY = nil,
    hayGeometryUpperRadius = nil,
    lastHayGeometryAt = 0,
}

local function getKnownNeedleHayPart(haystack)
    local hayId = Landmarks.TargetNeedleHayId
    if not haystack or type(hayId) ~= "number" then return nil end
    if FarmDigState.cachedNeedleHayId ~= hayId then
        FarmDigState.cachedNeedleHayId = hayId
        FarmDigState.cachedNeedleHayPart = nil
        FarmDigState.cachedNeedleTargetPosition = nil
        FarmDigState.lastNeedleHayLookupAt = 0
        NeedleProtection.targetId = hayId
        NeedleProtection.anchor = nil
        NeedleProtection.localActions = 0
        NeedleProtection.ready = false
        table.clear(FarmDigState.visitedSectors)
        FarmProgressState.cycle = 1
    end
    if FarmDigState.cachedNeedleHayPart and FarmDigState.cachedNeedleHayPart.Parent == haystack
        and FarmDigState.cachedNeedleHayPart:GetAttribute("HayId") == hayId then
        return FarmDigState.cachedNeedleHayPart
    end
    if FarmDigState.lastNeedleHayLookupAt > 0 and os.clock() - FarmDigState.lastNeedleHayLookupAt < 2 then return nil end
    FarmDigState.lastNeedleHayLookupAt = os.clock()
    for _, part in ipairs(haystack:GetChildren()) do
        if part:IsA("BasePart") and part:GetAttribute("HayId") == hayId then
            FarmDigState.cachedNeedleHayPart = part
            FarmDigState.cachedNeedleTargetPosition = part.Position
            return part
        end
    end
    return nil
end

local function getHayGeometryCenter(haystack)
    if not haystack then return nil end
    if haystack == FarmDigState.hayGeometryFolder and FarmDigState.hayGeometryCenter
        and os.clock() - FarmDigState.lastHayGeometryAt < 20 then
        return FarmDigState.hayGeometryCenter, FarmDigState.hayGeometryMinY, FarmDigState.hayGeometryMaxY, FarmDigState.hayGeometryUpperRadius
    end
    local sumX, sumY, sumZ, count = 0, 0, 0, 0
    local minY, maxY = math.huge, -math.huge
    local parts = haystack:GetChildren()
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") and type(part:GetAttribute("HayId")) == "number" then
            local pos = part.Position
            sumX, sumY, sumZ = sumX + pos.X, sumY + pos.Y, sumZ + pos.Z
            minY = math.min(minY, pos.Y)
            maxY = math.max(maxY, pos.Y)
            count = count + 1
        end
    end
    FarmDigState.hayGeometryFolder = haystack
    FarmDigState.lastHayGeometryAt = os.clock()
    if count > 0 then
        local configuredCenter = HaystackConfig and HaystackConfig.PILE_CENTER
        if typeof(configuredCenter) == "Vector3" then
            -- The live centroid moves as hay disappears. Keep X/Z anchored to
            -- the server's pile center so angular sectors never drift or repeat.
            FarmDigState.hayGeometryCenter = Vector3.new(configuredCenter.X, sumY / count, configuredCenter.Z)
        else
            FarmDigState.hayGeometryCenter = Vector3.new(sumX / count, sumY / count, sumZ / count)
        end
        FarmDigState.hayGeometryMinY, FarmDigState.hayGeometryMaxY = minY, maxY
        local upperRadius = 0
        for _, part in ipairs(parts) do
            if part:IsA("BasePart") and type(part:GetAttribute("HayId")) == "number" then
                local dx = part.Position.X - FarmDigState.hayGeometryCenter.X
                local dz = part.Position.Z - FarmDigState.hayGeometryCenter.Z
                upperRadius = math.max(upperRadius, math.sqrt(dx * dx + dz * dz))
            end
        end
        FarmDigState.hayGeometryUpperRadius = tonumber(HaystackConfig and HaystackConfig.PILE_RADIUS) or upperRadius
        Landmarks.HayCenter = FarmDigState.hayGeometryCenter
    else
        FarmDigState.hayGeometryCenter = nil
        FarmDigState.hayGeometryMinY, FarmDigState.hayGeometryMaxY, FarmDigState.hayGeometryUpperRadius = nil, nil, nil
    end
    return FarmDigState.hayGeometryCenter, FarmDigState.hayGeometryMinY, FarmDigState.hayGeometryMaxY, FarmDigState.hayGeometryUpperRadius
end

local function getFarmSector(position, center)
    if typeof(position) ~= "Vector3" or typeof(center) ~= "Vector3" then return nil end
    local angle = math.atan2(position.Z - center.Z, position.X - center.X)
    local normalized = (angle + math.pi * 2) % (math.pi * 2)
    return math.floor(normalized / (math.pi * 2) * FarmDigState.sectorCount) + 1
end

-- Angular sectors alone merge the top, bottom, center and rim. Track each
-- sector's three height bands and three radial bands independently instead.
local function getFarmZone(position, center, minY, maxY, pileRadius)
    local sector = getFarmSector(position, center)
    if not sector then return nil end
    local heightSpan = minY and maxY and (maxY - minY) or 0
    local height = heightSpan > 0.01 and math.clamp((position.Y - minY) / heightSpan, 0, 0.999999) or 0
    local dx, dz = position.X - center.X, position.Z - center.Z
    local radius = math.sqrt(dx * dx + dz * dz)
    local radial = pileRadius and pileRadius > 0.01 and math.clamp(radius / pileRadius, 0, 0.999999) or 0
    return sector + FarmDigState.sectorCount * (math.floor(height * 3) + math.floor(radial * 3) * 3)
end

local function chooseSmartHayPart(candidates, origin, maxDistance, haystack, respectCoverage)
    if not haystack then return nil end
    local center, minY, maxY, upperRadius = getHayGeometryCenter(haystack)
    local targetAngle = (FarmDigState.digSequence * 2.399963229728653 + math.sin(FarmDigState.digSequence * 1.618) * 0.17)
        % (math.pi * 2)
    local heightSpan = minY and maxY and (maxY - minY) or 0
    local targetHeight = (FarmDigState.digSequence % 3 + 0.5) / 3
    local targetDigY = minY and (minY + heightSpan * targetHeight) or 0
    local targetRadius = (upperRadius or 0) * ((math.floor(FarmDigState.digSequence / 3) % 3 + 0.5) / 3)
    local chosen, bestScore = nil, -math.huge

    for _, part in ipairs(candidates) do
        if part:IsA("BasePart") and part.Parent == haystack
            and type(part:GetAttribute("HayId")) == "number" then
            local offset = part.Position - origin
            local distance = offset.Magnitude
            local zone = getFarmZone(part.Position, center, minY, maxY, upperRadius)
            local alreadyCovered = respectCoverage and zone and FarmDigState.visitedSectors[zone]
            local protected = part:GetAttribute("HayId") == NeedleProtection.targetId and not NeedleProtection.ready
            if distance <= maxDistance and not alreadyCovered and not protected then
                local score = -distance * 0.015 - math.abs(part.Position.Y - targetDigY) / math.max(heightSpan, 1) * 24
                if part:GetAttribute("HayId") == FarmDigState.lastDigHayId then score = score - 25 end
                if center then
                    local dx, dz = part.Position.X - center.X, part.Position.Z - center.Z
                    local radius = math.sqrt(dx * dx + dz * dz)
                    local angle = math.atan2(dz, dx)
                    local angleError = math.abs((angle - targetAngle + math.pi) % (math.pi * 2) - math.pi)
                    score = score - math.abs(radius - targetRadius) / math.max(upperRadius or 0, 1) * 20 - angleError * 7
                end
                if score > bestScore then chosen, bestScore = part, score end
            end
        end
    end
    return chosen
end

-- When the player moves freely, harvest nearby hay at any height. The edge
-- pattern is useful for autonomous TP digging, but must not gate local picks.
local function chooseLocalHayPart(candidates, origin, maxDistance, haystack, excludedHayId)
    excludedHayId = excludedHayId or (not NeedleProtection.ready and NeedleProtection.targetId or nil)
    local chosen, bestScore = nil, -math.huge
    for _, part in ipairs(candidates) do
        if part:IsA("BasePart") and part.Parent == haystack then
            local hayId = part:GetAttribute("HayId")
            if type(hayId) == "number" and hayId ~= excludedHayId then
                local distance = (part.Position - origin).Magnitude
                if distance <= maxDistance then
                    local score = -distance - math.abs(part.Position.Y - origin.Y) * 0.12
                    if hayId == FarmDigState.lastDigHayId then score = score - 8 end
                    if score > bestScore then chosen, bestScore = part, score end
                end
            end
        end
    end
    return chosen
end

local function markCurrentFarmSectorVisited()
    if FarmDigState.cornerMode == "coverage" and FarmDigState.cornerZone then
        FarmDigState.visitedSectors[FarmDigState.cornerZone] = true
    end
end

local function clearAutoFarmCorner(markVisited)
    if markVisited then markCurrentFarmSectorVisited() end
    FarmDigState.cornerPosition = nil
    FarmDigState.cornerStartedAt = 0
    FarmDigState.cornerSector = nil
    FarmDigState.cornerZone = nil
    FarmDigState.cornerMode = nil
    FarmProgressState.localDepth = nil
    FarmProgressState.sector = nil
    FarmProgressState.target = "aguardando"
end

local function setAutoFarmCorner(position, sector, mode)
    FarmDigState.cornerPosition = position
    FarmDigState.cornerStartedAt = os.clock()
    FarmDigState.cornerSector = sector
    FarmDigState.cornerMode = mode or "coverage"
    local center, minY, maxY, radius = getHayGeometryCenter(workspace:FindFirstChild("HaystackClient"))
    FarmDigState.cornerZone = getFarmZone(position, center, minY, maxY, radius)
    FarmProgressState.localDepth = getDigDepthFraction(position)
    FarmProgressState.sector = sector
    FarmProgressState.target = FarmDigState.cornerMode == "needle"
        and (IS_BASEMENT and "regiao da chave" or "regiao da agulha") or "cobertura"
end

local function isNeedleAlreadyRevealed()
    local folder = ReplicatedStorage and ReplicatedStorage:FindFirstChild("NeedleHaystack")
    if LocalPlayer:GetAttribute("NeedleOwned") == true then
        NeedleProtection.targetId = nil
        NeedleProtection.anchor = nil
        NeedleProtection.ready = true
        return true
    end
    if folder and folder:GetAttribute("NeedleRevealed") ~= nil then
        local revealed = folder:GetAttribute("NeedleRevealed") == true
        if revealed then
            NeedleProtection.targetId = nil
            NeedleProtection.anchor = nil
            NeedleProtection.ready = true
        end
        return revealed
    end
    return findVisibleNeedleObjective() ~= nil
end

local function getNeedleSlotAnchor()
    local targetId = Landmarks.TargetNeedleHayId
    local slot = Landmarks.TargetNeedleSlot
    local center = HaystackConfig and HaystackConfig.PILE_CENTER
    local rendered = tonumber(HaystackConfig and HaystackConfig.RENDERED_HAY)
    local total = tonumber(HaystackConfig and HaystackConfig.TOTAL_HAY)
    if typeof(center) ~= "Vector3" or not rendered or not total
        or not HaystackSurface or type(HaystackSurface.slotPolar) ~= "function" then return nil end
    if not slot and type(targetId) ~= "number" then return nil end
    local slotCount = math.min(rendered, total)
    if slotCount <= 0 then return nil end
    if not slot then
        -- Exact fallback used by NeedleHaystackClient when an ID has not entered
        -- the rendered active set yet. This is the critical deep-layer case.
        slot = (targetId - 1) % slotCount + 1
        Landmarks.TargetNeedleSlot = slot
        Landmarks.TargetNeedleGeneration = (targetId - 1) // slotCount
    end
    local ok, radiusFraction, angle = pcall(HaystackSurface.slotPolar, slot, slotCount, 11, 0)
    if not ok or type(radiusFraction) ~= "number" or type(angle) ~= "number" then return nil end
    local radius = radiusFraction * (tonumber(HaystackConfig.PILE_RADIUS) or 17)
    local dx, dz = radius * math.cos(angle), radius * math.sin(angle)
    local profileFraction = 0.5
    if type(HaystackSurface.profileHeightFraction) == "function" then
        local profileOk, profile = pcall(HaystackSurface.profileHeightFraction, radiusFraction)
        if profileOk and type(profile) == "number" then profileFraction = profile end
    end
    local rawDepth = 0
    if type(HaystackSurface.digAt) == "function" then
        local depthOk, depth = pcall(HaystackSurface.digAt, dx, dz)
        if depthOk and type(depth) == "number" then rawDepth = depth end
    end
    local y = center.Y + (tonumber(HaystackConfig.PILE_BASE_Y) or 0)
        + (tonumber(HaystackConfig.PILE_HEIGHT) or 12) * profileFraction - rawDepth
    return Vector3.new(center.X + dx, y, center.Z + dz)
end

local function getNeedleDigAnchor(haystack)
    if isNeedleAlreadyRevealed() then return nil end
    local targetPart = getKnownNeedleHayPart(haystack)
    if targetPart then FarmDigState.cachedNeedleTargetPosition = targetPart.Position end
    if not FarmDigState.cachedNeedleTargetPosition then
        FarmDigState.cachedNeedleTargetPosition = getNeedleSlotAnchor()
    end
    NeedleProtection.targetId = Landmarks.TargetNeedleHayId
    NeedleProtection.anchor = FarmDigState.cachedNeedleTargetPosition
    return FarmDigState.cachedNeedleTargetPosition, targetPart
end

local function recordNeedleAreaAction(position, hayId)
    local anchor = NeedleProtection.anchor
    if NeedleProtection.ready or not anchor or typeof(position) ~= "Vector3"
        or hayId == NeedleProtection.targetId then return end
    local digRadius = tonumber(HaystackConfig and HaystackConfig.NEEDLE_DIG_RADIUS) or 5.5
    local dx, dz = position.X - anchor.X, position.Z - anchor.Z
    if math.sqrt(dx * dx + dz * dz) <= digRadius then
        NeedleProtection.localActions = NeedleProtection.localActions + 1
    end
end

local function chooseAutoFarmHayPart(haystack, hrp, reach)
    if HubState.NoTeleportMode then
        clearAutoFarmCorner()
        FarmProgressState.localDepth = getDigDepthFraction(hrp.Position)
        FarmProgressState.target = "area do jogador"
        return chooseLocalHayPart(getNearbyHayParts(hrp.Position, reach, 0),
            hrp.Position, reach, haystack), false
    end

    -- Keep reveal protection/progress, but never pin the whole route to its
    -- estimated position. Traverse the remaining live hay instead.
    local needleAnchor = getNeedleDigAnchor(haystack)
    if needleAnchor then
        local depth = getDigDepthFraction(needleAnchor)
        local required = tonumber(HaystackConfig and HaystackConfig.NEEDLE_LOCAL_PICKS_REQUIRED) or 18
        if depth and depth >= FarmDigState.targetDepth and NeedleProtection.localActions >= required then
            NeedleProtection.ready = true
        end
    end
    if FarmDigState.cornerMode == "needle" then clearAutoFarmCorner() end

    local now = os.clock()
    if FarmDigState.cornerPosition and FarmDigState.cornerMode == "coverage" then
        local elapsed = now - FarmDigState.cornerStartedAt
        local depth = getDigDepthFraction(FarmDigState.cornerPosition)
        FarmProgressState.localDepth = depth
        local localTarget = chooseLocalHayPart(getNearbyHayParts(hrp.Position, reach, 0),
            hrp.Position, reach, haystack)
        local stillNeedsDigging = not depth or depth < 0.99
        if localTarget and stillNeedsDigging and elapsed < math.min(FarmDigState.minDwell, FarmDigState.maxDwell) then
            return localTarget, false
        end
        -- No local hay, nearly complete local depth, or the dwell elapsed.
        -- Retire this height/radius/angle zone for the rest of the current cycle.
        clearAutoFarmCorner(true)
    end

    FarmDigState.digSequence = FarmDigState.digSequence + 1
    local nextTarget = chooseSmartHayPart(haystack:GetChildren(), hrp.Position,
        math.huge, haystack, true)
    if not nextTarget then
        -- Every still-viable height/radius/angle zone was covered. Only now begin a
        -- fresh pass; this is what prevents the old same-corners loop.
        table.clear(FarmDigState.visitedSectors)
        FarmProgressState.cycle = (FarmProgressState.cycle or 1) + 1
        FarmDigState.digSequence = FarmDigState.digSequence + 1
        nextTarget = chooseSmartHayPart(haystack:GetChildren(), hrp.Position,
            math.huge, haystack, true)
    end
    if not nextTarget then
        -- Surface data may be unavailable briefly during round synchronization.
        nextTarget = chooseSmartHayPart(haystack:GetChildren(), hrp.Position,
            math.huge, haystack, false)
    end
    if nextTarget then
        local center = getHayGeometryCenter(haystack)
        setAutoFarmCorner(nextTarget.Position, getFarmSector(nextTarget.Position, center), "coverage")
    end
    return nextTarget, nextTarget ~= nil
end

chooseTntTarget = function(hrp)
    local haystack = workspace:FindFirstChild("HaystackClient")
    if not haystack then return nil end
    local origin = hrp.Position + Vector3.new(0, 2.5, 0)
    local blastRadius = tonumber(HaystackConfig and HaystackConfig.TNT_BLAST_RADIUS) or 2.1
    local feasibleNormal = {}
    if HubState.PrioritizeRGB then
        local feasibleRare = {}
        for _, part in ipairs(getAllRainbowStrands()) do
            if part.Parent == haystack and (part.Position - hrp.Position).Magnitude <= 32
                and not NeedleProtection.isNear(part.Position, blastRadius)
                and solveTntVelocity(origin, part.Position) then
                table.insert(feasibleRare, part)
            end
        end
        local rareTarget = chooseRareHayPart(feasibleRare, hrp.Position, 32)
        if rareTarget then return rareTarget.Position end
    end
    if not HubState.NoTeleportMode then
        local excavationTarget = FarmDigState.cornerPosition
        if excavationTarget and (excavationTarget - hrp.Position).Magnitude <= 32
            and not NeedleProtection.isNear(excavationTarget, blastRadius)
            and solveTntVelocity(origin, excavationTarget) then
            return excavationTarget
        end
    end
    local scanOrigin = hrp.Position + Vector3.new(0, 7, 0)
    local nearby = HubState.NoTeleportMode and getNearbyHayParts(hrp.Position, 32, 0)
        or getNearbyHayParts(scanOrigin, 32)
    for _, part in ipairs(nearby) do
        if part:IsA("BasePart") and part.Parent == haystack
            and type(part:GetAttribute("HayId")) == "number"
            and not NeedleProtection.isNear(part.Position, blastRadius)
            and solveTntVelocity(origin, part.Position) then
            table.insert(feasibleNormal, part)
        end
    end
    local chosen
    if HubState.NoTeleportMode then
        chosen = chooseLocalHayPart(feasibleNormal, hrp.Position, 32, haystack)
    else
        chosen = chooseSmartHayPart(feasibleNormal, hrp.Position, 32, haystack)
    end
    return chosen and chosen.Position or nil
end

local function resolveWorldPart(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance end
    if instance:IsA("Model") and instance.PrimaryPart then return instance.PrimaryPart end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function findBasementTrapdoorPart()
    local trapdoor = workspace:FindFirstChild("Trapdoor")
    local closed = trapdoor and trapdoor:FindFirstChild("TrapDoorClosed")
    return resolveWorldPart(closed and (closed:FindFirstChild("Keyhole", true) or closed))
end

local BasementPuzzleLabels = {
    ColorPuzzle = "Cores",
    PicturePuzzle = "Imagem",
    NumberPuzzle = "Teclado numerico",
}

local BasementSolver = (function()
-- BEGIN EMBEDDED BASEMENT SOLVER
-- Pure planning only. The embedded copy in main.lua must match this module.
-- Never treats a sent action as success; the runtime must wait for server state.
local Solver = {}

function Solver.isTaken(taken, index)
    return type(taken) == "table" and (taken[index] == true or taken[tostring(index)] == true)
end

function Solver.leverIndex(step)
    local model = step.Model
    if type(model) == "table" then model = model[#model] end
    return tonumber(tostring(model or ""):match("Lever(%d+)$"))
        or tonumber(tostring(step.Id or ""):match("(%d+)$"))
end

function Solver.mergeLeverState(definition, state, attributes)
    local copy = type(state) == "table" and table.clone(state) or {}
    copy.completed = copy.completed == true or attributes.LeverPuzzleSolved == true
    copy.steps = table.clone(type(copy.steps) == "table" and copy.steps or {})
    for _, step in ipairs(definition and definition.Steps or {}) do
        local index = Solver.leverIndex(step)
        if index and attributes["Lever" .. index .. "Pulled"] == true then copy.steps[step.Id] = true end
    end
    return copy
end

function Solver.phase(leverSolved, now, doorReadyAt, states, requiredPuzzles)
    if leverSolved ~= true then return "LEVERS", "LeverPuzzle" end
    if now < (doorReadyAt or 0) then return "DOOR" end
    for _, id in ipairs(requiredPuzzles) do
        local state = states and states[id]
        if type(state) ~= "table" or state.completed ~= true then return "PUZZLE", id end
    end
    return "DONE"
end

function Solver.exitPhase(state)
    if state.roundComplete == true or state.winnerUserId ~= nil then return "COMPLETE" end
    if state.cutscene == true or state.inputLocked == true or state.hintOpen == true then return "PAUSED" end
    if state.puzzlesComplete ~= true then return "WAIT_PUZZLES" end
    if state.keyOwned ~= true then return "WAIT_KEY" end
    if state.escapeReady ~= true then return "WAIT_RELEASE" end
    return "UNLOCK"
end

function Solver.lever(definition, state)
    if state.completed == true then return nil, "DONE" end
    local steps = table.clone(definition.Steps or {})
    table.sort(steps, function(a, b)
        local first, second = Solver.leverIndex(a) or math.huge, Solver.leverIndex(b) or math.huge
        if first ~= second then return first < second end
        return tostring(a.Id) < tostring(b.Id)
    end)
    for _, step in ipairs(steps) do
        if not (state.steps and state.steps[step.Id]) then
            return {kind = "Lever", puzzleId = "LeverPuzzle", stepId = step.Id, model = step.Model}
        end
    end
    return nil, "WAIT_SERVER"
end

function Solver.mergeNumberState(state, feedbackTaken, feedbackCode)
    if type(state) ~= "table" then return nil end
    local copy = table.clone(state)
    copy.taken = table.clone(type(state.taken) == "table" and state.taken or {})
    for index, taken in pairs(feedbackTaken or {}) do
        if taken == true then copy.taken[index] = true end
    end
    if not (type(copy.code) == "string" and copy.code:match("^%d+$"))
        and type(feedbackCode) == "string" and feedbackCode:match("^%d+$") then
        copy.code = feedbackCode
    end
    return copy
end

function Solver.number(definition, state, posters)
    if state.completed == true then return nil, "DONE" end
    local code = state.code
    if type(code) == "string" and code:match("^%d+$") and #code == definition.CodeLength then
        -- Do not tonumber(code): a code starting with zero must keep that zero.
        return {kind = "Submit", puzzleId = "NumberPuzzle", code = code}
    end
    for _, poster in ipairs(posters) do
        if not Solver.isTaken(state.taken, poster.index) then
            return {kind = "Poster", puzzleId = "NumberPuzzle", index = poster.index, model = poster.model}
        end
    end
    return nil, "WAIT_CODE"
end

function Solver.picture(definition, state)
    if state.completed == true then return nil, "DONE" end
    local rotations = state.rotations
    if type(rotations) ~= "table" then return nil, "WAIT_STATE" end
    local size = tonumber(definition.GridSize)
    if not size or size < 1 or size > 8 or size % 1 ~= 0 then return nil, "BAD_CONFIG" end
    for index = 1, size * size do
        local id = "Tile" .. index
        local value = rotations[id]
        if type(value) ~= "number" or value % 1 ~= 0 then return nil, "WAIT_STATE" end
        if value % 4 ~= 0 then
            return {kind = "Rotate", puzzleId = "PicturePuzzle", stepId = id, before = value,
                expected = (value + 1) % 4}
        end
    end
    -- Zero is the unrotated image orientation, not a fabricated completion flag.
    return nil, "WAIT_SERVER"
end

function Solver.colorBounds(definition)
    local minimum, maximum = tonumber(definition.MinCount), tonumber(definition.MaxCount)
    if not minimum or not maximum or minimum % 1 ~= 0 or maximum % 1 ~= 0
        or maximum < minimum or maximum - minimum > 19 then
        return nil
    end
    return minimum, maximum
end

-- Each configured Gems group is a clue, not another counter. The game marks
-- whole gem models with ColorPuzzleVisible; count models, never their parts.
function Solver.colorTargets(definition, groups)
    local minimum, maximum = Solver.colorBounds(definition)
    local steps = definition.Steps
    if not minimum or type(steps) ~= "table" or #steps == 0 or #steps > 8 then
        return nil, "BAD_CONFIG"
    end
    local targets = {}
    for _, step in ipairs(steps) do
        if type(step.Id) ~= "string" or targets[step.Id] ~= nil then return nil, "BAD_CONFIG" end
        local gems = type(groups) == "table" and groups[step.Id]
        if type(gems) ~= "table" or #gems == 0 then return nil, "WAIT_CLUE" end
        local count = 0
        for _, gem in ipairs(gems) do
            if type(gem) ~= "table" or gem.loaded ~= true or type(gem.visible) ~= "boolean" then
                return nil, "WAIT_CLUE"
            end
            if gem.visible then count = count + 1 end
        end
        if count < minimum or count > maximum then return nil, "BAD_CLUE" end
        targets[step.Id] = count
    end
    return targets
end

function Solver.color(definition, state, targets)
    if state.completed == true then return nil, "DONE" end
    local minimum, maximum = Solver.colorBounds(definition)
    local steps, values = definition.Steps, state.values
    if not minimum or type(steps) ~= "table" or #steps == 0 or #steps > 8 then return nil, "BAD_CONFIG" end
    if type(values) ~= "table" then return nil, "WAIT_STATE" end
    if type(targets) ~= "table" then return nil, "WAIT_CLUE" end
    -- Validate the entire live vector and clue before changing any counter.
    for _, step in ipairs(steps) do
        if type(step.Id) ~= "string" then return nil, "BAD_CONFIG" end
        local goal, value = targets[step.Id], values[step.Id]
        if type(goal) ~= "number" then return nil, "WAIT_CLUE" end
        if goal % 1 ~= 0 or goal < minimum or goal > maximum then return nil, "BAD_CLUE" end
        if type(value) ~= "number" or value % 1 ~= 0 then return nil, "WAIT_STATE" end
        if value < minimum - 1 or value > maximum then return nil, "BAD_STATE" end
    end
    for _, step in ipairs(steps) do
        local value, goal = values[step.Id], targets[step.Id]
        if value ~= goal then
            return {kind = "Counter", puzzleId = "ColorPuzzle", stepId = step.Id, model = step.Model,
                before = value, expected = value < minimum and minimum
                    or (value == maximum and minimum or value + 1), goal = goal}
        end
    end
    -- Matching the clue is not a fabricated server completion flag.
    return nil, "WAIT_SERVER"
end

function Solver.acknowledged(action, state)
    if type(state) ~= "table" then return false end
    if state.completed == true then return true end
    if action.kind == "Lever" then return state.steps and not not state.steps[action.stepId] or false end
    if action.kind == "Poster" then
        return Solver.isTaken(state.taken, action.index) or (type(state.code) == "string" and #state.code > 0)
    end
    if action.kind == "Rotate" then
        return type(state.rotations) == "table" and type(state.rotations[action.stepId]) == "number"
            and state.rotations[action.stepId] ~= action.before
    end
    if action.kind == "Counter" then
        return type(state.values) == "table" and type(state.values[action.stepId]) == "number"
            and state.values[action.stepId] == action.expected
    end
    return false
end

function Solver.token(action)
    return table.concat({action.puzzleId, action.kind, tostring(action.stepId or action.index or ""),
        tostring(action.before or action.code or "")}, ":")
end

return Solver
-- END EMBEDDED BASEMENT SOLVER
end)()

local function getBasementNextObjective()
    if not IS_BASEMENT or not BasementState.folder then return "Porão indisponivel", nil end
    if BasementState.automation.exitCompleted or LocalPlayer:GetAttribute("NeedleRoundComplete") == true then
        return "Saida concluida. Capitulo finalizado.", nil
    end
    local action = HubState.BasementAutoPuzzles and BasementState.automation.currentAction
    local definition = action and BasementState.config and BasementState.config.Puzzles
        and BasementState.config.Puzzles[action.puzzleId]
    if definition then
        local target = BasementSolver.target(action, definition)
        if target then return "Auto: " .. (BasementPuzzleLabels[action.puzzleId] or "Alavancas"), target end
    end
    if BasementState.automation.exitActive then return "Saindo do porao pelo alcapao", findBasementTrapdoorPart() end
    local hayFolder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    local keyOwned = LocalPlayer:GetAttribute("NeedleOwned") == true
    local keyClaimed = hayFolder and hayFolder:GetAttribute("NeedleClaimed") == true
    if BasementState.folder:GetAttribute("LeverPuzzleSolved") ~= true then
        local worldPuzzles = workspace:FindFirstChild("Puzzles")
        local leverPuzzle = worldPuzzles and worldPuzzles:FindFirstChild("LeverPuzzle")
        local levers = leverPuzzle and leverPuzzle:FindFirstChild("Levers")
        for i = 1, 3 do
            if BasementState.folder:GetAttribute("Lever" .. i .. "Pulled") ~= true then
                return "Acione a alavanca " .. i, resolveWorldPart(levers and levers:FindFirstChild("Lever" .. i))
            end
        end
        return "Conclua o puzzle das alavancas", resolveWorldPart(leverPuzzle)
    end
    if HubState.BasementAutoPuzzles and os.clock() < (BasementState.automation.doorReadyAt or 0) then
        local world = workspace:FindFirstChild("Puzzles")
        local leverPuzzle = world and world:FindFirstChild("LeverPuzzle")
        return "Aguarde a porta abrir", resolveWorldPart(leverPuzzle and leverPuzzle:FindFirstChild("MetalDoor"))
    end

    local solvedCount = tonumber(BasementState.folder:GetAttribute("SolvedPuzzleCount")) or 0
    local requiredCount = tonumber(BasementState.folder:GetAttribute("RequiredPuzzleCount")) or #BasementState.requiredPuzzles
    if solvedCount < requiredCount then
        local worldPuzzles = workspace:FindFirstChild("Puzzles")
        for _, puzzleId in ipairs(BasementState.requiredPuzzles) do
            local state = BasementState.snapshot and BasementState.snapshot[puzzleId]
            if type(state) ~= "table" or state.completed ~= true then
                return "Resolva: " .. (BasementPuzzleLabels[puzzleId] or puzzleId),
                    resolveWorldPart(worldPuzzles and worldPuzzles:FindFirstChild(puzzleId))
            end
        end
        return "Resolva os puzzles restantes", nil
    end

    if not keyOwned and not keyClaimed then
        local target = findVisibleNeedleObjective()
        local haystack = workspace:FindFirstChild("HaystackClient")
        return "Encontre a chave no feno", target or getKnownNeedleHayPart(haystack)
    end

    if BasementState.folder:GetAttribute("EscapeReady") == true then
        return "Abra a saida com a chave", findBasementTrapdoorPart()
    end
    return "Aguardando liberacao da saida", findBasementTrapdoorPart()
end

function BasementSolver.snapshot(puzzleId)
    local state = BasementState.snapshot and BasementState.snapshot[puzzleId]
    if puzzleId == "LeverPuzzle" and BasementState.folder then
        local attributes = {LeverPuzzleSolved = BasementState.folder:GetAttribute("LeverPuzzleSolved")}
        for index = 1, 3 do
            attributes["Lever" .. index .. "Pulled"] = BasementState.folder:GetAttribute("Lever" .. index .. "Pulled")
        end
        local definition = BasementState.config and BasementState.config.Puzzles and BasementState.config.Puzzles.LeverPuzzle
        return BasementSolver.mergeLeverState(definition, state, attributes)
    end
    if type(state) ~= "table" then return nil end
    if puzzleId ~= "NumberPuzzle" then return state end
    return BasementSolver.mergeNumberState(state, BasementState.automation.posterTaken, BasementState.automation.numberCode)
end

function BasementSolver.releaseCamera(cutscene)
    local automation = BasementState.automation
    local lease = automation.cameraLease
    automation.cameraLease = nil
    if lease and not cutscene and lease.camera == workspace.CurrentCamera
        and lease.camera.CameraType == Enum.CameraType.Scriptable then
        lease.camera.CameraType = lease.cameraType
        lease.camera.CFrame = lease.cframe
        lease.camera.Focus = lease.focus
    end
end

function BasementSolver.resetRound()
    local automation = BasementState.automation
    automation.pending = nil
    automation.colorClue = nil
    automation.colorCounts = nil
    automation.colorStream = nil
    automation.colorClueIssue = nil
    automation.currentAction = nil
    automation.posterTaken = {}
    automation.numberCode = nil
    automation.submitRejectedAt = nil
    automation.doorReadyAt = nil
    automation.doorPuzzleId = nil
    automation.wasLeverSolved = nil
    automation.attempts = {}
    automation.blockedUntil = {}
    automation.details = {}
    automation.nextActionAt = 0
    automation.exitActive = false
    automation.exitTeleport = false
    automation.exitCompleted = false
    automation.exitSentAt = nil
    automation.exitApproachReadyAt = nil
    automation.exitAttempts = 0
    automation.exitRetryAt = nil
    automation.exitStatus = nil
    BasementSolver.releaseCamera(false)
end

function BasementSolver.isBusy()
    if not IS_BASEMENT then return false end
    local automation = BasementState.automation
    local hay = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    return automation.active == true or automation.exitActive == true or automation.exitCompleted == true
        or LocalPlayer:GetAttribute("NeedleRoundComplete") == true
        or (hay ~= nil and hay:GetAttribute("WinnerUserId") ~= nil)
end

function BasementSolver.positionExit(allowTeleport)
    local trapdoor, part = workspace:FindFirstChild("Trapdoor"), findBasementTrapdoorPart()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local camera, automation = workspace.CurrentCamera, BasementState.automation
    if not trapdoor or not part then return false, "Aguardando alcapao/fechadura carregar." end
    if not hrp or not humanoid or humanoid.Health <= 0 or not camera then
        BasementSolver.releaseCamera(false)
        return false, "Aguardando personagem e camera."
    end
    local pivot = trapdoor:GetPivot().Position
    if allowTeleport and (hrp.Position - pivot).Magnitude > 22 then
        -- The lock is on the ceiling above the ladder. Approach from below;
        -- teleporting onto the lock itself places the character in/above the roof.
        local destination = part.Position - Vector3.new(0, 8, 0)
        hrp.CFrame = CFrame.lookAt(destination, destination + Vector3.new(0, 0, -1))
        hrp.AssemblyLinearVelocity = Vector3.zero
        automation.exitApproachReadyAt = os.clock() + 0.35
        return false, "Aproximando da escada/alcapao..."
    end
    if os.clock() < (automation.exitApproachReadyAt or 0) then return false, "Ajustando posicao na saida..." end
    if getCurrentEquippedSlot() ~= SLOT_NEEDLE then
        if not equipToolSlot(SLOT_NEEDLE, true) or getCurrentEquippedSlot() ~= SLOT_NEEDLE then
            return false, "Equipando a chave..."
        end
    end
    if allowTeleport then
        if not automation.cameraLease or automation.cameraLease.camera ~= camera then
            BasementSolver.releaseCamera(false)
            automation.cameraLease = {camera = camera, cameraType = camera.CameraType,
                cframe = camera.CFrame, focus = camera.Focus}
        end
        local origin = hrp.Position + Vector3.new(0, 1.5, 0)
        if (part.Position - origin).Magnitude < 0.01 then return false, "Ajustando mira da fechadura..." end
        automation.cameraLease.aim = CFrame.lookAt(origin, part.Position)
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame, camera.Focus = automation.cameraLease.aim, CFrame.new(part.Position)
    else
        BasementSolver.releaseCamera(false)
    end
    -- Mirror NeedleEndingBasementClient: 24 studs from the trapdoor pivot and
    -- aim toward the keyhole (0.68 dot fallback), with the key equipped.
    if (hrp.Position - pivot).Magnitude > 24 then return false, "Auto TP desligado: aproxime-se da escada/alcapao." end
    local direction = part.Position - camera.CFrame.Position
    if direction.Magnitude < 0.01 or camera.CFrame.LookVector:Dot(direction.Unit) < 0.68 then
        return false, "Auto TP desligado: mire a fechadura com a chave."
    end
    return true
end

function BasementSolver.exit(allowTeleport, puzzlesComplete)
    local automation, now = BasementState.automation, os.clock()
    local hay = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    local folder = BasementState.folder
    if puzzlesComplete == nil then
        local solved = tonumber(folder and folder:GetAttribute("SolvedPuzzleCount")) or 0
        local required = tonumber(folder and folder:GetAttribute("RequiredPuzzleCount")) or #BasementState.requiredPuzzles
        puzzlesComplete = required > 0 and solved >= required
    end
    local state = {puzzlesComplete = puzzlesComplete,
        keyOwned = LocalPlayer:GetAttribute("NeedleOwned") == true,
        escapeReady = folder and folder:GetAttribute("EscapeReady") == true or false,
        roundComplete = automation.exitCompleted == true or LocalPlayer:GetAttribute("NeedleRoundComplete") == true,
        winnerUserId = hay and hay:GetAttribute("WinnerUserId"),
        cutscene = LocalPlayer:GetAttribute("CutsceneActive") == true,
        inputLocked = LocalPlayer:GetAttribute("NeedleInputLocked") == true,
        hintOpen = LocalPlayer:GetAttribute("HintViewerOpen") == true}
    local phase = BasementSolver.exitPhase(state)
    automation.exitTeleport = allowTeleport == true
    automation.currentAction = nil
    if phase ~= "UNLOCK" then
        local notices = {COMPLETE = "Saida confirmada pelo servidor. Cena final/tela de resultado do jogo.",
            PAUSED = "Aguardando cena/animacao do jogo terminar para sair.",
            WAIT_PUZZLES = "Aguardando os puzzles serem concluidos.",
            WAIT_KEY = "Puzzles concluidos; falta pegar a chave no feno para sair.",
            WAIT_RELEASE = "Puzzles concluidos; aguardando liberacao da saida pelo servidor."}
        automation.exitActive = phase == "PAUSED" or phase == "WAIT_RELEASE"
        if phase == "COMPLETE" then automation.exitCompleted = true end
        if automation.exitActive or phase == "COMPLETE" then ToolRuntime.stopVacuumAutomation() end
        automation.exitStatus = notices[phase]
        if phase == "WAIT_KEY" and hay and hay:GetAttribute("NeedleClaimed") == true then
            automation.exitStatus = "Puzzles concluidos; chave com outro jogador. Aguardando ele abrir a saida."
        end
        BasementSolver.releaseCamera(phase == "COMPLETE" or state.cutscene or state.inputLocked)
        return automation.exitStatus
    end
    automation.exitActive = true
    ToolRuntime.stopVacuumAutomation()
    if FarmRuntime.isCurrentlySelling or ToolRuntime.tntComboInProgress then
        automation.exitStatus = "Finalizando venda/TNT antes de sair."
        return automation.exitStatus
    end
    if automation.exitSentAt and now - automation.exitSentAt < 5 then
        automation.exitStatus = "Abrindo alcapao; aguardando confirmacao/cena de saida."
        return automation.exitStatus
    end
    if (automation.exitAttempts or 0) >= 3 then
        automation.exitRetryAt = automation.exitRetryAt or now + 20
        if now < automation.exitRetryAt then
            automation.exitStatus = "Saida ainda nao confirmada; aguardando para tentar novamente."
            return automation.exitStatus
        end
        automation.exitAttempts, automation.exitRetryAt = 0, nil
    end
    local ready, notice = BasementSolver.positionExit(allowTeleport)
    if not ready then automation.exitStatus = notice; return notice end
    if not Remotes.NeedleHandIn then
        automation.exitStatus = "Interacao da saida indisponivel no servidor."
        return automation.exitStatus
    end
    local ok = pcall(function() Remotes.NeedleHandIn:FireServer() end)
    automation.exitSentAt, automation.exitAttempts = now, (automation.exitAttempts or 0) + 1
    automation.exitStatus = ok and "Chave usada no alcapao; aguardando cena de subida/saida."
        or "Falha ao interagir com a saida; nova tentativa com intervalo."
    return automation.exitStatus
end

if IS_BASEMENT and Remotes.NeedleRoundCompleted then
    table.insert(HubConnections, Remotes.NeedleRoundCompleted.OnClientEvent:Connect(function()
        BasementState.automation.exitCompleted = true
    end))
end

function BasementSolver.worldFolder(puzzleId)
    local config = BasementState.config
    if config and type(config.folderFor) == "function" then
        local ok, folder = pcall(config.folderFor, puzzleId)
        if ok and typeof(folder) == "Instance" then return folder end
    end
    local world = workspace:FindFirstChild("Puzzles")
    return world and world:FindFirstChild(puzzleId)
end

function BasementSolver.target(action, definition)
    local folder = BasementSolver.worldFolder(action.puzzleId)
    if not folder then return nil end
    local model, board
    if action.kind == "Poster" then
        model = action.model
    elseif action.kind == "Submit" then
        model = folder:FindFirstChild(definition.Keypad or "Keypad", true)
    elseif action.kind == "Rotate" then
        local picture = folder:FindFirstChild("PicturePuzzle") or folder
        board = picture:FindFirstChild("BoardPart", true)
        local hitboxes = picture:FindFirstChild("TileHitboxes", true)
        model = hitboxes and hitboxes:FindFirstChild(action.stepId, true)
        local tileIndex = tonumber(action.stepId:match("^Tile(%d+)$"))
        if hitboxes and (not model or model:GetAttribute("TileIndex") ~= tileIndex) then
            model = nil
            for _, candidate in ipairs(hitboxes:GetDescendants()) do
                if candidate:IsA("BasePart") and candidate:GetAttribute("TileIndex") == tileIndex then
                    model = candidate
                    break
                end
            end
        end
        if not model then return nil end
    elseif typeof(action.model) == "Instance" then
        model = action.model
    elseif type(BasementState.config.resolve) == "function" then
        local ok, result = pcall(BasementState.config.resolve, folder, action.model)
        if ok then model = result end
    end
    if typeof(model) ~= "Instance" then return nil end
    local part = resolveWorldPart(model)
    return part, model, board
end

function BasementSolver.posters(definition)
    local folder = BasementSolver.worldFolder("NumberPuzzle")
    local container = folder and folder:FindFirstChild(definition.Posters or "Posters", true)
    local result = {}
    if container then
        for _, part in ipairs(container:GetChildren()) do
            local index = part:GetAttribute(BasementState.config.PosterIndexAttribute or "PosterIndex")
            if part:IsA("BasePart") and type(index) == "number" then
                table.insert(result, {index = index, model = part})
            end
        end
    end
    table.sort(result, function(a, b) return a.index < b.index end)
    return result
end

function BasementSolver.readColorTargets(definition)
    local automation = BasementState.automation
    automation.colorClueIssue = nil
    local config, folder = BasementState.config, BasementSolver.worldFolder("ColorPuzzle")
    local groups, sources, labels = {}, {folder}, {}
    if type(definition.Steps) ~= "table" or #definition.Steps == 0 or #definition.Steps > 8 then
        automation.colorClue = nil
        automation.colorCounts = nil
        return nil, "BAD_CONFIG"
    end
    if not folder or not config or type(config.resolve) ~= "function" then
        automation.colorClue = nil
        automation.colorCounts = nil
        return nil, "WAIT_CLUE"
    end
    if workspace.StreamingEnabled then
        local stream = automation.colorStream
        if not stream or stream.folder ~= folder then
            local anchor = resolveWorldPart(folder)
            if not anchor then return nil, "WAIT_CLUE" end
            stream = {folder = folder, ready = false}
            automation.colorStream = stream
            local position = anchor.Position
            -- Loading the clue's area does not move the player. Do not count a
            -- streamed-out gem as hidden just because the farm was far away.
            local streamThread = task.spawn(function()
                local ok = pcall(function() LocalPlayer:RequestStreamAroundAsync(position, 5) end)
                if IsHubLoaded and automation.colorStream == stream then
                    stream.ready, stream.finishedAt = ok, os.clock()
                end
            end)
            table.insert(HubThreads, streamThread)
            automation.colorClue = nil
            return nil, "CLUE_SYNC"
        end
        if not stream.ready then
            if stream.finishedAt and os.clock() - stream.finishedAt >= 5 then automation.colorStream = nil end
            return nil, "CLUE_SYNC"
        end
        if os.clock() - stream.finishedAt < 1 then return nil, "CLUE_SYNC" end
    end
    local usedContainers = {}
    for _, step in ipairs(definition.Steps) do
        if type(step.Id) ~= "string" then
            automation.colorClue = nil
            automation.colorCounts = nil
            return nil, "BAD_CONFIG"
        end
        local ok, container = false, nil
        if step.Gems == nil then
            automation.colorClue = nil
            automation.colorCounts = nil
            automation.colorClueIssue = "Configuracao sem grupo de gemas para " .. step.Id .. ". Nenhum valor sera testado."
            return nil, "BAD_CONFIG"
        end
        ok, container = pcall(config.resolve, folder, step.Gems)
        if not ok or typeof(container) ~= "Instance" or not container:IsDescendantOf(folder) then
            automation.colorClue = nil
            automation.colorCounts = nil
            automation.colorClueIssue = "Grupo da pista " .. step.Id .. " ainda nao carregou."
            return nil, "WAIT_CLUE"
        end
        if usedContainers[container] then
            automation.colorClue = nil
            automation.colorCounts = nil
            return nil, "BAD_CLUE"
        end
        usedContainers[container] = true
        table.insert(sources, container)
        local gems = {}
        for _, gem in ipairs(container:GetChildren()) do
            if gem:IsA("Model") then
                local visible = gem:GetAttribute("ColorPuzzleVisible")
                if type(visible) ~= "boolean" then
                    automation.colorClueIssue = "Gema de " .. step.Id .. " ainda sem atributo de visibilidade."
                end
                table.insert(gems, {visible = visible, loaded = visible == false or resolveWorldPart(gem) ~= nil})
                table.insert(sources, gem)
            end
        end
        groups[step.Id] = gems
    end
    local targets, reason = BasementSolver.colorTargets(definition, groups)
    if not targets then
        automation.colorClue = nil
        automation.colorCounts = nil
        return nil, reason
    end
    for _, step in ipairs(definition.Steps) do
        table.insert(labels, step.Id .. "=" .. tostring(targets[step.Id]))
    end
    local signature = table.concat(labels, ", ")
    automation.colorCounts = signature
    local previous, now = automation.colorClue, os.clock()
    local same = previous and previous.signature == signature and #previous.sources == #sources
    if same then
        for index, source in ipairs(sources) do
            if previous.sources[index] ~= source then same = false; break end
        end
    end
    if not same then
        automation.colorClue = {signature = signature, sources = sources, since = now}
        return nil, "CLUE_SYNC"
    end
    -- Never act on partially arriving/initializing clue models or stale round
    -- counts. All groups and identities must settle before a counter is changed.
    if now - previous.since < 1 then return nil, "CLUE_SYNC" end
    return targets
end

function BasementSolver.position(action, definition)
    local part, model, board = BasementSolver.target(action, definition)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local camera = workspace.CurrentCamera
    if not part or not part:IsDescendantOf(workspace) then return false, "Controle ainda nao carregou no mapa." end
    if not hrp or not humanoid or humanoid.Health <= 0 or not camera then
        BasementSolver.releaseCamera(false)
        return false, "Aguardando personagem e camera."
    end
    local reach = tonumber(action.kind == "Poster" and definition.PosterDistance or definition.InteractDistance)
    if not reach or reach <= 2 then return false, "Distancia de interacao ausente na configuracao." end
    local anchor = board and board:IsA("BasePart") and board or part
    local anchorPosition = board and board:IsA("BasePart") and board.Position
        or (model:IsA("Model") and model:GetPivot().Position or part.Position)
    local aimPoint = action.kind == "Lever" and anchorPosition or part.Position
    if HubState.BasementPuzzleTeleport then
        local backside = board and board:IsA("BasePart")
            and board.CFrame:PointToObjectSpace(hrp.Position).Z >= -1
        if (hrp.Position - anchorPosition).Magnitude > reach - 2 or backside then
            local forward = Vector3.new(anchor.CFrame.LookVector.X, 0, anchor.CFrame.LookVector.Z)
            if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
            local destination = anchorPosition + forward.Unit * math.min(6, reach * 0.5)
                + Vector3.new(0, 1, 0)
            hrp.CFrame = CFrame.lookAt(destination, Vector3.new(aimPoint.X, destination.Y, aimPoint.Z))
            hrp.AssemblyLinearVelocity = Vector3.zero
            BasementState.automation.nextActionAt = os.clock() + 0.35
            return false, "Aproximando do controle..."
        end
        local automation = BasementState.automation
        if not automation.cameraLease or automation.cameraLease.camera ~= camera then
            BasementSolver.releaseCamera(false)
            automation.cameraLease = {camera = camera, cameraType = camera.CameraType,
                cframe = camera.CFrame, focus = camera.Focus}
        end
        local origin = hrp.Position + Vector3.new(0, 1.5, 0)
        if (aimPoint - origin).Magnitude < 0.01 then return false, "Ajustando mira..." end
        automation.cameraLease.aim = CFrame.lookAt(origin, aimPoint)
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = automation.cameraLease.aim
        camera.Focus = CFrame.new(aimPoint)
    else
        BasementSolver.releaseCamera(false)
    end
    if (hrp.Position - anchorPosition).Magnitude > reach then
        return false, "Auto TP desligado: aproxime-se do controle."
    end
    local direction = aimPoint - camera.CFrame.Position
    if direction.Magnitude > 0.001 and camera.CFrame.LookVector:Dot(direction.Unit)
        < (tonumber(definition.AimDot) or 0.82) then
        return false, "Auto TP desligado: mire no controle."
    end
    if board and board:IsA("BasePart") and board.CFrame:PointToObjectSpace(camera.CFrame.Position).Z >= 0 then
        return false, "Fique em frente ao quadro, nao atras."
    end
    -- findActiveStep in PuzzleClient checks pivot distance and aim, not a ray.
    if action.kind == "Lever" then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, camera}
    local hit = workspace:Raycast(camera.CFrame.Position, direction, params)
    if hit and hit.Instance ~= part and hit.Instance ~= model and not hit.Instance:IsDescendantOf(model) then
        return false, "Mira bloqueada por um objeto."
    end
    return true
end

function BasementSolver.sync()
    local automation = BasementState.automation
    if BasementState.remote and os.clock() - automation.lastSyncAt >= 2 then
        automation.lastSyncAt = os.clock()
        pcall(function() BasementState.remote:FireServer() end)
    end
end

function BasementSolver.tick()
    local automation = BasementState.automation
    local now = os.clock()
    if not IS_BASEMENT or not HubState.BasementAutoPuzzles then
        automation.active = false
        if not HubState.AutoWinNeedle then
            automation.exitActive = false
            automation.exitTeleport = false
        end
        automation.pending = nil
        automation.currentAction = nil
        automation.status = "Desligado"
        BasementSolver.releaseCamera(LocalPlayer:GetAttribute("CutsceneActive") == true)
        return
    end
    local hay = ReplicatedStorage:FindFirstChild("NeedleHaystack")
    local claimed = hay and hay:GetAttribute("NeedleClaimed") == true or false
    local targetId = Landmarks.TargetNeedleHayId
    if (automation.wasClaimed and not claimed)
        or (automation.targetId and targetId and automation.targetId ~= targetId) then
        BasementSolver.resetRound()
    end
    automation.wasClaimed = claimed
    automation.targetId = targetId or automation.targetId
    if not BasementState.folder then
        automation.active = false
        automation.status = "Puzzles ainda nao carregaram no servidor."
        BasementSolver.releaseCamera(false)
        return
    end
    local cutscene = LocalPlayer:GetAttribute("CutsceneActive") == true
    if automation.exitCompleted or LocalPlayer:GetAttribute("NeedleRoundComplete") == true
        or (hay and hay:GetAttribute("WinnerUserId") ~= nil) then
        automation.active = false
        automation.pending = nil
        automation.status = BasementSolver.exit(HubState.BasementPuzzleTeleport, false)
        return
    end
    local leverSolved = BasementState.folder:GetAttribute("LeverPuzzleSolved") == true
    if leverSolved and automation.wasLeverSolved == false and not automation.doorReadyAt then
        -- Covers joining/running without receiving PuzzleSolved's timing event.
        local definition = BasementState.config and BasementState.config.Puzzles and BasementState.config.Puzzles.LeverPuzzle
        local sliding = definition and definition.Reward and definition.Reward.Kind == "SlidingDoor"
        automation.doorReadyAt = now + (sliding and 5.95 or 0.55)
        automation.doorPuzzleId = "LeverPuzzle"
    end
    automation.wasLeverSolved = leverSolved
    local phase, nextPuzzle = BasementSolver.phase(leverSolved, now, automation.doorReadyAt,
        BasementState.snapshot, BasementState.requiredPuzzles)
    automation.phase = phase
    if phase == "DONE" then
        automation.active = false
        automation.pending = nil
        automation.currentAction = nil
        automation.status = BasementSolver.exit(HubState.BasementPuzzleTeleport, true)
        return
    end
    automation.active = true
    automation.exitActive = false
    automation.exitTeleport = false
    ToolRuntime.stopVacuumAutomation()
    if cutscene or LocalPlayer:GetAttribute("NeedleInputLocked") == true
        or LocalPlayer:GetAttribute("HintViewerOpen") == true then
        automation.status = "Pausado durante cena ou interface do jogo."
        BasementSolver.releaseCamera(cutscene)
        return
    end
    if phase == "DOOR" then
        automation.status = "Alavancas/puzzle concluidos; aguardando a porta terminar de abrir."
        automation.currentAction = nil
        BasementSolver.releaseCamera(false)
        return
    end
    if not BasementState.config or not BasementState.folder then
        automation.status = "Aguardando configuracao dos puzzles."
        return
    end
    BasementSolver.sync()
    if FarmRuntime.isCurrentlySelling or ToolRuntime.tntComboInProgress then
        automation.status = "Aguardando terminar venda/TNT."
        return
    end
    local definitions = BasementState.config.Puzzles
    if type(definitions) ~= "table" then automation.status = "Configuracao de puzzles indisponivel."; return end
    local pending = automation.pending
    if pending then
        local state = BasementSolver.snapshot(pending.action.puzzleId)
        local token = BasementSolver.token(pending.action)
        if BasementSolver.acknowledged(pending.action, state) then
            automation.attempts[token] = nil
            automation.blockedUntil[token] = nil
            automation.pending = nil
            automation.currentAction = nil
            automation.nextActionAt = now + 0.4
        elseif pending.action.kind == "Counter" and state and type(state.values) == "table"
            and type(state.values[pending.action.stepId]) == "number"
            and state.values[pending.action.stepId] ~= pending.action.before then
            -- Another click/player changed the counter unexpectedly. Re-read the
            -- live value and clue; never advance a cached combination search.
            automation.pending = nil
            automation.currentAction = nil
            automation.attempts[token] = nil
            automation.blockedUntil[token] = nil
            automation.nextActionAt = now + 0.4
            automation.details.ColorPuzzle = "Contador alterado; relendo a pista e o valor atual."
        elseif pending.action.kind == "Submit" and (automation.submitRejectedAt or 0) >= pending.sentAt then
            automation.pending = nil
            automation.blockedUntil[token] = now + 15
            automation.details.NumberPuzzle = "Codigo recusado pelo servidor; aguardando sincronizacao."
        elseif now - pending.sentAt < 5 then
            automation.status = "Aguardando confirmacao: " .. (BasementPuzzleLabels[pending.action.puzzleId] or "Alavancas")
            return
        else
            automation.pending = nil
            if (automation.attempts[token] or 0) >= 3 then
                automation.blockedUntil[token] = now + 20
                automation.attempts[token] = nil
            else
                automation.nextActionAt = now + 1
            end
            automation.details[pending.action.puzzleId] = "Servidor nao confirmou; nova tentativa com intervalo."
        end
    end
    if now < automation.nextActionAt then return end
    -- Only the next stage may act. Do not jump past locked doors to another puzzle.
    local order = {nextPuzzle}
    for _, id in ipairs(order) do
        local definition, state = definitions[id], BasementSolver.snapshot(id)
        local action, reason
        if type(definition) ~= "table" or not state then
            automation.details[id] = "Aguardando configuracao/estado replicado."
        elseif state.completed == true then
            automation.details[id] = "Concluido pelo servidor."
        else
            if id == "LeverPuzzle" then action, reason = BasementSolver.lever(definition, state)
            elseif id == "NumberPuzzle" then action, reason = BasementSolver.number(definition, state, BasementSolver.posters(definition))
            elseif id == "PicturePuzzle" then action, reason = BasementSolver.picture(definition, state)
            elseif id == "ColorPuzzle" then
                local targets
                targets, reason = BasementSolver.readColorTargets(definition)
                if targets then action, reason = BasementSolver.color(definition, state, targets) end
            end
            if action then
                local token = BasementSolver.token(action)
                if now >= (automation.blockedUntil[token] or 0) then
                    automation.currentAction = action
                    local ready, notice = BasementSolver.position(action, definition)
                    automation.status = (BasementPuzzleLabels[id] or "Alavancas") .. ": " .. (notice or "interagindo...")
                    automation.details[id] = notice or (id == "ColorPuzzle"
                        and ("Pista lida: " .. tostring(automation.colorCounts) .. ". Ajustando " .. action.stepId
                            .. " para " .. tostring(action.goal) .. ".") or "Resolvendo automaticamente...")
                    if not ready then return end
                    local remote = BasementState.folder:FindFirstChild("PuzzleAction")
                    if not remote or not remote:IsA("RemoteEvent") then automation.status = "PuzzleAction indisponivel."; return end
                    automation.pending = {action = action, sentAt = now}
                    automation.attempts[token] = (automation.attempts[token] or 0) + 1
                    local ok = pcall(function()
                        if action.kind == "Submit" then remote:FireServer(id, "Submit", action.code)
                        elseif action.kind == "Poster" then remote:FireServer(id, "Poster", action.index)
                        else remote:FireServer(id, action.stepId) end
                    end)
                    if not ok then automation.pending = nil; automation.nextActionAt = now + 2 end
                    return
                end
            else
                local notices = {WAIT_CODE = "Aguardando codigo/cartazes carregarem.", WAIT_STATE = "Aguardando estado completo.",
                    WAIT_SERVER = "Aguardando conclusao pelo servidor.", BAD_CONFIG = "Configuracao nao reconhecida.",
                    BAD_STATE = "Contador fora do intervalo configurado.", WAIT_CLUE = "Aguardando gemas/pista de cores carregarem.",
                    CLUE_SYNC = "Sincronizando pista de cores...", BAD_CLUE = "Pista de cores incompleta ou fora do intervalo."}
                automation.details[id] = notices[reason] or "Aguardando..."
                if id == "ColorPuzzle" and automation.colorClueIssue then
                    automation.details[id] = automation.colorClueIssue
                end
                if id == "ColorPuzzle" and reason == "WAIT_SERVER" then
                    automation.details[id] = "Contadores iguais a pista: " .. tostring(automation.colorCounts)
                        .. ". Aguardando conclusao pelo servidor."
                end
            end
        end
    end
    automation.status = (BasementPuzzleLabels[nextPuzzle] or "Alavancas") .. ": "
        .. (automation.details[nextPuzzle] or "aguardando confirmacao.")
    BasementSolver.releaseCamera(false)
end

table.insert(HubConnections, RunService.RenderStepped:Connect(function()
    local automation = BasementState.automation
    local lease = automation.cameraLease
    if not lease or not lease.aim then return end
    local ownsCamera = HubState.BasementAutoPuzzles and HubState.BasementPuzzleTeleport
        or automation.exitActive and automation.exitTeleport and HubState.AutoWinNeedle
    if LocalPlayer:GetAttribute("CutsceneActive") == true or LocalPlayer:GetAttribute("NeedleInputLocked") == true then
        BasementSolver.releaseCamera(true)
    elseif not IsHubLoaded or not ownsCamera then
        BasementSolver.releaseCamera(false)
    elseif (automation.active or automation.exitActive) and lease.camera == workspace.CurrentCamera then
        lease.camera.CFrame = lease.aim
    end
end))

local basementPuzzleThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(0.2)
        local ok, err = pcall(BasementSolver.tick)
        if not ok then
            BasementState.automation.status = "Falha no solver; veja Atividade."
            BasementSolver.releaseCamera(LocalPlayer:GetAttribute("CutsceneActive") == true)
            if os.clock() - BasementState.automation.lastErrorAt >= 10 then
                BasementState.automation.lastErrorAt = os.clock()
                addLog("warn", "Auto Puzzles: " .. tostring(err))
            end
        end
    end
    BasementSolver.releaseCamera(false)
end)
table.insert(HubThreads, basementPuzzleThread)

local farmThread = task.spawn(function()
    while IsHubLoaded do
        local equippedSlot = getCurrentEquippedSlot()
        local cooldown = getPickCooldown()
        if equippedSlot == SLOT_VACUUM and isVacuumReady() then
            cooldown = tonumber(HaystackConfig and HaystackConfig.VACUUM_TICK) or 0.16
        elseif equippedSlot == SLOT_PITCHFORK then
            cooldown = tonumber(LocalPlayer:GetAttribute("PitchforkCooldown"))
                or tonumber(HaystackConfig and HaystackConfig.PITCHFORK_COOLDOWN)
                or 0.85
        end
        task.wait(cooldown)

        local basementExitReady = IS_BASEMENT and HubState.AutoWinNeedle
            and LocalPlayer:GetAttribute("NeedleOwned") == true
            and BasementState.folder and BasementState.folder:GetAttribute("EscapeReady") == true
        if (HubState.AutoFarmHay or HubState.AutoSell) and IS_GAMEPLAY and not FarmRuntime.isCurrentlySelling
            and not ToolRuntime.tntComboInProgress and not basementExitReady
            and not BasementSolver.isBusy() then
            local hrp = getHRP()
            local char = getCharacter()

            if hrp and char then
                local currentHay = getHayHeld()
                local maxCap = getHayCapacity()

                -- FULL BAG CHECK -> COMPLETE AUTONOMOUS SELL CYCLE
                if currentHay >= maxCap and maxCap > 0 and not HubState.AutoSell then
                    ToolRuntime.stopVacuumAutomation()
                elseif currentHay >= maxCap and maxCap > 0 and HubState.AutoSell then
                    ToolRuntime.stopVacuumAutomation()
                    if HubState.NoTeleportMode then
                        local now = os.clock()
                        local sellDistance = (hrp.Position - Landmarks.SellCow).Magnitude
                        local sellReach = (tonumber(HaystackConfig and HaystackConfig.SELL_INTERACT_DISTANCE) or 20) + 5
                        if Remotes.SellHay and sellDistance <= sellReach
                            and now - FarmRuntime.lastNoTeleportSellAttemptAt >= 1.25 then
                            FarmRuntime.lastNoTeleportSellAttemptAt = now
                            pcall(function() Remotes.SellHay:FireServer() end)
                        end
                        if now - FarmRuntime.lastNoTeleportNoticeAt >= 8 then
                            FarmRuntime.lastNoTeleportNoticeAt = now
                            addLog("info", string.format("Bolsa cheia. Para vender sem teleporte, aproxime-se e olhe para a vaca (%.0f studs).", sellDistance))
                        end
                    else
                        FarmRuntime.isCurrentlySelling = true
                        addLog("info", "Bag full (" .. currentHay .. "/" .. maxCap .. "). Travelling to Sell Cow...")

                        local farmReturnCFrame = hrp.CFrame
                        scanExactLandmarks()
                        teleportTo(Landmarks.SellCow)
                        task.wait(0.2)

                        if Remotes.SellHay then
                            pcall(function() Remotes.SellHay:FireServer() end)
                        end

                        local sellTimeout = os.clock()
                        while getHayHeld() > 0 and (os.clock() - sellTimeout) < 0.6 do
                            task.wait(0.06)
                            if Remotes.SellHay then pcall(function() Remotes.SellHay:FireServer() end) end
                        end

                        addLog("info", "Hay sold! Returning to harvest...")
                        teleportTo(farmReturnCFrame)
                        task.wait(0.12)
                        FarmRuntime.isCurrentlySelling = false
                    end
                elseif HubState.AutoFarmHay then
                    local myPos = hrp.Position
                    local haystack = workspace:FindFirstChild("HaystackClient")
                    if haystack then getNeedleDigAnchor(haystack) end
                    -- 1. Intelligent Tool Recognition & Auto-Equip
                    local activeSlot = getCurrentEquippedSlot()
                    if HubState.AutoEquipBestTool then
                        -- Hand picks let us exclude the hidden target ID while
                        -- satisfying its depth/pick requirements. Wide tools can
                        -- consume it prematurely and force a server retarget.
                        local bestSlot = NeedleProtection.isNear(hrp.Position, 3)
                            and SLOT_HAND or getBestAvailableToolSlot()
                        if activeSlot ~= bestSlot then
                            if equipToolSlot(bestSlot) then
                                activeSlot = getCurrentEquippedSlot()
                            end
                        end
                    end

                    -- 2. Rare strands anywhere in the rendered pile, constrained
                    -- only by the active tool's real reach in no-teleport mode.
                    local rgbStrands = {}
                    if HubState.PrioritizeRGB then
                        rgbStrands = getAllRainbowStrands()
                    end

                    local targetRgb = nil
                    if #rgbStrands > 0 then
                        local reachableRare = {}
                        for _, candidate in ipairs(rgbStrands) do
                            local isDropped = candidate.Parent and candidate.Parent.Name == "DroppedHay"
                            local reachable = isDropped and (candidate.Position - myPos).Magnitude <= 20
                                or isHayWithinReach(candidate, myPos, activeSlot)
                            if not HubState.NoTeleportMode or reachable then
                                if isDropped or candidate.Parent == haystack then
                                    table.insert(reachableRare, candidate)
                                end
                            end
                        end
                        targetRgb = chooseRareHayPart(reachableRare, myPos, math.huge)
                    end

                    if targetRgb then
                        local targetPos = targetRgb.Position
                        local rId = targetRgb:GetAttribute("HayId")

                        if not HubState.NoTeleportMode
                            and not isHayWithinReach(targetRgb, myPos, activeSlot) then
                            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 0.6, 0))
                            -- Rares bypass dwell/coverage. Drop the interrupted
                            -- corner so it cannot make the next normal tick farm
                            -- around this temporary rare teleport by mistake.
                            clearAutoFarmCorner()
                            task.wait(0.04)
                        end

                        if targetRgb.Parent and targetRgb.Parent.Name == "DroppedHay" then
                            if Remotes.PickDroppedHay then
                                pcall(function() Remotes.PickDroppedHay:FireServer(targetRgb) end)
                            end
                        elseif rId then
                            if harvestWithEquippedTool(targetRgb) then
                                FarmDigState.lastDigHayId = rId
                                recordNeedleAreaAction(targetRgb.Position, rId)
                            end
                        end
                    else
                        -- 3. NORMAL HAY HARVESTING (when 0 RGB straws remain on field)
                        if haystack then
                            local reach = getToolReach(activeSlot)
                            local primaryPart, shouldTeleport = chooseAutoFarmHayPart(haystack, hrp, reach)

                            if primaryPart then
                                if shouldTeleport and not HubState.NoTeleportMode then
                                    hrp.CFrame = CFrame.new(primaryPart.Position + Vector3.new(0, 0.6, 0))
                                    task.wait(0.04)
                                end

                                local selectedHayId = primaryPart:GetAttribute("HayId")
                                if harvestWithEquippedTool(primaryPart) then
                                    FarmDigState.lastDigHayId = selectedHayId
                                    recordNeedleAreaAction(primaryPart.Position, selectedHayId)
                                end
                            elseif HubState.NoTeleportMode and os.clock() - FarmRuntime.lastNoReachNoticeAt >= 8 then
                                FarmRuntime.lastNoReachNoticeAt = os.clock()
                                addLog("info", "Sem feno ao alcance da ferramenta. Aproxime-se do feno; seu personagem continua livre.")
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
        else
            ToolRuntime.stopVacuumAutomation()
        end
    end
end)
table.insert(HubThreads, farmThread)

-- 8.1b AUTONOMOUS TNT RECURRING CLEAVER ENGINE
local tntThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(1)
        local basementExitReady = IS_BASEMENT and HubState.AutoWinNeedle
            and LocalPlayer:GetAttribute("NeedleOwned") == true
            and BasementState.folder and BasementState.folder:GetAttribute("EscapeReady") == true
        if HubState.AutoUseTnt and IS_GAMEPLAY and not FarmRuntime.isCurrentlySelling
            and not ToolRuntime.tntComboInProgress and not basementExitReady
            and not BasementSolver.isBusy() then
            local hrp = getHRP()
            if hrp and isToolOwned("Tnt") then
                local currentHay = getHayHeld()
                local maxCap = getHayCapacity()
                local now = os.clock()
                local serverCooldown = tonumber(LocalPlayer:GetAttribute("TntCooldown"))
                    or tonumber(HaystackConfig and HaystackConfig.TNT_COOLDOWN)
                    or 20
                local cd = math.max(serverCooldown, tonumber(HubState.TntInterval) or serverCooldown)
                if (now - ToolRuntime.lastAutoTntThrow) >= cd and (maxCap - currentHay) >= 10 then
                    local target = chooseTntTarget(hrp)
                    if target then throwTntAt(target) end
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
        if HubState.AutoCollectGems and IS_GAMEPLAY and Remotes.CollectGem
            and not BasementSolver.isBusy() then
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
                            elseif not HubState.NoTeleportMode and HubState.AutoFarmHay and dist <= 45 then
                                -- Quick hop to grab gem
                                local prev = hrp.CFrame
                                teleportTo(gemPos + Vector3.new(0, 1.5, 0))
                                task.wait(0.05)
                                pcall(function() Remotes.CollectGem:FireServer(gemId) end)
                                teleportTo(prev)
                            end
                        elseif not HubState.NoTeleportMode then
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
        if HubState.AutoCollectGems and not HubState.NoTeleportMode and Remotes.CollectGem and gemId then
            if not BasementSolver.isBusy() then pcall(function() Remotes.CollectGem:FireServer(gemId) end) end
        end
    end)
    table.insert(HubConnections, conn)
end

-- 8.3 AUTO-WIN NEEDLE ENGINE
local lastNeedleMovementNoticeAt = 0
local needleThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(0.4)
        if HubState.AutoWinNeedle and IS_GAMEPLAY
            and not (IS_BASEMENT and HubState.BasementAutoPuzzles and BasementSolver.isBusy())
            and not (IS_BASEMENT and (BasementState.automation.exitCompleted
                or LocalPlayer:GetAttribute("NeedleRoundComplete") == true)) then
            local needleOwned = LocalPlayer:GetAttribute("NeedleOwned")

            if needleOwned then
                if IS_BASEMENT then
                    BasementSolver.exit(not HubState.NoTeleportMode)
                else
                    equipToolSlot(SLOT_NEEDLE)
                    scanExactLandmarks()
                    local hrp = getHRP()
                    local farmerDistance = hrp and (hrp.Position - Landmarks.FarmerNPC).Magnitude or math.huge
                    if not HubState.NoTeleportMode or farmerDistance <= 12 then
                        if not HubState.NoTeleportMode then
                            teleportTo(Landmarks.FarmerNPC)
                            task.wait(0.2)
                        end
                        if Remotes.NeedleHandIn then
                            pcall(function() Remotes.NeedleHandIn:FireServer() end)
                        end
                    elseif os.clock() - lastNeedleMovementNoticeAt >= 8 then
                        lastNeedleMovementNoticeAt = os.clock()
                        addLog("info", string.format("Agulha coletada. Aproxime-se do fazendeiro para entregar sem teleporte (%.0f studs).", farmerDistance))
                    end
                end
            else
                local roundFolder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
                local revealed = roundFolder and roundFolder:GetAttribute("NeedleRevealed") == true
                local needlePart = revealed and findVisibleNeedleObjective() or nil
                if needlePart then
                    local hrp = getHRP()
                    local needleDistance = hrp and (needlePart.Position - hrp.Position).Magnitude or math.huge
                    if not HubState.NoTeleportMode then
                        teleportTo(needlePart.Position + Vector3.new(0, 1.2, 0))
                        task.wait(0.08)
                    end
                    local interactDistance = tonumber(HaystackConfig and HaystackConfig.INTERACT_DISTANCE) or 20
                    if Remotes.PickHay and (not HubState.NoTeleportMode or needleDistance <= interactDistance) then
                        pcall(function() Remotes.PickHay:FireServer("Objective") end)
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
        if HubState.AutoDeployDrone and IS_GAMEPLAY and Remotes.DeployDrone
            and not BasementSolver.isBusy()
            and not (NeedleProtection.anchor and not NeedleProtection.ready) then
            if isToolOwned("Drone") and LocalPlayer:GetAttribute("DroneDeployed") ~= true then
                pcall(function() Remotes.DeployDrone:FireServer() end)
                addLog("info", "Auto-deployed Hay Drone companion!")
            end
        end
    end
end)
table.insert(HubThreads, droneThread)

-- 8.5 PRICE-AWARE AUTO-BUY TOOLS & UPGRADES
local barnToolNames = {"Pitchfork", "Tnt", "Drone", "Vacuum"}
local BarnToolDisplayNames = {
    Pitchfork = "Forquilha",
    Tnt = "Dinamite",
    Drone = "Drone agricola",
    Vacuum = "Aspirador",
}
local UpgradeToolRequirements = {
    TntLuck = "Tnt", TntCooldown = "Tnt", TntPower = "Tnt",
    PitchforkCooldown = "Pitchfork", PitchforkHold = "Pitchfork", Pitchfork = "Pitchfork",
    DroneSpeed = "Drone", DroneGrab = "Drone", DroneCapacity = "Drone",
    VacuumPower = "Vacuum", VacuumCooling = "Vacuum", VacuumRuntime = "Vacuum",
}
local upgradeTracks = {
    "Capacity", "HandHold", "Speed", "Grab",
    "PitchforkCooldown", "PitchforkHold", "Pitchfork",
    "TntLuck", "TntCooldown", "TntPower",
    "DroneSpeed", "DroneGrab", "DroneCapacity",
    "VacuumPower", "VacuumCooling", "VacuumRuntime",
}
local PendingToolPurchases = {}
local PendingUpgradePurchases = {}

local function getCashBalance()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    return math.max(0, tonumber(cash and cash.Value) or 0)
end

local function formatCash(value)
    -- Cash and Config.Levels.Cost are already decimal currency values.
    local cents = math.max(0, math.round((tonumber(value) or 0) * 100))
    local dollars = math.floor(cents / 100)
    local digits = tostring(dollars):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return "$" .. digits .. string.format(".%02d", cents % 100)
end

local function parseShopPrice(rawPrice)
    local numeric = tonumber(rawPrice)
    if numeric then return numeric end
    if type(rawPrice) ~= "string" then return nil end
    local cleaned = rawPrice:gsub(",", ""):gsub("[^%d%.]", "")
    return tonumber(cleaned)
end

local RobuxPrices = {
    cache = {},
    pending = {},
    failureAt = {},
}
local function getRobuxPrice(kind, productId)
    local id = tonumber(productId)
    if (kind ~= "Product" and kind ~= "GamePass") or not id or id <= 0 then return nil end
    local key = kind .. ":" .. tostring(id)
    if RobuxPrices.cache[key] == false and os.clock() - (RobuxPrices.failureAt[key] or 0) >= 30 then
        RobuxPrices.cache[key] = nil
    end
    if RobuxPrices.cache[key] ~= nil then return RobuxPrices.cache[key] or nil end
    if not RobuxPrices.pending[key] then
        RobuxPrices.pending[key] = true
        task.spawn(function()
            local marketplace = safeService("MarketplaceService")
            local infoType = kind == "GamePass" and Enum.InfoType.GamePass or Enum.InfoType.Product
            local ok, result = pcall(function() return marketplace:GetProductInfoAsync(id, infoType) end)
            RobuxPrices.pending[key] = nil
            if IsHubLoaded then
                RobuxPrices.cache[key] = (ok and type(result) == "table" and tonumber(result.PriceInRobux)) or false
                if RobuxPrices.cache[key] == false then RobuxPrices.failureAt[key] = os.clock() end
            end
        end)
    end
    return nil
end

local function findBarnShopItem(itemId)
    local barnShop = workspace:FindFirstChild("BarnShop")
    if not barnShop then return nil end
    for _, item in ipairs(barnShop:GetDescendants()) do
        if item:IsA("BasePart") and item.Name == "ShopHitbox" then
            local shopModel = item.Parent
            if shopModel and shopModel:GetAttribute("ShopItemId") == itemId then return shopModel end
        end
    end
    -- Compatibility with shop variants that publish the item without a hitbox.
    for _, item in ipairs(barnShop:GetDescendants()) do
        if item:GetAttribute("ShopItemId") == itemId then return item end
    end
    return nil
end

local function getBarnToolInfo(itemId)
    local item = findBarnShopItem(itemId)
    local info = {
        id = itemId,
        displayName = BarnToolDisplayNames[itemId] or itemId,
        item = item,
        options = {},
        purchaseOption = nil,
    }
    if not item then return info end
    info.displayName = tostring(item:GetAttribute("ShopName") or info.displayName)
    for _, suffix in ipairs({"A", "B", "C"}) do
        local currency = item:GetAttribute("ShopCurrency" .. suffix)
        local rawPrice = item:GetAttribute("ShopPrice" .. suffix)
        if currency and rawPrice ~= nil and tostring(rawPrice) ~= "" then
            local option = {
                currency = tostring(currency),
                price = parseShopPrice(rawPrice),
                rawPrice = tostring(rawPrice),
                robuxKind = item:GetAttribute("ShopRobuxKind" .. suffix),
                robuxId = item:GetAttribute("ShopRobuxId" .. suffix),
            }
            if option.currency == "Robux" then
                option.price = getRobuxPrice(option.robuxKind, option.robuxId)
                if not option.price then
                    local sign = item:FindFirstChild("Price", true)
                    local worldText = sign and sign:IsA("TextLabel") and sign.Text or ""
                    option.price = tonumber(worldText:match("^%s*R%$%s*(%d+)%s*$"))
                end
            elseif option.currency ~= "Coins" and option.currency ~= "Cash" and option.currency ~= "Gems" then
                option.price = nil
            end
            table.insert(info.options, option)
            if (option.currency == "Coins" or option.currency == "Cash") and option.price then
                info.purchaseOption = option
            elseif option.currency == "Gems" and option.price and not info.purchaseOption then
                info.purchaseOption = option
            end
        end
    end
    return info
end

local function formatShopOption(option)
    if option.currency == "Robux" then
        return option.price and (formatNumber(option.price) .. " Robux") or "Robux (valor indisponivel)"
    end
    if option.currency == "Gems" then
        return (option.price and formatNumber(option.price) or option.rawPrice) .. " gemas"
    end
    if option.currency == "Coins" or option.currency == "Cash" then
        return (option.price and formatCash(option.price) or option.rawPrice) .. " moedas"
    end
    return option.rawPrice .. " (" .. option.currency .. ")"
end

local function formatBarnToolPrice(info)
    if #info.options == 0 then return "sem preco publicado nesta partida" end
    local labels = {}
    for _, option in ipairs(info.options) do table.insert(labels, formatShopOption(option)) end
    return table.concat(labels, " / ")
end

local function requestBarnToolPurchase(itemId, manual)
    if isToolOwned(itemId) then
        PendingToolPurchases[itemId] = nil
        if manual then addLog("info", (BarnToolDisplayNames[itemId] or itemId) .. " ja esta comprada.") end
        return false, "OWNED"
    end
    if not Remotes.BuyShopItem then return false, "REMOTE" end

    local pendingAt = PendingToolPurchases[itemId]
    if pendingAt and os.clock() - pendingAt < 5 then return false, "PENDING" end
    local info = getBarnToolInfo(itemId)
    if not info.item or #info.options == 0 then
        if manual then addLog("warn", "A loja desta partida nao publicou uma opcao de compra para " .. info.displayName .. ".") end
        return false, "PRICE"
    end
    local option = info.purchaseOption
    if not option then
        if manual then addLog("warn", info.displayName .. " so tem opcao Robux: " .. formatBarnToolPrice(info) .. ". Use a loja oficial do jogo para confirmar a compra.") end
        return false, "ROBUX_ONLY"
    end
    if not manual and option.currency == "Gems" then
        -- Auto Buy may spend gems only on the explicitly requested round Drone.
        -- Read its live price, but never exceed the authorized 40-gem purchase.
        if itemId ~= "Drone" then return false, "GEMS_AUTO_DISABLED" end
        if option.price < 1 or option.price > 40 or option.price % 1 ~= 0 then return false, "PRICE" end
    end
    -- The in-match shop uses the player's replicated Gems attribute. Prefer it
    -- over a potentially lagging account/reactive snapshot for this purchase.
    local balance = option.currency == "Gems"
        and math.max(0, math.floor(tonumber(LocalPlayer:GetAttribute("Gems")) or getGemBalance()))
        or getCashBalance()
    if balance < option.price then
        if manual then
            addLog("warn", string.format("Saldo insuficiente: %s custa %s; faltam %s.", info.displayName, formatShopOption(option), formatShopOption({currency = option.currency, price = option.price - balance})))
        end
        return false, option.currency == "Gems" and "GEMS" or "CASH"
    end

    PendingToolPurchases[itemId] = os.clock()
    local ok = pcall(function()
        Remotes.BuyShopItem:FireServer(itemId)
    end)
    if not ok then PendingToolPurchases[itemId] = nil end
    if ok and (manual or (itemId == "Drone" and option.currency == "Gems")) then
        addLog("info", "Compra solicitada: " .. info.displayName .. " por " .. formatShopOption(option) .. ".")
    end
    return ok, ok and "SENT" or "ERROR"
end

local function getUpgradeState(track)
    local config = HaystackConfig and HaystackConfig.UPGRADE_TRACKS and HaystackConfig.UPGRADE_TRACKS[track]
    if type(config) ~= "table" or type(config.Levels) ~= "table" then return nil end
    local maxLevel = #config.Levels
    local level = math.clamp(tonumber(LocalPlayer:GetAttribute("HayUpgrade" .. track)) or 1, 1, maxLevel)
    local nextLevel = config.Levels[level + 1]
    local cost = nextLevel and tonumber(nextLevel.Cost) or nil
    if cost then
        cost = cost * (tonumber(LocalPlayer:GetAttribute("UpgradeCostMultiplier")) or 1)
        if string.sub(track, 1, 9) == "Pitchfork" then
            cost = cost * (tonumber(LocalPlayer:GetAttribute("PitchforkUpgradeCostMultiplier")) or 1)
        end
        cost = math.round(cost * 100) / 100
    end
    local requiredTool = UpgradeToolRequirements[track]
    return {
        track = track,
        displayName = tostring(config.DisplayName or track),
        description = tostring(config.Description or ""),
        level = level,
        maxLevel = maxLevel,
        cost = cost,
        requiredTool = requiredTool,
        available = not requiredTool or isToolOwned(requiredTool),
    }
end

local function requestSessionUpgrade(track, manual)
    if not Remotes.BuyUpgrade then return false, "REMOTE" end
    local state = getUpgradeState(track)
    if not state then return false, "CONFIG" end
    if not state.available then
        if manual then addLog("warn", "Compre " .. (BarnToolDisplayNames[state.requiredTool] or state.requiredTool) .. " antes desta melhoria.") end
        return false, "LOCKED"
    end
    if not state.cost then
        if manual then addLog("info", state.displayName .. " ja esta no nivel maximo.") end
        return false, "MAX"
    end
    local pendingAt = PendingUpgradePurchases[track]
    if pendingAt and os.clock() - pendingAt < 5 then return false, "PENDING" end
    local cash = getCashBalance()
    if cash < state.cost then
        if manual then addLog("warn", string.format("Saldo insuficiente: %s custa %s; faltam %s.", state.displayName, formatCash(state.cost), formatCash(state.cost - cash))) end
        return false, "CASH"
    end
    PendingUpgradePurchases[track] = os.clock()
    local ok = pcall(function()
        Remotes.BuyUpgrade:FireServer(track)
    end)
    if not ok then PendingUpgradePurchases[track] = nil end
    if manual and ok then addLog("info", "Melhoria solicitada: " .. state.displayName .. " por " .. formatCash(state.cost) .. ".") end
    return ok, ok and "SENT" or "ERROR"
end

if Remotes.ShopPurchaseResult then
    local conn = Remotes.ShopPurchaseResult.OnClientEvent:Connect(function(success, itemId, reason)
        PendingToolPurchases[itemId] = nil
        local displayName = BarnToolDisplayNames[itemId] or tostring(itemId)
        if success then
            addLog("info", displayName .. " comprada com sucesso.")
            if HubState.AutoEquipBestTool then
                task.defer(function()
                    if BasementSolver.isBusy() then return end
                    local bestSlot = getBestAvailableToolSlot()
                    equipToolSlot(bestSlot, true)
                end)
            end
        elseif reason ~= "OWNED" then
            local message = reason == "CASH" and "saldo insuficiente" or (reason == "GEMS" and "gemas insuficientes" or "compra indisponivel")
            addLog("warn", "Falha ao comprar " .. displayName .. ": " .. message .. ".")
        end
    end)
    table.insert(HubConnections, conn)
end

for toolId, attributes in pairs(ToolOwnershipAttributes) do
    local ownershipAttribute = attributes[1]
    if toolId ~= "Needle" and ownershipAttribute then
        local capturedToolId = toolId
        local capturedOwnershipAttribute = ownershipAttribute
        local conn = LocalPlayer:GetAttributeChangedSignal(ownershipAttribute):Connect(function()
            if LocalPlayer:GetAttribute(capturedOwnershipAttribute) == true then
                PendingToolPurchases[capturedToolId] = nil
                if HubState.AutoEquipBestTool then
                    task.defer(function()
                        if BasementSolver.isBusy() then return end
                        local bestSlot = getBestAvailableToolSlot()
                        equipToolSlot(bestSlot, true)
                    end)
                end
            end
        end)
        table.insert(HubConnections, conn)
    end
end

for _, track in ipairs(upgradeTracks) do
    local capturedTrack = track
    local conn = LocalPlayer:GetAttributeChangedSignal("HayUpgrade" .. capturedTrack):Connect(function()
        PendingUpgradePurchases[capturedTrack] = nil
    end)
    table.insert(HubConnections, conn)
end

local autoBuyThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(1.5)
        if IS_GAMEPLAY and not BasementSolver.isBusy() then
            -- Buy a single progression item per cycle. This prevents prompt/event spam.
            local purchaseSent = false
            if HubState.AutoBuyTools then
                for _, toolName in ipairs(barnToolNames) do
                    if not isToolOwned(toolName) then
                        local sent = requestBarnToolPurchase(toolName, false)
                        if sent then purchaseSent = true; break end
                    end
                end
            end
            if HubState.AutoBuyUpgrades and not purchaseSent then
                for _, track in ipairs(upgradeTracks) do
                    local state = getUpgradeState(track)
                    if state and state.available and state.cost and getCashBalance() >= state.cost then
                        local sent = requestSessionUpgrade(track, false)
                        if sent then break end
                    end
                end
            end
        end
    end
end)
table.insert(HubThreads, autoBuyThread)

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
local ESPParent = LocalPlayer:WaitForChild("PlayerGui")
local activeBillboards = {}
local seenBillboards = {}

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
        -- BillboardGui renders reliably as a PlayerGui child with a Workspace Adornee.
        bb.Parent = ESPParent

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
    if lbl then lbl.Text = text; lbl.TextColor3 = color end
    seenBillboards[key] = true
end

local function removeBillboard(key)
    if activeBillboards[key] then
        activeBillboards[key]:Destroy()
        activeBillboards[key] = nil
    end
end

local espThread = task.spawn(function()
    while IsHubLoaded do
        task.wait(0.5)
        seenBillboards = {}
        local myHRP = getHRP()
        local myPos = myHRP and myHRP.Position or Vector3.new(0, 0, 0)

        -- 1. Sell Zone ESP
        if HubState.SellESP and IS_GAMEPLAY then
            local nearest, nearestDistance = nil, math.huge
            for _, part in ipairs(CollectionService:GetTagged("SellPart")) do
                if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
                    local distance = (myPos - part.Position).Magnitude
                    if distance < nearestDistance then nearest, nearestDistance = part, distance end
                end
            end
            if nearest then
                updateBillboard("SellZone", nearest, "VENDA [" .. math.floor(nearestDistance) .. " studs]", Color3.fromRGB(50, 220, 255))
            end
        end

        if IS_BASEMENT and HubState.BasementGuideESP then
            local objectiveText, objectivePart = getBasementNextObjective()
            if objectivePart and (objectiveText ~= "Encontre a chave no feno" or not HubState.NeedleESP) then
                local distance = math.floor((myPos - objectivePart.Position).Magnitude)
                updateBillboard("BasementObjective", objectivePart,
                    objectiveText .. " [" .. distance .. " studs]", Color3.fromRGB(255, 190, 75))
            end
        end

        -- 2. Needle ESP
        if HubState.NeedleESP and IS_GAMEPLAY then
            -- "The Needle" in Workspace is map decoration. The live objective is
            -- placed inside HiddenNeedleClient or identified by NeedleTargetChanged.
            local targetHayId = Landmarks.TargetNeedleHayId
            local roundFolder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
            local visibleNeedle = roundFolder and roundFolder:GetAttribute("NeedleRevealed") == true
                and findVisibleNeedleObjective() or nil
            if visibleNeedle then
                local dist = math.floor((myPos - visibleNeedle.Position).Magnitude)
                local objectiveName = IS_BASEMENT and "CHAVE" or "AGULHA"
                updateBillboard("Needle", visibleNeedle, objectiveName .. " [" .. dist .. " studs]", Color3.fromRGB(255, 230, 0))
            elseif targetHayId then
                local haystack = workspace:FindFirstChild("HaystackClient")
                if haystack then
                    local p = getKnownNeedleHayPart(haystack)
                    if p then
                        local dist = math.floor((myPos - p.Position).Magnitude)
                        updateBillboard("Needle", p, "AREA DE ESCAVACAO [" .. dist .. " studs]", Color3.fromRGB(255, 230, 0))
                    end
                end
            end
        end

        -- 3. Gem ESP
        if HubState.GemESP and IS_GAMEPLAY then
            local gemsFolder = workspace:FindFirstChild("GemsClient")
            if gemsFolder then
                for _, gem in ipairs(gemsFolder:GetChildren()) do
                    if gem:IsA("BasePart") and gem:GetAttribute("GemId") then
                        local dist = math.floor((myPos - gem.Position).Magnitude)
                        updateBillboard("Gem_" .. tostring(gem:GetAttribute("GemId")), gem, "GEMA [" .. dist .. " studs]", Color3.fromRGB(120, 255, 120))
                    elseif gem:IsA("Model") and gem.Name:match("^Gem_") then
                        local p = gem.PrimaryPart or gem:FindFirstChildWhichIsA("BasePart", true)
                        if p then
                            local dist = math.floor((myPos - p.Position).Magnitude)
                            updateBillboard("Gem_" .. tostring(p:GetAttribute("GemId") or gem.Name), p, "GEMA [" .. dist .. " studs]", Color3.fromRGB(120, 255, 120))
                        end
                    end
                end
            end
        end

        -- 4. RGB Straw ESP
        if HubState.RgbESP and IS_GAMEPLAY then
            local haystack = workspace:FindFirstChild("HaystackClient")
            if haystack then
                local rareParts = {}
                for _, p in ipairs(getAllRainbowStrands()) do
                    if p.Parent == haystack and type(p:GetAttribute("HayId")) == "number" then
                        table.insert(rareParts, {part = p, value = getRareHayMultiplier(p), distance = (myPos - p.Position).Magnitude})
                    end
                end
                table.sort(rareParts, function(a, b)
                    if a.value ~= b.value then return a.value > b.value end
                    return a.distance < b.distance
                end)
                for i = 1, math.min(25, #rareParts) do
                    local entry = rareParts[i]
                    local p = entry.part
                    local mutation = tostring(p:GetAttribute("HayMutation") or "Raro")
                    updateBillboard("RGB_" .. tostring(p:GetAttribute("HayId")), p,
                        mutation .. " x" .. tostring(entry.value) .. " [" .. math.floor(entry.distance) .. " studs]",
                        Color3.fromRGB(255, 100, 255))
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
                        updateBillboard("Player_" .. plr.Name, pRoot, plr.DisplayName .. " [" .. dist .. " studs]", Color3.fromRGB(255, 255, 255))
                    end
                end
            end
        end
        local staleKeys = {}
        for key in pairs(activeBillboards) do
            if not seenBillboards[key] then table.insert(staleKeys, key) end
        end
        for _, key in ipairs(staleKeys) do removeBillboard(key) end
    end
end)
table.insert(HubThreads, espThread)

-- 8.10 UNLOAD / DESTROY HUB
local function unloadHub()
    addLog("warn", "Unloading Needle Hub completely...")
    BasementSolver.releaseCamera(LocalPlayer:GetAttribute("CutsceneActive") == true)
    if ToolRuntime.stopVacuumAutomation then ToolRuntime.stopVacuumAutomation() end
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
    clearUIConnections()

    toggleFly(false)

    local billboardKeys = {}
    for key in pairs(activeBillboards) do table.insert(billboardKeys, key) end
    for _, key in ipairs(billboardKeys) do removeBillboard(key) end
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
    if RuntimeRegistry and RuntimeRegistry.__NeedleHubRuntime == ThisRuntime then
        RuntimeRegistry.__NeedleHubRuntime = nil
    end
end
ThisRuntime.unload = unloadHub

---- SECTION 9: USER INTERFACE (FROSTED GRAPHITE)

local UI_THEME = {
    shell = Color3.fromRGB(19, 26, 34),
    header = Color3.fromRGB(27, 37, 47),
    sidebar = Color3.fromRGB(22, 31, 40),
    card = Color3.fromRGB(32, 43, 54),
    cardHover = Color3.fromRGB(43, 57, 68),
    border = Color3.fromRGB(117, 145, 157),
    text = Color3.fromRGB(235, 243, 245),
    muted = Color3.fromRGB(165, 184, 194),
    accent = Color3.fromRGB(101, 213, 198),
    accentDark = Color3.fromRGB(38, 78, 77),
}
local MENU_TOGGLE_KEY = Enum.KeyCode.RightShift

local function getUIViewport()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function clampToRange(value, low, high)
    if low > high then return (low + high) * 0.5 end
    return math.clamp(value, low, high)
end

-- Helper: Smooth Tweening
local function tweenGui(obj, props, duration, style, direction)
    local info = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local tw = TweenService:Create(obj, info, props)
    tw:Play()
    return tw
end

-- Floating Toggle Button on Screen
local function createFloatingToggleButton(toggleCallback)
    if FloatingButtonGui then FloatingButtonGui:Destroy() end

    local floatGui = Instance.new("ScreenGui")
    floatGui.Name = "NeedleHubFloatingBtn"
    floatGui.ResetOnSpawn = false
    floatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    floatGui.IgnoreGuiInset = true
    floatGui.DisplayOrder = 10
    pcall(function() floatGui.Parent = CoreGui end)
    if not floatGui.Parent then floatGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    FloatingButtonGui = floatGui

    local floatBtn = Instance.new("TextButton")
    floatBtn.Name = "MenuToggle"
    floatBtn.Size = UDim2.fromOffset(48, 48)
    floatBtn.Position = UDim2.fromOffset(16, getUIViewport().Y * 0.45 - 24)
    floatBtn.BackgroundColor3 = UI_THEME.accentDark
    floatBtn.BackgroundTransparency = 0.02
    floatBtn.Text = ""
    floatBtn.AutoButtonColor = false
    floatBtn.Parent = floatGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = floatBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = UI_THEME.accent
    stroke.Transparency = 0.2
    stroke.Thickness = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = floatBtn

    -- Circular launcher stays available in every window state.
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = "N"
    lbl.TextColor3 = UI_THEME.text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 18
    lbl.Parent = floatBtn

    -- Hover effect
    floatBtn.MouseEnter:Connect(function()
        tweenGui(floatBtn, {BackgroundColor3 = Color3.fromRGB(49, 96, 92)}, 0.18)
        tweenGui(stroke, {Transparency = 0}, 0.18)
    end)
    floatBtn.MouseLeave:Connect(function()
        tweenGui(floatBtn, {BackgroundColor3 = UI_THEME.accentDark}, 0.18)
        tweenGui(stroke, {Transparency = 0.2}, 0.18)
    end)

    local function clampFloat(x, y)
        local vp = getUIViewport()
        floatBtn.Position = UDim2.fromOffset(
            clampToRange(x, 8, vp.X - floatBtn.Size.X.Offset - 8),
            clampToRange(y, 48, vp.Y - floatBtn.Size.Y.Offset - 8)
        )
    end
    clampFloat(floatBtn.Position.X.Offset, floatBtn.Position.Y.Offset)

    -- Dragging the launcher never counts as a click, and cannot lose it off-screen.
    local dragging = false
    local dragStart, startPos, activeTouch
    local suppressClick = false

    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = floatBtn.Position
            activeTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
            suppressClick = false
        end
    end)

    local dragEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input == activeTouch then
            dragging = false
            activeTouch = nil
        end
    end)
    trackUIConnection(dragEndConn)

    local dragMoveConn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeTouch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 6 then suppressClick = true end
            clampFloat(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
        end
    end)
    trackUIConnection(dragMoveConn)

    floatBtn.MouseButton1Click:Connect(function()
        if not suppressClick then toggleCallback() end
    end)

    local floatCameraConnection
    local function bindFloatCamera()
        if floatCameraConnection then floatCameraConnection:Disconnect() end
        local camera = workspace.CurrentCamera
        if camera then
            floatCameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                clampFloat(floatBtn.Position.X.Offset, floatBtn.Position.Y.Offset)
            end)
            trackUIConnection(floatCameraConnection)
        end
        clampFloat(floatBtn.Position.X.Offset, floatBtn.Position.Y.Offset)
    end
    trackUIConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindFloatCamera))
    bindFloatCamera()
    return floatGui
end

-- Version & GitHub Update Status Store
local ScriptUpdateState = {
    remoteVersion = nil,
    commitSha = nil,
    available = false,
    notice = "Aguardando consulta ao GitHub",
    requestId = 0,
    rawRoot = "https://raw.githubusercontent.com/victorcxzk/search-for-the-needle-script/",
}

local function versionCacheKey()
    return tostring(os.time()) .. "-" .. tostring(math.floor(os.clock() * 1000))
end

local function readGitHubHeadSha()
    local requestOk, response = pcall(function()
        return game:HttpGet("https://api.github.com/repos/victorcxzk/search-for-the-needle-script/branches/master?cb=" .. versionCacheKey())
    end)
    if not requestOk or type(response) ~= "string" then return nil end
    local HttpService = safeService("HttpService")
    local parsed = nil
    pcall(function()
        if HttpService then parsed = HttpService:JSONDecode(response) end
    end)
    local sha = type(parsed) == "table" and type(parsed.commit) == "table" and parsed.commit.sha or nil
    if type(sha) == "string" and #sha == 40 and sha:match("^[%da-fA-F]+$") then
        return sha
    end
    return nil
end

local function compareHubVersions(remote, installed)
    local remoteParts, installedParts = {}, {}
    for value in tostring(remote):gmatch("%d+") do table.insert(remoteParts, tonumber(value)) end
    for value in tostring(installed):gmatch("%d+") do table.insert(installedParts, tonumber(value)) end
    if #remoteParts == 0 or #installedParts == 0 then return nil end
    for index = 1, math.max(#remoteParts, #installedParts) do
        local remotePart = remoteParts[index] or 0
        local installedPart = installedParts[index] or 0
        if remotePart > installedPart then return 1 end
        if remotePart < installedPart then return -1 end
    end
    return 0
end

local function checkForScriptUpdates(onFinished)
    ScriptUpdateState.requestId = ScriptUpdateState.requestId + 1
    local requestId = ScriptUpdateState.requestId
    ScriptUpdateState.notice = "Consultando GitHub..."
    task.spawn(function()
        local commitSha = readGitHubHeadSha()
        local success, res = pcall(function()
            return game:HttpGet(ScriptUpdateState.rawRoot .. (commitSha or "master") .. "/version.json?cb=" .. versionCacheKey())
        end)
        local remoteVersion = nil
        local notice = nil
        local available = false
        if success and type(res) == "string" and #res > 0 then
            local HttpService = safeService("HttpService")
            local parsed = nil
            pcall(function()
                if HttpService then parsed = HttpService:JSONDecode(res) end
            end)
            if type(parsed) == "table" and parsed.version then
                remoteVersion = tostring(parsed.version)
                local comparison = compareHubVersions(remoteVersion, SCRIPT_VERSION)
                if comparison == 1 then
                    available = true
                    notice = "Nova versao disponivel"
                elseif comparison == 0 then
                    notice = "Atualizada"
                elseif comparison == -1 then
                    notice = "GitHub mostra versao anterior"
                else
                    notice = "Versao do GitHub invalida"
                end
            else
                notice = "Resposta invalida do GitHub"
            end
        else
            notice = "Falha ao consultar GitHub"
        end
        if requestId ~= ScriptUpdateState.requestId then return end
        ScriptUpdateState.commitSha = commitSha
        ScriptUpdateState.remoteVersion = remoteVersion
        ScriptUpdateState.available = available
        ScriptUpdateState.notice = notice
        addLog((available or not remoteVersion) and "warn" or "info", "Versao instalada v" .. SCRIPT_VERSION .. "; GitHub " ..
            (remoteVersion and ("v" .. remoteVersion) or "indisponivel") .. ": " .. notice)
        if onFinished then pcall(onFinished, notice, available, remoteVersion) end
    end)
end

-- Primary Modern Native UI Builder (Context-Aware: Lobby vs Match)
local function buildNativeUI()
    local isLobbyMode = (CurrentContextMode == "Lobby")
    addLog("info", "Construindo UI Frosted Graphite (" .. (isLobbyMode and "MODO LOBBY" or "MODO JOGO") .. ")...")

    clearUIConnections()
    if GlobalScreenGui then GlobalScreenGui:Destroy() end
    if FloatingButtonGui then
        FloatingButtonGui:Destroy()
        FloatingButtonGui = nil
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NeedleHubNative"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 5
    pcall(function() screenGui.Parent = CoreGui end)
    if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    GlobalScreenGui = screenGui

    -- Comfortable desktop canvas, scaled down only when the viewport requires it.
    local WIN_WIDTH = 800
    local WIN_HEIGHT = 520
    local TITLE_HEIGHT = 52
    local SIDEBAR_WIDTH = 172
    local windowScale = 1
    local isMinimized = false

    -- Main Window Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.fromOffset(WIN_WIDTH, WIN_HEIGHT)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, -WIN_HEIGHT / 2)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0)
    mainFrame.BackgroundColor3 = UI_THEME.shell
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui

    local responsiveScale = Instance.new("UIScale")
    responsiveScale.Name = "ResponsiveScale"
    responsiveScale.Parent = mainFrame

    local function clampWindowPosition(centerX, topY)
        local viewport = getUIViewport()
        local halfW = WIN_WIDTH * windowScale * 0.5
        local current = mainFrame.Position
        centerX = centerX or viewport.X * current.X.Scale + current.X.Offset
        topY = topY or viewport.Y * current.Y.Scale + current.Y.Offset
        mainFrame.Position = UDim2.fromOffset(
            clampToRange(centerX, halfW + 12, viewport.X - halfW - 12),
            clampToRange(topY, 48, viewport.Y - WIN_HEIGHT * windowScale - 12)
        )
    end

    local positionedInitially = false
    local function updateResponsiveScale()
        local viewport = getUIViewport()
        windowScale = math.max(0.1, math.min(1,
            (viewport.X - 24) / WIN_WIDTH,
            (viewport.Y - 60) / WIN_HEIGHT))
        responsiveScale.Scale = windowScale
        if not positionedInitially then
            mainFrame.Position = UDim2.fromOffset(viewport.X * 0.5, (viewport.Y - WIN_HEIGHT * windowScale) * 0.5)
            positionedInitially = true
        end
        clampWindowPosition()
    end
    local cameraViewportConnection
    local function bindWindowCamera()
        if cameraViewportConnection then cameraViewportConnection:Disconnect() end
        local camera = workspace.CurrentCamera
        if camera then
            cameraViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
            trackUIConnection(cameraViewportConnection)
        end
        updateResponsiveScale()
    end
    trackUIConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindWindowCamera))
    bindWindowCamera()

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = UI_THEME.border
    mainStroke.Transparency = 0.42
    mainStroke.Thickness = 1
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mainStroke.Parent = mainFrame

    local mainGrad = Instance.new("UIGradient")
    mainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, UI_THEME.header),
        ColorSequenceKeypoint.new(1, UI_THEME.shell)
    })
    mainGrad.Rotation = 90
    mainGrad.Parent = mainFrame

    -- Title Bar (Header)
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
    titleBar.BackgroundColor3 = UI_THEME.header
    titleBar.BackgroundTransparency = 0.08
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 14)
    titleCorner.Parent = titleBar

    -- Quiet hairline keeps the frosted header distinct from the content.
    local headerLine = Instance.new("Frame")
    headerLine.Size = UDim2.new(1, 0, 0, 1)
    headerLine.Position = UDim2.new(0, 0, 1, -1)
    headerLine.BorderSizePixel = 0
    headerLine.BackgroundColor3 = UI_THEME.border
    headerLine.BackgroundTransparency = 0.64
    headerLine.Parent = titleBar

    -- Logo Badge Icon
    local logoIcon = Instance.new("Frame")
    logoIcon.Size = UDim2.fromOffset(28, 28)
    logoIcon.Position = UDim2.new(0, 12, 0.5, -14)
    logoIcon.BackgroundColor3 = UI_THEME.accentDark
    logoIcon.BorderSizePixel = 0
    logoIcon.Parent = titleBar
    local logoCorner = Instance.new("UICorner") logoCorner.CornerRadius = UDim.new(0, 6) logoCorner.Parent = logoIcon
    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.fromScale(1, 1)
    logoText.BackgroundTransparency = 1
    logoText.Text = "N"
    logoText.TextColor3 = UI_THEME.accent
    logoText.Font = Enum.Font.GothamBold
    logoText.TextSize = 15
    logoText.Parent = logoIcon

    -- Title Text
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.fromOffset(120, 28)
    titleLabel.Position = UDim2.new(0, 50, 0.5, -14)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "NEEDLE HUB"
    titleLabel.TextColor3 = UI_THEME.text
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local versionLabel = Instance.new("TextButton")
    versionLabel.Name = "InstalledVersion"
    versionLabel.Size = UDim2.fromOffset(54, 22)
    versionLabel.Position = UDim2.new(0, 174, 0.5, -11)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Text = "v" .. SCRIPT_VERSION
    versionLabel.TextColor3 = UI_THEME.muted
    versionLabel.Font = Enum.Font.GothamMedium
    versionLabel.TextSize = 12
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
    versionLabel.AutoButtonColor = false
    versionLabel.Parent = titleBar
    versionLabel.MouseEnter:Connect(function() versionLabel.TextColor3 = UI_THEME.accent end)
    versionLabel.MouseLeave:Connect(function() versionLabel.TextColor3 = UI_THEME.muted end)

    -- Live account balance; the authoritative replicated Data service is used.
    local gemPill = Instance.new("Frame")
    gemPill.Name = "GemBalance"
    gemPill.Size = UDim2.fromOffset(112, 22)
    gemPill.Position = UDim2.new(0, 238, 0.5, -11)
    gemPill.BackgroundColor3 = UI_THEME.accentDark
    gemPill.BackgroundTransparency = 0.2
    gemPill.BorderSizePixel = 0
    gemPill.Parent = titleBar
    local gemCorner = Instance.new("UICorner") gemCorner.CornerRadius = UDim.new(0, 11) gemCorner.Parent = gemPill
    local gemStroke = Instance.new("UIStroke") gemStroke.Color = UI_THEME.accent gemStroke.Transparency = 0.35 gemStroke.Thickness = 1 gemStroke.Parent = gemPill
    local gemLabel = Instance.new("TextLabel")
    gemLabel.Size = UDim2.new(1, -14, 1, 0)
    gemLabel.Position = UDim2.fromOffset(7, 0)
    gemLabel.BackgroundTransparency = 1
    gemLabel.Text = "GEMAS  " .. formatNumber(getGemBalance())
    gemLabel.TextColor3 = UI_THEME.text
    gemLabel.Font = Enum.Font.GothamSemibold
    gemLabel.TextSize = 12
    gemLabel.TextXAlignment = Enum.TextXAlignment.Center
    gemLabel.Parent = gemPill

    task.spawn(function()
        while IsHubLoaded and screenGui.Parent and gemLabel.Parent do
            gemLabel.Text = "GEMAS  " .. formatNumber(getGemBalance())
            task.wait(0.5)
        end
    end)

    -- Minimize Button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.fromOffset(30, 30)
    minBtn.Position = UDim2.new(1, -76, 0.5, -15)
    minBtn.BackgroundColor3 = UI_THEME.card
    minBtn.Text = "-"
    minBtn.TextColor3 = UI_THEME.muted
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 15
    minBtn.AutoButtonColor = false
    minBtn.Parent = titleBar
    local minCorner = Instance.new("UICorner") minCorner.CornerRadius = UDim.new(0, 8) minCorner.Parent = minBtn

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(30, 30)
    closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
    closeBtn.BackgroundColor3 = UI_THEME.card
    closeBtn.Text = "×"
    closeBtn.TextColor3 = UI_THEME.muted
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = titleBar
    local closeCorner = Instance.new("UICorner") closeCorner.CornerRadius = UDim.new(0, 8) closeCorner.Parent = closeBtn

    -- Container for Tabs & Content
    local bodyContainer = Instance.new("Frame")
    bodyContainer.Name = "BodyContainer"
    bodyContainer.Size = UDim2.new(1, 0, 1, -TITLE_HEIGHT)
    bodyContainer.Position = UDim2.fromOffset(0, TITLE_HEIGHT)
    bodyContainer.BackgroundTransparency = 1
    bodyContainer.Parent = mainFrame

    -- The frame is top-anchored, so changing its height never moves the title bar.
    local windowTween = nil
    local function setWindowMinimized(nextMinimized)
        if isMinimized == nextMinimized then return end

        if windowTween then windowTween:Cancel() end
        local newHeight = nextMinimized and TITLE_HEIGHT or WIN_HEIGHT

        isMinimized = nextMinimized
        minBtn.Text = isMinimized and "+" or "-"
        if isMinimized then
            bodyContainer.Visible = false
        else
            bodyContainer.Visible = true
        end

        windowTween = tweenGui(mainFrame, {
            Size = UDim2.fromOffset(WIN_WIDTH, newHeight),
        }, 0.22, Enum.EasingStyle.Quart)
    end

    minBtn.MouseButton1Click:Connect(function()
        setWindowMinimized(not isMinimized)
    end)

    local function setMenuVisible(visible)
        if visible then
            mainFrame.Visible = true
            updateResponsiveScale()
            if isMinimized then
                setWindowMinimized(false)
            else
                clampWindowPosition()
            end
        else
            mainFrame.Visible = false
        end
    end

    -- Minimize keeps the title bar; close hides the window entirely.
    closeBtn.MouseButton1Click:Connect(function()
        setMenuVisible(false)
    end)

    -- Viewport Clamped Window Dragging
    local isDraggingMain = false
    local dragStartPos, frameStartPos, activeTitleTouch

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            -- Search and window controls own the right side of the header.
            if input.Position.X >= mainFrame.AbsolutePosition.X + 492 * windowScale then return end
            isDraggingMain = true
            dragStartPos = input.Position
            frameStartPos = mainFrame.Position
            activeTitleTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
        end
    end)

    local dragTitleEnd = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input == activeTitleTouch then
            isDraggingMain = false
            activeTitleTouch = nil
        end
    end)
    trackUIConnection(dragTitleEnd)

    local dragTitleMove = UserInputService.InputChanged:Connect(function(input)
        if isDraggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeTitleTouch) then
            local delta = input.Position - dragStartPos
            local vp = getUIViewport()
            clampWindowPosition(
                vp.X * frameStartPos.X.Scale + frameStartPos.X.Offset + delta.X,
                vp.Y * frameStartPos.Y.Scale + frameStartPos.Y.Offset + delta.Y
            )
        end
    end)
    trackUIConnection(dragTitleMove)

    -- Sidebar for Tabs
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0)
    sidebar.BackgroundColor3 = UI_THEME.sidebar
    sidebar.BackgroundTransparency = 0.12
    sidebar.BorderSizePixel = 0
    sidebar.ClipsDescendants = false
    sidebar.Parent = bodyContainer

    -- Separator line between sidebar and content area
    local sidebarSep = Instance.new("Frame")
    sidebarSep.Name = "SidebarDivider"
    sidebarSep.Size = UDim2.new(0, 1, 1, 0)
    sidebarSep.Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0)
    sidebarSep.BackgroundColor3 = UI_THEME.border
    sidebarSep.BackgroundTransparency = 0.7
    sidebarSep.BorderSizePixel = 0
    sidebarSep.Parent = bodyContainer

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.Padding = UDim.new(0, 7)
    sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Parent = sidebar

    local sidebarPadding = Instance.new("UIPadding")
    sidebarPadding.PaddingTop = UDim.new(0, 14)
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
    local activeTabName = nil
    local applyTabFilter = nil

    local function selectTab(tabName)
        activeTabName = tabName
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
                tweenGui(btn, {BackgroundColor3 = UI_THEME.accentDark, TextColor3 = UI_THEME.text}, 0.16)
                if ind then ind.Visible = true end
            else
                tweenGui(btn, {BackgroundColor3 = UI_THEME.sidebar, TextColor3 = UI_THEME.muted}, 0.16)
                if ind then ind.Visible = false end
            end
        end
        if applyTabFilter then applyTabFilter() end
    end

    local function createTab(tabName, badgeTag)
        tabOrderCounter = tabOrderCounter + 1
        local btn = Instance.new("TextButton")
        btn.Name = "TabBtn_" .. tabName
        btn.Size = UDim2.new(0.9, 0, 0, 42)
        btn.BackgroundColor3 = UI_THEME.sidebar
        btn.Text = "  " .. tabName
        btn.TextColor3 = UI_THEME.muted
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.LayoutOrder = tabOrderCounter
        btn.Parent = sidebar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        -- Left Active Indicator Pill
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 3, 0.6, 0)
        indicator.Position = UDim2.new(0, 2, 0.2, 0)
        indicator.BackgroundColor3 = UI_THEME.accent
        indicator.BorderSizePixel = 0
        indicator.Visible = false
        indicator.Parent = btn
        local ic = Instance.new("UICorner") ic.CornerRadius = UDim.new(1, 0) ic.Parent = indicator

        btn.MouseEnter:Connect(function()
            if tabFrames[tabName] and not tabFrames[tabName].Visible then
                tweenGui(btn, {BackgroundColor3 = UI_THEME.card, TextColor3 = UI_THEME.text}, 0.15)
            end
        end)
        btn.MouseLeave:Connect(function()
            if tabFrames[tabName] and not tabFrames[tabName].Visible then
                tweenGui(btn, {BackgroundColor3 = UI_THEME.sidebar, TextColor3 = UI_THEME.muted}, 0.15)
            end
        end)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "TabContent_" .. tabName
        scroll.Size = UDim2.new(1, -24, 1, -20)
        scroll.Position = UDim2.fromOffset(12, 10)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 6
        scroll.ScrollBarImageColor3 = UI_THEME.border
        scroll.CanvasPosition = Vector2.new(0, 0)
        scroll.Visible = false
        scroll.Parent = contentArea

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 10)
        list.HorizontalAlignment = Enum.HorizontalAlignment.Center
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = scroll

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 6)
        pad.PaddingBottom = UDim.new(0, 18)
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

    -- Global filter keeps dense tabs usable without adding more navigation layers.
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "OptionSearch"
    searchBox.Size = UDim2.fromOffset(176, 30)
    searchBox.Position = UDim2.new(1, -300, 0.5, -15)
    searchBox.BackgroundColor3 = UI_THEME.shell
    searchBox.BackgroundTransparency = 0.22
    searchBox.BorderSizePixel = 0
    searchBox.Text = ""
    searchBox.PlaceholderText = "Buscar opções"
    searchBox.TextColor3 = UI_THEME.text
    searchBox.PlaceholderColor3 = UI_THEME.muted
    searchBox.Font = Enum.Font.GothamMedium
    searchBox.TextSize = 12
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = titleBar
    local searchCorner = Instance.new("UICorner") searchCorner.CornerRadius = UDim.new(0, 8) searchCorner.Parent = searchBox
    local searchStroke = Instance.new("UIStroke") searchStroke.Color = UI_THEME.border searchStroke.Transparency = 0.72 searchStroke.Thickness = 1 searchStroke.Parent = searchBox

    local function getSearchableText(guiObject)
        local parts = {}
        if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
            table.insert(parts, guiObject.Text)
        end
        for _, descendant in ipairs(guiObject:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                table.insert(parts, descendant.Text)
            end
        end
        return string.lower(table.concat(parts, " "))
    end

    applyTabFilter = function()
        local activeFrame = activeTabName and tabFrames[activeTabName]
        if not activeFrame then return end
        local query = string.lower(searchBox.Text):match("^%s*(.-)%s*$") or ""
        for _, child in ipairs(activeFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                child.Visible = query == "" or string.find(getSearchableText(child), query, 1, true) ~= nil
            end
        end
    end
    trackUIConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(applyTabFilter))

    local function resolveUIAccent(color)
        if color and math.abs(color.R - 99 / 255) < 0.01
            and math.abs(color.G - 102 / 255) < 0.01
            and math.abs(color.B - 241 / 255) < 0.01 then
            return UI_THEME.accent
        end
        return color or UI_THEME.accent
    end

    -- UI Component: Section Header (Context-Colored)
    local function addNativeSection(parent, title, customAccentColor)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.98, 0, 0, 30)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local accent = resolveUIAccent(customAccentColor)

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
        lbl.TextColor3 = UI_THEME.muted
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        local line = Instance.new("Frame")
        line.Size = UDim2.fromOffset(48, 1)
        line.Position = UDim2.new(1, -52, 0.5, 0)
        line.BackgroundColor3 = UI_THEME.border
        line.BackgroundTransparency = 0.7
        line.BorderSizePixel = 0
        line.Parent = frame
    end

    -- UI Component: Animated Switch Toggle
    local function addNativeToggle(parent, title, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.98, 0, 0, 46)
        frame.BackgroundColor3 = UI_THEME.card
        frame.BackgroundTransparency = 0.13
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 9) c.Parent = frame
        local s = Instance.new("UIStroke")
        s.Color = UI_THEME.border
        s.Transparency = 0.76
        s.Thickness = 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = frame

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -76, 1, 0)
        lbl.Position = UDim2.fromOffset(14, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = title
        lbl.TextColor3 = UI_THEME.text
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 13
        lbl.TextWrapped = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame

        -- Switch Pill Track
        local track = Instance.new("TextButton")
        track.Size = UDim2.fromOffset(46, 24)
        track.Position = UDim2.new(1, -58, 0.5, -12)
        track.BackgroundColor3 = default and UI_THEME.accentDark or UI_THEME.sidebar
        track.Text = ""
        track.AutoButtonColor = false
        track.Parent = frame

        local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(1, 0) tc.Parent = track
        local ts = Instance.new("UIStroke") ts.Color = UI_THEME.border ts.Transparency = 0.55 ts.Thickness = 1 ts.Parent = track

        -- Thumb knob
        local thumb = Instance.new("Frame")
        thumb.Size = UDim2.fromOffset(18, 18)
        thumb.Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        thumb.BorderSizePixel = 0
        thumb.Parent = track
        local thumbC = Instance.new("UICorner") thumbC.CornerRadius = UDim.new(1, 0) thumbC.Parent = thumb

        local state = default
        local function toggleState()
            state = not state
            if state then
                tweenGui(track, {BackgroundColor3 = UI_THEME.accentDark}, 0.18)
                tweenGui(thumb, {Position = UDim2.new(1, -21, 0.5, -9)}, 0.18)
            else
                tweenGui(track, {BackgroundColor3 = UI_THEME.sidebar}, 0.18)
                tweenGui(thumb, {Position = UDim2.new(0, 3, 0.5, -9)}, 0.18)
            end
            callback(state)
        end

        track.MouseButton1Click:Connect(toggleState)
        return frame
    end

    -- UI Component: Button (Supports Robux Gold, Gem Green, Primary Indigo)
    local function addNativeButton(parent, title, callback, isPrimary, buttonStyle)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.98, 0, 0, 42)
        btn.Text = title
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 13
        btn.TextWrapped = true
        btn.AutoButtonColor = false
        btn.Parent = parent

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 9) c.Parent = btn
        local s = Instance.new("UIStroke")
        s.Thickness = 1
        s.Transparency = 0.58
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = btn

        local bgCol = UI_THEME.card
        local textCol = UI_THEME.text
        local strokeCol = UI_THEME.border
        local hoverCol = UI_THEME.cardHover

        if buttonStyle == "robux" then
            bgCol = Color3.fromRGB(59, 47, 35)
            textCol = Color3.fromRGB(246, 205, 139)
            strokeCol = Color3.fromRGB(190, 142, 77)
            hoverCol = Color3.fromRGB(70, 55, 39)
        elseif buttonStyle == "gem" then
            bgCol = Color3.fromRGB(28, 62, 53)
            textCol = Color3.fromRGB(155, 228, 186)
            strokeCol = Color3.fromRGB(89, 179, 129)
            hoverCol = Color3.fromRGB(36, 76, 63)
        elseif isPrimary then
            bgCol = UI_THEME.accentDark
            textCol = UI_THEME.text
            strokeCol = UI_THEME.accent
            hoverCol = Color3.fromRGB(49, 96, 92)
        end

        btn.BackgroundColor3 = bgCol
        btn.BackgroundTransparency = 0.1
        btn.TextColor3 = textCol
        s.Color = strokeCol

        btn.MouseEnter:Connect(function()
            tweenGui(btn, {BackgroundColor3 = hoverCol}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            tweenGui(btn, {BackgroundColor3 = bgCol}, 0.15)
        end)
        btn.MouseButton1Click:Connect(function()
            tweenGui(btn, {BackgroundColor3 = hoverCol}, 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
            task.wait(0.08)
            tweenGui(btn, {BackgroundColor3 = bgCol}, 0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
            callback()
        end)
        return btn
    end

    -- UI Component: Interactive Slider
    local function addNativeSlider(parent, title, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.98, 0, 0, 58)
        frame.BackgroundColor3 = UI_THEME.card
        frame.BackgroundTransparency = 0.13
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 9) c.Parent = frame
        local s = Instance.new("UIStroke")
        s.Color = UI_THEME.border
        s.Transparency = 0.76
        s.Thickness = 1
        s.Parent = frame

        local tLbl = Instance.new("TextLabel")
        tLbl.Size = UDim2.new(1, -72, 0, 22)
        tLbl.Position = UDim2.fromOffset(14, 5)
        tLbl.BackgroundTransparency = 1
        tLbl.Text = title
        tLbl.TextColor3 = UI_THEME.text
        tLbl.Font = Enum.Font.GothamMedium
        tLbl.TextSize = 13
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.Parent = frame

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.fromOffset(52, 22)
        valLbl.Position = UDim2.new(1, -66, 0, 5)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(default)
        valLbl.TextColor3 = UI_THEME.accent
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 12
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = frame

        local barBg = Instance.new("TextButton")
        barBg.Size = UDim2.new(1, -24, 0, 8)
        barBg.Position = UDim2.fromOffset(12, 37)
        barBg.BackgroundColor3 = UI_THEME.sidebar
        barBg.Text = ""
        barBg.AutoButtonColor = false
        barBg.Parent = frame
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = barBg

        local fill = Instance.new("Frame")
        local startFrac = math.clamp((default - min) / (max - min), 0, 1)
        fill.Size = UDim2.fromScale(startFrac, 1)
        fill.BackgroundColor3 = UI_THEME.accent
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
        trackUIConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDraggingSlider = false
            end
        end))
        trackUIConnection(UserInputService.InputChanged:Connect(function(input)
            if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                updateVal(input)
            end
        end))
    end

    -- UI Component: Modern Info / Status Card (Context-Colored)
    local function addNativeParagraph(parent, title, content, customAccentColor)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0.98, 0, 0, 72)
        frame.BackgroundColor3 = UI_THEME.card
        frame.BackgroundTransparency = 0.12
        frame.BorderSizePixel = 0
        frame.Parent = parent

        local accentCol = resolveUIAccent(customAccentColor)

        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 9) c.Parent = frame
        local s = Instance.new("UIStroke")
        s.Color = UI_THEME.border
        s.Transparency = 0.72
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
        tLbl.Size = UDim2.new(1, -30, 0, 22)
        tLbl.Position = UDim2.fromOffset(15, 7)
        tLbl.BackgroundTransparency = 1
        tLbl.Text = title
        tLbl.TextColor3 = accentCol
        tLbl.Font = Enum.Font.GothamBold
        tLbl.TextSize = 13
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.Parent = frame

        local cLbl = Instance.new("TextLabel")
        cLbl.Size = UDim2.new(1, -30, 0, 36)
        cLbl.Position = UDim2.fromOffset(15, 31)
        cLbl.BackgroundTransparency = 1
        cLbl.Text = content
        cLbl.TextColor3 = UI_THEME.muted
        cLbl.Font = Enum.Font.Gotham
        cLbl.TextSize = 12
        cLbl.TextWrapped = true
        cLbl.TextXAlignment = Enum.TextXAlignment.Left
        cLbl.TextYAlignment = Enum.TextYAlignment.Top
        cLbl.Parent = frame

        return cLbl
    end

    ----------------------------------------------------------------------
    -- ADAPTIVE CONTEXT TABS CONSTRUCTION
    ----------------------------------------------------------------------

    if isLobbyMode then
        -- ==================================================================
        -- LOBBY MODE (ONLY LOBBY FEATURES SHOWN)
        -- ==================================================================
        local lobbyTab = createTab("Inicio", "HUB")
        local lobbyShopTab = createTab("Loja", "SHOP")
        local setTab = createTab("Ajustes", "CFG")

        -- 1. Lobby account overview (read-only, replicated data only)
        addNativeSection(lobbyTab, "Resumo da conta", Color3.fromRGB(99, 102, 241))
        local classStatusCard = addNativeParagraph(lobbyTab, "Resumo da conta",
            string.format("Classe ativa: %s   |   Gemas: %s",
                getActiveClass(),
                formatNumber(getGemBalance())), Color3.fromRGB(99, 102, 241))

        task.spawn(function()
            while IsHubLoaded and classStatusCard and classStatusCard.Parent do
                task.wait(1.5)
                pcall(function()
                    if classStatusCard and classStatusCard.Parent then
                        classStatusCard.Text = string.format("Classe ativa: %s   |   Gemas: %s",
                            getActiveClass(),
                            formatNumber(getGemBalance()))
                    end
                end)
            end
        end)

        -- 2. Lobby Shop Tab (Dedicated Store with Clear Separation)
        addNativeSection(lobbyShopTab, "Melhorias permanentes", Color3.fromRGB(52, 211, 153))
        local lobbyGemsCard = addNativeParagraph(lobbyShopTab, "Gemas da conta", "Saldo atual: " .. formatNumber(getGemBalance()) .. " gemas | Valores replicados pelo servidor.", Color3.fromRGB(52, 211, 153))
        local permanentUpgradeCards = {}
        for _, entry in ipairs(PermanentUpgradeUi) do
            permanentUpgradeCards[entry.id] = addNativeParagraph(lobbyShopTab, entry.title, formatPermanentUpgradeState(entry), Color3.fromRGB(52, 211, 153))
        end
        task.spawn(function()
            while IsHubLoaded and lobbyGemsCard and lobbyGemsCard.Parent do
                task.wait(1)
                pcall(function()
                    if lobbyGemsCard and lobbyGemsCard.Parent then
                        lobbyGemsCard.Text = "Saldo atual: " .. formatNumber(getGemBalance()) .. " gemas | Valores replicados pelo servidor."
                    end
                    for _, entry in ipairs(PermanentUpgradeUi) do
                        local card = permanentUpgradeCards[entry.id]
                        if card and card.Parent then
                            card.Text = formatPermanentUpgradeState(entry)
                        end
                    end
                end)
            end
        end)

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

        -- Default Lobby Tab Selection
        selectTab("Inicio")

    else
        -- ==================================================================
        -- MATCH MODE (ONLY GAMEPLAY FARMING & COMBAT FEATURES SHOWN)
        -- ==================================================================
        local farmTab = createTab("Automacao", "AUTO")
        local basementTab = IS_BASEMENT and createTab("Porao", "CH2") or nil
        local shopTab = createTab("Loja", "SHOP")
        local playerTab = createTab("Jogador", "HERO")
        local teleTab = createTab("Viagem", "WARP")
        local espTab = createTab("Destaques", "ESP")
        local consoleTab = createTab("Atividade", "LOGS")
        local setTab = createTab("Ajustes", "CFG")

        -- 1. Each named automation owns its related actions, without a global
        -- master switch that silently changes unrelated features.
        addNativeSection(farmTab, "Automation", Color3.fromRGB(99, 102, 241))
        addNativeToggle(farmTab, "Auto Farm", HubState.AutoFarmHay, function(val)
            HubState.AutoFarmHay = val
            HubState.NoTeleportMode = not val
            HubState.AutoEquipBestTool = val
            HubState.AutoUseTnt = val
            HubState.AutoCollectGems = val
            HubState.AutoDeployDrone = val
            if val then
                HubState.PrioritizeRGB = true
                HubState.ForcedToolSlot = 0
                local bestSlot = getBestAvailableToolSlot()
                equipToolSlot(bestSlot, true)
            else
                ToolRuntime.stopVacuumAutomation()
                clearAutoFarmCorner()
            end
            addLog("info", val and "Auto Farm ligado: TP automatico, raros, melhor ferramenta, TNT, gemas e drone."
                or "Auto Farm desligado.")
        end)
        addNativeToggle(farmTab, "Auto Buy", HubState.AutoBuyTools and HubState.AutoBuyUpgrades, function(val)
            HubState.AutoBuyTools = val
            HubState.AutoBuyUpgrades = val
            addLog("info", val and "Auto Buy ligado: ferramentas e melhorias por moedas da partida."
                or "Auto Buy desligado.")
        end)
        addNativeToggle(farmTab, "Auto Sell", HubState.AutoSell, function(val)
            HubState.AutoSell = val
            addLog("info", val and "Auto Sell ligado." or "Auto Sell desligado.")
        end)
        addNativeToggle(farmTab, "Auto Objective (Needle/Key)",
            HubState.AutoWinNeedle, function(val)
                HubState.AutoWinNeedle = val
                addLog("info", val and "Auto Objective ligado." or "Auto Objective desligado.")
            end)

        addNativeSection(farmTab, "Ferramentas detectadas", Color3.fromRGB(99, 102, 241))
        local toolStatusLbl = addNativeParagraph(farmTab, "Ferramentas e escavacao", getToolStatusSummary(), Color3.fromRGB(99, 102, 241))
        toolStatusLbl.Size = UDim2.new(1, -30, 0, 52)
        toolStatusLbl.Parent.Size = UDim2.new(0.98, 0, 0, 88)
        task.spawn(function()
            while IsHubLoaded and toolStatusLbl and toolStatusLbl.Parent do
                task.wait(1.2)
                pcall(function()
                    if toolStatusLbl and toolStatusLbl.Parent then
                        toolStatusLbl.Text = getToolStatusSummary()
                    end
                end)
            end
        end)

        addNativeSection(farmTab, "Acoes rapidas", Color3.fromRGB(99, 102, 241))
        addNativeButton(farmTab, "Equipar melhor ferramenta", function()
            HubState.ForcedToolSlot = 0
            local bestSlot = getBestAvailableToolSlot()
            equipToolSlot(bestSlot)
            addLog("info", "Ferramenta escolhida: slot " .. bestSlot)
        end)
        addNativeButton(farmTab, "Arremessar TNT no feno alcancavel", function()
            local hrp = getHRP()
            if hrp then
                local target = chooseTntTarget(hrp)
                if target then
                    throwTntAt(target)
                else
                    addLog("info", "Nao ha feno no alcance real da TNT.")
                end
            end
        end, true)
        addNativeButton(farmTab, "Vender agora sem mover personagem", function()
            ToolRuntime.stopVacuumAutomation()
            if Remotes.SellHay then Remotes.SellHay:FireServer() end
            addLog("info", "Venda solicitada sem teleporte. Se necessario, aproxime-se e olhe para a vaca.")
        end, true)

        -- 2. Barn Shop Tab (live prices and ownership from the match)
        addNativeSection(shopTab, "Ferramentas do Celeiro", Color3.fromRGB(99, 102, 241))
        local matchCashCard = addNativeParagraph(shopTab, "Saldo da partida", formatCash(getCashBalance()) .. " moedas | " .. formatNumber(getGemBalance()) .. " gemas. Opcoes da loja oficial.", Color3.fromRGB(99, 102, 241))
        addNativeParagraph(shopTab, "Compra automatica segura", "Tenta Forquilha > TNT > Drone > Aspirador. Usa moedas da partida e ate 40 diamantes no Drone. Nunca abre Robux nem gasta gemas em outros itens automaticamente.", Color3.fromRGB(99, 102, 241))
        
        local toolPurchaseButtons = {}
        for _, toolId in ipairs(barnToolNames) do
            local capturedToolId = toolId
            toolPurchaseButtons[capturedToolId] = addNativeButton(shopTab, "Carregando " .. (BarnToolDisplayNames[capturedToolId] or capturedToolId) .. "...", function()
                requestBarnToolPurchase(capturedToolId, true)
            end)
        end

        addNativeSection(shopTab, "Melhorias da partida", Color3.fromRGB(99, 102, 241))
        addNativeParagraph(shopTab, "Upgrades de sessao", "Mostra nivel e preco real. Opcoes de ferramentas ficam bloqueadas ate voce possuir o item correspondente.", Color3.fromRGB(99, 102, 241))
        
        local UpgradeLabels = {
            Capacity = "Mochila: capacidade", HandHold = "Mao: coleta continua", Speed = "Mao: velocidade", Grab = "Mao: quantidade",
            PitchforkCooldown = "Forquilha: velocidade", PitchforkHold = "Forquilha: coleta continua", Pitchfork = "Forquilha: alcance",
            TntLuck = "TNT: sorte arco-iris", TntCooldown = "TNT: velocidade", TntPower = "TNT: potencia",
            DroneSpeed = "Drone: velocidade", DroneGrab = "Drone: quantidade", DroneCapacity = "Drone: capacidade",
            VacuumPower = "Aspirador: potencia", VacuumCooling = "Aspirador: resfriamento", VacuumRuntime = "Aspirador: autonomia",
        }
        local upgradeButtons = {}
        for _, track in ipairs(upgradeTracks) do
            local capturedTrack = track
            upgradeButtons[capturedTrack] = addNativeButton(shopTab, UpgradeLabels[capturedTrack] or capturedTrack, function()
                requestSessionUpgrade(capturedTrack, true)
            end)
        end

        task.spawn(function()
            while IsHubLoaded and matchCashCard and matchCashCard.Parent do
                task.wait(0.75)
                pcall(function()
                    matchCashCard.Text = formatCash(getCashBalance()) .. " moedas | " .. formatNumber(getGemBalance()) .. " gemas. Opcoes da loja oficial."
                    for toolId, button in pairs(toolPurchaseButtons) do
                        if button and button.Parent then
                            local info = getBarnToolInfo(toolId)
                            local name = info.displayName or BarnToolDisplayNames[toolId] or toolId
                            if isToolOwned(toolId) then
                                button.Text = "[COMPRADO] " .. name
                            elseif PendingToolPurchases[toolId] and os.clock() - PendingToolPurchases[toolId] < 5 then
                                button.Text = "Processando " .. name .. "..."
                            else
                                button.Text = name .. " - " .. formatBarnToolPrice(info)
                            end
                        end
                    end
                    for track, button in pairs(upgradeButtons) do
                        if button and button.Parent then
                            local state = getUpgradeState(track)
                            local label = UpgradeLabels[track] or track
                            if not state then
                                button.Text = label .. " - dados carregando..."
                            elseif not state.available then
                                button.Text = label .. " - requer " .. (BarnToolDisplayNames[state.requiredTool] or state.requiredTool)
                            elseif not state.cost then
                                button.Text = "[MAXIMO] " .. label .. " - nivel " .. tostring(state.level)
                            elseif PendingUpgradePurchases[track] and os.clock() - PendingUpgradePurchases[track] < 5 then
                                button.Text = "Processando " .. label .. "..."
                            else
                                button.Text = string.format("%s - nivel %d/%d - %s", label, state.level, state.maxLevel, formatCash(state.cost))
                            end
                        end
                    end
                end)
            end
        end)

        -- 3. Teleport Tab
        addNativeSection(teleTab, "Locais do mapa", Color3.fromRGB(99, 102, 241))
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
        addNativeSection(teleTab, "Servidor", Color3.fromRGB(99, 102, 241))
        addNativeButton(teleTab, "Return to Lobby Server", function()
            if Remotes.ReturnToLobby then Remotes.ReturnToLobby:FireServer() end
            TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
        end)
        addNativeButton(teleTab, "Rejoin Current Server", function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)

        -- 4. Visuals ESP Tab
        addNativeSection(espTab, "Destaques visuais", Color3.fromRGB(99, 102, 241))
        addNativeToggle(espTab, IS_BASEMENT and "Chave ESP (amarelo)" or "Needle ESP (Bright Yellow)",
            HubState.NeedleESP, function(val) HubState.NeedleESP = val end)
        addNativeToggle(espTab, "Rare / RGB / Void Straw ESP (Magenta)", HubState.RgbESP, function(val) HubState.RgbESP = val end)
        addNativeToggle(espTab, "Gems ESP (Emerald Green)", HubState.GemESP, function(val) HubState.GemESP = val end)
        addNativeToggle(espTab, "Sell Cow ESP (Electric Blue)", HubState.SellESP, function(val) HubState.SellESP = val end)
        addNativeToggle(espTab, "Player ESP (White)", HubState.PlayerESP, function(val) HubState.PlayerESP = val end)

        if basementTab then
            addNativeSection(basementTab, "Capitulo 2: Porão", Color3.fromRGB(255, 190, 75))
            addNativeParagraph(basementTab, "Fluxo do capitulo",
                "Alavancas 1, 2 e 3, depois os puzzles na ordem do jogo. Ao concluir, usa a chave na saida automaticamente. Com Auto TP ligado, aproxima-se da escada e mira a fechadura.",
                Color3.fromRGB(255, 190, 75))
            addNativeToggle(basementTab, "Auto Puzzles", HubState.BasementAutoPuzzles, function(val)
                HubState.BasementAutoPuzzles = val
                if not val then
                    BasementState.automation.active = false
                    if not HubState.AutoWinNeedle then
                        BasementState.automation.exitActive = false
                        BasementState.automation.exitTeleport = false
                    end
                    BasementState.automation.pending = nil
                    BasementState.automation.currentAction = nil
                    BasementSolver.releaseCamera(LocalPlayer:GetAttribute("CutsceneActive") == true)
                end
                addLog("info", "Auto Puzzles: " .. (val and "ligado" or "desligado"))
            end)
            addNativeToggle(basementTab, "Auto TP (puzzles)", HubState.BasementPuzzleTeleport, function(val)
                HubState.BasementPuzzleTeleport = val
                if not val then BasementSolver.releaseCamera(false) end
            end)
            local solverCard = addNativeParagraph(basementTab, "Auto Puzzles", "Desligado", Color3.fromRGB(99, 102, 241))
            local keyCard = addNativeParagraph(basementTab, "Chave", "Carregando estado...", Color3.fromRGB(255, 190, 75))
            local leverCard = addNativeParagraph(basementTab, "Alavancas", "Carregando estado...", Color3.fromRGB(255, 190, 75))
            local puzzleCards = {}
            for _, puzzleId in ipairs(BasementState.requiredPuzzles) do
                puzzleCards[puzzleId] = addNativeParagraph(basementTab,
                    BasementPuzzleLabels[puzzleId] or puzzleId, "Sincronizando puzzle...", Color3.fromRGB(99, 102, 241))
            end
            local exitCard = addNativeParagraph(basementTab, "Saida", "Carregando estado...", Color3.fromRGB(52, 211, 153))
            local nextCard = addNativeParagraph(basementTab, "Proximo objetivo", "Carregando estado...", Color3.fromRGB(255, 190, 75))
            addNativeToggle(basementTab, "Destacar proximo objetivo no mapa", HubState.BasementGuideESP, function(val)
                HubState.BasementGuideESP = val
            end)
            addNativeButton(basementTab, "Sincronizar progresso dos puzzles", function()
                if BasementState.remote and BasementState.remote:IsA("RemoteEvent") then
                    pcall(function() BasementState.remote:FireServer() end)
                else
                    addLog("warn", "PuzzleState nao esta disponivel neste servidor.")
                end
            end)
            local basementStatusThread = task.spawn(function()
                while IsHubLoaded and basementTab.Parent do
                    solverCard.Text = BasementState.automation.status
                    local hayFolder = ReplicatedStorage:FindFirstChild("NeedleHaystack")
                    local keyOwned = LocalPlayer:GetAttribute("NeedleOwned") == true
                    local keyClaimed = hayFolder and hayFolder:GetAttribute("NeedleClaimed") == true
                    keyCard.Text = keyOwned and "Chave em sua posse. Guarde-a para abrir a saida."
                        or (keyClaimed and "Chave ja encontrada nesta rodada; nao esta em sua posse."
                        or "Ainda oculta no feno. O destaque mostra a area quando o alvo aparece.")

                    local pulled = 0
                    for i = 1, 3 do
                        if BasementState.folder and BasementState.folder:GetAttribute("Lever" .. i .. "Pulled") == true then
                            pulled = pulled + 1
                        end
                    end
                    leverCard.Text = string.format("%d/3 acionadas | %s", pulled,
                        BasementState.folder and BasementState.folder:GetAttribute("LeverPuzzleSolved") == true
                            and "concluido" or "pendente")

                    local solved = BasementState.folder and tonumber(BasementState.folder:GetAttribute("SolvedPuzzleCount")) or 0
                    local required = BasementState.folder and tonumber(BasementState.folder:GetAttribute("RequiredPuzzleCount"))
                        or #BasementState.requiredPuzzles
                    for puzzleId, card in pairs(puzzleCards) do
                        local state = BasementState.snapshot and BasementState.snapshot[puzzleId]
                        card.Text = type(state) == "table" and (state.completed == true and "Concluido pelo servidor."
                            or (HubState.BasementAutoPuzzles and BasementState.automation.details[puzzleId])
                            or "Pendente. Ligue Auto Puzzles para resolver.")
                            or "Estado individual ainda nao sincronizado."
                    end
                    local escapeReady = BasementState.folder and BasementState.folder:GetAttribute("EscapeReady") == true
                    local phase = BasementState.folder and BasementState.folder:GetAttribute("ReleasePhase") or "?"
                    exitCard.Text = BasementState.automation.exitStatus or string.format("Puzzles: %d/%d | Saida: %s | Fase: %s", solved or 0,
                        required or #BasementState.requiredPuzzles, escapeReady and "liberada" or "bloqueada", tostring(phase))
                    nextCard.Text = getBasementNextObjective()
                    task.wait(1)
                end
            end)
            table.insert(HubThreads, basementStatusThread)
        end

        -- Default Match Tab Selection
        selectTab(IS_BASEMENT and "Porao" or "Automacao")
    end

    -- ==================================================================
    -- COMMON TABS (BUILT IN BOTH LOBBY AND MATCH)
    -- ==================================================================

    -- Common: Player Tab
    local playerTab = tabFrames["Jogador"]
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
    local consoleTab = tabFrames["Atividade"]
    if consoleTab then
        addNativeSection(consoleTab, "Registro de atividade")
        local consoleBox = Instance.new("TextBox")
        consoleBox.Size = UDim2.new(0.98, 0, 0, 280)
        consoleBox.BackgroundColor3 = UI_THEME.sidebar
        consoleBox.BackgroundTransparency = 0.08
        consoleBox.TextColor3 = UI_THEME.text
        consoleBox.Font = Enum.Font.Code
        consoleBox.TextSize = 12
        consoleBox.ClearTextOnFocus = false
        consoleBox.TextEditable = false
        consoleBox.TextXAlignment = Enum.TextXAlignment.Left
        consoleBox.TextYAlignment = Enum.TextYAlignment.Top
        consoleBox.MultiLine = true
        consoleBox.Active = false
        consoleBox.Text = table.concat(LogEntries, "\n")
        consoleBox.Parent = consoleTab
        local cbCorner = Instance.new("UICorner") cbCorner.CornerRadius = UDim.new(0, 9) cbCorner.Parent = consoleBox
        local cbStroke = Instance.new("UIStroke") cbStroke.Color = UI_THEME.border cbStroke.Transparency = 0.7 cbStroke.Thickness = 1 cbStroke.Parent = consoleBox

        local consoleRefreshThread = task.spawn(function()
            while IsHubLoaded and consoleBox and consoleBox.Parent do
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

        addNativeButton(consoleTab, "Listar remotos detectados", function()
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
    local setTab = tabFrames["Ajustes"]
    if setTab then
        addNativeSection(setTab, "Atualizacoes")

        local versionCard = addNativeParagraph(setTab, "Versao do hub",
            "Instalada: v" .. SCRIPT_VERSION .. "\nGitHub: aguardando consulta")
        local checkButton
        local function refreshVersionCard()
            versionCard.Text = "Instalada: v" .. SCRIPT_VERSION .. "\nGitHub: verificando..."
            if checkButton then checkButton.Text = "Verificando GitHub..." end
            checkForScriptUpdates(function(notice, available, remoteVersion)
                if not versionCard.Parent then return end
                local githubText = remoteVersion and ("v" .. remoteVersion) or "indisponivel"
                versionCard.Text = "Instalada: v" .. SCRIPT_VERSION .. "\nGitHub: " .. githubText .. " - " .. notice
                if checkButton and checkButton.Parent then
                    checkButton.Text = remoteVersion and "Verificar novamente" or "Tentar novamente"
                end
            end)
        end
        checkButton = addNativeButton(setTab, "Verificar versao no GitHub", refreshVersionCard)
        refreshVersionCard()
        versionLabel.MouseButton1Click:Connect(function()
            setWindowMinimized(false)
            selectTab("Ajustes")
            refreshVersionCard()
        end)

        addNativeButton(setTab, "Atualizar / Recarregar Script (Auto-Download)", function()
            versionCard.Text = "Instalada: v" .. SCRIPT_VERSION .. "\nBaixando script do GitHub..."
            local commitSha = readGitHubHeadSha() or ScriptUpdateState.commitSha
            local downloadOk, source = pcall(function()
                return game:HttpGet(ScriptUpdateState.rawRoot .. (commitSha or "master") .. "/main.lua?cb=" .. versionCacheKey())
            end)
            if not downloadOk or type(source) ~= "string" or #source == 0 then
                versionCard.Text = "Instalada: v" .. SCRIPT_VERSION .. "\nFalha ao baixar. Tente novamente."
                return
            end
            local downloadedVersion = source:match('local%s+SCRIPT_VERSION%s*=%s*"([^"]+)"')
            local comparison = downloadedVersion and compareHubVersions(downloadedVersion, SCRIPT_VERSION) or nil
            if comparison == nil or comparison < 0 then
                versionCard.Text = "Instalada: v" .. SCRIPT_VERSION .. "\nArquivo remoto invalido ou mais antigo."
                return
            end
            local loader, compileError = loadstring(source)
            if not loader then
                versionCard.Text = "Instalada: v" .. SCRIPT_VERSION .. "\nFalha ao preparar a atualizacao."
                addLog("error", tostring(compileError))
                return
            end
            versionCard.Text = "Instalada: v" .. SCRIPT_VERSION .. "\nAbrindo versao baixada..."
            local runOk, runError = pcall(loader)
            if not runOk then
                addLog("error", "Falha ao abrir script baixado: " .. tostring(runError))
                if versionCard.Parent then
                    versionCard.Text = "Instalada: v" .. SCRIPT_VERSION .. "\nFalha ao abrir a atualizacao."
                end
            end
        end, true)

        addNativeParagraph(setTab, "Atalho do menu",
            "RightShift abre ou fecha o menu. A bolinha permanece visivel para usar com o mouse.")

        addNativeSection(setTab, "Sessao")
        addNativeButton(setTab, "Fechar e descarregar o hub", function()
            unloadHub()
        end, true)
    end

    createFloatingToggleButton(function()
        setMenuVisible(not mainFrame.Visible)
    end)
    trackUIConnection(UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode ~= MENU_TOGGLE_KEY then return end
        if UserInputService:GetFocusedTextBox() then return end
        setMenuVisible(not mainFrame.Visible)
    end))
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

-- Initialize UI & Apply Camera Snap
local okUi, errUi = pcall(buildNativeUI)
if not okUi then
    warn("[Needle Hub Error]: Failed to construct UI: " .. tostring(errUi))
    addLog("error", "UI Construct Error: " .. tostring(errUi))
end
forceSnap3rdPerson(22)
addLog("info", "Needle Hub v" .. SCRIPT_VERSION .. " loaded successfully! Press LeftAlt to toggle mouse, hold RMB to rotate camera.")
