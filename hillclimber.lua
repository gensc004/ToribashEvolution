-- Population objects for evolution
local evaluatedClimber = {}
local climber = {}
local climberIndex = 1
local oldClimber = {}


-- Toribash specifications
local frameLength = 10
local game_length = 500

-- Evolution parameters
local numGenerations = 1
local generationsEvaluated = 0
local maxSteps = 50
local lastInjury = 0
local lastScore = 0


local function writePopulationtoFile()
	local file = io.open("hillclimberPopulation.txt", "a",1)
	file:write("moveSet\n")
	for i=1, #climber do
		file:write("Steps:" .. climber[i].steps)
		file:write("\n")
		for j=1, #climber[i].move do
			file:write(climber[i].move[j])
			file:write("\n")
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
	echo("Average: "..getAverageScore())
	file:write(""..getAverageScore())
	file:write("\n")
	io.close(file)
end

function ourCopy(obj)
	echo("ourCOpy")
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
	echo("Returning "..generationsEvaluated)
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
	echo("MUTATING")
	climber = mutateAnswer(climber, 6)
	return climber
end

function evaluateClimber()
	climber[climberIndex].score = get_player_info(1).injury 
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
	if numGenerations == generationsEvaluated then
		-- replayBest()
		echo("weDone")
	else
		climberIndex = 1
		if generationsEvaluated > 0 then
			echo(getScore(lastClimber))
			echo(getScore(climber))
			if getScore(lastClimber) > getScore(climber) then
				echo("Keeping lastClimber")
				climber = ourCopy(lastClimber)
			else 
				echo("keeping climber")
				lastClimber = ourCopy(climber)
			end
		else 
			lastClimber = ourCopy(climber)
		end
		writeScoretoFile()
		writePopulationtoFile()
		generationsEvaluated = generationsEvaluated + 1
		climber = mutateClimber()
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
    		--echo(climber[i].move[j])
    	end
    end 
    return climber
end

function initializeEvolution()
	--create a population and start the game
	--example move-set {{move = {}, steps = 1, score = 0}}
	climber = createRandomClimber()
	--echo(climber[1].move[1])
	--free_play()
	start_new_game()
	echo("new game started")
	echo(#climber)
	evaluateClimber()
end

add_hook("enter_freeze","echowinner", evaluateClimber)
add_hook("end_game", "end game", endGame)

initializeEvolution()




