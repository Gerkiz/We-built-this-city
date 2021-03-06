-- dependencies
local Event = require 'utils.event'
local Global = require 'utils.global'
local table = require 'utils.table'
local remove = table.remove
local pairs = pairs
local next = next

local biter_utils_conf = {
    enabled = true,
    chunk_size = 3,
    corpse_threshold = 3
}

local max_corpse_age = 15 * 60 * 60
local kills_per_cleanup = 500

local this = {
    corpse_chunks = {},
    cleanup_count = {kills_per_cleanup}
}

Global.register(
    this,
    function(t)
        this = t
    end
)

-- cleans up the stored list of corpses and chunks
local function remove_outdated_corpses(now)
    -- loop each stored chunk
    for x, column in pairs(this.corpse_chunks) do
        for y, corpses in pairs(column) do
            local count = #corpses

            for i = count, 1, -1 do
                if corpses[i].tick < now then
                    remove(corpses, i)
                    count = count - 1
                end
            end

            if count == 0 then
                column[y] = nil
            end
        end

        if next(column) == nil then
            remove(this.corpse_chunks, x)
        end
    end
end

local function biter_died(event)
    local prot = event.prototype

    -- Only trigger on dead units
    if prot.type ~= 'unit' then
        return
    end

    local entity = event.corpses[1]
    -- Ensure there is actually a corpse
    if entity == nil then
        return
    end

    local tick = event.tick

    -- Chance to clean up old corpses and chunks
    local amount = this.cleanup_count[1] - 1
    if amount <= 0 then
        remove_outdated_corpses(tick)
        this.cleanup_count[1] = kills_per_cleanup
    else
        this.cleanup_count[1] = amount
    end

    --Calculate the chunk position
    local chunk_size = biter_utils_conf.chunk_size
    local pos = entity.position
    local x, y = pos.x, pos.y
    x = x - (x % chunk_size)
    y = y - (y % chunk_size)

    -- check global table has this position, add if not
    local corpse_chunks_column = this.corpse_chunks[x]
    if corpse_chunks_column == nil then
        corpse_chunks_column = {}
        this.corpse_chunks[x] = corpse_chunks_column
    end

    local corpses = corpse_chunks_column[y]
    if corpses == nil then
        corpses = {}
        corpse_chunks_column[y] = corpses
    end

    -- Add this entity
    local count = #corpses + 1
    corpses[count] = {
        entity = entity,
        tick = tick + max_corpse_age
    }

    -- Cleanup old corpse if above threshold
    if count > biter_utils_conf.corpse_threshold then
        local old_entity = remove(corpses, 1).entity

        if old_entity.valid then
            old_entity.destroy()
        end
    end
end

Event.add(defines.events.on_post_entity_died, biter_died)
