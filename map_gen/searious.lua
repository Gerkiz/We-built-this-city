--Searious map-mod.
--Written by Mylon
--MIT license
--2017

--deep = require "noise"

SEARIOUS_STARTING_RADIUS = 70


--Create a 32x32 table and set a flag if ore is nearby.  Then turn everything not flagged to water.
function sea_the_world(event)
    local math_floor = math.floor
    --Create a 2d array.  This will auto-create our y table if x does not exist, allowing flood[x][y] = true to just work
    local flood = setmetatable({}, { __index = function(t, k) t[k] = {} return t[k] end })

    local tiles = {}

    local ltx = event.area.left_top.x
    local lty = event.area.left_top.y
    local rbx = event.area.right_bottom.x
    local rby = event.area.right_bottom.y

    --Check starting area
    --Check existing water and ignore if true
    for x = ltx-1, rbx+1 do
        for y = lty-1, rby+1 do
            if x^2 + y^2 > SEARIOUS_STARTING_RADIUS^2 then
                -- Need to add a special check to avoid drawing lines on the edges.
                if not event.surface.get_tile(x, y).collides_with("water-tile") then
                --table.insert(tiles, {name="deepwater", position={x,y}})
                -- else
                    flood[x][y] = true
                end
            end
        end
    end

    --Check ore.
    local ores = event.surface.find_entities_filtered{area=event.area, type="resource"}
    for k,v in pairs(ores) do
        for x = math_floor(v.position.x) - 1, math_floor(v.position.x) + 1 do
            for y = math_floor(v.position.y) - 1, math_floor(v.position.y) + 1 do
                flood[x][y] = false
            end
        end
    end
    
    --Now build tile table
    for x = ltx, rbx do
        for y = lty, rby do
            if (flood[x][y]) then
                -- if not sea_sharp(x, y) then
                --if event.surface.get_tile_properties({x,y}).elevation < 5 then
                  --  table.insert(tiles, {name="deepwater", position={x,y}})
                --else
                    table.insert(tiles, {name="water", position={x,y}})
                --end
            end
        end
    end

    --Finally set
    event.surface.set_tiles(tiles, true)
end

--My very own noise generator.
--Shelved for now.
function sea_sharp(x, y)
    if (x+y) % 300 / 500 + math.sin((y)/400) > 0.8 then
        -- if (x - y + game.surfaces[1].map_gen_settings.seed) % 1100 > 700 then
            return true
        -- end
    end
    -- Still here?  Return false
    return false
end

Event.register(defines.events.on_chunk_generated, sea_the_world)
