-- ============================================================
-- evolvingPopulationsEnhanced.lua  —  Toribash EC Algorithm
-- ============================================================
-- Enhancements over evolvingPopulations.lua:
--
--   1. ELITISM
--        The top ELITE_COUNT individuals are copied unchanged into
--        the next generation, guaranteeing the best solutions are
--        never lost to crossover or mutation.
--
--   2. SELF-ADAPTIVE MUTATION RATES
--        Every move set carries its own mutationRate field.  When
--        two parents produce offspring, their rates are blended and
--        lightly perturbed, letting the algorithm tune aggression
--        automatically over time.
--
--   3. DUAL CROSSOVER OPERATORS  (randomly chosen each pairing)
--        • Uniform crossover  – each move gene is independently
--          coin-flipped between the two parents.
--        • Two-point crossover – a contiguous slice is swapped,
--          matching the original behaviour.
--        Additionally, a single randomly-chosen shared move also
--        undergoes joint-level uniform crossover, mixing individual
--        joint states between parents.
--
--   4. HALL OF FAME
--        The all-time best HALL_OF_FAME_SIZE solutions are archived
--        across every generation.  At the end of the run the overall
--        champion is replayed instead of just the last-generation
--        best.
--
--   5. STAGNATION GUARD
--        Tracks how many consecutive generations pass without a new
--        best score.  After STAGNATION_LIMIT stagnant generations,
--        DIVERSITY_INJECT_N fresh random individuals replace the
--        weakest slots in the next population, helping escape local
--        optima.
--
--   6. VARIABLE-LENGTH CHROMOSOMES
--        Mutation can insert a brand-new random move or delete an
--        existing one, allowing the length of a strategy to grow or
--        shrink as evolution progresses.
--
--   7. STEP-COUNT MUTATION
--        The per-move frame duration (steps field) is also subject
--        to mutation, so the algorithm can evolve timing as well as
--        joint configuration.
-- ============================================================


-- ── State ────────────────────────────────────────────────────
local evaluatedPopulation = {}
local population          = {}
local chromosome          = {}
local parents             = {}
local parent1             = {}
local parent2             = {}

-- Hall of Fame: best-ever solutions across all generations
local hallOfFame     = {}
local HALL_OF_FAME_SIZE = 3

-- ── Toribash constants ────────────────────────────────────────
local FRAME_LENGTH = 10
local GAME_LENGTH  = 500
local NUM_JOINTS   = 20   -- Toribash has 20 controllable joints
local JOINT_STATES = 4    -- joint values: 1 (extend) 2 (contract) 3 (hold) 4 (relax)

-- ── Evolution hyper-parameters ────────────────────────────────
local POPULATION_SIZE = 50
local NUM_GENERATIONS = 100
local TOURNAMENT_SIZE = 10
local PARENT_SIZE     = 4
local ELITE_COUNT     = 3   -- best individuals copied to next gen unchanged

-- Mutation defaults (each individual also carries its own rate)
local BASE_MUTATION_RATE = 0.25  -- per-joint mutation probability
local BASE_MUTATE_MOVES  = 5     -- max number of moves tweaked per offspring
local RATE_NOISE         = 0.08  -- perturbation applied to an inherited rate
local MIN_MUTATION_RATE  = 0.05
local MAX_MUTATION_RATE  = 0.65

-- Variable-length chromosome bounds
local MIN_MOVES   = 3
local MAX_MOVES   = 25
local INSERT_PROB = 0.05  -- probability to insert a new random move during mutation
local DELETE_PROB = 0.05  -- probability to delete a move during mutation

-- Stagnation / diversity injection
local STAGNATION_LIMIT   = 8
local DIVERSITY_INJECT_N = 6

-- ── Mutable runtime state ─────────────────────────────────────
local generationNum   = 1
local lastInjury      = 0
local lastScore       = 0
local stagnationCount = 0
local bestScoreEver   = -math.huge


-- ── Helpers ───────────────────────────────────────────────────

local function clamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

-- Build a random single move
local function randomMove()
    local m = { move = {}, steps = math.random(4), score = 0 }
    for k = 1, NUM_JOINTS do
        m.move[k] = math.random(JOINT_STATES)
    end
    return m
end

-- Build a random move set of variable length; includes a mutationRate field
local function randomMoveSet()
    local ms  = { mutationRate = BASE_MUTATION_RATE }
    local len = math.random(MIN_MOVES, math.min(MAX_MOVES, 20))
    for j = 1, len do
        ms[j] = randomMove()
    end
    return ms
end

-- Deep copy a move set, preserving the mutationRate field
local function copyMoveSet(src)
    local dst = { mutationRate = src.mutationRate or BASE_MUTATION_RATE }
    for i = 1, #src do
        local sm = src[i]
        local dm = { steps = sm.steps, score = sm.score, move = {} }
        for j = 1, #sm.move do
            dm.move[j] = sm.move[j]
        end
        dst[i] = dm
    end
    return dst
end


-- ── File I/O ──────────────────────────────────────────────────

local function appendLine(filename, value)
    local file = io.open(filename, "a", 1)
    file:write(tostring(value) .. "\n")
    io.close(file)
end

local function writePopulationToFile()
    local file = io.open("populationEnhanced.txt", "w", 1)
    for i = 1, #evaluatedPopulation do
        local ep = evaluatedPopulation[i]
        file:write("moveSet\n")
        file:write("mutationRate:" .. (ep.moveSet.mutationRate or BASE_MUTATION_RATE) .. "\n")
        for j = 1, #ep.moveSet do
            file:write("Steps:" .. ep.moveSet[j].steps .. "\n")
            for k = 1, #ep.moveSet[j].move do
                file:write(ep.moveSet[j].move[k] .. "\n")
            end
        end
        file:write("\n")
    end
    io.close(file)
end


-- ── Fitness helpers ───────────────────────────────────────────

-- Best (max) raw score across moves in a single move list
local function getFinalScore(moveList)
    local best = moveList[1] and moveList[1].score or 0
    for i = 2, #moveList do
        if moveList[i].score > best then best = moveList[i].score end
    end
    return best
end

function getAverageScore()
    local total = 0
    for i = 1, #evaluatedPopulation do
        total = total + evaluatedPopulation[i].finalScore
    end
    return total / #evaluatedPopulation
end

function getMaxScore()
    local max = -math.huge
    for i = 1, #evaluatedPopulation do
        if evaluatedPopulation[i].finalScore > max then
            max = evaluatedPopulation[i].finalScore
        end
    end
    return max
end


-- ── Joints ────────────────────────────────────────────────────

local function setJoints(player, js)
    for i = 1, #js do
        set_joint_state(player, i - 1, js[i])
    end
end


-- ── Hall of Fame ──────────────────────────────────────────────

local function updateHallOfFame()
    for i = 1, #evaluatedPopulation do
        table.insert(hallOfFame, {
            moveSet    = copyMoveSet(evaluatedPopulation[i].moveSet),
            finalScore = evaluatedPopulation[i].finalScore
        })
    end
    table.sort(hallOfFame, function(a, b) return a.finalScore > b.finalScore end)
    while #hallOfFame > HALL_OF_FAME_SIZE do
        table.remove(hallOfFame, #hallOfFame)
    end
end


-- ── Selection ─────────────────────────────────────────────────

local function getBest(li)
    local best = li[1]
    for i = 2, #li do
        if li[i].finalScore > best.finalScore then best = li[i] end
    end
    return best
end

local function randomSubset()
    local subset = {}
    local i = 1
    while #subset < TOURNAMENT_SIZE do
        if math.random(10) == 1 then
            table.insert(subset, evaluatedPopulation[i])
        end
        i = (i < #evaluatedPopulation) and (i + 1) or 1
    end
    return subset
end

local function tournamentSelection()
    parents = {}
    for _ = 1, PARENT_SIZE do
        table.insert(parents, getBest(randomSubset()))
    end
end


-- ── Crossover operators ───────────────────────────────────────

-- Two-point crossover: swap a contiguous slice of moves between two move sets
local function twoPointCrossover(ms1, ms2)
    local len = math.min(#ms1, #ms2)
    if len < 2 then return end
    local p1, p2 = math.random(len), math.random(len)
    if p1 > p2 then p1, p2 = p2, p1 end
    for i = p1, p2 do
        ms1[i], ms2[i] = ms2[i], ms1[i]
    end
end

-- Uniform crossover: independently coin-flip each move gene
local function uniformCrossover(ms1, ms2)
    local len = math.min(#ms1, #ms2)
    for i = 1, len do
        if math.random() < 0.5 then
            ms1[i], ms2[i] = ms2[i], ms1[i]
        end
    end
end

-- Joint-level uniform crossover within a single pair of moves
local function jointLevelCrossover(move1, move2)
    for i = 1, NUM_JOINTS do
        if math.random() < 0.5 then
            move1.move[i], move2.move[i] = move2.move[i], move1.move[i]
        end
    end
end


-- ── Mutation ──────────────────────────────────────────────────

-- Randomise individual joints and optionally the step count of one move
local function tweakMove(move, rate)
    for i = 1, NUM_JOINTS do
        if math.random() < rate then
            move.move[i] = math.random(JOINT_STATES)
        end
    end
    -- Mutate the per-move frame duration too
    if math.random() < rate then
        move.steps = math.random(4)
    end
    return move
end

-- Mutate a move set in-place: tweak moves, possibly insert/delete, adapt rate
local function mutateMoveSet(ms)
    local rate = ms.mutationRate or BASE_MUTATION_RATE
    -- Tweak a random selection of moves
    for _ = 1, math.random(BASE_MUTATE_MOVES) do
        local idx = math.random(#ms)
        ms[idx] = tweakMove(ms[idx], rate)
    end
    -- Variable-length: insert a new random move
    if math.random() < INSERT_PROB and #ms < MAX_MOVES then
        table.insert(ms, math.random(#ms + 1), randomMove())
    end
    -- Variable-length: delete a random move
    if math.random() < DELETE_PROB and #ms > MIN_MOVES then
        table.remove(ms, math.random(#ms))
    end
    -- Self-adapt the mutation rate with a small random perturbation
    ms.mutationRate = clamp(
        rate + (math.random() * 2 - 1) * RATE_NOISE,
        MIN_MUTATION_RATE,
        MAX_MUTATION_RATE
    )
    return ms
end


-- ── Stagnation & diversity ────────────────────────────────────

local function checkStagnation()
    local currentBest = getMaxScore()
    if currentBest > bestScoreEver then
        bestScoreEver = currentBest
        stagnationCount = 0
    else
        stagnationCount = stagnationCount + 1
    end
    echo(string.format("Stagnation: %d/%d  |  Best ever: %.2f",
        stagnationCount, STAGNATION_LIMIT, bestScoreEver))
end

-- Replace the weakest non-elite slots in the built population with randoms
local function injectDiversityIfStagnating()
    if stagnationCount >= STAGNATION_LIMIT then
        echo("Stagnating — injecting " .. DIVERSITY_INJECT_N .. " random individuals")
        stagnationCount = 0
        for i = 1, DIVERSITY_INJECT_N do
            local idx = #population - i + 1
            if idx > ELITE_COUNT then
                population[idx] = randomMoveSet()
            end
        end
    end
end


-- ── Next-generation construction ─────────────────────────────

local function sortedEvaluatedPop()
    local sorted = {}
    for i = 1, #evaluatedPopulation do sorted[i] = evaluatedPopulation[i] end
    table.sort(sorted, function(a, b) return a.finalScore > b.finalScore end)
    return sorted
end

local function buildNextGeneration()
    local sorted = sortedEvaluatedPop()
    population = {}

    -- 1. Elitism: carry the best individuals into next gen unchanged
    for i = 1, math.min(ELITE_COUNT, #sorted) do
        table.insert(population, copyMoveSet(sorted[i].moveSet))
    end

    -- 2. Fill the rest with crossover offspring
    while #population < POPULATION_SIZE do
        parent1 = copyMoveSet(parents[math.random(#parents)].moveSet)
        parent2 = copyMoveSet(parents[math.random(#parents)].moveSet)

        -- Randomly choose uniform or two-point crossover
        if math.random() < 0.5 then
            uniformCrossover(parent1, parent2)
        else
            twoPointCrossover(parent1, parent2)
        end

        -- Joint-level crossover on one randomly chosen shared move
        if #parent1 > 0 and #parent2 > 0 then
            local sharedIdx = math.random(math.min(#parent1, #parent2))
            jointLevelCrossover(parent1[sharedIdx], parent2[sharedIdx])
        end

        -- Blend and lightly perturb mutation rates from both parents
        local r1       = parent1.mutationRate or BASE_MUTATION_RATE
        local r2       = parent2.mutationRate or BASE_MUTATION_RATE
        local blended  = (r1 + r2) / 2
        parent1.mutationRate = clamp(blended + (math.random() * 2 - 1) * RATE_NOISE,
                                     MIN_MUTATION_RATE, MAX_MUTATION_RATE)
        parent2.mutationRate = clamp(blended + (math.random() * 2 - 1) * RATE_NOISE,
                                     MIN_MUTATION_RATE, MAX_MUTATION_RATE)

        if #population < POPULATION_SIZE then
            table.insert(population, mutateMoveSet(parent1))
        end
        if #population < POPULATION_SIZE then
            table.insert(population, mutateMoveSet(parent2))
        end
    end

    echo("New population size: " .. #population)
end


-- ── Core evolution step ───────────────────────────────────────

function evolvePopulation()
    tournamentSelection()
    buildNextGeneration()
    injectDiversityIfStagnating()
    evaluatedPopulation = {}
    lastScore  = 0
    lastInjury = 0
    start_new_game()
    evaluatePopulation()
end


-- ── Chromosome evaluation ─────────────────────────────────────

function evaluateChromosome()
    local currentMove = table.remove(chromosome, 1)
    setJoints(0, currentMove.move)
    table.insert(evaluatedPopulation[#evaluatedPopulation], currentMove)
    if #chromosome == 0 then
        run_frames(GAME_LENGTH - get_world_state().match_frame)
    else
        run_frames(FRAME_LENGTH * currentMove.steps)
    end
end

-- Called on every enter_freeze hook; drives the evaluation pipeline
function evaluatePopulation()
    if #chromosome == 0 then
        if #population ~= 0 then
            chromosome = table.remove(population, 1)
            -- Carry the move set's self-adapted mutation rate into the eval slot
            local slot = {}
            slot.mutationRate = chromosome.mutationRate or BASE_MUTATION_RATE
            table.insert(evaluatedPopulation, slot)
            evaluateChromosome()
        end
    else
        -- Score the move that just finished executing
        local injuryDelta = get_player_info(1).injury - lastScore
        local selfDelta   = get_player_info(0).injury - lastInjury
        evaluatedPopulation[#evaluatedPopulation][#evaluatedPopulation[#evaluatedPopulation]].score =
            injuryDelta - selfDelta
        lastScore  = get_player_info(1).injury
        lastInjury = get_player_info(0).injury
        evaluateChromosome()
    end
end


-- ── Scoring ───────────────────────────────────────────────────

function scorePopulation()
    for i = 1, #evaluatedPopulation do
        local moveList = evaluatedPopulation[i]
        evaluatedPopulation[i] = {
            moveSet    = moveList,
            finalScore = getFinalScore(moveList)
        }
        -- Normalise stored scores to deltas between successive moves
        for j = #evaluatedPopulation[i].moveSet, 2, -1 do
            evaluatedPopulation[i].moveSet[j].score =
                evaluatedPopulation[i].moveSet[j].score -
                evaluatedPopulation[i].moveSet[j-1].score
        end
    end
end


-- ── Replay ────────────────────────────────────────────────────

function replayBest()
    local best = evaluatedPopulation[1]
    for i = 2, #evaluatedPopulation do
        if evaluatedPopulation[i].finalScore > best.finalScore then
            best = evaluatedPopulation[i]
        end
    end
    echo("Replaying generation best — score: " .. best.finalScore)
    table.insert(population, copyMoveSet(best.moveSet))
    start_new_game()
    evaluatePopulation()
end

-- Replay the overall champion from the Hall of Fame
function replayHallOfFame()
    if #hallOfFame == 0 then
        replayBest()
        return
    end
    local champion = hallOfFame[1]
    echo("Hall of Fame champion replay — score: " .. champion.finalScore)
    table.insert(population, copyMoveSet(champion.moveSet))
    start_new_game()
    evaluatePopulation()
end


-- ── Initialisation ────────────────────────────────────────────

function createRandomPopulation()
    population = {}
    for i = 1, POPULATION_SIZE do
        population[i] = randomMoveSet()
    end
    return population
end

function initializeEvolution()
    -- Seed the RNG so each run produces a different initial population
    if os and os.time then math.randomseed(os.time()) end
    population = createRandomPopulation()
    start_new_game()
    evaluatePopulation()
end


-- ── End-of-game handler ───────────────────────────────────────

function endGame()
    if #population ~= 0 then
        -- Mid-generation: an individual game ended, keep going
        chromosome = {}
        lastScore  = 0
        lastInjury = 0
        start_new_game()
        evaluatePopulation()
    else
        -- Full generation evaluated; clear any stale moves from an early game end (e.g. KO)
        chromosome = {}
        lastScore  = 0
        lastInjury = 0
        scorePopulation()
        updateHallOfFame()
        checkStagnation()

        local avg = getAverageScore()
        local max = getMaxScore()
        echo(string.format("Gen %d/%d  |  Avg: %.2f  |  Max: %.2f  |  Best ever: %.2f",
            generationNum, NUM_GENERATIONS, avg, max, bestScoreEver))

        appendLine("averageScoreEnhanced.txt", avg)
        appendLine("maxScoreEnhanced.txt",     max)

        if generationNum == NUM_GENERATIONS then
            writePopulationToFile()
            replayHallOfFame()
        else
            generationNum = generationNum + 1
            evolvePopulation()
        end
    end
end


-- ── Toribash hooks ────────────────────────────────────────────

set_option("fixedframerate", 0)
run_cmd("set tf 10")

add_hook("enter_freeze", "eval_population_enhanced", evaluatePopulation)
add_hook("end_game",     "end_game_enhanced",        endGame)

initializeEvolution()
