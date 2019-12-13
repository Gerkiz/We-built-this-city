--local Session = require 'utils.session_data'
--local Modifiers = require 'utils.player_modifiers'
local Server = require 'utils.server'
local Color = require 'utils.color_presets'

-- these items are not repaired, true means it is blocked
local disallow = {
    ['loader']=true,
    ['fast-loader']=true,
    ['express-loader']=true,
    ['electric-energy-interface']=true,
    ['infinity-chest']=true
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
            local p = player.print
            if not player.admin then
                p("[ERROR] Only admins are allowed to run this command!", Color.fail)
                return
            end
        end
    end
    local range = tonumber(args.parameter)
    local max_range = const
    local center = player and player.position or {x=0,y=0}
    if not range or max_range and range > max_range then player.print("Invalid range.") return end
    for x = -range-2, range+2 do
        for y = -range-2, range+2 do
            if x^2+y^2 < range^2 then
                for key, entity in pairs(player.surface.find_entities_filtered({area={{x+center.x,y+center.y},{x+center.x+1,y+center.y+1}},type='entity-ghost'})) do
                    if not disallow[entity.name] then
                        entity.silent_revive()
                    else player.print('You have repaired: '..entity.name..' this item is not allowed.') end
                end
                for key, entity in pairs(player.surface.find_entities({{x+center.x,y+center.y},{x+center.x+1,y+center.y+1}})) do if entity.health then entity.health = 10000 end end
            end
        end
    end
    Server.to_admin_embed(table.concat{'[Info] ', player.name, ' ran command: ', args.name, " ", args.parameter, ' at game.tick: ', game.tick, '.'})
end)