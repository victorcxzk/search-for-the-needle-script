--[[
    SEARCH FOR THE NEEDLE - ULTIMATE FORENSIC DUMPER v3.1
    Ultra-Resilient Game Explorer & Reverse Engineering Scanner
    - Live On-Screen Visual Progress HUD (never silent)
    - Zero-Hang Safe Architecture (no indefinite yields)
    - ReplicatedStorage Tree & Full Remote Catalog
    - Targeted Module & Config Inspection
    - Workspace Prompts, Models, Spawns & CollectionService Tags
    - Complete PlayerGui Hierarchy & Text Elements
    - Targeted Game LocalScripts & Modules Decompilation
    - Dual File Output: workspace/forensics_v3.txt & workspace/forensics.txt
    - Zero emojis - 100% Executor Safe
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
local CollectionService = safeService("CollectionService")
local StarterGui = safeService("StarterGui")
local CoreGui = safeService("CoreGui")
local TweenService = safeService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- ON-SCREEN VISUAL PROGRESS OVERLAY
local hudGui = nil
local statusLbl = nil
local fillBar = nil

pcall(function()
    local old = CoreGui:FindFirstChild("NeedleDumperHUD") or (LocalPlayer and LocalPlayer.PlayerGui:FindFirstChild("NeedleDumperHUD"))
    if old then old:Destroy() end

    hudGui = Instance.new("ScreenGui")
    hudGui.Name = "NeedleDumperHUD"
    hudGui.ResetOnSpawn = false
    pcall(function() hudGui.Parent = CoreGui end)
    if not hudGui.Parent and LocalPlayer then hudGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(360, 80)
    card.Position = UDim2.new(0.5, -180, 0.08, 0)
    card.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
    card.BorderSizePixel = 0
    card.Parent = hudGui

    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 10) corner.Parent = card
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(99, 102, 241) stroke.Thickness = 1.6 stroke.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 22)
    titleLbl.Position = UDim2.fromOffset(12, 6)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "NEEDLE FORENSIC DUMPER v3.1"
    titleLbl.TextColor3 = Color3.fromRGB(129, 140, 248)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card

    statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -20, 0, 20)
    statusLbl.Position = UDim2.fromOffset(12, 28)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Iniciando exploracao do jogo..."
    statusLbl.TextColor3 = Color3.fromRGB(220, 225, 240)
    statusLbl.Font = Enum.Font.GothamMedium
    statusLbl.TextSize = 11
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = card

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -24, 0, 8)
    barBg.Position = UDim2.fromOffset(12, 56)
    barBg.BackgroundColor3 = Color3.fromRGB(28, 31, 46)
    barBg.BorderSizePixel = 0
    barBg.Parent = card
    local bbc = Instance.new("UICorner") bbc.CornerRadius = UDim.new(1, 0) bbc.Parent = barBg

    fillBar = Instance.new("Frame")
    fillBar.Size = UDim2.fromScale(0.05, 1)
    fillBar.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    fillBar.BorderSizePixel = 0
    fillBar.Parent = barBg
    local fbc = Instance.new("UICorner") fbc.CornerRadius = UDim.new(1, 0) fbc.Parent = fillBar
end)

local function updateProgress(text, progressFrac)
    print("[DUMPER] " .. text)
    if statusLbl then statusLbl.Text = text end
    if fillBar then
        fillBar.Size = UDim2.fromScale(math.clamp(progressFrac or 0.1, 0.05, 1), 1)
    end
    task.wait(0.05)
end

-- Native Toast Notification
pcall(function()
    if StarterGui then
        StarterGui:SetCore("SendNotification", {
            Title = "Needle Dumper v3.1",
            Text = "Execucao iniciada! Acompanhe a barra no topo da tela.",
            Duration = 5
        })
    end
end)

local report = {}
local function out(str)
    report[#report + 1] = tostring(str)
end

local function header(title)
    out("
" .. string.rep("=", 64))
    out("[FORENSICS] " .. string.upper(title))
    out(string.rep("=", 64))
end

-- Table serializer helper
local function serializeTable(tbl, maxDepth, currentDepth, indent)
    maxDepth = maxDepth or 3
    currentDepth = currentDepth or 0
    indent = indent or "  "
    if currentDepth > maxDepth then return indent .. "... (max depth reached)" end

    local lines = {}
    for k, v in pairs(tbl) do
        local kStr = tostring(k)
        local vType = type(v)
        if vType == "table" then
            table.insert(lines, indent .. kStr .. " (table) = {")
            table.insert(lines, serializeTable(v, maxDepth, currentDepth + 1, indent .. "  "))
            table.insert(lines, indent .. "}")
        elseif vType == "function" then
            table.insert(lines, indent .. kStr .. " = [function]")
        elseif vType == "string" then
            table.insert(lines, indent .. kStr .. " = "" .. tostring(v) .. """)
        else
            table.insert(lines, indent .. kStr .. " = " .. tostring(v) .. " (" .. vType .. ")")
        end
    end
    return table.concat(lines, "
")
end

-- SECTION 0: METADATA & PLACE CONTEXT
updateProgress("Identificando servidor e mapa...", 0.1)
header("0. SESSION & PLACE CONTEXT")
out("Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S"))
out("PlaceId: " .. tostring(game.PlaceId))
out("PlaceVersion: " .. tostring(game.PlaceVersion))
out("JobId: " .. tostring(game.JobId))
out("GameId: " .. tostring(game.GameId))
out("Player Name: " .. (LocalPlayer and LocalPlayer.Name or "Unknown"))
out("Player UserId: " .. (LocalPlayer and tostring(LocalPlayer.UserId) or "Unknown"))

local placeType = "UNKNOWN"
if game.PlaceId == 77108422251420 then
    placeType = "LOBBY"
elseif game.PlaceId == 108628039999641 then
    placeType = "FARMHOUSE (GAMEPLAY)"
elseif game.PlaceId == 83445806734780 then
    placeType = "BASEMENT (GAMEPLAY)"
end
out("Detected Location: " .. placeType)

-- SECTION 1: PLAYER ATTRIBUTES & DATA
updateProgress("Escaneando atributos do jogador...", 0.2)
header("1. LOCAL PLAYER ATTRIBUTES & BACKPACK")
if LocalPlayer then
    out("--- LocalPlayer Attributes ---")
    local attrs = LocalPlayer:GetAttributes()
    local attrCount = 0
    for aName, aVal in pairs(attrs) do
        attrCount = attrCount + 1
        out(string.format("  [%s] = %s (%s)", tostring(aName), tostring(aVal), type(aVal)))
    end
    out("Total Player Attributes: " .. tostring(attrCount))

    out("
--- Backpack Items ---")
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for i, item in ipairs(bp:GetChildren()) do
            out(string.format("  [%d] %s (%s)", i, item.Name, item.ClassName))
        end
    else
        out("  Backpack not found")
    end

    out("
--- Character Hierarchy & Equipped Tools ---")
    local char = LocalPlayer.Character
    if char then
        out("  Character Name: " .. char.Name)
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") then
                out("  [Equipped Tool] " .. c.Name)
            end
        end
        local charAttrs = char:GetAttributes()
        for k, v in pairs(charAttrs) do
            out(string.format("  [CharAttr] %s = %s", tostring(k), tostring(v)))
        end
    else
        out("  Character not loaded")
    end
end

-- SECTION 2: REPLICATED STORAGE COMPREHENSIVE SCAN
updateProgress("Escaneando ReplicatedStorage e Remotes...", 0.35)
header("2. REPLICATED STORAGE COMPREHENSIVE TREE")
if ReplicatedStorage then
    local remotesFound = {}
    local modulesFound = {}
    local valueObjectsFound = {}

    local function scanRS(parent, indent, depth)
        if depth > 8 then return end
        for _, obj in ipairs(parent:GetChildren()) do
            local line = indent .. "- " .. obj.Name .. " [" .. obj.ClassName .. "]"
            
            local attrs = obj:GetAttributes()
            if next(attrs) ~= nil then
                local aList = {}
                for k, v in pairs(attrs) do table.insert(aList, tostring(k) .. "=" .. tostring(v)) end
                line = line .. " {Attrs: " .. table.concat(aList, ", ") .. "}"
            end

            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") or obj:IsA("BindableFunction") then
                table.insert(remotesFound, {Path = obj:GetFullName(), Class = obj.ClassName, Name = obj.Name})
                line = line .. " *** REMOTE ***"
            elseif obj:IsA("ModuleScript") then
                table.insert(modulesFound, obj)
            elseif obj:IsA("ValueBase") or obj:IsA("Configuration") then
                local val = ""
                pcall(function() val = tostring(obj.Value) end)
                line = line .. " (Value: " .. val .. ")"
                table.insert(valueObjectsFound, obj)
            end

            out(line)
            pcall(function()
                if #obj:GetChildren() > 0 and not obj:IsA("ModuleScript") then
                    scanRS(obj, indent .. "  ", depth + 1)
                end
            end)
        end
    end

    scanRS(ReplicatedStorage, "", 0)

    out("
--- SUMMARY OF ALL REMOTES IN REPLICATED STORAGE ---")
    out("Total Remotes Found: " .. tostring(#remotesFound))
    for i, r in ipairs(remotesFound) do
        out(string.format("  [%02d] %s -> %s", i, r.Class, r.Path))
    end

    -- Target only modules containing Config, Data, Pet, Class, Code, Shop
    updateProgress("Inspecionando modulos de configuracao...", 0.5)
    out("
--- TARGETED CONFIG & DATA MODULES INSPECTION ---")
    for _, mod in ipairs(modulesFound) do
        local mName = mod.Name:lower()
        if mName:find("config") or mName:find("data") or mName:find("pet") or mName:find("class") or mName:find("code") or mName:find("shop") or mName:find("upgrade") then
            out("
[Safe Config Module] " .. mod:GetFullName())
            local s, res = pcall(function() return require(mod) end)
            if s and type(res) == "table" then
                out(serializeTable(res, 2, 0, "  "))
            elseif s then
                out("  Result: " .. tostring(res))
            else
                out("  Require failed or yielded: " .. tostring(res))
            end
        end
    end
end

-- SECTION 3: WORKSPACE LANDMARKS, NPCS, PROMPTS & OBJECTS
updateProgress("Mapeando Workspace, Prompts e Modelos...", 0.65)
header("3. WORKSPACE LANDMARKS, PROMPTS & INTERACTABLES")
if Workspace then
    out("--- All ProximityPrompts in Workspace ---")
    local promptCount = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            promptCount = promptCount + 1
            local parentPath = desc.Parent and desc.Parent:GetFullName() or "Nil"
            out(string.format("  Prompt [%d]: ObjectText="%s" | ActionText="%s" | Hold=%.2fs | Dist=%.1f | Enabled=%s | Parent=%s",
                promptCount, tostring(desc.ObjectText), tostring(desc.ActionText),
                tonumber(desc.HoldDuration) or 0, tonumber(desc.MaxActivationDistance) or 0,
                tostring(desc.Enabled), parentPath))
        end
    end
    out("Total ProximityPrompts: " .. tostring(promptCount))

    out("
--- CollectionService Tags Scan ---")
    local allTags = {}
    pcall(function() allTags = CollectionService:GetAllTags() end)
    out("Total Tags Found: " .. tostring(#allTags))
    for _, tagName in ipairs(allTags) do
        local taggedList = CollectionService:GetTagged(tagName)
        out(string.format("  Tag: [%s] (%d instances)", tagName, #taggedList))
        for j = 1, math.min(5, #taggedList) do
            local inst = taggedList[j]
            local pos = "N/A"
            if inst:IsA("BasePart") then pos = tostring(inst.Position)
            elseif inst:IsA("Model") then pcall(function() pos = tostring(inst:GetPivot().Position) end) end
            out(string.format("    [%d] %s (%s) @ %s", j, inst.Name, inst.ClassName, pos))
        end
    end

    out("
--- Workspace Root Level Children ---")
    for _, child in ipairs(Workspace:GetChildren()) do
        local pos = "N/A"
        if child:IsA("BasePart") then pos = tostring(child.Position)
        elseif child:IsA("Model") then pcall(function() pos = tostring(child:GetPivot().Position) end) end
        out(string.format("  - %s [%s] @ %s (Children: %d)", child.Name, child.ClassName, pos, #child:GetChildren()))
    end

    local haystack = Workspace:FindFirstChild("HaystackClient")
    if haystack then
        local kids = haystack:GetChildren()
        out("  HaystackClient Children Count: " .. tostring(#kids))
    end

    local gemsClient = Workspace:FindFirstChild("GemsClient")
    if gemsClient then
        local gemKids = gemsClient:GetChildren()
        out("  GemsClient Children Count: " .. tostring(#gemKids))
        for i = 1, math.min(15, #gemKids) do
            local g = gemKids[i]
            local pos = "N/A"
            if g:IsA("BasePart") then pos = tostring(g.Position)
            elseif g:IsA("Model") then pcall(function() pos = tostring(g:GetPivot().Position) end) end
            out(string.format("    Gem [%d] Name: %s | Class: %s | Pos: %s", i, g.Name, g.ClassName, pos))
        end
    end
end

-- SECTION 4: PLAYER GUI COMPLETE DUMP
updateProgress("Escaneando PlayerGui e Interface do Jogo...", 0.8)
header("4. PLAYER GUI & INTERFACE HIERARCHY")
if LocalPlayer then
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        local function scanGui(parent, indent, depth)
            if depth > 6 then return end
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name ~= "NeedleDumperHUD" and child.Name ~= "NeedleHubNative" and child.Name ~= "NeedleHubFloatingBtn" then
                    local line = indent .. "- " .. child.Name .. " [" .. child.ClassName .. "]"
                    if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                        line = line .. " Text="" .. tostring(child.Text) .. """
                    end
                    if child:IsA("GuiObject") then
                        line = line .. " Visible=" .. tostring(child.Visible)
                    end
                    out(line)
                    pcall(function()
                        if #child:GetChildren() > 0 then
                            scanGui(child, indent .. "  ", depth + 1)
                        end
                    end)
                end
            end
        end
        scanGui(pGui, "", 0)
    else
        out("PlayerGui not found.")
    end
end

-- SECTION 5: PLAYERSCRIPTS DECOMPILATION (TARGETED GAME SCRIPTS ONLY)
updateProgress("Descompilando scripts do cliente...", 0.9)
header("5. PLAYERSCRIPTS DECOMPILATION (GAME SCRIPTS ONLY)")
if LocalPlayer then
    local pScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if pScripts then
        local gameScripts = {}
        for _, desc in ipairs(pScripts:GetDescendants()) do
            if desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
                local fullName = desc:GetFullName()
                -- Skip Roblox Core PlayerModule internals to prevent freezes
                if not fullName:find("PlayerModule") and not fullName:find("RbxCharacterSounds") and not fullName:find("ChatScript") then
                    table.insert(gameScripts, desc)
                end
            end
        end
        out("Total Game Client Scripts Found: " .. tostring(#gameScripts))

        for _, scr in ipairs(gameScripts) do
            out("
" .. string.rep("-", 50))
            out("SCRIPT: " .. scr:GetFullName() .. " [" .. scr.ClassName .. "]")
            out(string.rep("-", 50))
            if decompiler then
                local s, res = pcall(decompiler, scr)
                if s and res and #res > 0 then
                    out(res)
                else
                    out("[Decompile error or empty: " .. tostring(res) .. "]")
                end
            else
                out("[Decompiler function not available on this executor]")
            end
        end
    end
end

-- SECTION 6: SAVE TO FILE & FINISH
updateProgress("Salvando relatorio em disco...", 0.98)
local fullReport = table.concat(report, "
")
local fileName1 = "forensics_v3.txt"
local fileName2 = "forensics.txt"

if write_file then
    pcall(function() write_file(fileName1, fullReport) end)
    pcall(function() write_file(fileName2, fullReport) end)
end

updateProgress("DUMP CONCLUIDO COM SUCESSO!", 1.0)

if statusLbl then
    statusLbl.Text = "CONCLUIDO! Salvo em workspace/" .. fileName1
    statusLbl.TextColor3 = Color3.fromRGB(34, 197, 94)
end
if fillBar then
    fillBar.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
end

pcall(function()
    if StarterGui then
        StarterGui:SetCore("SendNotification", {
            Title = "Needle Dumper - Sucesso!",
            Text = "Relatorio completo salvo em workspace/forensics_v3.txt (" .. #fullReport .. " bytes)",
            Duration = 10
        })
    end
end)

print("
==================================================")
print("[FORENSICS v3.1 COMPLETE!]")
print("Salvo em: workspace/" .. fileName1 .. " e workspace/" .. fileName2)
print("Tamanho: " .. #fullReport .. " bytes (" .. #report .. " linhas)")
print("==================================================")

-- Fade out HUD after 6 seconds
task.delay(6, function()
    if hudGui then
        pcall(function() hudGui:Destroy() end)
    end
end)
