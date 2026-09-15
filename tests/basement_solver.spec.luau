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
local reversed = {Steps = {{Id = "third", Model = {"Levers", "Lever3"}},
    {Id = "second", Model = "Levers.Lever2"}, {Id = "first", Model = "Levers.Lever1"}}}
local leverState = Solver.mergeLeverState(reversed, nil, {LeverPuzzleSolved = false})
lever = Solver.lever(reversed, leverState)
check(lever.stepId == "first", "first lever must precede the remaining two, even with shuffled config")
leverState = Solver.mergeLeverState(reversed, nil, {Lever1Pulled = true, Lever2Pulled = false})
lever = Solver.lever(reversed, leverState)
check(lever.stepId == "second", "replicated attributes work without a PuzzleState snapshot")
leverState = Solver.mergeLeverState(reversed, leverState, {Lever1Pulled = true, Lever2Pulled = true})
lever = Solver.lever(reversed, leverState)
check(lever.stepId == "third", "third lever must follow the first two")
check(Solver.acknowledged(lever, Solver.mergeLeverState(reversed, nil, {Lever3Pulled = true})),
    "replicated pulled attribute acknowledges a lever")
local phase, id = Solver.phase(false, 100, nil, {LeverPuzzle = {completed = true}}, {"ColorPuzzle", "PicturePuzzle", "NumberPuzzle"})
check(phase == "LEVERS" and id == "LeverPuzzle", "do not pass the gate before LeverPuzzleSolved is replicated")
phase, id = Solver.phase(true, 100, 105.95, {}, {"ColorPuzzle", "PicturePuzzle", "NumberPuzzle"})
check(phase == "DOOR" and id == nil, "wait for sliding door animation before acting inside")
phase, id = Solver.phase(true, 106, 105.95, {}, {"ColorPuzzle", "PicturePuzzle", "NumberPuzzle"})
check(phase == "PUZZLE" and id == "ColorPuzzle", "use release-config order, not arbitrary keypad-first order")
phase, id = Solver.phase(true, 106, nil, {ColorPuzzle = {completed = true}}, {"ColorPuzzle", "PicturePuzzle", "NumberPuzzle"})
check(id == "PicturePuzzle", "do not skip locked puzzle stages")
phase, id = Solver.phase(true, 106, nil, {ColorPuzzle = {completed = true}, PicturePuzzle = {completed = true}},
    {"ColorPuzzle", "PicturePuzzle", "NumberPuzzle"})
check(id == "NumberPuzzle", "keypad follows preceding stages")

local function flag(mask, index) return math.floor(mask / 2 ^ index) % 2 == 1 end
for mask = 0, 127 do
    local state = {puzzlesComplete = flag(mask, 0), keyOwned = flag(mask, 1), escapeReady = flag(mask, 2),
        cutscene = flag(mask, 3), inputLocked = flag(mask, 4), hintOpen = flag(mask, 5), roundComplete = flag(mask, 6)}
    local expected = state.roundComplete and "COMPLETE"
        or ((state.cutscene or state.inputLocked or state.hintOpen) and "PAUSED")
        or (not state.puzzlesComplete and "WAIT_PUZZLES") or (not state.keyOwned and "WAIT_KEY")
        or (not state.escapeReady and "WAIT_RELEASE") or "UNLOCK"
    check(Solver.exitPhase(state) == expected, "exit must respect puzzles, key, release, cutscenes and actual completion")
end
check(Solver.exitPhase({}) == "WAIT_PUZZLES", "missing exit prerequisites must never trigger a hand-in")
check(Solver.exitPhase({winnerUserId = 12345}) == "COMPLETE", "another player's server win stops exit interactions too")
check(Solver.exitPhase({puzzlesComplete = true, keyOwned = true, escapeReady = true}) == "UNLOCK",
    "auto exit must not depend on a separate AutoWin toggle")
check(Solver.exitPhase({puzzlesComplete = true, keyOwned = false, escapeReady = true}) == "WAIT_KEY",
    "escape release alone is not ownership of the key")
check(Solver.exitPhase({puzzlesComplete = true, keyOwned = true, escapeReady = "true"}) == "WAIT_RELEASE",
    "only the server's boolean EscapeReady authorizes exit")

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
local function distanceToClue(definition, values, targets)
    local remaining, width = 0, definition.MaxCount - definition.MinCount + 1
    for _, step in ipairs(definition.Steps) do
        local value, goal = values[step.Id], targets[step.Id]
        remaining += value < definition.MinCount and (goal - definition.MinCount + 1) or (goal - value) % width
    end
    return remaining
end
local function solveColors(definition, initial, targets)
    local state = {completed = false, values = table.clone(initial)}
    local moves, expectedMoves = 0, distanceToClue(definition, initial, targets)
    while true do
        local action, notice = Solver.color(definition, state, targets)
        if not action then check(notice == "WAIT_SERVER", "matching clue still needs server confirmation"); break end
        check(action.goal == targets[action.stepId], "every click must have a clue-derived goal")
        check(state.values[action.stepId] ~= targets[action.stepId], "never change a counter already matching its clue")
        check(not Solver.acknowledged(action, state), "wait for the exact server counter value")
        local repeated = Solver.color(definition, state, targets)
        check(repeated.stepId == action.stepId and repeated.expected == action.expected,
            "planning without acknowledgement must not advance")
        local previousDistance = distanceToClue(definition, state.values, targets)
        state.values[action.stepId] = action.expected
        check(Solver.acknowledged(action, state), "expected counter value acknowledges action")
        check(distanceToClue(definition, state.values, targets) == previousDistance - 1,
            "each click must advance exactly one step toward the clue, including 5-to-1 wrap")
        moves += 1
        check(moves <= #definition.Steps * (definition.MaxCount - definition.MinCount + 1),
            "direct color solve must not enumerate combinations")
    end
    check(moves == expectedMoves, "perform only the necessary counter increments")
    for _, step in ipairs(definition.Steps) do check(state.values[step.Id] == targets[step.Id], "match every clue") end
end

for first = 1, 3 do
    for second = 1, 3 do
        for targetFirst = 1, 3 do
            for targetSecond = 1, 3 do
                solveColors(colorDefinition(2, 1, 3), {Color1 = first, Color2 = second},
                    {Color1 = targetFirst, Color2 = targetSecond})
            end
        end
    end
end
-- Exercise every live 1..5 three-color vector against every clue, as in Hard.
for initial = 0, 124 do
    for goal = 0, 124 do
        solveColors(colorDefinition(3, 1, 5),
            {Color1 = initial % 5 + 1, Color2 = math.floor(initial / 5) % 5 + 1, Color3 = math.floor(initial / 25) + 1},
            {Color1 = goal % 5 + 1, Color2 = math.floor(goal / 5) % 5 + 1, Color3 = math.floor(goal / 25) + 1})
    end
end
solveColors(colorDefinition(3, 1, 5), {Color1 = 0, Color2 = 0, Color3 = 0}, {Color1 = 5, Color2 = 2, Color3 = 4})
solveColors(colorDefinition(2, 2, 4), {Color1 = 4, Color2 = 3}, {Color1 = 2, Color2 = 4})

local definition = colorDefinition(2, 1, 5)
local state = {values = {Color1 = 2, Color2 = 3}}
local targets = {Color1 = 4, Color2 = 3}
local action = Solver.color(definition, state, targets)
state.values.Color1 = 5
check(not Solver.acknowledged(action, state), "an unexpected other-player click is not our action acknowledgement")
action = Solver.color(definition, state, targets)
check(action.before == 5 and action.expected == 1 and action.goal == 4, "re-plan from actual counter after manual changes")
state.completed = true
check(Solver.color(definition, state, targets) == nil, "stop immediately on server completion")
state = {values = {Color1 = 0, Color2 = 3}}
action = Solver.color(definition, state, targets)
check(action.expected == 1 and action.goal == 4, "zero start is advanced toward a known clue only")
missing, reason = Solver.color(definition, state)
check(missing == nil and reason == "WAIT_CLUE", "never normalize or guess without a clue")
missing, reason = Solver.color(definition, {values = {Color1 = 2}}, targets)
check(missing == nil and reason == "WAIT_STATE", "missing colors must not be guessed")
missing, reason = Solver.color({Steps = definition.Steps}, {values = {Color1 = 2, Color2 = 3}}, targets)
check(missing == nil and reason == "BAD_CONFIG", "read actual live bounds, including Hard mode")
missing, reason = Solver.color(colorDefinition(1, 1, 1), {values = {Color1 = 1}}, {Color1 = 1})
check(missing == nil and reason == "WAIT_SERVER", "never send a counter action that cannot change its value")
missing, reason = Solver.color(definition, state, {Color1 = 4})
check(missing == nil and reason == "WAIT_CLUE", "all clues must be available before changing any counter")
missing, reason = Solver.color(definition, state, {Color1 = 4, Color2 = 6})
check(missing == nil and reason == "BAD_CLUE", "reject out-of-range clue without partial changes")
missing, reason = Solver.color(definition, {values = {Color1 = -1, Color2 = 3}}, targets)
check(missing == nil and reason == "BAD_STATE", "invalid counters cannot be blindly clicked")
local groups = {Color1 = {}, Color2 = {}}
for index = 1, 5 do
    groups.Color1[index] = {visible = index <= 4, loaded = true}
    groups.Color2[index] = {visible = index <= 3, loaded = true}
end
local readTargets = Solver.colorTargets(definition, groups)
check(readTargets.Color1 == 4 and readTargets.Color2 == 3, "count only models with ColorPuzzleVisible true")
check(Solver.color(definition, {values = {Color1 = 4, Color2 = 3}}, readTargets) == nil,
    "matching gem counts must remain untouched")
groups.Color2[5].visible = nil
missing, reason = Solver.colorTargets(definition, groups)
check(missing == nil and reason == "WAIT_CLUE", "unknown visibility is not a hidden gem")
groups.Color2[5].visible = false
groups.Color1[1].loaded = false
missing, reason = Solver.colorTargets(definition, groups)
check(missing == nil and reason == "WAIT_CLUE", "partially streamed visible models are not a complete clue")
groups.Color1[1].loaded = true
missing, reason = Solver.colorTargets(definition, {Color1 = groups.Color1})
check(missing == nil and reason == "WAIT_CLUE", "missing clue group must not trigger guessing")
missing, reason = Solver.colorTargets(definition, {Color1 = groups.Color1, Color2 = {}})
check(missing == nil and reason == "WAIT_CLUE", "empty group must wait for loading")
for _, gem in ipairs(groups.Color2) do gem.visible = false end
missing, reason = Solver.colorTargets(definition, groups)
check(missing == nil and reason == "BAD_CLUE", "all-hidden group cannot fabricate a valid target")
table.insert(groups.Color1, {visible = true, loaded = true})
table.insert(groups.Color1, {visible = true, loaded = true})
missing, reason = Solver.colorTargets(definition, groups)
check(missing == nil and reason == "BAD_CLUE", "over-counted clue must not be used")

print("Basement solver passed " .. checks .. " checks.")
