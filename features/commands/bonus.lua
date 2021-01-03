local Event = require 'utils.event'
local Global = require 'utils.global'
local Modifiers = require 'utils.player_modifiers'
local Color = require 'utils.color_presets'
local Roles = require 'utils.role.main'
local Server = require 'utils.server'

local Public = {}

local this = {}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

function Public.get_table()
    return this
end

local settings = {
    {key = 'character_mining_speed_modifier', scale = 3},
    {key = 'character_crafting_speed_modifier', scale = 3},
    {key = 'character_running_speed_modifier', scale = 3},
    {key = 'character_build_distance_bonus', scale = 20},
    {key = 'character_reach_distance_bonus', scale = 20},
    {key = 'character_inventory_slots_bonus', scale = 200}
}

commands.add_command(
    'bonus',
    'Set your player bonus (speed, mining etc)(Veterans or higher can run this)',
    function(args)
        local player = game.player
        local p_modifer = Modifiers.get_table()
        local _a = p_modifer
        if player then
            if player ~= nil then
                if not Roles.allowed(player, 'bonus') then
                    player.print('[ERROR] Only admins and trusted weebs are allowed to run this command!', Color.fail)
                    return
                end
            end
        end
        if is_loaded('features.modules.towny.table') then
            local TownyTable = is_loaded('features.modules.towny.table')
            local towny = TownyTable.get('towny')
            if towny.town_centers[tostring(player.name)] then
                player.print("Bonus can't be applied. You are in PVP-mode.", Color.warning)
                return
            end
        end
        local bonus = tonumber(args.parameter)
        if not bonus or bonus < 0 or bonus > 50 then
            player.print('Invalid range.', Color.fail)
            return
        end
        for _, setting in pairs(settings) do
            _a[player.index][setting.key]['bonus'] = setting.scale * math.floor(bonus) * 0.01
            player[setting.key] = setting.scale * math.floor(bonus) * 0.01
        end
        this[player.index] = bonus
        player.print('Bonus set to: ' .. math.floor(bonus) .. '%', Color.success)
    end
)

Event.add(
    defines.events.on_player_respawned,
    function(event)
        local player = game.players[event.player_index]
        local bonus = this[player.index]
        if bonus then
            for _, setting in pairs(settings) do
                player[setting.key] = setting.scale * math.floor(bonus) * 0.01
            end
        end
    end
)

Event.add(
    defines.events.on_pre_player_died,
    function(event)
        local player = game.players[event.player_index]
        if Roles.allowed(player, 'bonus-respawn') then
            player.ticks_to_respawn = 120
        -- script.raise_event(defines.events.on_player_died,{
        --     tick=event.tick,
        --     player_index=event.player_index,
        --     cause = event.cause
        -- })
        end
    end
)

return Public
