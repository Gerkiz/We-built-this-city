--junkyard-- mewmew made this --
-- modified by Gerkiz --

local Map = require 'features.modules.map_info'
require 'features.functions.on_tick_schedule'
require 'features.modules.dynamic_landfill'
--require "features.modules.satellite_score"
require 'features.modules.mineable_wreckage_yields_scrap'
require 'features.modules.rocks_heal_over_time'
require 'features.modules.spawners_contain_biters'
require 'features.modules.biters_yield_coins'
--require "maps.modules.fluids_are_explosive"
--require "maps.modules.explosives_are_explosive"
--require "features.modules.dangerous_nights"

local unearthing_worm = require 'features.functions.unearthing_worm'
local unearthing_biters = require 'features.functions.unearthing_biters'
local tick_tack_trap = require 'features.functions.tick_tack_trap'
local create_entity_chain = require 'features.functions.create_entity_chain'
local create_tile_chain = require 'features.functions.create_tile_chain'

local simplex_noise = require 'utils.simplex_noise'
simplex_noise = simplex_noise.d2
local Event = require 'utils.event'
local table_insert = table.insert
local math_random = math.random
local map_functions = require 'features.tools.map_functions'

local insert = table.insert

local disabled_for_deconstruction = {
    ['fish'] = true,
    ['rock-huge'] = true,
    ['rock-big'] = true,
    ['sand-rock-big'] = true,
    ['mineable-wreckage'] = true
}

local tile_replacements = {
    ['grass-1'] = 'dirt-7',
    ['grass-2'] = 'dirt-6',
    ['grass-3'] = 'dirt-5',
    ['grass-4'] = 'dirt-4',
    ['water'] = 'water-green',
    ['deepwater'] = 'deepwater-green',
    ['sand-1'] = 'dirt-7',
    ['sand-2'] = 'dirt-6',
    ['sand-3'] = 'dirt-5'
}

local entity_replacements = {
    ['tree-01'] = 'dead-grey-trunk',
    ['tree-02'] = 'tree-06-brown',
    ['tree-03'] = 'dead-grey-trunk',
    ['tree-04'] = 'dry-hairy-tree',
    ['tree-05'] = 'dead-grey-trunk',
    ['tree-06'] = 'tree-06-brown',
    ['tree-07'] = 'dry-hairy-tree',
    ['tree-08'] = 'dead-grey-trunk',
    ['tree-09'] = 'tree-06-brown',
    ['tree-02-red'] = 'dry-tree',
    --["tree-06-brown"] = "dirt",
    ['tree-08-brown'] = 'tree-06-brown',
    ['tree-09-brown'] = 'tree-06-brown',
    ['tree-09-red'] = 'tree-06-brown',
    ['iron-ore'] = 'mineable-wreckage',
    ['copper-ore'] = 'mineable-wreckage',
    ['coal'] = 'mineable-wreckage',
    ['stone'] = 'mineable-wreckage'
}

local wrecks = {'big-ship-wreck-1', 'big-ship-wreck-2', 'big-ship-wreck-3'}

local scrap_buildings = {
    'nuclear-reactor',
    'centrifuge',
    'beacon',
    'chemical-plant',
    'assembling-machine-1',
    'assembling-machine-2',
    'assembling-machine-3',
    'oil-refinery',
    'arithmetic-combinator',
    'constant-combinator',
    'decider-combinator',
    'programmable-speaker',
    'steam-turbine',
    'steam-engine',
    'chemical-plant',
    'assembling-machine-1',
    'assembling-machine-2',
    'assembling-machine-3',
    'oil-refinery',
    'arithmetic-combinator',
    'constant-combinator',
    'decider-combinator',
    'programmable-speaker',
    'steam-turbine',
    'steam-engine'
}

local function shuffle(tbl)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = math_random(size)
        tbl[i], tbl[rand] = tbl[rand], tbl[i]
    end
    return tbl
end

local function get_noise(name, pos)
    local seed = game.surfaces[1].map_gen_settings.seed
    local noise_seed_add = 25000
    seed = seed
    if name == 1 then
        local noise = {}
        noise[1] = simplex_noise(pos.x * 0.005, pos.y * 0.005, seed)
        seed = seed + noise_seed_add
        noise[2] = simplex_noise(pos.x * 0.01, pos.y * 0.01, seed)
        seed = seed + noise_seed_add
        noise[3] = simplex_noise(pos.x * 0.05, pos.y * 0.05, seed)
        seed = seed + noise_seed_add
        noise[4] = simplex_noise(pos.x * 0.1, pos.y * 0.1, seed)
        local noise = noise[1] + noise[2] * 0.35 + noise[3] * 0.23 + noise[4] * 0.11
        return noise
    end
end

local function create_shipwreck(surface, position)
    local raffle = {}
    local loot = {
        --{{name = "steel-axe", count = math_random(1,3)}, weight = 2, evolution_min = 0.0, evolution_max = 0.5},
        {{name = 'submachine-gun', count = math_random(1, 3)}, weight = 3, evolution_min = 0.0, evolution_max = 0.1},
        {{name = 'slowdown-capsule', count = math_random(16, 32)}, weight = 1, evolution_min = 0.3, evolution_max = 0.7},
        {{name = 'poison-capsule', count = math_random(16, 32)}, weight = 3, evolution_min = 0.3, evolution_max = 1},
        {
            {name = 'uranium-cannon-shell', count = math_random(16, 32)},
            weight = 5,
            evolution_min = 0.6,
            evolution_max = 1
        },
        {{name = 'cannon-shell', count = math_random(16, 32)}, weight = 5, evolution_min = 0.4, evolution_max = 0.7},
        {
            {name = 'explosive-uranium-cannon-shell', count = math_random(16, 32)},
            weight = 5,
            evolution_min = 0.6,
            evolution_max = 1
        },
        {
            {name = 'explosive-cannon-shell', count = math_random(16, 32)},
            weight = 5,
            evolution_min = 0.4,
            evolution_max = 0.8
        },
        {{name = 'shotgun', count = 1}, weight = 2, evolution_min = 0.0, evolution_max = 0.2},
        {{name = 'shotgun-shell', count = math_random(16, 32)}, weight = 5, evolution_min = 0.0, evolution_max = 0.2},
        {{name = 'combat-shotgun', count = 1}, weight = 3, evolution_min = 0.3, evolution_max = 0.8},
        {
            {name = 'piercing-shotgun-shell', count = math_random(16, 32)},
            weight = 10,
            evolution_min = 0.2,
            evolution_max = 1
        },
        {{name = 'flamethrower', count = 1}, weight = 3, evolution_min = 0.3, evolution_max = 0.6},
        {{name = 'flamethrower-ammo', count = math_random(16, 32)}, weight = 5, evolution_min = 0.3, evolution_max = 1},
        {{name = 'rocket-launcher', count = 1}, weight = 3, evolution_min = 0.2, evolution_max = 0.6},
        {{name = 'rocket', count = math_random(16, 32)}, weight = 5, evolution_min = 0.2, evolution_max = 0.7},
        {{name = 'explosive-rocket', count = math_random(16, 32)}, weight = 5, evolution_min = 0.3, evolution_max = 1},
        {{name = 'land-mine', count = math_random(16, 32)}, weight = 5, evolution_min = 0.2, evolution_max = 0.7},
        {{name = 'grenade', count = math_random(16, 32)}, weight = 5, evolution_min = 0.0, evolution_max = 0.5},
        {{name = 'cluster-grenade', count = math_random(16, 32)}, weight = 5, evolution_min = 0.4, evolution_max = 1},
        {{name = 'firearm-magazine', count = math_random(32, 128)}, weight = 5, evolution_min = 0, evolution_max = 0.3},
        {
            {name = 'piercing-rounds-magazine', count = math_random(32, 128)},
            weight = 5,
            evolution_min = 0.1,
            evolution_max = 0.8
        },
        {
            {name = 'uranium-rounds-magazine', count = math_random(32, 128)},
            weight = 5,
            evolution_min = 0.5,
            evolution_max = 1
        },
        {{name = 'railgun', count = 1}, weight = 1, evolution_min = 0.2, evolution_max = 1},
        {{name = 'railgun-dart', count = math_random(16, 32)}, weight = 3, evolution_min = 0.2, evolution_max = 0.7},
        {{name = 'defender-capsule', count = math_random(8, 16)}, weight = 2, evolution_min = 0.0, evolution_max = 0.7},
        {{name = 'distractor-capsule', count = math_random(8, 16)}, weight = 2, evolution_min = 0.2, evolution_max = 1},
        {{name = 'destroyer-capsule', count = math_random(8, 16)}, weight = 2, evolution_min = 0.3, evolution_max = 1},
        --{{name = "atomic-bomb", count = math_random(8,16)}, weight = 1, evolution_min = 0.3, evolution_max = 1},
        {{name = 'light-armor', count = 1}, weight = 3, evolution_min = 0, evolution_max = 0.1},
        {{name = 'heavy-armor', count = 1}, weight = 3, evolution_min = 0.1, evolution_max = 0.3},
        {{name = 'modular-armor', count = 1}, weight = 2, evolution_min = 0.2, evolution_max = 0.6},
        {{name = 'power-armor', count = 1}, weight = 2, evolution_min = 0.4, evolution_max = 1},
        --{{name = "power-armor-mk2", count = 1}, weight = 1, evolution_min = 0.9, evolution_max = 1},
        {{name = 'battery-equipment', count = 1}, weight = 2, evolution_min = 0.3, evolution_max = 0.7},
        {{name = 'battery-mk2-equipment', count = 1}, weight = 2, evolution_min = 0.6, evolution_max = 1},
        {{name = 'belt-immunity-equipment', count = 1}, weight = 1, evolution_min = 0.3, evolution_max = 1},
        --{{name = "solar-panel-equipment", count = math_random(1,4)}, weight = 5, evolution_min = 0.3, evolution_max = 0.8},
        {{name = 'discharge-defense-equipment', count = 1}, weight = 1, evolution_min = 0.5, evolution_max = 0.8},
        {
            {name = 'energy-shield-equipment', count = math_random(1, 2)},
            weight = 2,
            evolution_min = 0.3,
            evolution_max = 0.8
        },
        {{name = 'energy-shield-mk2-equipment', count = 1}, weight = 2, evolution_min = 0.7, evolution_max = 1},
        {{name = 'exoskeleton-equipment', count = 1}, weight = 1, evolution_min = 0.3, evolution_max = 1},
        {{name = 'fusion-reactor-equipment', count = 1}, weight = 1, evolution_min = 0.5, evolution_max = 1},
        --{{name = "night-vision-equipment", count = 1}, weight = 1, evolution_min = 0.3, evolution_max = 0.8},
        {{name = 'personal-laser-defense-equipment', count = 1}, weight = 2, evolution_min = 0.5, evolution_max = 1},
        {{name = 'exoskeleton-equipment', count = 1}, weight = 1, evolution_min = 0.3, evolution_max = 1},
        {{name = 'iron-gear-wheel', count = math_random(80, 100)}, weight = 3, evolution_min = 0.0, evolution_max = 0.3},
        {{name = 'copper-cable', count = math_random(100, 200)}, weight = 3, evolution_min = 0.0, evolution_max = 0.3},
        {{name = 'engine-unit', count = math_random(16, 32)}, weight = 2, evolution_min = 0.1, evolution_max = 0.5},
        {
            {name = 'electric-engine-unit', count = math_random(16, 32)},
            weight = 2,
            evolution_min = 0.4,
            evolution_max = 0.8
        },
        {{name = 'battery', count = math_random(50, 150)}, weight = 2, evolution_min = 0.3, evolution_max = 0.8},
        {{name = 'advanced-circuit', count = math_random(50, 150)}, weight = 3, evolution_min = 0.4, evolution_max = 1},
        {
            {name = 'electronic-circuit', count = math_random(50, 150)},
            weight = 3,
            evolution_min = 0.0,
            evolution_max = 0.4
        },
        {{name = 'processing-unit', count = math_random(50, 150)}, weight = 3, evolution_min = 0.7, evolution_max = 1},
        {{name = 'explosives', count = math_random(40, 50)}, weight = 10, evolution_min = 0.0, evolution_max = 1},
        {{name = 'lubricant-barrel', count = math_random(4, 10)}, weight = 1, evolution_min = 0.3, evolution_max = 0.5},
        {{name = 'rocket-fuel', count = math_random(4, 10)}, weight = 2, evolution_min = 0.3, evolution_max = 0.7},
        --{{name = "computer", count = 1}, weight = 2, evolution_min = 0, evolution_max = 1},
        {{name = 'steel-plate', count = math_random(25, 75)}, weight = 2, evolution_min = 0.1, evolution_max = 0.3},
        {{name = 'nuclear-fuel', count = 1}, weight = 2, evolution_min = 0.7, evolution_max = 1},
        {{name = 'burner-inserter', count = math_random(8, 16)}, weight = 3, evolution_min = 0.0, evolution_max = 0.1},
        {{name = 'inserter', count = math_random(8, 16)}, weight = 3, evolution_min = 0.0, evolution_max = 0.4},
        {
            {name = 'long-handed-inserter', count = math_random(8, 16)},
            weight = 3,
            evolution_min = 0.0,
            evolution_max = 0.4
        },
        {{name = 'fast-inserter', count = math_random(8, 16)}, weight = 3, evolution_min = 0.1, evolution_max = 1},
        {{name = 'filter-inserter', count = math_random(8, 16)}, weight = 1, evolution_min = 0.2, evolution_max = 1},
        {
            {name = 'stack-filter-inserter', count = math_random(4, 8)},
            weight = 1,
            evolution_min = 0.4,
            evolution_max = 1
        },
        {{name = 'stack-inserter', count = math_random(4, 8)}, weight = 3, evolution_min = 0.3, evolution_max = 1},
        {
            {name = 'small-electric-pole', count = math_random(16, 24)},
            weight = 3,
            evolution_min = 0.0,
            evolution_max = 0.3
        },
        {
            {name = 'medium-electric-pole', count = math_random(8, 16)},
            weight = 3,
            evolution_min = 0.2,
            evolution_max = 1
        },
        {{name = 'big-electric-pole', count = math_random(4, 8)}, weight = 3, evolution_min = 0.3, evolution_max = 1},
        {{name = 'substation', count = math_random(2, 4)}, weight = 3, evolution_min = 0.5, evolution_max = 1},
        {{name = 'wooden-chest', count = math_random(16, 24)}, weight = 3, evolution_min = 0.0, evolution_max = 0.2},
        {{name = 'iron-chest', count = math_random(4, 8)}, weight = 3, evolution_min = 0.1, evolution_max = 0.4},
        {{name = 'steel-chest', count = math_random(4, 8)}, weight = 3, evolution_min = 0.3, evolution_max = 1},
        {{name = 'small-lamp', count = math_random(16, 32)}, weight = 3, evolution_min = 0.1, evolution_max = 0.3},
        {{name = 'rail', count = math_random(25, 75)}, weight = 3, evolution_min = 0.1, evolution_max = 0.6},
        {
            {name = 'assembling-machine-1', count = math_random(2, 4)},
            weight = 3,
            evolution_min = 0.0,
            evolution_max = 0.3
        },
        {
            {name = 'assembling-machine-2', count = math_random(2, 4)},
            weight = 3,
            evolution_min = 0.2,
            evolution_max = 0.8
        },
        {{name = 'assembling-machine-3', count = math_random(1, 2)}, weight = 3, evolution_min = 0.5, evolution_max = 1},
        {{name = 'accumulator', count = math_random(4, 8)}, weight = 3, evolution_min = 0.4, evolution_max = 1},
        {{name = 'offshore-pump', count = math_random(1, 3)}, weight = 2, evolution_min = 0.0, evolution_max = 0.1},
        {{name = 'beacon', count = math_random(1, 2)}, weight = 3, evolution_min = 0.7, evolution_max = 1},
        {{name = 'boiler', count = math_random(4, 8)}, weight = 3, evolution_min = 0.0, evolution_max = 0.3},
        {{name = 'steam-engine', count = math_random(2, 4)}, weight = 3, evolution_min = 0.0, evolution_max = 0.5},
        {{name = 'steam-turbine', count = math_random(1, 2)}, weight = 2, evolution_min = 0.6, evolution_max = 1},
        --{{name = "nuclear-reactor", count = 1}, weight = 1, evolution_min = 0.6, evolution_max = 1},
        {{name = 'centrifuge', count = math_random(1, 2)}, weight = 1, evolution_min = 0.6, evolution_max = 1},
        {{name = 'heat-pipe', count = math_random(4, 8)}, weight = 2, evolution_min = 0.5, evolution_max = 1},
        {{name = 'heat-exchanger', count = math_random(2, 4)}, weight = 2, evolution_min = 0.5, evolution_max = 1},
        {
            {name = 'arithmetic-combinator', count = math_random(8, 16)},
            weight = 1,
            evolution_min = 0.1,
            evolution_max = 1
        },
        {{name = 'constant-combinator', count = math_random(8, 16)}, weight = 1, evolution_min = 0.1, evolution_max = 1},
        {{name = 'decider-combinator', count = math_random(8, 16)}, weight = 1, evolution_min = 0.1, evolution_max = 1},
        {{name = 'power-switch', count = math_random(1, 2)}, weight = 1, evolution_min = 0.1, evolution_max = 1},
        {{name = 'programmable-speaker', count = math_random(4, 8)}, weight = 1, evolution_min = 0.1, evolution_max = 1},
        {{name = 'green-wire', count = math_random(50, 99)}, weight = 1, evolution_min = 0.1, evolution_max = 1},
        {{name = 'red-wire', count = math_random(50, 99)}, weight = 1, evolution_min = 0.1, evolution_max = 1},
        {{name = 'chemical-plant', count = math_random(1, 3)}, weight = 3, evolution_min = 0.3, evolution_max = 1},
        {
            {name = 'burner-mining-drill', count = math_random(2, 4)},
            weight = 3,
            evolution_min = 0.0,
            evolution_max = 0.2
        },
        {
            {name = 'electric-mining-drill', count = math_random(2, 4)},
            weight = 3,
            evolution_min = 0.2,
            evolution_max = 0.6
        },
        {
            {name = 'express-transport-belt', count = math_random(25, 75)},
            weight = 3,
            evolution_min = 0.5,
            evolution_max = 1
        },
        {
            {name = 'express-underground-belt', count = math_random(4, 8)},
            weight = 3,
            evolution_min = 0.5,
            evolution_max = 1
        },
        {{name = 'express-splitter', count = math_random(2, 4)}, weight = 3, evolution_min = 0.5, evolution_max = 1},
        {
            {name = 'fast-transport-belt', count = math_random(25, 75)},
            weight = 3,
            evolution_min = 0.2,
            evolution_max = 0.7
        },
        {
            {name = 'fast-underground-belt', count = math_random(4, 8)},
            weight = 3,
            evolution_min = 0.2,
            evolution_max = 0.7
        },
        {{name = 'fast-splitter', count = math_random(2, 4)}, weight = 3, evolution_min = 0.2, evolution_max = 0.3},
        {{name = 'transport-belt', count = math_random(25, 75)}, weight = 3, evolution_min = 0, evolution_max = 0.3},
        {{name = 'underground-belt', count = math_random(4, 8)}, weight = 3, evolution_min = 0, evolution_max = 0.3},
        {{name = 'splitter', count = math_random(2, 4)}, weight = 3, evolution_min = 0, evolution_max = 0.3},
        --{{name = "oil-refinery", count = math_random(2,4)}, weight = 2, evolution_min = 0.3, evolution_max = 1},
        --{{name = "pipe", count = math_random(30,50)}, weight = 3, evolution_min = 0.0, evolution_max = 0.3},
        {{name = 'pipe-to-ground', count = math_random(4, 8)}, weight = 1, evolution_min = 0.2, evolution_max = 0.5},
        {{name = 'pumpjack', count = math_random(1, 3)}, weight = 1, evolution_min = 0.3, evolution_max = 0.8},
        {{name = 'pump', count = math_random(1, 2)}, weight = 1, evolution_min = 0.3, evolution_max = 0.8},
        --{{name = "solar-panel", count = math_random(8,16)}, weight = 3, evolution_min = 0.4, evolution_max = 0.9},
        {{name = 'electric-furnace', count = math_random(2, 4)}, weight = 3, evolution_min = 0.5, evolution_max = 1},
        {{name = 'steel-furnace', count = math_random(4, 8)}, weight = 3, evolution_min = 0.2, evolution_max = 0.7},
        {{name = 'stone-furnace', count = math_random(8, 16)}, weight = 3, evolution_min = 0.0, evolution_max = 0.1},
        {{name = 'radar', count = math_random(1, 2)}, weight = 1, evolution_min = 0.1, evolution_max = 0.3},
        {{name = 'rail-signal', count = math_random(8, 16)}, weight = 2, evolution_min = 0.2, evolution_max = 0.8},
        {{name = 'rail-chain-signal', count = math_random(8, 16)}, weight = 2, evolution_min = 0.2, evolution_max = 0.8},
        {{name = 'stone-wall', count = math_random(25, 75)}, weight = 1, evolution_min = 0.1, evolution_max = 0.5},
        {{name = 'gate', count = math_random(4, 8)}, weight = 1, evolution_min = 0.1, evolution_max = 0.5},
        {{name = 'storage-tank', count = math_random(1, 4)}, weight = 3, evolution_min = 0.3, evolution_max = 0.6},
        {{name = 'train-stop', count = math_random(1, 2)}, weight = 1, evolution_min = 0.2, evolution_max = 0.7},
        --{{name = "express-loader", count = math_random(1,3)}, weight = 1, evolution_min = 0.5, evolution_max = 1},
        --{{name = "fast-loader", count = math_random(1,3)}, weight = 1, evolution_min = 0.2, evolution_max = 0.7},
        --{{name = "loader", count = math_random(1,3)}, weight = 1, evolution_min = 0.0, evolution_max = 0.5},
        {{name = 'lab', count = math_random(1, 2)}, weight = 2, evolution_min = 0.0, evolution_max = 0.1},
        --{{name = "roboport", count = math_random(2,4)}, weight = 2, evolution_min = 0.6, evolution_max = 1},
        --{{name = "flamethrower-turret", count = math_random(1,3)}, weight = 3, evolution_min = 0.5, evolution_max = 1},
        --{{name = "laser-turret", count = math_random(4,8)}, weight = 3, evolution_min = 0.5, evolution_max = 1},
        {{name = 'gun-turret', count = math_random(2, 6)}, weight = 3, evolution_min = 0.2, evolution_max = 0.9}
    }

    local distance_to_center = math.sqrt(position.x ^ 2 + position.y ^ 2)
    if distance_to_center < 1 then
        distance_to_center = 0.1
    else
        distance_to_center = distance_to_center / 2500
    end
    if distance_to_center > 1 then
        distance_to_center = 1
    end

    for _, t in pairs(loot) do
        for x = 1, t.weight, 1 do
            if t.evolution_min <= distance_to_center and t.evolution_max >= distance_to_center then
                table.insert(raffle, t[1])
            end
        end
    end
    local e = surface.create_entity {name = wrecks[math_random(1, #wrecks)], position = position, force = 'scrap'}
    for x = 1, math_random(2, 3), 1 do
        local loot = raffle[math_random(1, #raffle)]
        e.insert(loot)
    end
end

local function secret_shop(pos, surface)
    local secret_market_items = {
        {price = {{'coin', math_random(30, 60)}}, offer = {type = 'give-item', item = 'construction-robot'}},
        {price = {{'coin', math_random(100, 200)}}, offer = {type = 'give-item', item = 'loader'}},
        {price = {{'coin', math_random(200, 300)}}, offer = {type = 'give-item', item = 'fast-loader'}},
        {price = {{'coin', math_random(300, 500)}}, offer = {type = 'give-item', item = 'express-loader'}},
        {price = {{'coin', math_random(100, 200)}}, offer = {type = 'give-item', item = 'locomotive'}},
        {price = {{'coin', math_random(75, 150)}}, offer = {type = 'give-item', item = 'cargo-wagon'}},
        {price = {{'coin', math_random(2, 3)}}, offer = {type = 'give-item', item = 'rail'}},
        {price = {{'coin', math_random(4, 12)}}, offer = {type = 'give-item', item = 'small-lamp'}},
        {price = {{'coin', math_random(80, 160)}}, offer = {type = 'give-item', item = 'car'}},
        {price = {{'coin', math_random(300, 600)}}, offer = {type = 'give-item', item = 'electric-furnace'}},
        {price = {{'coin', math_random(80, 160)}}, offer = {type = 'give-item', item = 'effectivity-module'}},
        {price = {{'coin', math_random(80, 160)}}, offer = {type = 'give-item', item = 'productivity-module'}},
        {price = {{'coin', math_random(80, 160)}}, offer = {type = 'give-item', item = 'speed-module'}},
        {price = {{'coin', math_random(5, 10)}}, offer = {type = 'give-item', item = 'wood', count = 50}},
        {price = {{'coin', math_random(5, 10)}}, offer = {type = 'give-item', item = 'iron-ore', count = 50}},
        {price = {{'coin', math_random(5, 10)}}, offer = {type = 'give-item', item = 'copper-ore', count = 50}},
        {price = {{'coin', math_random(5, 10)}}, offer = {type = 'give-item', item = 'stone', count = 50}},
        {price = {{'coin', math_random(5, 10)}}, offer = {type = 'give-item', item = 'coal', count = 50}},
        {price = {{'coin', math_random(8, 16)}}, offer = {type = 'give-item', item = 'uranium-ore', count = 50}},
        {price = {{'wood', math_random(10, 12)}}, offer = {type = 'give-item', item = 'coin'}},
        {price = {{'iron-ore', math_random(10, 12)}}, offer = {type = 'give-item', item = 'coin'}},
        {price = {{'copper-ore', math_random(10, 12)}}, offer = {type = 'give-item', item = 'coin'}},
        {price = {{'stone', math_random(10, 12)}}, offer = {type = 'give-item', item = 'coin'}},
        {price = {{'coal', math_random(10, 12)}}, offer = {type = 'give-item', item = 'coin'}},
        {price = {{'uranium-ore', math_random(8, 10)}}, offer = {type = 'give-item', item = 'coin'}}
    }
    secret_market_items = shuffle(secret_market_items)

    local market = surface.create_entity {name = 'market', position = pos}
    market.destructible = false

    for i = 1, math.random(6, 8), 1 do
        market.add_market_item(secret_market_items[i])
    end
end

local function place_random_scrap_entity(surface, position)
    local r = math.random(1, 100)
    if r < 15 then
        local e =
            surface.create_entity(
            {name = scrap_buildings[math.random(1, #scrap_buildings)], position = position, force = 'scrap'}
        )
        e.destructible = false
        e.active = false
        return
    end
    if r < 25 then
        local e = surface.create_entity({name = 'substation', position = position, force = 'scrap'})
        e.destructible = false
        e.active = false
        return
    end
    if r < 70 then
        local e = surface.create_entity({name = 'medium-electric-pole', position = position, force = 'scrap'})
        e.destructible = false
        e.active = false
        return
    end
    if r < 30 then
        local e = surface.create_entity({name = 'gun-turret', position = position, force = 'scrap_defense'})
        e.insert({name = 'firearm-magazine', count = math.random(64, 128)})
        return
    end

    local e =
        surface.create_entity(
        {name = 'storage-tank', position = position, force = 'scrap', direction = math.random(0, 3)}
    )
    e.destructible = false
    local fluids = {'crude-oil', 'lubricant', 'heavy-oil', 'light-oil', 'petroleum-gas', 'sulfuric-acid', 'water'}
    e.fluidbox[1] = {name = fluids[math.random(1, #fluids)], amount = math.random(15000, 25000)}
end

local function create_inner_content(surface, pos, noise)
    if math_random(1, 90000) == 1 then
        secret_shop(pos, surface)
        return
    end
    if math_random(1, 102400) == 1 then
        if noise < 0.3 or noise > -0.3 then
            map_functions.draw_noise_entity_ring(surface, pos, 'laser-turret', 'scrap_defense', 0, 2)
            map_functions.draw_noise_entity_ring(surface, pos, 'accumulator', 'scrap_defense', 2, 3)
            map_functions.draw_noise_entity_ring(surface, pos, 'substation', 'scrap_defense', 3, 4)
            map_functions.draw_noise_entity_ring(surface, pos, 'solar-panel', 'scrap_defense', 4, 6)
            map_functions.draw_noise_entity_ring(surface, pos, 'stone-wall', 'scrap_defense', 6, 7)

            create_tile_chain(surface, {name = 'concrete', position = pos}, math_random(16, 32), 50)
            create_tile_chain(surface, {name = 'concrete', position = pos}, math_random(16, 32), 50)
            create_tile_chain(surface, {name = 'stone-path', position = pos}, math_random(16, 32), 50)
            create_tile_chain(surface, {name = 'stone-path', position = pos}, math_random(16, 32), 50)
        --create_entity_chain(surface, {name = "laser-turret", position = pos, force = "scrap_defense"}, 1, 25)
        --create_entity_chain(surface, {name = "accumulator", position = pos, force = "scrap_defense"}, math_random(2, 4), 1)
        --create_entity_chain(surface, {name = "substation", position = pos, force = "scrap_defense"}, math_random(6, 8), 1)
        --	create_entity_chain(surface, {name = "solar-panel", position = pos, force = "scrap_defense"}, math_random(16, 24), 1)
        end
        return
    end
    if math_random(1, 650) == 1 then
        if surface.can_place_entity({name = 'biter-spawner', position = pos}) then
            local distance_to_center = pos.x ^ 2 + pos.y ^ 2
            if distance_to_center > 35000 then
                surface.create_entity({name = 'biter-spawner', position = pos})
            end
        end
        return
    end
end

local function process_entity(e)
    if not e.valid then
        return
    end
    if entity_replacements[e.name] then
        if e.type == 'tree' then
            if math_random(1, 2) == 1 then
                e.surface.create_entity({name = entity_replacements[e.name], position = e.position})
            end
        else
            e.surface.create_entity({name = entity_replacements[e.name], position = e.position})
        end
        e.destroy()
        return
    end

    if e.type == 'unit-spawner' then
        for _, wreck in pairs(
            e.surface.find_entities_filtered(
                {
                    area = {{e.position.x - 4, e.position.y - 4}, {e.position.x + 4, e.position.y + 4}},
                    name = 'mineable-wreckage'
                }
            )
        ) do
            if wreck.valid then
                wreck.destroy()
            end
        end
        return
    end
end

local function on_chunk_generated(event)
    local center = {
        x = (event.area.left_top.x + event.area.right_bottom.x) / 2,
        y = (event.area.left_top.y + event.area.right_bottom.y) / 2
    }
    local surface = game.surfaces['nauvis']
    local left_top = event.area.left_top
    local tiles = {}
    local entities = {}

    for x = 0, 31, 1 do
        for y = 0, 31, 1 do
            local tile_to_insert = false
            local pos = {x = left_top.x + x, y = left_top.y + y}

            local tile = surface.get_tile(pos)
            if tile_replacements[tile.name] then
                table_insert(tiles, {name = tile_replacements[tile.name], position = pos})
            end

            if not tile.collides_with('player-layer') then
                if math.abs(center.x) < CHUNK_SIZE * 2 and math.abs(center.y) < CHUNK_SIZE * 2 then
                else
                    local noise = get_noise(1, pos)
                    if noise > 0.43 or noise < -0.43 then
                        if math_random(1, 3) ~= 1 then
                            surface.create_entity({name = 'mineable-wreckage', position = pos})
                        else
                            if math_random(1, 512) == 1 then
                                create_shipwreck(surface, pos)
                            else
                                if math_random(1, 512) == 1 then
                                    place_random_scrap_entity(surface, pos)
                                end
                            end
                        end
                    else
                        create_inner_content(surface, pos, noise)
                    end
                end
            end
        end
    end
    surface.set_tiles(tiles, true)

    for _, e in pairs(surface.find_entities_filtered({area = event.area})) do
        process_entity(e)
    end

    if global.spawn_generated then
        return
    end
    --surface.request_to_generate_chunks({0,0}, 2)
    if left_top.x < 96 then
        return
    end
    map_functions.draw_rainbow_patch_v2({x = 0, y = 0}, surface, 12, 2500)
    local p = surface.find_non_colliding_position('character-corpse', {2, -2}, 32, 2)
    local e = surface.create_entity({name = 'character-corpse', position = p})
    for _, e in pairs(surface.find_entities_filtered({area = {{-50, -50}, {50, 50}}})) do
        local distance_to_center = math.sqrt(e.position.x ^ 2 + e.position.y ^ 2)
        if e.valid then
            if distance_to_center < 8 and e.name == 'mineable-wreckage' and math_random(1, 5) ~= 1 then
                e.destroy()
            end
        end
        if e.valid then
            if distance_to_center < 30 and e.name == 'gun-turret' then
                e.destroy()
            end
        end
    end
    global.spawn_generated = true
end

local function on_chunk_charted(event)
    if not global.chunks_charted then
        global.chunks_charted = {}
    end
    local surface = game.surfaces['nauvis']
    local position = event.position
    if global.chunks_charted[tostring(position.x) .. tostring(position.y)] then
        return
    end
    global.chunks_charted[tostring(position.x) .. tostring(position.y)] = true

    if math_random(1, 16) ~= 1 then
        return
    end
    local pos = {x = position.x * 32 + math_random(1, 32), y = position.y * 32 + math_random(1, 32)}
    local noise = get_noise(1, pos)
    if noise > 0.4 or noise < -0.4 then
        return
    end
    local distance_to_center = math.sqrt(pos.x ^ 2 + pos.y ^ 2)
    local size = 7 + math.floor(distance_to_center * 0.0075)
    if size > 20 then
        size = 20
    end
    local amount = 500 + distance_to_center * 2
    map_functions.draw_rainbow_patch_v2(pos, surface, size, amount)
    if global.spawn_resource_spawned then
        return
    end
    local ore_positions = {{x = -16, y = -16}, {x = 16, y = -16}, {x = -16, y = 16}, {x = 16, y = 16}}
    ore_positions = shuffle(ore_positions)
    map_functions.draw_noise_entity_ring(surface, {x = 0, y = 0}, 'stone-wall', 'Protectors', 40, 42)
    map_functions.draw_smoothed_out_ore_circle(ore_positions[1], 'copper-ore', surface, 10, 2500)
    map_functions.draw_smoothed_out_ore_circle(ore_positions[2], 'iron-ore', surface, 10, 2500)
    map_functions.draw_smoothed_out_ore_circle(ore_positions[3], 'coal', surface, 10, 2500)
    map_functions.draw_smoothed_out_ore_circle(ore_positions[4], 'stone', surface, 10, 2500)
    global.spawn_resource_spawned = true
end

local function on_marked_for_deconstruction(event)
    if disabled_for_deconstruction[event.entity.name] then
        event.entity.cancel_deconstruction(game.players[event.player_index].force.name)
    end
end

local function get_sorted_list(column_name, score_list)
    for x = 1, #score_list, 1 do
        for y = 1, #score_list, 1 do
            if not score_list[y + 1] then
                break
            end
            if score_list[y][column_name] < score_list[y + 1][column_name] then
                local key = score_list[y]
                score_list[y] = score_list[y + 1]
                score_list[y + 1] = key
            end
        end
    end
    return score_list
end

local function get_mvps(force)
    if not global.score[force] then
        return false
    end
    local score = global.score[force]
    local score_list = {}
    for _, p in pairs(game.players) do
        if score.players[p.name] then
            local killscore = 0
            if score.players[p.name].killscore then
                killscore = score.players[p.name].killscore
            end
            local deaths = 0
            if score.players[p.name].deaths then
                deaths = score.players[p.name].deaths
            end
            local built_entities = 0
            if score.players[p.name].built_entities then
                built_entities = score.players[p.name].built_entities
            end
            local mined_entities = 0
            if score.players[p.name].mined_entities then
                mined_entities = score.players[p.name].mined_entities
            end
            table.insert(
                score_list,
                {
                    name = p.name,
                    killscore = killscore,
                    deaths = deaths,
                    built_entities = built_entities,
                    mined_entities = mined_entities
                }
            )
        end
    end
    local mvp = {}
    score_list = get_sorted_list('killscore', score_list)
    mvp.killscore = {name = score_list[1].name, score = score_list[1].killscore}
    score_list = get_sorted_list('deaths', score_list)
    mvp.deaths = {name = score_list[1].name, score = score_list[1].deaths}
    score_list = get_sorted_list('built_entities', score_list)
    mvp.built_entities = {name = score_list[1].name, score = score_list[1].built_entities}
    return mvp
end

local function show_mvps(player)
    if not global.score then
        return
    end
    if player.gui.left['mvps'] then
        return
    end
    local frame = player.gui.left.add({type = 'frame', name = 'mvps', direction = 'vertical'})
    local l = frame.add({type = 'label', caption = 'MVPs - Protectors:'})
    l.style.font = 'default-listbox'
    l.style.font_color = {r = 0.55, g = 0.55, b = 0.99}

    local t = frame.add({type = 'table', column_count = 2})
    local mvp = get_mvps('Protectors')
    if mvp then
        local l = t.add({type = 'label', caption = 'Defender >> '})
        l.style.font = 'default-listbox'
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({type = 'label', caption = mvp.killscore.name .. ' with a score of ' .. mvp.killscore.score})
        l.style.font = 'default-bold'
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        local l = t.add({type = 'label', caption = 'Builder >> '})
        l.style.font = 'default-listbox'
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l =
            t.add(
            {type = 'label', caption = mvp.built_entities.name .. ' built ' .. mvp.built_entities.score .. ' things'}
        )
        l.style.font = 'default-bold'
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        local l = t.add({type = 'label', caption = 'Deaths >> '})
        l.style.font = 'default-listbox'
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({type = 'label', caption = mvp.deaths.name .. ' died ' .. mvp.deaths.score .. ' times'})
        l.style.font = 'default-bold'
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        if not global.results_sent_protectors then
            local result = {}
            insert(result, 'Protectors: \\n')
            insert(result, 'MVP Defender: \\n')
            insert(result, mvp.killscore.name .. ' with a score of ' .. mvp.killscore.score .. '\\n')
            insert(result, '\\n')
            insert(result, 'MVP Builder: \\n')
            insert(result, mvp.built_entities.name .. ' built ' .. mvp.built_entities.score .. ' things\\n')
            insert(result, '\\n')
            insert(result, 'MVP Deaths: \\n')
            insert(result, mvp.deaths.name .. ' died ' .. mvp.deaths.score .. ' times')
            local message = table.concat(result)
            server_commands.to_discord_embed(message)
            global.results_sent_protectors = true
        end
    end

    local l = frame.add({type = 'label', caption = 'MVPs - Renegades:'})
    l.style.font = 'default-listbox'
    l.style.font_color = {r = 0.99, g = 0.33, b = 0.33}

    local t = frame.add({type = 'table', column_count = 2})
    local mvp = get_mvps('Renegades')
    if mvp then
        local l = t.add({type = 'label', caption = 'Defender >> '})
        l.style.font = 'default-listbox'
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({type = 'label', caption = mvp.killscore.name .. ' with a score of ' .. mvp.killscore.score})
        l.style.font = 'default-bold'
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        local l = t.add({type = 'label', caption = 'Builder >> '})
        l.style.font = 'default-listbox'
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l =
            t.add(
            {type = 'label', caption = mvp.built_entities.name .. ' built ' .. mvp.built_entities.score .. ' things'}
        )
        l.style.font = 'default-bold'
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        local l = t.add({type = 'label', caption = 'Deaths >> '})
        l.style.font = 'default-listbox'
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({type = 'label', caption = mvp.deaths.name .. ' died ' .. mvp.deaths.score .. ' times'})
        l.style.font = 'default-bold'
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        if not global.results_sent_renegades then
            local result = {}
            insert(result, 'Renegades: \\n')
            insert(result, 'MVP Attackers: \\n')
            insert(result, mvp.killscore.name .. ' with a score of ' .. mvp.killscore.score .. '\\n')
            insert(result, '\\n')
            insert(result, 'MVP Builder: \\n')
            insert(result, mvp.built_entities.name .. ' built ' .. mvp.built_entities.score .. ' things\\n')
            insert(result, '\\n')
            insert(result, 'MVP Deaths: \\n')
            insert(result, mvp.deaths.name .. ' died ' .. mvp.deaths.score .. ' times')
            local message = table.concat(result)
            server_commands.to_discord_embed(message)
            global.results_sent_renegades = true
        end
    end
end

local function create_jk_menu(player)
    if global.rocket_silo_destroyed then
        if player.gui.left['victory_popup'] then
            player.gui.left['victory_popup'].destroy()
        end
        local frame = player.gui.left.add {type = 'frame', name = 'victory_popup', direction = 'vertical'}
        local l =
            frame.add {
            type = 'label',
            caption = global.rocket_silo_destroyed,
            single_line = false,
            name = 'victory_caption'
        }
        l.style.font = 'default-listbox'
        l.style.font_color = {r = 0.98, g = 0.66, b = 0.22}
        l.style.top_padding = 10
        l.style.left_padding = 20
        l.style.right_padding = 20
        l.style.bottom_padding = 10
        show_mvps(player)
        return
    end
end

local function refresh_gui()
    for _, player in pairs(game.connected_players) do
        local frame = player.gui.left['create_jk_menu']
        create_jk_menu(player)
        if (frame) then
            frame.destroy()
        end
    end
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
    if player.online_time == 0 then
        player.insert({name = 'pistol', count = 1})
        player.insert({name = 'firearm-magazine', count = 16})
        player.insert({name = 'iron-plate', count = 64})
        player.insert({name = 'burner-mining-drill', count = 4})
        player.insert({name = 'stone-furnace', count = 4})
    end
    if player.tag == '' then
        player.teleport({x = 0.5, y = 0.5}, game.surfaces['lobby'])
    --player.teleport(game.surfaces["lobby"].find_non_colliding_position("player", {0,0}, 4, 1))
    end
    --AssignPlayerToStartSurface(game.players[event.player_index])

    if global.map_init_done then
        return
    end
    game.forces['player'].technologies['optics'].researched = true
    --game.surfaces["nauvis"].ticks_per_day = game.surfaces["nauvis"].ticks_per_day * 2
    game.surfaces['nauvis'].always_day = true
    global.map_init_done = true
end

local function on_player_mined_entity(event)
    local entity = event.entity
    if not entity.valid then
        return
    end

    if entity.name == 'mineable-wreckage' then
        if math_random(1, 40) == 1 then
            unearthing_biters(entity.surface, entity.position, math_random(4, 12))
        end
        if math_random(1, 80) == 1 then
            unearthing_worm(entity.surface, entity.position)
        end
        if math_random(1, 160) == 1 then
            tick_tack_trap(entity.surface, entity.position)
        end
    end

    if entity.force.name ~= 'scrap' then
        return
    end
    local positions = {}
    local r = math.ceil(entity.prototype.max_health / 32)
    for x = r * -1, r, 1 do
        for y = r * -1, r, 1 do
            positions[#positions + 1] = {x = entity.position.x + x, y = entity.position.y + y}
        end
    end
    positions = shuffle(positions)
    for i = 1, math.ceil(entity.prototype.max_health / 32), 1 do
        if not positions[i] then
            return
        end
        if math_random(1, 3) ~= 1 then
            unearthing_biters(entity.surface, positions[i], math_random(5, 10))
        else
            unearthing_worm(entity.surface, positions[i])
        end
    end
end

local function on_tick(event)
    if global.rocket_silo_destroyed then
        refresh_gui()
        if not global.game_restart_timeout then
            global.game_restart_timeout = 7200
        end
        if not global.game_restart_timer_completed then
            if game.tick % 900 == 0 then
                if global.game_restart_timeout > 0 then
                    game.print(
                        'Map will restart in ' .. math.ceil(global.game_restart_timeout / 60) .. ' seconds!',
                        {r = 0.22, g = 0.88, b = 0.22}
                    )
                end
                global.game_restart_timeout = global.game_restart_timeout - 900
            end
            if global.game_restart_timeout < 0 then
                global.game_restart_timer_completed = true
                game.print('Map is restarting!', {r = 0.22, g = 0.88, b = 0.22})
                local message = 'Map is restarting! '
                server_commands.to_discord_bold(table.concat {'*** ', message, ' ***'})
                server_commands.start_scenario('Junkyard')
            end
        end
    end
end

local function on_entity_died(event)
    if not global.rocket_silo_destroyed then
        if event.entity == silo then
            global.rocket_silo_destroyed = 'Renegades have won!'
            for _, player in pairs(game.connected_players) do
                player.play_sound {path = 'utility/game_won', volume_modifier = 1}
            end
        end
    end
    on_player_mined_entity(event)
    refresh_gui()
end

local function on_research_finished(event)
    event.research.force.character_inventory_slots_bonus = game.forces.player.mining_drill_productivity_bonus * 300
end

local function on_init()
    local T = Map.Pop_info()
    T.main_caption = 'A n a r c h y'
    T.sub_caption = '    ---defend the silo---'
    T.text =
        table.concat(
        {
            "### Captain's log, stardate 1834.2. ###",
            '\n',
            'Catlord Corp. has sent you to gather resources in this god forsaken planet.\n',
            'Remnants of an ancient war fill its surface.\n',
            "Don't feel free yet. You are a prisoner and you belong to The Company.\n",
            'And you are worth less than your rusty armor.\n',
            '\n',
            'OR...\n',
            '\n',
            'You could always parachute out of this damn spaceship before it lands and do your thing.. you know..\n',
            'Maybe the local population is not as mean as they say..\n',
            '\n',
            'Choose your path..\n',
            '\n',
            'The Company --- Renegade\n',
            '\n',
            '### Log End ###'
        }
    )
    T.main_caption_color = {r = 150, g = 150, b = 0}
    T.sub_caption_color = {r = 0, g = 150, b = 0}
end

Event.on_init(on_init)
Event.add(defines.events.on_research_finished, on_research_finished)
Event.add(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_mined_entity, on_player_mined_entity)
Event.add(defines.events.on_chunk_generated, on_chunk_generated)
Event.add(defines.events.on_chunk_charted, on_chunk_charted)
Event.add(defines.events.on_tick, on_tick)
Event.add(defines.events.on_entity_died, on_entity_died)
