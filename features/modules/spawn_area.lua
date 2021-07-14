local Event = require 'utils.event'
local Surface = require 'utils.surface'
local Token = require 'utils.token'
local Task = require 'utils.task'
local market_items = require 'features.modules.map_market_items'
local Global = require 'utils.global'

local this = {
    enable_market = true
}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

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
local spawn_radius = 20
local p_radius = 20
local p_tile = 'stone-path'
local concrete_tiles = {
    'refined-concrete',
    'acid-refined-concrete',
    'blue-refined-concrete',
    'brown-refined-concrete',
    'cyan-refined-concrete',
    'green-refined-concrete',
    'orange-refined-concrete',
    'red-refined-concrete',
    'yellow-refined-concrete'
}

local function shuffle(tbl)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = math.random(size)
        tbl[i], tbl[rand] = tbl[rand], tbl[i]
    end
    return tbl
end

local function generate_random_tile()
    local tile = concrete_tiles[random(1, #concrete_tiles)]
    return tile
end

local function is_spawn(position)
    if math.abs(position.x) > 32 then
        return false
    end
    if math.abs(position.y) > 32 then
        return false
    end
    local p = {x = position.x, y = position.y}
    if p.x > 0 then
        p.x = p.x + 1
    end
    if p.y > 0 then
        p.y = p.y + 1
    end
    local d = math.sqrt(p.x ^ 2 + p.y ^ 2)
    if d < 32 then
        return true
    end
end

local spawn_market_token =
    Token.register(
    function()
        if not this.enable_market then
            return
        end

        local get_surface = Surface.get_surface()
        local surface = game.surfaces[get_surface]
        local pos = {{x = -10, y = -10}, {x = 10, y = 10}, {x = -10, y = -10}, {x = 10, y = -10}}
        local _pos = shuffle(pos)
        local p = surface.find_non_colliding_position('market', {_pos[1].x, _pos[1].y}, 60, 2)

        this.market = surface.create_entity {name = 'market', position = p, force = this.main_force_name}

        rendering.draw_text {
            text = 'Spawn Market',
            surface = surface,
            target = this.market,
            target_offset = {0, 2},
            color = {r = 0.98, g = 0.66, b = 0.22},
            alignment = 'center'
        }

        this.market.destructible = false

        for _, item in pairs(market_items.spawn) do
            this.market.add_market_item(item)
        end
    end
)

local spawn_on_chunk_generated_token =
    Token.register(
    function()
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
                if x ^ 2 + y ^ 2 < spawn_radius ^ 2 then
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

        local positions = {}
        for x = -p_radius - 5, p_radius + 5 do
            for y = -p_radius - 5, p_radius + 5 do
                if x ^ 2 + y ^ 2 < spawn_radius ^ 2 then
                    local position = {x = x, y = y}
                    if is_spawn(position) then
                        table.insert(positions, position)
                    end
                end
            end
        end

        table.shuffle_table(positions)

        for _, position in pairs(positions) do
            if surface.count_tiles_filtered({area = {{position.x - 1, position.y - 1}, {position.x + 2, position.y + 2}}, name = 'black-refined-concrete'}) < 4 then
                surface.set_tiles({{name = 'black-refined-concrete', position = position}}, true)
            end
        end

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
)

Event.add(
    defines.events.on_player_created,
    function(event)
        if event.player_index == 1 then
            Task.set_timeout_in_ticks(10, spawn_on_chunk_generated_token)
            Task.set_timeout_in_ticks(15, spawn_market_token)
        end
    end
)

return Public
