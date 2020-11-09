local Color = require 'utils.color_presets'
local Event = require 'utils.event'
local Table = require 'utils.extended_table'
local Public = require 'utils.role.table'
local Server = require 'utils.server'
local Session = require 'utils.datastore.session_data'
local Token = require 'utils.token'
local Task = require 'utils.task'

local session_data_set = 'sessions'

-- @usage _log('something')
local function _log(string)
    if not _DEBUG then
        return
    end
    return log('RAW: ' .. serpent.block(string))
end

function Public.output_roles(player)
    local this = Public.config
    local _player = player or game.player or game.player.name
    if not _player then
        return
    end
    for power, role in pairs(this.role) do
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
        Server.player_return(output, role.colour, _player)
    end
end

function Public.get()
    return {}
end

function Public.standard_roles(table)
    Public.config.current = table
end

function Public.get_role(player)
    local this = Public.config
    if not player then
        return false
    end
    local _roles = Public.add_roles()
    local _return
    if Server.is_type(player, 'table') then
        if player.index then
            _return = game.players[player.index] and _roles[player.permission_group.name] or nil
        else
            _return = player.group and player or nil
        end
    else
        _return =
            game.players[player] and _roles[game.players[player].permission_group.name] or
            Table.autokey(_roles, player) and Table.autokey(_roles, player) or
            Table.string_contains(player, 'server') and Public.get_role(this.meta.root) or
            Table.string_contains(player, 'root') and Public.get_role(this.meta.root) or
            nil
    end
    return _return
end

function Public.get_group(mixed)
    if not mixed then
        return false
    end
    local _groups = Public.add_groups()
    local role = Public.get_role(mixed)
    return role and role.group or Server.is_type(mixed, 'table') and mixed.roles and mixed or
        Server.is_type(mixed, 'string') and Table.autokey(_groups, mixed) and Table.autokey(_groups, mixed) or
        false
end

function Public.give_role(player, role, by_player, tick, raise_event)
    local this = Public.config
    local print_colour = Color.warning
    local _tick = tick or game.tick
    local by_player_name = Server.is_type(by_player, 'string') and by_player or player.name or 'script'
    local this_role = Public.get_role(role) or Public.get_role(this.meta.default)
    local old_role = Public.get_role(player) or Public.get_role(this.meta.default)
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
        Server.player_return({'roles.role-given', this_role.name}, print_colour, player)
    end
    if player.tag ~= old_role.tag then
        Server.player_return({'roles.tag-reset'}, print_colour, player)
    end
    -- role change
    player.permission_group = game.permissions.get_group(this_role.name)
    player.tag = this_role.tag
    if old_role.group.name ~= 'Jail' then
        this.old[player.index] = old_role.name
    end
    player.admin = this_role.is_admin or false
    player.spectator = this_role.is_spectator or false
    if raise_event == nil then
        if Public.events.on_role_change then
            script.raise_event(
                Public.events.on_role_change,
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
end

function Public.revert(player, by_player)
    local this = Public.config
    local _player = game.get_player(player)
    Public.give_role(_player, this.old[_player.index], by_player)
end

function Public.update_role(player, tick)
    local this = Public.config
    local default_roles = this.current
    local meta_data = this.meta
    local played_time = Session.get_session_table()
    local default = Public.get_role(meta_data.default)
    local current_role = Public.get_role(player) or {power = -1, group = {name = 'not jail'}}
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
    if player.admin and not default_roles[string.lower(player.name)] then
        default_roles[string.lower(player.name)] = 'Moderator'
    end
    if current_role.group.name == 'Jail' then
        return
    end
    if default_roles[string.lower(player.name)] then
        local role = Public.get_role(default_roles[string.lower(player.name)])
        table.insert(_roles, role)
    end
    if not meta_data.next_role_power then
        return
    end
    if current_role.power > meta_data.next_role_power and Server.tick_to_min(online_time) > meta_data.time_lowest then
        for _, role_name in pairs(meta_data.next_role_name) do
            local role = Public.get_role(role_name)
            if Server.tick_to_min(online_time) > role.time then
                table.insert(_roles, role)
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
            Public.give_role(player, _role, 'Script', tick, false)
        end
    end
end

function Public._set_role_power()
    for power, role in pairs(Public.config.role) do
        role.power = power
    end
end

function Public.adjust_permission()
    for power, role in pairs(Public.config.role) do
        if Public.config.role[power - 1] then
            role:edit('disallow', false, Public.config.role[power - 1].disallow)
        end
    end
    for power = #Public.config.role, 1, -1 do
        local role = Public.config.role[power]
        role:edit('disallow', false, role.group.disallow)
        if Public.config.role[power + 1] then
            role:edit('allow', false, Public.config.role[power + 1].allow)
        end
    end
end

function Public.add_groups()
    local _return = {}
    for _, group in pairs(Public.config.group) do
        _return[group.name] = group
    end
    return _return
end

function Public.add_roles()
    local _return = {}
    for _, role in pairs(Public.config.role) do
        _return[role.name] = role
    end
    return _return
end

function Public._metadata()
    local meta = Public.config.meta
    if not meta.next_role_name then
        meta.next_role_name = {}
    end
    for power, role in pairs(Public.config.role) do
        meta.role_count = power
        if role.is_default then
            meta.default = role.name
        end
        if role.is_root then
            meta.root = role.name
        end
        if role.time then
            table.insert(meta.next_role_name, role.name)
            if not meta.next_role_power or power < meta.next_role_power then
                meta.next_role_power = power
            end
            if not meta.time_lowest or role.time < meta.time_lowest then
                meta.time_lowest = role.time
            end
        end
    end
    return meta
end

function Public._role:allowed(action)
    return self.allow[action] or self.is_root or false
end

function Public._role:disallowed(action)
    return not self.allow[action] or false
end

function Public._role:get_players(online)
    local players = game.permissions.get_group(self.name).players
    local _return = {}
    if online then
        for _, player in pairs(players) do
            if player.connected then
                table.insert(_return, player)
            end
        end
    else
        _return = players
    end
    return _return
end

function Public._role:edit(key, set_value, value)
    if game then
        return
    end
    _log('Edited role: ' .. self.name .. '/' .. key)
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
    Public.config.role[self.power] = self
end

function Public._group:create(obj)
    local this = Public.config
    if game then
        return
    end
    if not Server.is_type(obj.name, 'string') then
        return
    end
    _log('Created Group: ' .. obj.name)
    setmetatable(obj, {__index = Public._group})
    self.index = #this.group + 1
    obj.roles = {}
    obj.allow = obj.allow or {}
    obj.disallow = obj.disallow or {}
    table.insert(Public.config.group, obj)
    return obj
end

function Public._group:add_role(obj)
    if game then
        return
    end
    if
        not Server.is_type(obj.name, 'string') or not Server.is_type(obj.short_hand, 'string') or not Server.is_type(obj.tag, 'string') or
            not Server.is_type(obj.colour, 'table')
     then
        return
    end
    _log('Created role: ' .. obj.name)
    setmetatable(obj, {__index = Public._role})
    obj.group = self
    obj.allow = obj.allow or {}
    obj.disallow = obj.disallow or {}
    obj.power = obj.power and self.highest and self.highest.power + obj.power or obj.power or self.lowest and self.lowest.power + 1 or nil
    setmetatable(obj.allow, {__index = self.allow})
    setmetatable(obj.disallow, {__index = self.disallow})
    if obj.power then
        table.insert(Public.config.role, obj.power, obj)
    else
        table.insert(Public.config.role, obj)
    end
    Public._set_role_power()
    if not self.highest or obj.power < self.highest.power then
        self.highest = obj
    end
    if not self.lowest or obj.power > self.lowest.power then
        self.lowest = obj
    end
end

function Public._group:edit(key, set_value, value)
    if game then
        return
    end
    _log('Edited Group: ' .. self.name .. '/' .. key)
    if set_value then
        self[key] = value
        return
    end
    if key == 'disallow' then
        self.disallow = Table.merge(self.disallow, value, true)
    elseif key == 'allow' then
        self.allow = Table.merge(self.allow, value)
    end
    Public.config.group[self.index] = self
end

local fetch_player =
    Token.register(
    function(data)
        local player = data.player
        Public.update_role(player)
    end
)

Server.on_data_set_changed(
    session_data_set,
    function(data)
        Public.update_role(data.key)
    end
)

Event.add(
    Public.events.on_role_change,
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
        Public.update_role(player)
        local data = {
            player = player
        }
        Task.set_timeout_in_ticks(10, fetch_player, data)
    end
)

Event.on_init(
    function()
        Public._metadata()
        local this = Public.config
        for _, role in pairs(this.role) do
            local perm = game.permissions.create_group(role.name)
            for _, toRemove in pairs(role.disallow) do
                if role ~= nil then
                    perm.set_allows_action(defines.input_action[toRemove], false)
                end
            end
        end
    end
)

Event.add(
    defines.events.on_tick,
    function(event)
        if (((event.tick + 10) / (3600)) + (15 / 2)) % 15 == 0 then
            for _, player in pairs(game.connected_players) do
                local data = {
                    player = player
                }
                Task.set_timeout_in_ticks(5, fetch_player, data)
            end
        end
    end
)

return Public
