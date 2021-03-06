-- << creepwars/endlevel_utils

local wesnoth = wesnoth
local addon = creepwars
local ipairs = ipairs
local side_to_team = creepwars.side_to_team
local team_array = creepwars.team_array

local function is_single_survivor()
	local alive_team
	for _, unit in ipairs(wesnoth.get_units { canrecruit = true }) do
		local new_team = wesnoth.sides[unit.side].team_name
		if alive_team == nil then
			alive_team = new_team
		elseif alive_team ~= new_team then
			return false
		end
	end
	return true
end


local function side_is_local(side)
	return wesnoth.sides[side].controller == "human" and wesnoth.sides[side].is_local ~= false
end

local function am_i_victorious(winner_team)
	for _, side in ipairs(wesnoth.sides) do
		if side.team_name == winner_team and side_is_local(side.side) then
			return true
		end
	end
	for _, side in ipairs(wesnoth.sides) do
		if side_is_local(side.side) then
			return false
		end
	end
	return true
end


local function guard_killed_event(aggressive_side, defeated_side)
	for _, ally_side in ipairs(team_array[side_to_team[defeated_side]]) do
		wesnoth.wml_actions.kill { side = ally_side }
	end
	if is_single_survivor() then
		local winner_team = wesnoth.sides[aggressive_side].team_name
		print("is single surviver: yes, result: ", am_i_victorious(winner_team) and "victory" or "defeat")
		wesnoth.wml_actions.endlevel { result = am_i_victorious(winner_team) and "victory" or "defeat" }
	end
end

addon.guard_killed_event = guard_killed_event

-- >>
