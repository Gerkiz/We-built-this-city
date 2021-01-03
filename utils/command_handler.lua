local Color = require 'utils.color_presets'
local Roles = require 'utils.role.main'

local function interface(callback, ...)
    if type(callback) == 'function' then
        local success, err = pcall(callback, ...)
        return success, err
    else
        local success, err = pcall(load(callback), ...)
        return success, err
    end
end

commands.add_command(
    'interface',
    'Runs the given input from the script',
    function(args)
        local player = game.player
        if player then
            if player ~= nil then
                if not Roles.allowed(player, 'interface') then
                    player.print('[ERROR] Only admins are allowed to run this command!', Color.fail)
                    return
                end
            end
        end
        local callback = args.parameter
        if not callback then
            return
        end
        if not string.find(callback, '%s') and not string.find(callback, 'return') and not string.find(callback, 'return') then
            callback = 'return ' .. callback
        end
        if player and not string.find(callback, 'utils.event') then
            callback = 'local player, surface, force, entity = game.player, game.player.surface, game.player.force, game.player.selected;' .. callback
        end
        if string.find(callback, 'Roles') or string.find(callback, 'roles') and not string.find(callback, 'utils.event') then
            callback = 'local Roles = require "utils.role.main" Roles.get_role(game.player);' .. callback
        end

        if not string.find(callback, 'utils.event') then
            callback = 'local Event = require "utils.event";' .. callback
        end

        local success, err = interface(callback)
        if not success and type(err) == 'string' then
            local _end = string.find(err, 'stack traceback')
            if _end then
                err = string.sub(err, 0, _end - 2)
            end
        end
        if (err or err == false) then
            if type(err) == 'boolean' then
                if err then
                    player.print(err)
                end
            else
                err = err:gsub('..-/temp/currently%-playing..-%....', '')
                err = '[color=red][Interface-Error][/color] ' .. err
                pcall(player.print, err)
            end
        end
    end
)
