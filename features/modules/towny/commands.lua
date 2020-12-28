local TownyTable = require 'features.modules.towny.table'
local Color = require 'utils.color_presets'
local Event = require 'utils.event'

Event.add(
    defines.events.on_console_command,
    function(event)
        local player_index = event.player_index
        if not player_index or event.command ~= 'color' then
            return
        end

        local player = game.get_player(player_index)
        if not player or not player.valid then
            return
        end

        local param = event.parameters
        if not param then
            return
        end

        if param == '' then
            return
        end

        local towny = TownyTable.get('towny')

        local town_center = towny.town_centers[player.force.name]
        if not town_center then
            town_center = towny.town_centers_placeholders[player.force.name]
            if not town_center then
                return
            end
        end

        param = string.lower(param)
        if param then
            for word in param:gmatch('%S+') do
                if Color[word] then
                    town_center.color = Color[word]
                    player.play_sound {path = 'utility/scenario_message', volume_modifier = 1}
                    player.print('[Towny] Color changed successfully!', Color.green)
                    return true
                end
            end
        end
    end
)
