local Event = require 'utils.event'
local Gui = require 'utils.gui.main'
local m_gui = require 'mod-gui'
local mod = m_gui.get_button_flow

local popup = {}
popup._popup = {}

local function is_type(v, test_type)
    return test_type and v and type(v) == test_type or not test_type and not v or false
end

function popup._load()
    popup._popup.close =
        Gui.inputs.add {
        type = 'sprite-button',
        name = 'popup-close',
        caption = 'utility/set_bar_slot',
        tooltip = 'Close This Popup'
    }:on_event(
        'click',
        function(event)
            local frame = event.element.parent
            if frame and frame.valid then
                frame.destroy()
            end
        end
    )
end

--- Used to add a popup gui style
-- @usage Gui.left.add{name='foo',caption='Foo',draw=function}
-- @param obj this is what will be made, needs a name and a draw function(root_frame,data)
-- @return the object that is made to... well idk but for the future
function popup.add(obj)
    if not is_type(obj, 'table') then
        return
    end
    if not is_type(obj.name, 'string') then
        return
    end
    setmetatable(obj, {__index = popup._popup})
    local name = obj.name
    obj.name = nil
    Gui.fetch_data('popup', name, obj)
    obj.name = name
    return obj
end

-- this is used by the script to find the popup flow
function popup.flow(event)
    local player = game.players[event.player_index]
    local flow = mod(player).popups or mod(player).add {name = 'popups', type = 'flow', direction = 'vertical'}
    return flow
end

--- Use to open a popup for these players
-- @usage Gui.popup.open('ban',nil,{player=1,reason='foo'})
-- @tparam string style this is the name you gave to the popup when added
-- @param data this is the data that is sent to the draw function
-- @tparam[opt=game.connected_players] table players the players to open the popup for
function popup.open(style, data, players)
    local _popup = Gui.fetch_data('popup')[style]
    players = players or game.connected_players
    data = data or {}
    if not _popup then
        return
    end
    if _popup.left then
        Gui.left.close(_popup.left.name)
    end
    for _, player in pairs(players) do
        local flow = popup.flow(player)
        local _frame =
            flow.add {
            type = 'frame',
            direction = 'horizontal',
            style = m_gui.frame_style
        }
        local frame =
            _frame.add {
            type = 'frame',
            name = 'inner_frame',
            direction = 'vertical',
            style = 'deep_frame_in_shallow_frame'
        }
        _popup.close:draw(_frame)
        if is_type(_popup.draw, 'function') then
            local success, err = pcall(_popup.draw, frame, data)
            if not success then
                error(err)
            end
        else
            error('No Draw On Popup ' .. _popup.name)
        end
    end
end

function popup._popup:add_left(obj)
    obj.name = obj.name or self.name
    self.left = Gui.left.add(obj)
end

Event.add(defines.events.on_player_joined_game, popup.flow)

return popup
