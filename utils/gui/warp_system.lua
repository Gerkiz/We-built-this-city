local m_gui = require 'mod-gui'
local mod = m_gui.get_button_flow
local Gui = require 'utils.gui.core'
local Event = require 'utils.event'
local Global = require 'utils.global'
local Surface = require 'utils.surface'
local Tabs = require 'utils.gui.core'
local Color = require 'utils.color_presets'
local Session = require 'utils.datastore.session_data'
local Roles = require 'utils.role.table'

local warp_entities = {
    {'small-lamp', -3, -2},
    {'small-lamp', -3, 2},
    {'small-lamp', 3, -2},
    {'small-lamp', 3, 2},
    {'small-lamp', -2, -3},
    {'small-lamp', 2, -3},
    {'small-lamp', -2, 3},
    {'small-lamp', 2, 3},
    {'small-electric-pole', -3, -3},
    {'small-electric-pole', 3, 3},
    {'small-electric-pole', -3, 3},
    {'small-electric-pole', 3, -3}
}
local warp_tiles = {
    {-3, -2},
    {-3, -1},
    {-3, 0},
    {-3, 1},
    {-3, 2},
    {3, -2},
    {3, -1},
    {3, 0},
    {3, 1},
    {3, 2},
    {-2, -3},
    {-1, -3},
    {0, -3},
    {1, -3},
    {2, -3},
    {-2, 3},
    {-1, 3},
    {0, 3},
    {1, 3},
    {2, 3}
}

local radius = 4
local warp_tile = 'tutorial-grid'
local warp_item = 'discharge-defense-equipment'
local global_offset = {x = 0, y = 0}

local main_button_name = Gui.uid_name()
local main_frame_name = Gui.uid_name()
local create_warp_button_name = Gui.uid_name()
local confirmed_button_name = Gui.uid_name()
local create_warp_func_name = Gui.uid_name()
local create_warp_is_shared = Gui.uid_name()
local remove_warp_button_name = Gui.uid_name()
local close_main_frame_name = Gui.uid_name()
local cancel_button_name = Gui.uid_name()
local show_only_player_warps = Gui.uid_name()
local warp_icon_name = Gui.uid_name()

local warp_table = {}
local player_table = {}

Global.register(
    {
        warp_table = warp_table,
        player_table = player_table
    },
    function(t)
        warp_table = t.warp_table
        player_table = t.player_table
    end
)

local Public = {}

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
    if not game.players[player.name] then
        return false
    end
    return true
end

local function get_player_data(player)
    if not player_table[player.index] then
        player_table[player.index] = {
            creating = false,
            removing = false,
            frame = nil,
            spam = 100,
            only_my_warps = false
        }
    end
    return player_table[player.index]
end

function Public.inside(pos, area)
    local lt = area.left_top
    local rb = area.right_bottom

    return pos.x >= lt.x and pos.y >= lt.y and pos.x <= rb.x and pos.y <= rb.y
end
function Public.contains_positions(area)
    for _, pos in pairs(warp_table) do
        if Public.inside(pos.position, area) then
            return true
        end
    end
    return false
end

function Public.remove_warp_point(name)
    local warp = warp_table[name]
    if not warp then
        return
    end
    local base_tile = warp.old_tile
    local surface = warp.surface
    local offset = warp.position
    local tiles = {}
    if name == 'Spawn' then
        return
    end
    for x = -radius - 2, radius + 2 do
        for y = -radius - 2, radius + 2 do
            if x ^ 2 + y ^ 2 < (radius + 1) ^ 2 then
                tiles[#tiles + 1] = {name = base_tile, position = {x + offset.x, y + offset.y}}
                local entities =
                    surface.find_entities_filtered {
                    area = {{x + offset.x - 1, y + offset.y - 1}, {x + offset.x, y + offset.y}}
                }
                for _, entity in pairs(entities) do
                    if entity.name ~= 'character' then
                        entity.destroy()
                    end
                end
            --or entity.name ~= 'player' or entity.name ~= 'bob-character-fighter' or entity.name ~= 'bob-character-miner' or entity.name ~= 'bob-character-builder'
            end
        end
    end
    if warp.old_tile then
        surface.set_tiles(tiles)
    end
    if warp.tag then
        warp.tag.destroy()
    end
    warp_table[name] = nil
end

function Public.make_warp_point(player, position, surface, icon, force, name, shared)
    local warp = warp_table[name]
    if warp then
        return
    end
    local offset = {x = math.floor(position.x), y = math.floor(position.y)}
    local old_tile = surface.get_tile(offset).name
    local base_tiles = {}
    local tiles = {}
    local _shared = shared or false
    -- player_table makes the base template to make the warp point
    for x = -radius - 2, radius + 2 do
        for y = -radius - 2, radius + 2 do
            if x ^ 2 + y ^ 2 < radius ^ 2 then
                base_tiles[#base_tiles + 1] = {name = warp_tile, position = {x + offset.x, y + offset.y}}
            end
        end
    end
    local created_by = player.name
    surface.set_tiles(base_tiles)
    -- player_table adds the patterns and entities
    for _, p in pairs(warp_tiles) do
        tiles[#tiles + 1] = {
            name = warp_tile,
            position = {p[1] + offset.x + global_offset.x, p[2] + offset.y + global_offset.y}
        }
    end
    surface.set_tiles(tiles)
    for _, e in pairs(warp_entities) do
        local entity =
            surface.create_entity {
            name = e[1],
            position = {e[2] + offset.x + global_offset.x, e[3] + offset.y + global_offset.y},
            force = 'neutral'
        }
        entity.destructible = false
        entity.health = 0
        entity.minable = false
        entity.rotatable = false
    end

    local tag =
        force.add_chart_tag(
        surface,
        {
            position = {offset.x + 0.5, offset.y + 0.5},
            text = 'Warp: ' .. name,
            icon = {type = icon.type, name = icon.name}
        }
    )
    warp_table[name] = {
        tag = tag,
        position = tag.position,
        surface = surface,
        icon = icon,
        name = name,
        old_tile = old_tile,
        created_by = created_by,
        shared = _shared
    }
end

function Public.make_tag(name, pos, shared)
    local get_surface = Surface.get_surface_name()
    local surface = game.surfaces[get_surface]
    local data = {}
    if data.forces then
        data.forces = nil
    end
    for k, v in pairs(game.forces) do
        data.forces = v
    end
    local created_by = 'script'
    local v =
        data.forces.add_chart_tag(
        surface,
        {
            position = pos,
            text = 'Warp: ' .. name,
            icon = {type = 'item', name = warp_item}
        }
    )

    warp_table[name] = {
        tag = v,
        position = pos,
        name = name,
        icon = {type = 'item', name = warp_item},
        surface = surface,
        created_by = created_by,
        shared = shared
    }
    return data
end

function Public.create_warp_button(player, raise_event)
    if raise_event == nil then
        if Roles.events.on_role_change then
            if mod(player)[main_button_name] then
                mod(player)[main_button_name].destroy()
            end
        end
    end
    if not Roles.get_role(player):allowed('show-warp') then
        return
    end
    if mod(player)[main_button_name] then
        return
    end
    mod(player).add {
        type = 'sprite-button',
        sprite = 'item/discharge-defense-equipment',
        name = main_button_name,
        tooltip = 'Warp to places!',
        style = m_gui.button_style
    }
end

local function draw_create_warp(parent, player)
    local position = player.position
    local posx = position.x
    local posy = position.y
    local dist2 = 100 ^ 2
    local p = get_player_data(player)
    if not Roles.get_role(player):allowed('always-warp') then
        for name, warp in pairs(warp_table) do
            local pos = warp.position
            if (posx - pos.x) ^ 2 + (posy - pos.y) ^ 2 < dist2 then
                player.print('Too close to another warp: ' .. name, Color.fail)
                p.creating = false
                return
            end
        end
    end

    local x =
        parent.add {
        type = 'table',
        name = 'wp_table',
        column_count = 4
    }

    local elem =
        x.add {
        name = warp_icon_name,
        type = 'choose-elem-button',
        elem_type = 'signal',
        signal = {type = 'item', name = warp_item},
        tooltip = 'Choose the tag-icon'
    }
    local elem_style = elem.style
    elem_style.height = 32
    elem_style.width = 32

    local textfield =
        x.add {
        type = 'textfield',
        name = 'wp_text',
        text = 'Warp name:',
        numeric = false,
        allow_decimal = false,
        allow_negative = false
    }
    p.shared = true
    textfield.style.minimal_width = 150
    textfield.style.maximal_width = 150
    textfield.style.height = 24
    p.frame = {new_name = textfield}

    local _flow =
        x.add {
        type = 'flow'
    }
    _flow.style.horizontal_align = 'right'
    _flow.style.horizontally_stretchable = true

    local checkbox =
        _flow.add {
        type = 'checkbox',
        name = create_warp_is_shared,
        tooltip = 'Do you want to share this warp?',
        state = true
    }
    checkbox.style.top_margin = 5

    local btn =
        _flow.add {
        type = 'sprite-button',
        name = create_warp_func_name,
        tooltip = 'Creates a new warp point.',
        sprite = 'utility/confirm_slot',
        style = 'shortcut_bar_button_green'
    }
    btn.style.height = 23
    btn.style.width = 23
    btn.style.padding = -2
end

local function draw_remove_warp(parent, player)
    parent.clear()
    local trusted = Session.get_trusted_table()
    if player.admin or trusted[player.name] then
        local btn =
            parent.add {
            type = 'sprite-button',
            name = confirmed_button_name,
            tooltip = 'Do you really want to remove: ' .. parent.name,
            style = 'shortcut_bar_button_red',
            sprite = 'utility/confirm_slot'
        }
        btn.style.height = 23
        btn.style.width = 23
        btn.style.padding = -2
    else
        local btn =
            parent.add {
            type = 'sprite-button',
            name = confirmed_button_name,
            enabled = 'false',
            tooltip = 'You have not grown accustomed to this technology yet. Ask and admin to /trust ' .. player.name .. '.',
            style = 'shortcut_bar_button_red',
            sprite = 'utility/confirm_slot'
        }
        btn.style.height = 23
        btn.style.width = 23
        btn.style.padding = -2
    end
    local btn =
        parent.add {
        type = 'sprite-button',
        name = cancel_button_name,
        tooltip = 'Cancel deletion of: ' .. parent.name,
        style = 'shortcut_bar_button_blue',
        sprite = 'utility/reset'
    }
    btn.style.height = 23
    btn.style.width = 23
    btn.style.padding = -2
end

local warp_icon_button

local function draw_player_warp_only(player, p, table, sub_table, name, warp, e)
    if not warp.tag or not warp.tag then
        for k, v in pairs(game.forces) do
            v.add_chart_tag(
                warp.surface,
                {
                    position = warp.position,
                    text = 'Warp: ' .. name,
                    icon = {type = 'item', name = warp_item}
                }
            )
        end
    end
    local flow =
        table.add {
        type = 'flow',
        caption = warp.name
    }
    warp_icon_button(flow, warp)

    table.add {
        type = 'label',
        caption = name,
        style = 'caption_label',
        tooltip = 'Created by: ' .. warp.created_by .. '\nShared: ' .. tostring(warp.shared)
    }

    local _flows3 = table.add {type = 'flow'}
    _flows3.style.horizontal_align = 'right'
    _flows3.style.horizontally_stretchable = true

    local bottom_warp_flow = table.add {type = 'flow', name = name}

    if bottom_warp_flow.name ~= 'Spawn' then
        local remove_warp_flow =
            bottom_warp_flow.add {
            type = 'sprite-button',
            name = remove_warp_button_name,
            tooltip = 'Removes warp: ' .. bottom_warp_flow.name,
            style = m_gui.button_style,
            sprite = 'utility/trash'
        }
        remove_warp_flow.style.padding = -2
        remove_warp_flow.style.height = 23
        remove_warp_flow.style.width = 23
    end

    if p.creating == true then
        draw_create_warp(sub_table, player)
        p.creating = false
    end

    if p.removing == true then
        if bottom_warp_flow.name == e then
            draw_remove_warp(bottom_warp_flow, player)
            p.removing = false
        end
    end
end

local function draw_main_frame(player, left, are_you_sure)
    local e = are_you_sure
    local p = get_player_data(player)
    local trusted = Session.get_trusted_table()

    local frame = Gui.add_main_frame(left, main_frame_name, 'Warps', 'Warp to places!')

    local tbl = frame.add {type = 'table', column_count = 1}

    local _flows1 = tbl.add {type = 'flow'}
    --_flows1.style.minimal_width = 150
    _flows1.style.horizontally_stretchable = true

    local warp_list =
        _flows1.add {
        type = 'scroll-pane',
        direction = 'vertical',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto',
        style = 'scroll_pane_under_subheader'
    }
    local scroll_style = warp_list.style
    scroll_style.padding = {1, 3}
    scroll_style.maximal_height = 200
    warp_list.style.minimal_height = 200
    scroll_style.horizontally_stretchable = true

    local table = warp_list.add {type = 'table', column_count = 4}

    local sub_table = warp_list.add {type = 'table', column_count = 4}
    sub_table.style.cell_padding = 4

    for name, warp in pairs(warp_table) do
        if p.only_my_warps then
            if (warp.created_by == player.name or warp.created_by == 'script') then
                draw_player_warp_only(player, p, table, sub_table, name, warp, e)
            end
        else
            if (warp.created_by == player.name and not warp.shared) then
                draw_player_warp_only(player, p, table, sub_table, name, warp, e)
            elseif warp.shared == true then
                draw_player_warp_only(player, p, table, sub_table, name, warp, e)
            end
        end
    end

    local bottom_flow = frame.add {type = 'flow', direction = 'horizontal'}

    bottom_flow.add {
        type = 'checkbox',
        state = p.only_my_warps,
        name = show_only_player_warps,
        caption = 'Show only my warps.'
    }

    local bottom_bottom_flow = frame.add {type = 'flow', direction = 'horizontal'}

    local left_flow = bottom_bottom_flow.add {type = 'flow'}
    left_flow.style.horizontal_align = 'left'
    left_flow.style.horizontally_stretchable = true

    local close_button = left_flow.add {type = 'button', name = close_main_frame_name, caption = 'Close'}
    Tabs.apply_button_style(close_button)

    local button_flow = left_flow.add {type = 'flow'}
    button_flow.style.horizontal_align = 'right'
    button_flow.style.horizontally_stretchable = true

    if trusted[player.name] or player.admin then
        local button = button_flow.add {type = 'button', name = create_warp_button_name, caption = 'Create Warp'}
        Tabs.apply_button_style(button)
    else
        local button =
            button_flow.add {
            type = 'button',
            name = create_warp_button_name,
            caption = 'Create Warp.',
            enabled = false,
            tooltip = 'You have not grown accustomed to this technology yet. Ask and admin to /trust ' .. player.name .. '.'
        }
        Tabs.apply_button_style(button)
    end
end

function Public.toggle(player)
    local gui = player.gui
    local left = gui.left
    local main_frame = left[main_frame_name]

    if not validate_player(player) then
        return
    end

    if main_frame then
        Public.close_gui_player(main_frame)
        Tabs.panel_clear_left_gui(player)
    else
        Tabs.panel_clear_left_gui(player)
        draw_main_frame(player, left)
    end
end

function Public.refresh_gui_player(player, are_you_sure, close)
    local e = are_you_sure
    local gui = player.gui
    local left = gui.left
    local main_frame = left[main_frame_name]

    if not validate_player(player) then
        return
    end

    if main_frame then
        Public.close_gui_player(main_frame)
        if not close then
            draw_main_frame(player, left, e)
        end
    end
end

function Public.close_gui_player(frame)
    if frame and frame.valid then
        frame.destroy()
    end
end

function Public.is_spam(p, player)
    if p.spam > game.tick then
        player.print(
            'Please wait ' .. math.ceil((p.spam - game.tick) / 60) .. ' seconds before trying to warp or add warps again.',
            Color.warning
        )
        return true
    end
    return false
end

function Public.clear_player_table(player)
    local p = get_player_data(player)
    if p.removing == true then
        p.removing = false
    end
    if p.creating == true then
        p.creating = false
    end
end

function Public.refresh_gui()
    for _, player in pairs(game.connected_players) do
        local gui = player.gui
        local left = gui.left

        if not validate_player(player) then
            return
        end

        local main_frame = left[main_frame_name]

        if not player.connected then
            Public.close_gui_player(main_frame)
            return
        end

        if main_frame then
            Public.close_gui_player(main_frame)
            draw_main_frame(player, left)
        end
    end
end

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)

    if not validate_player(player) then
        return
    end

    get_player_data(player)

    Public.create_warp_button(player, false)
end

local function on_player_left_game(event)
    local player = game.get_player(event.player_index)

    if not validate_player(player) then
        return
    end

    Tabs.panel_clear_left_gui(player)
end

local function on_player_died(event)
    local player = game.get_player(event.player_index)

    if not validate_player(player) then
        return
    end

    local p = player.gui.left[main_frame_name]

    if not p then
        return
    end

    Public.close_gui_player(p)
end

Gui.on_click(
    main_button_name,
    function(event)
        local element = event.element
        if not element then
            return
        end
        local player = Gui.get_player_from_element(element)
        if not validate_player(player) then
            return
        end

        Public.toggle(player)
        Public.clear_player_table(player)
    end
)

Gui.on_click(
    close_main_frame_name,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        Public.toggle(player)
        Public.clear_player_table(player)
    end
)

Gui.on_click(
    remove_warp_button_name,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        local are_you_sure = event.element.parent.name

        local p = get_player_data(player)

        if not p then
            return
        end

        if not p.removing == true then
            p.removing = true
            Public.refresh_gui_player(player, are_you_sure)
        end
    end
)

Gui.on_click(
    create_warp_is_shared,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        local p = get_player_data(player)

        if not p then
            return
        end

        p.shared = event.element.state
    end
)

Gui.on_click(
    show_only_player_warps,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        local p = get_player_data(player)

        if not p then
            return
        end

        p.only_my_warps = event.element.state
        Public.refresh_gui_player(player)
    end
)

Gui.on_click(
    cancel_button_name,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        Public.refresh_gui_player(player)
        Public.clear_player_table(player)
    end
)

Gui.on_click(
    confirmed_button_name,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        local p = get_player_data(player)

        if not p then
            return
        end

        Public.remove_warp_point(event.element.parent.name)
        if p.shared == true then
            game.print(player.name .. ' removed warp: ' .. event.element.parent.name, Color.warning)
        elseif p.shared == false then
            player.print('Removed warp: ' .. event.element.parent.name, Color.warning)
        end
        Public.clear_player_table(player)
        Public.refresh_gui()
    end
)

Gui.allow_player_to_toggle(main_button_name)

Gui.on_click(
    create_warp_button_name,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        local p = get_player_data(player)

        Public.clear_player_table(player)

        if p.creating == false then
            p.creating = true
        end

        Public.refresh_gui_player(player)
        return
    end
)

warp_icon_button =
    Gui.new_frame(
    function(event_trigger, parent, warp)
        local warp_position = warp.position
        -- Draw the element
        local sprite = warp.icon.type .. '/' .. warp.icon.name
        if warp.icon.type == 'virtual' then
            sprite = 'virtual-signal/' .. warp.icon.name
        end

        return parent.add {
            name = event_trigger,
            type = 'sprite-button',
            sprite = sprite,
            tooltip = 'Go to: x:' .. warp_position.x .. ' y: ' .. warp_position.y,
            style = 'slot_button'
        }
    end
):style(Gui.Styles[32]):on_click(
    function(player, element, _)
        local p = get_player_data(player)

        if not p then
            return
        end

        element = element.parent.caption

        local warp

        local position

        if not Roles.get_role(player):allowed('always-warp') then
            if Public.is_spam(p, player) then
                return
            end

            warp = warp_table[element]

            position = player.position

            local area = {
                left_top = {x = position.x - 5, y = position.y - 5},
                right_bottom = {x = position.x + 5, y = position.y + 5}
            }

            if not Public.contains_positions(area) then
                player.print('You are not standing on a warp platform.', Color.warning)
                return
            end

            if (warp.position.x - position.x) ^ 2 + (warp.position.y - position.y) ^ 2 < 1024 then
                player.print('Destination is source warp: ' .. element, Color.fail)
                return
            end
        else
            warp = warp_table[element]
        end

        if player.vehicle then
            player.vehicle.set_driver(nil)
        end
        if player.vehicle then
            player.vehicle.set_passenger(nil)
        end
        if player.vehicle then
            return
        end

        player.teleport(warp.surface.find_non_colliding_position('character', warp.position, 32, 1), warp.surface)
        player.print('Warped you over to: ' .. element, Color.success)
        player.play_sound {path = 'utility/armor_insert', volume_modifier = 1}
        p.spam = game.tick + 900

        Public.clear_player_table(player)

        Public.refresh_gui_player(player, nil, true)
        return
    end
)

Gui.on_click(
    create_warp_func_name,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        local p = get_player_data(player)

        if not Roles.get_role(player):allowed('always-warp') then
            local success = Public.is_spam(p, player)
            if not success then
                return
            end

            local position = player.position

            local area = {
                left_top = {x = position.x - 100, y = position.y - 100},
                right_bottom = {x = position.x + 100, y = position.y + 100}
            }

            if Public.contains_positions(area) then
                player.print('You are too close to another warp!', Color.warning)
                return
            end
        end

        local shared = p.shared
        local icon = p.icon
        if not icon then
            icon = {type = 'item', name = warp_item}
        end

        local new = p.frame.new_name.text
        if new == '' or new == 'Spawn' or new == 'Name:' or new == 'Warp name:' then
            return player.print('Warp name is not valid.', Color.fail)
        end
        if string.len(new) > 30 then
            player.print('Warp name is too long!', Color.fail)
            return
        end
        local position = player.position
        if warp_table[new] then
            player.print('Warp name already exists!', Color.fail)
            return
        end
        p.spam = game.tick + 900
        Public.make_warp_point(player, position, player.surface, icon, player.force, new, shared)
        if p.shared == true then
            game.print(player.name .. ' created warp: ' .. new, Color.success)
        elseif p.shared == false then
            player.print('Created warp: ' .. new, Color.success)
        end
        Public.refresh_gui()
        Public.clear_player_table(player)
        return
    end
)

Gui.on_elem_changed(
    warp_icon_name,
    function(event)
        local player = game.get_player(event.player_index)

        if not validate_player(player) then
            return
        end

        local element = event.element

        if not (element and element.valid) then
            return
        end

        local p = get_player_data(player)
        p.icon = {type = element.elem_value.type, name = element.elem_value.name}
    end
)

Event.add(
    defines.events.on_tick,
    function()
        if game.tick == 50 then
            Public.make_tag('Spawn', {x = 0, y = 0}, true)
        end
    end
)

Event.add(defines.events.on_player_died, on_player_died)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game, on_player_left_game)
Event.add(
    Roles.events.on_role_change,
    function(event)
        local player = game.players[event.player_index]
        Public.create_warp_button(player)
    end
)

return Public
