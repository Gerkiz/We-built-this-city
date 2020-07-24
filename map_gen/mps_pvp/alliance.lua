local Event = require 'utils.event'
local message_color = {r = 0.98, g = 0.66, b = 0.22}

global.renegades = 0

local function CreateLobbySurface()
    local surface = game.create_surface('lobby', {width = 1, height = 1})
    surface.set_tiles({{name = 'out-of-map', position = {1, 1}}})
    surface.always_day = true
end

local function friends()
    for name, team in pairs(game.forces) do
        if name ~= 'Protectors' and name ~= 'scrap_defense' and name ~= 'scrap' and name ~= 'spectator' then
            for x, y in pairs(game.forces) do
                if x ~= 'Protectors' and x ~= 'scrap_defense' and x ~= 'scrap' and x ~= 'spectator' then
                    team.set_friend(x, true)
                    game.forces['enemy'].set_friend(x, true)
                end
            end
        end
    end
end

local function anarchy_gui_button(player)
    if not player.gui.top['anarchy_group_button'] then
        local b =
            player.gui.top.add(
            {type = 'button', name = 'anarchy_group_button', caption = '[Factionless]', tooltip = 'Join a faction!'}
        )
        b.style.font_color = {r = 0.77, g = 0.77, b = 0.77}
        b.style.font = 'default-bold'
        b.style.minimal_height = 38
        b.style.minimal_width = 38
        b.style.top_padding = 2
        b.style.left_padding = 4
        b.style.right_padding = 4
        b.style.bottom_padding = 2
    end
end

local function anarchy_gui(player)
    local group_name_width = 160
    local description_width = 200
    local members_width = 120
    local member_columns = 3
    local actions_width = 60
    local total_height = 350

    if player.gui.center['anarchy_group_frame'] then
        player.gui.center['anarchy_group_frame'].destroy()
    end

    local frame =
        player.gui.center.add(
        {type = 'frame', name = 'anarchy_group_frame', direction = 'vertical', caption = 'Alignment'}
    )
    frame.style.minimal_height = total_height

    local tbl =
        frame.add {
        type = 'scroll-pane',
        direction = 'vertical',
        vertical_scroll_policy = 'always',
        horizontal_scroll_policy = 'never'
    }
    tbl.style.maximal_height = 400
    tbl.style.horizontally_stretchable = true
    tbl.style.minimal_height = 400
    tbl.style.right_padding = 0

    local t = tbl.add({type = 'table', column_count = 5})
    local headings = {
        {'', group_name_width},
        {'', description_width},
        {'', members_width * member_columns},
        {'', actions_width * 2 - 30}
    }
    for _, h in pairs(headings) do
        local l = t.add({type = 'label', caption = h[1]})
        l.style.font_color = {r = 0.98, g = 0.66, b = 0.22}
        l.style.font = 'default-listbox'
        l.style.top_padding = 6
        l.style.minimal_height = 40
        l.style.minimal_width = h[2]
        l.style.maximal_width = h[2]
    end
    local left_flow = frame.add {type = 'flow'}
    left_flow.style.horizontal_align = 'right'
    left_flow.style.horizontally_stretchable = true

    local b = left_flow.add {type = 'button', caption = 'Close', name = 'close_alliance_group_frame'}
    b.style.font = 'default'
    b.style.minimal_height = 30
    b.style.minimal_width = 30
    b.style.top_padding = 2
    b.style.left_padding = 4
    b.style.right_padding = 4
    b.style.bottom_padding = 2

    local scroll_pane =
        tbl.add(
        {
            type = 'scroll-pane',
            name = 'scroll_pane',
            direction = 'vertical',
            horizontal_scroll_policy = 'never',
            vertical_scroll_policy = 'auto'
        }
    )
    scroll_pane.style.maximal_height = total_height - 50
    scroll_pane.style.minimal_height = total_height - 50

    local t = scroll_pane.add({type = 'table', name = 'groups_table', column_count = 4})
    for _, h in pairs(headings) do
        local l = t.add({type = 'label'})
        l.style.minimal_width = h[2]
        l.style.maximal_width = h[2]
    end

    for _, group in pairs(global.alliance_groups) do
        local l = t.add({type = 'label', caption = group.name})
        l.style.font = 'default-bold'
        l.style.top_padding = 16
        l.style.bottom_padding = 16
        l.style.minimal_width = group_name_width
        l.style.maximal_width = group_name_width
        l.style.font_color = group.color
        l.style.single_line = false

        local l = t.add({type = 'label', caption = group.description})
        l.style.top_padding = 16
        l.style.bottom_padding = 16
        l.style.minimal_width = description_width
        l.style.maximal_width = description_width
        l.style.font_color = {r = 0.90, g = 0.90, b = 0.90}
        l.style.single_line = false

        local tt = t.add({type = 'table', column_count = member_columns})
        for _, member in pairs(group.members) do
            local p = game.players[member]
            if p.connected then
                local l = tt.add({type = 'label', caption = tostring(p.name)})
                local color = {r = p.color.r * 0.6 + 0.4, g = p.color.g * 0.6 + 0.4, b = p.color.b * 0.6 + 0.4, a = 1}
                l.style.font_color = color
                l.style.maximal_width = members_width * 2
                l.style.top_padding = 16
                l.style.bottom_padding = 16
            end
        end

        for _, member in pairs(group.members) do
            local p = game.players[member]
            if not p.connected then
                local l = tt.add({type = 'label', caption = tostring(p.name)})
                local color = {r = 0.59, g = 0.59, b = 0.59, a = 1}
                l.style.font_color = color
                l.style.maximal_width = members_width * 2
                l.style.top_padding = 16
                l.style.bottom_padding = 16
            end
        end

        local tt = t.add({type = 'table', name = group.name, column_count = 2})

        if not group.members[tostring(player.name)] then
            if player.tag ~= '' then
            else
                local b = tt.add({type = 'button', caption = 'Join'})
                b.style.font = 'default-bold'
                b.style.minimal_width = actions_width
                b.style.maximal_width = actions_width
            end
        end
         --
        --[[if player.admin then
			if group.members[tostring(player.name)] then
				local b = tt.add({ type = "button", caption = "Leave"})
				b.style.font = "default-bold"
				b.style.minimal_width = actions_width
				b.style.maximal_width = actions_width
			end
		end]] if
            group.name == 'Protectors'
         then
        else
            if group.members[tostring(player.name)] then
                if global.spawn_protection[tostring(player.name)] > game.tick then
                    local b =
                        tt.add(
                        {
                            type = 'button',
                            caption = 'Set Spawn',
                            enabled = 'false',
                            tooltip = 'Please wait ' ..
                                math.ceil((global.spawn_protection[tostring(player.name)] - game.tick) / 60) ..
                                    ' seconds before setting spawn point.'
                        }
                    )
                    b.style.font = 'default-bold'
                    b.style.minimal_width = 90
                    b.style.maximal_width = 90
                else
                    local b = tt.add({type = 'button', caption = 'Set Spawn'})
                    b.style.font = 'default-bold'
                    b.style.minimal_width = 90
                    b.style.maximal_width = 90
                end
            end
        end
    end
end

local function refresh_gui()
    for _, p in pairs(game.connected_players) do
        if p.gui.center['anarchy_group_frame'] then
            anarchy_gui(p)
        end
    end
end

local function refresh_alliances()
    for _, group in pairs(global.alliance_groups) do
        for _, member in pairs(group.members) do
            local player = game.players[member]
            player.gui.top['anarchy_group_button'].caption = '[' .. group.name .. ']'
            player.tag = '[' .. group.name .. ']'
        end
    end
    refresh_gui()
end

local function on_gui_click(event)
    if not event then
        return
    end
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end
    local player = game.players[event.element.player_index]
    local surface = player.surface
    local nauvis = game.surfaces['nauvis']
    local name = event.element.name

    local frame = player.gui.center['anarchy_group_frame']
    if name == 'main' then
        new_group(frame, player)
        return
    end

    local p = event.element.parent
    if p then
        p = p.parent
    end
    if p then
        if p.name == 'groups_table' then
            if event.element.type == 'button' and event.element.caption == 'Join' then
                if player.tag ~= '' then
                    player.print('You are already in a group.', {r = 191, g = 78, b = 78})
                    player.play_sound {path = 'utility/cannot_build'}
                    return
                end
                if event.element.parent.name == 'Protectors' then
                    if #game.forces['Protectors'].connected_players > 1 then
                        if #game.forces['Protectors'].connected_players > global.renegades then
                            player.print(
                                'Team Protectors has too many players currently.',
                                {r = 0.98, g = 0.66, b = 0.22}
                            )
                            return
                        end
                    end
                    global.alliance_groups['Protectors'].members[tostring(player.name)] = player.index
                    game.print(tostring(player.name) .. ' has joined Protectors!', message_color)
                    player.force = game.forces['Protectors']
                    local p =
                        nauvis.find_non_colliding_position(
                        'character',
                        game.forces['Protectors'].get_spawn_position(nauvis),
                        8,
                        0.5
                    )
                    player.teleport(p, nauvis)
                    game.players[tostring(player.name)].gui.center['anarchy_group_frame'].destroy()
                    friends()
                    refresh_alliances()
                    return
                end
                if event.element.parent.name == 'Renegades' then
                    if global.renegades > 1 then
                        if global.renegades > #game.forces['Protectors'].connected_players then
                            player.print(
                                'Team Renegades has too many players currently.',
                                {r = 0.98, g = 0.66, b = 0.22}
                            )
                            return
                        end
                    end
                    global.alliance_groups['Renegades'].members[tostring(player.name)] = player.index
                    game.print(tostring(player.name) .. ' has joined Renegades!', {r = 191, g = 78, b = 78})
                    game.create_force(player.name)
                    --player.teleport({x=-350, y=170}, game.surfaces["nauvis"])
                    player.force = game.forces[player.name]
                    game.forces[player.name].set_friend('Protectors', false)
                    game.forces['Protectors'].set_friend(player.name, false)
                    game.forces[player.name].set_spawn_position({x = -600, y = 600}, nauvis)
                    local p =
                        nauvis.find_non_colliding_position(
                        'character',
                        game.forces[player.name].get_spawn_position(nauvis),
                        8,
                        0.5
                    )
                    player.teleport(p, nauvis)
                    game.forces[player.name].technologies['artillery'].enabled = false
                    game.forces[player.name].technologies['personal-laser-defense-equipment'].enabled = false
                    game.forces[player.name].technologies['atomic-bomb'].enabled = false
                    game.players[tostring(player.name)].gui.center['anarchy_group_frame'].destroy()
                    friends()
                    refresh_alliances()
                    global.renegades = global.renegades + 1
                    return
                end
            end
            if event.element.type == 'button' and event.element.caption == 'Set Spawn' then
                for _, group in pairs(global.alliance_groups) do
                    for _, member in pairs(group.members) do
                        local p = game.players[member]
                        if global.spawn_protection[tostring(player.name)] > game.tick then
                            player.print(
                                'Please wait ' ..
                                    math.ceil((global.spawn_protection[tostring(player.name)] - game.tick) / 60) ..
                                        ' seconds before setting spawn point.',
                                message_color
                            )
                            return
                        end
                        player.force.set_spawn_position(player.position, player.surface)
                        player.print('You have set a new spawn point for your force!', message_color)
                        refresh_alliances()
                        refresh_gui()
                        game.players[tostring(player.name)].gui.center['anarchy_group_frame'].destroy()
                        global.spawn_protection[tostring(player.name)] = game.tick + 16000
                    end
                end
            end
        end
    end

    if name == 'anarchy_group_button' then
        if frame then
            frame.destroy()
        else
            anarchy_gui(player)
        end
    end

    if name == 'close_alliance_group_frame' then
        frame.destroy()
    end
end

local function on_tick(event)
    if event.tick > 15 then
        if not global.map_init_tick then
            --			spawn()
            local startSurface = game.surfaces['lobby']
            e = startSurface.create_entity({name = 'compilatron', position = {10, -10}, force = 'spectator'})
            e.destructible = false
            startSurface.create_entity(
                {
                    name = 'compi-speech-bubble',
                    position = e.position,
                    source = e,
                    text = '[color=0,0.7,0]=^_^=[/color] [color=0.6,0,1] https://www.wbtc.nvfs.se/discord[/color] [color=0,0.7,0]=^_^=[/color]'
                }
            )
            r = startSurface.create_entity({name = 'compilatron', position = {-10, 10}, force = 'spectator'})
            r.destructible = false
            startSurface.create_entity(
                {
                    name = 'compi-speech-bubble',
                    position = r.position,
                    source = r,
                    text = '[img=virtual-signal/signal-info] [color=0,0.7,0]Please join a faction by clicking [Factionless] to start playing! [/color][img=virtual-signal/signal-info]'
                }
            )
            --t = startSurface.create_entity({name = "compilatron", position = {10,10}, force = "spectator"}) t.destructible = false startSurface.create_entity({name = "compi-speech-bubble", position = t.position, source = t, text = "[color=0,0.6,0]Click the [Factionless] button to choose your faction![/color] [img=virtual-signal/signal-info]"})
            global.map_init_tick = true
        end
    end
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
    local surface = game.surfaces[1]
    if not global.alliance_groups then
        global.alliance_groups = {}
    end
    if not global.spam_protection then
        global.spam_protection = {}
    end
    if not global.spam_protection[tostring(player.name)] then
        global.spam_protection[tostring(player.name)] = game.tick
    end
    if not global.spawn_protection then
        global.spawn_protection = {}
    end
    if not global.spawn_protection[tostring(player.name)] then
        global.spawn_protection[tostring(player.name)] = game.tick
    end
    if not global.map_init then
        CreateLobbySurface()
        if not game.forces['spectator'] then
            game.create_force('spectator')
        end
        if not global.alliance_groups['Protectors'] then
            global.alliance_groups['Protectors'] = {
                name = 'Protectors',
                color = {r = 0.98, g = 0.66, b = 0.22},
                description = 'Lawful Good faction!',
                members = {}
            }
        end
        if not game.forces['Protectors'] then
            game.create_force('Protectors')
        end
        if not global.alliance_groups['Renegades'] then
            global.alliance_groups['Renegades'] = {
                name = 'Renegades',
                color = {r = 191, g = 78, b = 78},
                description = 'Chaotic Evil faction!',
                members = {}
            }
        end
        if not game.forces['Renegades'] then
            game.create_force('Renegades')
        end
        game.create_force('scrap')
        game.create_force('scrap_defense')
        game.forces['spectator'].friendly_fire = false
        game.forces['Protectors'].set_spawn_position({x = 0, y = 0}, surface)
        game.forces['Protectors'].technologies['artillery'].enabled = false
        game.forces['Protectors'].technologies['personal-laser-defense-equipment'].enabled = false
        game.forces['Protectors'].technologies['atomic-bomb'].enabled = false
        game.difficulty_settings.recipe_difficulty = 1
        game.map_settings.pollution.enabled = false
        surface.request_to_generate_chunks({-600, 600}, 2)
        --surface.request_to_generate_chunks({0,0}, 2)
        for name, team in pairs(game.forces) do
            if name ~= 'enemy' and name ~= 'Renegades' and name ~= 'scrap_defense' and name ~= 'spectator' then
                for x, y in pairs(game.forces) do
                    if x ~= 'enemy' and x ~= 'Renegades' and x ~= 'scrap_defense' and x ~= 'spectator' then
                        team.set_friend(x, true)
                        ChartRocketSiloAreas(game.surfaces['nauvis'], game.forces[x])
                    end
                end
            end
        end
        global.map_init = true
    end

    --if player.surface.index ~= 3 then
    --	local s = game.surfaces[3]
    --	player.teleport({x=0,y=0}, s)
    --end

    if player.gui.center['group_frame'] then
        player.gui.center['group_frame'].destroy()
    end
    if player.gui.top['group_button'] then
        player.gui.top['group_button'].destroy()
    end

    --anarchy_gui(player)
    anarchy_gui_button(player)

    if player.online_time == 0 then
        player.force = game.forces.spectator
    end

    game.forces['spectator'].clear_chart(player.surface)
end

----------share chat -------------------
local function on_console_chat(event)
    if not event.message then
        return
    end
    if not event.player_index then
        return
    end
    local player = game.players[event.player_index]

    if player.tag then
        if player.tag ~= '' then
            return
        end
    end

    local color = {}
    color = player.color
    color.r = color.r * 0.6 + 0.35
    color.g = color.g * 0.6 + 0.35
    color.b = color.b * 0.6 + 0.35
    color.a = 1

    for _, target_player in pairs(game.connected_players) do
        if target_player.name ~= player.name then
            if target_player.force ~= player.force then
                target_player.print(player.name .. ': ' .. event.message, color)
            end
        end
    end
end

Event.add(defines.events.on_tick, on_tick)
Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
