local Token = require 'utils.token'
local Event = require 'utils.event'
local Global = require 'utils.global'
local mod_gui = require 'mod-gui'
local mod = mod_gui.get_button_flow

local tostring = tostring
local next = next
local insert = table.insert
local on_visible_handlers = {}
local on_pre_hidden_handlers = {}
local top_elements = {}

local Gui = {
    uid = 0,
    events = {},
    defines = {},
    _old = {},
    core_defines = {},
    file_paths = {},
    debug_info = {},
    _mt = {},
    _mt_execute = {
        __call = function(self, parent, ...)
            local element = self.draw(self.name, parent, ...)
            if self.style then
                if element.valid then
                    self.style(element.style, element, ...)
                end
            end
            return element
        end
    }
}

Gui._mt_execute.__index = Gui._mt

local element_data = {}
local element_map = {}

Global.register(
    {
        element_data = element_data,
        element_map = element_map
    },
    function(tbl)
        element_data = tbl.element_data
        element_map = tbl.element_map
    end
)

function Gui._mt:style(object)
    if type(object) == 'table' then
        Gui.debug_info[self.name].style = object
        self.style = function(style)
            for key, value in pairs(object) do
                style[key] = value
            end
        end
    else
        Gui.debug_info[self.name].style = 'Function'
        self.style = object
    end

    return self
end

function Gui._mt:raise_custom_event(event)
    local element = event.element
    if not element or not element.valid then
        return self
    end

    -- Get the event handler for this element
    local handler = self[event.name]
    if not handler then
        return self
    end

    -- Get the player for this event
    local player_index = event.player_index or element.player_index
    local player = game.get_player(player_index)
    if not player or not player.valid then
        return self
    end
    event.player = player

    local success, err = pcall(handler, player, element, event)
    if not success then
        print('###########################################################')
        print('There was an error for GUI element (check below):')
        print('###########################################################')
        error(err)
    end
    return self
end

function Gui.allow_player_to_toggle(elem)
    top_elements[#top_elements + 1] = elem
    return top_elements
end

function Gui.new_frame(object)
    local element = setmetatable({}, Gui._mt_execute)

    local uid = Gui.uid + 1
    Gui.uid = uid
    local name = tostring(uid)
    element.name = name
    Gui.debug_info[name] = {draw = 'None', style = 'None', events = {}}

    if type(object) == 'table' then
        Gui.debug_info[name].draw = object
        object.name = name
        element.draw = function(_, parent)
            return parent.add(object)
        end
    else
        Gui.debug_info[name].draw = 'Function'
        element.draw = object
    end

    local file_path = debug.getinfo(2, 'S').source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
    Gui.file_paths[name] = file_path
    Gui.defines[name] = element

    return element
end

function Gui.uid_name()
    local uid = Gui.new_frame()
    return uid.name
end

Gui.get_top_flow = mod_gui.get_button_flow
Gui.get_left_flow = mod_gui.get_frame_flow

-- Associates data with the LuaGuiElement. If data is nil then removes the data
function Gui.set_data(element, value)
    if type(element) == 'number' then
        return
    end
    local player_index = element.player_index
    local values = element_data[player_index]

    if value == nil then
        if not values then
            return
        end

        values[element.index] = nil

        if next(values) == nil then
            element_data[player_index] = nil
        end
    else
        if not values then
            values = {}
            element_data[player_index] = values
        end

        values[element.index] = value
    end
end
local set_data = Gui.set_data

-- Gets the Associated data with this LuaGuiElement if any.
function Gui.get_data(element)
    local player_index = element.player_index

    local values = element_data[player_index]
    if not values then
        return nil
    end

    return values[element.index]
end

local remove_data_recursively
-- Removes data associated with LuaGuiElement and its children recursively.
function Gui.remove_data_recursively(element)
    if type(element) == 'number' then
        return
    end
    set_data(element, nil)

    local children = element.children

    if not children then
        return
    end

    for _, child in next, children do
        if child.valid then
            remove_data_recursively(child)
        end
    end
end
remove_data_recursively = Gui.remove_data_recursively

local remove_children_data
function Gui.remove_children_data(element)
    if type(element) == 'number' then
        return
    end
    local children = element.children

    if not children then
        return
    end

    for _, child in next, children do
        if child.valid then
            set_data(child, nil)
            remove_children_data(child)
        end
    end
end
remove_children_data = Gui.remove_children_data

function Gui.destroy(element)
    remove_data_recursively(element)
    element.destroy()
end

function Gui.clear(element)
    remove_children_data(element)
    element.clear()
end

function Gui.get_player_from_element(element)
    if not element or not element.valid then
        return
    end
    return game.players[element.player_index]
end

function Gui.toggle_enabled_state(element, state)
    if not element or not element.valid then
        return
    end
    if state == nil then
        state = not element.enabled
    end
    element.enabled = state
    return state
end

function Gui.toggle_visible_state(element)
    if not element or not element.valid then
        return
    end
    if element.visible then
        element.visible = false
    elseif not element.visible then
        element.visible = true
    end
    return element
end

function Gui.destroy_if_valid(element)
    if not element or not element.valid then
        return false
    end
    element.destroy()
    return true
end

function Gui.sprite_style(size, padding, style)
    style = style or {}
    style.padding = padding or -2
    style.height = size
    style.width = size
    return style
end

Gui.Styles = {
    [20] = Gui.sprite_style(20, 0),
    [22] = Gui.sprite_style(20, nil, {right_margin = -3}),
    [23] = Gui.sprite_style(23, nil, {right_margin = -3}),
    [32] = {height = 32, width = 32, left_margin = 1},
    [40] = {height = 40, width = 40, left_margin = 1},
    ['button'] = {
        font = 'default-semibold',
        height = 26,
        minimal_width = 26,
        top_padding = 0,
        bottom_padding = 0,
        left_padding = 2,
        right_padding = 2
    }
}

function Gui.add_main_frame(parent, main_frame_name, frame_name, frame_tooltip, max_height, min_width)
    local main_frame = parent[main_frame_name]
    if main_frame then
        return main_frame
    end
    main_frame =
        parent.add(
        {
            type = 'frame',
            name = main_frame_name,
            caption = frame_name,
            tooltip = frame_tooltip,
            style = 'connect_gui_frame'
        }
    )
    main_frame.style.padding = 9
    main_frame.style.use_header_filler = true
    main_frame.style.maximal_height = max_height or 500
    main_frame.style.maximal_width = 500
    main_frame.style.minimal_width = min_width or 250

    local frame =
        main_frame.add {
        type = 'frame',
        direction = 'vertical',
        style = 'window_content_frame_packed'
    }
    frame.style.padding = 4
    frame.style.horizontally_stretchable = true
    frame.style.maximal_height = max_height or 500
    frame.style.maximal_width = 500
    frame.style.minimal_width = min_width or 250

    return frame, main_frame
end

Gui.top_flow_button_style = mod_gui.button_style
Gui.top_flow_button_visible_style = 'menu_button_continue'

function Gui.toolbar_button_style(button, state)
    if state then
        button.style = Gui.top_flow_button_visible_style
    else
        button.style = Gui.top_flow_button_style
    end
    button.style.minimal_width = 36
    button.style.height = 36
    button.style.width = 36
    button.style.padding = 1
end

local function event_handler_factory(event_name)
    Event.add(
        event_name,
        function(event)
            local element = event.element
            if not element or not element.valid then
                return
            end
            local element_define = Gui.defines[element.name]
            if not element_define then
                return
            end
            element_define:raise_custom_event(event)
        end
    )

    return function(self, handler)
        insert(Gui.debug_info[self.name].events, debug.getinfo(1, 'n').name)
        self[event_name] = handler
        return self
    end
end

local function custom_raise(handlers, element, player)
    local handler = handlers[element.name]
    if not handler then
        return
    end

    handler({element = element, player = player})
end

--- Called when the player opens a GUI.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_open(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_open = event_handler_factory(defines.events.on_gui_opened)

--- Called when the player closes the GUI they have open.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_close(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_close = event_handler_factory(defines.events.on_gui_closed)

--- Called when LuaGuiElement is clicked.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_click(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_click = event_handler_factory(defines.events.on_gui_click)

--- Called when a LuaGuiElement is confirmed, for example by pressing Enter in a textfield.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_confirmed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_confirmed = event_handler_factory(defines.events.on_gui_confirmed)

--- Called when LuaGuiElement checked state is changed (related to checkboxes and radio buttons).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_checked_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_checked_changed = event_handler_factory(defines.events.on_gui_checked_state_changed)

--- Called when LuaGuiElement element value is changed (related to choose element buttons).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_elem_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_elem_changed = event_handler_factory(defines.events.on_gui_elem_changed)

--- Called when LuaGuiElement element location is changed (related to frames in player.gui.screen).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_location_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_location_changed = event_handler_factory(defines.events.on_gui_location_changed)

--- Called when LuaGuiElement selected tab is changed (related to tabbed-panes).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_tab_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_tab_changed = event_handler_factory(defines.events.on_gui_selected_tab_changed)

--- Called when LuaGuiElement selection state is changed (related to drop-downs and listboxes).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_selection_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_selection_changed = event_handler_factory(defines.events.on_gui_selection_state_changed)

--- Called when LuaGuiElement switch state is changed (related to switches).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_switch_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_switch_changed = event_handler_factory(defines.events.on_gui_switch_state_changed)

--- Called when LuaGuiElement text is changed by the player.
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_text_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_text_changed = event_handler_factory(defines.events.on_gui_text_changed)

--- Called when LuaGuiElement slider value is changed (related to the slider element).
-- @tparam function handler the event handler which will be called
-- @usage element_define:on_value_changed(function(event)
--  event.player.print(table.inspect(event))
--end)
Gui._mt.on_value_changed = event_handler_factory(defines.events.on_gui_value_changed)

local function handler_factory(event_name)
    return function(element_name, handler)
        local element = Gui.defines[element_name]
        if not element then
            return
        end
        element[event_name](
            element,
            function(_, _, event)
                handler(event)
            end
        )
    end
end

-- Register a handler for the on_gui_confirmed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_gui_confirmed = handler_factory('on_confirmed')

-- Register a handler for the on_gui_checked_state_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_checked_state_changed = handler_factory('on_checked_changed')

-- Register a handler for the on_gui_selected_tab_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.tab_changed = handler_factory('on_tab_changed')

-- Register a handler for the on_gui_location_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_gui_location_changed = handler_factory('on_location_changed')

-- Register a handler for the on_gui_click event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_click = handler_factory('on_click')

-- Register a handler for the on_gui_closed event for a custom LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_custom_close = handler_factory('on_close')

-- Register a handler for the on_gui_elem_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_elem_changed = handler_factory('on_elem_changed')

-- Register a handler for the on_gui_selection_state_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_selection_state_changed = handler_factory('on_selection_changed')

-- Register a handler for the on_gui_text_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_text_changed = handler_factory('on_text_changed')

-- Register a handler for the on_gui_value_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_value_changed = handler_factory('on_value_changed')

local main_button_name = Gui.uid_name()

Event.add(
    defines.events.on_player_created,
    function(event)
        local player = game.get_player(event.player_index)

        if not player or not player.valid then
            return
        end

        local b =
            mod(player).add(
            {
                type = 'sprite-button',
                name = main_button_name,
                sprite = 'utility/preset',
                style = mod_gui.button_style,
                tooltip = 'Click to toggle hide top buttons!'
            }
        )
        b.style.padding = 2
        b.style.width = 20
    end
)

Gui.on_click(
    main_button_name,
    function(event)
        local button = event.element
        local player = event.player
        local top = mod(player)

        if button.sprite == 'utility/preset' then
            for i = 1, #top_elements do
                local name = top_elements[i]
                local ele = top[name]
                if ele and ele.valid then
                    if ele.visible then
                        custom_raise(on_pre_hidden_handlers, ele, player)
                        ele.visible = false
                    end
                end
            end

            button.sprite = 'utility/expand_dots_white'
            button.tooltip = 'Click to toggle show top buttons!'
        else
            for i = 1, #top_elements do
                local name = top_elements[i]
                local ele = top[name]
                if ele and ele.valid then
                    if not ele.visible then
                        ele.visible = true
                        custom_raise(on_visible_handlers, ele, player)
                    end
                end
            end

            button.sprite = 'utility/preset'
            button.tooltip = 'Click to toggle show top buttons!'
        end
    end
)

if _DEBUG then
    local concat = table.concat

    local names = {}
    Gui.names = names

    function Gui.uid_name()
        local info = debug.getinfo(2, 'Sl')
        local filepath = info.source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
        local line = info.currentline

        local token = tostring(Token.uid())

        local name = concat {token, ' - ', filepath, ':line:', line}
        names[token] = name

        return token
    end

    function Gui.set_data(element, value)
        if type(element) == 'number' then
            return
        end
        local player_index = element.player_index
        local values = element_data[player_index]

        if value == nil then
            if not values then
                return
            end

            local index = element.index
            values[index] = nil
            element_map[index] = nil

            if next(values) == nil then
                element_data[player_index] = nil
            end
        else
            if not values then
                values = {}
                element_data[player_index] = values
            end

            local index = element.index
            values[index] = value
            element_map[index] = element
        end
    end
    set_data = Gui.set_data

    function Gui.data()
        return element_data
    end

    function Gui.element_map()
        return element_map
    end
end

return Gui
