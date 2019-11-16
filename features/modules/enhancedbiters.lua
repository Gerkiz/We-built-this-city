-- Enhanced Biters, a mod for more dangerous biters
-- Factorio module by Mylon, 2018
-- MIT License

local event = require "utils.event"


global.zombies = {}
global.capsules = {}

local ENHANCED_SCALE = 1 --1 means 50% turret damage after 24h.  2 means 12h.

local Public = {}

--Unique behaviors
function Public.splitters(event)
	if not global.zombies then
		global.zombies = {}
	end
	if event.entity.force.name ~= "enemy" then
		return
	end

	if event.entity.name == "behemoth-spitter" and math.random(1,10) == 10 then
		event.entity.surface.create_entity{name="big-worm-turret", position=event.entity.position}
	end
	if event.entity.name == "big-worm-turret" and math.random() < 0.25 then
		for i=0, 5, 1 do
			local pos = event.entity.surface.find_non_colliding_position("medium-biter", event.entity.position, 10, 3)
			event.entity.surface.create_entity{name="medium-worm-turret", position=pos}
		end
	end
	if event.entity.name == "medium-worm-turret" and math.random(1,2) == 2 then
		for i=0, 5, 1 do
			local pos = event.entity.surface.find_non_colliding_position("medium-biter", event.entity.position, 10, 2)
			event.entity.surface.create_entity{name="small-worm-turret", position=pos}
		end
	end
	if event.entity.name == "medium-biter" and math.random() < 0.5 then
		table.insert(global.zombies, {tick=game.tick, position=event.entity.position, surface=event.entity.surface})
	end
	if event.entity.name == "big-spitter" and math.random() < 0.2 then
		if event.cause and event.cause.valid then
			local capsule = event.entity.surface.create_entity{name="acid-splash-fire-worm-big", position=event.entity.position, speed=0.5, target=event.cause}
			table.insert(global.capsules, {entity = capsule, target=event.cause, type="medium-biter", count=2})
		end
	end
end

function Public.delayed_spawn()
	if not global.zombies then
		global.zombies = {}
	end
	for i = #global.zombies, 1, -1 do
		local zombie = global.zombies[i]
		if game.tick > zombie.tick + (60*60*2) then
			local spawnPoint = zombie.surface.find_non_colliding_position("medium-biter", zombie.position, 10, 3)
			if spawnPoint then
				zombie.surface.create_entity{name="medium-biter", position=zombie.position}
			end
			table.remove(global.zombies, i)
		end
	end
	for i = #global.capsules, 1, -1 do
		local capsule = global.capsules[i]
		if not (capsule.entity and capsule.entity.valid) then --Projectile found its mark.
			--game.print("Popping Capsule")
			for n = 1, capsule.count do
				if capsule.target and capsule.target.valid then
					local spawnPoint = capsule.target.surface.find_non_colliding_position("small-biter", capsule.target.position, 10, 2)
					if spawnPoint then
						capsule.target.surface.create_entity{name=capsule.type, position=spawnPoint}
					end
				end
			end
			table.remove(global.capsules, i)
		end
	end
end

function Public.tech_nerf(event)
	local force = event.force
	local scale = 5184000 / ENHANCED_SCALE
	local factor = scale / (scale + game.tick) --Decrease by 50% per 12h.
	local turret_types = {"gun-turret", "laser-turret", "flamethrower-turret", "flamethrower-turret", "artillery-turret"} --Flamethrower turret is in here twice intentionally.  🔥 OP
	for k,v in pairs(turret_types) do
		force.set_turret_attack_modifier(v, (force.get_turret_attack_modifier(v) + 1) * factor - 1)
	end
	--For extra fun, let's buff biters.
	game.forces.enemy.set_ammo_damage_modifier("melee", 0.5 + (2 * scale + game.tick) / (2 * scale) )
end

event.add(defines.events.on_entity_died, Public.splitters)
event.add(defines.events.on_tick, Public.delayed_spawn)

return Public