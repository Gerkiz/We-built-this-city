require 'smallRuins'
require 'mediumRuins'
require 'largeRuins'
require 'ents'

local event = require 'utils.event'
local DEBUG = false --used for debug, users should not enable

--function that will return true 'percent' of the time.
local function probability(percent)
    return math.random() <= percent
end

local function chunk_ruin(e)
    local center = {x = (e.area.left_top.x + e.area.right_bottom.x) / 2, y = (e.area.left_top.y + e.area.right_bottom.y) / 2}
    if math.abs(center.x) < 200 and math.abs(center.y) < 200 then
        return
    end --too close to spawn

    if e.surface.name ~= 'nauvis' or e.surface.name ~= 'wbtc' then
        return
    end

    if probability(0.05) then
        --spawn small ruin
        if DEBUG then
            game.print('A small ruin was spawned at ' .. center.x .. ',' .. center.y)
        end

        --random variance so they aren't always chunk aligned
        center.x = center.x + math.random(-10, 10)
        center.y = center.y + math.random(-10, 10)

        spawnSmallRuins(center, e.surface)
    elseif probability(0.02) then
        --spawn medium ruin
        if DEBUG then
            game.print('A medium ruin was spawned at ' .. center.x .. ',' .. center.y)
        end

        --random variance so they aren't always chunk aligned
        center.x = center.x + math.random(-5, 5)
        center.y = center.y + math.random(-5, 5)

        spawnMediumRuins(center, e.surface)
    elseif probability(0.005) then
        --spawn large ruin
        if DEBUG then
            game.print('A large ruin was spawned at ' .. center.x .. ',' .. center.y)
        end
        spawnLargeRuins(center, e.surface)
    end
end

event.add(defines.events.on_chunk_generated, chunk_ruin)
