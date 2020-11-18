local Server = require 'utils.server'
local Public = require 'utils.role.table'
local Roles = require 'utils.role.roles'

local PermissionGroups = {__index = Roles}
local insert = table.insert

-- @usage debugStr('something')
local function debugStr(string)
    if not _DEBUG then
        return
    end
    return log('RAW: ' .. serpent.block(string))
end

function PermissionGroups:create(obj)
    if game then
        return
    end
    local this = Public.getConfig()

    if not Server.is_type(obj.name, 'string') then
        return
    end
    debugStr('Created Group: ' .. obj.name)
    setmetatable(obj, {__index = Roles})
    self.name = obj.name
    self.index = #this.group + 1
    self.allow = obj.allow or {}
    self.disallow = obj.disallow or {}
    insert(Public.config.group, obj)
    return obj
end

return PermissionGroups
