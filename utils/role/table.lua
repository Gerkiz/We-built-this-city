local Global = require "utils.global"

local Public = {
    _role = {},
    _group = {},
    config={
        role = {},
        group = {},
        meta = {},
        old = {},
        current = {},
        last_jail = nil
    },
    order = {},
    events = {
        on_role_change=script.generate_event_name()
    }
}   

Global.register(Public.config,function(tbl)
    Public.config = tbl
    for _,role in pairs(Public.config.role) do
        setmetatable(role,{__index=Public._role})
        local parent = Public.config.role[role.parent]
        if parent then
            setmetatable(role.actions, {__index=parent.actions})
        end
    end
end)

function Public.get_table()
    return Public.config
end

return Public
