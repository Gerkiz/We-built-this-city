local floor = math.floor

local Public = {}
Public.scale = 2

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

function Public.decompress(pic)
    local data = pic.data
    local height = pic.height
    local width = pic.width
    local decompressed = {}

    for y = 1, height do
        local row = data[y]
        local u_row = {}
        decompressed[y] = u_row
        local x = 1
        for index = 1, #row, 2 do
            local pixel = tile_map[row[index]]
            local count = row[index + 1]
            for _ = 1, count do
                u_row[x] = pixel
                x = x + 1
            end
        end
    end

    return {
        data = decompressed,
        width = width,
        height = height
    }
end

function Public.Build(pic)
    local data = pic.data
    local height = pic.height
    local width = pic.width

    -- the plus one is because lua tables are one based.
    local half_width = floor(width / 2) + 1
    local half_height = floor(height / 2) + 1
    return function(x, y)
        x = x / Public.scale
        y = y / Public.scale
        x = floor(x)
        y = floor(y)
        local x2 = x + half_width
        local y2 = y + half_height

        if y2 > 0 and y2 <= height and x2 > 0 and x2 <= width then
            return data[y2][x2]
        end
    end
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

function Public.flip_x(shape)
    return function(x, y, world)
        return shape(-x, y, world)
    end
end

function Public.translate(shape, x_offset, y_offset)
    return function(x, y, world)
        return shape(x - x_offset, y - y_offset, world)
    end
end

function Public.flip_y(shape)
    return function(x, y, world)
        return shape(x, -y, world)
    end
end

function Public.flip_xy(shape)
    return function(x, y, world)
        return shape(-x, -y, world)
    end
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

function Public.grid_pattern(pattern, columns, rows, width, height)
    local half_width = width / 2
    local half_height = height / 2

    return function(x, y, world)
        local y2 = ((y + half_height) % height) - half_height
        local row_pos = floor(y / height + 0.5)
        local row_i = row_pos % rows + 1
        local row = pattern[row_i] or {}

        local x2 = ((x + half_width) % width) - half_width
        local col_pos = floor(x / width + 0.5)
        local col_i = col_pos % columns + 1

        local shape = row[col_i] or false
        return shape(x2, y2, world)
    end
end

return Public
