-- config tab --

local Gui = require 'utils.gui.main'

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
    end
}

local function add_switch(element, switch_state, name, description_main, description)
    local label
    local t = element.add({type = 'table', column_count = 5})
    label = t.add({type = 'label', caption = 'ON'})
    label.style.padding = 0
    label.style.left_padding = 10
    label.style.font_color = {0.77, 0.77, 0.77}
    local switch = t.add({type = 'switch', name = name})
    switch.switch_state = switch_state
    switch.style.padding = 0
    switch.style.margin = 0
    label = t.add({type = 'label', caption = 'OFF'})
    label.style.padding = 0
    label.style.font_color = {0.70, 0.70, 0.70}

    label = t.add({type = 'label', caption = description_main})
    label.style.padding = 2
    label.style.left_padding = 10
    label.style.minimal_width = 120
    label.style.font = 'heading-2'
    label.style.font_color = {0.88, 0.88, 0.99}

    label = t.add({type = 'label', caption = description})
    label.style.padding = 2
    label.style.left_padding = 10
    label.style.single_line = false
    label.style.font = 'heading-3'
    label.style.font_color = {0.85, 0.85, 0.85}
end

local build_config_gui = (function(player, frame)
    local switch_state
    frame.clear()

    local line_elements = {}

    line_elements[#line_elements + 1] = frame.add({type = 'line'})

    switch_state = 'right'
    if player.spectator then
        switch_state = 'left'
    end
    add_switch(
        frame,
        switch_state,
        'panel_spectator_switch',
        'SpectatorMode',
        'Disables zoom-to-world view noise effect.\nEnvironmental sounds will be based on map view.'
    )

    line_elements[#line_elements + 1] = frame.add({type = 'line'})

    if global.auto_hotbar_enabled then
        switch_state = 'right'
        if global.auto_hotbar_enabled[player.index] then
            switch_state = 'left'
        end
        add_switch(
            frame,
            switch_state,
            'panel_auto_hotbar_switch',
            'AutoHotbar',
            'Automatically fills your hotbar with placeable items.'
        )
        line_elements[#line_elements + 1] = frame.add({type = 'line'})
    end

    if global.scenario_config and global.scenario_config.resource_tiles_new then
        if not player.admin then
            return
        end
        switch_state = 'right'
        for k, v in pairs(global.scenario_config.resource_tiles_new) do
            if v.amount > 10000 then
                switch_state = 'left'
            end
        end
        add_switch(frame, switch_state, 'panel_amount_of_ore', 'AmountOfOre', 'Starting ore: on = 10000, off = 2500.')
        line_elements[#line_elements + 1] = frame.add({type = 'line'})
    end

    if global.scenario_config and global.scenario_config.resource_tiles_new then
        if not player.admin then
            return
        end
        switch_state = 'right'
        for k, v in pairs(global.scenario_config.resource_tiles_new) do
            if v.size > 20 then
                switch_state = 'left'
            end
        end
        add_switch(frame, switch_state, 'panel_size_of_ore', 'SizeOfOre', 'Starting ore: on = 25, off = 18.')
        line_elements[#line_elements + 1] = frame.add({type = 'line'})
    end

    if global.scenario_config and global.scenario_config.gen_settings then
        if not player.admin then
            return
        end
        switch_state = 'right'
        if global.scenario_config.gen_settings.trees_enabled == false then
            switch_state = 'left'
        end
        add_switch(frame, switch_state, 'panel_trees_in_starting', 'TreesInStartingArea', 'on = false, off = true.')
        line_elements[#line_elements + 1] = frame.add({type = 'line'})
    end
end)

local function on_gui_click(event)
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end
    if functions[event.element.name] then
        functions[event.element.name](event)
        return
    end
end

Gui.tabs['Config'] = build_config_gui

local event = require 'utils.event'
event.add(defines.events.on_gui_click, on_gui_click)
