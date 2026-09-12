--[[
    TARGETED GAMEPLAY FORENSICS DUMPER v2.0
    Extracts complete LocalScripts, Rainbow/RGB Hay properties, Gems, and Full Configs.
    Outputs directly to workspace/forensics_v2.txt
    Zero emojis - 100% Executor Safe
]]

local decompiler = decompile or disassemble
local write_file = writefile

local function safeService(name)
    local s = nil
    pcall(function()
        s = cloneref and cloneref(game:GetService(name)) or game:GetService(name)
    end)
    if not s then pcall(function() s = game:GetService(name) end) end
    return s
end

local Players = safeService("Players")
local ReplicatedStorage = safeService("ReplicatedStorage")
local Workspace = safeService("Workspace")
local LocalPlayer = Players.LocalPlayer

local report = {}
local function out(str)
    report[#report + 1] = tostring(str)
end

local function header(title)
    out("\n================================================================")
    out("[FORENSICS] " .. string.upper(title))
    out("================================================================")
end

out("GAMEPLAY FORENSIC EXTRACTION REPORT")
out("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
out("PlaceId: " .. tostring(game.PlaceId))
out("Player: " .. (LocalPlayer and LocalPlayer.Name or "Unknown"))

-- SECTION 1: DECOMPILE TARGETED LOCAL SCRIPTS
header("1. LOCAL SCRIPTS DECOMPILATION (PLAYERSCRIPTS)")

local targetLocalScripts = {
    "NeedleHaystackClient",
    "NeedlePitchforkClient",
    "NeedleGemsClient",
    "NeedleSellEffects",
    "Client",
    "NeedleUpgradeClient",
    "NeedleTntClient",
    "NeedleDroneClient",
    "NeedleVacuumClient",
    "NeedleRoundTimerClient",
    "UfoHandler"
}

local playerScripts = LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
if playerScripts then
    for _, scriptName in ipairs(targetLocalScripts) do
        local scr = playerScripts:FindFirstChild(scriptName)
        if scr then
            out("\n--- LOCAL SCRIPT: " .. scriptName .. " ---")
            if decompiler then
                local s, res = pcall(decompiler, scr)
                if s and res then
                    out(res)
                else
                    out("Decompilation error: " .. tostring(res))
                end
            else
                out("Decompiler function not available on this executor.")
            end
        else
            out("\n[Not Found]: " .. scriptName)
        end
    end
else
    out("PlayerScripts folder not found.")
end

-- SECTION 2: FULL DECOMPILATION OF CRITICAL MODULES (NO TRUNCATION)
header("2. CRITICAL MODULES (FULL SOURCE)")

local targetModules = {
    ReplicatedStorage:FindFirstChild("NeedleHaystack") and ReplicatedStorage.NeedleHaystack:FindFirstChild("Config"),
    ReplicatedStorage:FindFirstChild("NeedleHaystack") and ReplicatedStorage.NeedleHaystack:FindFirstChild("GemConfig"),
    ReplicatedStorage:FindFirstChild("NeedleHaystack") and ReplicatedStorage.NeedleHaystack:FindFirstChild("Surface"),
}

for _, mod in ipairs(targetModules) do
    if mod and mod:IsA("ModuleScript") then
        out("\n--- MODULE: " .. mod:GetFullName() .. " ---")
        if decompiler then
            local s, res = pcall(decompiler, mod)
            if s and res then
                out(res)
            else
                out("Decompile error: " .. tostring(res))
            end
        end
    end
end

-- SECTION 3: HAYSTACK & RAINBOW / RGB FORENSIC ANALYSIS
header("3. HAYSTACK CLIENT & RAINBOW / RGB ANALYSIS")

local haystack = Workspace:FindFirstChild("HaystackClient")
if haystack then
    local children = haystack:GetChildren()
    out("Total HaystackClient children: " .. tostring(#children))

    -- Sample first 10 children
    out("\n--- First 10 Children Sample ---")
    for i = 1, math.min(10, #children) do
        local c = children[i]
        local attrStr = ""
        for aName, aVal in pairs(c:GetAttributes()) do
            attrStr = attrStr .. string.format(" [%s=%s]", tostring(aName), tostring(aVal))
        end
        local colStr = c:IsA("BasePart") and tostring(c.Color) or "N/A"
        local matStr = c:IsA("BasePart") and tostring(c.Material) or "N/A"
        out(string.format("  [%d] Name: %s | Class: %s | Color: %s | Material: %s | Attrs: %s",
            i, c.Name, c.ClassName, colStr, matStr, attrStr))
    end

    -- Scan for RAINBOW / RGB / UNUSUAL HAY
    out("\n--- Searching for Non-Default / Rainbow / RGB Strands ---")
    local specialCount = 0
    for i = 1, #children do
        local c = children[i]
        if c:IsA("BasePart") then
            local color = c.Color
            local h, s, v = color:ToHSV()
            local isSpecial = false
            local reason = ""

            -- Check if Material is Neon / Glass / ForceField
            if c.Material ~= Enum.Material.Plastic and c.Material ~= Enum.Material.SmoothPlastic and c.Material ~= Enum.Material.Wood then
                isSpecial = true
                reason = reason .. " [Material: " .. tostring(c.Material) .. "]"
            end

            -- Check if Color Hue is outside yellow/orange (0.08 .. 0.16) and has saturation
            if s > 0.25 and (h < 0.08 or h > 0.17) then
                isSpecial = true
                reason = reason .. string.format(" [RGB Color: H=%.2f, S=%.2f, V=%.2f, RGB=%s]", h, s, v, tostring(color))
            end

            -- Check for Children (ParticleEmitter, PointLight, Highlight, BillboardGui)
            local numKids = #c:GetChildren()
            if numKids > 0 then
                isSpecial = true
                local kidNames = {}
                for _, k in ipairs(c:GetChildren()) do table.insert(kidNames, k.ClassName .. ":" .. k.Name) end
                reason = reason .. " [Children: " .. table.concat(kidNames, ", ") .. "]"
            end

            -- Check for Attributes
            local attrs = c:GetAttributes()
            if next(attrs) ~= nil then
                isSpecial = true
                local aList = {}
                for aName, aVal in pairs(attrs) do table.insert(aList, tostring(aName) .. "=" .. tostring(aVal)) end
                reason = reason .. " [Attrs: " .. table.concat(aList, ", ") .. "]"
            end

            if isSpecial then
                specialCount = specialCount + 1
                if specialCount <= 50 then
                    out(string.format("  Special Strand [%d] Name: %s | Pos: %s | Reason: %s",
                        specialCount, c.Name, tostring(c.Position), reason))
                end
            end
        end
    end
    out("Total Special / RGB Strands Found: " .. tostring(specialCount))
else
    out("HaystackClient not found in Workspace.")
end

-- SECTION 4: GEMS CLIENT INSPECTION
header("4. GEMS CLIENT INSPECTION")

local gemsClient = Workspace:FindFirstChild("GemsClient")
if gemsClient then
    local gemChildren = gemsClient:GetChildren()
    out("Total GemsClient children: " .. tostring(#gemChildren))
    for i, g in ipairs(gemChildren) do
        local attrStr = ""
        pcall(function()
            for aName, aVal in pairs(g:GetAttributes()) do
                attrStr = attrStr .. string.format(" [%s=%s]", tostring(aName), tostring(aVal))
            end
        end)
        local kidStr = ""
        pcall(function()
            for _, k in ipairs(g:GetChildren()) do
                kidStr = kidStr .. " " .. k.ClassName .. ":" .. k.Name
            end
        end)
        local posStr = "N/A"
        local colorStr = "N/A"
        if g:IsA("BasePart") then
            posStr = tostring(g.Position)
            colorStr = tostring(g.Color)
        elseif g:IsA("Model") then
            pcall(function() posStr = tostring(g:GetPivot().Position) end)
        elseif g:IsA("Highlight") then
            colorStr = string.format("Fill:%s, Outline:%s, Adornee:%s", tostring(g.FillColor), tostring(g.OutlineColor), tostring(g.Adornee))
        end
        out(string.format("  [%d] Name: %s | Class: %s | Pos: %s | Color: %s | Attrs: %s | Kids: %s",
            i, g.Name, g.ClassName, posStr, colorStr, attrStr, kidStr))
    end
else
    out("GemsClient folder not found in Workspace.")
end

-- SECTION 5: DROPPED HAY & PICKUP EFFECTS
header("5. DROPPED HAY & EFFECTS")

local droppedHay = Workspace:FindFirstChild("DroppedHay")
if droppedHay then
    local dChildren = droppedHay:GetChildren()
    out("DroppedHay children: " .. tostring(#dChildren))
    for i, d in ipairs(dChildren) do
        local posStr = "N/A"
        if d:IsA("BasePart") then
            posStr = tostring(d.Position)
        elseif d:IsA("Model") then
            pcall(function() posStr = tostring(d:GetPivot().Position) end)
        end
        out(string.format("  [%d] Name: %s | Class: %s | Pos: %s", i, d.Name, d.ClassName, posStr))
    end
else
    out("DroppedHay folder not found.")
end

local pickupEffects = Workspace:FindFirstChild("PickupEffectsClient")
if pickupEffects then
    out("PickupEffectsClient children: " .. tostring(#pickupEffects:GetChildren()))
end

-- SECTION 6: PLAYER ATTRIBUTES SNAPSHOT
header("6. PLAYER ATTRIBUTES SNAPSHOT")

if LocalPlayer then
    for aName, aVal in pairs(LocalPlayer:GetAttributes()) do
        out(string.format("  %s = %s (%s)", tostring(aName), tostring(aVal), type(aVal)))
    end
end

-- WRITE REPORT TO FILE
local fullReport = table.concat(report, "\n")
if write_file then
    pcall(function()
        write_file("forensics_v2.txt", fullReport)
    end)
    print("\n[FORENSICS COMPLETE] Saved report to workspace/forensics_v2.txt (" .. #fullReport .. " bytes)")
else
    print("\n[FORENSICS COMPLETE] writefile not available. Report length: " .. #fullReport)
end

-- Print summary to console
print("==================================================")
print("FORENSIC DUMP v2 COMPLETED!")
print("Saved to: workspace/forensics_v2.txt")
print("==================================================")
