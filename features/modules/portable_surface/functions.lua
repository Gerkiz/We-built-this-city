local Utils = require 'utils.core'
local Color = require 'utils.color_presets'
local Task = require 'utils.task'
local Token = require 'utils.token'
local IC_Gui = require 'features.modules.portable_surface.gui'

local Public = {}
local main_tile_name = 'black-refined-concrete'

local function validate_entity(entity)
    if not (entity and entity.valid) then
        return false
    end

    return true
end

local function return_value(tab)
    for index, value in pairs(tab) do
        if value then
            tab[index] = nil
            return value, index
        end
    end
end

local function log_err(ic, err)
    if ic.debug_mode then
        if type(err) == 'string' then
            log('IC: ' .. err)
        end
    end
end

local function get_trusted_system(this, player)
    if not this.trust_system[player.index] then
        this.trust_system[player.index] = {
            [player.name] = true
        }
    end

    return this.trust_system[player.index]
end

local function upperCase(str)
    return (str:gsub('^%l', string.upper))
end

local function render_owner_text(renders, player, entity, new_owner)
    local color = {
        r = player.color.r * 0.6 + 0.25,
        g = player.color.g * 0.6 + 0.25,
        b = player.color.b * 0.6 + 0.25,
        a = 1
    }
    if not renders[player.index] then
        renders[player.index] = {}
    end

    if new_owner then
        if not renders[new_owner.index] then
            renders[new_owner.index] = {}
        end

        renders[new_owner.index][entity.unit_number] =
            rendering.draw_text {
            text = '## - ' .. new_owner.name .. "'s " .. entity.name .. ' - ##',
            surface = entity.surface,
            target = entity,
            target_offset = {0, -2.6},
            color = color,
            scale = 1.05,
            font = 'default-large-semibold',
            alignment = 'center',
            scale_with_zoom = false
        }
    else
        renders[player.index][entity.unit_number] =
            rendering.draw_text {
            text = '## - ' .. player.name .. "'s " .. entity.name .. ' - ##',
            surface = entity.surface,
            target = entity,
            target_offset = {0, -2.6},
            color = color,
            scale = 1.05,
            font = 'default-large-semibold',
            alignment = 'center',
            scale_with_zoom = false
        }
    end
    entity.color = color
end

local function kill_doors(ic, car)
    if not validate_entity(car.entity) then
        return
    end
    for k, e in pairs(car.doors) do
        ic.doors[e.unit_number] = nil
        e.destroy()
        car.doors[k] = nil
    end
end

local function get_entity_object(cars, entity)
    for k, car in pairs(cars) do
        if not entity or not car.entity then
            return false
        end
        if car.entity.unit_number == entity.unit_number then
            return k
        end
    end
    return false
end

local function get_owner_car_object(cars, player)
    for k, car in pairs(cars) do
        if car.owner == player.index then
            return k
        end
    end
    return false
end

local function get_entity_from_player_surface(cars, player)
    for k, car in pairs(cars) do
        if validate_entity(car.entity) then
            if validate_entity(car.surface) then
                if car.surface.index == player.surface.index then
                    return car.entity, car
                end
            end
        end
    end
    return false
end

local function get_owner_car_surface(cars, player, target)
    for k, car in pairs(cars) do
        if car.owner == player.index then
            if validate_entity(car.surface) then
                if car.surface.index == target.surface.index then
                    return true
                else
                    return false
                end
            else
                return false
            end
        end
    end
    return false
end

local function get_player_surface(ic, player)
    local surfaces = ic.surfaces
    for _, surface in pairs(surfaces) do
        if validate_entity(surface) then
            if surface.index == player.surface.index then
                return true
            end
        end
    end
    return false
end

local function get_player_entity(ic, player)
    local cars = ic.cars
    for k, car in pairs(cars) do
        if car.owner == player.index and type(car.entity) == 'boolean' then
            return car.name, true
        elseif car.owner == player.index then
            return car.name, false
        end
    end
    return false, false
end

local function get_owner_car_name(ic, player)
    local cars = ic.cars
    local saved_surfaces = ic.saved_surfaces
    local index = saved_surfaces[player.index]
    if not index then
        return false
    end
    for k, car in pairs(cars) do
        if car.owner == player.index then
            return car.name
        end
    end
    return false
end

local function get_saved_entity(entity, index)
    if index and index.name ~= entity.name then
        local msg =
            table.concat(
            {
                'The built entity is not the same as the saved one. ',
                'Saved entity is: ' .. upperCase(index.name) .. ' - Built entity is: ' .. upperCase(entity.name) .. '. '
            }
        )
        return false, msg
    end
    return true
end

local function replace_entity(cars, entity, index)
    local unit_number = entity.unit_number
    for k, car in pairs(cars) do
        if car.saved_entity == index.saved_entity then
            local c = car
            cars[unit_number] = c
            cars[unit_number].entity = entity
            cars[unit_number].unit_number = entity.unit_number
            cars[unit_number].saved_entity = nil
            cars[unit_number].transfer_entities = car.transfer_entities

            cars[k] = nil

            return car, k
        end
    end
end

local function replace_doors(doors, entity, index)
    if not validate_entity(entity) then
        return
    end
    for k, door in pairs(doors) do
        local unit_number = entity.unit_number
        if index.saved_entity == door then
            doors[k] = unit_number
        end
    end
end

------------------------
--- start belt functions
------------------------

local function remove_belts(car)
    local belts = car.belts
    for k, belt in pairs(belts) do
        if belt.render then
            rendering.destroy(belt.render)
        end
    end
    car.belts = {}
end

local outside_positions = {
    ['car'] = (function(x, y, left, pos)
        local outside
        local position
        local rend_position

        if left then
            position = {x = x + 0.5, y = y + 0.5}
            rend_position = {x = x + 0.5, y = y}
            if y > 10 and y < 25 then
                -- upper left
                outside = {x = pos.x - 1.5, y = pos.y - 1}
            elseif y > 30 and y < 40 then
                -- lower left
                outside = {x = pos.x - 1.5, y = pos.y + 1}
            end
        else
            position = {x = x - 0.5, y = y + 0.5}
            rend_position = {x = x - 0.5, y = y}
            if y > 10 and y < 25 then
                -- upper right
                outside = {x = pos.x + 2, y = pos.y - 1}
            elseif y > 30 and y < 40 then
                -- lower right
                outside = {x = pos.x + 2, y = pos.y + 1}
            end
        end
        return rend_position, position, outside
    end),
    ['tank'] = (function(x, y, left, pos)
        local outside
        local position
        local rend_position
        if left then
            position = {x = x + 0.5, y = y + 1}
            rend_position = {x = x + 0.5, y = y + 0.5}
            if y > 10 and y < 28 then
                -- upper left
                outside = {x = pos.x - 2, y = pos.y - 1.5}
            elseif y > 35 and y < 50 then
                -- lower left
                outside = {x = pos.x - 2, y = pos.y + 1.5}
            end
        else
            position = {x = x - 0.5, y = y + 1}
            rend_position = {x = x - 0.5, y = y + 0.5}
            if y > 10 and y < 28 then
                -- upper right
                outside = {x = pos.x + 2, y = pos.y - 1.5}
            elseif y > 35 and y < 50 then
                -- lower right
                outside = {x = pos.x + 2, y = pos.y + 1.5}
            end
        end
        return rend_position, position, outside
    end),
    ['spidertron'] = (function(x, y, left, pos)
        local outside
        local position
        local rend_position
        if left then
            position = {x = x + 0.5, y = y + 0.5}
            rend_position = {x = x + 0.5, y = y}
            if y > 15 and y < 32 then
                -- upper left
                outside = {x = pos.x - 2, y = pos.y - 1.5}
            elseif y > 40 and y < 60 then
                -- lower left
                outside = {x = pos.x - 2, y = pos.y + 1.5}
            end
        else
            position = {x = x - 0.5, y = y + 0.5}
            rend_position = {x = x - 0.5, y = y}
            if y > 15 and y < 32 then
                -- upper right
                outside = {x = pos.x + 2, y = pos.y - 1.5}
            elseif y > 40 and y < 60 then
                -- lower right
                outside = {x = pos.x + 2, y = pos.y + 1.5}
            end
        end
        return rend_position, position, outside
    end)
}

local function draw_arrows(sy, s, po)
    local rend =
        rendering.draw_text {
        text = sy,
        surface = s,
        target = po,
        target_offset = {0, 0},
        scale = 2,
        color = {r = 255, g = 165, b = 0},
        alignment = 'center'
    }
    return rend
end

local function construct_belts(car, update_positions)
    local area = car.area
    local surface = car.surface

    if not car.belts then
        car.belts = {}
    end

    local pos = car.entity.position
    local is_type = car.entity.name
    local outside
    local position
    local rend_position

    local inc = 0.05
    for i = 1, 2 do
        inc = inc + 0.3
        for _, x in pairs({area.left_top.x, area.right_bottom.x}) do
            local y = area.left_top.y + ((area.right_bottom.y - area.left_top.y) * inc)

            local p = {x = x, y = area.left_top.y + ((area.right_bottom.y - area.left_top.y) * 0.5)}

            if p.x < 0 then
                rend_position, position, outside = outside_positions[is_type](x, y, true, pos)

                if update_positions then
                    car.belts['L' .. i].outside = outside
                else
                    car.belts['L' .. i] = {
                        position = position,
                        outside = outside,
                        taken = false,
                        direction = 2,
                        render = draw_arrows('⇨', surface, rend_position),
                        direction_in = defines.direction.west,
                        direction_out = defines.direction.east
                    }
                end
            else
                rend_position, position, outside = outside_positions[is_type](x, y, false, pos)

                if update_positions then
                    car.belts['R' .. i].outside = outside
                else
                    car.belts['R' .. i] = {
                        position = position,
                        outside = outside,
                        taken = false,
                        direction = 6,
                        render = draw_arrows('⇦', surface, rend_position),
                        direction_in = defines.direction.east,
                        direction_out = defines.direction.west
                    }
                end
            end
        end
    end
end

local function get_direction(outside, inside, belt)
    local direction_out, direction_in, outside_type, inside_type = 0, 0, outside.type, inside.type
    if outside_type == 'transport-belt' or outside_type == 'loader' then
        direction_out = outside.direction
    elseif outside_type == 'underground-belt' then
        direction_out = outside.direction
        if outside.belt_to_ground_type == 'input' then
            if belt.direction_out ~= direction_out then
                return nil
            end
        else
            if belt.direction_in ~= direction_out then
                return nil
            end
        end
    end
    if inside_type == 'transport-belt' or inside_type == 'loader' then
        direction_in = inside.direction
    elseif inside_type == 'underground-belt' then
        direction_in = inside.direction
        if inside.belt_to_ground_type == 'input' then
            if belt.direction_in ~= direction_out then
                return nil
            end
        else
            if belt.direction_out ~= direction_out then
                return nil
            end
        end
    end
    if direction_out ~= direction_in then
        return nil
    end

    if direction_out == 6 and belt.direction == 2 then
        direction_out = 2
    elseif direction_out == 2 and belt.direction == 2 then
        direction_out = 6
    elseif direction_out == 2 and belt.direction == 6 then
        direction_out = 2
    elseif direction_out == 6 and belt.direction == 6 then
        direction_out = 6
    end
    return direction_out
end

local function in_area(x, y, area)
    return (x >= area.left_top.x and x <= area.right_bottom.x and y >= area.left_top.y and y <= area.right_bottom.y)
end

local function connect_belts_together(belt, outside, inside)
    local insert_at = {
        ['loader'] = 0.75,
        ['transport-belt'] = 0.75,
        ['underground-belt'] = 0.25
    }
    local direction = get_direction(outside, inside, belt)

    if direction == 6 then
        local connection = {
            from = outside,
            from_unit_number = outside.unit_number,
            f_l1 = outside.get_transport_line(1),
            f_l2 = outside.get_transport_line(2),
            to = inside,
            to_unit_number = inside.unit_number,
            to_l1 = inside.get_transport_line(1),
            to_l2 = inside.get_transport_line(2),
            direction_at = 6,
            insert_pos = insert_at[inside.type],
            valid = true
        }
        return connection
    elseif direction == 2 then
        local connection = {
            from = inside,
            from_unit_number = outside.unit_number,
            f_l1 = inside.get_transport_line(1),
            f_l2 = inside.get_transport_line(2),
            to = outside,
            to_unit_number = inside.unit_number,
            to_l1 = outside.get_transport_line(1),
            to_l2 = outside.get_transport_line(2),
            direction_at = 2,
            insert_pos = insert_at[outside.type],
            valid = true
        }
        return connection
    end
    return nil
end

local function show_text(entity, text, delay)
    entity.surface.create_entity(
        {
            name = 'flying-text',
            position = entity.position,
            text = text,
            speed = delay or 0,
            time_to_live = delay or 0,
            color = {r = 100, g = 160, b = 30}
        }
    )
end

local function init_link(car, id, belt)
    local outside_entities =
        car.entity.surface.find_entities_filtered {
        area = {{belt.outside.x - 1.5, belt.outside.y - 1.5}, {belt.outside.x + 1.5, belt.outside.y + 1.5}},
        force = car.force
    }

    if (outside_entities == nil or next(outside_entities) == nil) then
        return
    end

    local inside_entities =
        car.surface.find_entities_filtered {
        position = belt.position,
        force = car.force
    }

    if (inside_entities == nil or next(inside_entities) == nil) then
        return
    end

    for _, outside in pairs(outside_entities) do
        local o_t = outside.type
        if outside.type ~= nil then
            for _, inside in pairs(inside_entities) do
                local i_t = inside.type
                if (o_t == i_t) then
                    local conn = connect_belts_together(belt, outside, inside)
                    if conn then
                        if car.state and car.active_links == 0 then
                            if validate_entity(car.entity) then
                                car.entity.active = false
                                car.state = false
                            end
                        end
                        belt.taken = true
                        car.links[id] = conn
                        car.links[id].id = id
                        show_text(car.links[id].to, 'Connected! ✓')
                        show_text(car.links[id].from, 'Connected! ✓')
                        car.active_links = car.active_links + 1
                        if car.active_links > 4 then
                            car.active_links = 4
                        end
                        return
                    end
                end
            end
        end
    end
end

local function deconstruct_link(car, link, belt)
    if link and link.valid then
        link.valid = false
        car.links[link.id] = nil
        belt.taken = false
        car.active_links = car.active_links - 1

        if car.active_links <= 0 then
            car.active_links = 0
            if not car.state then
                if validate_entity(car.entity) then
                    car.entity.active = true
                end
                car.state = true
            end
        end
    end
end

local function recalibrate_car(car, outside_area, inside_area)
    local clear_links = false
    if not car.entity then
        clear_links = true
    end

    for id, belt in pairs(car.belts) do
        local is_near_car = outside_area == nil or in_area(belt.outside.x, belt.outside.y, outside_area)
        if not is_near_car then
            construct_belts(car, true)
            is_near_car = outside_area == nil or in_area(belt.outside.x, belt.outside.y, outside_area)
        end
        local is_near_inside_car = inside_area == nil or in_area(belt.position.x, belt.position.y, inside_area)

        if is_near_car and is_near_inside_car or clear_links then
            local link = car.links[id]
            if not car.entity then
                deconstruct_link(car, link, belt)
            elseif link then
                if (link.from.valid and link.to.valid and link.direction_at == get_direction(link.from, link.to, belt)) then
                    goto final
                else
                    deconstruct_link(car, link, belt)
                end
            else
                init_link(car, id, belt)
            end
            ::final::
        end
    end
end

------------------------
--- end belt functions
------------------------

local function replace_surface(surfaces, entity, index)
    if not validate_entity(entity) then
        return
    end
    for k, surface in pairs(surfaces) do
        local unit_number = entity.unit_number
        if tostring(index.saved_entity) == surface.name then
            if validate_entity(surface) then
                surface.name = tostring(unit_number)
                surfaces[unit_number] = surface
                surfaces[k] = nil
            end
        end
    end
end

local function replace_surface_entity(cars, entity, index)
    if not validate_entity(entity) then
        return
    end
    for _, car in pairs(cars) do
        local unit_number = entity.unit_number
        if index and index.saved_entity == car.saved_entity then
            if validate_entity(car.surface) then
                car.surface.name = tostring(unit_number)
            end
        end
    end
end

local function remove_text(ic, unit_number, owner)
    if ic.renders[owner.index] and ic.renders[owner.index][unit_number] then
        ic.renders[owner.index][unit_number] = nil
        if #ic.renders[owner.index] <= 0 then
            ic.renders[owner.index] = nil
        end
    end
end

local function remove_logistics(car)
    local chests = car.transfer_entities
    for k, chest in pairs(chests) do
        car.transfer_entities[k] = nil
        chest.destroy()
    end
end

local function set_new_area(ic, car)
    local new_area = ic.car_areas
    local name = car.name
    local apply_area = new_area[name]
    car.area = apply_area
end

local function upgrade_surface(ic, player, entity)
    local ce = entity
    local saved_surfaces = ic.saved_surfaces
    local cars = ic.cars
    local door = ic.doors
    local surfaces = ic.surfaces
    local index = saved_surfaces[player.index]
    if not index then
        return
    end

    local newIndex, key = return_value(index)
    if not newIndex then
        return
    end

    if saved_surfaces[player.index] then
        local c = get_owner_car_object(cars, player)
        local car = ic.cars[c]
        if ce.name == 'spidertron' then
            car.name = 'spidertron'
        elseif ce.name == 'tank' then
            car.name = 'tank'
        end
        set_new_area(ic, car)
        remove_logistics(car)
        car, _ = replace_entity(cars, ce, newIndex)

        remove_belts(car)
        replace_doors(door, ce, newIndex)
        replace_surface(surfaces, ce, newIndex)
        replace_surface_entity(cars, ce, newIndex)
        kill_doors(ic, car)
        Public.create_car_room(ic, car)
        saved_surfaces[player.index][key] = nil
        if #saved_surfaces[player.index] <= 0 then
            saved_surfaces[player.index] = nil
        end
        return true
    end
    return false
end

local function save_surface(ic, entity, player)
    local car = ic.cars[entity.unit_number]

    car.entity = false
    car.saved_entity = entity.unit_number

    if not ic.saved_surfaces[player.index] then
        ic.saved_surfaces[player.index] = {}
    end

    local saved = ic.saved_surfaces[player.index]

    saved[#saved + 1] = {saved_entity = entity.unit_number, name = entity.name}
end

local function kick_players_out_of_vehicles(car)
    for _, player in pairs(game.connected_players) do
        local character = player.character
        if validate_entity(character) and character.driving then
            if car.surface == player.surface then
                character.driving = false
            end
        end
    end
end

local function kick_players_from_surface(ic, car)
    if not validate_entity(car.surface) then
        return log_err('Car surface was not valid.')
    end
    if not car.entity or not car.entity.valid then
        local main_surface = game.surfaces[ic.allowed_surface]
        if validate_entity(main_surface) then
            for _, e in pairs(car.surface.find_entities_filtered({area = car.area})) do
                if validate_entity(e) and e.name == 'character' and e.player then
                    e.player.teleport(main_surface.find_non_colliding_position('character', game.forces.player.get_spawn_position(main_surface), 3, 0, 5), main_surface)
                end
            end
        end
        return log_err('Car entity was not valid.')
    end

    for _, e in pairs(car.surface.find_entities_filtered({area = car.area})) do
        if validate_entity(e) and e.name == 'character' and e.player then
            local p = car.entity.surface.find_non_colliding_position('character', car.entity.position, 128, 0.5)
            if p then
                e.player.teleport(p, car.entity.surface)
            else
                e.player.teleport(car.entity.position, car.entity.surface)
            end
        end
    end
end

local function kick_player_from_surface(ic, player, target)
    local cars = ic.cars

    local main_surface = game.surfaces[ic.allowed_surface]
    if not validate_entity(main_surface) then
        return
    end

    local c = get_owner_car_object(cars, player)
    local car = ic.cars[c]

    if not validate_entity(car.entity) then
        return
    end

    if validate_entity(player) then
        if validate_entity(target) then
            local locate = get_owner_car_surface(cars, player, target)
            if locate then
                local p = car.entity.surface.find_non_colliding_position('character', car.entity.position, 128, 0.5)
                if p then
                    target.teleport(p, car.entity.surface)
                else
                    target.teleport(main_surface.find_non_colliding_position('character', game.forces.player.get_spawn_position(main_surface), 3, 0, 5), main_surface)
                end
                target.print('You were kicked out of ' .. player.name .. ' vehicle.', Color.warning)
            end
        end
    end
end

local function restore_surface(ic, player, entity)
    local ce = entity
    local saved_surfaces = ic.saved_surfaces
    local cars = ic.cars
    local door = ic.doors
    local renders = ic.renders
    local surfaces = ic.surfaces
    local index = saved_surfaces[player.index]
    if not index then
        return
    end

    local newIndex, key = return_value(index)
    if not newIndex then
        return
    end

    if saved_surfaces[player.index] then
        local success, msg = get_saved_entity(ce, newIndex)
        if not success then
            player.print(msg, Color.warning)
            return true
        end
        replace_entity(cars, ce, newIndex)

        replace_doors(door, ce, newIndex)
        replace_surface(surfaces, ce, newIndex)
        replace_surface_entity(cars, ce, newIndex)
        saved_surfaces[player.index][key] = nil
        if #saved_surfaces[player.index] <= 0 then
            saved_surfaces[player.index] = nil
        end
        render_owner_text(renders, player, ce)
        return true
    end
    return false
end

local function input_filtered(car_inv, chest, chest_inv, free_slots)
    local request_stacks = {}

    local prototypes = game.item_prototypes
    for slot_index = 1, 30, 1 do
        local stack = chest.get_request_slot(slot_index)
        if stack then
            request_stacks[stack.name] = 10 * prototypes[stack.name].stack_size
        end
    end
    for i = 1, #car_inv - 1, 1 do
        if free_slots <= 0 then
            return
        end
        local stack = car_inv[i]
        if stack.valid_for_read then
            local request_stack = request_stacks[stack.name]
            if request_stack and request_stack > chest_inv.get_item_count(stack.name) then
                chest_inv.insert(stack)
                stack.clear()
                free_slots = free_slots - 1
            end
        end
    end
end

local function input_cargo(car, chest)
    if not chest.request_from_buffers then
        return
    end

    local car_entity = car.entity
    if not validate_entity(car_entity) then
        return
    end

    local car_inventory = car_entity.get_inventory(defines.inventory.car_trunk)
    if car_inventory.is_empty() then
        return
    end

    local chest_inventory = chest.get_inventory(defines.inventory.chest)
    local free_slots = 0

    for i = 1, chest_inventory.get_bar() - 1, 1 do
        if not chest_inventory[i].valid_for_read then
            free_slots = free_slots + 1
        end
    end

    if chest.get_request_slot(1) then
        input_filtered(car_inventory, chest, chest_inventory, free_slots)
        return
    end

    for i = 1, #car_inventory - 1, 1 do
        if free_slots <= 0 then
            return
        end
        if car_inventory[i].valid_for_read then
            chest_inventory.insert(car_inventory[i])
            car_inventory[i].clear()
            free_slots = free_slots - 1
        end
    end
end

local function output_cargo(car, passive_chest)
    if not validate_entity(car.entity) then
        return
    end

    if not passive_chest.valid then
        return
    end
    local chest1 = passive_chest.get_inventory(defines.inventory.chest)
    local chest2 = car.entity.get_inventory(defines.inventory.car_trunk)
    for k, v in pairs(chest1.get_contents()) do
        local t = {name = k, count = v}
        local c = chest2.insert(t)
        if (c > 0) then
            chest1.remove({name = k, count = c})
        end
    end
end

local transfer_functions = {
    ['logistic-chest-requester'] = input_cargo,
    ['logistic-chest-passive-provider'] = output_cargo
}

local function construct_doors(ic, car)
    local area = car.area
    local surface = car.surface

    for _, x in pairs({area.left_top.x - 1.5, area.right_bottom.x + 1.5}) do
        local p = {x = x, y = area.left_top.y + ((area.right_bottom.y - area.left_top.y) * 0.5)}
        if p.x < 0 then
            surface.set_tiles({{name = main_tile_name, position = {x = p.x + 0.5, y = p.y}}}, true)
        else
            surface.set_tiles({{name = main_tile_name, position = {x = p.x - 1, y = p.y}}}, true)
        end
        local player = game.get_player(car.owner)
        local e =
            surface.create_entity(
            {
                name = 'car',
                position = {x, area.left_top.y + ((area.right_bottom.y - area.left_top.y) * 0.5)},
                force = player.force.name,
                create_build_effect_smoke = false
            }
        )
        e.destructible = false
        e.minable = false
        e.operable = false
        e.get_inventory(defines.inventory.fuel).insert({name = 'coal', count = 1})
        ic.doors[e.unit_number] = car.entity.unit_number
        car.doors[#car.doors + 1] = e
    end
end

local function get_player_data(ic, player)
    local player_data = ic.players[player.index]
    if ic.players[player.index] then
        return player_data
    end

    ic.players[player.index] = {
        surface = 1,
        fallback_surface = player.surface.index,
        notified = false
    }
    return ic.players[player.index]
end

local remove_car =
    Token.register(
    function(data)
        local player = data.player
        local car = data.car
        player.remove_item({name = car.name, count = 1})
    end
)

function Public.save_car(ic, event)
    local entity = event.entity
    local player = game.players[event.player_index]

    local car = ic.cars[entity.unit_number]

    if not car then
        log_err('Car was not valid.')
        return
    end

    local position = entity.position
    local health = entity.health

    kick_players_out_of_vehicles(car)
    kick_players_from_surface(ic, car)
    get_player_data(ic, player)

    if car.owner == player.index then
        remove_text(ic, car.unit_number, player)
        save_surface(ic, entity, player)
        if not ic.players[player.index].notified then
            player.print(player.name .. ', the ' .. car.name .. ' surface has been saved.', Color.success)
            ic.players[player.index].notified = true
        end
    else
        local p = game.players[car.owner]
        if not p then
            return
        end

        remove_text(ic, car.unit_number, p)

        log_err(ic, 'Owner of this vehicle is: ' .. p.name)
        save_surface(ic, entity, p)
        Utils.action_warning('{Car}', player.name .. ' has looted ' .. p.name .. '´s car.')
        player.print('This car was not yours to keep.', Color.warning)
        local params = {
            player = player,
            car = car
        }
        Task.set_timeout_in_ticks(10, remove_car, params)
        if ic.restore_on_theft then
            local e = player.surface.create_entity({name = car.name, position = position, force = player.force, create_build_effect_smoke = false})
            e.health = health
            restore_surface(ic, p, e)
        else
            p.insert({name = car.name, count = 1, health = health})
            p.print('Your car was stolen from you - the gods foresaw this and granted you a new one.', Color.info)
        end
    end
end

function Public.kill_car(ic, entity)
    if not validate_entity(entity) then
        return
    end

    local entity_type = ic.entity_type

    if not entity_type[entity.type] then
        return
    end

    local car = ic.cars[entity.unit_number]
    local owner = car.owner
    if owner then
        owner = game.players[owner]
        remove_text(ic, car.unit_number, owner)
    end
    local surface = car.surface
    kick_players_out_of_vehicles(car)
    kill_doors(ic, car)
    kick_players_from_surface(ic, car)
    for _, tile in pairs(surface.find_tiles_filtered({area = car.area})) do
        surface.set_tiles({{name = 'out-of-map', position = tile.position}}, true)
    end
    for _, x in pairs({car.area.left_top.x - 1.5, car.area.right_bottom.x + 1.5}) do
        local p = {x = x, y = car.area.left_top.y + ((car.area.right_bottom.y - car.area.left_top.y) * 0.5)}
        surface.set_tiles({{name = 'out-of-map', position = {x = p.x + 0.5, y = p.y}}}, true)
        surface.set_tiles({{name = 'out-of-map', position = {x = p.x - 1, y = p.y}}}, true)
    end
    car.entity.force.chart(surface, car.area)
    game.delete_surface(surface)
    ic.surfaces[entity.unit_number] = nil
    ic.cars[entity.unit_number] = nil
end

function Public.validate_owner(ic, player, entity)
    if validate_entity(entity) then
        local cars = ic.cars
        local unit_number = entity.unit_number
        local car = cars[unit_number]
        if not car then
            return
        end
        if validate_entity(car.entity) then
            local p = game.players[car.owner]
            local list = get_trusted_system(ic, p)
            if p and p.valid and p.connected then
                if list[player.name] then
                    return
                end
            end
            if p then
                if car.owner ~= player.index and player.driving then
                    player.driving = false
                    if not player.admin then
                        return Utils.print_to(nil, '{Car} ' .. player.name .. ' tried to drive ' .. p.name .. '´s car.')
                    end
                end
            end
        end
        return false
    end
    return false
end

function Public.create_room_surface(ic, unit_number)
    if game.surfaces[tostring(unit_number)] then
        return game.surfaces[tostring(unit_number)]
    end

    local map_gen_settings = {
        ['width'] = 2,
        ['height'] = 2,
        ['water'] = 0,
        ['starting_area'] = 1,
        ['cliff_settings'] = {cliff_elevation_interval = 0, cliff_elevation_0 = 0},
        ['default_enable_all_autoplace_controls'] = true,
        ['autoplace_settings'] = {
            ['entity'] = {treat_missing_as_default = false},
            ['tile'] = {treat_missing_as_default = true},
            ['decorative'] = {treat_missing_as_default = false}
        }
    }
    local surface = game.create_surface(tostring(unit_number), map_gen_settings)
    surface.freeze_daytime = true
    surface.daytime = 0.1
    surface.request_to_generate_chunks({16, 16}, 1)
    surface.force_generate_chunk_requests()
    for _, tile in pairs(surface.find_tiles_filtered({area = {{-2, -2}, {2, 2}}})) do
        surface.set_tiles({{name = 'out-of-map', position = tile.position}}, true)
    end
    ic.surfaces[unit_number] = surface
    return surface
end

function Public.create_car_room(ic, car)
    local surface = car.surface
    local car_areas = ic.car_areas
    local entity_name = car.name
    local area = car_areas[entity_name]
    local tiles = {}

    for x = area.left_top.x, area.right_bottom.x - 1, 1 do
        for y = area.left_top.y + 2, area.right_bottom.y - 3, 1 do
            tiles[#tiles + 1] = {name = main_tile_name, position = {x, y}}
        end
    end

    local fishes = {}

    for x = area.left_top.x, area.right_bottom.x - 1, 1 do
        for y = -0, 1, 1 do
            tiles[#tiles + 1] = {name = 'water', position = {x, y}}
            fishes[#fishes + 1] = {name = 'fish', position = {x, y}}
        end
    end

    surface.set_tiles(tiles, true)
    for _, fish in pairs(fishes) do
        surface.create_entity(fish)
    end

    construct_doors(ic, car)

    construct_belts(car)

    local lx, ly, rx, ry = 4, 1, 5, 1

    local position1 = {area.left_top.x + lx, area.left_top.y + ly}
    local position2 = {area.right_bottom.x - rx, area.left_top.y + ry}

    local e1 =
        surface.create_entity(
        {
            name = 'logistic-chest-requester',
            position = position1,
            force = 'neutral',
            create_build_effect_smoke = false
        }
    )
    e1.destructible = false
    e1.minable = false

    local e2 =
        surface.create_entity(
        {
            name = 'logistic-chest-passive-provider',
            position = position2,
            force = 'neutral',
            create_build_effect_smoke = false
        }
    )
    e2.destructible = false
    e2.minable = false
    car.transfer_entities = {e1, e2}
    return
end

function Public.create_car(ic, event)
    local ce = event.created_entity

    local player = game.get_player(event.player_index)

    local map_name = ic.allowed_surface

    local entity_type = ic.entity_type
    local un = ce.unit_number

    if not un then
        return
    end

    if not entity_type[ce.type] then
        return
    end

    local name, mined = get_player_entity(ic, player)

    if entity_type[name] and not mined and ic.disable_multiple_vehicles then
        return player.print('Multiple vehicles are not supported at the moment.', Color.warning)
    end

    if string.sub(ce.surface.name, 0, #map_name) ~= map_name and ic.disable_multiple_surfaces then
        return player.print('Multi-surface is not supported at the moment.', Color.warning)
    end

    if
        get_owner_car_name(ic, player) == 'car' and ce.name == 'tank' or get_owner_car_name(ic, player) == 'car' and ce.name == 'spidertron' or
            get_owner_car_name(ic, player) == 'tank' and ce.name == 'spidertron'
     then
        upgrade_surface(ic, player, ce)
        render_owner_text(ic.renders, player, ce)
        player.print('Your car-surface has been upgraded!', Color.success)
        return
    end

    local saved_surface = restore_surface(ic, player, ce)
    if saved_surface then
        return
    end

    local car_areas = ic.car_areas
    local car_area = car_areas[ce.name]

    ic.cars[un] = {
        entity = ce,
        area = {
            left_top = {x = car_area.left_top.x, y = car_area.left_top.y},
            right_bottom = {x = car_area.right_bottom.x, y = car_area.right_bottom.y}
        },
        doors = {},
        owner = player.index,
        name = ce.name,
        belts = {},
        state = true,
        links = {},
        active_links = 0,
        unit_number = ce.unit_number,
        outside_x = ce.position.x,
        outside_y = ce.position.y
    }

    local car = ic.cars[un]

    car.surface = Public.create_room_surface(ic, un)
    Public.create_car_room(ic, car)
    render_owner_text(ic.renders, player, ce)

    return car
end

function Public.remove_invalid_cars(ic)
    for k, car in pairs(ic.cars) do
        if type(car.entity) ~= 'boolean' then
            if not validate_entity(car.entity) then
                remove_text(ic, car.unit_number, game.players[car.owner])
                ic.cars[k] = nil
                for key, value in pairs(ic.doors) do
                    if k == value then
                        ic.doors[key] = nil
                    end
                end
                kick_players_from_surface(ic, car)
            end
        end
    end
    for k, surface in pairs(ic.surfaces) do
        if not ic.cars[tonumber(surface.name)] then
            game.delete_surface(surface)
            ic.surfaces[k] = nil
        end
    end
end

function Public.use_door_with_entity(ic, player, door)
    local player_data = get_player_data(ic, player)
    if player_data.state then
        player_data.state = player_data.state - 1
        if player_data.state == 0 then
            player_data.state = nil
        end
        return
    end

    if not validate_entity(door) then
        return
    end
    local doors = ic.doors
    local cars = ic.cars

    local car = false
    if doors[door.unit_number] then
        car = cars[doors[door.unit_number]]
    end
    if cars[door.unit_number] then
        car = cars[door.unit_number]
    end
    if not car then
        return
    end

    local owner = game.players[car.owner]
    local list = get_trusted_system(ic, owner)
    if owner and owner.valid and player.connected then
        if not list[player.name] and not player.admin then
            player.driving = false
            return player.print('You have not been approved by ' .. owner.name .. ' to enter their vehicle.', Color.warning)
        end
    end

    player_data.fallback_surface = car.entity.surface.index
    player_data.fallback_position = {car.entity.position.x, car.entity.position.y}

    if car.entity.surface.name == player.surface.name then
        local surface = car.surface
        if validate_entity(car.entity) and car.owner == player.index then
            IC_Gui.add_toolbar(player)
            car.entity.minable = false
        end

        if not validate_entity(surface) then
            return
        end

        local area = car.area
        local x_vector = door.position.x - player.position.x
        local position
        if x_vector > 0 then
            position = {area.left_top.x + 0.5, area.left_top.y + ((area.right_bottom.y - area.left_top.y) * 0.5)}
        else
            position = {area.right_bottom.x - 0.5, area.left_top.y + ((area.right_bottom.y - area.left_top.y) * 0.5)}
        end
        local p = surface.find_non_colliding_position('character', position, 128, 0.5)
        if p then
            player.teleport(p, surface)
        else
            player.teleport(position, surface)
        end
        player_data.surface = surface.index
    else
        if validate_entity(car.entity) and car.owner == player.index then
            IC_Gui.remove_toolbar(player)
            car.entity.minable = true
        end
        local surface = car.entity.surface
        local x_vector = (door.position.x / math.abs(door.position.x)) * 2
        local position = {car.entity.position.x + x_vector, car.entity.position.y}
        local surface_position = surface.find_non_colliding_position('character', position, 128, 0.5)
        if car.entity.type == 'car' or car.entity.name == 'spidertron' then
            player.teleport(surface_position, surface)
            player_data.state = 2
            player.driving = true
        else
            player.teleport(surface_position, surface)
        end
        player_data.surface = surface.index
    end
end

function Public.item_transfer(ic)
    local car = next(ic.cars)
    if not car then
        return
    end
    car = ic.cars[car]
    if not car then
        return
    end
    if type(car.entity) ~= 'number' then
        if validate_entity(car.entity) then
            if car.transfer_entities then
                for k, e in pairs(car.transfer_entities) do
                    if validate_entity(e) then
                        transfer_functions[e.name](car, e)
                    end
                end
            end
        end
    end
end

------------------------
--- start belt functions
------------------------

local recalibrate_car_token =
    Token.register(
    function(data)
        local car = data.car
        local bbox2 = data.bbox2
        local inside = data.inside
        if inside then
            recalibrate_car(car, nil, bbox2)
        else
            recalibrate_car(car, bbox2, nil)
        end
    end
)

function Public.check_if_link_is_valid(cars, entity, wait)
    local surface = entity.surface
    local bbox = entity.bounding_box
    local bbox2 = {
        left_top = {x = bbox.left_top.x - 1.5, y = bbox.left_top.y - 1.5},
        right_bottom = {x = bbox.right_bottom.x + 1.5, y = bbox.right_bottom.y + 1.5}
    }

    local found_car = false
    local cars_in_surrounding = surface.find_entities_filtered {area = bbox2}
    for _, found in pairs(cars_in_surrounding) do
        if found ~= entity and cars[found.unit_number] then
            local car = cars[found.unit_number]
            if car then
                found_car = true
                if wait then
                    Task.set_timeout_in_ticks(10, recalibrate_car_token, {car = car, bbox2 = bbox2})
                else
                    recalibrate_car(car, bbox2, nil)
                end
            end
        end
    end
    if not found_car then
        local _, car = get_entity_from_player_surface(cars, entity)
        if not car then
            car = get_entity_object(cars, entity)
            car = cars[car]
        end
        if car then
            if wait then
                Task.set_timeout_in_ticks(10, recalibrate_car_token, {car = car, bbox2 = bbox2, inside = true})
            else
                recalibrate_car(car, nil, bbox2)
            end
        end
    end
end

function Public.ticking_belts(ic)
    local carId = next(ic.cars)
    if not carId then
        goto final
    end

    local connection = ic.cars[carId] and ic.cars[carId].links
    if not connection then
        goto final
    end

    for _, belt in pairs(connection) do
        local from = belt.from
        local to = belt.to
        if from.valid and to.valid then
            local f1 = belt.f_l1
            local t1 = belt.to_l1
            local contents = f1.get_contents()
            local t = next(contents)
            if t ~= nil then
                if t1.insert_at(belt.insert_pos, {name = t, count = 1}) then
                    f1.remove_item {name = t, count = 1}
                end
            end
            local f2 = belt.f_l2
            local t2 = belt.to_l2
            contents = f2.get_contents()
            t = next(contents)
            if t ~= nil then
                if t2.insert_at(belt.insert_pos, {name = t, count = 1}) then
                    f2.remove_item {name = t, count = 1}
                end
            end
        end
    end
    ::final::
end

------------------------
--- end belt functions
------------------------

Public.kick_player_from_surface = kick_player_from_surface
Public.get_player_surface = get_player_surface
Public.get_entity_from_player_surface = get_entity_from_player_surface
Public.get_owner_car_object = get_owner_car_object
Public.render_owner_text = render_owner_text

return Public
