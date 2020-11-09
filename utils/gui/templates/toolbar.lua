local Event = require 'utils.event'
local Gui = require 'utils.gui'
local Roles = require 'utils.role.main'
local Server = require 'utils.server'
local m_gui = require 'mod-gui'
local mod = m_gui.get_button_flow

local toolbar = {}

function toolbar.add(name, caption, tooltip, callback)
    local button = Gui.inputs.add {type = 'sprite-button', name = name, caption = caption, tooltip = tooltip}
    Gui.allow_player_to_toggle(button.name)
    button:on_event(Gui.inputs.events.click, callback)
    Gui.store_meta('toolbar', name, button)
    return button
end

function toolbar.draw(event)
    local player = game.players[event.player_index]
    if not player then
        return
    end
    local frame = mod(player)

    if not Gui.store_meta('toolbar') then
        return
    end
    for name, button in pairs(Gui.store_meta('toolbar')) do
        button:remove(frame)
        if Server.is_type(Roles, 'table') and Roles.config.meta.role_count > 0 then
            local role = Roles.get_role(player)
            if role:allowed(name) then
                button:draw(frame)
            else
                button:remove(frame)
            end
        end
    end
end

Event.add(Roles.events.on_role_change, toolbar.draw)
Event.add(defines.events.on_player_joined_game, toolbar.draw)

return toolbar
