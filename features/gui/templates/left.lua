local Event = require 'utils.event'
local Core = require 'features.gui.main'
local m_gui = require "mod-gui"
local mod = m_gui.get_frame_flow

local left = {}
left._left = {}

local function is_type(v,test_type)
    return test_type and v and type(v) == test_type or not test_type and not v or false
end

--- Used to add a left gui frame
-- @usage Gui.left.add{name='foo',caption='Foo',tooltip='just testing',open_on_join=true,can_open=function,draw=function}
-- @param obj this is what will be made, needs a name and a draw function(root_frame), open_on_join can be used to set the deaful state true/false, can_open is a test to block it from opening but is not needed
-- @return the object that is made to... well idk but for the future
function left.add(obj)
    if not is_type(obj,'table') then return end
    if not is_type(obj.name,'string') then return end
    setmetatable(obj,{__index=left._left})
    Core._add_data('left',obj.name,obj)
    Core.toolbar.add(obj.name,obj.caption,obj.tooltip,obj.toggle)
    return obj
end

function left.add1(obj)
    if not is_type(obj,'table') then return end
    if not is_type(obj.name,'string') then return end
    setmetatable(obj,{__index=left._left})
    Core._add_data('left',obj.name,obj)
    Core.toolbar.add1(obj.name,obj.sprite,obj.tooltip)
    return obj
end


--- This is used to update all the guis of conected players, good idea to use our thread system as it as nested for loops
-- @usage Gui.left.update()
-- @tparam[opt] string frame this is the name of a frame if you only want to update one
-- @param[opt] players the player to update for, if not given all players are updated, can be one player
function left.update(frame,players)
    local players = is_type(players,'table') and #players > 0 and {unpack(players)} or is_type(players,'table') and {players} or game.players(players) and {game.players(players)} or game.connected_players
    for _,player in pairs(players) do
        local frames = Core._get_data('left') or {}
        if frame then frames = {[frame]=frames[frame]} or {} end
        for name,left in pairs(frames) do
            if _left then
                local fake_event = {player_index=player.index,element={name=name}}
                left.open(fake_event)
            end
        end
    end
end

--- Used to open the left gui of every player
-- @usage Gui.left.open('foo')
-- @tparam string left_name this is the gui that you want to open
function left.open(left_name)
    local _left = Core._get_data('left')[left_name]
    if not _left then return end
    for _,player in pairs(game.connected_players) do
        local left_flow = mod(player)
        if left_flow[_left.name] then left_flow[_left.name].style.visible = true end
    end
end

--- Used to close the left gui of every player
-- @usage Gui.left.close('foo')
-- @tparam string left_name this is the gui that you want to close
function left.close(left_name)
    local _left = Core._get_data('left')[left_name]
    if not _left then return end
    for _,player in pairs(game.connected_players) do
        local left_flow = mod(player)
        if left_flow[_left.name] then left_flow[_left.name].style.visible = false end
    end
end

-- this is used to draw the gui for the first time (these guis are never destoryed), used by the script
function left._left.open(event)
    local player = game.players[event.player_index]
    local _left = Core._get_data('left')[event.element.name]
    local left_flow = mod(player)
    local frame = nil
    if left_flow[_left.name] then 
        frame = left_flow[_left.name] 
        frame.clear()
    else
        frame = left_flow.add{type='frame',name=_left.name,style=mod.frame_style,caption=_left.caption,direction='vertical'}
        frame.style.visible = false
        if is_type(_left.open_on_join,'boolean') then frame.style.visible = _left.open_on_join end
    end
    if is_type(_left.draw,'function') then _left.draw(frame) else frame.style.visible = false error('No Callback On '.._left.name) end
end

-- this is called when the toolbar button is pressed
function left._left.toggle(event)
    local player = game.players[event.player_index]
    local _left = Core._get_data('left')[event.element.name]
    local left_flow = mod(player)
    if not left_flow[_left.name] then _left.open(event) end
    local left = left_flow[_left.name]
    local open = false
    if is_type(_left.can_open,'function') then
        local success, err = pcall(_left.can_open,player)
        if not success then error(err)
        elseif err == true then open = true
        else open = err end
    end
    if open == true and left.style.visible ~= true then
        left.style.visible = true
    else
        left.style.visible = false
    end
    if open == false then player.print("Can't open.") player.play_sound{path='utility/cannot_build'}
    elseif open ~= true then player.print("Can't open.") player.play_sound{path='utility/cannot_build'} end
end

-- draws the left guis when a player first joins, fake_event is just because i am lazy
Event.add(defines.events.on_player_joined_game,function(event)
    local player = game.players[event.player_index]
    local frames = Core._get_data('left') or {}
    for name,left in pairs(frames) do
        local fake_event = {player_index=player.index,element={name=name}}
        left.open(fake_event)
    end
end)

return left