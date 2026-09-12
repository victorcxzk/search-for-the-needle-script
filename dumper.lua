--[[
    DUMP ENGINE v2.0 - Extracao Forense Universal
    Executa no executor e gera relatorio completo no console.
    Copie TODA a saida e cole para analise.
    Zero emojis, zero caracteres especiais, 100% ASCII seguro.
]]

-- ============================================================
-- CONFIGURACAO
-- ============================================================
local MAX_DEPTH = 6          -- profundidade maxima de varredura
local MAX_CHILDREN = 500     -- limite de filhos por container
local SCAN_WORKSPACE = true  -- varrer Workspace por partes interativas
local SCAN_MODULES = true    -- descompilar modulos (requer decompile())
local DECOMPILE_LIMIT = 80   -- limite de modulos a descompilar (evitar travamento)

-- ============================================================
-- SERVICOS SEGUROS
-- ============================================================
local function safeService(name)
    local ok, svc = pcall(function()
        return cloneref and cloneref(game:GetService(name)) or game:GetService(name)
    end)
    if not ok then
        ok, svc = pcall(function()
            return game:GetService(name)
        end)
    end
    return ok and svc or nil
end

local RS = safeService("ReplicatedStorage")
local RSFirst = safeService("ReplicatedFirst")
local SSS = safeService("ServerScriptService") -- normalmente nil no cliente
local SPS = safeService("StarterPlayerScripts")
local SPack = safeService("StarterPack")
local Players = safeService("Players")
local Workspace = safeService("Workspace")
local Lighting = safeService("Lighting")
local SSService = safeService("SoundService")
local Chat = safeService("Chat")
local Teams = safeService("Teams")
local LP = Players and Players.LocalPlayer or nil

-- ============================================================
-- UTILIDADES
-- ============================================================
local report = {}
local sectionCount = 0

local function out(str)
    report[#report + 1] = str
end

local function section(title)
    sectionCount = sectionCount + 1
    out("")
    out("================================================================")
    out(string.format("[SECAO %d] %s", sectionCount, title))
    out("================================================================")
end

local function subsection(title)
    out("")
    out("--- " .. title .. " ---")
end

local function indent(level)
    return string.rep("  ", level)
end

local function safeToString(v)
    local ok, s = pcall(tostring, v)
    return ok and s or "<erro ao converter>"
end

local function safeGetFullName(obj)
    local ok, name = pcall(function() return obj:GetFullName() end)
    return ok and name or "<caminho desconhecido>"
end

local function safeGetChildren(obj)
    local ok, children = pcall(function() return obj:GetChildren() end)
    return ok and children or {}
end

local function safeGetProp(obj, prop)
    local ok, val = pcall(function() return obj[prop] end)
    return ok and val or nil
end

-- ============================================================
-- INFO DO JOGO
-- ============================================================
section("INFORMACOES DO JOGO")

local gameId = game.GameId or 0
local placeId = game.PlaceId or 0
local placeVersion = game.PlaceVersion or 0
local jobId = game.JobId or ""

out(string.format("GameId:       %s", safeToString(gameId)))
out(string.format("PlaceId:      %s", safeToString(placeId)))
out(string.format("PlaceVersion: %s", safeToString(placeVersion)))
out(string.format("JobId:        %s", jobId))

if LP then
    out(string.format("LocalPlayer:  %s (UserId: %s)", LP.Name, safeToString(LP.UserId)))
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            out(string.format("WalkSpeed:    %s", safeToString(hum.WalkSpeed)))
            out(string.format("JumpHeight:   %s", safeToString(hum.JumpHeight)))
            out(string.format("JumpPower:    %s", safeToString(hum.JumpPower)))
            out(string.format("MaxHealth:    %s", safeToString(hum.MaxHealth)))
        end
    end
end

-- ============================================================
-- SCANNER DE REMOTES
-- ============================================================
local remoteEvents = {}
local remoteFunctions = {}
local bindableEvents = {}
local bindableFunctions = {}

local function scanRemotes(parent, depth)
    if depth > MAX_DEPTH then return end
    local children = safeGetChildren(parent)
    local count = 0
    for _, child in ipairs(children) do
        count = count + 1
        if count > MAX_CHILDREN then break end
        local className = safeGetProp(child, "ClassName") or ""
        if className == "RemoteEvent" then
            remoteEvents[#remoteEvents + 1] = {
                Name = child.Name,
                Path = safeGetFullName(child),
                Parent = safeGetFullName(parent)
            }
        elseif className == "RemoteFunction" then
            remoteFunctions[#remoteFunctions + 1] = {
                Name = child.Name,
                Path = safeGetFullName(child),
                Parent = safeGetFullName(parent)
            }
        elseif className == "BindableEvent" then
            bindableEvents[#bindableEvents + 1] = {
                Name = child.Name,
                Path = safeGetFullName(child)
            }
        elseif className == "BindableFunction" then
            bindableFunctions[#bindableFunctions + 1] = {
                Name = child.Name,
                Path = safeGetFullName(child)
            }
        end
        scanRemotes(child, depth + 1)
    end
end

section("REMOTE EVENTS E REMOTE FUNCTIONS")

-- Varrer containers primarios
local containers = {
    {"ReplicatedStorage", RS},
    {"ReplicatedFirst", RSFirst},
    {"Workspace", Workspace},
    {"Lighting", Lighting},
    {"StarterPlayerScripts", SPS},
    {"StarterPack", SPack},
    {"Chat", Chat},
    {"Teams", Teams},
}

-- Tambem varrer PlayerGui e Backpack do jogador local
if LP then
    local pg = safeGetProp(LP, "PlayerGui")
    local bp = safeGetProp(LP, "Backpack")
    local pscripts = safeGetProp(LP, "PlayerScripts")
    if pg then containers[#containers + 1] = {"PlayerGui", pg} end
    if bp then containers[#containers + 1] = {"Backpack", bp} end
    if pscripts then containers[#containers + 1] = {"PlayerScripts", pscripts} end
end

for _, pair in ipairs(containers) do
    if pair[2] then
        scanRemotes(pair[2], 0)
    end
end

subsection("RemoteEvents (" .. #remoteEvents .. " encontrados)")
for i, re in ipairs(remoteEvents) do
    out(string.format("  [%d] %s", i, re.Path))
end

subsection("RemoteFunctions (" .. #remoteFunctions .. " encontrados)")
for i, rf in ipairs(remoteFunctions) do
    out(string.format("  [%d] %s", i, rf.Path))
end

subsection("BindableEvents (" .. #bindableEvents .. " encontrados)")
for i, be in ipairs(bindableEvents) do
    out(string.format("  [%d] %s", i, be.Path))
end

subsection("BindableFunctions (" .. #bindableFunctions .. " encontrados)")
for i, bf in ipairs(bindableFunctions) do
    out(string.format("  [%d] %s", i, bf.Path))
end

-- ============================================================
-- SCANNER DE MODULESCRIPTS
-- ============================================================
section("MODULESCRIPTS - MAPA E DESCOMPILACAO")

local modules = {}

local function scanModules(parent, depth)
    if depth > MAX_DEPTH then return end
    local children = safeGetChildren(parent)
    local count = 0
    for _, child in ipairs(children) do
        count = count + 1
        if count > MAX_CHILDREN then break end
        if (safeGetProp(child, "ClassName") or "") == "ModuleScript" then
            modules[#modules + 1] = {
                Name = child.Name,
                Path = safeGetFullName(child),
                Obj = child
            }
        end
        scanModules(child, depth + 1)
    end
end

for _, pair in ipairs(containers) do
    if pair[2] then
        scanModules(pair[2], 0)
    end
end

subsection("Modulos Encontrados (" .. #modules .. " total)")
for i, m in ipairs(modules) do
    out(string.format("  [%d] %s", i, m.Path))
end

-- Descompilacao seletiva
if SCAN_MODULES then
    subsection("DESCOMPILACAO DE MODULOS-CHAVE")
    out("(Limitado a " .. DECOMPILE_LIMIT .. " modulos para evitar travamento)")
    out("")

    local hasDecompile = pcall(function() return type(decompile) == "function" end)
    if not hasDecompile then
        -- tentar alternativas
        hasDecompile = pcall(function()
            return type(getscriptbytecode) == "function" or type(debug.getinfo) == "function"
        end)
    end

    if hasDecompile and type(decompile) == "function" then
        local decompCount = 0
        -- Priorizar modulos com nomes relevantes
        local priorityKeywords = {
            "config", "data", "setting", "constant", "record", "catalog",
            "shop", "store", "item", "pet", "egg", "hatch", "inventory",
            "farm", "action", "remote", "network", "event", "handler",
            "controller", "manager", "util", "helper", "state", "quest",
            "mission", "reward", "code", "redeem", "teleport", "zone",
            "map", "world", "island", "area", "speed", "walk", "fly",
            "coin", "gem", "currency", "upgrade", "rebirth", "prestige",
            "auto", "loop", "tick", "game", "main", "init", "setup",
            "gui", "ui", "hud", "notification", "badge", "achievement",
            "index", "codex", "collection", "multiplier", "boost",
            "away", "offline", "earning", "sell", "equip", "backpack",
            "tool", "weapon", "damage", "health", "combat", "enemy",
            "spawn", "drop", "loot", "chest", "crate", "open",
            "merge", "craft", "recipe", "unlock", "level", "exp",
            "rank", "tier", "rarity", "common", "rare", "epic", "legend",
            "mythic", "divine", "secret", "special", "event", "seasonal"
        }

        local function isPriority(name)
            local lower = string.lower(name)
            for _, kw in ipairs(priorityKeywords) do
                if string.find(lower, kw, 1, true) then
                    return true
                end
            end
            return false
        end

        -- Ordenar: modulos prioritarios primeiro
        table.sort(modules, function(a, b)
            local aPri = isPriority(a.Name)
            local bPri = isPriority(b.Name)
            if aPri and not bPri then return true end
            if not aPri and bPri then return false end
            return a.Name < b.Name
        end)

        for _, m in ipairs(modules) do
            if decompCount >= DECOMPILE_LIMIT then
                out("  ... limite de descompilacao atingido ...")
                break
            end
            local ok, source = pcall(decompile, m.Obj)
            if ok and source and #source > 10 then
                decompCount = decompCount + 1
                out(string.format("  ---- MODULO: %s ----", m.Path))
                -- Truncar modulos muito grandes (>3000 chars) para nao estourar output
                if #source > 3000 then
                    out(string.sub(source, 1, 3000))
                    out("  ... [TRUNCADO - " .. #source .. " chars total] ...")
                else
                    out(source)
                end
                out("")
            end
        end
        out(string.format("  Total descompilados: %d", decompCount))
    else
        out("  [AVISO] Funcao decompile() nao disponivel neste executor.")
        out("  Tente usar um executor com suporte a descompilacao (ex: Synapse, Script-Ware, Fluxus).")
        out("  Alternativa: use saveinstance() para gerar o arquivo .rbxlx completo.")
    end
end

-- ============================================================
-- SCANNER DE WORKSPACE (PARTES INTERATIVAS)
-- ============================================================
if SCAN_WORKSPACE and Workspace then
    section("WORKSPACE - PARTES INTERATIVAS E ESTRUTURA 3D")

    local touchParts = {}
    local proximityPrompts = {}
    local clickDetectors = {}
    local npcs = {}
    local spawnLocations = {}
    local folders = {}

    local function scanWorkspace(parent, depth)
        if depth > MAX_DEPTH then return end
        local children = safeGetChildren(parent)
        local count = 0
        for _, child in ipairs(children) do
            count = count + 1
            if count > MAX_CHILDREN then break end
            local className = safeGetProp(child, "ClassName") or ""

            -- Pastas de nivel superior (estrutura do mapa)
            if depth <= 2 and (className == "Folder" or className == "Model") then
                folders[#folders + 1] = {
                    Name = child.Name,
                    Class = className,
                    Path = safeGetFullName(child),
                    ChildCount = #safeGetChildren(child)
                }
            end

            -- TouchParts
            if child:IsA("BasePart") then
                local canTouch = safeGetProp(child, "CanTouch")
                local isTouched = safeGetProp(child, "Touched")
                local transparency = safeGetProp(child, "Transparency") or 0
                -- Partes invisiveis com CanTouch sao provavelmente trigger zones
                if canTouch and transparency >= 0.5 then
                    touchParts[#touchParts + 1] = {
                        Name = child.Name,
                        Path = safeGetFullName(child),
                        Position = safeToString(safeGetProp(child, "Position")),
                        Size = safeToString(safeGetProp(child, "Size")),
                        Transparency = transparency,
                        CanCollide = safeGetProp(child, "CanCollide"),
                        Parent = parent.Name
                    }
                end
            end

            -- ProximityPrompts
            if className == "ProximityPrompt" then
                proximityPrompts[#proximityPrompts + 1] = {
                    Name = child.Name,
                    Path = safeGetFullName(child),
                    ActionText = safeGetProp(child, "ActionText") or "",
                    ObjectText = safeGetProp(child, "ObjectText") or "",
                    HoldDuration = safeGetProp(child, "HoldDuration") or 0,
                    MaxDistance = safeGetProp(child, "MaxActivationDistance") or 0,
                    RequiresLineOfSight = safeGetProp(child, "RequiresLineOfSight"),
                    Enabled = safeGetProp(child, "Enabled"),
                    ParentName = parent.Name,
                    ParentPath = safeGetFullName(parent)
                }
            end

            -- ClickDetectors
            if className == "ClickDetector" then
                clickDetectors[#clickDetectors + 1] = {
                    Name = child.Name,
                    Path = safeGetFullName(child),
                    MaxDistance = safeGetProp(child, "MaxActivationDistance") or 0,
                    ParentName = parent.Name
                }
            end

            -- SpawnLocations
            if className == "SpawnLocation" then
                spawnLocations[#spawnLocations + 1] = {
                    Name = child.Name,
                    Path = safeGetFullName(child),
                    Position = safeToString(safeGetProp(child, "Position"))
                }
            end

            -- NPCs (modelos com Humanoid)
            if className == "Model" and child:FindFirstChildOfClass("Humanoid") then
                local hum = child:FindFirstChildOfClass("Humanoid")
                npcs[#npcs + 1] = {
                    Name = child.Name,
                    Path = safeGetFullName(child),
                    Health = safeGetProp(hum, "Health") or 0,
                    MaxHealth = safeGetProp(hum, "MaxHealth") or 0,
                    WalkSpeed = safeGetProp(hum, "WalkSpeed") or 0
                }
            end

            scanWorkspace(child, depth + 1)
        end
    end

    scanWorkspace(Workspace, 0)

    subsection("Estrutura de Pastas e Modelos (Nivel Superior)")
    for i, f in ipairs(folders) do
        out(string.format("  [%d] [%s] %s (%d filhos) -> %s", i, f.Class, f.Name, f.ChildCount, f.Path))
    end

    subsection("TouchParts Invisiveis / Trigger Zones (" .. #touchParts .. ")")
    for i, tp in ipairs(touchParts) do
        out(string.format("  [%d] %s | Pos: %s | Size: %s | Transp: %s | Collide: %s",
            i, tp.Path, tp.Position, tp.Size,
            safeToString(tp.Transparency), safeToString(tp.CanCollide)))
    end

    subsection("ProximityPrompts (" .. #proximityPrompts .. ")")
    for i, pp in ipairs(proximityPrompts) do
        out(string.format("  [%d] %s | Action: '%s' | Object: '%s' | Hold: %ss | Dist: %s | Enabled: %s | Parent: %s",
            i, pp.Path, pp.ActionText, pp.ObjectText,
            safeToString(pp.HoldDuration), safeToString(pp.MaxDistance),
            safeToString(pp.Enabled), pp.ParentPath))
    end

    subsection("ClickDetectors (" .. #clickDetectors .. ")")
    for i, cd in ipairs(clickDetectors) do
        out(string.format("  [%d] %s | Dist: %s | Parent: %s",
            i, cd.Path, safeToString(cd.MaxDistance), cd.ParentName))
    end

    subsection("NPCs / Humanoids no Workspace (" .. #npcs .. ")")
    for i, npc in ipairs(npcs) do
        out(string.format("  [%d] %s | HP: %s/%s | Speed: %s",
            i, npc.Path, safeToString(npc.Health), safeToString(npc.MaxHealth),
            safeToString(npc.WalkSpeed)))
    end

    subsection("SpawnLocations (" .. #spawnLocations .. ")")
    for i, sp in ipairs(spawnLocations) do
        out(string.format("  [%d] %s | Pos: %s", i, sp.Path, sp.Position))
    end
end

-- ============================================================
-- PLAYER GUI - SCRIPTS ATIVOS
-- ============================================================
section("SCRIPTS ATIVOS NO CLIENTE")

local activeScripts = {}

local function scanScripts(parent, depth)
    if depth > 4 then return end
    local children = safeGetChildren(parent)
    for _, child in ipairs(children) do
        local className = safeGetProp(child, "ClassName") or ""
        if className == "LocalScript" or className == "ModuleScript" then
            local disabled = safeGetProp(child, "Disabled")
            activeScripts[#activeScripts + 1] = {
                Name = child.Name,
                Class = className,
                Path = safeGetFullName(child),
                Disabled = disabled
            }
        end
        scanScripts(child, depth + 1)
    end
end

if LP then
    local pg = safeGetProp(LP, "PlayerGui")
    local ps = safeGetProp(LP, "PlayerScripts")
    local bp = safeGetProp(LP, "Backpack")
    local char = LP.Character
    if pg then scanScripts(pg, 0) end
    if ps then scanScripts(ps, 0) end
    if bp then scanScripts(bp, 0) end
    if char then scanScripts(char, 0) end
end

subsection("Scripts encontrados (" .. #activeScripts .. ")")
for i, s in ipairs(activeScripts) do
    out(string.format("  [%d] [%s] %s | Disabled: %s",
        i, s.Class, s.Path, safeToString(s.Disabled)))
end

-- ============================================================
-- VALORES E ATRIBUTOS DO JOGADOR
-- ============================================================
section("VALORES E ATRIBUTOS DO JOGADOR LOCAL")

if LP then
    -- ValueObjects filhos diretos do player
    local function scanValues(parent, label)
        local children = safeGetChildren(parent)
        for _, child in ipairs(children) do
            local className = safeGetProp(child, "ClassName") or ""
            if string.find(className, "Value") then
                out(string.format("  [%s] %s (%s) = %s -> %s",
                    label, child.Name, className,
                    safeToString(safeGetProp(child, "Value")),
                    safeGetFullName(child)))
            end
            -- Checar pastas de stats
            if className == "Folder" or className == "Configuration" then
                scanValues(child, label .. "/" .. child.Name)
            end
        end
    end

    scanValues(LP, "Player")

    -- Leaderstats
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        subsection("Leaderstats")
        scanValues(ls, "leaderstats")
    end

    -- Atributos
    local attrs = {}
    local ok, attrList = pcall(function() return LP:GetAttributes() end)
    if ok and attrList then
        subsection("Atributos do Player (GetAttributes)")
        for k, v in pairs(attrList) do
            out(string.format("  %s = %s (%s)", k, safeToString(v), type(v)))
        end
    end
end

-- ============================================================
-- HIDDEN SERVICES / NETWORK INSPECTION
-- ============================================================
section("INSPECAO DE REDE (REMOTES CONECTADOS)")

local function getConnections(remote)
    -- Tenta obter conexoes (nem todo executor suporta)
    local ok, connections = pcall(function()
        if getconnections then
            return getconnections(remote.OnClientEvent or remote.OnClientInvoke)
        end
        return nil
    end)
    return ok and connections or nil
end

out("Tentando inspecionar conexoes de remotes no cliente...")
local connCount = 0
for _, re in ipairs(remoteEvents) do
    local obj = nil
    pcall(function()
        local pathParts = string.split(re.Path, ".")
        obj = game
        for idx = 2, #pathParts do
            obj = obj:FindFirstChild(pathParts[idx])
            if not obj then break end
        end
    end)
    if obj then
        local conns = getConnections(obj)
        if conns and #conns > 0 then
            connCount = connCount + 1
            out(string.format("  [CONECTADO] %s -> %d conexoes ativas", re.Path, #conns))
            -- Tentar pegar info do callback
            for ci, conn in ipairs(conns) do
                if ci <= 3 then -- limitar output
                    local funcInfo = ""
                    pcall(function()
                        if conn.Function then
                            local info = debug.getinfo(conn.Function)
                            if info then
                                funcInfo = string.format("source: %s, line: %s",
                                    info.source or "?", safeToString(info.currentline or info.linedefined))
                            end
                        end
                    end)
                    if funcInfo ~= "" then
                        out(string.format("    conn[%d]: %s", ci, funcInfo))
                    end
                end
            end
        end
    end
end
out(string.format("  Total remotes com conexoes ativas: %d", connCount))

-- ============================================================
-- RESUMO FINAL
-- ============================================================
section("RESUMO DA EXTRACAO")
out(string.format("  RemoteEvents:      %d", #remoteEvents))
out(string.format("  RemoteFunctions:   %d", #remoteFunctions))
out(string.format("  BindableEvents:    %d", #bindableEvents))
out(string.format("  BindableFunctions: %d", #bindableFunctions))
out(string.format("  ModuleScripts:     %d", #modules))
out(string.format("  ProximityPrompts:  %d", #proximityPrompts))
out(string.format("  ClickDetectors:    %d", #clickDetectors))
out(string.format("  NPCs/Humanoids:    %d", #npcs))
out(string.format("  Scripts Ativos:    %d", #activeScripts))
out("")
out("================================================================")
out("FIM DO RELATORIO - COPIE TUDO ACIMA E COLE PARA ANALISE")
out("================================================================")

-- ============================================================
-- OUTPUT FINAL
-- ============================================================
local fullReport = table.concat(report, "\n")

-- Metodo 1: Print no console (funciona em todos os executores)
print(fullReport)

-- Metodo 2: Tentar copiar para clipboard
pcall(function()
    if setclipboard then
        setclipboard(fullReport)
        print("\n[DUMP ENGINE] Relatorio copiado para a area de transferencia automaticamente!")
    elseif toclipboard then
        toclipboard(fullReport)
        print("\n[DUMP ENGINE] Relatorio copiado para a area de transferencia automaticamente!")
    else
        print("\n[DUMP ENGINE] Clipboard nao disponivel. Copie manualmente do console.")
    end
end)

-- Metodo 3: Tentar salvar em arquivo
pcall(function()
    if writefile then
        writefile("dump_report.txt", fullReport)
        print("[DUMP ENGINE] Relatorio salvo em: workspace/dump_report.txt")
    end
end)

return fullReport
