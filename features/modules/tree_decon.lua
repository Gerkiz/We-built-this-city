local Global = require 'utils.global'
local Roles = require 'utils.role.table'
local Event = require 'utils.event'

local this = {
    trees = {},
    clear = 0
}

Global.register(
    this,
    function(t)
        this = t
    end
)

Event.add(
    defines.events.on_tick,
    function()
        local trees = this.trees
        if this.clear ~= 0 and this.clear < game.tick then
            this.clear = 0
        end
        if #trees == 0 then
            return
        end
        for i = 0, math.ceil(#trees / 10) do
            local tree = table.remove(trees, 1)
            if tree and tree.valid then
                tree.destroy()
            end
        end
    end
)

Event.add(
    defines.events.on_marked_for_deconstruction,
    function(event)
        if not event.entity or not event.entity.valid then
            return
        end
        if not event.player_index then
            return
        end
        local player = game.players[event.player_index]
        if not player then
            return
        end
        local role = Roles.get_role(player)
        if not event.entity.last_user or event.entity.name == 'entity-ghost' then
            if role:allowed('tree-decon') then
                this.trees[#this.trees + 1] = event.entity
                this.clear = game.tick + 10
            end
        end
    end
)
