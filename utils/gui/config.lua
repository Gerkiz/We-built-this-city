-- config tab --

local Event = require 'utils.event'
local Gui = require 'utils.gui.core'
local SpamProtection = require 'utils.spam_protection'

local functions = {
    ['panel_spectator_switch'] = function(event)
        if event.element.switch_state == 'left' then
            game.players[event.player_index].spectator = true
        else
            game.players[event.player_index].spectator = false
        end
    end,
    ['panel_auto_hotbar_switch'] = function(event)
        if event.element.switch_state == 'left' then
            global.auto_hotbar_enabled[event.player_index] = true
        else
            global.auto_hotbar_enabled[event.player_index] = false
        end
    end,
    ['panel_amount_of_ore'] = function(event)
        if event.element.switch_state == 'left' then
            for k, v in pairs(global.scenario_config.resource_tiles_new) do
                v.amount = 10000
            end
        else
            for k, v in pairs(global.scenario_config.resource_tiles_new) do
                v.amount = 2500
            end
        end
    end,
    ['panel_size_of_ore'] = function(event)
        if event.element.switch_state == 'left' then
            for k, v in pairs(global.scenario_config.resource_tiles_new) do
                v.size = 35
            end
            global.scenario_config.pos = {{x = -60, y = -45}, {x = -20, y = -45}, {x = 20, y = -45}, {x = 60, y = -45}}
            global.scenario_config.resource_patches_new['crude-oil'].x_offset_start = 85
            global['scenario_config'].water_new.x_offset = -100
        else
            for k, v in pairs(global.scenario_config.resource_tiles_new) do
                v.size = 18
            end
            global.scenario_config.pos = {{x = -5, y = -45}, {x = 20, y = -45}, {x = -30, y = -45}, {x = -56, y = -45}}
            global.scenario_config.resource_patches_new['crude-oil'].x_offset_start = 60
            global['scenario_config'].water_new.x_offset = -90
        end
    end,
    ['panel_trees_in_starting'] = function(event)
        if event.element.switch_state == 'left' then
            global.scenario_config.gen_settings.trees_enabled = false
        else
            global.scenario_config.gen_settings.trees_enabled = true
        end
    end,
    ['panel_scrambled_ores'] = function(event)
        if event.element.switch_state == 'left' then
            global.enable_scramble = true
        else
            global.enable_scramble = false
        end
    end,
    ['panel_town_shape'] = function(event)
        local player = game.get_player(event.player_index)
        local SS = is_loaded('map_gen.multiplayer_spawn.lib.separate_spawns')
        if event.element.switch_state == 'left' then
            global.enable_town_shape = true
            global.enable_buddy_spawn = false
            if SS then
                SS.DisplaySpawnOptions(player, true)
            end
        end
        if event.element.switch_state == 'right' then
            global.enable_town_shape = false
            global.enable_buddy_spawn = true
            if SS then
                SS.DisplaySpawnOptions(player, true)
            end
        end
    end,
    ['panel_towny_isolation'] = function(event)
        local TownyTable = is_loaded('features.modules.towny.table')
        if event.element.switch_state == 'left' then
            if TownyTable then
                TownyTable.set_build_isolation(true)
            end
        end
        if event.element.switch_state == 'right' then
            if TownyTable then
                TownyTable.set_build_isolation(false)
            end
        end
    end
}

local function add_switch(element, switch_state, name, description_main)
    local t = element.add({type = 'table', column_count = 5})
    local main_label = t.add({type = 'label', caption = 'ON'})
    main_label.style.padding = 0
    main_label.style.left_padding = 10
    main_label.style.font_color = {0.77, 0.77, 0.77}
    local switch = t.add({type = 'switch', name = name})
    switch.switch_state = switch_state
    switch.style.padding = 0
    switch.style.margin = 0
    local off_label = t.add({type = 'label', caption = 'OFF'})
    off_label.style.padding = 0
    off_label.style.font_color = {0.70, 0.70, 0.70}

    local spacing_label = t.add({type = 'label'})
    spacing_label.style.padding = 2
    spacing_label.style.left_padding = 10
    spacing_label.style.minimal_width = 120
    spacing_label.style.font = 'heading-2'
    spacing_label.style.font_color = {0.88, 0.88, 0.99}

    local desc_label = t.add({type = 'label', caption = description_main})
    desc_label.style.padding = 2
    desc_label.style.left_padding = 10
    desc_label.style.single_line = false
    desc_label.style.font = 'heading-3'
    desc_label.style.font_color = {0.85, 0.85, 0.85}
    return desc_label
end

local build_config_gui = (function(player, frame)
    frame.clear()

    local line_elements = {}

    line_elements[#line_elements + 1] = frame.add({type = 'line'})

    local panel_spectator_switch_switch = 'right'
    if player.spectator then
        panel_spectator_switch_switch = 'left'
    end
    local spec_label = add_switch(frame, panel_spectator_switch_switch, 'panel_spectator_switch', 'Spectator Mode')
    spec_label.tooltip = 'Disables zoom-to-world view noise effect.\nEnvironmental sounds will be based on map view.'
    line_elements[#line_elements + 1] = frame.add({type = 'line'})

    if global.auto_hotbar_enabled then
        local panel_auto_hotbar_switch_switch = 'right'
        if global.auto_hotbar_enabled[player.index] then
            panel_auto_hotbar_switch_switch = 'left'
        end
        local hotbar_label = add_switch(frame, panel_auto_hotbar_switch_switch, 'panel_auto_hotbar_switch', 'Auto Hotbar')
        hotbar_label.tooltip = 'Automatically fills your hotbar with placeable items.'
        line_elements[#line_elements + 1] = frame.add({type = 'line'})
    end

    if player.admin then
        if global.scenario_config and global.scenario_config.resource_tiles_new then
            local panel_amount_of_ore_switch = 'right'
            for k, v in pairs(global.scenario_config.resource_tiles_new) do
                if v.amount > 10000 then
                    panel_amount_of_ore_switch = 'left'
                end
            end
            local ores_label = add_switch(frame, panel_amount_of_ore_switch, 'panel_amount_of_ore', 'Amount of Ore in starting area?')
            ores_label.tooltip = 'Starting ore: on = 10000, off = 2500.'
            line_elements[#line_elements + 1] = frame.add({type = 'line'})
        end

        if global.scenario_config and global.scenario_config.resource_tiles_new then
            local panel_size_of_ore = 'right'
            for k, v in pairs(global.scenario_config.resource_tiles_new) do
                if v.size > 20 then
                    panel_size_of_ore = 'left'
                end
            end
            local size_of_ores_label = add_switch(frame, panel_size_of_ore, 'panel_size_of_ore', 'Define size of ore in starting area?')
            size_of_ores_label.tooltip = 'Starting ore: on = 25, off = 18.'
            line_elements[#line_elements + 1] = frame.add({type = 'line'})
        end

        if global.scenario_config and global.scenario_config.gen_settings then
            local panel_trees_in_starting_switch = 'right'
            if global.scenario_config.gen_settings.trees_enabled == false then
                panel_trees_in_starting_switch = 'left'
            end
            add_switch(frame, panel_trees_in_starting_switch, 'panel_trees_in_starting', 'Enable trees in starting area?')
            line_elements[#line_elements + 1] = frame.add({type = 'line'})
        end
        if global.scenario_config then
            local panel_scrambled_ores_switch = 'right'
            if global.enable_scramble then
                panel_scrambled_ores_switch = 'left'
            end
            add_switch(frame, panel_scrambled_ores_switch, 'panel_scrambled_ores', 'Enable scrambled ores?')
            line_elements[#line_elements + 1] = frame.add({type = 'line'})
        end
        local TownyTable = is_loaded('features.modules.towny.table')

        if global.scenario_config and TownyTable.get_towny_enabled() then
            local panel_town_shape_switch = 'right'
            if global.enable_town_shape then
                panel_town_shape_switch = 'left'
            end
            add_switch(frame, panel_town_shape_switch, 'panel_town_shape', 'Enable ONLY Town shapes when creating a new base?')
            line_elements[#line_elements + 1] = frame.add({type = 'line'})
        end
        if global.scenario_config and TownyTable.get_towny_enabled() then
            local panel_towny_isolation = 'right'
            if TownyTable.get_build_isolation() then
                panel_towny_isolation = 'left'
            end
            add_switch(frame, panel_towny_isolation, 'panel_towny_isolation', 'Restrict users from building outside of their spawn area?')
            line_elements[#line_elements + 1] = frame.add({type = 'line'})
        end
    end
end)

local function on_gui_switch_state_changed(event)
    local player = game.players[event.player_index]
    if not (player and player.valid) then
        return
    end
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end
    if functions[event.element.name] then
        local is_spamming = SpamProtection.is_spamming(player)
        if is_spamming then
            return
        end
        functions[event.element.name](event)
        return
    end
end

Gui.tabs['Config'] = build_config_gui

Event.add(defines.events.on_gui_switch_state_changed, on_gui_switch_state_changed)
