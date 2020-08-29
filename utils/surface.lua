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
    water = 0.5,
    modded = false
}

Global.register(
    global_data,
    function(tbl)
        global_data = tbl
    end
)

function Public.create_surface(modded)
    local map_gen_settings
    if modded then
        map_gen_settings = {
            ['seed'] = math.random(10000, 99999),
            ['water'] = 0.001,
            ['starting_area'] = 2,
            ['cliff_settings'] = {cliff_elevation_interval = 0, cliff_elevation_0 = 0},
            ['default_enable_all_autoplace_controls'] = true,
            ['autoplace_settings'] = {
                ['entity'] = {treat_missing_as_default = true},
                ['tile'] = {treat_missing_as_default = true},
                ['decorative'] = {treat_missing_as_default = true}
            },
            property_expression_names = {
                cliffiness = 0,
                ['tile:water:probability'] = -10000,
                ['tile:deep-water:probability'] = -10000
            }
        }
        map_gen_settings.autoplace_controls = game.surfaces.nauvis.map_gen_settings.autoplace_controls
        for k, v in pairs(map_gen_settings.autoplace_controls) do
            v.size = 3
            v.richness = 3
        end
    else
        map_gen_settings = {}
        map_gen_settings.water = global_data.water
        map_gen_settings.starting_area = 0.5
        map_gen_settings.seed = math.random(10000, 99999)
        --map_gen_settings.width = 128
        --map_gen_settings.height = 128
        map_gen_settings.cliff_settings = {cliff_elevation_interval = 35, cliff_elevation_0 = 35}
        map_gen_settings.autoplace_controls = {
            ['coal'] = {frequency = 0.33, size = 1, richness = 1},
            ['stone'] = {frequency = 0.33, size = 1, richness = 1},
            ['copper-ore'] = {frequency = 0.33, size = 1, richness = 1},
            ['iron-ore'] = {frequency = 0.33, size = 1, richness = 1},
            ['crude-oil'] = {frequency = 0.33, size = 1, richness = 1},
            ['uranium-ore'] = {frequency = 0.33, size = 1, richness = 1},
            ['trees'] = {frequency = 1, size = 1, richness = 1},
            ['enemy-base'] = {frequency = 0.33, size = 0.33, richness = 1}
        }
    end
    local mine = {}
    mine['control-setting:moisture:bias'] = 0.33
    mine['control-setting:moisture:frequency:multiplier'] = 1

    map_gen_settings.property_expression_names = mine

    if (global_data.island) then
        map_gen_settings.property_expression_names.elevation = '0_17-island'
    end

    if not global_data.surface then
        global_data.surface = game.create_surface(wbtc_surface_name, map_gen_settings).index
    end

    local surface = game.surfaces[global_data.surface]

    surface.request_to_generate_chunks({0, 0}, 2)
    surface.force_generate_chunk_requests()

    local _y = surface.find_non_colliding_position('character-corpse', {0, -22}, 2, 2)
    surface.create_entity({name = 'character-corpse', position = _y})

    local y = surface.find_non_colliding_position('character-corpse', {0, 22}, 2, 2)
    surface.create_entity({name = 'character-corpse', position = y})

    --game.forces.player.technologies["landfill"].enabled = false
    --game.forces.player.technologies["optics"].researched = true
    game.forces.player.set_spawn_position({0, 0}, surface)
    global_data.spawn_position = {0, 0}

    surface.ticks_per_day = surface.ticks_per_day * 2
    surface.min_brightness = 0.08
    --surface.daytime = 0.7
end

local function on_init()
    local mgs = game.surfaces['nauvis'].map_gen_settings
    mgs.width = 16
    mgs.height = 16
    game.surfaces['nauvis'].map_gen_settings = mgs
    game.surfaces['nauvis'].clear()
    if global_data.modded then
        Public.create_surface(true)
    else
        Public.create_surface(false)
    end
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

function Public.set_modded(value)
    if value then
        global_data.modded = true
    else
        global_data.modded = false
    end
    return global_data.modded
end

function Public.set_island(var)
    global_data.island = var
end

function Public.get()
    return global_data
end

Event.on_init(on_init)

Event.add(
    defines.events.on_player_created,
    function(event)
        local player = game.players[event.player_index]
        Validate(player)

        -- Move the player to the game surface immediately.
        local pos =
            game.surfaces[global_data.surface_name].find_non_colliding_position('character', {x = 0, y = 0}, 3, 0, 5)
        player.teleport(pos, global_data.surface_name)
    end
)

return Public
