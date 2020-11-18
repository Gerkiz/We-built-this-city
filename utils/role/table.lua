local Global = require 'utils.global'
local Event = require 'utils.event'

local Public = {
    config = {
        role = {},
        group = {},
        meta = {},
        old = {},
        current = {}
    },
    events = {
        on_role_change = Event.generate_event_name('on_role_change')
    }
}

Global.register(
    Public.config,
    function(tbl)
        local Roles = package.loaded['utils.role.roles']
        Public.config = tbl
        local roles = Public.config.role
        for _, role in pairs(roles) do
            setmetatable(role, {__index = Roles})
        end
    end
)

function Public.getConfig()
    return Public.config
end

function Public.getConfigRole()
    return Public.config.role
end

function Public.getConfigMeta()
    return Public.config.meta
end

return Public
