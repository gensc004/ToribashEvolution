require "io"
local maxSteps = 50
local game_length = 500
local start = true


local evaluatedPopulation = {}
local population = {}
local chromosome = {}
local frameLength = 10

local population_size = 3
local generations_evaluated = 0
local max_generations = 1
local replay_move = 1
local bestGame = {}
local replay_steps = 0
replay = false
-- index representing where we are in the population
local current_move_set = 1

-- index representing where we are in the move
local current_move = 1

-- index representing how many steps we have been on this move for
local current_move_steps = 0


local function setJoints(player, js)
	for i = 1, #js do
		set_joint_state(player, i-1, js[i])
	end
end

-- joint values: 1 and 2 are extending or contracting, 3 is holding, 4 is relaxing

function evaluateChromosome()

	-- echo("Evaluate chromosome")
	-- get next move from the set (remove(table, 1) takes from the front)
	currentMove = table.remove(chromosome, 1)

	-- set the joints
	setJoints(0,currentMove.move)

	-- put the move in the evaluatedPopulation in the proper set of moves (insert(table, value) inserts at end)
	table.insert(evaluatedPopulation[#evaluatedPopulation], currentMove)

	-- Run the frameLength number of frames * the number of steps
	if #chromosome == 0 then
		echo("finish round")
		run_frames(game_length - get_world_state().match_frame)
	else
		-- echo("move")
		run_frames(frameLength * currentMove.steps)
	end
end

-- this is called whenever the frames move forward
function evaluatePopulation()
	--echo("Evaluate population")
	-- if we have used all the moves in a move set
	if #chromosome == 0 then
		-- Ensures that the last move is scored properly
		-- if #evaluatedPopulation ~= 0 then
		-- 	evaluatedPopulation[#evaluatedPopulation][#evaluatedPopulation[#evaluatedPopulation]].score = get_player_info(1).injury
		-- end
		-- Set the next moveSet in the population to chromosome and evaluate the first move in it
		if #population ~= 0 then
			chromosome = table.remove(population, 1)
			table.insert(evaluatedPopulation, {})
			evaluateChromosome()
		end
	else
		evaluatedPopulation[#evaluatedPopulation][#evaluatedPopulation[#evaluatedPopulation]].score = get_player_info(1).injury
		evaluateChromosome()
	end
end

function createRandomPopulation()
	population = {}
	for i=1,population_size do
		population[i] = {}
	    for j=1,math.random(20) do
	    	population[i][j] = {move = {}, steps = math.random(4), score = 0, injury = 0}
	    	for k=1,20 do
	    		population[i][j].move[k] = math.random(4)
	    	end
	    end 
	end
	return population
end

function initializeEvolution()
	--create a population and start the game
	--example move-set {{move = {}, steps = 1, score = 0}}
	population = createRandomPopulation()
	start_new_game()
	echo("new game started")
	evaluatePopulation()
end

--finds the total score

function getFinalScore(pop)
	best = pop[1].score
	for i=2,#pop do
		if best <= pop[i].score then
			best = pop[i].score
		end
	end
	return best
end

function scorePopulation()
	for i=1,#evaluatedPopulation do
		-- Set the final score to the max of the moves
		evaluatedPopulation[i] = {moveSet = evaluatedPopulation[i], finalScore = getFinalScore(evaluatedPopulation[i])}
		for j=#evaluatedPopulation[i].moveSet,1,-1 do
			--makes scores equal to the change in score
			if j ~= 1 then
				evaluatedPopulation[i].moveSet[j].score = evaluatedPopulation[i].moveSet[j].score - evaluatedPopulation[i].moveSet[j-1].score
			end
		end
	end
end

function replayBest()
	best = evaluatedPopulation[1]
	-- Pick the best
	for i=2,#evaluatedPopulation do
		if best.finalScore <= evaluatedPopulation[i].finalScore then
			best = evaluatedPopulation[i]
		end
	end
	table.insert(population, best.moveSet)
	--echo("BLAH: "..#population)
	start_new_game()
	--echo("new game started")
	evaluatePopulation()
end

-- this function is called when a game ends
function endGame()
	-- if the population is empty then we are done! else start a new game!
	if #population ~= 0 then
		-- the game ended and we want to move ahead in the world

		chromosome = {}
		start_new_game()
		evaluatePopulation()
	else
		echo("we done")

		-- Score the population
		scorePopulation()
		--echo("finished scored population")

		-- replays the best move set in a generation
		replayBest()

		-- Evolve the population
		evolvePopulation()
	end
end

function evolutionEnd()
	echo("We did it!")
end

set_option("fixedframerate", 0)
run_cmd("set tf 10")

add_hook("enter_freeze","echowinner", evaluatePopulation)
add_hook("end_game", "end game", endGame)
--add_hook("replay_best_game", "replay best", replayBestGame)

initializeEvolution()