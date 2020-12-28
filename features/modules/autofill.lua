local Color = require 'utils.color_presets'
local Event = require 'utils.event'
local Global = require 'utils.global'
local Gui = require 'utils.gui.core'

local this = {
    forces = {},
    valid_chest = {
        ['wooden-chest'] = {valid = true, limit = 4},
        ['iron-chest'] = {valid = true, limit = 4},
        ['steel-chest'] = {valid = true, limit = 4}
    },
    valid_turrets = {
        ['artillery-turret'] = {valid = true, category = 'artillery-shell'}
    },
    valid_ammo = {},
    valid_fuel = {},
    autofill_on_placement_amount = 10,
    fill_amount_on_turrets = 1,
    force_only = true,
    stop = false
}

Global.register(
    this,
    function(t)
        this = t
    end
)

local Public = {}
local insert = table.insert
local round = math.round
local container_frame_autofill = Gui.uid_name()
local player_toggled_autofill_on_container_gui_click = Gui.uid_name()

local function validate_entity(entity)
    if not entity then
        return false
    end
    if not entity.valid then
        return false
    end
    return true
end

local function fast_remove(tbl, index)
    local count = #tbl
    if index > count then
        return
    elseif index < count then
        tbl[index] = tbl[count]
    end

    tbl[count] = nil
end

local function contains_chest(tbl, entity, rtn, remove)
    if not tbl then
        return
    end
    for index, data in pairs(tbl) do
        if type(data) ~= 'number' then
            if validate_entity(entity) and validate_entity(data.chest) then
                if data.unit_number == entity.unit_number then
                    if remove then
                        return fast_remove(tbl, index)
                    end

                    if rtn then
                        return entity
                    else
                        return true, index
                    end
                end
            end
        end
    end
    return false
end

local function contains_turret(tbl, entity, rtn, remove)
    if not tbl then
        return
    end
    for index, data in pairs(tbl) do
        if type(data) ~= 'number' then
            if validate_entity(entity) and validate_entity(data.turret) then
                if data.unit_number == entity.unit_number then
                    if remove then
                        return fast_remove(tbl, index)
                    end

                    if rtn then
                        return entity
                    else
                        return true, index
                    end
                end
            end
        end
    end
    return false
end

local function get_damage(action)
    local dmg = 0
    local list = game.entity_prototypes
    local get_damage_from_entity = function(entity_name)
        local ent = list[entity_name]
        if ent then
            if ent.attack_result then
                dmg = dmg + Public.actions(ent.attack_result)
            end
            if ent.final_attack_result then
                dmg = dmg + Public.actions(ent.final_attack_result)
            end
        end
        return dmg
    end
    if action.type == 'instant' then
        if action.target_effects then
            for _, te in pairs(action.target_effects) do
                if te.action then
                    dmg = dmg + Public.actions(te.action)
                end
                if te.type == 'damage' then
                    dmg = dmg + te.damage.amount
                end
                if te.type == 'create-entity' and te.entity_name then
                    dmg = dmg + get_damage_from_entity(te.entity_name)
                end
            end
        end
    elseif action.stream then
        dmg = dmg + get_damage_from_entity(action.stream)
    elseif action.projectile then
        dmg = dmg + get_damage_from_entity(action.projectile)
    end
    return dmg
end

local result = function(action)
    local dmg = 0
    if action.action_delivery then
        for _, action_delivery in pairs(action.action_delivery) do
            dmg = dmg + get_damage(action_delivery)
        end
    end
    return dmg
end

local function get_highest(chest, tbl, turret_name, turret_ammo)
    local highest = -math.huge
    local item
    local count

    for chest_item, chest_count in next, tbl do
        if not chest_item then
            goto final
        end

        if not this.valid_ammo[chest_item] then
            chest.remove({name = chest_item, count = 999999})
            goto final
        end

        local from_chest_item = this.valid_ammo[chest_item]
        local from_turret_item = this.valid_turrets[turret_name]

        local is_from_chest = from_chest_item and from_chest_item.category == from_turret_item.category

        if is_from_chest then
            if turret_ammo and from_chest_item.priority > this.valid_ammo[turret_ammo].priority then
                item = chest_item
                count = chest_count
            elseif turret_ammo and from_chest_item.category == from_turret_item.category and from_chest_item.priority > highest then
                item = chest_item
                count = chest_count
            elseif from_chest_item.category == from_turret_item.category and from_chest_item.priority > highest then
                item = chest_item
                count = chest_count
            end
        end
    end

    ::final::

    if not item or not count then
        return false, false
    end

    return item, count
end

local function get_valid_chest(force)
    local chests = {}
    local forces = this.forces

    if not next(forces) then
        return
    end

    for _, tbl in pairs(forces) do
        local refill_chests = tbl.refill_chests
        for index = 1, #refill_chests do
            local data = refill_chests[index]
            if force and force == data.force.name then
                if data then
                    chests[#chests + 1] = data.chest
                end
                if not data.chest.valid then
                    fast_remove(refill_chests, index)
                    tbl.refill_chests_placed = tbl.refill_chests_placed - 1
                    if tbl.refill_chests_placed <= 0 then
                        tbl.refill_chests_placed = 0
                    end
                    return false
                end
            else
                if data then
                    chests[#chests + 1] = data.chest
                end
                if not data.chest.valid then
                    fast_remove(refill_chests, index)
                    tbl.refill_chests_placed = tbl.refill_chests_placed - 1
                    if tbl.refill_chests_placed <= 0 then
                        tbl.refill_chests_placed = 0
                    end
                    return false
                end
            end
        end
    end

    return chests
end

local function get_ammo(turret)
    local contents = turret.get_contents()

    local item, count
    local i = 0

    for dbi, dbc in pairs(contents) do
        i = i + dbc
        item = dbi
        count = dbc
    end

    if i >= 11 then
        return item, i
    else
        return item, count
    end
end

local function get_items(chest, turret_name, turret_ammo)
    local contents = chest.get_contents()
    local item, count = get_highest(chest, contents, turret_name, turret_ammo)

    if this.valid_ammo[item] and this.valid_ammo[item].valid and count >= 1 then
        return item, count
    end

    return false, false
end

local function remove_ammo(chest, turret)
    local current_ammo

    if not chest or not chest.valid then
        return
    end

    local contents = turret.get_contents()

    for item, count in pairs(contents) do
        if count >= 1 then
            local t = {name = item, count = count}
            if chest.can_insert(t) then
                local c = chest.insert(t)
                current_ammo = item
                turret.remove({name = item, count = c})
                return current_ammo
            end
        end
    end
end

local function refill(turret, chest, data)
    local turret_ammo_name, turret_ammo_count = get_ammo(turret)
    local chest_item_name, chest_item_count = get_items(chest, data.name, turret_ammo_name)

    if turret_ammo_count and turret_ammo_count >= 10 then
        if turret_ammo_count >= 20 then
            remove_ammo(chest, turret)
        end
        goto final
    end

    if not (this.valid_ammo[chest_item_name]) then
        goto final
    end

    if this.valid_ammo[chest_item_name] and this.valid_ammo[chest_item_name].valid and chest_item_count >= 1 then
        if turret_ammo_name and round(this.valid_ammo[chest_item_name].priority) > round(this.valid_ammo[turret_ammo_name].priority) then
            remove_ammo(chest, turret)
            goto continue
        end

        local t = {name = chest_item_name, count = this.fill_amount_on_turrets}
        local c = turret.insert(t)
        if (c > 0) then
            chest.remove({name = chest_item_name, count = c})
        end

        ::continue::
    end

    ::final::
end

local function do_refill_turrets()
    local chests = get_valid_chest()

    if not chests then
        goto continue
    end

    local forces = this.forces

    if not next(forces) then
        return
    end

    for _, tbl in pairs(forces) do
        local refill_turrets = tbl.refill_turrets
        for i = 1, #refill_turrets do
            local data = refill_turrets[i]
            if not data then
                goto continue
            end

            if not data.turret.valid then
                fast_remove(refill_turrets, i)
            else
                for x = 1, #chests do
                    local chest = chests[x]
                    refill(data.turret, chest, data)
                end
            end
        end
    end

    ::continue::
end

local function display_text(msg, pos, color, surface)
    if color == nil then
        surface.create_entity({name = 'flying-text', position = pos, text = msg})
    else
        surface.create_entity({name = 'flying-text', position = pos, text = msg, color = color})
    end
end

local function move_items(source, destination, stack)
    if (source.get_item_count(stack.name) == 0) then
        return -1
    end

    if (not destination.can_insert(stack)) then
        return -2
    end

    local itemsRemoved = source.remove(stack)
    stack.count = itemsRemoved
    return destination.insert(stack)
end

local function transfer_items(source, destination, stack, amount)
    local ret = 0
    for itemName, _ in pairs(stack) do
        ret = move_items(source, destination, {name = itemName, count = amount})
        if (ret > 0) then
            return ret
        end
    end
    return ret
end

local function into_turret(player, turret)
    local inventory = player.get_main_inventory()
    if (inventory == nil) then
        return
    end

    local success = transfer_items(inventory, turret, this.valid_ammo, this.autofill_on_placement_amount)

    if (success >= 1) then
        display_text('[Autofill] Inserted ' .. success .. '!', turret.position, Color.success, player.surface)
    elseif (success == -1) then
        display_text('[Autofill] Out of ammo!', turret.position, Color.red, player.surface)
    elseif (success == -2) then
        display_text('[Autofill] Autofill ERROR! - Report this bug!', turret.position, Color.red, player.surface)
    end
end

local function auto_insert_into_vehicle(player, vehicle)
    local inventory = player.get_main_inventory()
    if (inventory == nil) then
        return
    end

    if ((vehicle.type == 'car') or (vehicle.type == 'locomotive')) then
        transfer_items(inventory, vehicle, this.valid_fuel, 50)
    end

    if (vehicle.type == 'car') then
        transfer_items(inventory, vehicle, this.valid_ammo, this.autofill_on_placement_amount)
    end
end

local function get_fuel_items()
    local filter = game.get_filtered_item_prototypes
    for name, fuel in pairs(filter({{filter = 'fuel'}})) do
        this.valid_fuel[name] = {
            valid = true,
            priority = fuel.fuel_value
        }
    end
end

local function draw_container_frame(parent, entity, player)
    local frame = parent[container_frame_autofill]
    if frame and frame.valid then
        Gui.destroy(frame)
    end

    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right
    }

    frame =
        parent.add {
        type = 'frame',
        name = container_frame_autofill,
        anchor = anchor,
        direction = 'vertical'
    }

    local force = Public.get_force(player)

    local limit = this.valid_chest[entity.name] and this.valid_chest[entity.name].limit
    local placeholder = ''

    local tooltip
    if force then
        local isMember, id = contains_chest(force.refill_chests, entity)
        if isMember then
            placeholder = 'Chest ID: ' .. id
        end
        tooltip =
            '[color=blue]Info![/color]\nYou can easily toggle this chest autofill status.\n\nAmmo in this chest will inserted automatically onto turrets that are owned by your force.\nYou currently have: ' ..
            force.refill_chests_placed .. '/' .. limit .. ' autofill ' .. entity.name .. '.\n' .. placeholder
    else
        tooltip =
            '[color=blue]Info![/color]\nYou can easily toggle this chest autofill status.\n\nAmmo in this chest will inserted automatically onto turrets that are owned by your force.\n'
    end

    local data = {}

    local button =
        frame.add {
        type = 'sprite-button',
        sprite = 'item/firearm-magazine',
        name = player_toggled_autofill_on_container_gui_click,
        tooltip = tooltip,
        style = Gui.button_style
    }

    data.entity = entity
    data.button = button
    data.frame = frame

    Gui.set_data(button, data)
end

local function player_toggled_autofill_on_container(event)
    local player = event.player
    local button = event.button
    local data = Gui.get_data(event.element)
    local entity = data.entity
    local btn = data.button

    if button == defines.mouse_button_type.left then
        if not (entity and entity.valid) then
            return
        end

        if entity.force.name ~= player.force.name then
            return player.print('[Autofill] This chest is not owned by your force.', Color.warning)
        end

        local force = Public.get_force(player, true)

        if (this.valid_chest[entity.name] and this.valid_chest[entity.name].valid) then
            local isMember = contains_chest(force.refill_chests, entity)
            local limit = this.valid_chest[entity.name] and this.valid_chest[entity.name].limit
            if not isMember then
                if (force.refill_chests_placed < limit) then
                    Public.add_chest_to_force(player, entity)
                    local _, id = contains_chest(force.refill_chests, entity)
                    local placeholder = 'Chest ID: ' .. id
                    player.print('[Autofill] Chest added to autofill!', Color.success)
                    local tooltip =
                        '[color=blue]Info![/color]\nYou can easily toggle this chest autofill status.\n\nAmmo in this chest will inserted automatically onto turrets that are owned by your force.\nYou currently have: ' ..
                        force.refill_chests_placed .. '/' .. limit .. ' autofill ' .. entity.name .. '.\n' .. placeholder
                    btn.tooltip = tooltip
                else
                    player.print('[Autofill] Chest limit reached.', Color.warning)
                end
            else
                player.print('[Autofill] Chest removed from autofill!', Color.warning)
                Public.remove_chest_from_force(player, entity)
                local tooltip =
                    '[color=blue]Info![/color]\nYou can easily toggle this chest autofill status.\n\nAmmo in this chest will inserted automatically onto turrets that are owned by your force.\nYou currently have: ' ..
                    force.refill_chests_placed .. '/' .. limit .. ' autofill ' .. entity.name .. '.'
                btn.tooltip = tooltip
            end
        end
    else
        return
    end
end

local function get_valid_turrets()
    local filter = game.entity_prototypes
    for name, prototype in pairs(filter) do
        if prototype.attack_parameters and prototype.attack_parameters.ammo_categories then
            if prototype.attack_parameters.ammo_categories[1] then
                this.valid_turrets[name] = {
                    valid = true,
                    category = prototype.attack_parameters.ammo_categories[1]
                }
            end
        end
    end
end

Public.actions = function(tbl)
    local priority = 0
    for _, act in pairs(tbl) do
        priority = priority + result(act) * act.repeat_count
    end
    return priority
end

Public.get_priorities = function()
    for _, prototype in pairs(game.item_prototypes) do
        local ammo_type = prototype.get_ammo_type()
        if ammo_type then
            local priority = Public.actions(prototype.get_ammo_type().action)
            this.valid_ammo[prototype.name] = {
                valid = true,
                priority = round(priority),
                category = ammo_type.category
            }
        end
    end
end

Public.create_force = function(player)
    if not this.forces[player.force.name] then
        this.forces[player.force.name] = {
            refill_turrets = {},
            refill_chests = {},
            refill_chests_placed = 0,
            render_targets = {}
        }
        return this.forces[player.force.name]
    else
        return this.forces[player.force.name]
    end
end

Public.get_force = function(player, create)
    if create then
        if not this.forces[player.force.name] then
            return Public.create_force(player)
        else
            return this.forces[player.force.name]
        end
    end
    if this.forces[player.force.name] then
        return this.forces[player.force.name]
    end
    return false
end

Public.remove_force = function(player)
    if this.forces[player.force.name] then
        this.forces[player.force.name] = nil
    end
end

Public.is_force_tbl_empty = function(player)
    local s = 0
    if this.forces[player.force.name] then
        if #this.forces[player.force.name].refill_chests <= 0 then
            s = s + 1
        end
        if #this.forces[player.force.name].refill_turrets <= 0 then
            s = s + 1
        end
        if s == 2 then
            Public.remove_force(player)
        end
    end
end

Public.add_chest_to_force = function(player, entity)
    if entity and entity.valid then
        local force = Public.get_force(player)
        local refill_chests = force.refill_chests
        local render_targets = force.render_targets
        local chest = entity.get_inventory(defines.inventory.chest)
        refill_chests[#refill_chests + 1] = {chest = chest, force = entity.force.name, unit_number = entity.unit_number}
        force.refill_chests_placed = force.refill_chests_placed + 1

        render_targets[entity.unit_number] =
            rendering.draw_text {
            text = '⚙',
            surface = entity.surface,
            target = entity,
            target_offset = {0, -0.6},
            scale = 2.2,
            color = {r = 0, g = 0.6, b = 1},
            alignment = 'center'
        }
    end
end

Public.remove_chest_from_force = function(player, entity)
    local force = Public.get_force(player)
    local refill_chests = force.refill_chests
    local render_targets = force.render_targets

    contains_chest(refill_chests, entity, false, true)

    if render_targets[entity.unit_number] then
        rendering.destroy(render_targets[entity.unit_number])
        render_targets[entity.unit_number] = nil
    end

    force.refill_chests_placed = force.refill_chests_placed - 1

    Public.is_force_tbl_empty(player)
end

Public.add_turret_to_force = function(player, entity)
    if entity and entity.valid then
        local force = Public.get_force(player)
        local refill_turrets = force.refill_turrets
        local turret_inv = entity.get_inventory(defines.inventory.turret_ammo)

        refill_turrets[#refill_turrets + 1] = {
            turret = turret_inv,
            force = entity.force.name,
            unit_number = entity.unit_number,
            name = entity.name
        }
    end
end

Public.remove_turret_from_force = function(player, entity)
    local force = Public.get_force(player)
    local refill_turrets = force.refill_turrets

    contains_turret(refill_turrets, entity, false, true)

    Public.is_force_tbl_empty(player)
end

local get_priorities = Public.get_priorities

Gui.on_click(
    player_toggled_autofill_on_container_gui_click,
    function(event)
        player_toggled_autofill_on_container(event)
    end
)

Event.on_configuration_changed(
    function()
        log('[Autofill] - Called Configuration Changed.')
        this.valid_ammo = {}
        this.valid_fuel = {}
        this.valid_turrets = {}
        get_priorities()
        get_fuel_items()
        get_valid_turrets()
    end
)

Event.add(
    defines.events.script_raised_built,
    function(event)
        local entity = event.entity
        if not entity or not entity.valid then
            return
        end
        if this.valid_turrets[entity.name] then
            Public.add_turret_to_force(entity, entity)
        end
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
        if entity and entity.valid and entity.type == 'container' and entity.force.name == player.force.name then
            draw_container_frame(panel, entity, player)
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
        local panel = relative[container_frame_autofill]
        if panel and panel.valid then
            Gui.destroy(panel)
        end
    end
)

Event.add(
    defines.events.on_built_entity,
    function(event)
        local player = game.players[event.player_index]
        if not (player and player.valid) then
            return
        end

        local ce = event.created_entity
        if not (ce and ce.valid) then
            return
        end

        if (this.valid_turrets[ce.name]) then
            Public.add_turret_to_force(ce, ce)
            into_turret(player, ce)
        end

        if ((ce.type == 'car') or (ce.type == 'locomotive')) then
            auto_insert_into_vehicle(player, ce)
        end
    end
)

Event.add(
    defines.events.on_robot_built_entity,
    function(event)
        local ce = event.created_entity
        if not (ce and ce.valid) then
            return
        end

        if (this.valid_turrets[ce.name]) then
            Public.add_turret_to_force(ce, ce)
        end
    end
)

Event.add(
    defines.events.on_pre_player_mined_item,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_entity(player) then
            return
        end

        local entity = event.entity
        if not validate_entity(entity) then
            return
        end

        local chests = get_valid_chest(player.force.name)
        if not chests then
            return
        end

        local force = Public.get_force(player)

        if not this.valid_turrets[entity.name] then
            return
        end

        local refill_turrets = force.refill_turrets

        local t = contains_turret(refill_turrets, entity, true)

        if t then
            for index = 1, #chests do
                local chest = chests[index]
                remove_ammo(chest, t)
            end

            Public.remove_turret_from_force(player, t)
        end
        return
    end
)

Event.on_nth_tick(
    50,
    function()
        if this.stop then
            return
        end
        do_refill_turrets()
    end
)

Event.on_init(
    function()
        get_priorities()
        get_fuel_items()
        get_valid_turrets()
    end
)

return Public
