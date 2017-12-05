-- << leaders_mirror_style

local wesnoth = wesnoth
local helper = wesnoth.require "lua/helper.lua"
local creepwars_memoize_ai_side_set = creepwars_memoize_ai_side_set
local creepwars_mirror_style = creepwars_mirror_style
local creepwars_recruitable_array = creepwars_recruitable_array
local creepwars_leader_strength = creepwars_leader_strength
local split_comma = creepwars_split_comma

local function downgrade()
	for _, unit in ipairs(wesnoth.get_units { canrecruit = true }) do
		if creepwars_memoize_ai_side_set[unit.side] ~= true then
			local downgrade_array = wesnoth.unit_types[unit.type].advances_from
			if downgrade_array and #downgrade_array > 0 then
				-- local downgrade = downgrade_array[helper.rand("1.." .. #downgrade_array + 1)]
				local downgrade = downgrade_array[1] -- need the same for true mirror
				wesnoth.transform_unit(unit, downgrade)
				unit.hitpoints = unit.max_hitpoints
			end
		end
	end
end

local function downgrade_wesnoth112()
	local downgrade_map = {} -- map unit -> downgrades
	for unit_name, unit_data in pairs(wesnoth.unit_types) do
		for _, adv in ipairs(split_comma(unit_data.__cfg.advances_to)) do
			downgrade_map[adv] = downgrade_map[adv] or {}
			local arr = downgrade_map[adv]
			arr[#arr + 1] = unit_name
		end
	end

	for _, unit in ipairs(wesnoth.get_units { canrecruit = true }) do
		if creepwars_memoize_ai_side_set[unit.side] ~= true then
			local downgrade_array = downgrade_map[unit.type]
			if downgrade_array and #downgrade_array > 0 then
				local downgrade = downgrade_array[1] -- need the same for true mirror
				wesnoth.transform_unit(unit, downgrade)
				unit.hitpoints = unit.max_hitpoints
			end
		end
	end
end


local function set_all_leaders(unit_array_function)
	local team_units = {}
	local team_index = {}
	for _, side in ipairs(wesnoth.sides) do
		local has_leaders = #wesnoth.get_units { canrecruit = true, side = side.side } > 0
		local is_human = creepwars_memoize_ai_side_set[side.side] ~= true
		if has_leaders and is_human then
			team_units[side.team_name] = team_units[side.team_name] or unit_array_function()
			team_index[side.team_name] = team_index[side.team_name] or 1
			local type = team_units[side.team_name][team_index[side.team_name]]
			for _, unit in ipairs(wesnoth.get_units { canrecruit = true, side = side.side }) do
				wesnoth.transform_unit(unit, type)
				unit.hitpoints = unit.max_hitpoints
			end
			team_index[side.team_name] = team_index[side.team_name] + 1
		end
	end
end


local leader_rand_string = "1.." .. #creepwars_recruitable_array
local function random_leader() return creepwars_recruitable_array[helper.rand(leader_rand_string)] end


local function force_mirror()
	local units = {}
	local team
	for _, side in ipairs(wesnoth.sides) do
		local has_leaders = #wesnoth.get_units { canrecruit = true, side = side.side } > 0
		local is_human = creepwars_memoize_ai_side_set[side.side] ~= true
		if has_leaders and is_human then
			if team == nil then team = side.team_name end
			if team == side.team_name then
				units[#units + 1] = wesnoth.get_units { canrecruit = true, side = side.side }[1].type
			end
		end
	end
	if #units < 4 then units[#units + 1] = random_leader() end
	if #units < 4 then units[#units + 1] = random_leader() end
	if #units < 4 then units[#units + 1] = random_leader() end
	set_all_leaders(function() return units end)
end

local function force_same_strength()

	local function rnd_array() return { random_leader(), random_leader(), random_leader(), random_leader() } end

	local function array_cost(arr)
		local result = 0
		for _, u in ipairs(arr) do result = result + creepwars_leader_strength[u] end
		return result
	end

	local reference = rnd_array()
	local reference_cost = array_cost(reference)

	local function generate_similar()
		local result
		repeat
			result = rnd_array()
			local cost = array_cost(result)
		until cost > 0.93 * reference_cost and cost < 1.07 * reference_cost
		return result
	end

	return set_all_leaders(generate_similar)
end

if wesnoth.compare_versions(wesnoth.game_config.version, ">=", "1.13.10") then
	print("creepwars_mirror_style is " .. creepwars_mirror_style)
	if creepwars_mirror_style == "manual_no_downgrade" then
		-- done
	elseif creepwars_mirror_style == "manual" then
		downgrade()
	elseif creepwars_mirror_style == "mirror" then
		downgrade()
		force_mirror()
	elseif creepwars_mirror_style == "same_strength" then
		force_same_strength()
	else
		error("Unknown leader mirror style: " .. creepwars_mirror_style)
	end
else
	local all_lvl2 = true
	for _, unit in ipairs(wesnoth.get_units { canrecruit = true }) do
--		if not creepwars_memoize_ai_side_set[unit.side] then
--		end
		all_lvl2 = all_lvl2 and wesnoth.unit_types[unit.type].level > 1
	end

	local era = wesnoth.game_config.era.id
	if all_lvl2 and not string.find(era, "Creep") and not string.find(era, "War") then
		print('Non-"Creep Wars" Era detected, with all leaders being lvl2+. Downgrading all leaders. (In future, we may provide more intelligent options, but for now that\'s all.)')
		wesnoth.message("Creep Wars", 'Non-"Creep Wars" Era detected, with all leaders being lvl2+. Downgrading all leaders. (In future, we may provide more intelligent options, but for now that\'s all.)')
		downgrade_wesnoth112()
	end
end


-- >>
