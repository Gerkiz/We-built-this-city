local Event = require 'utils.event'
local Server = require 'utils.server'
local Surface = require 'utils.surface'
local Table = require 'utils.surface'
local Eval = require 'map_gen.shapes.evalpattern'

local map_name = 'distort_zoom'
local water_color = 'green'

local get_tile = nil
local force_initial_water = false
local mabs = math.abs
local insert = table.insert

local function replace_water(surface)
    if global.spawn_water_replaced then
        return
    end
    if not surface.is_chunk_generated({5, 5}) then
        return
    end
    local tilename
    for x = -50, 50, 1 do
        for y = -50, 50, 1 do
            local tile = surface.get_tile(x, y)
            if tile.name ~= 'water' and tile.name ~= 'deepwater' then
                tilename = tile.name
            end
        end
    end
    local tiles = {}
    for x = -128, 128, 1 do
        for y = -128, 128, 1 do
            local tile = surface.get_tile(x, y)
            if tile.name == 'water' or tile.name == 'water-green' or tile.name == 'deepwater' or tile.name == 'deepwater-green' then
                insert(tiles, {name = tilename, position = {x = tile.position.x, y = tile.position.y}})
            end
        end
    end
    surface.set_tiles(tiles, true)
    global.spawn_water_replaced = true
end

local function make_chunk(event)
    local s_name = Surface.get_surface_name()
    local gt = get_tile
    local tinsert = table.insert
    if not game.surfaces[s_name] then
        return
    end

    local surface = game.surfaces[s_name]

    local x1 = event.area.left_top.x
    local y1 = event.area.left_top.y
    local x2 = event.area.right_bottom.x
    local y2 = event.area.right_bottom.y

    local tiles = {}
    local fishes = {}

    if mabs(x1) + mabs(y1) > 70 then
        for x = x1, x2 do
            for y = y1, y2 do
                local new = gt(x, y)
                if new ~= nil then
                    tinsert(tiles, {name = new, position = {x, y}})
                --if math_random(1,1024) == 1 then tinsert(fishes, {x, y}) end
                end
            end
        end
    else
        -- Only happens for a few chunks near the origin
        for x = x1, x2 do
            for y = y1, y2 do
                if force_initial_water and ((x - 7) * (x - 7) + y * y < 10) then
                    tinsert(tiles, {name = water_color, position = {x, y}})
                else
                    if (x * x + y * y > 5) then
                        local new = gt(x, y)
                        if new ~= nil then
                            tinsert(tiles, {name = new, position = {x, y}})
                        end
                    end
                end
            end
        end
    end

    surface.set_tiles(tiles)

    for _, fish in pairs(fishes) do
        surface.create_entity({name = 'fish', position = fish})
    end
end

Event.on_load(
    function()
        local t = Table.get()
        local tp = Eval.evaluate_pattern(map_name)
        tp.reload(t.tp_data)
        get_tile = tp.get
    end
)

Event.on_init(
    function()
        local t = Table.get()
        t.water = 0
        local tp = Eval.evaluate_pattern(map_name)
        t.tp_data = tp.create()
        get_tile = tp.get
    end
)

Event.add(
    defines.events.on_chunk_generated,
    function(event)
        local s_name = Surface.get_surface_name()
        make_chunk(event)
        replace_water(game.surfaces[s_name])
    end
)
