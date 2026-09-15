local Solver = require("../lib/basement_solver")
local checks = 0
local function check(condition, message)
    checks += 1
    assert(condition, message)
end

local leverDefinition = {Steps = {{Id = "Lever1", Model = "Levers.Lever1"}, {Id = "Lever2", Model = "Levers.Lever2"}}}
local lever = Solver.lever(leverDefinition, {steps = {Lever1 = true, Lever2 = false}})
check(lever.stepId == "Lever2", "false steps must not count as solved")
check(not Solver.acknowledged(lever, {steps = {Lever2 = false}}), "sending does not acknowledge a lever")
check(Solver.acknowledged(lever, {steps = {Lever2 = true}}), "server step acknowledges lever")

local numberDefinition = {CodeLength = 4}
local originalNumberState = {code = "", taken = {[1] = true}}
local mergedNumberState = Solver.mergeNumberState(originalNumberState, {[2] = true}, "0042")
check(mergedNumberState.code == "0042", "feedback code must replace an empty snapshot code")
check(mergedNumberState.taken[1] and mergedNumberState.taken[2], "merge snapshot and feedback posters")
check(originalNumberState.code == "" and originalNumberState.taken[2] == nil, "never mutate a server snapshot")
mergedNumberState = Solver.mergeNumberState({code = "0017"}, {}, "9999")
check(mergedNumberState.code == "0017", "valid server code takes precedence over cached feedback")
check(Solver.mergeNumberState(nil, {}, "0042") == nil, "wait for a snapshot before acting")
local posters = {{index = 1, model = "poster1"}, {index = 2, model = "poster2"}}
local number = Solver.number(numberDefinition, {code = "0042", taken = {}}, posters)
check(number.kind == "Submit" and number.code == "0042", "preserve leading zeroes")
check(not Solver.acknowledged(number, {completed = false}), "submit alone is not completion")
check(Solver.acknowledged(number, {completed = true}), "completion must come from server")
number = Solver.number(numberDefinition, {taken = {["1"] = true}}, posters)
check(number.kind == "Poster" and number.index == 2, "normalize numeric/string poster indices")
check(not Solver.acknowledged(number, {taken = {}, code = ""}), "empty code must not acknowledge poster")
check(Solver.acknowledged(number, {taken = {[2] = true}}), "feedback marks poster taken")
number = Solver.number(numberDefinition, {code = "42", taken = {}}, posters)
check(number.kind == "Poster", "never submit a short code")
number = Solver.number(numberDefinition, {code = "123x", taken = {}}, posters)
check(number.kind == "Poster", "never submit a malformed code")
local missing, reason = Solver.number(numberDefinition, {taken = {[1] = true, [2] = true}}, posters)
check(missing == nil and reason == "WAIT_CODE", "do not guess keypad codes")

local pictureDefinition = {GridSize = 4}
local pictureState = {completed = false, rotations = {}}
for index = 1, 16 do pictureState.rotations["Tile" .. index] = index % 4 end
local rotations = 0
while true do
    local action, notice = Solver.picture(pictureDefinition, pictureState)
    if not action then check(notice == "WAIT_SERVER", "aligned board still needs server confirmation"); break end
    check(not Solver.acknowledged(action, pictureState), "unchanged tile is not an acknowledgement")
    pictureState.rotations[action.stepId] = action.expected
    check(Solver.acknowledged(action, pictureState), "changed tile acknowledges rotation")
    rotations += 1
    check(rotations <= 48, "picture solver must terminate")
end
for _, value in pairs(pictureState.rotations) do check(value == 0, "each tile must be unrotated") end
pictureState.completed = true
check(Solver.picture(pictureDefinition, pictureState) == nil, "no actions on completed picture")
local incomplete = {rotations = {Tile1 = 0}}
missing, reason = Solver.picture(pictureDefinition, incomplete)
check(missing == nil and reason == "WAIT_STATE", "missing rotations are not assumed to be zero")

local function colorDefinition(count, minimum, maximum)
    local definition = {MinCount = minimum, MaxCount = maximum, Steps = {}}
    for index = 1, count do definition.Steps[index] = {Id = "Color" .. index, Model = "Switch" .. index} end
    return definition
end
local function enumerate(definition, initial)
    local state = {completed = false, values = table.clone(initial)}
    local search, moves, seen = nil, 0, {}
    local function remember()
        local vector = {}
        for _, step in ipairs(definition.Steps) do table.insert(vector, tostring(state.values[step.Id])) end
        seen[table.concat(vector, ",")] = true
    end
    remember()
    while true do
        local action, nextSearch, notice = Solver.color(definition, state, search)
        search = nextSearch
        if not action then check(notice == "EXHAUSTED", "finite color search must exhaust"); break end
        check(not Solver.acknowledged(action, state), "color search must wait for actual value change")
        local previousCursor = search.cursor
        Solver.color(definition, state, search)
        check(search.cursor == previousCursor, "planning without acknowledgement must not advance")
        state.values[action.stepId] = action.expected
        check(Solver.acknowledged(action, state), "counter change acknowledges action")
        search = Solver.acceptColor(search, action, state)
        check(search ~= nil, "acknowledged odometer move must be accepted")
        moves += 1
        check(moves < 1000, "no repeating infinite color loop")
        remember()
    end
    local unique = 0
    for _ in pairs(seen) do unique += 1 end
    check(unique == (definition.MaxCount - definition.MinCount + 1) ^ #definition.Steps,
        "visit every combination, including from a non-minimum initial state")
end

for first = 1, 3 do
    for second = 1, 3 do enumerate(colorDefinition(2, 1, 3), {Color1 = first, Color2 = second}) end
end
enumerate(colorDefinition(3, 1, 5), {Color1 = 3, Color2 = 5, Color3 = 2})
enumerate(colorDefinition(2, 2, 4), {Color1 = 4, Color2 = 3})

local definition = colorDefinition(2, 1, 5)
local state = {values = {Color1 = 2, Color2 = 3}}
local action, search = Solver.color(definition, state)
state.values.Color1 = action.expected
state.values.Color2 = 4
check(Solver.acceptColor(search, action, state) == nil, "manual/other-player changes must rebase search")
action, search = Solver.color(definition, state, search)
check(search.start[2] == 4 and search.actions == 0, "rebase on current live vector")
state.completed = true
check(Solver.color(definition, state, search) == nil, "stop immediately on server completion")
state = {values = {Color1 = 0, Color2 = 3}}
action, search = Solver.color(definition, state)
check(action.normalize and action.expected == 1 and search == nil, "normalize zero counter before search")
missing, search, reason = Solver.color(definition, {values = {Color1 = 2}})
check(missing == nil and reason == "WAIT_STATE", "missing colors must not be guessed")
missing, search, reason = Solver.color({Steps = definition.Steps}, {values = {Color1 = 2, Color2 = 3}})
check(missing == nil and reason == "BAD_CONFIG", "read actual live bounds, including Hard mode")
missing, search, reason = Solver.color(colorDefinition(1, 1, 1), {values = {Color1 = 1}})
check(missing == nil and reason == "WAIT_SERVER", "never send a counter action that cannot change its value")

print("Basement solver passed " .. checks .. " checks.")
