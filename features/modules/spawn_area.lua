local Event = require 'utils.event'
local Surface = require 'utils.surface'

local Public = {}
local random = math.random

local tile_positions = {
    {-3, -2},
    {-3, -1},
    {-3, 0},
    {-3, 1},
    {-3, 2},
    {3, -2},
    {3, -1},
    {3, 0},
    {3, 1},
    {3, 2},
    {-2, -3},
    {-1, -3},
    {0, -3},
    {1, -3},
    {2, -3},
    {-2, 3},
    {-1, 3},
    {0, 3},
    {1, 3},
    {2, 3}
}

local place_blocks = {
    {'small-lamp', -3, -2},
    {'small-lamp', -3, 2},
    {'small-lamp', 3, -2},
    {'small-lamp', 3, 2},
    {'small-lamp', -2, -3},
    {'small-lamp', 2, -3},
    {'small-lamp', -2, 3},
    {'small-lamp', 2, 3},
    {'small-electric-pole', -3, -3},
    {'small-electric-pole', 3, 3},
    {'small-electric-pole', -3, 3},
    {'small-electric-pole', 3, -3},
    {'blue-chest', -2, -6},
    {'blue-chest', -2, -5},
    {'blue-chest', 2, -6},
    {'blue-chest', 2, -5},
    {'blue-chest', 2, 5},
    {'blue-chest', 2, 6},
    {'blue-chest', -2, 5},
    {'blue-chest', -2, 6},
    {'solar-panel', -5, -5},
    {'solar-panel', 5, -5},
    {'solar-panel', 5, 5},
    {'solar-panel', -5, 5},
    {'accumulator', 5, -2},
    {'accumulator', 5, 3},
    {'accumulator', -4, -2},
    {'accumulator', -4, 3}
}

local global_offset = {x = 0, y = 0}
local decon_radius = 15
local p_radius = 20
local p_tile = 'stone-path'
local concrete_tiles = {
    'refined-concrete',
    'black-refined-concrete',
    'acid-refined-concrete',
    'blue-refined-concrete',
    'brown-refined-concrete',
    'cyan-refined-concrete',
    'green-refined-concrete',
    'orange-refined-concrete',
    'red-refined-concrete',
    'yellow-refined-concrete'
}

local function generate_random_tile()
    local tile = concrete_tiles[random(1, #concrete_tiles)]
    return tile
end

function Public.spawn_on_chunk_generated()
    local get_surface = Surface.get_surface()
    local surface = game.surfaces[get_surface]
    local offset = {x = -0, y = 0}
    local base_tiles = {}
    local tiles = {}
    local tile = false
    if not tile then
        tile = generate_random_tile()
    end
    for x = -p_radius - 5, p_radius + 5 do
        for y = -p_radius - 5, p_radius + 5 do
            if x ^ 2 + y ^ 2 < decon_radius ^ 2 then
                base_tiles[#base_tiles + 1] = {name = tile, position = {x + offset.x, y + offset.y}}
                if not global.custom_spawn then
                    local entities =
                        surface.find_entities_filtered {
                        area = {{x + offset.x - 1, y + offset.y - 1}, {x + offset.x, y + offset.y}}
                    }
                    for _, entity in pairs(entities) do
                        if entity.name ~= 'character' then
                            entity.destroy()
                        end
                    end
                end
            end
        end
    end
    surface.set_tiles(base_tiles)
    for _, position in pairs(tile_positions) do
        table.insert(
            tiles,
            {
                name = p_tile,
                position = {position[1] + offset.x + global_offset.x, position[2] + offset.y + global_offset.y}
            }
        )
    end
    surface.set_tiles(tiles)
    for _, name in pairs(place_blocks) do
        local entity =
            surface.create_entity {
            name = name[1],
            position = {name[2] + offset.x + global_offset.x, name[3] + offset.y + global_offset.y},
            force = 'neutral'
        }
        entity.destructible = false
        entity.health = 0
        entity.minable = false
        entity.rotatable = false
        if entity.energy then
            entity.energy = 100000000
        end
    end
end
Event.add(
    defines.events.on_player_created,
    function(event)
        if event.player_index == 1 then
            Public.spawn_on_chunk_generated(event)
        end
    end
)

return Public
