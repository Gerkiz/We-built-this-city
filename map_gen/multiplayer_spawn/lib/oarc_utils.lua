-- oarc_utils.lua
-- Nov 2016
--
-- My general purpose utility functions for factorio
-- Also contains some constants and gui styles
local Surface = require 'utils.surface'
local MPS = require 'map_gen.multiplayer_spawn.lib.table'
local Gui = require 'map_gen.multiplayer_spawn.lib.oarc_gui_utils'
local Alert = require 'utils.alert'
local table_insert = table.insert
local table_remove = table.remove
local math_random = math.random
local math_floor = math.floor
local format = string.format
local abs = math.abs

local Public = {}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- General Helper Functions
--------------------------------------------------------------------------------

-- Prints flying text.
-- Color is optional
function Public.FlyingText(msg, pos, color, surface)
    if color == nil then
        surface.create_entity({name = 'flying-text', position = pos, text = msg})
    else
        surface.create_entity({name = 'flying-text', position = pos, text = msg, color = color})
    end
end

-- Requires having an on_tick handler.
function Public.DisplaySpeechBubble(player, text, timeout_secs)
    local global_data = MPS.get()

    if (global.oarc_speech_bubbles == nil) then
        global.oarc_speech_bubbles = {}
    end

    if (player and player.character) then
        local sp =
            player.surface.create_entity {
            name = 'compi-speech-bubble',
            position = player.position,
            text = text,
            source = player.character
        }
        table_insert(
            global.oarc_speech_bubbles,
            {
                entity = sp,
                timeout_tick = game.tick + (timeout_secs * global_data.ticks_per_second)
            }
        )
    end
end

-- Every second, check a global table to see if we have any speech bubbles to kill.
function Public.TimeoutSpeechBubblesOnTick()
    local global_data = MPS.get()
    if ((game.tick % (global_data.ticks_per_second)) == 3) then
        if (global.oarc_speech_bubbles and (#global.oarc_speech_bubbles > 0)) then
            for k, sp in pairs(global.oarc_speech_bubbles) do
                if (game.tick > sp.timeout_tick) then
                    if (sp.entity ~= nil) and (sp.entity.valid) then
                        sp.entity.start_fading_out()
                    end
                    table_remove(global.oarc_speech_bubbles, k)
                end
            end
        end
    end
end

-- Broadcast messages to all connected players
function Public.SendBroadcastMsg(msg)
    local color = {r = 0, g = 255, b = 171}
    for _, player in pairs(game.connected_players) do
        Alert.alert_player(player, 10, msg, color)
    end
end

-- Send a message to a player, safely checks if they exist and are online.
function Public.SendMsg(playerName, msg)
    if ((game.players[playerName] ~= nil) and (game.players[playerName].connected)) then
        game.players[playerName].print(msg)
    end
end

-- Useful for displaying game time in mins:secs format
function Public.formattime(ticks)
    local secs = ticks / 60
    local minutes = math_floor((secs) / 60)
    local seconds = math_floor(secs - 60 * minutes)
    return format('%dm:%02ds', minutes, seconds)
end

-- Useful for displaying game time in mins:secs format
function Public.formattime_hours_mins(ticks)
    local seconds = ticks / 60
    local minutes = math_floor((seconds) / 60)
    local hours = math_floor((minutes) / 60)
    local min = math_floor(minutes - 60 * hours)
    return format('%dh:%02dm', hours, minutes, min)
end

-- Simple function Public.to get total number of items in table
function Public.TableLength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

function Public.shuffle(tbl)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = math_random(size)
        tbl[i], tbl[rand] = tbl[rand], tbl[i]
    end
    return tbl
end

-- Get a random KEY from a table.
function Public.GetRandomKeyFromTable(t)
    local keyset = {}
    for k, _ in pairs(t) do
        table.insert(keyset, k)
    end
    return keyset[math.random(#keyset)]
end

function Public.GetRandomValueFromTable(t)
    return t[Public.GetRandomKeyFromTable(t)]
end

-- Simple function Public.to get distance between two positions.
function Public.getDistance(posA, posB)
    -- Get the length for each of the components x and y
    local xDist = posB.x - posA.x
    local yDist = posB.y - posA.y

    return math.sqrt((xDist ^ 2) + (yDist ^ 2))
end

-- Given a table of positions, returns key for closest to given pos.
function Public.GetClosestPosFromTable(pos, pos_table)
    local closest_dist
    local closest_key

    for k, p in pairs(pos_table) do
        local new_dist = Public.getDistance(pos, p)
        if (closest_dist == nil) then
            closest_dist = new_dist
            closest_key = k
        elseif (closest_dist > new_dist) then
            closest_dist = new_dist
            closest_key = k
        end
    end
end

-- Chart area for a force
function Public.ChartArea(force, position, chunkDist, surface)
    local global_data = MPS.get()
    force.chart(
        surface,
        {
            {
                position.x - (global_data.chunk_size * chunkDist),
                position.y - (global_data.chunk_size * chunkDist)
            },
            {
                position.x + (global_data.chunk_size * chunkDist),
                position.y + (global_data.chunk_size * chunkDist)
            }
        }
    )
end

-- Give player these default items.
function Public.GivePlayerItems(player)
    for _, item in pairs(global.player_respawn_start_items) do
        player.insert(item)
    end
end

-- Starter only items
function Public.GivePlayerStarterItems(player)
    for _, item in pairs(global.player_spawn_start_items) do
        player.insert(item)
    end

    if global.enable_power_armor then
        Public.GiveQuickStartPowerArmor(player)
    end
end

-- Cheater's quick start
function Public.GiveQuickStartPowerArmor(player)
    player.insert {name = 'modular-armor', count = 1}

    if
        player and player.get_inventory(defines.inventory.character_armor) ~= nil and
            player.get_inventory(defines.inventory.character_armor)[1] ~= nil
     then
        local p_armor = player.get_inventory(defines.inventory.character_armor)[1].grid
        if p_armor ~= nil then
            p_armor.put({name = 'battery-equipment'})
            p_armor.put({name = 'personal-roboport-equipment'})
            p_armor.put({name = 'battery-equipment'})
            p_armor.put({name = 'solar-panel-equipment'})
            p_armor.put({name = 'solar-panel-equipment'})
            p_armor.put({name = 'solar-panel-equipment'})
            p_armor.put({name = 'solar-panel-equipment'})
            p_armor.put({name = 'solar-panel-equipment'})
            p_armor.put({name = 'solar-panel-equipment'})
            p_armor.put({name = 'solar-panel-equipment'})
        end
        player.insert {name = 'construction-robot', count = 25}
    end
end

-- Create area given point and radius-distance
function Public.GetAreaFromPointAndDistance(point, dist)
    local area = {
        left_top = {
            x = point.x - dist,
            y = point.y - dist
        },
        right_bottom = {
            x = point.x + dist,
            y = point.y + dist
        }
    }
    return area
end

-- Check if given position is in area bounding box
function Public.CheckIfInArea(point, area)
    if ((point.x >= area.left_top.x) and (point.x < area.right_bottom.x)) then
        if ((point.y >= area.left_top.y) and (point.y < area.right_bottom.y)) then
            return true
        end
    end
    return false
end

-- Set all forces to ceasefire
function Public.SetCeaseFireBetweenAllForces()
    for name, team in pairs(game.forces) do
        if name ~= 'neutral' and name ~= 'enemy' then
            for x, _ in pairs(game.forces) do
                if x ~= 'neutral' and x ~= 'enemy' then
                    team.set_cease_fire(x, true)
                end
            end
        end
    end
end

-- Set all forces to friendly
function Public.SetFriendlyBetweenAllForces()
    for name, team in pairs(game.forces) do
        if name ~= 'neutral' and name ~= 'enemy' then
            for x, _ in pairs(game.forces) do
                if x ~= 'neutral' and x ~= 'enemy' then
                    team.set_friend(x, true)
                end
            end
        end
    end
end

-- For each other player force, share a chat msg.
function Public.ShareChatBetweenForces(player, msg)
    for _, force in pairs(game.forces) do
        if (force ~= nil) then
            if ((force.name ~= 'enemy') and (force.name ~= 'neutral') and (force.name ~= player) and (force ~= player.force)) then
                force.print(player.name .. ': ' .. msg)
            end
        end
    end
end

-- Merges force2 INTO force1 but keeps all research between both forces.
function Public.MergeForcesKeepResearch(force1, force2)
    for techName, luaTech in pairs(force2.technologies) do
        if (luaTech.researched) then
            force1.technologies[techName].researched = true
            force1.technologies[techName].level = luaTech.level
        end
    end
    game.merge_forces(force2, force1)
end

-- Undecorator
function Public.RemoveDecorationsArea(surface, area)
    surface.destroy_decoratives {area = area}
end

-- Remove fish
function Public.RemoveFish(surface, area)
    for _, entity in pairs(surface.find_entities_filtered {area = area, type = 'fish'}) do
        entity.destroy()
    end
end

-- Render a path
function Public.RenderPath(path, ttl, players)
    local surface_name = Surface.get_surface_name()
    local last_pos = path[1].position
    local color

    for i, v in pairs(path) do
        if (i ~= 1) then
            color = {r = 1 / (1 + (i % 3)), g = 1 / (1 + (i % 5)), b = 1 / (1 + (i % 7)), a = 0.5}
            rendering.draw_line {
                color = color,
                width = 2,
                from = v.position,
                to = last_pos,
                surface = game.surfaces[surface_name],
                players = players,
                time_to_live = ttl
            }
        end
        last_pos = v.position
    end
end

-- Get a random 1 or -1
function Public.RandomNegPos()
    if (math_random(0, 1) == 1) then
        return 1
    else
        return -1
    end
end

-- Create a random direction vector to look in
function Public.GetRandomVector()
    local randVec = {x = 0, y = 0}
    while ((randVec.x == 0) and (randVec.y == 0)) do
        randVec.x = math_random(-3, 3)
        randVec.y = math_random(-3, 3)
    end
    log('direction: x=' .. randVec.x .. ', y=' .. randVec.y)
    return randVec
end

-- Check for ungenerated chunks around a specific chunk
-- +/- chunkDist in x and y directions
function Public.IsChunkAreaUngenerated(chunkPos, chunkDist, surface)
    for x = -chunkDist, chunkDist do
        for y = -chunkDist, chunkDist do
            local checkPos = {
                x = chunkPos.x + x,
                y = chunkPos.y + y
            }
            if (surface.is_chunk_generated(checkPos)) then
                return false
            end
        end
    end
    return true
end

-- Clear out enemies around an area with a certain distance
function Public.ClearNearbyEnemies(pos, safeDist, surface)
    local safeArea = {
        left_top = {
            x = pos.x - safeDist,
            y = pos.y - safeDist
        },
        right_bottom = {
            x = pos.x + safeDist,
            y = pos.y + safeDist
        }
    }

    for _, entity in pairs(surface.find_entities_filtered {area = safeArea, force = 'enemy'}) do
        entity.destroy()
    end
end

-- function Public.to find coordinates of ungenerated map area in a given direction
-- starting from the center of the map
function Public.FindMapEdge(directionVec, surface)
    local global_data = MPS.get()
    local position = {x = 0, y = 0}
    local chunkPos = {x = 0, y = 0}

    -- Keep checking chunks in the direction of the vector
    while (true) do
        -- Set some absolute limits.
        if ((abs(chunkPos.x) > 1000) or (abs(chunkPos.y) > 1000)) then
            -- If chunk is already generated, keep looking
            break
        elseif (surface.is_chunk_generated(chunkPos)) then
            -- Found a possible ungenerated area
            chunkPos.x = chunkPos.x + directionVec.x
            chunkPos.y = chunkPos.y + directionVec.y
        else
            chunkPos.x = chunkPos.x + directionVec.x
            chunkPos.y = chunkPos.y + directionVec.y

            -- Check there are no generated chunks in a 10x10 area.
            if Public.IsChunkAreaUngenerated(chunkPos, 10, surface) then
                position.x = (chunkPos.x * global_data.chunk_size) + (global_data.chunk_size / 2)
                position.y = (chunkPos.y * global_data.chunk_size) + (global_data.chunk_size / 2)
                break
            end
        end
    end

    -- log("spawn: x=" .. position.x .. ", y=" .. position.y)
    return position
end

-- Find random coordinates within a given distance away
-- maxTries is the recursion limit basically.
function Public.FindUngeneratedCoordinates(minDistChunks, maxDistChunks, surface)
    local global_data = MPS.get()
    local position = {x = 0, y = 0}
    local chunkPos = {x = 0, y = 0}

    local maxTries = 100
    local tryCounter = 0

    local minDistSqr = minDistChunks ^ 2
    local maxDistSqr = maxDistChunks ^ 2

    while (true) do
        chunkPos.x = math_random(0, maxDistChunks) * Public.RandomNegPos()
        chunkPos.y = math_random(0, maxDistChunks) * Public.RandomNegPos()

        local distSqrd = chunkPos.x ^ 2 + chunkPos.y ^ 2

        -- Enforce a max number of tries
        tryCounter = tryCounter + 1
        if (tryCounter > maxTries) then
            -- Check that the distance is within the min,max specified
            log('FindUngeneratedCoordinates - Max Tries Hit!')
            break
        elseif ((distSqrd < minDistSqr) or (distSqrd > maxDistSqr)) then
            -- Keep searching!
            -- Check there are no generated chunks in a 10x10 area.
        elseif Public.IsChunkAreaUngenerated(chunkPos, global.check_spawn_ungenerated_chunk_radius, surface) then
            position.x = (chunkPos.x * global_data.chunk_size) + (global_data.chunk_size / 2)
            position.y = (chunkPos.y * global_data.chunk_size) + (global_data.chunk_size / 2)
            break -- SUCCESS
        end
    end

    log('spawn: x=' .. position.x .. ', y=' .. position.y)
    return position
end

-- General purpose function Public.for removing a particular recipe
function Public.RemoveRecipe(force, recipeName)
    local recipes = force.recipes
    if recipes[recipeName] then
        recipes[recipeName].enabled = false
    end
end

-- General purpose function Public.for adding a particular recipe
function Public.AddRecipe(force, recipeName)
    local recipes = force.recipes
    if recipes[recipeName] then
        recipes[recipeName].enabled = true
    end
end

-- General command for disabling a tech.
function Public.DisableTech(force, techName)
    if force.technologies[techName] then
        force.technologies[techName].enabled = false
        force.technologies[techName].visible_when_disabled = true
    end
end

-- General command for enabling a tech.
function Public.EnableTech(force, techName)
    if force.technologies[techName] then
        force.technologies[techName].enabled = true
    end
end

-- Get an area given a position and distance.
-- Square length = 2x distance
function Public.GetAreaAroundPos(pos, dist)
    return {
        left_top = {
            x = pos.x - dist,
            y = pos.y - dist
        },
        right_bottom = {
            x = pos.x + dist,
            y = pos.y + dist
        }
    }
end

-- Gets chunk position of a tile.
function Public.GetChunkPosFromTilePos(tile_pos)
    return {x = math_floor(tile_pos.x / 32), y = math_floor(tile_pos.y / 32)}
end

function Public.GetCenterTilePosFromChunkPos(c_pos)
    return {x = c_pos.x * 32 + 16, y = c_pos.y * 32 + 16}
end

-- Get the left_top
function Public.GetChunkTopLeft(pos)
    return {x = pos.x - (pos.x % 32), y = pos.y - (pos.y % 32)}
end

-- Get area given chunk
function Public.GetAreaFromChunkPos(chunk_pos)
    return {
        left_top = {x = chunk_pos.x * 32, y = chunk_pos.y * 32},
        right_bottom = {x = chunk_pos.x * 32 + 31, y = chunk_pos.y * 32 + 31}
    }
end

-- Removes the entity type from the area given
function Public.RemoveInArea(surface, area, type)
    for key, entity in pairs(surface.find_entities_filtered {area = area, type = type}) do
        if entity.valid and entity and entity.position then
            entity.destroy()
        end
    end
end

-- Removes the entity type from the area given
-- Only if it is within given distance from given position.
function Public.RemoveInCircle(surface, area, type, pos, dist)
    for key, entity in pairs(surface.find_entities_filtered {area = area, type = type}) do
        if entity.valid and entity and entity.position and entity.name ~= 'character' then
            if ((pos.x - entity.position.x) ^ 2 + (pos.y - entity.position.y) ^ 2 < dist ^ 2) then
                entity.destroy()
            end
        end
    end
end

-- Create another surface so that we can modify map settings and not have a screwy nauvis map.
function Public.CreateGameSurface()
    -- Get starting surface settings.
    local nauvis_settings = game.surfaces['nauvis'].map_gen_settings

    if global.enable_vanilla_spawns then
        Surface.set_island(true)
        nauvis_settings.starting_points = Public.CreateVanillaSpawns(global.vanilla_spawn_count, global.vanilla_spawn_distance)

        -- ENFORCE ISLAND MAP GEN
        if (global.silo_island_mode) then
            nauvis_settings.property_expression_names.elevation = '0_17-island'
        end
    end
end

--------------------------------------------------------------------------------
-- Functions for removing/modifying enemies
--------------------------------------------------------------------------------

-- Convenient way to remove aliens, just provide an area
function Public.RemoveAliensInArea(surface, area)
    for _, entity in pairs(surface.find_entities_filtered {area = area, force = 'enemy'}) do
        entity.destroy()
    end
end

-- Make an area safer
-- Reduction factor divides the enemy spawns by that number. 2 = half, 3 = third, etc...
-- Also removes all big and huge worms in that area
function Public.ReduceAliensInArea(surface, area, reductionFactor)
    for _, entity in pairs(surface.find_entities_filtered {area = area, force = 'enemy'}) do
        if (math_random(0, reductionFactor) > 0) then
            entity.destroy()
        end
    end
end

-- Downgrades worms in an area based on chance.
-- 100% small would mean all worms are changed to small.
function Public.DowngradeWormsInArea(surface, area, small_percent, medium_percent, big_percent)
    local worm_types = {'small-worm-turret', 'medium-worm-turret', 'big-worm-turret', 'behemoth-worm-turret'}

    for _, entity in pairs(surface.find_entities_filtered {area = area, name = worm_types}) do
        -- Roll a number between 0-100
        local rand_percent = math_random(0, 100)
        local worm_pos = entity.position
        local worm_name = entity.name

        -- If number is less than small percent, change to small
        if (rand_percent <= small_percent) then
            -- ELSE If number is less than medium percent, change to small
            if (not (worm_name == 'small-worm-turret')) then
                entity.destroy()
                surface.create_entity {name = 'small-worm-turret', position = worm_pos, force = game.forces.enemy}
            end
        elseif (rand_percent <= medium_percent) then
            -- ELSE If number is less than big percent, change to small
            if (not (worm_name == 'medium-worm-turret')) then
                entity.destroy()
                surface.create_entity {name = 'medium-worm-turret', position = worm_pos, force = game.forces.enemy}
            end
        elseif (rand_percent <= big_percent) then
            if (not (worm_name == 'big-worm-turret')) then
                entity.destroy()
                surface.create_entity {name = 'big-worm-turret', position = worm_pos, force = game.forces.enemy}
            end

        -- ELSE ignore it.
        end
    end
end

function Public.DowngradeWormsDistanceBasedOnChunkGenerate(event)
    local global_data = MPS.get()
    if (Public.getDistance({x = 0, y = 0}, event.area.left_top) < (global.near_max_dist * global_data.chunk_size)) then
        Public.DowngradeWormsInArea(event.surface, event.area, 100, 100, 100)
    elseif (Public.getDistance({x = 0, y = 0}, event.area.left_top) < (global.far_min_dist * global_data.chunk_size)) then
        Public.DowngradeWormsInArea(event.surface, event.area, 50, 90, 100)
    elseif (Public.getDistance({x = 0, y = 0}, event.area.left_top) < (global.far_max_dist * global_data.chunk_size)) then
        Public.DowngradeWormsInArea(event.surface, event.area, 20, 80, 97)
    else
        Public.DowngradeWormsInArea(event.surface, event.area, 0, 20, 90)
    end
end

-- A function Public.to help me remove worms in an area.
-- Yeah kind of an unecessary wrapper, but makes my life easier to remember the worm types.
function Public.RemoveWormsInArea(surface, area, small, medium, big, behemoth)
    local worm_types = {}

    if (small) then
        table_insert(worm_types, 'small-worm-turret')
    end
    if (medium) then
        table_insert(worm_types, 'medium-worm-turret')
    end
    if (big) then
        table_insert(worm_types, 'big-worm-turret')
    end
    if (behemoth) then
        table_insert(worm_types, 'behemoth-worm-turret')
    end

    -- Destroy
    if (Public.TableLength(worm_types) > 0) then
        for _, entity in pairs(surface.find_entities_filtered {area = area, name = worm_types}) do
            entity.destroy()
        end
    else
        log('RemoveWormsInArea had empty worm_types list!')
    end
end

-- Add Long Reach to Character
function Public.GivePlayerLongReach(player)
    player.character.character_build_distance_bonus = global.build_dist_bonus
    player.character.character_reach_distance_bonus = global.reach_dist_bonus
    -- player.character.character_resource_reach_distance_bonus  = global.resource_dist_bonus
end

-- General purpose cover an area in tiles.
function Public.CoverAreaInTiles(surface, area, tile_name)
    local tiles = {}
    for x = area.left_top.x, area.left_top.x + 31 do
        for y = area.left_top.y, area.left_top.y + 31 do
            table_insert(tiles, {name = tile_name, position = {x = x, y = y}})
        end
    end
    surface.set_tiles(tiles, true)
end

--------------------------------------------------------------------------------
-- Anti-griefing Stuff & Gravestone (My own version)
--------------------------------------------------------------------------------
function Public.AntiGriefing(force)
    force.zoom_to_world_deconstruction_planner_enabled = false
    Public.SetForceGhostTimeToLive(force)
end

function Public.SetForceGhostTimeToLive(force)
    if global.ghost_ttl ~= 0 then
        force.global.ghost_ttl = global.ghost_ttl + 1
    end
end

function Public.SetItemBlueprintTimeToLive(event)
    local type = event.created_entity.type
    if type == 'entity-ghost' or type == 'tile-ghost' then
        if global.ghost_ttl ~= 0 then
            event.created_entity.time_to_live = global.ghost_ttl
        end
    end
end

--------------------------------------------------------------------------------
-- Gravestone soft mod. With my own modifications/improvements.
--------------------------------------------------------------------------------
-- Return steel chest entity (or nil)
function Public.DropEmptySteelChest(player)
    local pos = player.surface.find_non_colliding_position('steel-chest', player.position, 15, 1)
    if not pos then
        return nil
    end
    local grave = player.surface.create_entity {name = 'steel-chest', position = pos, force = 'neutral'}
    return grave
end

function Public.DropGravestoneChests(player)
    local grave_inv
    local grave
    local count = 0

    -- Make sure we save stuff we're holding in our hands.
    player.clear_cursor()

    -- Loop through a players different inventories
    -- Put it all into a chest.
    -- If the chest is full, create a new chest.
    for i, id in ipairs {
        defines.inventory.character_armor,
        defines.inventory.character_main,
        defines.inventory.character_guns,
        defines.inventory.character_ammo,
        defines.inventory.character_vehicle,
        defines.inventory.character_trash
    } do
        local inv = player.get_inventory(id)

        -- No idea how inv can be nil sometimes...?
        if (inv ~= nil) then
            if ((#inv > 0) and not inv.is_empty()) then
                for j = 1, #inv do
                    if inv[j].valid_for_read then
                        -- Create a chest when counter is reset
                        if (count == 0) then
                            grave = Public.DropEmptySteelChest(player)
                            if (grave == nil) then
                                -- player.print("Not able to place a chest nearby! Some items lost!")
                                return
                            end
                            grave_inv = grave.get_inventory(defines.inventory.chest)
                        end
                        count = count + 1

                        -- Copy the item stack into a chest slot.
                        grave_inv[count].set_stack(inv[j])

                        -- Reset counter when chest is full
                        if (count == #grave_inv) then
                            count = 0
                        end
                    end
                end
            end

            -- Clear the player inventory so we don't have duplicate items lying around.
            inv.clear()
        end
    end

    if (grave ~= nil) then
        player.print('Successfully dropped your items into a chest! Go get them quick!')
    end
end

-- Dump player items into a chest after the body expires.
function Public.DropGravestoneChestFromCorpse(corpse)
    if ((corpse == nil) or (corpse.character_corpse_player_index == nil)) then
        return
    end

    local grave, grave_inv
    local count = 0

    local inv = corpse.get_inventory(defines.inventory.character_corpse)

    -- No idea how inv can be nil sometimes...?
    if (inv ~= nil) then
        if ((#inv > 0) and not inv.is_empty()) then
            for j = 1, #inv do
                if inv[j].valid_for_read then
                    -- Create a chest when counter is reset
                    if (count == 0) then
                        grave = Public.DropEmptySteelChest(corpse)
                        if (grave == nil) then
                            -- player.print("Not able to place a chest nearby! Some items lost!")
                            return
                        end
                        grave_inv = grave.get_inventory(defines.inventory.chest)
                    end
                    count = count + 1

                    -- Copy the item stack into a chest slot.
                    grave_inv[count].set_stack(inv[j])

                    -- Reset counter when chest is full
                    if (count == #grave_inv) then
                        count = 0
                    end
                end
            end
        end

    -- Clear the player inventory so we don't have duplicate items lying around.
    -- inv.clear()
    end

    if (grave ~= nil) and (game.players[corpse.character_corpse_player_index] ~= nil) then
        game.players[corpse.character_corpse_player_index].print(
            'Your corpse got eaten by biters! They kindly dropped your items into a chest! Go get them quick!'
        )
    end
end

--------------------------------------------------------------------------------
-- Item/Inventory stuff (used in autofill)
--------------------------------------------------------------------------------

-- Transfer Items Between Inventory
-- Returns the number of items that were successfully transferred.
-- Returns -1 if item not available.
-- Returns -2 if can't place item into destInv (ERROR)
function Public.TransferItems(srcInv, destEntity, itemStack)
    -- Check if item is in srcInv
    if (srcInv.get_item_count(itemStack.name) == 0) then
        return -1
    end

    -- Check if can insert into destInv
    if (not destEntity.can_insert(itemStack)) then
        return -2
    end

    -- Insert items
    local itemsRemoved = srcInv.remove(itemStack)
    itemStack.count = itemsRemoved
    return destEntity.insert(itemStack)
end

-- Attempts to transfer at least some of one type of item from an array of items.
-- Use this to try transferring several items in order
-- It returns once it successfully inserts at least some of one type.
function Public.TransferItemMultipleTypes(srcInv, destEntity, itemNameArray, itemCount)
    local ret = 0
    for _, itemName in pairs(itemNameArray) do
        ret = Public.TransferItems(srcInv, destEntity, {name = itemName, count = itemCount})
        if (ret > 0) then
            return ret -- Return the value succesfully transferred
        end
    end
    return ret -- Return the last error code
end

-- Autofills a turret with ammo
function Public.AutofillTurret(player, turret)
    local mainInv = player.get_main_inventory()
    if (mainInv == nil) then
        return
    end

    -- Attempt to transfer some ammo
    local ret =
        Public.TransferItemMultipleTypes(
        mainInv,
        turret,
        {'uranium-rounds-magazine', 'piercing-rounds-magazine', 'firearm-magazine'},
        global.autofill_ammo
    )

    -- Check the result and print the right text to inform the user what happened.
    if (ret > 0) then
        -- Inserted ammo successfully
        -- FlyingText("Inserted ammo x" .. ret, turret.position, my_color_red, player.surface)
    elseif (ret == -1) then
        Public.FlyingText('Out of ammo!', turret.position, Gui.my_color_red, player.surface)
    elseif (ret == -2) then
        Public.FlyingText('Autofill ERROR! - Report this bug!', turret.position, Gui.my_color_red, player.surface)
    end
end

-- Autofills a vehicle with fuel, bullets and shells where applicable
function Public.AutoFillVehicle(player, vehicle)
    local mainInv = player.get_main_inventory()
    if (mainInv == nil) then
        return
    end

    -- Attempt to transfer some fuel
    if ((vehicle.name == 'car') or (vehicle.name == 'tank') or (vehicle.name == 'locomotive')) then
        Public.TransferItemMultipleTypes(mainInv, vehicle, {'nuclear-fuel', 'rocket-fuel', 'solid-fuel', 'coal', 'wood'}, 50)
    end

    -- Attempt to transfer some ammo
    if ((vehicle.name == 'car') or (vehicle.name == 'tank')) then
        Public.TransferItemMultipleTypes(mainInv, vehicle, {'uranium-rounds-magazine', 'piercing-rounds-magazine', 'firearm-magazine'}, 100)
    end

    -- Attempt to transfer some tank shells
    if (vehicle.name == 'tank') then
        Public.TransferItemMultipleTypes(
            mainInv,
            vehicle,
            {'explosive-uranium-cannon-shell', 'uranium-cannon-shell', 'explosive-cannon-shell', 'cannon-shell'},
            100
        )
    end
end

--------------------------------------------------------------------------------
-- Resource patch and starting area generation
--------------------------------------------------------------------------------

-- Enforce a circle of land, also adds trees in a ring around the area.
function Public.CreateCropCircle(surface, centerPos, chunkArea, tileRadius, fillTile)
    local tileRadSqr = tileRadius ^ 2

    local dirtTiles = {}
    for i = chunkArea.left_top.x, chunkArea.right_bottom.x, 1 do
        for j = chunkArea.left_top.y, chunkArea.right_bottom.y, 1 do
            -- This ( X^2 + Y^2 ) is used to calculate if something
            -- is inside a circle area.
            local distVar = math_floor((centerPos.x - i) ^ 2 + (centerPos.y - j) ^ 2)

            -- Fill in all unexpected water in a circle
            if (distVar < tileRadSqr) then
                if
                    (surface.get_tile(i, j).collides_with('water-tile') or global.scenario_config.gen_settings.force_grass or
                        (game.active_mods['oarc-restricted-build']))
                 then
                    table_insert(dirtTiles, {name = fillTile, position = {i, j}})
                end
            end

            if global.scenario_config.gen_settings.trees_enabled then
                -- Create a circle of trees around the spawn point.
                if ((distVar < tileRadSqr - 200) and (distVar > tileRadSqr - 400)) then
                    surface.create_entity({name = 'tree-02', amount = 2, position = {i, j}})
                end
            end
        end
    end

    surface.set_tiles(dirtTiles)
end

function Public.CreateCropCircleNoTrees(surface, centerPos, chunkArea, tileRadius, fillTile)
    local tileRadSqr = tileRadius ^ 2

    local dirtTiles = {}
    for i = chunkArea.left_top.x, chunkArea.right_bottom.x, 1 do
        for j = chunkArea.left_top.y, chunkArea.right_bottom.y, 1 do
            -- This ( X^2 + Y^2 ) is used to calculate if something
            -- is inside a circle area.
            local distVar = math_floor((centerPos.x - i) ^ 2 + (centerPos.y - j) ^ 2)

            -- Fill in all unexpected water in a circle
            if (distVar < tileRadSqr) then
                if
                    (surface.get_tile(i, j).collides_with('water-tile') or global.scenario_config.gen_settings.force_grass or
                        (game.active_mods['oarc-restricted-build']))
                 then
                    table_insert(dirtTiles, {name = fillTile, position = {i, j}})
                end
            end
        end
    end

    surface.set_tiles(dirtTiles)
end

function Public.CreateCropSquare(surface, centerPos, area, tileRadius, fillTile)
    local left_top = area.left_top
    local right_bottom = area.right_bottom

    local dirtTiles = {}
    for i = left_top.x, right_bottom.x - 1, 1 do
        for j = left_top.y, right_bottom.y - 1, 1 do
            -- This ( X^2 + Y^2 ) is used to calculate if something
            -- is inside a circle area.

            local distVar = math_floor(math.max(abs(centerPos.x - i) - 10, abs(centerPos.y - j) + 20))
            --local distVar = math_floor((centerPos.x - i)^2 + (centerPos.y - j)^2)

            -- Fill in all unexpected water in a circle
            if (distVar < tileRadius) then
                if (surface.get_tile(i, j).collides_with('water-tile') or global.scenario_config.gen_settings.force_grass) then
                    table_insert(dirtTiles, {name = fillTile, position = {i, j}})
                end
            end
            if global.scenario_config.gen_settings.trees_enabled then
                -- Create a circle of trees around the spawn point.
                if ((distVar < tileRadius) and (distVar > tileRadius - 3)) then
                    surface.create_entity({name = 'tree-02', amount = 1, position = {i, j}})
                end
            end
        end
    end

    surface.set_tiles(dirtTiles)
end

-- COPIED FROM jvmguy!
-- Enforce a square of land, with a tree border
-- this is equivalent to the CreateCropCircle code
function Public.CreateCropOctagon(surface, centerPos, chunkArea, tileRadius, fillTile)
    local dirtTiles = {}
    for i = chunkArea.left_top.x, chunkArea.right_bottom.x, 1 do
        for j = chunkArea.left_top.y, chunkArea.right_bottom.y, 1 do
            local distVar1 = math_floor(math.max(abs(centerPos.x - i), abs(centerPos.y - j)))
            local distVar2 = math_floor(abs(centerPos.x - i) + abs(centerPos.y - j))
            local distVar = math.max(distVar1 * 1.1, distVar2 * 0.707 * 1.1)

            -- Fill in all unexpected water in a circle
            if (distVar < tileRadius + 2) then
                if
                    (surface.get_tile(i, j).collides_with('water-tile') or global.scenario_config.gen_settings.force_grass or
                        (game.active_mods['oarc-restricted-build']))
                 then
                    table_insert(dirtTiles, {name = fillTile, position = {i, j}})
                end
            end

            if global.scenario_config.gen_settings.trees_enabled then
                -- Create a tree ring
                if ((distVar < tileRadius) and (distVar > tileRadius - 2)) then
                    surface.create_entity({name = 'tree-01', amount = 1, position = {i, j}})
                end
            end
        end
    end
    surface.set_tiles(dirtTiles)
end

function Public.CreateMoat(surface, centerPos, chunkArea, tileRadius)
    local tileRadSqr = tileRadius ^ 2
    local waterTiles = {}
    for i = chunkArea.left_top.x, chunkArea.right_bottom.x, 1 do
        for j = chunkArea.left_top.y, chunkArea.right_bottom.y, 1 do
            -- This ( X^2 + Y^2 ) is used to calculate if something
            -- is inside a circle area.
            local distVar = math_floor((centerPos.x - i) ^ 2 + (centerPos.y - j) ^ 2)

            -- Create a circle of water
            if ((distVar < tileRadSqr + (1500 * global.scenario_config.gen_settings.moat_size_modifier)) and (distVar > tileRadSqr)) then
                table_insert(waterTiles, {name = 'water', position = {i, j}})
            end
        end
    end
    surface.set_tiles(waterTiles)
end

function Public.CreateMoatSquare(surface, centerPos, chunkArea, tileRadius)
    local waterTiles = {}
    local insert = table_insert
    for i = chunkArea.left_top.x, chunkArea.right_bottom.x - 1, 1 do
        for j = chunkArea.left_top.y, chunkArea.right_bottom.y - 1, 1 do
            local distVar = math_floor(math.max(abs(centerPos.x - i) - 22, abs(centerPos.y - j) + 18))

            -- Create a water ring
            if ((distVar < tileRadius) and (distVar > tileRadius - 3)) then
                insert(waterTiles, {name = 'deepwater', position = {i, j}})
            end
        end
    end
    surface.set_tiles(waterTiles)
end

-- Create a horizontal line of water
function Public.CreateWaterStrip(surface, leftPos, length)
    local waterTiles = {}
    for i = 0, length, 1 do
        table_insert(waterTiles, {name = 'water', position = {leftPos.x + i, leftPos.y}})
    end
    surface.set_tiles(waterTiles)
end

-- function to generate a resource patch, of a certain size/amount at a pos.
function Public.GenerateResourcePatch(surface, resourceName, diameter, pos, amount)
    local midPoint = math_floor(diameter / 2)
    if (diameter == 0) then
        return
    end
    for y = -midPoint, midPoint do
        for x = -midPoint, midPoint do
            if (not global.scenario_config.gen_settings.resources_circle_shape or ((x) ^ 2 + (y) ^ 2 < midPoint ^ 2)) then
                surface.create_entity(
                    {
                        name = resourceName,
                        amount = amount,
                        position = {pos.x + x, pos.y + y}
                    }
                )
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Holding pen for new players joining the map
--------------------------------------------------------------------------------
function Public.CreateWall(surface, pos)
    local wall = surface.create_entity({name = 'stone-wall', position = pos, force = global.main_force_name})
    if wall then
        wall.destructible = false
        wall.minable = false
    end
end

function Public.CreateHoldingPen(surface, chunkArea, sizeTiles, sizeMoat)
    local global_data = MPS.get()
    if
        (((chunkArea.left_top.x >= -(sizeTiles + sizeMoat + global_data.chunk_size)) and
            (chunkArea.left_top.x <= (sizeTiles + sizeMoat + global_data.chunk_size))) and
            ((chunkArea.left_top.y >= -(sizeTiles + sizeMoat + global_data.chunk_size)) and
                (chunkArea.left_top.y <= (sizeTiles + sizeMoat + global_data.chunk_size))))
     then
        -- Remove stuff
        Public.RemoveAliensInArea(surface, chunkArea)
        Public.RemoveInArea(surface, chunkArea, 'tree')
        Public.RemoveInArea(surface, chunkArea, 'resource')
        Public.RemoveInArea(surface, chunkArea, 'cliff')

        -- This loop runs through each tile
        local grassTiles = {}
        local waterTiles = {}
        for i = chunkArea.left_top.x, chunkArea.right_bottom.x, 1 do
            for j = chunkArea.left_top.y, chunkArea.right_bottom.y, 1 do
                -- Are we within the moat area?
                if
                    ((i > -(sizeTiles + sizeMoat)) and (i < ((sizeTiles + sizeMoat) - 1)) and (j > -(sizeTiles + sizeMoat)) and
                        (j < ((sizeTiles + sizeMoat) - 1)))
                 then
                    -- Are we within the land area? Place land.
                    if ((i > -(sizeTiles)) and (i < ((sizeTiles) - 1)) and (j > -(sizeTiles)) and (j < ((sizeTiles) - 1))) then
                        -- Else, surround with water.
                        table_insert(grassTiles, {name = 'grass-1', position = {i, j}})
                    else
                        table_insert(waterTiles, {name = 'water', position = {i, j}})
                    end
                end
            end
        end
        surface.set_tiles(waterTiles)
        surface.set_tiles(grassTiles)
    end
end

--------------------------------------------------------------------------------
-- EVENT SPECIFIC FUNCTIONS
--------------------------------------------------------------------------------

-- Display messages to a user everytime they join
function Public.PlayerJoinedMessages(event)
    local player = game.players[event.player_index]
    player.print(global.welcome_msg)
end

-- Remove decor to save on file size
function Public.UndecorateOnChunkGenerate(event)
    local surface = event.surface
    local chunkArea = event.area
    Public.RemoveDecorationsArea(surface, chunkArea)
    Public.RemoveFish(surface, chunkArea)
end

-- Give player items on respawn
-- Intended to be the default behavior when not using separate spawns
function Public.PlayerRespawnItems(event)
    Public.GivePlayerItems(game.players[event.player_index])
end

function Public.PlayerSpawnItems(event)
    Public.GivePlayerStarterItems(game.players[event.player_index])
end

-- Autofill softmod
function Public.Autofill(event)
    local player = game.players[event.player_index]
    local eventEntity = event.created_entity
    if not (eventEntity and eventEntity.valid) then
        return
    end

    -- Make sure player isn't dead?
    if (player.character == nil) then
        return
    end

    if (eventEntity.name == 'gun-turret') then
        Public.AutofillTurret(player, eventEntity)
    end

    if ((eventEntity.name == 'car') or (eventEntity.name == 'tank') or (eventEntity.name == 'locomotive')) then
        Public.AutoFillVehicle(player, eventEntity)
    end
end

-- Map loaders to logistics tech for unlocks.
local loaders_technology_map = {
    ['logistics'] = 'loader',
    ['logistics-2'] = 'fast-loader',
    ['logistics-3'] = 'express-loader'
}

function Public.EnableLoaders(event)
    local research = event.research
    local recipe = loaders_technology_map[research.name]
    if recipe then
        research.force.recipes[recipe].enabled = true
    end
end

return Public
