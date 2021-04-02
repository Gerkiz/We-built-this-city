local Color = require 'utils.color_presets'
local Global = require 'utils.global'
local Event = require 'utils.event'
local Table = require 'utils.extended_table'
local Server = require 'utils.server'
local Session = require 'utils.datastore.session_data'
local Token = require 'utils.token'
local Task = require 'utils.task'

local session_data_set = 'sessions'
local insert = table.insert

local Roles = {
    config = {
        role = {},
        group = {},
        meta = {},
        old = {},
        players = {}
    },
    events = {
        on_role_change = Event.generate_event_name('on_role_change')
    }
}

Global.register(
    Roles.config,
    function(tbl)
        Roles.config = tbl
    end
)

-- @usage debugStr('something')
local function debugStr(string)
    if not _DEBUG then
        return
    end
    return log('RAW: ' .. serpent.block(string))
end

function Roles.allowed(self, action)
    local role = Roles.get_role(self)
    if not role then
        return false
    end
    return role.allow[action] or role.is_root or false
end

function Roles.disallowed(self, action)
    local role = Roles.get_role(self)
    if not role then
        return false
    end
    return not role.allow[action] or role.is_root or false
end

function Roles.get_players(self, online)
    local players = game.permissions.get_group(self.name).players
    local r = {}
    if online then
        for _, player in pairs(players) do
            if player.connected then
                insert(r, player)
            end
        end
    else
        r = players
    end
    return r
end

function Roles.edit(self, key, set_value, value)
    if game then
        log(serpent.block('Roles._prototype:edit tried to edit during game.'))
        return
    end

    debugStr('Edited role: ' .. self.name .. '/' .. key)
    if set_value then
        self[key] = value
        return
    end
    if key == 'disallow' then
        if value ~= {} then
            self.disallow = Table.merge(self.disallow, value)
        end
    elseif key == 'allow' then
        self.allow = Table.merge(self.allow, value)
    end
    Roles.config.role[self.power] = self
    return self
end

function Roles.print(self)
    return log(serpent.block(self))
end

function Roles.add_role(self, obj)
    if game then
        log(serpent.block('Roles._prototype:add_role tried to edit during game.'))
        return
    end

    if not Server.is_type(obj.name, 'string') or not Server.is_type(obj.short_hand, 'string') or not Server.is_type(obj.tag, 'string') or not Server.is_type(obj.colour, 'table') then
        return
    end

    debugStr('Created role: ' .. obj.name)
    obj.group = {name = obj.name}
    obj.allow = obj.allow or {}
    obj.disallow = obj.disallow or {}
    obj.power = obj.power and self.highest and self.highest.power + obj.power or obj.power or self.lowest and self.lowest.power + 1 or nil

    if obj.power then
        insert(Roles.config.role, obj.power, obj)
    else
        insert(Roles.config.role, obj)
    end

    Roles.set_highest_power()
    if not self.highest or obj.power < self.highest.power then
        self.highest = {name = obj.name, power = obj.power}
    end
    if not self.lowest or obj.power > self.lowest.power then
        self.lowest = {name = obj.name, power = obj.power}
    end
    return self
end

function Roles.create_group(obj)
    if game then
        log(serpent.block('Roles.create_group tried to edit during game.'))
        return
    end

    debugStr('Created Group: ' .. obj.name)

    if not Server.is_type(obj.name, 'string') then
        return
    end

    obj.index = #Roles.config.group + 1
    obj.allow = obj.allow or {}
    obj.disallow = obj.disallow or {}
    insert(Roles.config.group, obj)

    return obj
end

function Roles.get_all_roles(player)
    local _player = player or game.player or game.player.name
    if not _player then
        return
    end
    for power, role in pairs(Roles.config) do
        local output = power .. ') ' .. role.name
        output = output .. ' ' .. role.tag
        local admin = 'No'
        if role.is_root then
            admin = 'Root'
        elseif role.is_admin then
            admin = 'Yes'
        end
        output = output .. ' Admin: ' .. admin
        output = output .. ' Group: ' .. role.group.name
        output = output .. ' AFK: ' .. tostring(role.base_afk_time)
        _player.print(output, role.colour)
    end
end

function Roles.standard_roles(tbl)
    if game then
        log(serpent.block('Roles.standard_roles tried to edit during game.'))
        return
    end

    if tbl then
        local player_roles = Roles.config.players
        for k, new_role in pairs(tbl) do
            player_roles[k] = new_role
        end
    end
end

function Roles.get_group(name)
    for _, group in pairs(Roles.config.group) do
        if group.name == name then
            return group
        end
    end
end

function Roles.get_role(player)
    if not player then
        return false
    end
    local _roles = Roles.get_roles()
    local r
    if Server.is_type(player, 'table') then
        if player.index then
            if not player.permission_group then
                r = nil
            else
                r = game.players[player.index] and _roles[player.permission_group.name] or nil
            end
        else
            r = player.group and player or nil
        end
    else
        r =
            game.players[player] and _roles[game.players[player].permission_group.name] or Table.contains(_roles, player) and Table.contains(_roles, player) or
            Table.string_contains(player, 'server') and Roles.get_role(Roles.config.meta.root) or
            Table.string_contains(player, 'root') and Roles.get_role(Roles.config.meta.root) or
            nil
    end

    return r
end

function Roles.give_role(player, role, by_player, tick, raise_event)
    local print_colour = Color.warning
    local _tick = tick or game.tick
    local by_player_name = Server.is_type(by_player, 'string') and by_player or player.name or 'script'
    local this_role = Roles.get_role(role) or Roles.get_role(Roles.config.meta.default)
    local old_role = Roles.get_role(player) or Roles.get_role(Roles.config.meta.default)
    local message = 'roles.role-down'
    -- messaging
    if old_role.name == this_role.name then
        return
    end

    if this_role.power < old_role.power then
        message = 'roles.role-up'
        player.play_sound {path = 'utility/achievement_unlocked'}
    else
        player.play_sound {path = 'utility/game_lost'}
    end

    if player.online_time > 60 or by_player_name ~= 'server' then
        game.print({message, player.name, this_role.name, by_player_name}, print_colour)
    end

    if this_role.group.name ~= 'User' then
        player.print({'roles.role-given', this_role.name}, print_colour)
    end

    if player.tag ~= old_role.tag then
        player.print({'roles.tag-reset'}, print_colour)
    end

    -- role change
    player.permission_group = game.permissions.get_group(this_role.name)
    player.tag = this_role.tag

    if old_role.group.name ~= 'Jail' then
        Roles.config.old[player.index] = old_role.name
    end

    player.admin = this_role.is_admin or false
    player.spectator = this_role.is_spectator or false

    if raise_event then
        script.raise_event(
            Roles.events.on_role_change,
            {
                tick = _tick,
                player_index = player.index,
                by_player_name = by_player_name,
                new_role = this_role,
                old_role = old_role
            }
        )
    end
end

function Roles.revert(player, by_player)
    player = player or game.get_player(player)
    Roles.give_role(player, Roles.config.old[player.index], by_player)
end

function Roles.update_role(player, tick)
    local played_time = Session.get_session_table()
    local default = Roles.get_role(Roles.config.meta.default)
    local current_role = Roles.get_role(player) or {power = -1, group = {name = 'not jail'}}
    local _roles = {default}
    local online_time
    if type(player) == 'string' then
        player = game.players[player]
        if not player then
            return
        end
    end
    if played_time[player.name] then
        online_time = player.online_time + played_time[player.name]
    else
        online_time = player.online_time
    end
    if player.admin and not Roles.config.players[string.lower(player.name)] then
        Roles.config.players[string.lower(player.name)] = 'Moderator'
    end
    if current_role.group.name == 'Jail' then
        return
    end
    if Roles.config.players[string.lower(player.name)] then
        local role = Roles.get_role(Roles.config.players[string.lower(player.name)])
        insert(_roles, role)
    end

    if not Roles.config.meta.next_role_power then
        return
    end

    if current_role.power > Roles.config.meta.next_role_power and Server.tick_to_min(online_time) > Roles.config.meta.time_lowest then
        for _, role_name in pairs(Roles.config.meta.next_role_name) do
            local role = Roles.get_role(role_name)
            if Server.tick_to_min(online_time) > role.time then
                insert(_roles, role)
            end
        end
    end

    local _role = current_role
    for _, role in pairs(_roles) do
        if role.power < _role.power or _role.power == -1 then
            _role = role
        end
    end

    if _role then
        if _role.name == default.name then
            player.tag = _role.tag
            player.permission_group = game.permissions.get_group(_role.name)
        else
            Roles.give_role(player, _role, 'Script', tick, true)
        end
    end
end

function Roles.set_highest_power()
    if game then
        log(serpent.block('Roles.set_highest_power tried to edit during game.'))
        return
    end
    for power, role in pairs(Roles.config.role) do
        role.power = power
    end
end

function Roles.adjust_permission()
    if game then
        log(serpent.block('Roles.adjust_permission tried to edit during game.'))
        return
    end
    for power, role in pairs(Roles.config.role) do
        if Roles.config.role[power - 1] then
            Roles.edit(role, 'disallow', false, Roles.config.role[power - 1].disallow)
        end
    end
    for power = #Roles.config.role, 1, -1 do
        local role = Roles.config.role[power]
        Roles.edit(role, 'disallow', false, role.disallow)
        if Roles.config.role[power + 1] then
            Roles.edit(role, 'allow', false, Roles.config.role[power + 1].allow)
        end
    end
end

function Roles.get_groups()
    local r = {}
    for _, group in pairs(Roles.config.group) do
        r[group.name] = group
    end

    return r
end

function Roles.get_roles()
    local r = {}

    for _, role in pairs(Roles.config.role) do
        r[role.name] = role
    end

    return r
end

function Roles.fix_roles()
    if not Roles.config.meta.next_role_name then
        Roles.config.meta.next_role_name = {}
    end

    for power, role in pairs(Roles.config.role) do
        Roles.config.meta.role_count = power

        if role.is_default then
            Roles.config.meta.default = role.name
        end

        if role.is_root then
            Roles.config.meta.root = role.name
        end

        if role.time then
            insert(Roles.config.meta.next_role_name, role.name)
            if not Roles.config.meta.next_role_power or power < Roles.config.meta.next_role_power then
                Roles.config.meta.next_role_power = power
            end
            if not Roles.config.meta.time_lowest or role.time < Roles.config.meta.time_lowest then
                Roles.config.meta.time_lowest = role.time
            end
        end
    end
    return Roles.config.meta
end

local fetch_player =
    Token.register(
    function(data)
        local player = data.player
        Roles.update_role(player)
    end
)

Event.add(
    Roles.events.on_role_change,
    function(player_index)
        local data = {
            player = player_index
        }
        Task.set_timeout_in_ticks(5, fetch_player, data)
    end
)
Event.add(
    defines.events.on_player_joined_game,
    function(event)
        local player = game.players[event.player_index]
        Roles.update_role(player)
        Task.set_timeout_in_ticks(10, fetch_player, {player = player})
    end
)

Event.on_init(
    function()
        Roles.fix_roles()
        for _, role in pairs(Roles.config.role) do
            local perm = game.permissions.create_group(role.name)
            for _, remove in pairs(role.disallow) do
                if role ~= nil then
                    perm.set_allows_action(defines.input_action[remove], false)
                end
            end
        end
    end
)

Event.on_nth_tick(
    3600,
    function()
        local players = game.connected_players
        for i = 1, #players do
            local player = players[i]
            local data = {
                player = player
            }
            Task.set_timeout_in_ticks(5, fetch_player, data)
        end
    end
)

Server.on_data_set_changed(
    session_data_set,
    function(data)
        Roles.update_role(data.key)
    end
)

return Roles
