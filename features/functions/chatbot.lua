local Event = require 'utils.event'
local Server = require 'utils.server'
local session = require 'utils.datastore.session_data'
local Color = require 'utils.color_presets'
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
    if not (cmd == 'silent-command' or cmd == 'sc') then
        return
    end
    if not event.player_index then
        return
    end
    local player = game.players[event.player_index]
    Server.to_admin_embed(
        table.concat {'[Info] ', player.name, ' ran command: ', event.parameters, ' at game.tick: ', game.tick, '.'}
    )
end

Event.add(defines.events.on_player_created, on_player_created)
--Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_console_command, on_console_command)
