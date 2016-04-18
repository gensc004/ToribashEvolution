local step = 0
local maxSteps = 10
local game_length = 500

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
    --echo("Winning: ^06" .. winning())
    move1 = {}
    for i=1,20 do
    	move1[i] = math.random(4)
    end 

    move2 = {}
    for i=1,20 do
    	move2[i] = math.random(4)
    end 


    setJoints(0,move1)
    setJoints(1,move2)
    echo(get_world_state())

    if get_world_state().match_frame <= 500 then
    	step_game()
    else 
    	start_new_game()
    	echo("We done bb")
    end

    
    --echo("blah " .. get_body_info(1, 0).pos)
end

function endGame()
	--check scores
	--run all children in generation
	--after that mutate and run again
	--repeat some set number of times
	if get_world_state().match_frame == 500 then
		echo("New game time")
		start_new_game()
		step_game()
	end
end

set_option("fixedframerate", 0)
run_cmd("set tf 10")

add_hook("enter_freeze","echowinner",enter_frame)
add_hook("end_game", "end game", endGame)
