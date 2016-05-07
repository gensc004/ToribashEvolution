
-- Population objects for evolution
local evaluatedPopulation = {}
local population = {}
local chromosome = {}
local parents = {}
local parent1 = {}
local parent2 = {}

-- Toribash specifications
local frameLength = 10
local game_length = 500

-- Evolution parameters
local population_size = 50
local numGenerations = 10
local generationNum = 1
local generations_evaluated = 0
local max_generations = 1
local maxSteps = 50
local maxNumOfParents = 4
local tournamentSize = 2
local lastInjury = 0
local lastScore = 0


-- index representing where we are in the population
local current_move_set = 1

-- index representing where we are in the move
local current_move = 1

-- index representing how many steps we have been on this move for
local current_move_steps = 0

local function writePopulationtoFile()
	--echo("writing")
	local file = io.open("randomPopulation.txt", "w",1)
	for i=1,population_size do
		file:write("moveSet\n")
		for j=1, #evaluatedPopulation[i].moveSet do
			file:write("Steps:" .. evaluatedPopulation[i].moveSet[j].steps)
			file:write("\n")
			for k=1, #evaluatedPopulation[i].moveSet[j].move do
				file:write(evaluatedPopulation[i].moveSet[j].move[k])
				file:write("\n")
			end
		end
		file:write("\n")
	end
	io.close(file)
end

function getAverageScore()
	total = 0
	for i=1, #evaluatedPopulation do
		total = total + evaluatedPopulation[i].finalScore
	end
	return total / #evaluatedPopulation
end

local function writeScoretoFile()
	local file = io.open("randomScore.txt", "a",1)
	echo("Average: "..getAverageScore())
	file:write(""..getAverageScore())
	file:write("\n")
	io.close(file)
end

local function fillPopulation(filename)
	local file = io.open(filename, "r",1)
	population = {}
	i = 0;
	j = 0;
	k = 1;
	for line in file:lines() do
		if string.find(line, "moveSet") then
			j = 1;
			k = 1;
			i = i + 1;
			population[i] = {}
			population[i][j] = {move = {}, steps = 0, score = 0}
		elseif string.find(line,"Steps:") then
			k = 1;
			population[i][j].steps = string.find(line,"%d+")
			j = j + 1;
			population[i][j] = {move = {}, steps = 0, score = 0}
		elseif string.find(line, "%d") then
			population[i][j].move[k] = string.find(line,"%d")
			-- --echo(population[i][j].move[k])
			k = k + 1;
		end
	end
	-- -- --echo("size" .. #population)
	io.close(file)
end

local function setJoints(player, js) 
	for i = 1, #js do
		set_joint_state(player, i-1, js[i])
	end
end

function getBest(li)
	best = li[1]
	for i=2,#li do
		if best.finalScore < li[i].finalScore then
			best = li[i]
		end
	end
	return best
end

function randomSubset() 
	subset = {}
	i = 1
	while #subset < tournamentSize do
		if math.random(10) == 1 then
			table.insert(subset, evaluatedPopulation[i])
		end
		if i < #evaluatedPopulation then
			i = i + 1
		else
			i = 1
		end
	end
	return subset
end

function tournamentSelection() 
	parents = {}
	--echo("selecting")

	for i=1, (math.random(maxNumOfParents) + 1) do
		----echo(i)
		table.insert(parents, getBest(randomSubset()))
	end

end

function crossover(i1, i2)
	if i1 <= i2 then
		left = i1
		right = i2
	else
		left = i2
		right = i1
	end

	for i=left, right do
		if i <= #parent2 then
			temp = parent1[i]
			parent1[i] = parent2[i]
			parent2[i] = temp
		end
	end
end

function tweak(move)
	for i = 1, 20 do
		rand = math.random()
		if rand <= 0.25 then
			move.move[i] = math.random(4)
		end
	end
	return move
end

function mutateAnswer(answer, maxChange)
	num = math.random(maxChange) - 1
	for i = 1, num do
		index = math.random(#answer)
		answer[index] = tweak(answer[index])
	end
	return answer
end

function ourCopy(obj)
	newArr = {}
	for i=1, #obj do 
		newMove = {}
		newMoveArr = {}
		for j=1, #obj[i].move do
			newMoveArr[j] = obj[i].move[j]
		end
		newMove.move = newMoveArr
		newMove.steps = obj[i].steps
		newMove.score = obj[i].score
		newArr[i] = newMove
	end
	return newArr
end

function crossoverParents()
	--echo("crossover")
	for i=1,(population_size / 2) do
		----echo(i)
		parent1 = ourCopy(parents[math.random(#parents)].moveSet)
		parent2 = ourCopy(parents[math.random(#parents)].moveSet)
		-- swap moves
		crossover(math.random(#parent1), math.random(#parent1))
		--maybe mutate
		table.insert(population, parent1)
		-- for i=1,#parent1 do
		-- 	table.insert(population[#population],parent1[i])
		-- end
		population[#population] = mutateAnswer(population[#population], 6)
		table.insert(population, parent2)
		-- for i=1,#parent2 do
		-- 	table.insert(population[#population],parent2[i])
		-- end
		population[#population] = mutateAnswer(population[#population], 6)
	end
	-- --echo(#population)
	for i=1, #population do
		--echo(#population[i])
	end
end


function evolvePopulation() 
	--echo("Evolving")
	-- Select some number of parents from the population
	tournamentSelection()
	-- Crossover sections of the parents with two point crossover
	crossoverParents()
	-- Create the next generation by mutating some joints
	evaluatedPopulation = {}
	--chromosome = {}
	start_new_game()
	evaluatePopulation()
	--createNewGeneration()
end

-- joint values: 1 and 2 are extending or contracting, 3 is holding, 4 is relaxing

function evaluateChromosome()

	-- --echo("Evaluate chromosome")
	-- get next move from the set (remove(table, 1) takes from the front)
	--echo(#chromosome)
	currentMove = table.remove(chromosome, 1)
	--echo("Set joints")
	-- set the joints
	setJoints(0,currentMove.move)



	-- put the move in the evaluatedPopulation in the proper set of moves (insert(table, value) inserts at end)
	table.insert(evaluatedPopulation[#evaluatedPopulation], currentMove)

	-- Run the frameLength number of frames * the number of steps
	if #chromosome == 0 then
		--echo("finish round")
		--echo(#population)
		run_frames(game_length - get_world_state().match_frame)
	else
		-- --echo("move")
		run_frames(frameLength * currentMove.steps)
	end
end

-- this is called whenever the frames move forward
function evaluatePopulation()
	----echo("Evaluate population")
	-- if we have used all the moves in a move set
	if #chromosome == 0 then
		--echo("Evaluating: "..#population)
		-- Ensures that the last move is scored properly
		-- if #evaluatedPopulation ~= 0 then
		-- 	evaluatedPopulation[#evaluatedPopulation][#evaluatedPopulation[#evaluatedPopulation]].score = get_player_info(1).injury
		-- end
		-- Set the next moveSet in the population to chromosome and evaluate the first move in it
		if #population ~= 0 then
			--echo("Evaluating cont: "..#population)
			--echo(#population[1])
			chromosome = table.remove(population, 1)
			--echo(#chromosome)
			--echo(chromosome)
			--echo(#population)

			table.insert(evaluatedPopulation, {})
			evaluateChromosome()
		end
	else
		evaluatedPopulation[#evaluatedPopulation][#evaluatedPopulation[#evaluatedPopulation]].score = ((get_player_info(1).injury - lastScore) - (get_player_info(0).injury - lastInjury))
		lastScore = get_player_info(1).injury
		lastInjury = get_player_info(0).injury
		evaluateChromosome()
	end
end

function createRandomPopulation()
	population = {}
	for i=1,population_size do
		population[i] = {}
	    for j=1,math.random(20) do
	    	population[i][j] = {move = {}, steps = math.random(4), score = 0}
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
	evaluatedPopulation = {}
	--fillPopulation("population.txt")
	--free_play()
	start_new_game()
	--echo("new game started")
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
	--echo("THE FUCK:"..#evaluatedPopulation)
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
	--echo("THE FUCK")
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
	----echo("BLAH: "..#population)
	start_new_game()
	----echo("new game started")
	evaluatePopulation()
end

-- this function is called when a game ends
function endGame()
	-- if the population is empty then we are done! else start a new game!
	if #population ~= 0 then
		-- the game ended and we want to move ahead in the world

		chromosome = {}
		lastScore = 0
		lastInjury = 0
		start_new_game()
		evaluatePopulation()
	else
		-- Score the population
		scorePopulation()
		----echo("finished scored population")

		-- replays the best move set in a generation
		--replayBest()

		-- Evolve the population
		if generationNum == numGenerations then
			echo("lastGen: "..generationNum)
			writeScoretoFile()
			writePopulationtoFile()
			replayBest()
		else
			echo("generation#: "..generationNum)
			writeScoretoFile()
			generationNum = generationNum + 1
			lastScore = 0
			lastInjury = 0
			initializeEvolution()
		end
	end
end

function evolutionEnd()
	--echo("We did it!")
end

set_option("fixedframerate", 0)
run_cmd("set tf 10")

add_hook("enter_freeze","--echowinner", evaluatePopulation)
add_hook("end_game", "end game", endGame)
--add_hook("replay_best_game", "replay best", replayBestGame)

initializeEvolution()