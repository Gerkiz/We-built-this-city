-- rocket_launch.lua
-- May 2019

-- This is meant to extract out any rocket launch related logic to support my oarc scenario designs.

local Utils = require 'map_gen.multiplayer_spawn.lib.oarc_utils'
local Config = require 'map_gen.multiplayer_spawn.config'
local Tabs = require 'utils.gui.main'

local Public = {}
--------------------------------------------------------------------------------
-- Rocket Launch Event Code
-- Controls the "win condition"
--------------------------------------------------------------------------------
function Public.RocketLaunchEvent(event)
    local force = event.rocket.force

    -- Notify players on force if rocket was launched without sat.
    if event.rocket.get_item_count('satellite') == 0 then
        for index, player in pairs(force.players) do
            player.print("You launched the rocket, but you didn't put a satellite inside.")
        end
        return
    end

    -- First ever sat launch
    if not global.satellite_sent then
        global.satellite_sent = {}
        Utils.SendBroadcastMsg('Team ' .. event.rocket.force.name .. ' was the first to launch a rocket!')

        for _, player in pairs(game.players) do
            Tabs.set_tab(player, 'Rockets', true)
        end
    end

    -- Track additional satellites launched by this force
    if global.satellite_sent[force.name] then
        -- First sat launch for this force.
        global.satellite_sent[force.name] = global.satellite_sent[force.name] + 1
        Utils.SendBroadcastMsg(
            'Team ' ..
                event.rocket.force.name .. ' launched another rocket. Total ' .. global.satellite_sent[force.name]
        )
    else
        -- game.set_game_state{game_finished=true, player_won=true, can_continue=true}
        global.satellite_sent[force.name] = 1
        Utils.SendBroadcastMsg('Team ' .. event.rocket.force.name .. ' launched their first rocket!')
    end
end

return Public
