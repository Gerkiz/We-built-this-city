local Event = require 'utils.event'
local Global = require 'utils.global'
local Gui = require 'utils.gui'
local Color = require 'utils.color_presets'
local SpamProtection = require 'utils.spam_protection'
local Token = require 'utils.token'

local disabled_tabs = {}
local main_gui_tabs = {}
local ignored_visibility = {}
local icons = {
    'entity/small-biter',
    'entity/character',
    'entity/medium-biter',
    'entity/character',
    'entity/big-biter',
    'entity/small-biter',
    'entity/character',
    'entity/medium-biter',
    'entity/character',
    'entity/big-biter',
    'entity/small-biter',
    'entity/character',
    'entity/medium-biter',
    'entity/character',
    'entity/big-biter'
}
local main_button_name = Gui.uid_name()
local main_frame_name = Gui.uid_name()

Global.register(
    {disabled_tabs = disabled_tabs, icons = icons},
    function(t)
        disabled_tabs = t.disabled_tabs
        icons = t.icons
    end
)

Gui.events = {on_gui_removal = Event.generate_event_name('on_gui_removal')}

Gui.classes = {}

Gui.my_fixed_width_style = {
    minimal_width = 450,
    maximal_width = 450
}
Gui.my_label_style = {
    single_line = false,
    font_color = {r = 1, g = 1, b = 1},
    top_padding = 0,
    bottom_padding = 0
}
Gui.my_label_header_style = {
    single_line = false,
    font = 'heading-1',
    font_color = {r = 1, g = 1, b = 1},
    top_padding = 0,
    bottom_padding = 0
}
Gui.my_label_header_grey_style = {
    single_line = false,
    font = 'heading-1',
    font_color = {r = 0.6, g = 0.6, b = 0.6},
    top_padding = 0,
    bottom_padding = 0
}
Gui.my_note_style = {
    single_line = false,
    font = 'default-small-semibold',
    font_color = {r = 1, g = 0.5, b = 0.5},
    top_padding = 0,
    bottom_padding = 0
}
Gui.my_warning_style = {
    single_line = false,
    font_color = {r = 1, g = 0.1, b = 0.1},
    top_padding = 0,
    bottom_padding = 0
}
Gui.my_spacer_style = {
    minimal_height = 10,
    top_padding = 0,
    bottom_padding = 0
}
Gui.my_small_button_style = {
    font = 'default-small-semibold'
}
Gui.my_player_list_fixed_width_style = {
    minimal_width = 200,
    maximal_width = 400,
    maximal_height = 200
}
Gui.my_player_list_admin_style = {
    font = 'default-semibold',
    font_color = {r = 1, g = 0.5, b = 0.5},
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
Gui.my_player_list_style = {
    font = 'default-semibold',
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
Gui.my_player_list_offline_style = {
    font_color = {r = 0.5, g = 0.5, b = 0.5},
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
Gui.my_player_list_style_spacer = {
    minimal_height = 20
}
Gui.my_color_red = {r = 1, g = 0.1, b = 0.1}

Gui.my_longer_label_style = {
    maximal_width = 600,
    single_line = false,
    font_color = {r = 1, g = 1, b = 1},
    top_padding = 0,
    bottom_padding = 0
}
Gui.my_longer_warning_style = {
    maximal_width = 600,
    single_line = false,
    font_color = {r = 1, g = 0.1, b = 0.1},
    top_padding = 0,
    bottom_padding = 0
}

Gui.store_meta =
    setmetatable(
    Gui._old,
    {
        __call = function(main_table, sub_table, key, value)
            if not sub_table then
                return main_table
            end
            if not key then
                return rawget(main_table, sub_table) or rawset(main_table, sub_table, {}) and rawget(main_table, sub_table)
            end
            if game then
                error('New guis cannot be added during runtime.', 2)
            end
            if not rawget(main_table, sub_table) then
                rawset(main_table, sub_table, {})
            end
            rawset(rawget(main_table, sub_table), key, value)
        end
    }
)

Gui.store_meta.__index = Gui._mt

function Gui.get_table(key)
    if key == 'tabs' then
        return disabled_tabs
    elseif key == 'icons' then
        return icons
    end
    return Gui.store_meta
end

--- Fetches the main gui tabs. You are forbidden to write as this is local.
---@param key
function Gui.get(key)
    if key then
        return main_gui_tabs[key]
    else
        return main_gui_tabs
    end
end

function Gui.ignored_visibility(elem)
    if not ignored_visibility[elem] then
        ignored_visibility[elem] = true
    elseif ignored_visibility[elem] then
        ignored_visibility[#ignored_visibility + 1] = elem
    end
end

function Gui:_load_parts(parts)
    for _, part in pairs(parts) do
        self[part] = require('objects.' .. part)
    end
end

function Gui.bar(frame, width)
    local line =
        frame.add {
        type = 'progressbar',
        size = 1,
        value = 1
    }
    line.style.height = 3
    line.style.width = width or 10
    line.style.color = Color.white
    return line
end

function Gui.set_dropdown_index(dropdown, _item)
    if not dropdown and not dropdown.valid and not dropdown.items and not _item then
        return
    end
    local _index = 1
    for index, item in pairs(dropdown.items) do
        if item == _item then
            _index = index
            break
        end
    end
    dropdown.selected_index = _index
    return dropdown
end

function Gui.apply_direction_button_style(button)
    local button_style = button.style
    button_style.width = 24
    button_style.height = 24
    button_style.top_padding = 0
    button_style.bottom_padding = 0
    button_style.left_padding = 0
    button_style.right_padding = 0
    button_style.font = 'default-listbox'
end

function Gui.apply_button_style(button)
    local button_style = button.style
    button_style.font = 'default-semibold'
    button_style.height = 26
    button_style.minimal_width = 26
    button_style.top_padding = 0
    button_style.bottom_padding = 0
    button_style.left_padding = 2
    button_style.right_padding = 2
end

--------------------------------------------------------------------------------
-- GUI Functions
--------------------------------------------------------------------------------

-- Apply a style option to a GUI
function Gui.ApplyStyle(guiIn, styleIn)
    for k, v in pairs(styleIn) do
        guiIn.style[k] = v
    end
end

-- Shorter way to add a label with a style
function Gui.AddLabel(guiIn, name, message, style)
    local g =
        guiIn.add {
        name = name,
        type = 'label',
        caption = message
    }
    if (type(style) == 'table') then
        Gui.ApplyStyle(g, style)
    else
        g.style = style
    end
end

function Gui.AddLabelCaption(guiIn, name, style)
    local g =
        guiIn.add {
        type = 'label',
        caption = name
    }
    if (type(style) == 'table') then
        Gui.ApplyStyle(g, style)
    else
        g.style = style
    end
end

-- Shorter way to add a spacer
function Gui.AddSpacer(guiIn)
    Gui.ApplyStyle(guiIn.add {type = 'label', caption = ' '}, Gui.my_spacer_style)
end

function Gui.AddSpacerLine(guiIn)
    Gui.ApplyStyle(guiIn.add {type = 'line', direction = 'horizontal'}, Gui.my_spacer_style)
end

--- This adds the given gui to the main gui.
---@param tbl
function Gui.add_tab_to_gui(tbl)
    if not tbl then
        return
    end
    if not tbl.name then
        return
    end
    if not tbl.id then
        return
    end
    local admin = tbl.admin or false
    local only_server_sided = tbl.only_server_sided or false

    if not main_gui_tabs[tbl.name] then
        main_gui_tabs[tbl.name] = {id = tbl.id, admin = admin, only_server_sided = only_server_sided}
    else
        error('Given name: ' .. tbl.name .. ' already exists in table.')
    end
end

function Gui.get_disabled_tabs()
    return disabled_tabs
end

function Gui.toggle_visibility(player, state)
    local left = player.gui.left
    local screen = player.gui.screen

    for _, child in pairs(left.children) do
        if child.valid and string.sub(child.name, 0, 4) ~= 'fnei' then
            if child.visible then
                child.visible = false
            else
                child.visible = true
            end
        end
    end

    if state == 'left' then
        return
    end

    for _, child in pairs(screen.children) do
        if not ignored_visibility[child.name] then
            if child.visible then
                child.visible = false
            else
                child.visible = true
            end
        end
    end
    return false
end

function Gui.refresh(player)
    local frame = Gui.panel_get_active_frame(player)
    if not frame then
        return
    end

    local t = Gui.get_content(player)

    for k, v in pairs(t.tabs) do
        v.content.clear()
    end
    Gui.panel_refresh_active_tab(player)
end

function Gui.get_panel(player)
    local left = player.gui.left
    if (left[main_frame_name] == nil) then
        return nil
    else
        return left[main_frame_name]
    end
end

function Gui.panel_get_active_frame(player)
    local left = player.gui.left
    if not left[main_frame_name] then
        return false
    end
    if not left[main_frame_name].next.tabbed_pane.selected_tab_index then
        return left[main_frame_name].next.tabbed_pane.tabs[1].content
    end
    return left[main_frame_name].next.tabbed_pane.tabs[left[main_frame_name].next.tabbed_pane.selected_tab_index].content
end

function Gui.get_content(player)
    local left = player.gui.left
    if not left[main_frame_name] then
        return false
    end
    return left[main_frame_name].next.tabbed_pane
end

function Gui.panel_refresh_active_tab(player)
    local frame = Gui.panel_get_active_frame(player)
    if not frame then
        return
    end

    local tab = main_gui_tabs[frame.name]
    if not tab then
        return
    end
    local id = tab.id
    if not id then
        return
    end
    local func = Token.get(id)

    local data = {
        player = player,
        frame = frame
    }

    return func(data)
end

local function top_button(player)
    if Gui.get_button_flow(player)[main_button_name] then
        return
    end
    local b =
        Gui.get_button_flow(player).add(
        {
            type = 'sprite-button',
            name = main_button_name,
            sprite = 'utility/expand_dots',
            style = Gui.button_style,
            tooltip = 'The panel of all the goodies!'
        }
    )
    b.style.padding = 2
    b.style.width = 20
end

local function shuffle(tbl)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = math.random(size)
        tbl[i], tbl[rand] = tbl[rand], tbl[i]
    end
    return tbl
end

local function main_frame(player)
    local left = player.gui.left
    local tabs = main_gui_tabs

    local frame = left.add {type = 'frame', name = main_frame_name, direction = 'vertical', style = 'changelog_subheader_frame'}

    frame.style.minimal_height = 400
    frame.style.maximal_height = 700
    frame.style.padding = 5
    shuffle(icons)
    local inside_frame = frame.add {type = 'frame', name = 'next', style = 'inside_deep_frame', direction = 'vertical'}
    local subhead = inside_frame.add {type = 'frame', name = 'sub_header'}

    Gui.AddLabel(subhead, 'scen_info', 'We built this city ', 'subheader_caption_label')
    for i = 1, 14, 1 do
        local e = subhead.add({type = 'sprite', sprite = icons[i]})
        e.style.maximal_width = 24
        e.style.maximal_height = 24
        e.style.padding = 0
    end

    local t = inside_frame.add {name = 'tabbed_pane', type = 'tabbed-pane', style = 'tabbed_pane'}
    t.style.top_padding = 8

    for name, func in pairs(tabs) do
        if func.only_server_sided then
            local tab = t.add({type = 'tab', caption = name, name = 'tab_' .. name})
            if disabled_tabs[player.index] then
                if disabled_tabs[player.index][name] == false then
                    tab.enabled = false
                end
            end
            local f1 = t.add({type = 'frame', name = name, direction = 'vertical'})
            f1.style.left_margin = 10
            f1.style.right_margin = 10
            f1.style.top_margin = 4
            f1.style.bottom_margin = 4
            f1.style.padding = 5
            f1.style.horizontally_stretchable = true
            f1.style.vertically_stretchable = true
            t.add_tab(tab, f1)
        elseif func.admin then
            if player.admin then
                local tab = t.add({type = 'tab', caption = name, name = 'tab_' .. name})
                if disabled_tabs[player.index] then
                    if disabled_tabs[player.index][name] == false then
                        tab.enabled = false
                    end
                end
                local f1 = t.add({type = 'frame', name = name, direction = 'vertical'})
                f1.style.left_margin = 10
                f1.style.right_margin = 10
                f1.style.top_margin = 4
                f1.style.bottom_margin = 4
                f1.style.padding = 5
                f1.style.horizontally_stretchable = true
                f1.style.vertically_stretchable = true
                t.add_tab(tab, f1)
            end
        else
            local tab = t.add({type = 'tab', caption = name, name = 'tab_' .. name})
            if disabled_tabs[player.index] then
                if disabled_tabs[player.index][name] == false then
                    tab.enabled = false
                end
            end
            local f2 = t.add({type = 'frame', name = name, direction = 'vertical'})
            f2.style.left_margin = 10
            f2.style.right_margin = 10
            f2.style.top_margin = 4
            f2.style.bottom_margin = 4
            f2.style.padding = 5
            f2.style.horizontally_stretchable = true
            f2.style.vertically_stretchable = true
            t.add_tab(tab, f2)
        end
    end

    Gui.panel_refresh_active_tab(player)
end

function Gui.visible(player)
    local left = player.gui.left
    local frame = left[main_frame_name]
    if (frame ~= nil) then
        frame.visible = not frame.visible
    end
end

function Gui.panel_call_tab(player, name)
    local left = player.gui.left
    main_frame(player)
    local tabbed_pane = left[main_frame_name].next.tabbed_pane
    for key, v in pairs(tabbed_pane.tabs) do
        if v.tab.caption == name then
            tabbed_pane.selected_tab_index = key
            Gui.panel_refresh_active_tab(player)
        end
    end
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
    top_button(player)
end

local function on_player_created(event)
    local player = game.players[event.player_index]

    if not disabled_tabs[player.index] then
        disabled_tabs[player.index] = {}
    end
end

function Gui.set_tab(player, tab_name, status)
    local left = player.gui.left
    local name = tab_name
    --Gui.panel_call_tab(player, tab_name)
    local frame = Gui.panel_get_active_frame(player)
    if not frame then
        disabled_tabs[player.index][name] = status
    end

    disabled_tabs[player.index][tab_name] = status
    if left[main_frame_name] then
        left[main_frame_name].destroy()
        main_frame(player)
        return
    end

    Gui.panel_refresh_active_tab(player)
end

function Gui.close_gui_player(player)
    local left = player.gui.left
    local menu_frame = left[main_frame_name]
    if (menu_frame) then
        menu_frame.destroy()
    end
end

function Gui.toggle(player)
    local left = player.gui.left
    local frame = left[main_frame_name]

    if frame then
        Gui.toggle_visibility(player)
    else
        Gui.toggle_visibility(player)
        main_frame(player)
    end
end

Gui.allow_player_to_toggle(main_button_name)

local function on_gui_click(event)
    local element = event.element
    if not element or not element.valid then
        return
    end

    local player = game.players[event.player_index]

    local name = element.name

    if name == main_button_name then
        local is_spamming = SpamProtection.is_spamming(player, nil, 'Main GUI Click')
        if is_spamming then
            return
        end

        Gui.toggle(player)
    end

    if not event.element.caption then
        return
    end
    if event.element.type ~= 'tab' then
        return
    end
    Gui.panel_refresh_active_tab(player)
    Gui.refresh(player)
end

Event.add(
    Gui.events.on_gui_removal,
    function(player)
        local b =
            Gui.get_button_flow(player).add(
            {
                type = 'sprite-button',
                name = main_button_name,
                sprite = 'utility/expand_dots',
                style = Gui.button_style,
                tooltip = 'The panel of all the goodies!'
            }
        )
        b.style.padding = 2
        b.style.width = 20
    end
)
Event.add(defines.events.on_player_created, on_player_created)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_gui_click, on_gui_click)

Gui.main_button_name = main_button_name
Gui.main_frame_name = main_frame_name

return Gui
