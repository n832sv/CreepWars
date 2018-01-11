-- << event_die.lua

local wesnoth = wesnoth
local creepwars = creepwars
local ipairs = ipairs
local unit_kill_event = creepwars.unit_kill_event
local side_to_team = creepwars.side_to_team
local team_array = creepwars.team_array
local is_ai_array = creepwars.is_ai_array

local defender = wesnoth.get_unit(wesnoth.get_variable("x1") or 0, wesnoth.get_variable("y1") or 0)
local attacker = wesnoth.get_unit(wesnoth.get_variable("x2") or 0, wesnoth.get_variable("y2") or 0)
if defender == nil then
	local msg = "Warning: cannot find killed unit. No gold/creep bonus was generated."
	print(msg)
	wesnoth.message("Creep Wars", msg)
elseif attacker == nil then
	local msg = "Warning: Unit died without attacker. This is unexpected. " ..
		"No creep score or gold bonus will be generated. " ..
		"This is probably because of a conflicting addon/modification. " ..
		"If the host has no modifications, please report the issue."
	print(msg)
	wesnoth.message("Creep Wars", msg)
elseif not defender.canrecruit and not defender.variables["creepwars_creep"] then
	local msg = "Turn " .. wesnoth.get_variable("turn_number") .. ": " .. defender.type
		.. " died, neither Leader nor Creep. Probably plagued. No gold/creep bonus was generated."
	print(msg)
	-- wesnoth.message("Creep Wars", msg)
else
	unit_kill_event(attacker, defender)
	if defender.canrecruit and is_ai_array[defender.side] then
		for _, ally_side in ipairs(team_array[side_to_team[defender.side]]) do
			wesnoth.wml_actions.kill { side = ally_side }
		end
	elseif defender.canrecruit and not is_ai_array[defender.side] then
		creepwars.leader_died_event(defender)
	end
end

-- >>
