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
    debug = false
}

local default_limit = 100
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
        if this.storage[player.index] and has_value(this.storage[player.index].chests) >= 1 then
            if this.stop then
                goto continue
            end
            local chest_index = this.storage[player.index].chests
            local chest_to_place, index = return_value(chest_index)
            local limits = this.storage[player.index].limits[index]
            local private = this.storage[player.index].private[index]
            local limit_index = limits.number
            local limit_state = limits.state

            this.inf_storage[entity.unit_number] = chest_to_place
            this.limits[entity.unit_number] = {state = limit_state, number = limit_index}
            this.private[entity.unit_number] = private
            this.storage[player.index].limits[index] = nil
            this.storage[player.index].private[index] = nil
        end
        ::continue::
        entity.active = false
        if not this.limits[entity.unit_number] then
            this.limits[entity.unit_number] = {state = true, number = default_limit}
        end
        this.inf_chests[entity.unit_number] = {chest = entity, content = entity.get_inventory(defines.inventory.chest), owner = player.index}
        if not this.private[entity.unit_number] then
            this.private[entity.unit_number] = {state = false, owner = player.name}
        end
        this.inf_mode[entity.unit_number] = 1
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
    elseif mode == 5 then
        diff = 2 ^ 31
    end
    if diff > 0 then
        if not storage[item_name] then
            local count = inv.remove({name = item_name, count = diff})
            this.inf_storage[unit_number][item_name] = count
        else
            if this.limits[unit_number] and this.limits[unit_number].state and this.inf_storage[unit_number][item_name] >= this.limits[unit_number].number then
                Public.err_msg('Limit for entity: ' .. unit_number .. 'and item: ' .. item_name .. ' is limited. ')
                if mode == 1 then
                    this.inf_mode[unit_number] = 4
                end
                if inv.can_insert({name = item_name, count = item_stack}) then
                    local count = inv.insert({name = item_name, count = item_stack})
                    this.inf_storage[unit_number][item_name] = storage[item_name] - count
                end
                return
            end
            local count = inv.remove({name = item_name, count = diff})
            this.inf_storage[unit_number][item_name] = storage[item_name] + count
        end
    elseif diff < 0 then
        if not storage[item_name] then
            return
        end
        if storage[item_name] > (diff * -1) then
            local inserted = inv.insert({name = item_name, count = (diff * -1)})
            this.inf_storage[unit_number][item_name] = storage[item_name] - inserted
        else
            inv.insert({name = item_name, count = storage[item_name]})
            this.inf_storage[unit_number][item_name] = nil
        end
    end
end

local function balance_items(inv, chest2, content)
    local storage2_inv = chest2.content
    local content2 = storage2_inv.get_contents()
    for item_name, count in pairs(content) do
        local count2 = content2[item_name] or 0
        local diff = count - count2
        if diff == 1 then
            return
        elseif diff > 1 then
            local count2 = storage2_inv.insert {name = item_name, count = math.floor(diff / 2)}
            if count2 > 0 then
                inv.remove {name = item_name, count = count2}
            end
        elseif diff < -1 then
            local count2 = inv.insert {name = item_name, count = math.floor(-diff / 2)}
            if count2 > 0 then
                storage2_inv.remove {name = item_name, count = count2}
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

local function remove_chest(unit_number)
    local linked = this.inf_chests[unit_number].linked_to
    if linked then
        linked = tonumber(linked)
        this.inf_chests[linked].linked_to = nil
        this.inf_chests[linked].linked_index = nil
    end

    this.inf_chests[unit_number] = nil
    this.inf_storage[unit_number] = nil
    this.limits[unit_number] = nil
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
            limits = {}
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

        local mode = this.inf_mode[chest.unit_number]
        if mode then
            if mode == 1 then
                inv.set_bar()
                chest.destructible = false
                chest.minable = false
            elseif mode == 2 then
                inv.set_bar(1)
                chest.destructible = true
                chest.minable = true
            elseif mode == 3 then
                inv.set_bar()
                chest.destructible = false
                chest.minable = false
            elseif mode == 4 then
                inv.set_bar(2)
                chest.destructible = false
                chest.minable = false
            end
        end

        if linked_to then
            linked_to = tonumber(linked_to)
            local chest2 = this.inf_chests[linked_to]
            if not chest2 then
                goto continue
            end

            if not chest2.linked_to then
                goto continue
            end

            balance_items(inv, chest2, content, unit_number, linked_to)

            goto continue
        end

        for item_name, item_count in pairs(content) do
            item(item_name, item_count, inv, unit_number)
        end

        local storage = this.inf_storage[unit_number]
        if not storage then
            goto continue
        end
        for item_name, _ in pairs(storage) do
            if this.limits[unit_number] and storage[item_name] <= this.limits[unit_number].number and mode == 4 then
                this.inf_mode[unit_number] = 1
            end
            if not content[item_name] then
                item(item_name, 0, inv, unit_number)
            end
        end

        ::continue::
    end
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

    if not data.text_field or not data.text_field.valid then
        return
    end

    if not data.text_field.text then
        return
    end

    local value = tonumber(element.text)

    if not value then
        return
    end

    if value ~= '' and value >= default_limit then
        data.text_field.text = tostring(value)

        local entity = data.entity
        if not entity or not entity.valid then
            return
        end

        local unit_number = entity.unit_number

        this.limits[unit_number].number = tonumber(value)
    elseif value ~= '' and value <= default_limit then
        return
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

    local limit_tooltip = '[color=yellow]Limit Info:[/color]\nThis is only usable if you intend to use this chest for one item.'
    local private_tooltip = '[color=yellow]Private Info:[/color]\nThis will make it so no one else other than you can open this chest.'

    local mode_tooltip =
        '[color=yellow]Mode Info:[/color]\nEnabled: will active the chest and allow for insertions.\nDisabled: will deactivate the chest and let´s the player utilize the GUI to retrieve items.\nLink: Link a chest with another chest. Content is divided between them.\nLimited: can´t be selected and will deactivate the chest as per limit.'

    local btn =
        tbl.add {
        type = 'sprite-button',
        tooltip = '[color=blue]Info![/color]\nThis chest stores unlimited quantity of items (up to 48 different item types).\nThe chest is best used with an inserter to add / remove items.\nThe chest is mineable if state is disabled.\nContent is kept when mined.\n[color=yellow]Limit:[/color]\nThis is only usable if you intend to use this chest for one item.',
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
        drop_down_items = {'Enabled', 'Disabled', 'Link', 'Limited', 'Editor'}
    else
        drop_down_items = {'Enabled', 'Disabled', 'Link', 'Limited'}
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

    local limit_one_label = tbl_3.add({type = 'label', caption = 'Limit: ', tooltip = limit_tooltip})
    limit_one_label.style.font = 'heading-2'
    local text_field = tbl_3.add({type = 'textfield', text = this.limits[entity.unit_number].number})
    text_field.style.width = 80
    text_field.numeric = true
    text_field.tooltip = limit_tooltip
    text_field.style.minimal_width = 25
    local bottom_flow = tbl_3.add {type = 'flow'}
    bottom_flow.style.minimal_width = 40

    local limit_two_label = bottom_flow.add({type = 'label', caption = '   Limit Enabled: ', tooltip = limit_tooltip})
    limit_two_label.style.font = 'heading-2'
    local limited = bottom_flow.add({type = 'checkbox', name = 'limit_chest', state = this.limits[entity.unit_number].state})
    limited.tooltip = limit_tooltip
    limited.style.minimal_height = 25
    limited.style.minimal_width = 25

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
        text_field = text_field,
        limited = limited,
        entity = entity,
        updated = false
    }
end

local function get_owner_chests(player, entity)
    local t = {'Select Chest'}
    for _, data in pairs(this.inf_chests) do
        if data.owner == player.index then
            if data.chest.unit_number ~= entity.unit_number then
                insert(t, data.chest.unit_number)
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
        if (mode == 2 or mode == 4 or mode == 5) and this.inf_gui[player.name].updated then
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
            total = total + 1
            items[item_name] = item_count
            if storage[item_name] >= limit and limit_state then
                full = true
            end
        end
        ::no_storage::

        if full then
            goto full
        end

        for item_name, item_count in pairs(content) do
            if not items[item_name] then
                total = total + 1
                items[item_name] = item_count
            else
                items[item_name] = items[item_name] + item_count
            end
        end

        ::full::

        if mode == 3 and not controls.tbl_2 then
            local linker_tooltip = '[color=yellow]Link Info:[/color]\nThis will only work with chests that you have placed.'

            local tbl_2 = controls.add {type = 'table', column_count = 3, name = 'tbl_2'}
            local chestId = tbl_2.add({type = 'label', caption = 'Chest ID: ' .. unit_number, tooltip = linker_tooltip})
            chestId.style.font = 'heading-2'
            local chests = get_owner_chests(player, entity)
            local private_label = tbl_2.add({type = 'label', caption = '    Link with: ', tooltip = linker_tooltip})
            private_label.style.font = 'heading-2'
            local private_checkbox =
                tbl_2.add(
                {
                    type = 'drop-down',
                    items = chests,
                    selected_index = this.inf_chests[unit_number] and this.inf_chests[unit_number].linked_index or 1,
                    name = 'linker',
                    tooltip = linker_tooltip
                }
            )
            private_checkbox.style.minimal_height = 25
        elseif mode ~= 3 and controls.tbl_2 and controls.tbl_2.valid then
            controls.tbl_2.destroy()
            if this.inf_chests[unit_number] and this.inf_chests[unit_number].linked_to then
                local linked = this.inf_chests[unit_number].linked_to
                if linked then
                    linked = tonumber(linked)
                    this.inf_chests[linked].linked_to = nil
                    this.inf_chests[linked].linked_index = nil
                    this.inf_mode[linked] = 1
                end
                this.inf_chests[unit_number].linked_to = nil
                this.inf_chests[unit_number].linked_index = nil
            end
        end

        local btn
        for item_name, item_count in pairs(items) do
            if mode == 1 or mode == 3 or mode == 4 then
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
            elseif mode == 2 or mode == 5 then
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
            if mode == 1 or mode == 2 or mode == 4 then
                btns = tbl.add {type = 'sprite-button', style = 'slot_button'}
                btns.enabled = false
            elseif mode == 5 then
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
        if this.inf_chests[unit_number] then
            if this.inf_chests[tonumber(selected)] and this.inf_chests[tonumber(selected)].linked_to and tonumber(this.inf_chests[tonumber(selected)].linked_to) ~= unit_number then
                this.inf_chests[unit_number].linked_to = nil
                this.inf_chests[unit_number].linked_index = nil
                return player.print('[Inf Chests] Target chest is already linked.', Color.warning)
            end

            this.inf_chests[unit_number].linked_to = selected
            this.inf_chests[unit_number].linked_index = element.selected_index
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
        if mode == 5 then
            if not storage[name] then
                return
            end
            if ctrl then
                storage[name] = storage[name] + 5000000
                goto update
            elseif shift then
                storage[name] = storage[name] - 5000000
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
        else
            storage[name] = storage[name] - inserted
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
        else
            player.insert {name = name, count = count}
            storage[name] = nil
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
