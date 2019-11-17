-- regrowth_map.lua
-- Sep 2019
-- REVERTED BACK TO SOFT MOD

-- Code tracks all chunks generated and allows for deleting of inactive chunks.
--
-- Basic rules of regrowth:
-- 1. Area around player is safe for quite a large distance.
-- 2. Chunks with pollution won't be deleted.
-- 3. Chunks with any player buildings won't be deleted.
-- 4. Anything within radar range won't be deleted, but radar MUST be active.
--      -- This works by refreshing all chunk timers within radar range using
--      the on_sector_scanned event.
-- 5. Chunks timeout after 1 hour-ish, configurable

local Utils = require("map_gen.mps_0_17.lib.oarc_utils")
local Config = require("map_gen.mps_0_17.config")
local global_data = require 'map_gen.mps_0_17.lib.table'.get_table()
local Global = require 'utils.global'

local regrowth = {
    surfaces_index = 1,
    player_refresh_index = 1,
    force_removal_flag = -1000,
    active_surfaces = {}
}


Global.register(
    {regrowth=regrowth},
    function(t)
        regrowth = t
    end
)
local Public = {}

function Public.TriggerCleanup()
    regrowth.force_removal_flag = game.tick
end

function Public.ForceRemoveChunksCmd(cmd_table)
    if (game.players[cmd_table.player_index].admin) then
        Public.TriggerCleanup()
    end
end

function Public.RegrowthAddSurface(s_index)

    if (regrowth[s_index] ~= nil) then
        log("ERROR - Tried to add surface that was already added?")
        return
    end

    log("Oarc Regrowth - ADD SURFACE " .. game.surfaces[s_index].name)

    regrowth[s_index] = {}
    table.insert(regrowth.active_surfaces, s_index)

    regrowth[s_index].map = {}
    regrowth[s_index].removal_list = {}
    regrowth[s_index].min_x = 0
    regrowth[s_index].max_x = 0
    regrowth[s_index].x_index = 0
    regrowth[s_index].min_y = 0
    regrowth[s_index].max_y = 0
    regrowth[s_index].y_index = 0

    -- MarkAreaSafeGivenTilePos({x=0,y=0}, 10)
end

-- Adds new chunks to the global table to track them.
-- This should always be called first in the chunk generate sequence
-- (Compared to other RSO & Oarc related functions...)
function Public.RegrowthChunkGenerate(event)

    local s_index = event.surface.index
    local c_pos = Utils.GetChunkPosFromTilePos(event.area.left_top)

    -- Surface must be "added" first.
    if (regrowth[s_index] == nil) then return end

    -- If this is the first chunk in that row:
    if (regrowth[s_index].map[c_pos.x] == nil) then
        regrowth[s_index].map[c_pos.x] = {}
    end

    -- Confirm the chunk doesn't already have a value set:
    if (regrowth[s_index].map[c_pos.x][c_pos.y] == nil) then
        regrowth[s_index].map[c_pos.x][c_pos.y] = game.tick
    end

    -- Store min/max values for x/y dimensions:
    if (c_pos.x < regrowth[s_index].min_x) then
        regrowth[s_index].min_x = c_pos.x
    end
    if (c_pos.x > regrowth[s_index].max_x) then
        regrowth[s_index].max_x = c_pos.x
    end
    if (c_pos.y < regrowth[s_index].min_y) then
        regrowth[s_index].min_y = c_pos.y
    end
    if (c_pos.y > regrowth[s_index].max_y) then
        regrowth[s_index].max_y = c_pos.y
    end
end

-- Mark an area for "immediate" forced removal
function Public.MarkAreaForRemoval(s_index, pos, chunk_radius)
    local c_pos = Utils.GetChunkPosFromTilePos(pos)
    for i=-chunk_radius,chunk_radius do
        for k=-chunk_radius,chunk_radius do
            local x = c_pos.x+i
            local y = c_pos.y+k

            if (regrowth[s_index].map[x] == nil) then
                regrowth[s_index].map[x] = {}
            end
            regrowth[s_index].map[x][y] = nil
            table.insert(regrowth[s_index].removal_list,
                            {pos={x=x,y=y},force=true})
        end
    end
end

-- Marks a chunk containing a position that won't ever be deleted.
function Public.MarkChunkSafe(s_index, c_pos)
    if (regrowth[s_index].map[c_pos.x] == nil) then
        regrowth[s_index].map[c_pos.x] = {}
    end
    regrowth[s_index].map[c_pos.x][c_pos.y] = -1
end

-- Marks a safe area around a TILE position that won't ever be deleted.
function Public.MarkAreaSafeGivenTilePos(s_index, pos, chunk_radius)
    if (regrowth[s_index] == nil) then return end

    local c_pos = Utils.GetChunkPosFromTilePos(pos)
    Public.MarkAreaSafeGivenChunkPos(s_index, c_pos, chunk_radius)
end

-- Marks a safe area around a CHUNK position that won't ever be deleted.
function Public.MarkAreaSafeGivenChunkPos(s_index, c_pos, chunk_radius)
    if (regrowth[s_index] == nil) then return end

    for i=-chunk_radius,chunk_radius do
        for j=-chunk_radius,chunk_radius do
            Public.MarkChunkSafe(s_index, {x=c_pos.x+i,y=c_pos.y+j})
        end
    end
end

-- Refreshes timers on a chunk containing position
function Public.RefreshChunkTimer(s_index, pos, bonus_time)
    local c_pos = Utils.GetChunkPosFromTilePos(pos)

    if (regrowth[s_index].map[c_pos.x] == nil) then
        regrowth[s_index].map[c_pos.x] = {}
    end
    if (regrowth[s_index].map[c_pos.x][c_pos.y] ~= -1) then
        regrowth[s_index].map[c_pos.x][c_pos.y] = game.tick + bonus_time
    end
end

-- Forcefully refreshes timers on a chunk containing position
-- Will overwrite -1 flag.
-- function Public.OarcRegrowthForceRefreshChunk(s_index, pos, bonus_time)
--     local c_pos = Utils.GetChunkPosFromTilePos(pos)

--     if (regrowth[s_index].map[c_pos.x] == nil) then
--         regrowth[s_index].map[c_pos.x] = {}
--     end
--     regrowth[s_index].map[c_pos.x][c_pos.y] = game.tick + bonus_time
-- end

 -- Refreshes timers on all chunks around a certain area
function Public.RefreshArea(s_index, pos, chunk_radius, bonus_time)
    local c_pos = Utils.GetChunkPosFromTilePos(pos)

    for i=-chunk_radius,chunk_radius do
        for k=-chunk_radius,chunk_radius do
            local x = c_pos.x+i
            local y = c_pos.y+k

            if (regrowth[s_index].map[x] == nil) then
                regrowth[s_index].map[x] = {}
            end
            if (regrowth[s_index].map[x][y] ~= -1) then
                regrowth[s_index].map[x][y] = game.tick + bonus_time
            end
        end
    end
end

-- Refreshes timers on all chunks near an ACTIVE radar
function Public.RegrowthSectorScan(event)
    local s_index = event.radar.surface.index
    if (regrowth[s_index] == nil) then return end

    Public.RefreshArea(s_index, event.radar.position, 14, 0)
    Public.RefreshChunkTimer(s_index, event.chunk_position, 0)
end

-- Refresh all chunks near a single player. Cyles through all connected players.
function Public.RefreshPlayerArea()
    regrowth.player_refresh_index = regrowth.player_refresh_index + 1
    if (regrowth.player_refresh_index > #game.connected_players) then
        regrowth.player_refresh_index = 1
    end
    if (game.connected_players[regrowth.player_refresh_index]) then
        local player = game.connected_players[regrowth.player_refresh_index]
        if (not player.character) then return end

        local s_index = player.character.surface.index
        if (regrowth[s_index] == nil) then return end

        Public.RefreshArea(s_index, player.position, 4, 0)
    end
end

-- Gets the next chunk the array map and checks to see if it has timed out.
-- Adds it to the removal list if it has.
function Public.RegrowthSingleStepArray(s_index)

    -- Increment X and reset when we hit the end.
    if (regrowth[s_index].x_index > regrowth[s_index].max_x) then
        regrowth[s_index].x_index = regrowth[s_index].min_x

        -- Increment Y and reset when we hit the end.
        if (regrowth[s_index].y_index > regrowth[s_index].max_y) then
            regrowth[s_index].y_index = regrowth[s_index].min_y
            -- log("Finished checking regrowth array. "..
            --         game.surfaces[s_index].name.." "..
            --         regrowth[s_index].min_x.." "..
            --         regrowth[s_index].max_x.." "..
            --         regrowth[s_index].min_y.." "..
            --         regrowth[s_index].max_y)
        else
            regrowth[s_index].y_index = regrowth[s_index].y_index + 1
        end
    else
        regrowth[s_index].x_index = regrowth[s_index].x_index + 1
    end

    local xidx = regrowth[s_index].x_index
    local yidx = regrowth[s_index].y_index

    if (not xidx or not yidx) then
        log("ERROR - xidx or yidx is nil?")
    end

    -- Check row exists, otherwise make one.
    if (regrowth[s_index].map[xidx] == nil) then
        regrowth[s_index].map[xidx] = {}
    end

    -- If the chunk has timed out, add it to the removal list
    local c_timer = regrowth[s_index].map[xidx][yidx]
    if ((c_timer ~= nil) and (c_timer ~= -1) and
        ((c_timer + global_data.ticks_per_hour) < game.tick)) then

        -- Check chunk actually exists
        if (game.surfaces[s_index].is_chunk_generated({x=xidx, y=yidx})) then
            table.insert(regrowth[s_index].removal_list, {pos={x=xidx,
                                                            y=yidx},
                                                            force=false})
            regrowth[s_index].map[xidx][yidx] = nil
        end
    end
end

-- Remove all chunks at same time to reduce impact to FPS/UPS
function Public.OarcRegrowthRemoveAllChunks()
    for _,s_index in pairs(regrowth.active_surfaces) do

        while (#regrowth[s_index].removal_list > 0) do
            local c_remove = table.remove(regrowth[s_index].removal_list)
            local c_pos = c_remove.pos
            local c_timer = regrowth[s_index].map[c_pos.x][c_pos.y]

            if (game.surfaces[s_index] == nil) then
                log("Error! game.surfaces[name] is nil")
                return
            end

            -- Confirm chunk is still expired
            if (c_timer == nil) then

                -- If it is FORCE removal, then remove it regardless of pollution.
                if (c_remove.force) then
                    game.surfaces[s_index].delete_chunk(c_pos)
                    regrowth[s_index].map[c_pos.x][c_pos.y] = nil

                -- If it is a normal timeout removal, don't do it if there is pollution in the chunk.
                elseif (game.surfaces[s_index].get_pollution({c_pos.x*32,c_pos.y*32}) > 0) then
                    regrowth[s_index].map[c_pos.x][c_pos.y] = game.tick

                -- Else delete the chunk
                else
                    game.surfaces[s_index].delete_chunk(c_pos)
                    regrowth[s_index].map[c_pos.x][c_pos.y] = nil
                end
            end
        end
    end
end

-- This is the main work function, it checks a single chunk in the list
-- per tick. It works according to the rules listed in the header of this
-- file.
function Public.RegrowthOnTick()

    if (#regrowth.active_surfaces == 0) then return end

    -- Every half a second, refresh all chunks near a single player
    -- Cyles through all players. Tick is offset by 2
    if ((game.tick % (30)) == 2) then
        Public.RefreshPlayerArea()
    end

    -- Iterate through the active surfaces.
    if (regrowth.surfaces_index > #regrowth.active_surfaces) then
        regrowth.surfaces_index = 1
    end
    local s_index = regrowth.active_surfaces[regrowth.surfaces_index]
    regrowth.surfaces_index = regrowth.surfaces_index+1

    if (s_index == nil) then
        log("ERROR - s_index = nil in OarcRegrowthOnTick?")
        return
    end

    -- Every tick, check a few points in the 2d array of one of the active surfaces
    -- According to /measured-command this shouldn't take more
    -- than 0.1ms on average
    for i=1,20 do
        Public.RegrowthSingleStepArray(s_index)
    end

    -- Allow enable/disable of auto cleanup, can change during runtime.
    if (global.enable_regrowth) then

        local interval_ticks = global_data.ticks_per_hour
        -- Send a broadcast warning before it happens.
        if ((game.tick % interval_ticks) == interval_ticks-601) then
            if (#regrowth[s_index].removal_list > 100) then
                Utils.SendBroadcastMsg("Map cleanup in 10 seconds... Unused and old map chunks will be deleted!")
            end
        end

        -- Delete all listed chunks across all active surfaces
        if ((game.tick % interval_ticks) == interval_ticks-1) then
            if (#regrowth[s_index].removal_list > 100) then
                Public.OarcRegrowthRemoveAllChunks()
                Utils.SendBroadcastMsg("Map cleanup done, sorry for your loss.")
            end
        end
    end
end

-- This function Public.removes any chunks flagged but on demand.
-- Controlled by the regrowth.force_removal_flag
-- This function Public.may be used outside of the normal regrowth modse.
function Public.RegrowthForceRemovalOnTick()
    -- Catch force remove flag
    if (game.tick == regrowth.force_removal_flag+60) then
        Utils.SendBroadcastMsg("Map cleanup (forced) in 10 seconds... Unused and old map chunks will be deleted!")
    end

    if (game.tick == regrowth.force_removal_flag+660) then
        Public.OarcRegrowthRemoveAllChunks()
        Utils.SendBroadcastMsg("Map cleanup done, sorry for your loss.")
    end
end

-- Broadcast messages to all connected players
function Public.SendBroadcastMsg(msg)
    local color = { r=0, g=255, b=171}
    for _,player in pairs(game.connected_players) do
        player.print(msg, color)
    end
end

-- Gets chunk position of a tile.
function Public.GetChunkPosFromTilePos(tile_pos)
    return {x=math.floor(tile_pos.x/32), y=math.floor(tile_pos.y/32)}
end

return Public