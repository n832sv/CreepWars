-- << enter_shop

local wesnoth = wesnoth
local creepwars = creepwars
local T = wesnoth.require("lua/helper.lua").set_wml_tag_metatable {}
local ipairs = ipairs
local string = string
local math = math
local show_dialog = creepwars.show_dialog


local event_side
local event_unit


local function err(message)
	wesnoth.synchronize_choice(function()
		wesnoth.show_dialog {
			T.tooltip { id = "tooltip_large" },
			T.helptip { id = "tooltip_large" },
			T.grid {
				T.row { T.column { T.image { label = "misc/red-x.png" } } },
				T.row { T.column { T.label { label = message .. "\n" } } },
				T.row { T.column { T.button { label = "\nOK\n", return_value = -1 } } },
			}
		}
		return {} -- strange obligatory "table" result
	end)
end

local function loop(label)
	return function(options)
		return function()
			repeat
				local label = label .. "\nYour gold: " .. event_side.gold
				local result = show_dialog { label = label, options = options }
				if result.is_ok and options[result.index].func then
					options[result.index].func()
				end
				wesnoth.wml_actions.redraw {}
			until not result.is_ok
		end
	end
end


local function give_effect(cost, id, effect)
	return function ()
		local effect = effect
		if effect[1] == "effect" then effect = { effect } end -- wrap
		if event_side.gold < cost then
			err("Not enough gold")
		else
			event_side.gold = event_side.gold - cost
			if id then
				event_unit.variables["creepwars_" .. id] = event_unit.variables["creepwars_" .. id] + 1
			end
			wesnoth.add_modification(event_unit, "object", effect)
		end
	end
end

local hero_loop = function()
	repeat
		local label = "Hero Upgrade."
		label = label .. "\nYour gold: " .. event_side.gold
		local small_hp = math.floor(5 + event_unit.variables.base_hp * 22 / 100)
		local big_hp = math.floor(14 + event_unit.variables.base_hp * 50 / 100)
		local options = {
			{
				text = "Large Hitpoint Boost +" .. big_hp .. " HP \ncost 50", -- \n(formula 50% orig + 14)
				image = "icons/potion_red_medium.png",
				func = give_effect(50, "health_big", T.effect {
					apply_to = "hitpoints",
					increase = big_hp,
					increase_total = big_hp,
				})
			}, {
				text = "Small Hitpoint Boost +" .. small_hp .. " HP \ncost 22",
				image = "icons/potion_red_small.png",
				func = give_effect(22, "health_small", T.effect {
					apply_to = "hitpoints",
					increase = small_hp,
					increase_total = small_hp,
				})
			}, {
				text = "Movement +1 \ncost 28",
				image = "icons/jewelry_butterfly_pin.png",
				func = give_effect(28, "mp", T.effect {
					apply_to = "movement",
					increase = 1
				})
			}, {
				text = "Melee Damage +1 \ncost 14",
--				image = "items/anvil.png",
				image = "items/flame-sword.png",
				func = give_effect(14, "melee_damage", T.effect {
					apply_to = "attack",
					range = "melee",
					increase_damage = 1
				})
			}, {
				text = "Melee Strikes +1 \ncost 42",
				image = "misc/blank-hex.png~BLIT(items/sword.png~CROP(0,0,60,60),6,2)~BLIT(items/sword.png~CROP(8,2,50,50))",
				func = give_effect(42, "melee_strikes", T.effect {
					apply_to = "attack",
					range = "melee",
					increase_attacks = 1
				})
			}, {
				text = "Ranged Damage +1 \ncost 14",
--				image = "items/archery-target-right.png",
				image = "projectiles/missile-fire-ne.png~FL(vert,horiz)",
				func = give_effect(14, "ranged_damage", T.effect {
					apply_to = "attack",
					range = "ranged",
					increase_damage = 1
				})
			}, {
				text = "Ranged Strikes +1 \ncost 42",
--				image = "items/bow-crystal.png",
				image = "misc/blank-hex.png~BLIT(projectiles/missile-ne.png~CROP(0,0,60,60),6,2)~BLIT(projectiles/missile-ne.png~CROP(6,2,60,60))",
				func = give_effect(42, "ranged_strikes", T.effect {
					apply_to = "attack",
					range = "ranged",
					increase_attacks = 1
				})
			}, {
				text = "Combo Damage +1 \n(discounts per buy)\ncost "
						.. math.max(16, 24 - event_unit.variables.creepwars_damage) .. ", "
						.. math.max(16, 23 - event_unit.variables.creepwars_damage)
						.. ", ..., 16, 16, 16",
				image = "items/dummy.png",
				func = give_effect(math.max(16, 24 - event_unit.variables.creepwars_damage),
					"damage",
					T.effect {
						apply_to = "attack",
						increase_damage = 1
					})
			}, {
				text = "Combo Strikes +1 \n(discounts per buy)\ncost "
						.. math.max(48, 72 - 6 * event_unit.variables.creepwars_strikes) .. ", "
						.. math.max(48, 66 - 6 * event_unit.variables.creepwars_strikes)
						.. ", ..., 48, 48, 48",
				image = "items/bonestack.png",
				func = give_effect(math.max(48, 72 - 6 * event_unit.variables.creepwars_strikes),
					"strikes",
					T.effect {
						apply_to = "attack",
						increase_attacks = 1
					})
			},
		}
		local result = show_dialog { label = label, spacer = "", options = options }
		if result.is_ok and options[result.index].func then options[result.index].func() end
	until not result.is_ok
end


local function weapon_item(settings)
	local effect = settings.effect
	local text = string.format("%s-%s %s\n%s %s %s\ncost %s",
		effect.damage,
		effect.number,
		effect.name,
		effect.range,
		effect.type,
		settings.specials or "",
		settings.gold)
	effect.damage = effect.damage + event_unit.variables.creepwars_damage
	effect.number = effect.number + event_unit.variables.creepwars_strikes
	if effect.range == "melee" then
		effect.damage = effect.damage + event_unit.variables.creepwars_melee_damage
		effect.number = effect.number + event_unit.variables.creepwars_melee_strikes
	else
		effect.damage = effect.damage + event_unit.variables.creepwars_ranged_damage
		effect.number = effect.number + event_unit.variables.creepwars_ranged_strikes
	end
	return {
		text = text,
		image = effect.icon,
		func = give_effect(settings.gold, nil, T.effect(effect))
	}
end

local weapon_loop = function()
	repeat
		local label = "Weapon Upgrade."
		label = label .. "\nYour gold: " .. event_side.gold
		local options = {
			weapon_item {
				gold = 34,
				specials = "backstab",
				effect = {
					apply_to = "new_attack",
					name = "dagger",
					type = "blade",
					icon = "attacks/dagger-human.png",
					range = "melee",
					damage = 9,
					number = 1,
					T.specials {
						wesnoth.macros.WEAPON_SPECIAL_BACKSTAB
					}
				}
			},
			weapon_item {
				gold = 34,
				effect = {
					apply_to = "new_attack",
					name = "short sword",
					type = "blade",
					icon = "attacks/sword-human-short.png",
					range = "melee",
					damage = 6,
					number = 3,
				}
			},
			weapon_item {
				gold = 40,
				effect = {
					apply_to = "new_attack",
					name = "holy sword",
					type = "arcane",
					icon = "attacks/sword-holy.png",
					range = "melee",
					damage = 6,
					number = 3,
				}
			},
			weapon_item {
				gold = 34,
				effect = {
					apply_to = "new_attack",
					name = "mace",
					type = "impact",
					icon = "attacks/mace.png",
					range = "melee",
					damage = 9,
					number = 2,
				}
			},
			weapon_item {
				gold = 40,
				effect = {
					apply_to = "new_attack",
					name = "torch",
					type = "fire",
					icon = "attacks/torch.png",
					range = "melee",
					damage = 6,
					number = 3
				}
			},
			--			{
			--				text = "spear + javelin",
			--				image = "attacks/spear.png",
			--			},
			weapon_item {
				gold = 40,
				effect = {
					apply_to = "new_attack",
					name = "thunderstick",
					type = "pierce",
					icon = "attacks/thunderstick.png",
					range = "ranged",
					damage = 15,
					number = 1
				}
			},
			weapon_item {
				gold = 28,
				effect = {
					apply_to = "new_attack",
					name = "bow",
					type = "pierce",
					icon = "attacks/bow.png",
					range = "ranged",
					damage = 5,
					number = 3
				}
			},
--			{
--				text = "crossbow",
--				image = "attacks/crossbow-human.png",
--			},
			weapon_item {
				gold = 36,
				specials = "marksman",
				effect = {
					apply_to = "new_attack",
					name = "longbow",
					type = "pierce",
					icon = "attacks/bow-elven-magic.png",
					range = "ranged",
					damage = 6,
					number = 3,
					T.specials {
						wesnoth.macros.WEAPON_SPECIAL_MARKSMAN
					}
				}
			},
			weapon_item {
				gold = 72,
				specials = "slows",
				effect = {
					apply_to = "new_attack",
					name = "net",
					type = "impact",
					icon = "attacks/net.png",
					range = "ranged",
					damage = 4,
					number = 2,
					T.specials {
						wesnoth.macros.WEAPON_SPECIAL_SLOW
					}
				}
			},
			weapon_item {
				gold = 56,
				specials = "poison",
				effect = {
					apply_to = "new_attack",
					name = "poisoned knife",
					type = "blade",
					icon = "attacks/dagger-thrown-poison-human.png",
					range = "ranged",
					damage = 4,
					number = 2,
					T.specials {
						wesnoth.macros.WEAPON_SPECIAL_POISON
					}
				}
			},
			weapon_item {
				gold = 40,
				specials = "magical",
				effect = {
					apply_to = "new_attack",
					name = "fireball",
					type = "fire",
					icon = "attacks/fireball.png",
					range = "ranged",
					damage = 6,
					number = 2,
					T.specials {
						wesnoth.macros.WEAPON_SPECIAL_MAGICAL
					}
				}
			},
			weapon_item {
				gold = 40,
				specials = "magical",
				effect = {
					apply_to = "new_attack",
					name = "chill wave",
					type = "cold",
					icon = "attacks/iceball.png",
					range = "ranged",
					damage = 7,
					number = 2,
					T.specials {
						wesnoth.macros.WEAPON_SPECIAL_MAGICAL
					}
				}
			},
		}
		local result = show_dialog { label = label, spacer = "", options = options }
		if result.is_ok and options[result.index].func then options[result.index].func() end
	until not result.is_ok
end


local function armor_item(gold, id, name, image, a, b, c, f, i, p)
	name = name .. string.format("\narcane %+d, blade %+d, cold %+d, fire %+d, impact %+d, pierce %+d", a, b, c, f, i, p)
	name = name .. "\ncost " .. gold
	local total_armor = event_unit.variables.creepwars_armor_ldc +
			event_unit.variables.creepwars_armor_hdc +
			event_unit.variables.creepwars_armor_hhc +
			event_unit.variables.creepwars_armor_smr
	local total_boots = event_unit.variables.creepwars_armor_eb +
			event_unit.variables.creepwars_armor_pg
	local robe_conflict = total_armor > 0 and (id == "ldc" or id == "hdc" or id == "hhc" or id == "smr")
	local boots_conflict = total_boots > 0 and (id == "eb" or id == "pg")
	local give_effect_func = give_effect(gold, "armor_" .. id, T.effect {
			apply_to = "resistance", T.resistance {
				arcane = -a,
				blade = -b,
				cold = -c,
				fire = -f,
				impact = -i,
				pierce = -p,
			}
		})
	local func = function()
		if robe_conflict or boots_conflict then
			err("Too many items of same type")
		else
			give_effect_func()
		end
	end

	return {
		text = name,
		image = image,
		func = func
	}
end

local armor_loop = function()
	repeat
		local label = "Armor is a cheaper alternative to Resistances, \nbut it affects many resistances at once.\n"
		label = label .. "\nYour gold: " .. event_side.gold .. "\n"
		local options = {
			armor_item(100, "hhc", "Heavy Human Cuirass", "icons/breastplate.png",
				0, 35, -10, -10, 20, 35),
			armor_item(115, "ldc", "Light Dwarven Cuirass", "icons/cuirass_leather_studded.png",
				0, 20, 10, 10, 20, 20),
			armor_item(150, "hdc", "Heavy Dwarven Cuirass", "icons/cuirass_muscled.png",
				3, 27, 12, 12, 23, 23),
			armor_item(150, "smr", "Silver Mage Robe", "icons/cloak_leather_brown.png",
				20, 0, 40, 40, 0, 0),
			armor_item(70, "eb", "Elven Boots", "icons/boots_elven.png",
				0, 8, 8, 8, 8, 8),
			armor_item(25, "pg", "Plate Greaves", "icons/greaves.png",
				0, 8, 0, -10, 8, 8),
		}
		local result = show_dialog { label = label, spacer = "", options = options }
		if result.is_ok and options[result.index].func then options[result.index].func() end
		wesnoth.wml_actions.redraw {}
	until not result.is_ok
end


local function resistance_item(sum, weap)
	local have = event_unit.variables["creepwars_res_" .. weap]
	local func = function()
		if sum >= 10 then
			err("Too many resistances bought")
		elseif wesnoth.sides[wesnoth.current.side].gold < 22 then
			err("Not enough gold (need 22)")
		else
			event_side.gold = event_side.gold - 22
			event_unit.variables["creepwars_res_" .. weap] = have + 1
			wesnoth.add_modification(event_unit, "object", {
				T.effect { apply_to = "resistance", T.resistance { [weap] = -10 } },
			})
		end
	end
	local have_string = have > 0 and " (" .. have .. ")" or ""
	return {
		text = "+10% " .. string.gsub(weap, "^%l", string.upper) .. " Resistance" .. have_string .. ". Cost 22.",
		func = func
	}
end

local resistance_loop = function()
	repeat
		local sum = event_unit.variables.creepwars_res_arcane +
				event_unit.variables.creepwars_res_blade +
				event_unit.variables.creepwars_res_cold +
				event_unit.variables.creepwars_res_fire +
				event_unit.variables.creepwars_res_impact +
				event_unit.variables.creepwars_res_pierce
		local label = "Resistance. \nAvailable:" .. 10 - sum .. "/10\n"
		label = label .. "(Hower unit HP on the right to see current resistances)\n"
		label = label .. "\nYour gold: " .. event_side.gold
		local options = {
			resistance_item(sum, "arcane"),
			resistance_item(sum, "blade"),
			resistance_item(sum, "cold"),
			resistance_item(sum, "fire"),
			resistance_item(sum, "impact"),
			resistance_item(sum, "pierce"),
		}
		local result = show_dialog { label = label, options = options }
		if result.is_ok and options[result.index].func then options[result.index].func() end
		wesnoth.wml_actions.redraw {}
	until not result.is_ok
end


local heal_guard_cost = 5
local heal_guards = function()
	local this_turn = wesnoth.current.turn .. "," .. wesnoth.current.side
	local variable_name = "creepwars_last_heal"
	if event_side.gold < heal_guard_cost then
		err("Not enough gold")
	elseif wesnoth.get_variable(variable_name) == this_turn then
		err("Can only heal once per turn")
	else
		local healed = false
		for _, unit in ipairs(wesnoth.get_units { ability = "creepwars_guard" }) do
			if unit.hitpoints < unit.max_hitpoints then
				healed = true
				unit.hitpoints = math.min(unit.hitpoints + unit.max_hitpoints / 5, unit.max_hitpoints)
				break
			end
		end
		if healed then
			event_side.gold = event_side.gold - heal_guard_cost
			wesnoth.set_variable(variable_name, this_turn)
		else
			err("Cannot heal: all guards healthy.")
		end
		wesnoth.wml_actions.redraw {}
	end
end

local unpoison_guard_cost = 10
local unpoison_guards = function()
	if event_side.gold < unpoison_guard_cost then
		err("Not enough gold")
	else
		local cured = false
		for _, unit in ipairs(wesnoth.get_units { ability = "creepwars_guard" }) do
			if unit.status.poisoned then
				cured = true
				unit.status.poisoned = false
				break
			end
		end
		if cured then
			event_side.gold = event_side.gold - unpoison_guard_cost
			wesnoth.wml_actions.redraw {}
		else
			err("No poisoned guards found")
		end
	end
end

local guard_loop = loop("Guard.") {
	{
		text = "Heal most damaged guard 20% HP \ncost " .. heal_guard_cost,
		image = "icons/potion_red_small.png",
		func = heal_guards
	},
	{
		text = "Unpoison guard \ncost " .. unpoison_guard_cost,
		image = "icons/potion_green_small.png",
		func = unpoison_guards
	},
}


local shop_loop = loop("Shop.") {
	{
		text = "Upgrade Hero",
		image = "icons/potion_red_small.png",
		func = hero_loop
	}, {
		text = "Buy Weapons",
		image = "icons/crossed_sword_and_hammer.png",
		func = weapon_loop
	}, {
		text = "Buy Armor",
		image = "icons/cuirass_muscled.png",
		func = armor_loop
	}, {
		text = "Buy Resistance",
--		image = "items/ornate1.png",
		image = "icons/ring_gold.png",
		func = resistance_loop
	}, {
		text = "Heal Guard",
		image = "units/human-loyalists/lieutenant.png",
		func = guard_loop
	},
}


local function enter_shop()
	local x1 = wesnoth.get_variable("x1") or 0
	local y1 = wesnoth.get_variable("y1") or 0
	print("visiting shop")
	event_unit = wesnoth.get_unit(x1, y1) or wesnoth.get_units { side = 1 }[1]
	print("unit", event_unit)
	event_side = wesnoth.sides[wesnoth.current.side]

	shop_loop()
	creepwars.set_leader_ability()
end

creepwars.enter_shop = enter_shop

-- >>