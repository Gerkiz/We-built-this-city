local Event = require 'utils.event'
local Color = require 'utils.color_presets'
local Global = require 'utils.global'

local this = {
    inf_chests = {},
    inf_storage = {},
    inf_mode = {},
    inf_gui = {},
    storage = {},
    private = {},
    chest = {
        ['infinity-chest'] = true
    },
    stop = false,
    editor = {},
    limits = {},
    shares = {},
    debug = false
}

local default_limit = 100
local default_share_name = 'Share name'
local insert = table.insert
local Public = {}

Public.storage = {}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

function Public.get_table()
    return this
end

function Public.err_msg(string)
    local debug = this.debug
    if not debug then
        return
    end
    log('[Infinity] ' .. string)
end

local function has_value(tab)
    local count = 0
    for _, k in pairs(tab) do
        count = count + 1
    end
    return count
end

local function return_value(tab)
    for index, value in pairs(tab) do
        if value then
            tab[index] = nil
            return value, index
        end
    end
end

local function validate_player(player)
    if not player then
        return false
    end
    if not player.valid then
        return false
    end
    if not player.character then
        return false
    end
    if not player.connected then
        return false
    end
    if not game.players[player.index] then
        return false
    end
    return true
end

local function item_counter(unit_number, count, state)
    local storage = this.inf_storage[unit_number]
    if not storage then
        return
    end

    if not count then
        return storage['count']
    end

    if not storage['count'] then
        storage['count'] = 0
    end
    if state == 'inc' then
        storage['count'] = storage['count'] + count
    elseif state == 'dec' then
        storage['count'] = storage['count'] - count
    end
    if storage['count'] <= 0 then
        storage['count'] = 0
    end
end

local function create_chest(entity, player)
    entity.active = false

    if not this.limits[entity.unit_number] then
        this.limits[entity.unit_number] = {state = true, number = default_limit}
    end
    if not this.shares[entity.unit_number] then
        this.shares[entity.unit_number] = {state = false, name = default_share_name, owner = player.force.index}
    end
    if not this.inf_chests[entity.unit_number] then
        this.inf_chests[entity.unit_number] = {chest = entity, content = entity.get_inventory(defines.inventory.chest), owner = player.force.index}
    end

    if not this.private[entity.unit_number] then
        this.private[entity.unit_number] = {state = false, owner = player.name}
    end
    if not this.inf_mode then
        this.inf_mode[entity.unit_number] = 1
    end

    rendering.draw_text {
        text = '♾',
        surface = entity.surface,
        target = entity,
        target_offset = {0, -0.6},
        scale = 2,
        color = {r = 0, g = 0.6, b = 1},
        alignment = 'center'
    }
end

local function get_share(entity, player)
    if not this.shares[entity.unit_number] then
        create_chest(entity, player)
    end
    if this.shares[entity.unit_number] then
        return this.shares[entity.unit_number]
    end
end

local function restore_chest(entity, player)
    if this.storage[player.index] and has_value(this.storage[player.index].chests) >= 1 then
        if this.stop then
            goto continue
        end
        local chest_index = this.storage[player.index].chests
        local chest_to_place, index = return_value(chest_index)
        local limits = this.storage[player.index].limits[index]
        local shares = this.storage[player.index].limits[index]
        local private = this.storage[player.index].private[index]
        local limit_index = limits.number
        local limit_state = limits.state

        local share_state = shares.state
        local share_name = shares.name
        local share_owner = shares.owner

        this.inf_storage[entity.unit_number] = chest_to_place
        this.limits[entity.unit_number] = {state = limit_state, number = limit_index}
        this.shares[entity.unit_number] = {state = share_state, name = share_name, owner = share_owner}
        this.private[entity.unit_number] = private
        this.storage[player.index].limits[index] = nil
        this.storage[player.index].private[index] = nil
    end
    ::continue::
end

local function built_entity(event)
    local entity = event.created_entity
    if not entity.valid then
        return
    end
    if not this.chest[entity.name] then
        return
    end
    if event.player_index then
        local player = game.get_player(event.player_index)
        restore_chest(entity, player)

        create_chest(entity, player)
    end
end

local function built_entity_robot(event)
    local entity = event.created_entity
    if not entity.valid then
        return
    end
    if not this.chest[entity.name] then
        return
    end
    entity.destroy()
end

local function item(item_name, item_count, inv, unit_number)
    local item_stack = game.item_prototypes[item_name].stack_size
    local diff = item_count - item_stack

    if not this.inf_storage[unit_number] then
        this.inf_storage[unit_number] = {}
    end
    local storage = this.inf_storage[unit_number]

    local mode = this.inf_mode[unit_number]
    if mode == 2 then
        diff = 2 ^ 31
    elseif mode == 4 then
        diff = 2 ^ 31
    end

    if diff > 0 then
        if not storage[item_name] then
            local count = inv.remove({name = item_name, count = diff})
            storage[item_name] = count
            item_counter(unit_number, count, 'inc')
        else
            local count = inv.remove({name = item_name, count = diff})
            storage[item_name] = storage[item_name] + count
            item_counter(unit_number, count, 'inc')
        end
    elseif diff < 0 then
        if not storage[item_name] then
            return
        end
        if storage[item_name] > (diff * -1) then -- more items in central storage and chest has lower
            local to_insert = (diff * -1)
            if to_insert >= item_stack - 1 then
                inv.set_bar(2)
            end
            local inserted = inv.insert({name = item_name, count = (diff * -1)})
            storage[item_name] = storage[item_name] - inserted
            item_counter(unit_number, inserted, 'dec')
        else -- less items in central storage - remove central storage after ins
            inv.insert({name = item_name, count = storage[item_name]})
            storage[item_name] = nil
            item_counter(unit_number, storage[item_name], 'dec')
        end
    end
end

local function balance_items(inv, chest2, content)
    local storage2_inv = chest2.content
    if storage2_inv then
        local content2 = storage2_inv.get_contents()
        for item_name, count in pairs(content) do
            local count2 = content2[item_name] or 0
            local diff = count - count2

            if diff > 1 then
                local count3 = storage2_inv.insert {name = item_name, count = math.floor(diff / 2)}
                if count3 > 0 then
                    inv.remove {name = item_name, count = count3}
                end
            elseif diff < -1 then
                local count4 = inv.insert {name = item_name, count = math.floor(-diff / 2)}
                if count4 > 0 then
                    storage2_inv.remove {name = item_name, count = count4}
                end
            end
        end
        for item_name, count in pairs(content2) do
            if count > 1 and not content[item_name] then
                local count2 = inv.insert {name = item_name, count = math.floor(count / 2)}
                if count2 > 0 then
                    storage2_inv.remove {name = item_name, count = count2}
                end
            end
        end
    end
end

local function remove_link(unit_number)
    local links = this.inf_chests[unit_number].links
    this.shares[unit_number].name = default_share_name
    this.shares[unit_number].state = false
    if links then
        for unit, _ in pairs(links) do
            unit = tonumber(unit)
            if this.inf_chests[unit] then
                this.inf_chests[unit].linked_to = nil
                this.inf_mode[unit] = 1
            end
        end
    end
end

local function remove_chest(unit_number)
    remove_link(unit_number)
    this.inf_chests[unit_number] = nil
    this.inf_storage[unit_number] = nil
    this.limits[unit_number] = nil
    this.shares[unit_number] = nil
    this.private[unit_number] = nil
    this.inf_mode[unit_number] = nil
end

local function is_chest_empty(entity, player)
    local number = entity.unit_number
    local inv = this.inf_mode[number]

    if inv == 2 then
        for k, v in pairs(this.inf_storage) do
            if k == number then
                if not v then
                    goto no_storage
                end
                if (has_value(v) >= 1) then
                    this.storage[player].chests[number] = this.inf_storage[number]
                    this.storage[player].private[number] = this.private[number]
                    this.storage[player].limits[number] = {state = this.limits[number].state, number = this.limits[number].number}
                    this.storage[player].shares[number] = {state = this.shares[number].state, name = this.shares[number].name, owner = this.shares[number].owner}
                end
            end
        end
        ::no_storage::

        remove_chest(number)
    else
        remove_chest(number)
    end
end

local function on_entity_died(event)
    local entity = event.entity
    if not entity then
        return
    end
    if not this.chest[entity.name] then
        return
    end

    local number = entity.unit_number
    remove_chest(number)
end

local function on_pre_player_mined_item(event)
    local entity = event.entity
    local player = game.players[event.player_index]
    if not player then
        return
    end

    if not this.storage[player.index] then
        this.storage[player.index] = {
            chests = {},
            private = {},
            limits = {},
            shares = {}
        }
    end

    if not this.chest[entity.name] then
        return
    end
    is_chest_empty(entity, player.index)
    local data = this.inf_gui[player.name]
    if not data then
        return
    end
    data.frame.destroy()
end

local function update_chest()
    for unit_number, data in pairs(this.inf_chests) do
        if data and not data.chest.valid then
            remove_chest(unit_number)
            goto continue
        end
        local inv = data.content
        local content = inv.get_contents()
        local chest = data.chest
        local linked_to = data.linked_to
        local storage = this.inf_storage[unit_number]

        local mode = this.inf_mode[chest.unit_number]
        if mode then
            if this.limits[unit_number] and this.limits[unit_number].state and storage and storage.count and storage.count >= this.limits[unit_number].number then
                inv.set_bar(1)
            else
                if mode == 1 then
                    inv.set_bar()
                    chest.destructible = false
                    chest.minable = false
                elseif mode == 2 then
                    inv.set_bar(1)
                    chest.destructible = true
                    chest.minable = true
                elseif mode == 3 then
                    chest.destructible = false
                    chest.minable = false
                end
            end
        end

        if linked_to then
            linked_to = tonumber(linked_to)
            local chest2 = this.inf_chests[linked_to]
            if not chest2 then
                goto continue
            end

            if this.inf_storage[unit_number] then
                this.inf_storage[unit_number] = nil
            end

            balance_items(inv, chest2, content, unit_number)

            goto continue
        end

        for item_name, item_count in pairs(content) do
            if item_name ~= 'count' then
                item(item_name, item_count, inv, unit_number)
            end
        end

        if not storage then
            goto continue
        end
        for item_name, _ in pairs(storage) do
            if not content[item_name] then
                if item_name ~= 'count' then
                    item(item_name, 0, inv, unit_number)
                end
            end
        end

        ::continue::
    end
end

local function does_share_exist(player, text)
    for unit_number, data in pairs(this.shares) do
        if data and data.name == text and data.owner == player.force.index then
            return true, unit_number
        end
    end
    return false
end

local function text_changed(event)
    local element = event.element
    if not element then
        return
    end
    if not element.valid then
        return
    end

    local player = game.players[event.player_index]

    local data = this.inf_gui[player.name]
    if not data then
        return
    end

    local name = element.name

    if not data.text_field or not data.text_field.valid then
        return
    end

    if not data.text_field.text then
        return
    end

    if name and name == 'share_name' and element.text then
        local entity = data.entity
        if not entity or not entity.valid then
            return
        end

        local unit_number = entity.unit_number
        if string.len(element.text) > 2 then
            if not does_share_exist(player, element.text) then
                this.shares[unit_number].name = element.text
            else
                player.print('A share with name "' .. element.text .. '" already exists.', Color.fail)
            end
        end
    end

    local value = tonumber(element.text)

    if not value then
        return
    end

    if value ~= '' then
        if name and name == 'limit_number' then
            if value >= 1 then
                data.text_field.text = tostring(value)

                local entity = data.entity
                if not entity or not entity.valid then
                    return
                end

                local unit_number = entity.unit_number

                this.limits[unit_number].number = value
            elseif value <= default_limit then
                return
            end
        end
    end
    this.inf_gui[player.name].updated = false
end

local function gui_opened(event)
    if not event.gui_type == defines.gui_type.entity then
        return
    end
    local entity = event.entity
    if not (entity and entity.valid) then
        return
    end
    if not this.chest[entity.name] then
        return
    end
    local number = entity.unit_number
    local player = game.players[event.player_index]

    if this.private[number] and this.private[number].state then
        if player.name ~= this.private[number].owner and not player.admin then
            player.opened = nil
            return
        end
    end

    local frame =
        player.gui.center.add {
        type = 'frame',
        caption = 'Unlimited Chest',
        direction = 'vertical',
        name = number
    }
    local controls = frame.add {type = 'flow', direction = 'horizontal'}
    local items = frame.add {type = 'flow', direction = 'vertical'}

    local mode = this.inf_mode[number]
    local selected = mode and mode or 1
    local tbl = controls.add {type = 'table', column_count = 1}

    local limit_tooltip = '[color=yellow]Limit Info:[/color]\nThis will stop the input after the limit is reached.'
    local private_tooltip = '[color=yellow]Private Info:[/color]\nThis will make it so no one else other than you can open this chest.'

    local mode_tooltip =
        '[color=yellow]Mode Info:[/color]\nEnabled: will active the chest and allow for insertions.\nDisabled: will deactivate the chest and let´s the player utilize the GUI to retrieve items.\nLink: Link a chest with another chest. Content is divided between them.'

    local btn =
        tbl.add {
        type = 'sprite-button',
        tooltip = '[color=blue]Info![/color]\nChest ID: ' ..
            number ..
                '\nThis chest stores unlimited quantity of items (up to 48 different item types).\nThe chest is best used with an inserter to add / remove items.\nThe chest is mineable if state is disabled.\nContent is kept when mined.\n[color=yellow]Limit:[/color]\nThis will stop the input after the limit is reached.',
        sprite = 'utility/questionmark'
    }
    btn.style.height = 20
    btn.style.width = 20
    btn.enabled = false
    btn.focus()

    local tbl_2 = tbl.add {type = 'table', column_count = 2}

    local mode_label = tbl_2.add {type = 'label', caption = 'Mode: ', tooltip = mode_tooltip}
    mode_label.style.font = 'heading-2'
    local drop_down_items

    if player.admin and this.editor[player.name] then
        drop_down_items = {'Enabled', 'Disabled', 'Link', 'Editor'}
    else
        drop_down_items = {'Enabled', 'Disabled', 'Link'}
    end

    local drop_down =
        tbl_2.add {
        type = 'drop-down',
        items = drop_down_items,
        selected_index = selected,
        name = number,
        tooltip = mode_tooltip
    }

    local tbl_3 = tbl.add {type = 'table', column_count = 8}

    local limit_one_label = tbl_3.add({type = 'label', caption = '   Limit Enabled: ', tooltip = limit_tooltip})
    limit_one_label.style.font = 'heading-2'
    local limit_one_checkbox = tbl_3.add({type = 'checkbox', name = 'limit_chest', state = this.limits[entity.unit_number].state})
    limit_one_checkbox.tooltip = limit_tooltip
    limit_one_checkbox.style.minimal_height = 25
    limit_one_checkbox.style.minimal_width = 25

    local bottom_flow = tbl_3.add {type = 'flow'}
    bottom_flow.style.minimal_width = 40

    local limit_two_label = bottom_flow.add({type = 'label', caption = 'Limit: ', tooltip = limit_tooltip})
    limit_two_label.style.font = 'heading-2'
    local limit_two_text = bottom_flow.add({type = 'textfield', name = 'limit_number', text = this.limits[entity.unit_number].number})
    limit_two_text.style.width = 80
    limit_two_text.numeric = true
    limit_two_text.tooltip = limit_tooltip
    limit_two_text.style.minimal_width = 25

    local private_label = bottom_flow.add({type = 'label', caption = 'Private Chest? ', tooltip = private_tooltip})
    private_label.style.font = 'heading-2'
    local private_checkbox = bottom_flow.add({type = 'checkbox', name = 'private_chest', state = this.private[entity.unit_number].state})
    private_checkbox.tooltip = private_tooltip
    private_checkbox.style.minimal_height = 25

    this.inf_mode[entity.unit_number] = drop_down.selected_index
    player.opened = frame
    this.inf_gui[player.name] = {
        item_frame = items,
        frame = frame,
        drop_down = drop_down,
        controls = tbl,
        text_field = limit_two_text,
        limited = limit_one_checkbox,
        entity = entity,
        updated = false
    }
end

local function get_owner_chests(player, entity)
    local t = {'Select Chest'}
    for _, data in pairs(this.inf_chests) do
        if data.owner == player.force.index then
            if data.chest and data.chest.valid then
                local share_chest = this.shares[data.chest.unit_number]
                if data.chest.unit_number ~= entity.unit_number and share_chest and share_chest.state then
                    insert(t, share_chest.name)
                end
            end
        end
    end
    if #t <= 0 then
        return false
    end

    return t
end

local function update_gui()
    for _, player in pairs(game.connected_players) do
        local chest_gui_data = this.inf_gui[player.name]
        if not chest_gui_data then
            goto continue
        end
        local frame = chest_gui_data.item_frame
        local entity = chest_gui_data.entity
        if not frame then
            goto continue
        end
        if not entity or not entity.valid then
            goto continue
        end

        local unit_number = entity.unit_number

        local controls = chest_gui_data.controls

        local mode = this.inf_mode[unit_number]
        if (mode == 2 or mode == 4) and this.inf_gui[player.name].updated then
            goto continue
        end
        frame.clear()

        local tbl = frame.add {type = 'table', column_count = 10, name = 'infinity_chest_inventory'}
        local total = 0
        local items = {}

        local storage = this.inf_storage[unit_number]
        local inv = entity.get_inventory(defines.inventory.chest)
        local content = inv.get_contents()
        local limit = this.limits[unit_number].number
        local limit_state = this.limits[unit_number].state
        local full

        if not storage then
            goto no_storage
        end
        for item_name, item_count in pairs(storage) do
            if item_name ~= 'count' then
                total = total + 1
                items[item_name] = item_count
                if storage[item_name] >= limit and limit_state then
                    full = true
                end
            end
        end
        ::no_storage::

        if full then
            goto full
        end

        for item_name, item_count in pairs(content) do
            if item_name ~= 'count' then
                if not items[item_name] then
                    total = total + 1
                    items[item_name] = item_count
                else
                    items[item_name] = items[item_name] + item_count
                end
            end
        end

        ::full::

        local inf_chest = this.inf_chests[unit_number]
        if mode == 1 and not controls.tbl_4 then
            local tbl_4 = controls.add {type = 'table', column_count = 8, name = 'tbl_4'}

            local share_tooltip = '[color=yellow]Share Info:[/color]\nA name for the share so you can easy find it when you want to link it with another chest.'
            local share_one_label = tbl_4.add({type = 'label', caption = '   Share Enabled: ', tooltip = share_tooltip})
            share_one_label.style.font = 'heading-2'
            local share_one_checkbox = tbl_4.add({type = 'checkbox', name = 'share_chest', state = get_share(entity, player).state})
            share_one_checkbox.tooltip = share_tooltip
            share_one_checkbox.style.minimal_height = 25
            share_one_checkbox.style.minimal_width = 25

            local share_one_bottom_flow = tbl_4.add {type = 'flow'}
            share_one_bottom_flow.style.minimal_width = 40

            local share_two_label = share_one_bottom_flow.add({type = 'label', caption = 'Share Name: ', tooltip = share_tooltip})
            share_two_label.style.font = 'heading-2'
            local share_two_text = share_one_bottom_flow.add({type = 'textfield', name = 'share_name', text = get_share(entity, player).name})
            share_two_text.style.width = 80
            share_two_text.allow_decimal = true
            share_two_text.allow_negative = false
            share_two_text.tooltip = share_tooltip
            share_two_text.style.minimal_width = 25
        elseif mode ~= 1 and controls.tbl_4 and controls.tbl_4.valid then
            controls.tbl_4.destroy()
            remove_link(unit_number)
        end

        if mode == 3 and not controls.tbl_2 then
            local linker_tooltip = '[color=yellow]Link Info:[/color]\nThis will only work with chests that you have placed.'
            local tbl_2 = controls.add {type = 'table', column_count = 3, name = 'tbl_2'}
            local chestId = tbl_2.add({type = 'label', caption = 'Chest ID: ' .. unit_number, tooltip = linker_tooltip})
            chestId.style.font = 'heading-2'
            if inf_chest then
                if inf_chest and inf_chest.owner ~= player.force.index then
                    local private_label = tbl_2.add({type = 'label', caption = '    Not owner of chest. ', tooltip = linker_tooltip})
                    private_label.style.font = 'heading-2'
                else
                    local chests = get_owner_chests(player, entity)

                    if inf_chest.linked_to and this.shares[inf_chest.linked_to] then
                        local private_label = tbl_2.add({type = 'label', caption = '    Linked with: ' .. this.shares[inf_chest.linked_to].name, tooltip = linker_tooltip})
                        private_label.style.font = 'heading-2'
                    else
                        local private_label = tbl_2.add({type = 'label', caption = '    Link with: ', tooltip = linker_tooltip})
                        private_label.style.font = 'heading-2'
                        local private_checkbox =
                            tbl_2.add(
                            {
                                type = 'drop-down',
                                items = chests,
                                selected_index = 1,
                                name = 'linker',
                                tooltip = linker_tooltip
                            }
                        )
                        private_checkbox.style.minimal_height = 25
                    end
                end
            end
        elseif mode ~= 3 and controls.tbl_2 and controls.tbl_2.valid then
            controls.tbl_2.destroy()
            if inf_chest and inf_chest.linked_to then
                inf_chest.linked_to = nil
            end
        end

        local btn
        for item_name, item_count in pairs(items) do
            if mode == 1 or mode == 3 then
                btn =
                    tbl.add {
                    type = 'sprite-button',
                    sprite = 'item/' .. item_name,
                    style = 'slot_button',
                    number = item_count,
                    name = item_name,
                    tooltip = 'Withdrawal is possible when state is disabled!'
                }
                btn.enabled = false
            elseif mode == 2 or mode == 4 then
                btn =
                    tbl.add {
                    type = 'sprite-button',
                    sprite = 'item/' .. item_name,
                    style = 'slot_button',
                    number = item_count,
                    name = item_name
                }
                btn.enabled = true
            end
        end

        while total < 48 do
            local btns
            if mode == 1 or mode == 2 then
                btns = tbl.add {type = 'sprite-button', style = 'slot_button'}
                btns.enabled = false
            elseif mode == 4 then
                btns = tbl.add {type = 'choose-elem-button', style = 'slot_button', elem_type = 'item'}
                btns.enabled = true
            end

            total = total + 1
        end

        this.inf_gui[player.name].updated = true
        ::continue::
    end
end

local function gui_closed(event)
    local player = game.players[event.player_index]
    local type = event.gui_type

    if type == defines.gui_type.custom then
        local data = this.inf_gui[player.name]
        if not data then
            return
        end
        data.frame.destroy()
        this.inf_gui[player.name] = nil
    end
end

local function state_changed(event)
    local player = game.players[event.player_index]
    if not validate_player(player) then
        return
    end

    local element = event.element
    if not element.valid then
        return
    end
    if not element.selected_index then
        return
    end
    local name = element.name

    if name == 'linker' then
        local items = element.items
        if not items then
            return
        end
        local selected = items[element.selected_index]
        if not selected then
            return
        end
        if element.selected_index == 1 then
            return
        end
        local unit_number = this.inf_gui[player.name] and this.inf_gui[player.name].entity and this.inf_gui[player.name].entity.unit_number
        local inf_chest = this.inf_chests[unit_number]
        if inf_chest then
            local _, _unit_number = does_share_exist(player, selected)
            if _unit_number then
                inf_chest.linked_to = _unit_number
                if this.inf_chests[_unit_number] then
                    if not this.inf_chests[_unit_number].links then
                        this.inf_chests[_unit_number].links = {}
                    end
                    if not this.inf_chests[_unit_number].links[unit_number] then
                        this.inf_chests[_unit_number].links[unit_number] = true
                    end
                end
            else
                inf_chest.linked_to = selected
            end
            inf_chest.wants_to_link = nil
            local chest_gui_data = this.inf_gui[player.name]
            if chest_gui_data then
                local controls = chest_gui_data.controls
                if controls then
                    controls.tbl_2.destroy()
                end
            end
            this.inf_gui[player.name].updated = false
            return
        end
    end

    local unit_number = tonumber(element.name)
    if unit_number then
        if not this.inf_mode[unit_number] then
            return
        end
        this.inf_mode[unit_number] = element.selected_index
        local mode = this.inf_mode[unit_number]

        if mode >= 2 then
            this.inf_gui[player.name].updated = false
            return
        end
    end
end

local function gui_click(event)
    local element = event.element
    local player = game.players[event.player_index]
    if not validate_player(player) then
        return
    end
    if not element.valid then
        return
    end
    local parent = element.parent
    if not parent then
        return
    end
    if parent.name ~= 'infinity_chest_inventory' then
        return
    end
    local unit_number = tonumber(parent.parent.parent.name)
    if tonumber(element.name) == unit_number then
        return
    end

    local shift = event.shift
    local ctrl = event.control
    local name = element.name
    local storage = this.inf_storage[unit_number]
    local mode = this.inf_mode[unit_number]

    if not storage then
        return
    end

    if player.admin then
        if mode == 4 then
            if not storage[name] then
                return
            end

            if ctrl then
                storage[name] = storage[name] + 5000000
                item_counter(unit_number, 5000000, 'inc')
                goto update
            elseif shift then
                storage[name] = storage[name] - 5000000
                item_counter(unit_number, 5000000, 'dec')
                if storage[name] <= 0 then
                    storage[name] = nil
                end
                goto update
            end
        end
    end

    if mode == 1 then
        return
    end

    if ctrl then
        local count = storage[name]
        if not count then
            return
        end
        local inserted = player.insert {name = name, count = count}
        if not inserted then
            return
        end

        if inserted == count then
            storage[name] = nil
            item_counter(unit_number, inserted, 'dec')
        else
            storage[name] = storage[name] - inserted
            item_counter(unit_number, inserted, 'dec')
        end
    elseif shift then
        local count = storage[name]
        local stack = game.item_prototypes[name].stack_size
        if not count then
            return
        end
        if not stack then
            return
        end
        if count > stack then
            local inserted = player.insert {name = name, count = stack}
            storage[name] = storage[name] - inserted
            item_counter(unit_number, inserted, 'dec')
        else
            local inserted = player.insert {name = name, count = count}
            storage[name] = nil
            item_counter(unit_number, inserted, 'dec')
        end
    else
        if not storage[name] then
            return
        end
        storage[name] = storage[name] - 1
        player.insert {name = name, count = 1}
        if storage[name] <= 0 then
            storage[name] = nil
        end
        item_counter(unit_number, 1, 'dec')
    end

    ::update::

    for _, p in pairs(game.connected_players) do
        if this.inf_gui[p.name] then
            this.inf_gui[p.name].updated = false
        end
    end
end

local function on_gui_elem_changed(event)
    local element = event.element
    local player = game.players[event.player_index]
    if not validate_player(player) then
        return
    end
    if not element.valid then
        return
    end
    local parent = element.parent
    if not parent then
        return
    end
    if parent.name ~= 'infinity_chest_inventory' then
        return
    end
    local unit_number = tonumber(parent.parent.parent.name)
    if tonumber(element.name) == unit_number then
        return
    end

    local button = event.button
    local storage = this.inf_storage[unit_number]
    if not storage then
        this.inf_storage[unit_number] = {}
        storage = this.inf_storage[unit_number]
    end
    local name = element.elem_value

    if button == defines.mouse_button_type.right then
        storage[name] = nil
        return
    end

    if not name then
        return
    end
    storage[name] = 5000000
    item_counter(unit_number, 5000000, 'inc')

    if this.inf_gui[player.name] then
        this.inf_gui[player.name].updated = false
    end
end

local function on_gui_checked_state_changed(event)
    local element = event.element
    local player = game.players[event.player_index]
    if not validate_player(player) then
        return
    end
    if not element.valid then
        return
    end
    local state = element.state and true or false

    local pGui = this.inf_gui[player.name]
    if not pGui then
        return
    end

    local entity = pGui.entity
    if not (entity and entity.valid) then
        return
    end

    local unit_number = entity.unit_number

    if element.name == 'private_chest' then
        if this.private[unit_number] == false or true then
            this.private[entity.unit_number].state = state
        end
    elseif element.name == 'limit_chest' and this.limits[unit_number] then
        this.limits[unit_number].state = state
    elseif element.name == 'share_chest' and this.shares[unit_number] then
        if this.shares[unit_number].name ~= 'Share name' then
            this.shares[unit_number].state = state
        else
            player.print('Please provide a valid share name.', Color.warning)
            element.state = false
        end
    end

    pGui.updated = false
end

local function on_entity_settings_pasted(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    local source = event.source
    if not source or not source.valid then
        return
    end

    local destination = event.destination
    if not destination or not destination.valid then
        return
    end

    local source_number = source.unit_number
    local destination_number = destination.unit_number

    if this.limits[source_number] then
        local source_limit = this.limits[source_number].number
        local source_limit_state = this.limits[source_number].state
        this.limits[destination_number] = {number = source_limit, state = source_limit_state}
    end

    if this.private[source_number] then
        local source_state = this.private[source_number].state
        local source_owner = this.private[source_number].owner
        this.private[destination_number] = {state = source_state, owner = source_owner}
    end
end

Event.on_nth_tick(
    5,
    function()
        update_chest()
        update_gui()
    end
)

Event.add(defines.events.on_gui_click, gui_click)
Event.add(defines.events.on_gui_opened, gui_opened)
Event.add(defines.events.on_gui_closed, gui_closed)
Event.add(defines.events.on_built_entity, built_entity)
Event.add(defines.events.on_robot_built_entity, built_entity_robot)
Event.add(defines.events.on_pre_player_mined_item, on_pre_player_mined_item)
Event.add(defines.events.on_gui_selection_state_changed, state_changed)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_gui_elem_changed, on_gui_elem_changed)
Event.add(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
Event.add(defines.events.on_gui_text_changed, text_changed)
Event.add(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)

return Public
