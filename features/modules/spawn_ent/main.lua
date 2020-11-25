local Market = require 'features.functions.basic_markets'
local Loot = require 'features.modules.loot_items_v2'
local Event = require 'utils.event'
local Fort = require 'features.modules.spawn_ent.fort'
--local StorageLoot = require 'features.modules.spawn_ent.storage'
local Turret = require 'features.modules.spawn_ent.turrets'
local m_random = math.random

local Public = {}

Public.debug = false

local function d_print(name, pos)
    if not Public.debug then
        return
    end
    game.print('Spawned ' .. name .. ' at: x=' .. pos.x .. ', y=' .. pos.y)
end

local function m_clearArea(center, surface)
    for y = center.y - 8, center.y + 8 do
        for x = center.x - 8, center.x + 8 do
            if surface.get_tile(x, y).name == 'water' or surface.get_tile(x, y).name == 'deepwater' then
                return false
            end
        end
    end

    for index, entity in pairs(surface.find_entities({{center.x - 8, center.y - 8}, {center.x + 8, center.y + 8}})) do
        if entity.valid and entity.type ~= 'resource' then
            entity.destroy()
        end
    end

    return true
end

local function probability(v1, v2)
    return m_random(v1, v2) >= v2
end

local function spawn_market(center, surface)
    if probability(1, 128) then
        center.x = center.x + m_random(-10, 10)
        center.y = center.y + m_random(-10, 10)
        local pos = {x = center.x, y = center.y}
        if m_clearArea(center, surface) then
            if probability(1, 2) then
                local area = {{pos.x - 64, pos.y - 64}, {pos.x + 64, pos.y + 64}}
                if surface.count_entities_filtered({name = 'market', area = area}) == 0 then
                    local a = Market.mountain_market(surface, center, math.abs(center.y) * 0.004)
                    rendering.draw_text {
                        text = 'Market',
                        surface = surface,
                        target = a,
                        target_offset = {0, 2},
                        color = {r = 0.98, g = 0.66, b = 0.22},
                        alignment = 'center'
                    }
                    a.destructible = false
                end
                d_print('market', pos)
            else
                local area = {{pos.x - 64, pos.y - 64}, {pos.x + 64, pos.y + 64}}
                if surface.count_entities_filtered({name = 'market', area = area}) == 0 then
                    local a = Market.mountain_market(surface, center, math.abs(center.x) * 0.004)
                    rendering.draw_text {
                        text = 'Market',
                        surface = surface,
                        target = a,
                        target_offset = {0, 2},
                        color = {r = 0.98, g = 0.66, b = 0.22},
                        alignment = 'center'
                    }
                    a.destructible = false
                end
                d_print('market', pos)
            end
            return
        end
    end
end

local function spawn_turret(center, surface)
    if probability(1, 40) then
        center.x = center.x + math.random(-15, 5)
        center.y = center.y + math.random(-15, 5)
        local pos = {x = center.x, y = center.y}
        if m_clearArea(center, surface) then
            Turret(center, surface)
            d_print('turret', pos)
        end
    end
end

local function spawn_loot(center, surface)
    if probability(1, 96) then
        center.x = center.x + math.random(-5, 5)
        center.y = center.y + math.random(-5, 5)
        local pos = {x = center.x, y = center.y}
        local name = 'crash-site-chest-1'
        if probability(1, 2) then
            name = 'crash-site-chest-2'
        end
        if m_clearArea(center, surface) then
            if probability(1, 2) then
                Loot.add(surface, center, name)
                Fort(center, surface)
            else
                Loot.add(surface, center, name)
                --	StorageLoot(center, surface)
                d_print(name, pos)
            end
        end
    end
end

local tiles = {
    ['water'] = true,
    ['deepwater'] = true,
    ['water-green'] = true,
    ['deepwater-green'] = true
}

local function ticker(e)
    if e.surface.name ~= 'nauvis' or e.surface.name ~= 'wbtc' then
        return
    end
    local center = {x = (e.area.left_top.x + e.area.right_bottom.x) / 2, y = (e.area.left_top.y + e.area.right_bottom.y) / 2}
    if math.abs(center.x) < 200 and math.abs(center.y) < 200 then
        return
    end --too close to spawn
    local pos = {x = center.x, y = center.y}
    local t_name = e.surface.get_tile(pos).name
    if tiles[t_name] then
        return
    end
    spawn_market(center, e.surface)
    spawn_loot(center, e.surface)
    spawn_turret(center, e.surface)
end

Event.add(defines.events.on_chunk_generated, ticker)

return Public
