--[[
    SEARCH FOR THE NEEDLE - ULTIMATE FORENSIC DUMPER v3.0
    Comprehensive Game Explorer & Reverse Engineering Scanner
    - Full ReplicatedStorage tree & Remote mapping
    - Workspace Prompts, CollectionService tags, NPCs & Spawns
    - Complete PlayerGui dump (UI elements, text, buttons, paths)
    - Player attributes, Backpack tools & Character inspection
    - ModuleScript table serialization (require)
    - Full LocalScript decompilation (PlayerScripts)
    - Zero emojis - 100% Executor Safe
    Outputs directly to: workspace/forensics_v3.txt
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
local HttpService = safeService("HttpService")
local UserInputService = safeService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local report = {}
local function out(str)
    report[#report + 1] = tostring(str)
end

local function header(title)
    out("\n" .. string.rep("=", 64))
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
            table.insert(lines, indent .. kStr .. " = \"" .. tostring(v) .. "\"")
        else
            table.insert(lines, indent .. kStr .. " = " .. tostring(v) .. " (" .. vType .. ")")
        end
    end
    return table.concat(lines, "\n")
end

-- SECTION 0: METADATA & SESSION CONTEXT
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

    out("\n--- Backpack Items ---")
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for i, item in ipairs(bp:GetChildren()) do
            out(string.format("  [%d] %s (%s)", i, item.Name, item.ClassName))
        end
    else
        out("  Backpack not found")
    end

    out("\n--- Character Hierarchy & Equipped Tools ---")
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
header("2. REPLICATED STORAGE COMPREHENSIVE TREE")
if ReplicatedStorage then
    local remotesFound = {}
    local modulesFound = {}
    local valueObjectsFound = {}
    local foldersFound = {}

    local function scanRS(parent, indent)
        for _, obj in ipairs(parent:GetChildren()) do
            local line = indent .. "- " .. obj.Name .. " [" .. obj.ClassName .. "]"
            
            -- Check for attributes
            local attrs = obj:GetAttributes()
            if next(attrs) ~= nil then
                local aList = {}
                for k, v in pairs(attrs) do table.insert(aList, tostring(k) .. "=" .. tostring(v)) end
                line = line .. " {Attrs: " .. table.concat(aList, ", ") .. "}"
            end

            -- Track specifics
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
            elseif obj:IsA("Folder") then
                table.insert(foldersFound, obj)
            end

            out(line)
            pcall(function()
                if #obj:GetChildren() > 0 and not obj:IsA("ModuleScript") then
                    scanRS(obj, indent .. "  ")
                end
            end)
        end
    end

    out("Scanning ReplicatedStorage descendants...")
    scanRS(ReplicatedStorage, "")

    out("\n--- SUMMARY OF ALL REMOTES IN REPLICATED STORAGE ---")
    out("Total Remotes Found: " .. tostring(#remotesFound))
    for i, r in ipairs(remotesFound) do
        out(string.format("  [%02d] %s -> %s", i, r.Class, r.Path))
    end

    out("\n--- REQUIRE & INSPECTION OF MODULE SCRIPTS ---")
    for _, mod in ipairs(modulesFound) do
        out("\n[ModuleScript] " .. mod:GetFullName())
        local s, res = pcall(function() return require(mod) end)
        if s then
            if type(res) == "table" then
                out("  Successfully required! Table dump:")
                local serialized = serializeTable(res, 3, 0, "    ")
                out(serialized)
            else
                out("  Required return type: " .. type(res) .. " = " .. tostring(res))
            end
        else
            out("  Failed to require: " .. tostring(res))
        end
    end
end

-- SECTION 3: WORKSPACE LANDMARKS, NPCS, PROMPTS & OBJECTS
header("3. WORKSPACE LANDMARKS, PROMPTS & INTERACTABLES")
if Workspace then
    out("--- All ProximityPrompts in Workspace ---")
    local promptCount = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            promptCount = promptCount + 1
            local parentPath = desc.Parent and desc.Parent:GetFullName() or "Nil"
            out(string.format("  Prompt [%d]: ObjectText=\"%s\" | ActionText=\"%s\" | Hold=%.2fs | Dist=%.1f | Enabled=%s | Parent=%s",
                promptCount, tostring(desc.ObjectText), tostring(desc.ActionText),
                tonumber(desc.HoldDuration) or 0, tonumber(desc.MaxActivationDistance) or 0,
                tostring(desc.Enabled), parentPath))
        end
    end
    out("Total ProximityPrompts: " .. tostring(promptCount))

    out("\n--- CollectionService Tags Scan ---")
    local allTags = {}
    pcall(function()
        allTags = CollectionService:GetAllTags()
    end)
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

    out("\n--- Workspace Root Level Children ---")
    for _, child in ipairs(Workspace:GetChildren()) do
        local pos = "N/A"
        if child:IsA("BasePart") then pos = tostring(child.Position)
        elseif child:IsA("Model") then pcall(function() pos = tostring(child:GetPivot().Position) end) end
        out(string.format("  - %s [%s] @ %s (Children: %d)", child.Name, child.ClassName, pos, #child:GetChildren()))
    end

    out("\n--- HaystackClient Forensic Analysis (if present) ---")
    local haystack = Workspace:FindFirstChild("HaystackClient")
    if haystack then
        local kids = haystack:GetChildren()
        out("  HaystackClient Children Count: " .. tostring(#kids))
        local specialCount = 0
        for i = 1, #kids do
            local c = kids[i]
            if c:IsA("BasePart") then
                local col = c.Color
                local h, s, v = col:ToHSV()
                local isSpecial = false
                local note = ""
                if c.Material ~= Enum.Material.Plastic and c.Material ~= Enum.Material.SmoothPlastic and c.Material ~= Enum.Material.Wood then
                    isSpecial = true
                    note = note .. " [Mat: " .. tostring(c.Material) .. "]"
                end
                if s > 0.25 and (h < 0.08 or h > 0.17) then
                    isSpecial = true
                    note = note .. string.format(" [RGB Hue: %.2f, Sat: %.2f, Val: %.2f]", h, s, v)
                end
                if #c:GetChildren() > 0 then
                    isSpecial = true
                    note = note .. " [Has Children: " .. tostring(#c:GetChildren()) .. "]"
                end
                if isSpecial then
                    specialCount = specialCount + 1
                    if specialCount <= 25 then
                        out(string.format("    Special [%d] %s @ %s | %s", specialCount, c.Name, tostring(c.Position), note))
                    end
                end
            end
        end
        out("  Total Special/Rainbow Hay Found: " .. tostring(specialCount))
    else
        out("  HaystackClient not found in this Place.")
    end

    out("\n--- GemsClient Forensic Analysis (if present) ---")
    local gemsClient = Workspace:FindFirstChild("GemsClient")
    if gemsClient then
        local gemKids = gemsClient:GetChildren()
        out("  GemsClient Children Count: " .. tostring(#gemKids))
        for i = 1, math.min(25, #gemKids) do
            local g = gemKids[i]
            local pos = "N/A"
            if g:IsA("BasePart") then pos = tostring(g.Position)
            elseif g:IsA("Model") then pcall(function() pos = tostring(g:GetPivot().Position) end) end
            out(string.format("    Gem [%d] Name: %s | Class: %s | Pos: %s", i, g.Name, g.ClassName, pos))
        end
    else
        out("  GemsClient not found in this Place.")
    end
end

-- SECTION 4: PLAYER GUI COMPLETE DUMP (BUTTONS, TEXT, FRAMES)
header("4. PLAYER GUI & INTERFACE HIERARCHY")
if LocalPlayer then
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        out("Scanning PlayerGui...")
        local function scanGui(parent, indent, depth)
            if depth > 7 then return end
            for _, child in ipairs(parent:GetChildren()) do
                local line = indent .. "- " .. child.Name .. " [" .. child.ClassName .. "]"
                if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                    line = line .. " Text=\"" .. tostring(child.Text) .. "\""
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
        scanGui(pGui, "", 0)
    else
        out("PlayerGui not found.")
    end
end

-- SECTION 5: PLAYERSCRIPTS & LOCAL SCRIPTS DECOMPILATION
header("5. PLAYERSCRIPTS DECOMPILATION (CLIENT SOURCE CODE)")
if LocalPlayer then
    local pScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if pScripts then
        local allScripts = {}
        for _, desc in ipairs(pScripts:GetDescendants()) do
            if desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
                table.insert(allScripts, desc)
            end
        end
        out("Total Client Scripts Found: " .. tostring(#allScripts))

        for _, scr in ipairs(allScripts) do
            out("\n" .. string.rep("-", 50))
            out("SCRIPT: " .. scr:GetFullName() .. " [" .. scr.ClassName .. "]")
            out(string.rep("-", 50))
            if decompiler then
                local s, res = pcall(decompiler, scr)
                if s and res and #res > 0 then
                    out(res)
                else
                    out("[Decompile returned empty or error: " .. tostring(res) .. "]")
                end
            else
                out("[Decompiler function not available on this executor]")
            end
        end
    else
        out("PlayerScripts folder not found.")
    end
end

-- SECTION 6: SAVE TO FILE & FINISH
local fullReport = table.concat(report, "\n")
local fileName = "forensics_v3.txt"
if write_file then
    pcall(function()
        write_file(fileName, fullReport)
    end)
    print("\n==================================================")
    print("[FORENSICS v3.0 COMPLETE!]")
    print("Saved complete report to: workspace/" .. fileName)
    print("Total Report Size: " .. #fullReport .. " bytes (" .. #report .. " lines)")
    print("==================================================")
else
    print("\n[FORENSICS v3.0 COMPLETE] writefile unavailable! Report length: " .. #fullReport)
end
