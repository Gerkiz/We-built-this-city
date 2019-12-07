	require 'util'
local Global = require 'utils.global'
local Event = require 'utils.event'
local Validate = require 'utils.validate_player'
local wbtc_surface_name = 'wbtc'

local Public = {}

local global_data = {
    surface = nil,
    spawn_position = nil,
    island = false,
    surface_name = wbtc_surface_name,
    water = 0.5
}

Global.register(
    global_data,
    function(tbl)
        global_data = tbl
    end
)

function Public.create_surface()
	local map_gen_settings = {}
	map_gen_settings.water = global_data.water
	map_gen_settings.starting_area = 0.5
	map_gen_settings.cliff_settings = {cliff_elevation_interval = 35, cliff_elevation_0 = 35}
	map_gen_settings.autoplace_controls = {
		["coal"] = {frequency = 0.33, size = 1, richness = 1},
		["stone"] = {frequency = 0.33, size = 1, richness = 1},
		["copper-ore"] = {frequency = 0.33, size = 1, richness = 1},
		["iron-ore"] = {frequency = 0.33, size = 1, richness = 1},
		["crude-oil"] = {frequency = 0.33, size = 1, richness = 1},
		["uranium-ore"] = {frequency = 0.33, size = 1, richness = 1},
		["trees"] = {frequency = 1, size = 1, richness = 1},
		["enemy-base"] = {frequency = 0.33, size = 0.33, richness = 1}
	}

	if (global_data.island) then
	    map_gen_settings.property_expression_names.elevation = "0_17-island"
	end

	if not global_data.surface then
		global_data.surface = game.create_surface(wbtc_surface_name, map_gen_settings).index
	end

	local surface = game.surfaces[global_data.surface]

	surface.request_to_generate_chunks({0,0}, 8)
	surface.force_generate_chunk_requests()

	local _y = surface.find_non_colliding_position("character-corpse", {0,-22}, 2, 2)
	surface.create_entity({name = "character-corpse", position = _y})

	local y = surface.find_non_colliding_position("character-corpse", {0,22}, 2, 2)
	surface.create_entity({name = "character-corpse", position = y})

	--game.forces.player.technologies["landfill"].enabled = false
	--game.forces.player.technologies["optics"].researched = true
	game.forces.player.set_spawn_position({0, 0}, surface)
	global_data.spawn_position = {0, 0}

	surface.ticks_per_day = surface.ticks_per_day * 2
	surface.min_brightness = 0.08
	--surface.daytime = 0.7
end

function Public.get_surface()
    return global_data.surface
end

function Public.get_surface_name()
    return global_data.surface_name
end

function Public.set_spawn_pos(var)
    global_data.spawn_position = var
end

function Public.set_island(var)
    global_data.island = var
end

function Public.get()
    return global_data
end

Event.on_init(Public.create_surface)

Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    Validate(player)

    -- Move the player to the game surface immediately.
    local pos = game.surfaces[global_data.surface_name].find_non_colliding_position("character", {x=0,y=0}, 3, 0,5)
    player.teleport(pos, global_data.surface_name)

end)

return Public