
local maxSteps = 50
local game_length = 500
local start = true
local population = {}
local population_size = 10
local generations_evaluated = 0
local max_generations = 1
-- index representing where we are in the population
local current_move_set = 1

-- index representing where we are in the move
local current_move = 1

-- index representing how many steps we have been on this move for
local current_move_steps = 0


function winning()
   Player1_Score = get_player_info(1).injury
   Player2_Score = get_player_info(0).injury
   if(Player1_Score > Player2_Score) then
      return "Player 1"
   elseif(Player2_Score > Player1_Score) then
      return "Player 2"
   else
      return "Draw!"
   end
end



local function setJoints(player, js)
	for i = 1, #js do
		set_joint_state(player, i-1, js[i])
	end
end

-- joint values: 1 and 2 are extending or contracting, 3 is holding, 4 is relaxing

function enter_frame()
	echo("entered frame " .. current_move_set .. " " .. current_move .. " " .. current_move_steps .. " " .. generations_evaluated)
    --echo("Winning: ^06" .. winning())
    if current_move_steps == population[current_move_set][current_move].steps then
    	--echo("move steps")
    	if current_move < #population[current_move_set] then
    		current_move = current_move + 1
    	end
    	current_move_steps = 0
    end

    -- if current_move > #population[current_move_set][current_move] then
    -- 	--calculate the score of the move_set
    -- 	--echo("move " .. current_move)
    -- 	current_move_set = current_move_set + 1

    -- 	current_move = 1
    -- 	current_move_steps = 0
    -- end
    echo(#population)
    
    if current_move == 1 then
    	population[current_move_set][current_move].score = get_player_info(1).injury
    	population[current_move_set][current_move].injury = get_player_info(0).injury
    else 
    	population[current_move_set][current_move].score = (get_player_info(1).injury - population[current_move_set][current_move].score)
    	population[current_move_set][current_move].score = (get_player_info(0).injury - population[current_move_set][current_move].injury)
    end
    
    -- Change joints and step the game
    setJoints(0,population[current_move_set][current_move].move)
    current_move_steps = current_move_steps + 1

    step_game()

    
    --echo("blah " .. get_body_info(1, 0).pos)
end

function endGame()
	--check scores
	--run all children in generation
	--after that mutate and run again
	--repeat some set number of times
	if current_move_set >= #population then
    	--mutate and restart
    	echo("move_set " .. current_move_set)
    	current_move_set = 1
    	current_move = 1
    	current_move_steps = 0

    	generations_evaluated = generations_evaluated + 1
    	--make generation based on the old generation
    end
	if get_world_state().match_frame == game_length then
		if generations_evaluated == max_generations then
    		evolutionEnd()
    	else
			--change move set
			current_move_set = current_move_set + 1
	    	current_move = 1
	    	current_move_steps = 0

	    	--start new game
			--echo(current_move_set)
			start_new_game()
			step_game()
		end
	end
end

function initializeEvolution()
	--create a population and start the game
	--example move-set {{move = {}, steps = 1, score = 0}}

	population = {}
	move1 = {}
	
	for i=1,population_size do
		population[i] = {}
	    for j=1,math.random(20) do
	    	population[i][j] = {move = {}, steps = math.random(4), score = 0, injury = 0}
	    	for k=1,20 do
	    		population[i][j].move[k] = math.random(4)
	    	end
	    end 
	end

	start_new_game()
	step_game()
end

local function WritePopulationFile()
	local file = io.open("population.txt", "w",1)
	for i=1,population_size do
		for j=1, #population[i] do
			file:write("[")
			for k=1, #population[i][j].move - 1 do
				file:write(population[i][j].move[k])
				file:write(", ")
			end
			file:write(population[i][j].move[#population[i][j].move])
			file:write("] \n Score: ")
			file:write(population[i][j].score)
			file:write("\n Injury: ")
			file:write(population[i][j].injury)
			file:write("\n")
		end
		file:write("\n")
	end
	io.close(file)
end

function evolutionEnd()
	-- do some final selection and shit
	local current_move_set = 1

	-- index representing where we are in the move
	local current_move = 1

	-- index representing how many steps we have been on this move for
	local current_move_steps = 0
	local generations_evaluated = 0
	
	-- save final population to file
	WritePopulationFile()
	

end



set_option("fixedframerate", 0)
run_cmd("set tf 10")

add_hook("enter_freeze","echowinner",enter_frame)
add_hook("end_game", "end game", endGame)

initializeEvolution()
