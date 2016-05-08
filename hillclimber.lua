-- Population objects for evolution
local evaluatedClimber = {}
local climber = {}
local climberIndex = 1
local oldClimber = {}
local biggestWinners = {}


-- Toribash specifications
local frameLength = 10
local game_length = 500

-- Evolution parameters
local numGenerations = 500
local generationsEvaluated = 1
local maxSteps = 50
local lastInjury = 0
local lastScore = 0
local last = true


local function writePopulationtoFile()
	local file = io.open("hillclimberPopulation.txt", "w",1)
	--file:write("moveSet\n")
	echo(#biggestWinners)
	for k=1, #biggestWinners do
		file:write("moveSet\n")
		for i=1, #biggestWinners[k].moveSet do
			file:write("Steps:" .. biggestWinners[k].moveSet[i].steps)
			file:write("\n")
			for j=1, #biggestWinners[k].moveSet[i].move do
				file:write(biggestWinners[k].moveSet[i].move[j])
				file:write("\n")
			end
		end
	end
	file:write("\n")
	io.close(file)
end

function getAverageScore()
	return climber[#climber].score
end

local function writeScoretoFile()
	local file = io.open("hillclimberScore.txt", "a",1)
	-- echo("Average: "..getAverageScore())
	file:write(""..getScore(climber))
	file:write("\n")
	io.close(file)
end

local function createClimber(filename)
	local file = io.open(filename, "r",1)
	population = {}
	i = 0;
	j = 1;
	k = 1;
	for line in file:lines() do
		if string.find(line, "moveSet") ~= nil then
			j = 1;
			k = 1;
			i = i + 1;
			-- echo("blerb")
			climber = {}
			climber[j] = {move = {}, steps = 0, score = 0}
		elseif string.find(line,"Steps:") ~= nil then
			--echo(line)
			--echo(string.sub(line, string.find(line,"%d+"), string.find(line,"%d+")))
			k = 1;
			climber[j] = {move = {}, steps = 0, score = 0}
			climber[j].steps = string.match(line, "%d+")
			j = j + 1;
			
		elseif string.find(line, "%d") ~= nil then
			climber[j-1].move[k] = string.match(line, "%d")
			--echo(climber[j].move[k])
			k = k + 1;
		end
	end
	io.close(file)
end

function ourCopy(obj)
	-- echo("ourCOpy")
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

local function setJoints(player, js) 
	for i = 1, #js do
		set_joint_state(player, i-1, js[i])
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
	-- echo("Returning "..generationsEvaluated)
	return answer
end

function getScore(cli) 
	total = 0
	for i=1, #cli do
		total = total + cli[i].score
	end
	return total
end

function mutateClimber() 
	-- echo("MUTATING")
	climber = mutateAnswer(climber, 6)
	return climber
end

function evaluateClimber()
	climber[climberIndex].score = (get_player_info(1).injury - lastScore) - (get_player_info(0).injury - lastInjury)
	lastInjury = get_player_info(0).injury
	lastScore = get_player_info(1).injury
	if climberIndex < #climber then
		setJoints(0,climber[climberIndex].move)
		run_frames(frameLength * climber[climberIndex].steps)
	else 
		setJoints(0,climber[climberIndex].move)
		run_frames(game_length - get_world_state().match_frame)
	end
	climberIndex = climberIndex + 1

end

function endGame()
	climberIndex = 1
	if generationsEvaluated > 1 then
		echo("lastClimber: "..getScore(lastClimber))
		echo("climber: "..getScore(climber))
		if getScore(lastClimber) > getScore(climber) then
			 echo("Keeping lastClimber")
			climber = ourCopy(lastClimber)
		else 
			-- echo("keeping climber")
			if #biggestWinners <= 10 then
				table.insert(biggestWinners, {moveSet = ourCopy(climber), change = (getScore(climber) - getScore(lastClimber))})
			else
				smallestIndex = 1
				for i=1, #biggestWinners do
					if biggestWinners[i].change < biggestWinners[smallestIndex].change then
						smallestIndex = i
					end
				end
				if biggestWinners[smallestIndex].change < (getScore(climber) - getScore(lastClimber)) then
					biggestWinners[smallestIndex] = {moveSet = ourCopy(climber), change = (getScore(climber) - getScore(lastClimber))}
				end
			end
			lastClimber = ourCopy(climber)
		end
	else 
		lastClimber = ourCopy(climber)
	end
	writeScoretoFile()
	if numGenerations == generationsEvaluated then
		-- replayBest()
		if last then
			start_new_game()
			evaluateClimber()
			writePopulationtoFile()
			last = false
		end
		-- echo("weDone")
	else
		generationsEvaluated = generationsEvaluated + 1
		climber = mutateClimber()
		lastInjury = 0
		lastScore = 0
		start_new_game()
		evaluateClimber()
	end

end

function createRandomClimber()
	climber = {}
	for i=1,math.random(20) do
    	climber[i] = {move = {}, steps = math.random(4), score = 0}
    	for j=1,20 do
    		climber[i].move[j] = math.random(4)
    		---- echo(climber[i].move[j])
    	end
    end 
    return climber
end

function initializeEvolution()
	--create a population and start the game
	--example move-set {{move = {}, steps = 1, score = 0}}
	--climber = createRandomClimber()
	createClimber("runs/hillclimberPopulation6.txt")
	---- echo(climber[1].move[1])
	--free_play()
	start_new_game()
	-- echo("new game started")
	-- echo(#climber)
	evaluateClimber()
end

add_hook("enter_freeze","-- echowinner", evaluateClimber)
add_hook("end_game", "end game", endGame)

initializeEvolution()




