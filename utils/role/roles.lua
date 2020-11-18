local Table = require 'utils.extended_table'
local Server = require 'utils.server'
local Public = require 'utils.role.table'

local Roles = {}
local insert = table.insert

-- @usage debugStr('something')
local function debugStr(string)
    if not _DEBUG then
        return
    end
    return log('RAW: ' .. serpent.block(string))
end

function Roles:allowed(action)
    return self.allow[action] or self.is_root or false
end

function Roles:disallowed(action)
    return not self.allow[action] or self.is_root or false
end

function Roles:get_players(online)
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

function Roles:edit(key, set_value, value)
    if game then
        return
    end
    local Config = Public.getConfig()
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
    Config.role[self.power] = self
end

function Roles:add_role(obj)
    if game then
        return
    end
    local this = Public.getConfig()
    if
        not Server.is_type(obj.name, 'string') or not Server.is_type(obj.short_hand, 'string') or not Server.is_type(obj.tag, 'string') or
            not Server.is_type(obj.colour, 'table')
     then
        return
    end
    debugStr('Created role: ' .. obj.name)
    setmetatable(obj, {__index = Roles})
    obj.group = self
    obj.allow = obj.allow or {}
    obj.disallow = obj.disallow or {}
    obj.power = obj.power and self.highest and self.highest.power + obj.power or obj.power or self.lowest and self.lowest.power + 1 or nil
    setmetatable(obj.allow, {__index = self.allow})
    setmetatable(obj.disallow, {__index = self.disallow})
    if obj.power then
        insert(this.role, obj.power, obj)
    else
        insert(this.role, obj)
    end
    Public.set_highest_power()
    if not self.highest or obj.power < self.highest.power then
        self.highest = obj
    end
    if not self.lowest or obj.power > self.lowest.power then
        self.lowest = obj
    end
end

return Roles
