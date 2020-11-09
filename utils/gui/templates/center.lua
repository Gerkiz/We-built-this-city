local Event = require 'utils.event'
local Core = require 'utils.gui'
local Color = require 'utils.color_presets'
local m_gui = require 'mod-gui'

local center = {}
center._center = {}

local function is_type(v, test_type)
    return test_type and v and type(v) == test_type or not test_type and not v or false
end

--- Adds a new obj to the center gui
-- @usage Gui.center.add{name='foo',caption='Foo',tooltip='Testing',draw=function}
-- @param obj contains the new object, needs name, fraw is opt and is function(root_frame)
-- @return the object made, used to add tabs
function center.add(obj)
    if not is_type(obj, 'table') then
        return
    end
    if not is_type(obj.name, 'string') then
        return
    end
    setmetatable(obj, {__index = center._center})
    obj.tabs = {}
    obj._tabs = {}
    Core.store_meta('center', obj.name, obj)
    Core.toolbar.add(obj.name, obj.caption, obj.tooltip, obj.open)
    return obj
end

-- used to get the center frame of the player, used mainly in script
function center.get_flow(player)
    local gui = player.gui
    local c = gui.center
    return c.wbtc_center or c.add {name = 'wbtc_center', type = 'flow'}
end

-- used to clear the center frame of the player, used mainly in script
function center.clear(player)
    center.get_flow(player).clear()
end

-- used on the button press when the toolbar button is press, can be overriden
function center._center.open(event)
    local player = game.players[event.player_index]
    local frame = Core.store_meta('center')[event.element.name]
    local parent = center.get_flow(player)
    if parent[frame.name] then
        center.clear(player)
        return
    end
    local child =
        parent.add {
        name = frame.name,
        type = 'frame',
        caption = frame.caption,
        direction = 'vertical',
        style = m_gui.frame_style
    }
    if is_type(child.caption, 'string') and player.gui.is_valid_sprite_path(child.caption) then
        child.caption = ''
    end
    if is_type(frame.draw, 'function') then
        local success, err = pcall(frame.draw, frame, child)
        if not success then
            error(err)
        end
    else
        error('No Callback on center frame ' .. frame.name)
    end
    player.opened = child
end

-- this is the default draw function if one is not provided
function center._center:draw(frame)
    Core.bar(frame, 510)
    local tab_bar =
        frame.add {
        type = 'frame',
        name = 'tab_bar',
        style = 'deep_frame_in_shallow_frame',
        direction = 'vertical'
    }
    tab_bar.style.width = 510
    tab_bar.style.height = 65
    local tab_bar_scroll =
        tab_bar.add {
        type = 'scroll-pane',
        name = 'tab_bar_scroll',
        horizontal_scroll_policy = 'auto-and-reserve-space',
        vertical_scroll_policy = 'never'
    }
    tab_bar_scroll.style.vertically_squashable = false
    tab_bar_scroll.style.vertically_stretchable = true
    tab_bar_scroll.style.width = 500
    local tab_bar_scroll_flow =
        tab_bar_scroll.add {
        type = 'flow',
        name = 'tab_bar_scroll_flow',
        direction = 'horizontal'
    }
    Core.bar(frame, 510)
    local tab =
        frame.add {
        type = 'frame',
        name = 'tab',
        direction = 'vertical',
        style = 'deep_frame_in_shallow_frame'
    }
    tab.style.width = 510
    tab.style.height = 305
    local tab_scroll =
        tab.add {
        type = 'scroll-pane',
        name = 'tab_scroll',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto'
    }
    tab_scroll.style.vertically_squashable = false
    tab_scroll.style.vertically_stretchable = true
    tab_scroll.style.width = 500
    local tab_scroll_flow =
        tab_scroll.add {
        type = 'flow',
        name = 'tab_scroll_flow',
        direction = 'vertical'
    }
    tab_scroll_flow.style.width = 480
    Core.bar(frame, 510)
    local first_tab = nil
    for name, button in pairs(self.tabs) do
        first_tab = first_tab or name
        button:draw(tab_bar_scroll_flow).style.font_color = Color.white
    end
    self._tabs[self.name .. '_' .. first_tab](tab_scroll_flow)
    tab_bar_scroll_flow.children[1].style.font_color = Color.red
    frame.parent.add {type = 'frame', name = 'temp'}.destroy()
    --recenter the GUI
end

--- If deafult draw is used then you can add tabs to the gui with this function
-- @usage _center:add_tab('foo','Foo','Just a tab',function)
-- @tparam string name this is the name of the tab
-- @tparam string caption this is the words that appear on the tab button
-- @tparam[opt] string tooltip the tooltip that is on the button
-- @tparam function callback this is called when button is pressed with function(root_frame)
-- @return self to allow chaining of _center:add_tab
function center._center:add_tab(name, caption, tooltip, callback)
    self._tabs[self.name .. '_' .. name] = callback
    self.tabs[name] =
        Core.inputs.add {
        type = 'sprite-button',
        name = self.name .. '_' .. name,
        caption = caption,
        tooltip = tooltip
    }:on_event(
        'click',
        function(event)
            local tab = event.element.parent.parent.parent.parent.tab.tab_scroll.tab_scroll_flow
            tab.clear()
            local frame_name = tab.parent.parent.parent.name
            local _center = Core.store_meta('center')[frame_name]
            local handler = _center._tabs[event.element.name]
            if is_type(handler, 'function') then
                for _, button in pairs(event.element.parent.children) do
                    if button.name == event.element.name then
                        button.style.font_color = Color.red
                    else
                        button.style.font_color = Color.white
                    end
                end
                local success, err = pcall(handler, tab)
                if not success then
                    error(err)
                end
            end
        end
    )
    return self
end

-- used so that when gui close key is pressed this will close the gui
Event.add(
    defines.events.on_gui_closed,
    function(event)
        if event.element and event.element.valid then
            event.element.destroy()
        end
    end
)

return center
