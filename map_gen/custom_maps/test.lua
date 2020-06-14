local map_data = require 'output'

local Event = require 'utils.event'
local t_insert = table.insert
local scale = 2
local spawn = {
    x = map_data.width,
    y = map_data.height
}

local codes = {
    ['a'] = 'water-green',
    ['b'] = 'dirt-7',
    ['c'] = 'concrete',
    ['d'] = 'deepwater-green',
    ['e'] = 'deepwater',
    ['f'] = 'dirt-1',
    ['g'] = 'dirt-2',
    ['h'] = 'dirt-3',
    ['i'] = 'dirt-4',
    ['j'] = 'dirt-5',
    ['k'] = 'dirt-6',
    ['l'] = 'dirt-7',
    ['m'] = 'dry-dirt',
    ['n'] = 'grass-1',
    ['o'] = 'grass-2',
    ['p'] = 'grass-3',
    ['q'] = 'grass-4',
    ['r'] = 'hazard-concrete-left',
    ['s'] = 'hazard-concrete-right',
    ['t'] = 'lab-dark-1',
    ['u'] = 'lab-dark-2',
    ['v'] = 'lab-white',
    ['w'] = 'out-of-map',
    ['x'] = 'red-desert-0',
    ['y'] = 'red-desert-1',
    ['z'] = 'red-desert-2',
    ['A'] = 'red-desert-3',
    ['B'] = 'sand-1',
    ['C'] = 'sand-2',
    ['D'] = 'sand-3',
    ['E'] = 'stone-path',
    ['F'] = 'water-green',
    ['G'] = 'water'
}

local function decompress_map_data()
    --print("Decompressing, this can take a while...")
    local decompressed = {}
    local data = map_data.data
    local height = #data
    local width = nil
    for y = 0, height - 1 do
        decompressed[y] = {}

        local total_count = 0
        local line = data[y + 1]
        for letter, count in string.gmatch(line, '(%a+)(%d+)') do
            for x = total_count, total_count + count do
                decompressed[y][x] = letter
            end
            total_count = total_count + count
        end
        if width == nil then
            width = total_count
        elseif width ~= total_count then
            error()
        end
    end
    return decompressed, width, height
end

local decompressed_map_data, width, height = decompress_map_data()

local function add_to_total(totals, weight, code)
    if totals[code] == nil then
        totals[code] = {code = code, weight = weight}
    else
        totals[code].weight = totals[code].weight + weight
    end
end

local function get_tile(x, y)
    x = x / scale
    y = y / scale
    local top = math.floor(y)
    local bottom = (top + 1)
    local left = math.floor(x)
    local right = (left + 1)
    local sqrt2 = math.sqrt(2)
    local w_top_left = 1 - math.sqrt((top - y) * (top - y) + (left - x) * (left - x)) / sqrt2
    local w_top_right = 1 - math.sqrt((top - y) * (top - y) + (right - x) * (right - x)) / sqrt2
    local w_bottom_left = 1 - math.sqrt((bottom - y) * (bottom - y) + (left - x) * (left - x)) / sqrt2
    local w_bottom_right = 1 - math.sqrt((bottom - y) * (bottom - y) + (right - x) * (right - x)) / sqrt2
    w_top_left = w_top_left * w_top_left + math.random() / math.max(scale / 2, 10)
    w_top_right = w_top_right * w_top_right + math.random() / math.max(scale / 2, 10)
    w_bottom_left = w_bottom_left * w_bottom_left + math.random() / math.max(scale / 2, 10)
    w_bottom_right = w_bottom_right * w_bottom_right + math.random() / math.max(scale / 2, 10)
    local c_top_left = decompressed_map_data[top % height][left % width]
    local c_top_right = decompressed_map_data[top % height][right % width]
    local c_bottom_left = decompressed_map_data[bottom % height][left % width]
    local c_bottom_right = decompressed_map_data[bottom % height][right % width]
    local totals = {}
    add_to_total(totals, w_top_left, c_top_left)
    add_to_total(totals, w_top_right, c_top_right)
    add_to_total(totals, w_bottom_left, c_bottom_left)
    add_to_total(totals, w_bottom_right, c_bottom_right)
    --choose final code
    local code = nil
    local weight = 0
    for _, total in pairs(totals) do
        if total.weight > weight then
            code = total.code
            weight = total.weight
        end
    end
    return codes[code]
end

local function on_chunk_generated(event)
    local surface = event.surface
    local lt = event.area.left_top
    local rb = event.area.right_bottom

    --local w = rb.x - lt.x
    --local h = rb.y - lt.y
    --print("Chunk generated: ", lt.x, lt.y, w, h)

    local tiles = {}
    for y = lt.y - 1, rb.y do
        for x = lt.x - 1, rb.x do
            t_insert(tiles, {name = get_tile(x + spawn.x, y + spawn.y), position = {x, y}})
        end
    end
    surface.set_tiles(tiles, true)
end

Event.add(defines.events.on_chunk_generated, on_chunk_generated)
