require 'util'
local Global = require 'utils.global'
local Event = require 'utils.event'
local Public = {}

local global_data = {
    surface = nil,
    spawn_position = nil,
    island = false,
    surface_name = 'wbtc',
    water = 0.5,
    modded = false
}

Global.register(
    global_data,
    function(tbl)
        global_data = tbl
    end
)

local function is_game_modded()
    local i = 0
    for k, _ in pairs(game.active_mods) do
        i = i + 1
        if i > 1 then
            return true
        end
    end
    return false
end

function Public.create_surface()
    local map_gen_settings
    local is_modded = is_game_modded()
    if is_modded then
        --surface.daytime = 0.7
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
            if k ~= 'trees' then
                v.size = 10
                v.richness = 10
            end
        end
        local mine = {}
        mine['control-setting:moisture:bias'] = 0.33
        mine['control-setting:moisture:frequency:multiplier'] = 1

        map_gen_settings.property_expression_names = mine

        if (global_data.island) then
            map_gen_settings.property_expression_names.elevation = '0_17-island'
        end

        if not global_data.surface then
            global_data.surface = game.surfaces.nauvis.index
            global_data.surface_name = 'nauvis'
            global_data.modded = true
        end

        local surface = game.surfaces[global_data.surface]

        surface.map_gen_settings = map_gen_settings

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
    else
        --surface.daytime = 0.7
        map_gen_settings = {}
        map_gen_settings.water = global_data.water
        map_gen_settings.starting_area = 2
        map_gen_settings.seed = math.random(10000, 99999)
        --map_gen_settings.width = 128
        --map_gen_settings.height = 128
        map_gen_settings.cliff_settings = {cliff_elevation_interval = 35, cliff_elevation_0 = 35}
        map_gen_settings.autoplace_controls = {
            ['coal'] = {frequency = 1, size = 2, richness = 2},
            ['stone'] = {frequency = 1, size = 2, richness = 2},
            ['copper-ore'] = {frequency = 1, size = 2, richness = 2},
            ['iron-ore'] = {frequency = 1, size = 2, richness = 2},
            ['crude-oil'] = {frequency = 1, size = 2, richness = 2},
            ['uranium-ore'] = {frequency = 1, size = 2, richness = 2},
            ['trees'] = {frequency = 0.88, size = 0.64, richness = 1},
            ['enemy-base'] = {frequency = 1, size = 1, richness = 1}
        }
        local mine = {}
        mine['control-setting:moisture:bias'] = 0.07
        mine['control-setting:moisture:frequency:multiplier'] = 1

        map_gen_settings.property_expression_names = mine

        if (global_data.island) then
            map_gen_settings.property_expression_names.elevation = '0_17-island'
        end

        if not global_data.surface then
            global_data.surface = game.create_surface(global_data.surface_name, map_gen_settings).index
        end

        local surface = game.surfaces[global_data.surface]

        surface.request_to_generate_chunks({0, 0}, 2)
        surface.force_generate_chunk_requests()

        --game.forces.player.technologies["landfill"].enabled = false
        --game.forces.player.technologies["optics"].researched = true
        game.forces.player.set_spawn_position({0, 0}, surface)
        global_data.spawn_position = {0, 0}

        surface.ticks_per_day = surface.ticks_per_day * 2
        surface.min_brightness = 0.08
    end
end

local function on_init()
    if is_game_modded() then
        global_data.surface_name = 'nauvis'
        global_data.modded = true
        Public.create_surface()
        return
    end
    local mgs = game.surfaces['nauvis'].map_gen_settings
    mgs.width = 16
    mgs.height = 16
    game.surfaces['nauvis'].map_gen_settings = mgs
    game.surfaces['nauvis'].clear()
    Public.create_surface()
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

        if is_game_modded() and not global_data.init then
            global_data.surface_name = 'nauvis'
            global_data.modded = true
            global_data.init = true
        end

        -- Move the player to the game surface immediately.
        local pos = game.surfaces[global_data.surface_name].find_non_colliding_position('character', {x = 0, y = 0}, 3, 0, 5)
        player.teleport(pos, global_data.surface_name)

        if global_data.modded then
            if player.online_time == 0 then
                player.insert({name = 'pistol', count = 1})
                player.insert({name = 'firearm-magazine', count = 16})
                player.insert({name = 'iron-plate', count = 64})
                player.insert({name = 'burner-mining-drill', count = 4})
                player.insert({name = 'stone-furnace', count = 4})
            end
        end
    end
)

return Public
