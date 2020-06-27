local Event = require 'utils.event'
local Global = require 'utils.global'
local Color = require 'utils.color_presets'
local Token = require 'utils.token'
local Table = require 'utils.extended_table'
local Roles = require 'utils.role.table'
local Server = require 'utils.server'

local this = {
    print_to = {},
    queue = {},
    tick = {},
    timeout = {},
    events = {},
    all = {_n = 0},
    paused = {},
    named = {}
}

Global.register(
    {this = this},
    function(t)
        this = t.this
    end
)

local Public = {}
Public._thread = {}

local function is_type(v, test_type)
    return test_type and v and type(v) == test_type or not test_type and not v or false
end

function Public._thread:create(obj)
    local _obj = obj or {}
    setmetatable(_obj, {__index = Public._thread})
    _obj.uuid = Public.new_uuid()
    return _obj
end

function Public._thread:queue()
    self:open()
    return Public.queue_thread(self)
end

function Public._thread:valid(skip_location_check)
    local _skip_location_check = skip_location_check or false
    if
        is_type(self.uuid, 'string') and _skip_location_check or is_type(self.opened, 'number') and _skip_location_check or
            is_type(this.all[self.uuid], 'table') and is_type(self.timeout) or
            is_type(self.timeout, 'number') and is_type(self.name) or
            is_type(self.name, 'string') and is_type(self._close) or
            is_type(self._close, 'function') and is_type(self._timeout) or
            is_type(self._timeout, 'function') and is_type(self._tick) or
            is_type(self._tick, 'function') and is_type(self._resolve) or
            is_type(self._resolve, 'function') and is_type(self._success) or
            is_type(self._success, 'function') and is_type(self._error) or
            is_type(self._error, 'function')
     then
        return true
    end
    return false
end

function Public._thread:open()
    if not self:valid(true) or self.opened then
        return false
    end
    local threads = this
    local uuid = self.uuid
    self.opened = game.tick
    threads.all[uuid] = threads.all[uuid] or self
    threads.all._n = threads.all._n + 1
    if threads.paused[self.name] then
        threads.paused[self.name] = nil
    end
    if is_type(self.timeout, 'number') then
        table.insert(threads.timeout, uuid)
    end
    if is_type(self._tick, 'function') then
        table.insert(threads.tick, uuid)
    end
    if is_type(self.name, 'string') then
        threads.named[self.name] = threads.named[self.name] or self.uuid
    end
    if is_type(self._events, 'table') then
        Table.each(
            self._events,
            function(callback, event, threads, uuid)
                -- cant be used V
                --Public.add_thread_handler(event)
                if not threads.events[event] then
                    threads.events[event] = {}
                end
                table.insert(threads.events[event], uuid)
            end,
            threads,
            self.uuid
        )
    end
    return true
end

function Public._thread:close()
    local threads = this
    local uuid = self.uuid
    local _return = false
    if is_type(self._close, 'function') then
        pcall(self._close, self)
        _return = true
    end
    local value, key =
        Table.find(
        threads.queue,
        function(v, k, uuid)
            return v == uuid
        end,
        uuid
    )
    if key then
        threads.queue[key] = nil
    end
    local value, key =
        Table.find(
        threads.timeout,
        function(v, k, uuid)
            return v == uuid
        end,
        uuid
    )
    if key then
        threads.timeout[key] = nil
    end
    local value, key =
        Table.find(
        threads.tick,
        function(v, k, uuid)
            return v == uuid
        end,
        uuid
    )
    if key then
        threads.tick[key] = nil
    end
    if is_type(self._events, 'table') then
        Table.each(
            self._events,
            function(callback, event)
                if threads.events[event] then
                    local value, key =
                        Table.find(
                        threads.events[event],
                        function(v, k, uuid)
                            return v == uuid
                        end,
                        uuid
                    )
                    if key then
                        threads.events[event][key] = nil
                    end
                -- cant be used V
                --if #threads.events[event] == 0 then Event.remove(event,Public.game_event) threads.events[event] = nil end
                end
            end
        )
    end
    if is_type(self.name, 'string') then
        threads.paused[self.name] = self.uuid
        self.opened = nil
        if self.reopen == true then
            self:open()
        end
    else
        threads.all[uuid] = nil
        threads.all._n = threads.all._n - 1
    end
    return _return
end

function Public._thread:resolve(...)
    local _return = false
    if is_type(self._resolve, 'function') then
        local success, err = pcall(self._resolve, self, ...)
        if success then
            if is_type(self._success, 'function') then
                Public.interface(
                    function(thread, err)
                        local success, err = pcall(thread._success, thread, err)
                        if not success then
                            thread:error(err)
                        end
                    end,
                    true,
                    self,
                    err
                )
                _return = true
            end
        else
            _return = self:error(err)
        end
    end
    self:close()
    return _return
end

function Public._thread:check_timeout()
    local _return = false
    if not self:valid() then
        return false
    end
    if is_type(self.timeout, 'number') and game.tick >= (self.opened + self.timeout) then
        if is_type(self._timeout, 'function') then
            pcall(self._timeout, self)
        end
        _return = true
        self:close()
    end
    return _return
end

function Public._thread:error(err)
    local _return = false
    if is_type(self._error, 'function') then
        pcall(self._error, self, err)
        _return = true
    else
        error(err)
    end
    return _return
end

function Public._thread:on_event(event, callback)
    local events = {'close', 'timeout', 'tick', 'resolve', 'success', 'error'}
    local value =
        Table.find(
        events,
        function(v, k, find)
            return v == string.lower(find)
        end,
        event
    )
    if value and is_type(callback, 'function') then
        self['_' .. value] = callback
    elseif is_type(event, 'number') and is_type(callback, 'function') then
        if not self._events then
            self._events = {}
        end
        self._events[event] = callback
    end
    return self
end

function Public.new_uuid()
    return Token.uid()
end

function Public.threads(count)
    return count and this.all._n or this.all
end

function Public._threads(t)
    this =
        not t and this or
        {print_to = {}, queue = {}, tick = {}, timeout = {}, events = {}, all = {_n = 0}, paused = {}, named = {}}
    return this
end

function Public.new_thread(obj)
    return Public._thread:create(obj)
end

function Public.event_retrieve(mixed)
    local threads = this
    if threads.named[mixed] then
        return threads.all[threads.named[mixed]]
    elseif threads.paused[mixed] then
        return threads.all[threads.paused[mixed]]
    elseif threads.all[mixed] then
        return threads.all[mixed]
    else
        return false
    end
end

function Public.queue_thread(thread_to_queue)
    if not thread_to_queue and not thread_to_queue.valid and not thread_to_queue:valid() then
        return false
    end
    if not thread_to_queue._resolve then
        return false
    end
    table.insert(this.queue, thread_to_queue.uuid)
    return true
end

function Public.close_all_threads(with_force)
    if not with_force then
        for uuid, next_thread in pairs(Public.threads()) do
            if uuid ~= '_n' then
                next_thread:close()
            end
        end
    else
        Public._threads(true)
    end
end

function Public.run_tick_threads()
    Table.each(
        this.tick,
        function(uuid)
            local next_thread = Public.event_retrieve(uuid)
            if next_thread and next_thread:valid() and next_thread._tick then
                local success, err = pcall(next_thread._tick, next_thread)
                if not success then
                    next_thread:error(err)
                end
            end
        end
    )
end

function Public.check_timeouts()
    Table.each(
        this.timeout,
        function(uuid)
            local next_thread = Public.event_retrieve(uuid)
            if next_thread and next_thread:valid() then
                next_thread:check_timeout()
            end
        end
    )
end

function Public._thread_handler_debuger(player, event, state)
    --local player = game.get_player(player)
    local print_to = this.print_to
    print_to[player.index] = print_to[player.index] or {}
    print_to[player.index][event] = state
end

function Public._thread_handler(event)
    Table.each(
        this.print_to,
        function(print_to, player_index, event)
            if event.name == defines.events.on_tick then
                return true
            end
            if print_to[event.name] then
                player_index.print(event, Color.white, player_index)
            end
        end,
        event
    )
    local event_id = event.name
    local threads = this.events[event_id]
    if not threads then
        return
    end
    Table.each(
        threads,
        function(uuid)
            local next_thread = Public.event_retrieve(uuid)
            if next_thread and next_thread:valid() then
                if is_type(next_thread._events[event_id], 'function') then
                    local success, err = pcall(next_thread._events[event_id], next_thread, event)
                    if not success then
                        next_thread:error(err)
                    end
                end
            end
        end
    )
end

for _, event in pairs(defines.events) do
    Event.add(event, Public._thread_handler)
end

function Public.interface(callback, use_thread, ...)
    if use_thread then
        if use_thread == true then
            use_thread = Public.new_thread {data = {callback, ...}}
        end
        use_thread:on_event(
            'resolve',
            function(thread)
                if is_type(thread.data[1], 'function') then
                    local success, err = pcall(unpack(thread.data))
                    if not success then
                        error(err)
                    end
                    return err
                else
                    local clb = thread.data[1] == nil
                    local success, err = pcall(loadstring(clb), unpack(thread.data))
                    if not success then
                        error(err)
                    end
                    return err
                end
            end
        )
        use_thread:open()
        Public.queue_thread(use_thread)
    else
        if type(callback) == 'function' then
            local success, err = pcall(callback, ...)
            return success, err
        else
            local success, err = pcall(loadstring(callback), ...)
            return success, err
        end
    end
end

commands.add_command(
    'interface',
    'Runs the given input from the script',
    function(args)
        local player = game.player
        if player then
            if player ~= nil then
                local p = Server.player_return
                if not Roles.get_role(player):allowed('interface') then
                    p('[ERROR] Only admins are allowed to run this command!', Color.fail, player)
                    return
                end
            end
        end
        local callback = args.parameter
        if not callback then
            return
        end
        if not string.find(callback, '%s') and not string.find(callback, 'return') then
            callback = 'return ' .. callback
        end
        if player then
            callback =
                'local player, surface, force, entity = game.player, game.player.surface, game.player.force, game.player.selected;' ..
                callback
        end
        if string.find(callback, 'Roles') or string.find(callback, 'roles') then
            callback = 'local Roles = require "utils.role.main" Roles.get_role(game.player);' .. callback
        end
        local success, err = Public.interface(callback)
        if not success and type(err) == 'string' then
            local _end = string.find(err, 'stack traceback')
            if _end then
                err = string.sub(err, 0, _end - 2)
            end
        end
        if err or err == false then
            Server.player_return(err, Color.warning, player)
        end
    end
)

Event.add(
    defines.events.on_tick,
    function(event)
        if event.tick < 10 then
            return
        end
        local threads = this
        if #threads.tick > 0 then
            Public.run_tick_threads()
        end
        if #threads.timeout > 0 then
            Public.check_timeouts()
        end
        if #threads.queue > 0 then
            local current_thread = threads.all[threads.queue[1]]
            if current_thread and current_thread:valid() then
                current_thread:resolve()
            end
        end
    end
)

Event.on_init(
    function()
        local threads = Public.threads()
        for uuid, thread in pairs(threads) do
            if uuid ~= '_n' then
                setmetatable(thread, {__index = Public._thread})
            end
        end
    end
)

return Public
