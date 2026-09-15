-- Pure planning only. The embedded copy in main.lua must match this module.
-- Never treats a sent action as success; the runtime must wait for server state.
local Solver = {}

function Solver.isTaken(taken, index)
    return type(taken) == "table" and (taken[index] == true or taken[tostring(index)] == true)
end

function Solver.lever(definition, state)
    if state.completed == true then return nil, "DONE" end
    for _, step in ipairs(definition.Steps or {}) do
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

function Solver.color(definition, state, search)
    if state.completed == true then return nil, search, "DONE" end
    local minimum, maximum = tonumber(definition.MinCount), tonumber(definition.MaxCount)
    if not minimum or not maximum or minimum % 1 ~= 0 or maximum % 1 ~= 0
        or maximum < minimum or maximum - minimum > 19 then
        return nil, search, "BAD_CONFIG"
    end
    local steps, values = definition.Steps, state.values
    if type(steps) ~= "table" or #steps == 0 or #steps > 8 or type(values) ~= "table" then
        return nil, search, "WAIT_STATE"
    end
    local ids, vector = {}, {}
    for index, step in ipairs(steps) do
        if type(step.Id) ~= "string" then return nil, search, "BAD_CONFIG" end
        ids[index] = step.Id
        local value = values[step.Id]
        if type(value) ~= "number" or value % 1 ~= 0 then return nil, search, "WAIT_STATE" end
        if value < minimum or value > maximum then
            -- Some rounds start with zero. Normalize it before enumerating.
            if value ~= minimum - 1 then return nil, search, "BAD_STATE" end
            return {kind = "Counter", puzzleId = "ColorPuzzle", stepId = step.Id,
                model = step.Model, before = value, expected = minimum, normalize = true}, nil
        end
        vector[index] = value
    end
    if minimum == maximum then return nil, search, "WAIT_SERVER" end
    local reset = not search or #search.ids ~= #ids or search.minimum ~= minimum or search.maximum ~= maximum
    if not reset then
        for index, id in ipairs(ids) do
            if search.ids[index] ~= id or search.vector[index] ~= vector[index] then reset = true; break end
        end
    end
    if reset then
        search = {ids = ids, vector = table.clone(vector), start = table.clone(vector), cursor = 1,
            minimum = minimum, maximum = maximum, actions = 0, total = (maximum - minimum + 1) ^ #ids}
    end
    if search.cursor > #ids then return nil, search, "EXHAUSTED" end
    local index = search.cursor
    return {kind = "Counter", puzzleId = "ColorPuzzle", stepId = ids[index], model = steps[index].Model,
        before = vector[index], expected = vector[index] == maximum and minimum or vector[index] + 1,
        colorIndex = index}, search
end

function Solver.acceptColor(search, action, state)
    if not search or action.normalize then return nil end
    local values = state.values
    if type(values) ~= "table" or values[action.stepId] ~= action.expected then return nil end
    for index, id in ipairs(search.ids) do
        if index ~= action.colorIndex and values[id] ~= search.vector[index] then return nil end
    end
    search.vector[action.colorIndex] = action.expected
    search.actions = search.actions + 1
    -- Mixed-radix odometer: exhaust one counter before carrying to the next.
    search.cursor = action.expected == search.start[action.colorIndex] and action.colorIndex + 1 or 1
    return search
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
            and state.values[action.stepId] ~= action.before
    end
    return false
end

function Solver.token(action)
    return table.concat({action.puzzleId, action.kind, tostring(action.stepId or action.index or ""),
        tostring(action.before or action.code or "")}, ":")
end

return Solver
