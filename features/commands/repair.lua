--local Session = require 'utils.datastore.session_data'
--local Modifiers = require 'utils.player_modifiers'
local Server = require 'utils.server'
local Color = require 'utils.color_presets'
local Roles = require 'utils.role.main'

-- these items are not repaired, true means it is blocked
local disallow = {
    ['loader'] = true,
    ['fast-loader'] = true,
    ['express-loader'] = true,
    ['electric-energy-interface'] = true,
    ['infinity-chest'] = true
}

local const = 100
-- given const = 100: admin+ has unlimited, admin has 100, mod has 50, member has 20

commands.add_command(
    'repair',
    'Repairs all destroyed and damaged entites in an area',
    function(args)
        local player = game.player
        if player then
            if player ~= nil then
                if not Roles.get_role(player):allowed('repair') then
                    local p = Server.player_return
                    p('[ERROR] Only admins are allowed to run this command!', Color.fail, player)
                    return
                end
            end
        end
        local range = tonumber(args.parameter)
        local role = Roles.get_role(player)
        local highest_admin_power = Roles.get_group('Admin').highest.power - 1
        local max_range = role.power - highest_admin_power > 0 and const / (role.power - highest_admin_power) or nil
        local pos = player.position
        if not range or max_range and range > max_range then
            Server.player_return('Invalid range.', Color.fail, player)
            return
        end
        local radius = {
            {pos.x - range, pos.y - range},
            {pos.x + range, pos.y + range}
        }

        local entities =
            player.surface.find_entities_filtered {
            force = player.force,
            area = radius
        }
        for i = 1, #entities do
            local e = entities[i]
            if e and e.valid then
                if e.health then
                    e.health = 10000
                end
                if e.type == 'entity-ghost' then
                    if not disallow[e.name] then
                        e.silent_revive()
                    else
                        Server.player_return(
                            'You have repaired: ' .. e.name .. ' this item is not allowed.',
                            Color.warning,
                            player
                        )
                    end
                end
            end
        end
        Server.to_admin_embed(
            table.concat {
                '[Info] ',
                player.name,
                ' ran command: ',
                args.name,
                ' ',
                args.parameter,
                ' at game.tick: ',
                game.tick,
                '.'
            }
        )
    end
)
