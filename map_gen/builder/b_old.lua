local Public = {}
local map_data = require 'map_gen.builder.output'
local random = math.random
local scale = 5
local spawn = {
    x = map_data.width,
    y = map_data.height
}

local dirt = {
    'dirt-1',
    'dirt-2',
    'dirt-3',
    'dirt-4',
    'dirt-5',
    'dirt-6',
    'dirt-7'
}

local dirt_n = #dirt

local tile_map = {
    [1] = false,
    [2] = true,
    [3] = 'dirt-7',
    [4] = 'deepwater-green',
    [5] = 'deepwater',
    [6] = 'dirt-1',
    [7] = 'dirt-2',
    [8] = 'dirt-3',
    [9] = 'dirt-4',
    [10] = 'dirt-5',
    [11] = 'dirt-6',
    [12] = 'dirt-7',
    [13] = 'dry-dirt',
    [14] = 'grass-1',
    [15] = 'grass-2',
    [16] = 'grass-3',
    [17] = 'grass-4',
    [18] = 'hazard-concrete-left',
    [19] = 'hazard-concrete-right',
    [20] = 'lab-dark-1',
    [21] = 'lab-dark-2',
    [22] = 'lab-white',
    [23] = 'out-of-map',
    [24] = 'red-desert-0',
    [25] = 'red-desert-1',
    [26] = 'red-desert-2',
    [27] = 'red-desert-3',
    [28] = 'sand-1',
    [29] = 'sand-2',
    [30] = 'sand-3',
    [31] = 'stone-path',
    [32] = 'water-green',
    [33] = 'water'
}

local function noop()
    return nil
end

local function decompress()
    local decompressed = {}
    local data = map_data.data
    local height = map_data.height
    local width = map_data.width

    for y = 1, height do
        local row = data[y]
        local u_row = {}
        decompressed[y] = u_row
        local x = 1
        for index = 1, #row, 2 do
            local pixel = row[index]
            local count = row[index + 1]

            for _ = 1, count do
                u_row[x] = pixel
                x = x + 1
            end
        end
    end

    return decompressed, width, height
end
local tile_data, width, height = decompress()

local function add_to_total(totals, weight, code)
    if totals[code] == nil then
        totals[code] = {code = code, weight = weight}
    else
        totals[code].weight = totals[code].weight + weight
    end
end

local function get_pos(x, y)
    local floor = math.floor

    -- the plus one is because lua tables are one based.
    local half_width = floor(width / 2) + 1
    local half_height = floor(height / 2) + 1
    x = x / scale
    y = y / scale
    x = floor(x)
    y = floor(y)
    local x2 = x + half_width
    local y2 = y + half_height

    if y2 > 0 and y2 <= height and x2 > 0 and x2 <= width then
        return tile_map[tile_data[y2][x2]]
    end
    local function get(x, y)
        if x < -1 then
            return false
        else
            return (x < 2) or ((y % 2) < 1)
        end
    end
end

function Public.get(data)
    local x = data.x
    local y = data.y
    --scaling
    x = x / scale
    y = y / scale
    --get cells you're between
    local top = math.floor(y)
    local bottom = (top + 1)
    local left = math.floor(x)
    local right = (left + 1)
    --calc weights
    local sqrt2 = math.sqrt(2)
    local w_top_left = 1 - math.sqrt((top - y) * (top - y) + (left - x) * (left - x)) / sqrt2
    local w_top_right = 1 - math.sqrt((top - y) * (top - y) + (right - x) * (right - x)) / sqrt2
    local w_bottom_left = 1 - math.sqrt((bottom - y) * (bottom - y) + (left - x) * (left - x)) / sqrt2
    local w_bottom_right = 1 - math.sqrt((bottom - y) * (bottom - y) + (right - x) * (right - x)) / sqrt2
    w_top_left = w_top_left * w_top_left + math.random() / math.max(scale / 2, 10)
    w_top_right = w_top_right * w_top_right + math.random() / math.max(scale / 2, 10)
    w_bottom_left = w_bottom_left * w_bottom_left + math.random() / math.max(scale / 2, 10)
    w_bottom_right = w_bottom_right * w_bottom_right + math.random() / math.max(scale / 2, 10)
    --get codes
    local c_top_left = tile_data[top % height][left % width]
    local c_top_right = tile_data[top % height][right % width]
    local c_bottom_left = tile_data[bottom % height][left % width]
    local c_bottom_right = tile_data[bottom % height][right % width]
    --calculate total weights for codes
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
    if string.match(tile_map[code], 'dirt') then
        tile_map[code] = dirt[random(1, dirt_n)]
    end
    return tile_map[code]
end

function Public.AllLand()
    local function get(x, y)
        return true
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.NoLand()
    local function get(x, y)
        return false
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Square(radius)
    local r = radius or 32
    local function get(x, y)
        return x >= -r and y >= -r and x < r and y < r
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

-- Includes (x1, y1) and excludes (x1, y2)
function Public.Rectangle(x1, y1, x2, y2)
    local function get(x, y)
        return (x >= x1) and (x < x2) and (y >= y1) and (y < y2)
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Circle(radius, centerx, centery)
    local r = radius or 32
    local r2 = r * r
    local cx = centerx or 0
    local cy = centery or 0
    local function get(x, y)
        return ((x - cx) * (x - cx)) + ((y - cy) * (y - cy)) < r2
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Halfplane()
    local function get(x, y)
        return (x >= 0)
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Quarterplane()
    local function get(x, y)
        return (x >= 0) and (y >= 0)
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Strip(width)
    local n = width or 1
    local function get(x, y)
        return (math.abs(y) * 2) < n
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Cross(width)
    local n = width or 1
    local function get(x, y)
        return (math.abs(x) * 2 < n) or (math.abs(y) * 2 < n)
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Comb()
    local function get(x, y)
        if x < -1 then
            return false
        else
            return (x < 2) or ((y % 2) < 1)
        end
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Grid()
    local function get(x, y)
        return ((x % 2) < 1) or ((y % 2) < 1)
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Checkerboard()
    local function get(x, y)
        return ((x % 2) < 1) == ((y % 2) < 1)
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

-- 'ratio' is the ratio of the distance of consecutive spirals from the center
-- 'land' is the proportion of terrain that is land
-- Use the reciprocal of some ratio to make the spiral go the other way
function Public.Spiral(ratio, land)
    local r = ratio or 1.4
    local l = land or 0.5
    local lr = math.log(r)
    local function get(x, y)
        local n = (x * x) + (y * y)
        if n < 10 then
            return true
        else
            -- Very irritatingly Lua makes a backwards incompatible
            -- change in arctan between 5.2 and 5.3 that makes it impossible
            -- to write code that is correct in both versions. We are using
            -- 5.2 here.
            return (((math.atan2(y, x) / math.pi) + (math.log(n) / lr)) % 2) < (l * 2)
        end
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

-- 'ratio' is the ratio of the distance of consecutive circles from the center
-- 'land' is the proportion of terrain that is land
function Public.ConcentricCircles(ratio, land)
    local r = ratio or 1.4
    local l = land or 0.5
    local lr2 = 2 * math.log(r)
    local function get(x, y)
        local n = (x * x) + (y * y)
        if n < 10 then
            return true
        else
            return ((math.log(n) / lr2) % 1) < l
        end
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

-- 'dist' is the distance between consecutive spirals
-- 'land' is the proportion of terrain that is land
function Public.ArithmeticSpiral(dist, land)
    local d = dist or 40
    local l = land or 0.5
    local function get(x, y)
        local r = math.sqrt((x * x) + (y * y))
        if r < d then
            return true
        else
            return (((math.atan2(y, x) / (2 * math.pi)) + (r / d)) % 1) < l
        end
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

-- 'dist' is the distance between consecutive circles
-- 'land' is the proportion of terrain that is land
function Public.ArithmeticConcentricCircles(dist, land)
    local d = dist or 40
    local l = land or 0.5
    local function get(x, y)
        local r = math.sqrt((x * x) + (y * y))
        return ((r / d) % 1) < l
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.RectSpiral()
    local function get(x, y)
        if math.abs(x) > math.abs(y) or (x + y > 0 and y < x + 2) then
            return ((x + 0.5) % 2) < 1
        else
            return ((y + 0.5) % 2) < 1
        end
    end
    return {create = noop, reload = noop, get = get, output = 'bool'}
end

function Public.Zoom(pattern, f)
    local factor = f or 16
    local pget = pattern.get

    local function get(x, y)
        return pget(x / factor, y / factor)
    end

    return {
        create = pattern.create,
        reload = pattern.reload,
        get = get,
        output = pattern.output
    }
end

function Public.on_chunk(x, y, data)
    local p = {x = data.x, y = data.y}
    local tiles = data.tiles

    local tile = get_pos(data.x, data.y)
    local t = Public.Zoom(tile)
    if tile ~= nil then
        if t.get(p.x, p.y) then
            tiles[#tiles + 1] = {name = tile, position = p}
        else
            tiles[#tiles + 1] = {name = 'out-of-map', position = p}
        end
    end
end

return Public
