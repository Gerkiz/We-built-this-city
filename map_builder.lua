local Generate = require 'map_gen.builder.generate'
local b = require 'map_gen.builder.b'
local pic = require 'map_gen.builder.output'
b.scale = 2
pic = b.decompress(pic)
local shape = b.Build(pic)

local function on_chunk(x, y, data)
    local p = {x = x, y = y}
    local tiles = data.tiles

    local pattern = {
        {shape, b.flip_x(shape)},
        {b.flip_y(shape), b.flip_xy(shape)}
    }

    local map = b.grid_pattern(pattern, 2, 2, pic.width - 1, pic.height - 1)

    map = b.translate(map, 222, 64)

    local build = map(data.x, data.y)

    local RectSpiral = b.RectSpiral()

    if build then
        tiles[#tiles + 1] = {name = build, position = p}
    else
        tiles[#tiles + 1] = {name = 'out-of-map', position = p}
    end
    return {
        tiles = tiles,
        tile = tiles
    }
end

Generate.init({map_selector = on_chunk})
