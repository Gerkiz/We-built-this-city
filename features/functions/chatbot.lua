local Event = require 'utils.event'
local Server = require 'utils.server'
local session = require 'utils.datastore.session_data'
local Color = require 'utils.color_presets'
local Timestamp = require 'utils.timestamp'
local format = string.format
local font = 'default-game'

local brain = {
    [1] = {'Our Discord server is at: discord.io/wbtc'},
    [2] = {
        'Need an admin? Type @Mods in game chat to notify moderators,',
        'or put a message in the discord help channel.'
    }
}

local links = {
    ['admin'] = brain[2],
    ['administrator'] = brain[2],
    ['discord'] = brain[1],
    ['greifer'] = brain[2],
    ['grief'] = brain[2],
    ['griefer'] = brain[2],
    ['griefing'] = brain[2],
    ['mod'] = brain[2],
    ['ban'] = brain[2],
    ['mods'] = brain[2],
    ['moderator'] = brain[2],
    ['stealing'] = brain[2],
    ['stole'] = brain[2],
    ['troll'] = brain[2],
    ['trolling'] = brain[2]
}

local function on_player_created(event)
    local player = game.players[event.player_index]
    local trusted = session.get_trusted_table()
    --player.print("[font=" .. font .. "]" .. "Join our sweet discord >> discord.io/wbtc" .. "[/font]", Color.success)
    if player.admin then
        trusted[player.name] = true
    end
end

local function process_bot_answers(event)
    local message = event.message
    message = string.lower(message)
    if links[message] then
        for _, bot_answer in pairs(links[message]) do
            game.print('[font=' .. font .. ']' .. bot_answer .. '[/font]', Color.info)
        end
        return
    end
end

local function on_console_chat(event)
    if not event.player_index then
        return
    end
    process_bot_answers(event)
end

--share vision of silent-commands with other admins
local function on_console_command(event)
    local cmd = event.command
    if not event.player_index then
        return
    end
    local player = game.players[event.player_index]
    local param = event.parameters

    if not player.admin then
        return
    end

    local server_time = Server.get_current_time()
    if server_time then
        server_time = format(' (Server time: %s)', Timestamp.to_string(server_time))
    else
        server_time = ' at tick: ' .. game.tick
    end

    if string.len(param) <= 0 then
        param = nil
    end

    local commands = {
        ['editor'] = true,
        ['interface'] = true,
        ['silent-command'] = true,
        ['sc'] = true,
        ['debug'] = true
    }

    if not commands[cmd] then
        return
    end

    if string.find(cmd, 'interface') then
        return
    end

    if player then
        if param then
            print(player.name .. ' ran: ' .. cmd .. ' "' .. param .. '" ' .. server_time)
            Server.to_admin_embed(table.concat {'[Info] ', player.name, ' ran: ', cmd, ' "', param, '" ', server_time, '.'})
        else
            print(player.name .. ' ran: ' .. cmd .. server_time)
            Server.to_admin_embed(table.concat {'[Info] ', player.name, ' ran: ', cmd, ' ', server_time, '.'})
        end
    else
        if param then
            print('ran: ' .. cmd .. ' "' .. param .. '" ' .. server_time)
            Server.to_admin_embed(table.concat {'[Info] ran: ', cmd, ' "', param, '" ', server_time, '.'})
        else
            print('ran: ' .. cmd .. server_time)
            Server.to_admin_embed(table.concat {'[Info] ran: ', cmd, ' ', server_time, '.'})
        end
    end
end

Event.add(defines.events.on_player_created, on_player_created)
Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_console_command, on_console_command)
