local Info = require 'features.modules.towny.info'
local Team = require 'features.modules.towny.team'
local TownyTable = require 'features.modules.towny.table'

local Public = {}

local math_random = math.random
local table_insert = table.insert
local math_floor = math.floor

local town_radius = 27
local ore_amount = 1200

local colors = {}
local c1 = 250
local c2 = 210
local c3 = -40
for v = c1, c2, c3 do
    table.insert(colors, {0, 0, v})
end
for v = c1, c2, c3 do
    table.insert(colors, {0, v, 0})
end
for v = c1, c2, c3 do
    table.insert(colors, {v, 0, 0})
end
for v = c1, c2, c3 do
    table.insert(colors, {0, v, v})
end
for v = c1, c2, c3 do
    table.insert(colors, {v, v, 0})
end
for v = c1, c2, c3 do
    table.insert(colors, {v, 0, v})
end

local town_wall_vectors = {}
for x = 2, town_radius, 1 do
    table_insert(town_wall_vectors, {x, town_radius})
    table_insert(town_wall_vectors, {x * -1, town_radius})
    table_insert(town_wall_vectors, {x, town_radius * -1})
    table_insert(town_wall_vectors, {x * -1, town_radius * -1})
end
for y = 2, town_radius - 1, 1 do
    table_insert(town_wall_vectors, {town_radius, y})
    table_insert(town_wall_vectors, {town_radius, y * -1})
    table_insert(town_wall_vectors, {town_radius * -1, y})
    table_insert(town_wall_vectors, {town_radius * -1, y * -1})
end

local gate_vectors_horizontal = {}
for x = -1, 1, 1 do
    table_insert(gate_vectors_horizontal, {x, town_radius})
    table_insert(gate_vectors_horizontal, {x, town_radius * -1})
end
local gate_vectors_vertical = {}
for y = -1, 1, 1 do
    table_insert(gate_vectors_vertical, {town_radius, y})
    table_insert(gate_vectors_vertical, {town_radius * -1, y})
end

local resource_vectors = {}
resource_vectors[1] = {}
for x = 7, 24, 1 do
    for y = 7, 24, 1 do
        table_insert(resource_vectors[1], {x, y})
    end
end
resource_vectors[2] = {}
for _, vector in pairs(resource_vectors[1]) do
    table_insert(resource_vectors[2], {vector[1] * -1, vector[2]})
end
resource_vectors[3] = {}
for _, vector in pairs(resource_vectors[1]) do
    table_insert(resource_vectors[3], {vector[1] * -1, vector[2] * -1})
end
resource_vectors[4] = {}
for _, vector in pairs(resource_vectors[1]) do
    table_insert(resource_vectors[4], {vector[1], vector[2] * -1})
end

local additional_resource_vectors = {}
additional_resource_vectors[1] = {}
for x = 10, 22, 1 do
    for y = -4, 4, 1 do
        table_insert(additional_resource_vectors[1], {x, y})
    end
end
additional_resource_vectors[2] = {}
for _, vector in pairs(additional_resource_vectors[1]) do
    table_insert(additional_resource_vectors[2], {vector[1] * -1, vector[2]})
end
additional_resource_vectors[3] = {}
for y = 10, 22, 1 do
    for x = -4, 4, 1 do
        table_insert(additional_resource_vectors[3], {x, y})
    end
end
additional_resource_vectors[4] = {}
for _, vector in pairs(additional_resource_vectors[3]) do
    table_insert(additional_resource_vectors[4], {vector[1], vector[2] * -1})
end

local clear_blacklist_types = {
    ['simple-entity'] = true,
    ['resource'] = true,
    ['cliff'] = true
}

local starter_supplies = {
    {name = 'raw-fish', count = 3},
    {name = 'grenade', count = 3},
    {name = 'stone', count = 32},
    {name = 'land-mine', count = 4},
    {name = 'iron-gear-wheel', count = 16},
    {name = 'iron-plate', count = 32},
    {name = 'copper-plate', count = 16},
    {name = 'shotgun', count = 1},
    {name = 'shotgun-shell', count = 8},
    {name = 'firearm-magazine', count = 16},
    {name = 'firearm-magazine', count = 16},
    {name = 'gun-turret', count = 2}
}

local function count_nearby_ore(surface, position, ore_name)
    local count = 0
    local r = town_radius + 8
    for _, e in pairs(surface.find_entities_filtered({area = {{position.x - r, position.y - r}, {position.x + r, position.y + r}}, force = 'neutral', name = ore_name})) do
        count = count + e.amount
    end
    return count
end

local function get_replacement_tile(surface, position)
    for i = 1, 128, 1 do
        local vectors = {{0, i}, {0, i * -1}, {i, 0}, {i * -1, 0}}
        table.shuffle_table(vectors)
        for k, v in pairs(vectors) do
            local tile = surface.get_tile(position.x + v[1], position.y + v[2])
            if not tile.collides_with('resource-layer') then
                if tile.name ~= 'stone-path' then
                    return tile.name
                end
            end
        end
    end
    return 'grass-1'
end

local function draw_town_spawn(player_name, mock, set_force)
    local towny = TownyTable.get('towny')
    local market
    if not mock then
        market = towny.town_centers[player_name].market
    else
        market = towny.town_centers_placeholders[player_name].market
        player_name = set_force
    end
    local position = market.position
    local surface = market.surface

    local area = {{position.x - (town_radius + 1), position.y - (town_radius + 1)}, {position.x + (town_radius + 1), position.y + (town_radius + 1)}}

    for _, t in pairs(surface.find_tiles_filtered({area = area, name = {'water', 'deepwater'}})) do
        surface.set_tiles({{name = get_replacement_tile(surface, t.position), position = t.position}})
    end

    for _, e in pairs(surface.find_entities_filtered({area = area, force = 'neutral'})) do
        if not clear_blacklist_types[e.type] then
            e.destroy()
        end
    end

    for _, vector in pairs(gate_vectors_horizontal) do
        local p = {position.x + vector[1], position.y + vector[2]}
        p = surface.find_non_colliding_position('gate', p, 64, 1)
        if p then
            surface.create_entity({name = 'gate', position = p, force = player_name, direction = 2})
        end
    end
    for _, vector in pairs(gate_vectors_vertical) do
        local p = {position.x + vector[1], position.y + vector[2]}
        p = surface.find_non_colliding_position('gate', p, 64, 1)
        if p then
            surface.create_entity({name = 'gate', position = p, force = player_name, direction = 0})
        end
    end

    for _, vector in pairs(town_wall_vectors) do
        local p = {position.x + vector[1], position.y + vector[2]}
        p = surface.find_non_colliding_position('stone-wall', p, 64, 1)
        if p then
            surface.create_entity({name = 'stone-wall', position = p, force = player_name})
        end
    end

    local ores = {'iron-ore', 'copper-ore', 'stone', 'coal'}
    table.shuffle_table(ores)

    for i = 1, 4, 1 do
        if count_nearby_ore(surface, position, ores[i]) < 200000 then
            for _, vector in pairs(resource_vectors[i]) do
                local p = {position.x + vector[1], position.y + vector[2]}
                p = surface.find_non_colliding_position(ores[i], p, 64, 1)
                if p then
                    surface.create_entity({name = ores[i], position = p, amount = ore_amount})
                end
            end
        end
    end

    for _, item_stack in pairs(starter_supplies) do
        local m1 = -8 + math_random(0, 16)
        local m2 = -8 + math_random(0, 16)
        local p = {position.x + m1, position.y + m2}
        p = surface.find_non_colliding_position('wooden-chest', p, 64, 1)
        if p then
            local e = surface.create_entity({name = 'wooden-chest', position = p, force = player_name})
            local inventory = e.get_inventory(defines.inventory.chest)
            inventory.insert(item_stack)
        end
    end

    local vector_indexes = {1, 2, 3, 4}
    table.shuffle_table(vector_indexes)

    local tree = 'tree-0' .. math_random(1, 9)
    for _, vector in pairs(additional_resource_vectors[vector_indexes[1]]) do
        if math_random(1, 6) == 1 then
            local p = {position.x + vector[1], position.y + vector[2]}
            p = surface.find_non_colliding_position(tree, p, 64, 1)
            if p then
                surface.create_entity({name = tree, position = p})
            end
        end
    end

    local area = {{position.x - town_radius * 1.5, position.y - town_radius * 1.5}, {position.x + town_radius * 1.5, position.y + town_radius * 1.5}}
    if surface.count_tiles_filtered({name = {'water', 'deepwater'}, area = area}) < 8 then
        for _, vector in pairs(additional_resource_vectors[vector_indexes[2]]) do
            local p = {position.x + vector[1], position.y + vector[2]}
            if surface.get_tile(p).name ~= 'out-of-map' then
                surface.set_tiles({{name = 'water', position = p}})
            end
        end
    end
    if count_nearby_ore(surface, position, 'uranium-ore') < 100000 then
        for _, vector in pairs(additional_resource_vectors[vector_indexes[3]]) do
            local p = {position.x + vector[1], position.y + vector[2]}
            p = surface.find_non_colliding_position('uranium-ore', p, 64, 1)
            if p then
                surface.create_entity({name = 'uranium-ore', position = p, amount = ore_amount * 2})
            end
        end
    end
    local vectors = additional_resource_vectors[vector_indexes[4]]
    for _ = 1, 3, 1 do
        local vector = vectors[math_random(1, #vectors)]
        local p = {position.x + vector[1], position.y + vector[2]}
        p = surface.find_non_colliding_position('crude-oil', p, 64, 1)
        if p then
            surface.create_entity({name = 'crude-oil', position = p, amount = 500000})
        end
    end
end

function Public.set_market_health(entity, final_damage_amount, player)
    local towny = TownyTable.get('towny')
    local town_center = towny.town_centers[entity.force.name]
    if not town_center then
        town_center = towny.town_centers_placeholders[entity.force.name]
        if not town_center then
            if player and player.valid then
                town_center = towny.town_centers_placeholders[player.name]
                if not town_center then
                    return
                end
            else
                return
            end
        end
    end

    town_center.health = math_floor(town_center.health - final_damage_amount)
    if town_center.health > town_center.max_health then
        town_center.health = town_center.max_health
    end
    local m = town_center.health / town_center.max_health
    entity.health = 150 * m
    rendering.set_text(town_center.health_text, 'HP: ' .. town_center.health .. ' / ' .. town_center.max_health)
end

local function is_color_used(color, town_centers)
    for k, center in pairs(town_centers) do
        if center.color then
            if center.color.r == color.r and center.color.g == color.g and center.color.b == color.b then
                return true
            end
        end
    end
end

local function get_color()
    local towny = TownyTable.get('towny')
    local town_centers = towny.town_centers
    local c

    local shuffle_index = {}
    for i = 1, #colors, 1 do
        shuffle_index[i] = i
    end
    table.shuffle_table(shuffle_index)

    for i = 1, #colors, 1 do
        c = {r = colors[shuffle_index[i]][1], g = colors[shuffle_index[i]][2], b = colors[shuffle_index[i]][3]}
        if not is_color_used(c, town_centers) then
            return c
        end
    end

    return c
end

function Public.add_new_force(force_name)
    local force = game.forces[force_name]
    if not force then
        force = game.create_force(force_name)
    end
    force.research_queue_enabled = true
    force.share_chart = true
    force.technologies['atomic-bomb'].enabled = false
    force.technologies['explosive-rocketry'].enabled = false
    force.technologies['rocketry'].enabled = false
    force.technologies['artillery-shell-range-1'].enabled = false
    force.technologies['artillery-shell-speed-1'].enabled = false
    force.set_ammo_damage_modifier('landmine', -0.6)
    force.set_ammo_damage_modifier('artillery-shell', -0.75)
end

function Public.create_new_town(surface, player, position, mock, own_team, just_market)
    if not player then
        return
    end

    local player_name = tostring(player.name)

    local towny = TownyTable.get('towny')

    if towny.town_centers[player_name] then
        return
    end
    if not mock then
        Info.toggle_button(player)
    end
    Public.add_new_force(player_name)

    local town_center

    if not mock then
        towny.town_centers[player_name] = {}
        town_center = towny.town_centers[player_name]
        town_center.market = surface.create_entity({name = 'market', position = position, force = player_name})
        town_center.chunk_position = {math.floor(town_center.market.position.x / 32), math.floor(town_center.market.position.y / 32)}
        town_center.max_health = 1000
        town_center.health = town_center.max_health
        town_center.color = get_color()
        town_center.research_counter = 1
        town_center.upgrades = {}
        town_center.upgrades.mining_prod = 0

        game.print('>> ' .. player.name .. ' has founded a new town!', {255, 255, 0})
        if not just_market then
            draw_town_spawn(player_name)
        end
        towny.size_of_town_centers = towny.size_of_town_centers + 1
        town_center.town_caption =
            rendering.draw_text {
            text = player.name .. "'s Town (PVP)",
            surface = surface,
            target = town_center.market,
            target_offset = {0, -3.25},
            color = town_center.color,
            scale = 1.30,
            font = 'default-game',
            alignment = 'center',
            scale_with_zoom = false
        }
    else
        towny.town_centers_placeholders[player_name] = {}
        town_center = towny.town_centers_placeholders[player_name]
        local set_force = global.main_force_name
        if own_team then
            set_force = player_name
        end
        town_center.market = surface.create_entity({name = 'market', position = position, force = set_force})
        town_center.market.active = false
        town_center.chunk_position = {math.floor(position.x / 32), math.floor(position.y / 32)}
        town_center.position = position
        town_center.max_health = 1000
        town_center.health = town_center.max_health
        town_center.color = get_color()
        town_center.force = set_force
        town_center.surface = surface
        town_center.research_counter = 1
        town_center.upgrades = {}
        town_center.upgrades.mining_prod = 0
        if not just_market then
            draw_town_spawn(player_name, true, set_force)
        end
        towny.size_of_placeholders_towns = towny.size_of_placeholders_towns + 1
        game.print('>> ' .. player.name .. ' has founded a new town!', {255, 255, 0})
        town_center.town_caption =
            rendering.draw_text {
            text = player.name .. "'s Town (NON-PVP)",
            surface = surface,
            target = town_center.market,
            target_offset = {0, -3.25},
            color = town_center.color,
            scale = 1.30,
            font = 'default-game',
            alignment = 'center',
            scale_with_zoom = false
        }
    end

    Team.add_chart_tag(game.forces[global.main_force_name], town_center.market)

    town_center.health_text =
        rendering.draw_text {
        text = 'HP: ' .. town_center.health .. ' / ' .. town_center.max_health,
        surface = surface,
        target = town_center.market,
        target_offset = {0, -2.5},
        color = {200, 200, 200},
        scale = 1.00,
        font = 'default-game',
        alignment = 'center',
        scale_with_zoom = false
    }

    return true
end

return Public
