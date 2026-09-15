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
