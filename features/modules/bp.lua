local Event = require 'utils.event'
local Gui = require 'utils.gui.core'
local Global = require 'utils.global'

local this = {
    config = {},
    config_tmp = {},
    storage = {},
    storage_index = {},
    temporary_ignore = {},
    max_config_size = 16,
    check_distance = true,
    banned_targets = {'landfill'},
    player_upgrade = true
}

Global.register(
    this,
    function(t)
        this = t
    end
)

local function get_config_item(player, index, type)
    if not this.config_tmp[player.name] or index > #this.config_tmp[player.name] or this.config_tmp[player.name][index][type] == '' then
        return nil
    end
    if not game.item_prototypes[this.config_tmp[player.name][index][type]] then
        return nil
    end
    if not game.item_prototypes[this.config_tmp[player.name][index][type]].valid then
        return nil
    end

    return game.item_prototypes[this.config_tmp[player.name][index][type]].name
end

local function gui_restore(player, name)
    local frame = player.gui.screen.upgrade_planner_config_frame
    if not frame then
        return
    end

    local storage = this.storage[player.name][name]
    if not storage and name == 'New storage' then
        storage = {}
    end
    if not storage then
        return
    end

    this.config_tmp[player.name] = {}

    local ruleset_grid = frame['upgrade_planner_ruleset_grid']
    local items = game.item_prototypes
    for i = 1, this.max_config_size do
        if i > #storage then
            this.config_tmp[player.name][i] = {from = '', to = ''}
        else
            local player_storage = this.storage[player.name][name][i]

            this.config_tmp[player.name][i] = {
                from = player_storage.from,
                to = player_storage.to,
                is_module = player_storage.is_module,
                is_rail = player_storage.is_rail,
                from_curved_rail = player_storage.from_curved_rail,
                from_straight_rail = player_storage.from_straight_rail,
                to_curved_rail = player_storage.to_curved_rail,
                to_straight_rail = player_storage.to_straight_rail
            }
        end

        local from = get_config_item(player, i, 'from')
        local tooltip = ''
        if (from) then
            tooltip = items[from].localised_name
        end

        ruleset_grid['upgrade_planner_from_' .. i].elem_value = from
        ruleset_grid['upgrade_planner_from_' .. i].tooltip = tooltip

        local to = get_config_item(player, i, 'to')
        if (to) then
            tooltip = items[to].localised_name
        end

        ruleset_grid['upgrade_planner_to_' .. i].elem_value = to
        ruleset_grid['upgrade_planner_to_' .. i].tooltip = tooltip
    end
end

local function gui_open_frame(player)
    local flow = player.gui.screen

    local frame = flow.upgrade_planner_config_frame

    if frame then
        frame.destroy()
        this.config_tmp[player.name] = nil
        return
    end

    this.config[player.name] = this.config[player.name] or {}

    this.config_tmp[player.name] = {}

    for i = 1, this.max_config_size do
        if i > #this.config[player.name] then
            this.config_tmp[player.name][i] = {from = '', to = ''}
        else
            this.config_tmp[player.name][i] = {
                is_module = this.config[player.name][i].is_module,
                is_rail = this.config[player.name][i].is_rail,
                from = this.config[player.name][i].from,
                to = this.config[player.name][i].to,
                from_curved_rail = this.config[player.name][i].from_curved_rail,
                from_straight_rail = this.config[player.name][i].from_straight_rail,
                to_curved_rail = this.config[player.name][i].to_curved_rail,
                to_straight_rail = this.config[player.name][i].to_straight_rail
            }
        end
    end

    frame =
        flow.add {
        type = 'frame',
        caption = 'Upgrade Planner',
        name = 'upgrade_planner_config_frame',
        direction = 'vertical'
    }
    frame.auto_center = true

    local storage_flow = frame.add {type = 'table', name = 'upgrade_planner_storage_flow', column_count = 3}

    local drop_down = storage_flow.add {type = 'drop-down', name = 'upgrade_planner_drop_down'}

    drop_down.style.minimal_width = 164
    drop_down.style.maximal_width = 0

    for key, _ in pairs(this.storage[player.name]) do
        drop_down.add_item(key)
    end
    if not this.storage[player.name]['New storage'] then
        drop_down.add_item('New storage')
    end
    local items = drop_down.items
    local index = math.min(this.storage_index[player.name], #items)
    index = math.max(index, 1)
    drop_down.selected_index = index
    this.storage_index[player.name] = index
    local storage_to_restore = drop_down.get_item(drop_down.selected_index)
    local rename_button =
        storage_flow.add {
        type = 'sprite-button',
        name = 'upgrade_planner_storage_rename',
        sprite = 'utility/rename_icon_normal',
        tooltip = 'Rename Storage'
    }
    rename_button.style = 'slot_button'
    rename_button.style.maximal_width = 24
    rename_button.style.minimal_width = 24
    rename_button.style.maximal_height = 24
    rename_button.style.minimal_height = 24
    local remove_button =
        storage_flow.add {
        type = 'sprite-button',
        name = 'upgrade_planner_storage_delete',
        sprite = 'utility/trash',
        tooltip = 'Delete Storage'
    }
    remove_button.style = 'back_button'
    remove_button.style.maximal_width = 24
    remove_button.style.minimal_width = 24
    remove_button.style.maximal_height = 24
    remove_button.style.minimal_height = 24
    local rename_field =
        storage_flow.add {
        type = 'textfield',
        name = 'upgrade_planner_storage_rename_textfield',
        text = drop_down.get_item(drop_down.selected_index)
    }
    rename_field.visible = false
    local confirm_button =
        storage_flow.add {
        type = 'sprite-button',
        name = 'upgrade_planner_storage_confirm',
        sprite = 'utility/confirm_slot',
        tooltip = 'Confirm Storage Name'
    }
    confirm_button.style = 'confirm_button'
    confirm_button.style.maximal_width = 24
    confirm_button.style.minimal_width = 24
    confirm_button.style.maximal_height = 24
    confirm_button.style.minimal_height = 24
    confirm_button.visible = false
    local cancel_button =
        storage_flow.add {
        type = 'sprite-button',
        name = 'upgrade_planner_storage_cancel',
        sprite = 'utility/set_bar_slot',
        tooltip = 'Cancel'
    }
    cancel_button.style = 'back_button'
    cancel_button.style.maximal_width = 24
    cancel_button.style.minimal_width = 24
    cancel_button.style.maximal_height = 24
    cancel_button.style.minimal_height = 24
    cancel_button.visible = false
    local ruleset_grid =
        frame.add {
        type = 'table',
        column_count = 6,
        name = 'upgrade_planner_ruleset_grid',
        style = 'slot_table'
    }

    ruleset_grid.add {
        type = 'label',
        caption = 'From'
    }
    ruleset_grid.add {
        type = 'label',
        caption = 'To'
    }
    ruleset_grid.add {
        type = 'label',
        caption = 'Clear',
        ''
    }
    ruleset_grid.add {
        type = 'label',
        caption = 'From'
    }
    ruleset_grid.add {
        type = 'label',
        caption = 'To'
    }
    ruleset_grid.add {
        type = 'label',
        caption = 'Clear',
        ''
    }
    items = game.item_prototypes
    for i = 1, this.max_config_size do
        local tooltip
        local from = get_config_item(player, i, 'from')
        if from then
            tooltip = items[from].localised_name
        end
        local elem =
            ruleset_grid.add {
            type = 'choose-elem-button',
            name = 'upgrade_planner_from_' .. i,
            style = 'slot_button',
            elem_type = 'item',
            tooltip = tooltip
        }
        elem.elem_value = from
        local to = get_config_item(player, i, 'to')
        if to then
            tooltip = items[to].localised_name
        end
        elem =
            ruleset_grid.add {
            type = 'choose-elem-button',
            name = 'upgrade_planner_to_' .. i,
            elem_type = 'item',
            tooltip = tooltip
        }
        elem.elem_value = to
        ruleset_grid.add {
            type = 'sprite-button',
            name = 'upgrade_planner_clear_' .. i,
            sprite = 'utility/trash',
            tooltip = 'Clear',
            ''
        }
    end

    local button_grid =
        frame.add {
        type = 'table',
        column_count = 4
    }
    button_grid.add {
        type = 'sprite-button',
        name = 'upgrade_blueprint',
        sprite = 'item/blueprint-book',
        tooltip = 'Upgrade BPs',
        style = 'button'
    }
    button_grid.add {
        type = 'sprite-button',
        name = 'give_upgrade_tool',
        sprite = 'item/selection-tool',
        tooltip = 'Receive BP tool',
        style = 'button'
    }
    gui_restore(player, storage_to_restore)
    player.opened = frame
end

local function gui_save_changes(player)
    if this.config_tmp[player.name] then
        this.config[player.name] = {}
        for i = 1, #this.config_tmp[player.name] do
            this.config[player.name][i] = {
                from = this.config_tmp[player.name][i].from,
                to = this.config_tmp[player.name][i].to
            }
        end
    end

    local gui = player.gui.screen.upgrade_planner_config_frame
    if not gui then
        return
    end
    local drop_down = gui.upgrade_planner_storage_flow.children[1]
    local name = drop_down.get_item(this.storage_index[player.name])
    this.storage[player.name][name] = this.config[player.name]
end

local zero_delta = {x = 0, y = 0, origx = 0, origy = 0, posx = 0, posy = 0}
local curved_track_deltas = {
    {x = -3, y = -3, origx = 1, origy = -1, posx = -2, posy = 0},
    {x = 1, y = -3, origx = -1, origy = -1, posx = 0, posy = 0},
    {x = 0.5, y = -3, origx = 1, origy = 1, posx = -2, posy = -2},
    {x = 1, y = 1, origx = 1, origy = -1, posx = -2, posy = 0},
    {x = 1, y = 1, origx = -1, origy = 1, posx = 0, posy = -2},
    {x = -3, y = 1, origx = 1, origy = 1, posx = -2, posy = -2},
    {x = -2.5, y = 1, origx = -1, origy = -1, posx = 0, posy = 0},
    {x = -2.5, y = -3, origx = -1, origy = 1, posx = 0, posy = -2}
}

local function gui_set_rule(player, type, index, element)
    local function get_type(entity)
        if game.entity_prototypes[entity] then
            return game.entity_prototypes[entity].type
        end
        if game.item_prototypes[entity] then
            return game.item_prototypes[entity].type
        end
        return ''
    end
    local function is_exception(from, to)
        local exceptions = {
            {from = 'container', to = 'logistic-container'},
            {from = 'logistic-container', to = 'container'}
        }
        for k, exception in pairs(exceptions) do
            if from == exception.from and to == exception.to then
                return true
            end
        end
        return false
    end
    local name = element.elem_value
    local frame = player.gui.screen.upgrade_planner_config_frame
    local ruleset_grid = frame['upgrade_planner_ruleset_grid']
    local storage_name = element.parent.parent.upgrade_planner_storage_flow.children[1].get_item(this.storage_index[player.name])
    local storage = this.config_tmp[player.name]
    if not frame or not storage then
        return
    end
    local is_module = false
    local is_rail = false
    local curved_rail = nil
    local straight_rail = nil

    if type == 'to' or type == 'from' then
        for _, to_type in pairs(this.banned_targets) do
            if element.elem_value == to_type then
                if storage[index][type] ~= '' then
                    element.elem_value = storage[index][type]
                else
                    element.elem_value = nil
                end
                player.print('Item not valid!')
                return
            end
        end
    end

    if not name then
        ruleset_grid['upgrade_planner_' .. type .. '_' .. index].tooltip = ''
        storage[index][type] = ''
        gui_save_changes(player)
        return
    end

    if name ~= 'deconstruction-planner' or type ~= 'to' then
        local opposite = 'from'
        if type == 'from' then
            opposite = 'to'
            for i = 1, #storage do
                if index ~= i and storage[i].from == name then
                    player.print('Item already set!')
                    gui_restore(player, storage_name)
                    return
                end
            end
        end
        local related = storage[index][opposite]
        if related ~= '' then
            if related == name then
                player.print('Item is the same!')
                gui_restore(player, storage_name)
                return
            end
            if get_type(name) ~= get_type(related) and (not is_exception(get_type(name), get_type(related))) then
                player.print('Item is not the same type!')
                if storage[index][type] ~= '' then
                    element.elem_value = storage[index][type]
                else
                    element.elem_value = nil
                end
                return
            end
        end

        storage[index][type] = name
        storage[index]['is_module'] = is_module
        storage[index]['is_rail'] = is_rail
        storage[index][type .. '_curved_rail'] = curved_rail
        storage[index][type .. '_straight_rail'] = straight_rail

        ruleset_grid['upgrade_planner_' .. type .. '_' .. index].tooltip = game.item_prototypes[name].localised_name
        gui_save_changes(player)
    end
end

local function gui_clear_rule(player, index)
    local frame = player.gui.screen.upgrade_planner_config_frame
    if not frame or not this.config_tmp[player.name] then
        return
    end
    local ruleset_grid = frame['upgrade_planner_ruleset_grid']
    this.config_tmp[player.name][index] = {from = '', to = ''}
    ruleset_grid['upgrade_planner_from_' .. index].elem_value = nil
    ruleset_grid['upgrade_planner_from_' .. index].tooltip = ''
    ruleset_grid['upgrade_planner_to_' .. index].elem_value = nil
    ruleset_grid['upgrade_planner_to_' .. index].tooltip = ''
    gui_save_changes(player)
end

local on_gui_selection_state_changed = function(event)
    local element = event.element

    if not element or not element.valid then
        return
    end
    local player = game.players[event.player_index]

    local name = element.name

    if not string.find(name, 'upgrade_planner_') then
        return
    end

    if element.selected_index > 0 then
        this.storage_index[player.name] = element.selected_index
        name = element.get_item(element.selected_index)
        gui_restore(player, name)
        this.config[player.name] = this.storage[player.name][name]
    end
end

local on_gui_elem_changed = function(event)
    local element = event.element

    if not element or not element.valid then
        return
    end

    local player = game.players[event.player_index]
    local type, index = string.match(element.name, '(%a+)%_(%d+)')
    if type and index then
        if type == 'from' or type == 'to' then
            gui_set_rule(player, type, tonumber(index), element)
        end
    end
end

local function player_upgrade(player, orig_inv_name, belt, inv_name, upgrade, bool, is_curved_rail)
    local item_count = 1
    if not belt then
        return
    end
    if this.temporary_ignore[belt.name] then
        return
    end
    local surface = player.surface
    if is_curved_rail then
        item_count = 4
    end
    if player.get_item_count(inv_name) >= item_count or player.cheat_mode then
        local d = belt.direction
        local f = belt.force
        local p = belt.position
        local inserter_pickup = nil
        local inserter_drop = nil
        local pdel = zero_delta

        if is_curved_rail then
            item_count = 4
            pdel = curved_track_deltas[d + 1]
            p = {x = p.x + pdel.posx, y = p.y + pdel.posy}
        end

        if player.can_reach_entity(belt) or this.check_distance then
            local new_item
            if upgrade ~= 'deconstruction-planner' then
                if belt.type == 'underground-belt' then
                    if belt.neighbours and bool then
                        player_upgrade(player, orig_inv_name, belt.neighbours, inv_name, upgrade, false, is_curved_rail)
                    end
                    new_item =
                        surface.create_entity {
                        name = upgrade,
                        position = p,
                        force = belt.force,
                        fast_replace = true,
                        direction = belt.direction,
                        type = belt.belt_to_ground_type,
                        spill = false
                    }
                elseif belt.type == 'loader' then
                    new_item =
                        surface.create_entity {
                        name = upgrade,
                        position = p,
                        force = belt.force,
                        fast_replace = true,
                        direction = belt.direction,
                        type = belt.loader_type,
                        spill = false
                    }
                else
                    if (belt.type == 'inserter') then
                        inserter_pickup = belt.pickup_position
                        inserter_drop = belt.drop_position
                    end
                    new_item =
                        surface.create_entity {
                        name = upgrade,
                        position = p,
                        force = belt.force,
                        fast_replace = true,
                        direction = belt.direction,
                        spill = false
                    }
                end
                if belt.valid then
                    if new_item then
                        if new_item.valid then
                            new_item.destroy()
                        end
                    end
                    local a = belt.bounding_box

                    player.cursor_stack.set_stack {name = 'blueprint', count = 1}
                    player.cursor_stack.create_blueprint {surface = surface, force = belt.force, area = a}
                    local old_blueprint = player.cursor_stack.get_blueprint_entities()
                    local record_index = nil
                    for index, entity in pairs(old_blueprint) do
                        if (entity.direction == nil) then
                            entity.direction = 0
                        end
                        if (entity.name == belt.name and entity.direction == belt.direction) then
                            record_index = index
                            entity.position.x = pdel.origx
                            entity.position.y = pdel.origy
                        else
                            old_blueprint[index] = nil
                        end
                    end
                    if record_index == nil then
                        player.print('Blueprint index error line ' .. debug.getinfo(1).currentline)
                        return
                    end
                    old_blueprint[record_index].name = upgrade
                    player.cursor_stack.set_stack {name = 'blueprint', count = 1}
                    player.cursor_stack.set_blueprint_entities(old_blueprint)
                    if not player.cheat_mode then
                        player.insert {name = orig_inv_name, count = item_count}
                    end

                    local inventories = {}
                    for index = 1, 10 do
                        if belt.get_inventory(index) ~= nil then
                            inventories[index] = {}
                            inventories[index].name = index
                            inventories[index].contents = belt.get_inventory(index).get_contents()
                        end
                    end

                    belt.destroy()

                    player.cursor_stack.build_blueprint {surface = surface, force_build = true, force = f, position = p}
                    local ghost = surface.find_entities_filtered {area = a, name = 'entity-ghost'}

                    player.remove_item {name = inv_name, count = item_count}
                    if ghost[1] ~= nil then
                        local p_x = player.position.x
                        local p_y = player.position.y

                        while ghost[1] ~= nil do
                            ghost[1].revive()
                            player.teleport({math.random(p_x - 5, p_x + 5), math.random(p_y - 5, p_y + 5)})
                            ghost = surface.find_entities_filtered {area = a, name = 'entity-ghost'}
                        end
                        player.teleport({p_x, p_y})
                    end
                    local assembling = surface.find_entities_filtered {area = a, name = upgrade}
                    if not assembling[1] then
                        player.print("This won't work!")
                        player.cursor_stack.set_stack {name = 'selection-tool', count = 1}
                        return
                    end
                    script.raise_event(defines.events.on_built_entity, {player_index = player.index, created_entity = assembling[1]})

                    for j, items in pairs(inventories) do
                        for l, contents in pairs(items.contents) do
                            if assembling[1] ~= nil then
                                assembling[1].get_inventory(items.name).insert {name = l, count = contents}
                            end
                        end
                    end
                    local proxy = surface.find_entities_filtered {area = a, name = 'item-request-proxy'}
                    if proxy[1] ~= nil then
                        proxy[1].destroy()
                    end
                    player.cursor_stack.set_stack {name = 'selection-tool', count = 1}
                else
                    if (new_item.type == 'inserter') then
                        new_item.pickup_position = inserter_pickup
                        new_item.drop_position = inserter_drop
                    end
                    player.remove_item {name = inv_name, count = item_count}
                end
            else
                belt.destroy()
            end
        else
            surface.create_entity {
                name = 'flying-text',
                position = {belt.position.x - 1.3, belt.position.y - 0.5},
                text = 'Out of range',
                color = {r = 1, g = 0.6, b = 0.6}
            }
        end
    else
        this.temporary_ignore[orig_inv_name] = true
        surface.create_entity {
            name = 'flying-text',
            position = {belt.position.x - 1.3, belt.position.y - 0.5},
            text = "You don't have enough items to do this!",
            color = {r = 1, g = 0.6, b = 0.6}
        }
    end
end

local function player_module_upgrade(player, belt, from, to)
    local surface = player.surface
    local m_inv = belt.get_module_inventory()
    if m_inv then
        local m_content = m_inv.get_contents()
        for item, count in pairs(m_content) do
            if player.get_item_count(to) >= count or player.cheat_mode then
                if (item == from) then
                    m_inv.remove({name = from, count = count})
                    m_inv.insert({name = to, count = count})
                    player.remove_item({name = to, count = count})
                end
            else
                surface.create_entity {
                    name = 'flying-text',
                    position = {belt.position.x - 1.3, belt.position.y - 0.5},
                    text = "You don't have enough items to do this!",
                    color = {r = 1, g = 0.6, b = 0.6}
                }
                this.temporary_ignore[from] = true
            end
        end
    end
end

local on_player_selected_area = function(event)
    if event.item ~= 'selection-tool' then
        return
    end

    local player = game.players[event.player_index]
    local config = this.config[player.name]
    if config == nil then
        return
    end

    local surface = player.surface
    if event.tiles then
        local new_tiles = {}
        for _, tile in pairs(event.tiles) do
            local proto = game.tile_prototypes[tile.name]
            local placed_by_list = proto.items_to_place_this
            for _, entry in pairs(config) do
                if entry and entry.from then
                    if not this.temporary_ignore[entry.from] then
                        for _, placed_by in pairs(placed_by_list) do
                            if placed_by.name == entry.from then
                                if player.get_item_count(entry.from) > 0 or player.cheat_mode then
                                    new_tiles[#new_tiles + 1] = {
                                        name = game.item_prototypes[entry.to].place_as_tile_result.result.name,
                                        position = tile.position
                                    }
                                    player.remove_item {name = entry.to, count = 1}
                                else
                                    this.temporary_ignore[entry.from] = true
                                    surface.create_entity {
                                        name = 'flying-text',
                                        position = {tile.position.x - 1.3, tile.position.y - 0.5},
                                        text = "You don't have enough items to do this!",
                                        color = {r = 1, g = 0.6, b = 0.6}
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
        if #new_tiles > 0 then
            surface.set_tiles(new_tiles)
            local positions = {}
            for _, tile in pairs(new_tiles) do
                positions[#positions + 1] = tile.position
            end
            script.raise_event(defines.events.on_player_mined_tile, {player_index = player.index, surface_index = surface.index, positions = positions})
            script.raise_event(defines.events.on_player_built_tile, {player_index = player.index, surface_index = surface.index, positions = positions})
        end
    end

    for k, belt in pairs(event.entities) do
        if belt.valid then
            local upgrade = nil
            local upgrade_to = nil
            local is_curved_rail = false
            for i = 1, #config do
                if this.temporary_ignore[config[i].from] then
                    break
                end

                if config[i].is_rail then
                    if config[i].from_curved_rail == belt.name then
                        upgrade = config[i]
                        upgrade_to = config[i].to_curved_rail
                        is_curved_rail = true
                        break
                    elseif config[i].from_straight_rail == belt.name then
                        upgrade = config[i]
                        upgrade_to = config[i].to_straight_rail
                        break
                    end
                elseif config[i].is_module then
                    if player.get_item_count(config[i].to) > 0 or player.cheat_mode then
                        player_module_upgrade(player, belt, config[i].from, config[i].to)
                    else
                        this.temporary_ignore[config[i].from] = true
                        surface.create_entity {
                            name = 'flying-text',
                            position = {belt.position.x - 1.3, belt.position.y - 0.5},
                            text = "You don't have enough items to do this!",
                            color = {r = 1, g = 0.6, b = 0.6}
                        }
                    end
                else
                    if config[i].from == belt.name then
                        upgrade = config[i]
                        upgrade_to = config[i].to
                        break
                    end
                end
            end
            if upgrade_to ~= nil then
                player_upgrade(player, upgrade.from, belt, upgrade.to, upgrade_to, true, is_curved_rail)
            end
        end
    end
    for k, _ in pairs(this.temporary_ignore) do
        this.temporary_ignore[k] = nil
    end
end

local function get_hashmap(config)
    local items = game.item_prototypes
    local hashmap = {}
    for k, entry in pairs(config) do
        local item_from = items[entry.from]
        local item_to = items[entry.to]
        if item_to and item_from then
            hashmap[entry.from] = {item_to = entry.to}
            local entity_from = item_from.place_result
            local entity_to = item_to.place_result
            if entity_from and entity_to then
                hashmap[entity_from.name] = {entity_to = entity_to.name, item_to = entry.to, item_from = entry.from}
            end
            if item_from.type == 'rail-planner' and item_to.type == 'rail-planner' then
                hashmap[item_from.straight_rail.name] = {
                    entity_to = item_to.straight_rail.name,
                    item_to = entry.to,
                    item_from = entry.from
                }
                hashmap[item_from.curved_rail.name] = {
                    entity_to = item_to.curved_rail.name,
                    item_to = entry.to,
                    item_from = entry.from,
                    item_amount = 4
                }
            end
        end
    end
    return hashmap
end

local function update_blueprint_entities(stack, hashmap)
    if not (stack and stack.valid and stack.valid_for_read and stack.is_blueprint_setup()) then
        return
    end
    local entities = stack.get_blueprint_entities()
    if entities then
        for k, entity in pairs(entities) do
            local new = hashmap[entity.name]
            if new and new.entity_to then
                entities[k].name = new.entity_to
            end
            if entity.items then
                local new_items = {}
                for item, count in pairs(entity.items) do
                    new_items[item] = count
                end
                for item, count in pairs(entity.items) do
                    new = hashmap[item]
                    if new and new.item_to then
                        if new_items[new.item_to] then
                            new_items[new.item_to] = new_items[new.item_to] + count
                        else
                            new_items[new.item_to] = count
                        end
                        new_items[item] = new_items[item] - count
                    end
                end
                for item, count in pairs(new_items) do
                    if count == 0 then
                        new_items[item] = nil
                    end
                end
                entities[k].items = new_items
            end
        end
        stack.set_blueprint_entities(entities)
    end
    local tiles = stack.get_blueprint_tiles()
    if tiles then
        local tile_prototypes = game.tile_prototypes
        local items = game.item_prototypes
        for k, tile in pairs(tiles) do
            local prototype = tile_prototypes[tile.name]
            local items_to_place = prototype.items_to_place_this
            local item = nil
            if items_to_place then
                for name, _ in pairs(items_to_place) do
                    item = hashmap[name]
                    if item and item.item_to then
                        break
                    end
                end
            end
            if item then
                local tile_item = items[item.item_to]
                if tile_item then
                    local result = tile_item.place_as_tile_result
                    if result then
                        local new_tile = tile_prototypes[result.result.name]
                        if new_tile and new_tile.can_be_part_of_blueprint then
                            tiles[k].name = result.result.name
                        end
                    end
                end
            end
        end
        stack.set_blueprint_tiles(tiles)
    end
    local icons = stack.blueprint_icons
    for k, icon in pairs(icons) do
        local new = hashmap[icon.signal.name]
        if new and new.item_to then
            icons[k].signal.name = new.item_to
        end
    end
    stack.blueprint_icons = icons
    return true
end

local function upgrade_blueprint(player)
    local stack = player.cursor_stack
    if not (stack.valid and stack.valid_for_read) then
        return
    end

    local config = this.config[player.name]
    if not config then
        return
    end
    local hashmap = get_hashmap(config)

    if stack.is_blueprint then
        if update_blueprint_entities(stack, hashmap) then
            player.print('Blueprint upgrade successful!')
        end
        return
    end

    if stack.is_blueprint_book then
        local inventory = stack.get_inventory(defines.inventory.item_main)
        local success = 0
        for k = 1, #inventory do
            if update_blueprint_entities(inventory[k], hashmap) then
                success = success + 1
            end
        end
        player.print('Blueprint book upgrade successful!', success)
        return
    end
end

local on_gui_click = function(event)
    local element = event.element

    if not element or not element.valid then
        return
    end

    local name = element.name
    local player = game.players[event.player_index]

    if name == 'upgrade_blueprint' then
        upgrade_blueprint(player)
        return
    end
    if name == 'give_upgrade_tool' then
        player.clear_cursor()
        if player.get_item_count('selection-tool') > 0 then
            player.remove_item {name = 'selection-tool', count = 999}
        end
        player.cursor_stack.set_stack({name = 'selection-tool'})

        return
    end

    if name == 'upgrade_planner_storage_rename' then
        local children = element.parent.children
        for k, child in pairs(children) do
            child.visible = true
        end
        children[4].text = children[1].get_item(children[1].selected_index)
        if children[4].text == 'New storage' then
            children[4].text = ''
        end
        return
    end

    if name == 'upgrade_planner_storage_cancel' then
        local children = element.parent.children
        for k = 4, 6 do
            children[k].visible = false
        end
        children[4].text = children[1].get_item(children[1].selected_index)
        return
    end

    if name == 'upgrade_planner_storage_confirm' then
        local index = this.storage_index[player.name]
        local children = element.parent.children
        local new_name = children[4].text
        local length = string.len(new_name)
        if length < 1 then
            player.print('Name is too short!')
            return
        end
        for k = 4, 6 do
            children[k].visible = false
        end
        local items = children[1].items
        if index > #items then
            index = #items
        end
        local old_name = items[index]
        if old_name == 'New storage' then
            children[1].add_item('New storage')
        end

        if this.storage[player.name][old_name] then
            this.storage[player.name][new_name] = this.storage[player.name][old_name]
        else
            this.storage[player.name][new_name] = {}
        end
        this.storage[player.name][old_name] = nil

        children[1].set_item(index, new_name)
        children[1].selected_index = 0
        children[1].selected_index = index
        this.storage_index[player.name] = index
        return
    end

    if name == 'upgrade_planner_storage_delete' then
        local children = element.parent.children
        local dropdown = children[1]
        local index = dropdown.selected_index
        name = dropdown.get_item(index)
        this.storage[player.name][name] = nil
        if name ~= 'New storage' then
            dropdown.remove_item(index)
        end
        if index > 1 then
            index = index - 1
        end
        dropdown.selected_index = 0
        dropdown.selected_index = index
        gui_restore(player, dropdown.get_item(index))
        this.storage_index[player.name] = index
        return
    end
    if name == 'upgrade_planner_config_button' then
        gui_open_frame(player)
        return
    end
    if name == 'upgrade_planner_frame_close' then
        player.opened.destroy()
        gui_open_frame(player)
        return
    end

    local type, index = string.match(name, '(%a+)%_(%d+)')
    if type and index then
        if type == 'clear' then
            gui_clear_rule(player, tonumber(index))
            return
        end
    end
end

Event.add(defines.events.on_gui_click, on_gui_click)

Event.add(
    defines.events.on_player_joined_game,
    function(event)
        local player = game.players[event.player_index]

        if not player.admin then
            return
        end

        if not this.storage[player.name] then
            this.storage[player.name] = {}
        end

        if not this.storage_index[player.name] then
            this.storage_index[player.name] = 1
        end

        if Gui.get_button_flow(player)['upgrade_planner_config_button'] then
            return
        end
        local b =
            Gui.get_button_flow(player).add {
            type = 'sprite-button',
            sprite = 'item/fast-transport-belt',
            name = 'upgrade_planner_config_button',
            tooltip = 'Upgrade planner',
            style = Gui.button_style
        }
        Gui.allow_player_to_toggle(b.name)
    end
)

Event.add(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
Event.add(defines.events.on_gui_elem_changed, on_gui_elem_changed)

Event.add(
    defines.events.on_player_selected_area,
    function(event)
        if this.player_upgrade then
            on_player_selected_area(event)
        end
    end
)
