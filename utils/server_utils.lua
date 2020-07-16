local Print = require('utils.print_override')
local Public = {}

local concat = table.concat
local data_set_tag = '[DATA-SET]'
local data_get_all_tag = '[DATA-GET-ALL]'
local raw_print = Print.raw_print

local function double_escape(str)
    -- Excessive escaping because the data is serialized twice.
    return str:gsub('\\', '\\\\\\\\'):gsub('"', '\\\\\\"'):gsub('\n', '\\\\n')
end

function Public.set_data(data_set, key, value)
    local message
    local vt = type(value)
    if vt == 'nil' then
        message = concat({data_set_tag, '{data_set:"', data_set, '",key:"', key, '"}'})
    else
        message = concat({data_set_tag, '{data_set:"', data_set, '",key:"', key, '",value:"', value, '"}'})
    end
    raw_print(message)
end

function Public.add_function_to_dataset(dataset, event, handler)
    if dataset and event and handler then
        Public.set_data(dataset, event, handler)
    end
end

function Public.remove_function_to_dataset(dataset, event)
    if dataset and event then
        Public.set_data(dataset, event, nil)
    end
end

function Public.try_get_all_data(data_set, callback_token)
    if type(data_set) ~= 'string' then
        error('data_set must be a string', 2)
    end
    if type(callback_token) ~= 'number' then
        error('callback_token must be a number', 2)
    end

    data_set = double_escape(data_set)

    local message = concat {data_get_all_tag, callback_token, ' {', 'data_set:"', data_set, '"}'}
    raw_print(message)
end

return Public
