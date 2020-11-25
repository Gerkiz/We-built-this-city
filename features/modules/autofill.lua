local Color = require 'utils.color_presets'
local Event = require 'utils.event'
local Global = require 'utils.global'

local this = {
    refill_turrets = {},
    refill_chests = {index = 1, placed = 0},
    valid_chest = {
        ['iron-chest'] = {valid = true, limit = 4}
    },
    valid_turrets = {
        ['artillery-turret'] = {valid = true, category = 'artillery-shell'}
    },
    valid_ammo = {},
    valid_fuel = {},
    message_limit = {},
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

local function validate_entity(entity)
    if not entity then
        return false
    end
    if not entity.valid then
        return false
    end
    return true
end

local function logger(string)
    if not this.debug then
        return
    end
    log(serpent.block(string))
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

local function contains(tbl, entity)
    if not tbl then
        return
    end
    for k, turret in pairs(tbl) do
        if not validate_entity(turret) then
            return false
        end
        if not validate_entity(entity) then
            return false
        end
        if turret.unit_number == entity.unit_number then
            return true
        end
    end
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

    for chest_item, chest_count in pairs(tbl) do
        if not chest_item then
            goto final
        end

        if not this.valid_ammo[chest_item] then
            chest.remove({name = chest_item, count = 999999})
            goto final
        end

        local a_item = this.valid_ammo[chest_item]
        local t_item = this.valid_turrets[turret_name]

        if (a_item and a_item.category == t_item.category) then
            if turret_ammo then
                if round(a_item.priority) > round(this.valid_ammo[turret_ammo].priority) then
                    item = chest_item
                    count = chest_count
                    break
                elseif a_item.category == t_item.category and round(a_item.priority) > highest then
                    item = chest_item
                    count = chest_count
                    break
                end
            elseif a_item.category == t_item.category and round(a_item.priority) > highest then
                item = chest_item
                count = chest_count
                break
            end
        end
    end

    ::final::

    if not item or not count then
        return false, false
    end

    return item, count
end

local function get_valid_chest()
    local chests = {}
    local refill_chests = this.refill_chests
    local index = refill_chests.index
    if not index then
        refill_chests.index = 1
        index = refill_chests.index
    end

    if index > #refill_chests then
        refill_chests.index = 1
        return
    end
    if not next(refill_chests) then
        return
    end

    refill_chests.index = index + 1

    local chest = refill_chests[index]
    if chest then
        chests[#chests + 1] = chest
    end

    if not chest.valid then
        fast_remove(refill_chests, index)
        refill_chests.placed = refill_chests.placed - 1
        if refill_chests.placed <= 0 then
            refill_chests.placed = 0
        end
        return false
    end

    refill_chests.index = index

    return chests
end

local function get_ammo(entity_turret)
    local turret = entity_turret.get_inventory(defines.inventory.turret_ammo)

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

local function remove_ammo(chest, entity_turret)
    local turret = entity_turret.get_inventory(defines.inventory.turret_ammo)
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

local function refill(entity_turret, entity_chest)
    local turret = entity_turret

    for i = 1, #entity_chest do
        local chests = entity_chest[i]

        if turret.force.name ~= chests.force.name then
            goto final
        end

        local chest = chests.get_inventory(defines.inventory.chest)
        local turret_ammo_name, turret_ammo_count = get_ammo(turret)

        if turret_ammo_count and turret_ammo_count >= 10 then
            if turret_ammo_count >= 15 then
                remove_ammo(chest, turret)
            end
            goto final
        end

        local chest_item_name, chest_item_count = get_items(chest, turret.name, turret_ammo_name)

        if not (this.valid_ammo[chest_item_name]) then
            goto final
        end

        if this.valid_ammo[chest_item_name] and this.valid_ammo[chest_item_name].valid and chest_item_count >= 1 then
            local turret_inv = turret.get_inventory(defines.inventory.turret_ammo)

            if turret_ammo_name and round(this.valid_ammo[chest_item_name].priority) > round(this.valid_ammo[turret_ammo_name].priority) then
                remove_ammo(chest, turret)
                goto continue
            end

            local t = {name = chest_item_name, count = this.fill_amount_on_turrets}
            local c = turret_inv.insert(t)
            if (c > 0) then
                chest.remove({name = chest_item_name, count = c})
            end

            ::continue::
        end

        ::final::
    end
end

local function do_refill_turrets()
    local chest = get_valid_chest()

    if not chest then
        goto continue
    end

    local refill_turrets = this.refill_turrets

    for i = 1, #refill_turrets do
        local turret = refill_turrets[i]
        if not turret then
            goto continue
        end

        if not turret.valid then
            fast_remove(refill_turrets, i)
        else
            refill(turret, chest)
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

local function on_entity_built(event)
    local player = game.players[event.player_index]
    if not (player and player.valid) then
        return
    end

    local ce = event.created_entity
    if not (ce and ce.valid) then
        return
    end

    if (this.valid_chest[ce.name] and this.valid_chest[ce.name].valid) then
        local limit

        limit = this.valid_chest[ce.name].limit

        if (this.refill_chests.placed < limit) then
            if this.message_limit[player.index] then
                this.message_limit[player.index] = nil
            end
            Public.add_chest_to_refill_callback(ce)
        else
            if not this.message_limit[player.index] then
                this.message_limit[player.index] = true
                player.print('[Autofill] Chest limit reached.', Color.warning)
            end
        end
    end

    if (this.valid_turrets[ce.name]) then
        Public.refill_turret_callback(ce)
        into_turret(player, ce)
    end

    if ((ce.type == 'car') or (ce.type == 'locomotive')) then
        auto_insert_into_vehicle(player, ce)
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

local function on_pre_player_mined_item(event)
    local player = game.get_player(event.player_index)

    if not validate_entity(player) then
        return
    end

    local entity = event.entity
    if not validate_entity(entity) then
        return
    end

    if not this.valid_turrets[entity.name] then
        return
    end

    local refill_turrets = this.refill_turrets

    local chest = get_valid_chest()

    if not chest then
        return
    end

    if contains(refill_turrets, entity) then
        remove_ammo(chest, entity)
    end
    return
end

local function on_tick()
    if this.stop then
        return
    end
    do_refill_turrets()
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

Public.refill_turret_callback = function(turret)
    local refill_turrets = this.refill_turrets
    if turret and turret.valid then
        insert(refill_turrets, turret)
    end
    return
end

Public.add_chest_to_refill_callback = function(entity)
    if entity and entity.valid then
        local refill_chests = this.refill_chests
        refill_chests[#refill_chests + 1] = entity
        refill_chests.placed = refill_chests.placed + 1

        rendering.draw_text {
            text = '⚙',
            surface = entity.surface,
            target = entity,
            target_offset = {0, -0.5},
            scale = 1.5,
            color = {r = 0, g = 0.6, b = 1},
            alignment = 'center'
        }
    end
end

local get_priorities = Public.get_priorities

Event.add(defines.events.on_built_entity, on_entity_built)
Event.add(defines.events.on_pre_player_mined_item, on_pre_player_mined_item)
Event.on_nth_tick(50, on_tick)
Event.on_init(
    function()
        get_priorities()
        get_fuel_items()
        get_valid_turrets()
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
            Public.refill_turret_callback(entity)
        end
    end
)

return Public
