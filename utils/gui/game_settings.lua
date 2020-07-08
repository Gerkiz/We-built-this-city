local Gui = require 'utils.gui.core'
local Modifiers = require 'utils.player_modifiers'
local TaskTable = require 'utils.task_table'
local Event = require 'utils.event'

if Gui.popup then
    Gui.popup._load()
end

local close_element = function(data)
    if data and data.valid then
        data.parent.parent['game-settings-are-you-sure'].state = false
        data.parent.visible = false
        data.state = false
    end
end

local hide_element = function(data)
    if data and data.valid then
        data.state = false
        data.parent.sure.visible = false
    end
end

local add_tick = function(callback, data, tick)
    local this = TaskTable.get('ticker')
    if not this[game.tick + tick] then
        this[game.tick + tick] = {}
    end
    this[game.tick + tick][#this[game.tick + tick] + 1] = {
        callback = callback,
        data = data
    }
end

local basic_settings = {
    {type = 'slider', object = 'force', key = 'manual_mining_speed_modifier', name = 'mining-speed', min = 0, max = 30},
    {type = 'slider', object = 'force', key = 'manual_crafting_speed_modifier', name = 'craft-speed', min = 0, max = 50},
    {
        type = 'slider',
        object = 'force',
        key = 'character_running_speed_modifier',
        name = 'running-speed',
        min = 0,
        max = 10
    },
    {
        type = 'slider',
        object = 'force',
        key = 'character_build_distance_bonus',
        name = 'build-distance',
        min = 0,
        max = 50
    },
    {
        type = 'slider',
        object = 'force',
        key = 'character_reach_distance_bonus',
        name = 'reach-distance',
        min = 0,
        max = 50
    },
    {type = 'slider', object = 'force', key = 'worker_robots_speed_modifier', name = 'bot-speed', min = 0, max = 20},
    {type = 'slider', object = 'force', key = 'worker_robots_battery_modifier', name = 'bot-battery', min = 0, max = 20},
    {type = 'slider', object = 'force', key = 'worker_robots_storage_bonus', name = 'bot-storage', min = 0, max = 20},
    {type = 'slider', object = 'force', key = 'laboratory_speed_modifier', name = 'lab-speed', min = 0, max = 40},
    {type = 'slider', object = 'force', key = 'stack_inserter_capacity_bonus', name = 'stack-bonus', min = 1, max = 40}
}

local advanced_settings = {
    {
        type = 'slider',
        object = 'force',
        key = 'character_inventory_slots_bonus',
        name = 'inventory-size',
        min = 0,
        max = 1000
    },
    {
        type = 'slider',
        object = 'force',
        key = 'mining_drill_productivity_bonus',
        name = 'mining-prod',
        min = 0,
        max = 10
    },
    {type = 'slider', object = 'game', key = 'speed', name = 'game-speed', min = 0.01, max = 5},
    {type = 'function', object = 'game', key = 'server_save', name = 'save'},
    {type = 'function', object = 'force', key = 'reset_technology_effects', name = 'reload-effects'},
    {type = 'function', object = 'enemy', key = 'kill_all_units', name = 'kill-biters'},
    {type = 'function', object = 'force', key = 'rechart', name = 'reload-map'},
    {type = 'function', object = 'game', key = 'force_crc', name = 'crc'},
    {type = 'function', object = 'force', key = 'reset', name = 'reset-force'}
}

local personal_settings = {
    {
        type = 'slider',
        object = 'player',
        key = 'character_resource_reach_distance_bonus',
        name = 'reach-bonus',
        min = 0,
        max = 30
    },
    {
        type = 'slider',
        object = 'player',
        key = 'character_mining_speed_modifier',
        name = 'mining-speed',
        min = 0,
        max = 30
    },
    {
        type = 'slider',
        object = 'player',
        key = 'character_crafting_speed_modifier',
        name = 'craft-speed',
        min = 0,
        max = 30
    },
    {
        type = 'slider',
        object = 'player',
        key = 'character_running_speed_modifier',
        name = 'running-speed',
        min = 0,
        max = 10
    },
    {
        type = 'slider',
        object = 'player',
        key = 'character_build_distance_bonus',
        name = 'build-distance',
        min = 0,
        max = 50
    },
    {
        type = 'slider',
        object = 'player',
        key = 'character_reach_distance_bonus',
        name = 'reach-distance',
        min = 0,
        max = 50
    },
    {
        type = 'slider',
        object = 'player',
        key = 'character_inventory_slots_bonus',
        name = 'inventory-size',
        min = 0,
        max = 1000
    },
    {type = 'slider', object = 'player', key = 'character_health_bonus', name = 'health', min = 0, max = 5000}
}

local _root_list = {
    basic_settings = basic_settings,
    advanced_settings = advanced_settings,
    personal_settings = personal_settings
}

local function _get_data(root_frame)
    local object = root_frame.name
    local key = root_frame.setting_name.caption
    for _, setting in pairs(_root_list[object]) do
        if key == setting.key then
            return setting
        end
    end
end

local function _object_list(player)
    return {game = game, player = player, force = player.force, enemy = game.forces['enemy']}
end

for name, group in pairs(_root_list) do
    if name == 'personal_settings' then
        for key, setting in pairs(group) do
            local _added = nil
            if setting.type == 'slider' then
                _added =
                    Gui.inputs.add_slider(
                    'game-settings-' .. setting.name,
                    'horizontal',
                    setting.min,
                    setting.max,
                    0.10,
                    function(player, root_frame)
                        local data = _get_data(root_frame)
                        local objects = _object_list(player)
                        local object = objects[data.object]
                        return object[data.key] or 1
                    end,
                    function(player, value, _, element)
                        local p_modifer = Modifiers.get_table()
                        local _a = p_modifer
                        local data = _get_data(element.parent)
                        local objects = _object_list(player)
                        local object = objects[data.object]
                        local _caption = string.format('%.2f', value)
                        if value > 2 then
                            _caption = string.format('%.2f', math.floor(value))
                        end
                        object[data.key] = tonumber(_caption)
                        if not _a[player.index][data.key] then
                            goto continue
                        end
                        _a[player.index][data.key]['bonus'] = tonumber(_caption)
                        ::continue::
                        element.parent.counter.caption = _caption
                    end
                )
            elseif setting.type == 'function' then
                _added =
                    Gui.inputs.add_checkbox(
                    'game-settings-' .. setting.name,
                    true,
                    nil,
                    false,
                    function(player, element)
                        local data = _get_data(element.parent.parent)
                        local objects = _object_list(player)
                        local object = objects[data.object]
                        pcall(object[data.key], unpack(data.params))
                        add_tick('close_element', element, 60)
                    end
                )
                if not setting.params then
                    setting.params = {}
                end
            end
            setting._loaded = _added
            setting._group = name
        end
    else
        for key, setting in pairs(group) do
            local _added = nil
            if setting.type == 'slider' then
                _added =
                    Gui.inputs.add_slider(
                    'game-settings-' .. setting.name,
                    'horizontal',
                    setting.min,
                    setting.max,
                    0.10,
                    function(player, root_frame)
                        local data = _get_data(root_frame)
                        local objects = _object_list(player)
                        local object = objects[data.object]
                        return object[data.key] or 1
                    end,
                    function(player, value, _, element)
                        local data = _get_data(element.parent)
                        local objects = _object_list(player)
                        local object = objects[data.object]
                        local _caption = string.format('%.2f', value)
                        if value > 2 then
                            _caption = string.format('%.2f', math.floor(value))
                        end
                        --if object[data.key]
                        object[data.key] = tonumber(_caption)
                        element.parent.counter.caption = _caption
                    end
                )
            elseif setting.type == 'function' then
                _added =
                    Gui.inputs.add_checkbox(
                    'game-settings-' .. setting.name,
                    true,
                    nil,
                    false,
                    function(player, element)
                        local data = _get_data(element.parent.parent)
                        local objects = _object_list(player)
                        local object = objects[data.object]
                        pcall(object[data.key], unpack(data.params))
                        add_tick('close_element', element, 60)
                    end
                )
                if not setting.params then
                    setting.params = {}
                end
            end
            setting._loaded = _added
            setting._group = name
        end
    end
end

local are_you_sure =
    Gui.inputs.add_checkbox(
    'game-settings-are-you-sure',
    true,
    nil,
    false,
    function(_, element)
        element.parent.sure.visible = true
        add_tick('hide_element', element, 600)
    end
)

local function _draw_setting(frame, setting)
    frame = frame.add {type = 'flow'}
    frame =
        frame.add {
        type = 'flow',
        name = setting._group
    }
    frame.add {
        type = 'label',
        caption = {'game-settings.effect-' .. setting.name},
        style = 'caption_label'
    }
    frame.add {
            type = 'label',
            caption = setting.key,
            name = 'setting_name'
        }.visible = false
    if setting.type == 'slider' then
        local slider = setting._loaded:draw(frame)
        slider.style.width = 300
        local _caption = string.format('%.2f', slider.slider_value)
        if slider.slider_value > 2 then
            _caption = tostring(math.floor(slider.slider_value))
        end
        frame.add {
            type = 'label',
            name = 'counter',
            caption = _caption
        }
    elseif setting.type == 'function' then
        are_you_sure:draw(frame)
        local flow = frame.add {type = 'flow', name = 'sure'}
        flow.visible = false
        flow.add {
            type = 'label',
            caption = {'game-settings.sure'},
            style = 'bold_red_label'
        }
        setting._loaded:draw(flow)
    end
end

Gui.center.add {
    name = 'game-settings',
    caption = 'utility/no_building_material_icon',
    tooltip = {'game-settings.tooltip'}
}:add_tab(
    'basic',
    {'game-settings.basic-name'},
    {'game-settings.basic-name'},
    function(frame)
        frame.add {
                type = 'label',
                caption = {'game-settings.basic-message'}
            }.style.single_line = false
        for _, setting in pairs(basic_settings) do
            _draw_setting(frame, setting)
        end
    end
):add_tab(
    'advanced',
    {'game-settings.advanced-name'},
    {'game-settings.advanced-tooltip'},
    function(frame)
        frame.add {
                type = 'label',
                caption = {'game-settings.advanced-message'}
            }.style.single_line = false
        for _, setting in pairs(advanced_settings) do
            _draw_setting(frame, setting)
        end
    end
):add_tab(
    'personal',
    {'game-settings.personal-name'},
    {'game-settings.personal-tooltip'},
    function(frame)
        frame.add {
                type = 'label',
                caption = {'game-settings.personal-message'}
            }.style.single_line = false
        for _, setting in pairs(personal_settings) do
            _draw_setting(frame, setting)
        end
    end
)

Event.add(
    defines.events.on_tick,
    function()
        local this = TaskTable.get('ticker')
        if not this[game.tick] then
            return
        end
        for _, token in pairs(this[game.tick]) do
            local callback = token.callback
            local data = token.data
            if callback == 'close_element' then
                close_element(data)
                this[game.tick] = nil
            elseif callback == 'hide_element' then
                hide_element(data)
                this[game.tick] = nil
            end
        end
    end
)
