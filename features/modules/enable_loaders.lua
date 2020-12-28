local Event = require 'utils.event'
local Gui = require 'utils.gui.core'
local Token = require 'utils.token'
local Task = require 'utils.task'

local loader_crafter_frame_for_player_name = Gui.uid_name()
local loader_crafter_frame_for_assembly_machine_name = Gui.uid_name()
local player_craft_loader_1 = Gui.uid_name()
local player_craft_loader_2 = Gui.uid_name()
local player_craft_loader_3 = Gui.uid_name()
local machine_craft_loader_1 = Gui.uid_name()
local machine_craft_loader_2 = Gui.uid_name()
local machine_craft_loader_3 = Gui.uid_name()

local open_gui_token =
    Token.register(
    function(data)
        local player = data.player
        local entity = data.entity
        player.opened = entity
    end
)

local close_gui_token =
    Token.register(
    function(data)
        local player = data.player
        player.opened = nil
    end
)

local function any_loader_enabled(recipes)
    return recipes['loader'].enabled or recipes['fast-loader'].enabled or recipes['express-loader'].enabled
end

local function draw_loader_frame_for_player(parent, player)
    local frame = parent[loader_crafter_frame_for_player_name]
    if frame and frame.valid then
        Gui.destroy(frame)
    end

    local recipes = player.force.recipes
    if not any_loader_enabled(recipes) then
        return
    end

    local anchor = {gui = defines.relative_gui_type.controller_gui, position = defines.relative_gui_position.right}
    frame =
        parent.add {
        type = 'frame',
        name = loader_crafter_frame_for_player_name,
        anchor = anchor,
        direction = 'vertical'
    }

    if recipes['loader'].enabled then
        local button =
            frame.add {
            type = 'choose-elem-button',
            name = player_craft_loader_1,
            elem_type = 'recipe',
            recipe = 'loader'
        }
        button.locked = true
    end

    if recipes['fast-loader'].enabled then
        local button =
            frame.add {
            type = 'choose-elem-button',
            name = player_craft_loader_2,
            elem_type = 'recipe',
            recipe = 'fast-loader'
        }
        button.locked = true
    end

    if recipes['express-loader'].enabled then
        local button =
            frame.add {
            type = 'choose-elem-button',
            name = player_craft_loader_3,
            elem_type = 'recipe',
            recipe = 'express-loader'
        }
        button.locked = true
    end
end

local function draw_loader_frame_for_assembly_machine(parent, entity, player)
    local frame = parent[loader_crafter_frame_for_assembly_machine_name]
    if frame and frame.valid then
        Gui.destroy(frame)
    end

    local recipes = player.force.recipes
    if not any_loader_enabled(recipes) then
        return
    end

    local anchor = {
        gui = defines.relative_gui_type.assembling_machine_select_recipe_gui,
        position = defines.relative_gui_position.right
    }
    frame =
        parent.add {
        type = 'frame',
        name = loader_crafter_frame_for_assembly_machine_name,
        anchor = anchor,
        direction = 'vertical'
    }

    if recipes['loader'].enabled then
        local button =
            frame.add {
            type = 'choose-elem-button',
            name = machine_craft_loader_1,
            elem_type = 'recipe',
            recipe = 'loader'
        }
        button.locked = true
        Gui.set_data(button, entity)
    end

    if recipes['fast-loader'].enabled then
        local button =
            frame.add {
            type = 'choose-elem-button',
            name = machine_craft_loader_2,
            elem_type = 'recipe',
            recipe = 'fast-loader'
        }
        button.locked = true
        Gui.set_data(button, entity)
    end

    if recipes['express-loader'].enabled then
        local button =
            frame.add {
            type = 'choose-elem-button',
            name = machine_craft_loader_3,
            elem_type = 'recipe',
            recipe = 'express-loader'
        }
        button.locked = true
        Gui.set_data(button, entity)
    end
end

local function player_craft_loaders(event, loader_name)
    local player = event.player
    if not player.force.recipes[loader_name].enabled then
        return
    end

    local button = event.button -- int
    local shift = event.shift -- bool

    local count
    if button == defines.mouse_button_type.left then
        if shift then
            count = 4294967295 -- uint highest value. Factorio crafts as many as able
        else
            count = 1
        end
    elseif button == defines.mouse_button_type.right then
        count = 5
    else
        return
    end
    player.begin_crafting {count = count, recipe = loader_name}
end

Gui.on_click(
    player_craft_loader_1,
    function(event)
        player_craft_loaders(event, 'loader')
    end
)

Gui.on_click(
    player_craft_loader_2,
    function(event)
        player_craft_loaders(event, 'fast-loader')
    end
)

Gui.on_click(
    player_craft_loader_3,
    function(event)
        player_craft_loaders(event, 'express-loader')
    end
)

local function set_assembly_machine_recipe(event, loader_name)
    if not event.player.force.recipes[loader_name].enabled then
        return
    end

    local entity = Gui.get_data(event.element)
    entity.set_recipe(loader_name)
    Task.set_timeout_in_ticks(1, close_gui_token, {player = event.player})
    Task.set_timeout_in_ticks(2, open_gui_token, {player = event.player, entity = entity})
end

Gui.on_click(
    machine_craft_loader_1,
    function(event)
        set_assembly_machine_recipe(event, 'loader')
    end
)

Gui.on_click(
    machine_craft_loader_2,
    function(event)
        set_assembly_machine_recipe(event, 'fast-loader')
    end
)

Event.add(
    defines.events.on_gui_opened,
    function(event)
        local player = game.get_player(event.player_index)
        if not player or not player.valid then
            return
        end

        local panel = player.gui.relative
        local entity = event.entity
        if entity and entity.valid and entity.type == 'assembling-machine' then
            draw_loader_frame_for_assembly_machine(panel, entity, player)
        elseif event.gui_type == defines.gui_type.controller then
            draw_loader_frame_for_player(panel, player)
        end
    end
)

Event.add(
    defines.events.on_gui_closed,
    function(event)
        local player = game.get_player(event.player_index)
        if not player or not player.valid then
            return
        end

        local relative = player.gui.relative
        local panel = relative[loader_crafter_frame_for_assembly_machine_name]
        if panel and panel.valid then
            Gui.destroy(panel)
        end

        panel = relative[loader_crafter_frame_for_player_name]
        if panel and panel.valid then
            Gui.destroy(panel)
        end
    end
)
