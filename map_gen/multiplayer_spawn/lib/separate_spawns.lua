-- separate_spawns.lua
-- Nov 2016
--
-- Code that handles everything regarding giving each player a separate spawn
-- Includes the GUI stuff

local Utils = require 'map_gen.multiplayer_spawn.lib.oarc_utils'
local UtilsGui = require 'map_gen.multiplayer_spawn.lib.oarc_gui_utils'
local Silo = require 'map_gen.multiplayer_spawn.lib.frontier_silo'
local MPS = require 'map_gen.multiplayer_spawn.lib.table'
local surface_name = require 'utils.surface'.get_surface_name()
local surface_index = require 'utils.surface'.get_surface()
local Config = require 'map_gen.multiplayer_spawn.config'
local Gui = require 'utils.gui.core'

local Public = {}
Public.removal = {}

local main_style = 'changelog_subheader_frame'

--------------------------------------------------------------------------------
-- EVENT RELATED FUNCTIONS
--------------------------------------------------------------------------------

-- When a new player is created, present the spawn options
-- Assign them to the main force so they can communicate with the team
-- without shouting.
function Public.SeparateSpawnsPlayerCreated(player_index)
    local player = game.players[player_index]

    -- Make sure spawn control tab is disabled
    Gui.set_tab(player, 'Spawn Controls', false)

    -- This checks if they have just joined the server.
    -- No assigned force yet.
    if (player.force.name ~= 'player') then
        Public.FindUnusedSpawns(player, false)
    end

    if game.forces[player.name] then
        game.merge_forces(player.name, global.main_force_name)
    end

    local i = player.get_main_inventory()
    local armor = player.get_inventory(defines.inventory.character_armor)
    local guns = player.get_inventory(defines.inventory.character_guns)
    local ammo = player.get_inventory(defines.inventory.character_ammo)
    local trash = player.get_inventory(defines.inventory.character_trash)
    if i and armor and guns and ammo and trash then
        i.clear()
        armor.clear()
        guns.clear()
        ammo.clear()
        trash.clear()
    end

    player.character.active = false

    player.force = global.main_force_name
    Public.DisplayWelcomeTextGui(player)
end

-- Check if the player has a different spawn point than the default one
-- Make sure to give the default starting items
function Public.SeparateSpawnsPlayerRespawned(event)
    local player = game.players[event.player_index]
    Public.SendPlayerToSpawn(player)
end

-- This is the main function Public.that creates the spawn area
-- Provides resources, land and a safe zone
function Public.SeparateSpawnsGenerateChunk(event)
    local surface = event.surface
    local chunkArea = event.area

    -- Modify enemies first.
    if global.modded_enemy then
        Utils.DowngradeWormsDistanceBasedOnChunkGenerate(event)
    end

    -- This handles chunk generation near player spawns
    -- If it is near a player spawn, it does a few things like make the area
    -- safe and provide a guaranteed area of land and water tiles.
    Public.SetupAndClearSpawnAreas(surface, chunkArea)
end

function Public.Remove_area(pos, chunk_radius)
    local data = Public.removal
    local c_pos = Utils.GetChunkPosFromTilePos(pos)
    for i = -chunk_radius, chunk_radius do
        for k = -chunk_radius, chunk_radius do
            local x = c_pos.x + i
            local y = c_pos.y + k
            table.insert(data, {pos = {x = x, y = y}})
        end
    end
end

function Public.Init_remove()
    local data = Public.removal
    while (#data > 0) do
        local c_remove = table.remove(data)
        local c_pos = c_remove.pos
        game.surfaces[surface_name].delete_chunk(c_pos)
    end
end

-- Call this if a player leaves the game or is reset
function Public.FindUnusedSpawns(player, remove_player)
    local global_data = MPS.get()
    if not player then
        log('ERROR - FindUnusedSpawns on NIL Player!')
        return
    end

    if (player.online_time < (global.min_online * global_data.ticks_per_minute)) then
        -- If this player is staying in the game, lets make sure we don't delete them
        -- along with the map chunks being cleared.
        player.teleport({x = 0, y = 0}, surface_name)
        if player and player.character and player.character.valid then
            player.character.active = true
        end

        -- Clear out global variables for that player
        if (global.playerSpawns[player.name] ~= nil) then
            global.playerSpawns[player.name] = nil
        end

        -- Remove them from the delayed spawn queue if they are in it
        for i = #global.delayedSpawns, 1, -1 do
            local delayedSpawn = global.delayedSpawns[i]

            if (player.name == delayedSpawn.playerName) then
                if (delayedSpawn.vanilla) then
                    log('Returning a vanilla spawn back to available.')
                    table.insert(global.vanillaSpawns, {x = delayedSpawn.pos.x, y = delayedSpawn.pos.y})
                end

                table.remove(global.delayedSpawns, i)
                log('Removing player from delayed spawn queue: ' .. player.name)
            end
        end

        -- Transfer or remove a shared spawn if player is owner
        if (global.sharedSpawns[player.name] ~= nil) then
            local teamMates = global.sharedSpawns[player.name].players

            if (#teamMates >= 1) then
                local newOwnerName = table.remove(teamMates)
                Public.TransferOwnershipOfSharedSpawn(player.name, newOwnerName)
            else
                global.sharedSpawns[player.name] = nil
            end
        end

        -- If a uniqueSpawn was created for the player, mark it as unused.
        if (global.uniqueSpawns[player.name] ~= nil) then
            local spawnPos = global.uniqueSpawns[player.name].pos

            -- Check if it was near someone else's base.
            local nearOtherSpawn = false
            for spawnPlayerName, otherSpawnPos in pairs(global.uniqueSpawns) do
                if
                    ((spawnPlayerName ~= player.name) and
                        (Utils.getDistance(spawnPos, otherSpawnPos.pos) < (global.scenario_config.gen_settings.land_area_tiles * 3)))
                 then
                    log("Won't remove base as it's close to another spawn: " .. spawnPlayerName)
                    nearOtherSpawn = true
                end
            end

            if (global.uniqueSpawns[player.name].vanilla) then
                log('Returning a vanilla spawn back to available.')
                table.insert(global.vanillaSpawns, {x = spawnPos.x, y = spawnPos.y})
            end

            global.uniqueSpawns[player.name] = nil

            log('Removing base: ' .. spawnPos.x .. ',' .. spawnPos.y)
            Public.Remove_area(spawnPos, global.check_spawn_ungenerated_chunk_radius + 5)
            Public.Init_remove()
            Utils.SendBroadcastMsg(
                'Press F for ' ..
                    player.name .. '. Their base was deleted because they left within ' .. global.min_online .. ' minutes of joining.'
            )
        end

        -- remove that player's cooldown setting
        if (global.playerCooldowns[player.name] ~= nil) then
            global.playerCooldowns[player.name] = nil
        end

        -- Remove from shared spawn player slots (need to search all)
        for _, sharedSpawn in pairs(global.sharedSpawns) do
            for key, playerName in pairs(sharedSpawn.players) do
                if (player.name == playerName) then
                    sharedSpawn.players[key] = nil
                end
            end
        end

        -- Remove a force if this player created it and they are the only one on it
        if ((#player.force.players <= 1) and (player.force.name ~= global.main_force_name)) then
            game.merge_forces(player.force, global.main_force_name)
        end

        -- Remove the character completely
        if (remove_player) then
            game.remove_offline_players({player})
        end
    end
end

-- Clear the spawn areas.
-- This should be run inside the chunk generate event and be given a list of all
-- unique spawn points.
-- This clears enemies in the immediate area, creates a slightly safe area around it,
-- It no LONGER generates the resources though as that is now handled in a delayed event!
function Public.SetupAndClearSpawnAreas(surface, chunkArea)
    local global_data = MPS.get()
    for _, spawn in pairs(global.uniqueSpawns) do
        -- Create a bunch of useful area and position variables
        local landArea = Utils.GetAreaAroundPos(spawn.pos, global.scenario_config.gen_settings.land_area_tiles + global_data.chunk_size)
        local safeArea = Utils.GetAreaAroundPos(spawn.pos, global.scenario_config.safe_area.safe_radius)
        local warningArea = Utils.GetAreaAroundPos(spawn.pos, global.scenario_config.safe_area.warn_radius)
        local reducedArea = Utils.GetAreaAroundPos(spawn.pos, global.scenario_config.safe_area.danger_radius)
        local chunkAreaCenter = {
            x = chunkArea.left_top.x + (global_data.chunk_size / 2),
            y = chunkArea.left_top.y + (global_data.chunk_size / 2)
        }
        local spawnPosOffset = {
            x = spawn.pos.x + global.scenario_config.gen_settings.land_area_tiles,
            y = spawn.pos.y + global.scenario_config.gen_settings.land_area_tiles
        }

        -- Make chunks near a spawn safe by removing enemies
        if Utils.CheckIfInArea(chunkAreaCenter, safeArea) then
            -- Create a warning area with heavily reduced enemies
            Utils.RemoveAliensInArea(surface, chunkArea)
        elseif Utils.CheckIfInArea(chunkAreaCenter, warningArea) then
            -- Create a third area with moderatly reduced enemies
            Utils.ReduceAliensInArea(surface, chunkArea, global.scenario_config.safe_area.warn_reduction)
            -- DowngradeWormsInArea(surface, chunkArea, 100, 100, 100)
            Utils.RemoveWormsInArea(surface, chunkArea, false, true, true, true) -- remove all non-small worms.
        elseif Utils.CheckIfInArea(chunkAreaCenter, reducedArea) then
            Utils.ReduceAliensInArea(surface, chunkArea, global.scenario_config.safe_area.danger_reduction)
            -- DowngradeWormsInArea(surface, chunkArea, 50, 100, 100)
            Utils.RemoveWormsInArea(surface, chunkArea, false, false, true, true) -- remove all huge/behemoth worms.
        end

        if (not spawn.vanilla) then
            -- If the chunk is within the main land area, then clear trees/resources
            -- and create the land spawn areas (guaranteed land with a circle of trees)
            if Utils.CheckIfInArea(chunkAreaCenter, landArea) then
                if spawn.this then
                    -- Remove trees/resources inside the spawn area
                    if (spawn.layout == 'classic') then
                        Utils.RemoveInCircle(surface, chunkArea, 'tree', spawn.pos, global.scenario_config.gen_settings.land_area_tiles)
                    else
                        Utils.RemoveInCircle(surface, chunkArea, 'tree', spawn.pos, global.scenario_config.gen_settings.land_area_tiles + 5)
                    end
                    Utils.RemoveInCircle(surface, chunkArea, 'resource', spawn.pos, global.scenario_config.gen_settings.land_area_tiles + 5)
                    Utils.RemoveInCircle(surface, chunkArea, 'cliff', spawn.pos, global.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'market', spawn.pos, global.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(
                        surface,
                        chunkArea,
                        'container',
                        spawn.pos,
                        global.scenario_config.gen_settings.land_area_tiles + 50
                    )
                    Utils.RemoveInCircle(
                        surface,
                        chunkArea,
                        'simple-entity',
                        spawn.pos,
                        global.scenario_config.gen_settings.land_area_tiles + 50
                    )
                    Utils.RemoveDecorationsArea(surface, chunkArea)
                else
                    -- Remove trees/resources inside the spawn area
                    Utils.RemoveInCircle(surface, chunkArea, 'tree', spawn.pos, global.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(
                        surface,
                        chunkArea,
                        'resource',
                        spawn.pos,
                        global.scenario_config.gen_settings.land_area_tiles + 50
                    )
                    Utils.RemoveInCircle(surface, chunkArea, 'cliff', spawn.pos, global.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'market', spawn.pos, global.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(
                        surface,
                        chunkArea,
                        'container',
                        spawn.pos,
                        global.scenario_config.gen_settings.land_area_tiles + 50
                    )
                    Utils.RemoveInCircle(
                        surface,
                        chunkArea,
                        'simple-entity',
                        spawn.pos,
                        global.scenario_config.gen_settings.land_area_tiles + 50
                    )
                    Utils.RemoveDecorationsArea(surface, chunkArea)
                end

                local fill_tile = 'dirt-' .. math.random(1, 6)

                if (spawn.layout == 'classic') then
                    Utils.CreateCropCircle(surface, spawn.pos, chunkArea, global.scenario_config.gen_settings.land_area_tiles, fill_tile)
                    if (spawn.moat) then
                        Utils.CreateMoat(surface, spawn.pos, chunkArea, global.scenario_config.gen_settings.land_area_tiles, fill_tile)
                    end
                end
                if (spawn.layout == 'new') then
                    Utils.CreateCropSquare(surface, spawn.pos, chunkArea, global_data.chunk_size * 3, fill_tile)
                    if (spawn.moat) then
                        Utils.CreateMoatSquare(
                            surface,
                            spawn.pos,
                            chunkArea,
                            global.scenario_config.gen_settings.land_area_tiles,
                            fill_tile
                        )
                    end
                end
            end
        end
    end
end

-- Same as GetClosestPosFromTable but specific to global.uniqueSpawns
function Public.GetClosestUniqueSpawn(pos)
    local closest_dist = nil
    local closest_key = nil

    for k, s in pairs(global.uniqueSpawns) do
        local new_dist = Utils.getDistance(pos, s.pos)
        if (closest_dist == nil) then
            closest_dist = new_dist
            closest_key = k
        elseif (closest_dist > new_dist) then
            closest_dist = new_dist
            closest_key = k
        end
    end

    if (closest_key == nil) then
        -- log("GetClosestUniqueSpawn ERROR - None found?")
        return nil
    end

    return global.uniqueSpawns[closest_key]
end

-- I wrote this to ensure everyone gets safer spawns regardless of evolution level.
-- This is intended to downgrade any biters/spitters spawning near player bases.
-- I'm not sure the performance impact of this but I'm hoping it's not bad.
function Public.ModifyEnemySpawnsNearPlayerStartingAreas(event)
    if (not event.entity or not (event.entity.force.name == 'enemy') or not event.entity.position) then
        log('ModifyBiterSpawns - Unexpected use.')
        return
    end

    local enemy_pos = event.entity.position
    local surface = event.entity.surface
    local enemy_name = event.entity.name

    local closest_spawn = Public.GetClosestUniqueSpawn(enemy_pos)

    if (closest_spawn == nil) then
        -- log("GetClosestUniqueSpawn ERROR - None found?")
        return
    end

    -- No enemies inside safe radius!
    if (Utils.getDistance(enemy_pos, closest_spawn.pos) < global.scenario_config.safe_area.safe_radius) then
        -- Warn distance is all SMALL only.
        event.entity.destroy()
    elseif (Utils.getDistance(enemy_pos, closest_spawn.pos) < global.scenario_config.safe_area.warn_radius) then
        -- Danger distance is MEDIUM max.
        if ((enemy_name == 'big-biter') or (enemy_name == 'behemoth-biter') or (enemy_name == 'medium-biter')) then
            -- log("Downgraded biter close to spawn.")
            event.entity.destroy()
            surface.create_entity {name = 'small-biter', position = enemy_pos, force = game.forces.enemy}
        elseif ((enemy_name == 'big-spitter') or (enemy_name == 'behemoth-spitter') or (enemy_name == 'medium-spitter')) then
            -- log("Downgraded spitter close to spawn.")
            event.entity.destroy()
            surface.create_entity {name = 'small-spitter', position = enemy_pos, force = game.forces.enemy}
        elseif ((enemy_name == 'big-worm-turret') or (enemy_name == 'behemoth-worm-turret') or (enemy_name == 'medium-worm-turret')) then
            event.entity.destroy()
            surface.create_entity {name = 'small-worm-turret', position = enemy_pos, force = game.forces.enemy}
        -- log("Downgraded worm close to spawn.")
        end
    elseif (Utils.getDistance(enemy_pos, closest_spawn.pos) < global.scenario_config.safe_area.danger_radius) then
        if ((enemy_name == 'big-biter') or (enemy_name == 'behemoth-biter')) then
            -- log("Downgraded biter further from spawn.")
            event.entity.destroy()
            surface.create_entity {name = 'medium-biter', position = enemy_pos, force = game.forces.enemy}
        elseif ((enemy_name == 'big-spitter') or (enemy_name == 'behemoth-spitter')) then
            -- log("Downgraded spitter further from spawn
            event.entity.destroy()
            surface.create_entity {name = 'medium-spitter', position = enemy_pos, force = game.forces.enemy}
        elseif ((enemy_name == 'big-worm-turret') or (enemy_name == 'behemoth-worm-turret')) then
            event.entity.destroy()
            surface.create_entity {name = 'medium-worm-turret', position = enemy_pos, force = game.forces.enemy}
        -- log("Downgraded worm further from spawn.")
        end
    end
end

--------------------------------------------------------------------------------
-- NON-EVENT RELATED FUNCTIONS
--------------------------------------------------------------------------------

-- Generate the basic starter resource around a given location.
function Public.GenerateStartingResources_New(surface, pos)
    local g_res = global.scenario_config.resource_tiles_new
    local g_pos = global.scenario_config.pos

    local ore_pos = Utils.shuffle(g_pos)
    local _pos_1 = {x = pos.x + ore_pos[1].x, y = pos.y + ore_pos[1].y}
    local _pos_2 = {x = pos.x + ore_pos[2].x, y = pos.y + ore_pos[2].y}
    local _pos_3 = {x = pos.x + ore_pos[3].x, y = pos.y + ore_pos[3].y}
    local _pos_4 = {x = pos.x + ore_pos[4].x, y = pos.y + ore_pos[4].y}

    Utils.GenerateResourcePatch(surface, 'iron-ore', g_res[1].size, _pos_1, g_res[1].amount)

    Utils.GenerateResourcePatch(surface, 'copper-ore', g_res[2].size, _pos_2, g_res[2].amount)

    Utils.GenerateResourcePatch(surface, 'stone', g_res[3].size, _pos_3, g_res[3].amount)

    Utils.GenerateResourcePatch(surface, 'coal', g_res[4].size, _pos_4, g_res[4].amount)

    -- Generate special resource patches (oil)
    for p_name, p_data in pairs(global.scenario_config.resource_patches_new) do
        local oil_patch_x = pos.x + p_data.x_offset_start
        local oil_patch_y = pos.y + p_data.y_offset_start
        for i = 1, p_data.num_patches do
            surface.create_entity(
                {
                    name = p_name,
                    amount = p_data.amount,
                    position = {oil_patch_x, oil_patch_y}
                }
            )
            oil_patch_x = oil_patch_x + p_data.x_offset_next
            oil_patch_y = oil_patch_y + p_data.y_offset_next
        end
    end
end

function Public.GenerateStartingResources_Classic(surface, pos)
    local rand_settings = global.scenario_config.resource_rand_pos_settings

    -- Generate all resource tile patches
    if (not rand_settings.enabled) then
        for t_name, t_data in pairs(global.scenario_config.resource_tiles_classic) do
            local pos = {x = pos.x + t_data.x_offset, y = pos.y + t_data.y_offset}
            Utils.GenerateResourcePatch(surface, t_name, t_data.size, pos, t_data.amount)
        end
    else
        -- Create list of resource tiles
        local r_list = {}
        for k, _ in pairs(global.scenario_config.resource_tiles_classic) do
            if (k ~= '') then
                table.insert(r_list, k)
            end
        end
        local shuffled_list = Utils.shuffle(r_list)

        -- This places resources in a semi-circle
        -- Tweak in config.lua
        local angle_offset = rand_settings.angle_offset
        local num_resources = Utils.TableLength(global.scenario_config.resource_tiles_classic)
        local theta = ((rand_settings.angle_final - rand_settings.angle_offset) / num_resources)
        local count = 0

        for _, k_name in pairs(shuffled_list) do
            local angle = (theta * count) + angle_offset

            local tx = (rand_settings.radius * math.cos(angle)) + pos.x
            local ty = (rand_settings.radius * math.sin(angle)) + pos.y

            local pos = {x = math.floor(tx), y = math.floor(ty)}
            Utils.GenerateResourcePatch(
                surface,
                k_name,
                global.scenario_config.resource_tiles_classic[k_name].size,
                pos,
                global.scenario_config.resource_tiles_classic[k_name].amount
            )
            count = count + 1
        end
    end

    -- Generate special resource patches (oil)
    for p_name, p_data in pairs(global.scenario_config.resource_patches_classic) do
        local oil_patch_x = pos.x + p_data.x_offset_start
        local oil_patch_y = pos.y + p_data.y_offset_start
        for i = 1, p_data.num_patches do
            surface.create_entity(
                {
                    name = p_name,
                    amount = p_data.amount,
                    position = {oil_patch_x, oil_patch_y}
                }
            )
            oil_patch_x = oil_patch_x + p_data.x_offset_next
            oil_patch_y = oil_patch_y + p_data.y_offset_next
        end
    end
end

-- Add a spawn to the shared spawn global
-- Used for tracking which players are assigned to it, where it is and if
-- it is open for new players to join
function Public.CreateNewSharedSpawn(player)
    global.sharedSpawns[player.name] = {
        openAccess = false,
        AlwaysAccess = false,
        position = global.playerSpawns[player.name],
        players = {}
    }
end

function Public.TransferOwnershipOfSharedSpawn(prevOwnerName, newOwnerName)
    -- Transfer the shared spawn global
    global.sharedSpawns[newOwnerName] = global.sharedSpawns[prevOwnerName]
    global.sharedSpawns[newOwnerName].openAccess = false
    global.sharedSpawns[newOwnerName].AlwaysAccess = false
    global.sharedSpawns[prevOwnerName] = nil

    -- Transfer the unique spawn global
    global.uniqueSpawns[newOwnerName] = global.uniqueSpawns[prevOwnerName]
    global.uniqueSpawns[prevOwnerName] = nil

    game.players[newOwnerName].print('You have been given ownership of this base!')
end

-- Returns the number of players currently online at the shared spawn
function Public.GetOnlinePlayersAtSharedSpawn(ownerName)
    if (global.sharedSpawns[ownerName] ~= nil) then
        -- Does not count base owner
        local count = 0

        -- For each player in the shared spawn, check if online and add to count.
        for _, player in pairs(game.connected_players) do
            if (ownerName == player.name) then
                count = count + 1
            end

            for _, playerName in pairs(global.sharedSpawns[ownerName].players) do
                if (playerName == player.name) then
                    count = count + 1
                end
            end
        end

        return count
    else
        return 0
    end
end

-- Get the number of currently available shared spawns
-- This means the base owner has enabled access AND the number of online players
-- is below the threshold.
function Public.GetNumberOfAvailableSharedSpawns()
    local count = 0

    for ownerName, sharedSpawn in pairs(global.sharedSpawns) do
        if (sharedSpawn.openAccess or sharedSpawn.AlwaysAccess and (game.players[ownerName] ~= nil) and game.players[ownerName].connected) then
            if ((global.max_players == 0) or (#global.sharedSpawns[ownerName].players < global.max_players)) then
                count = count + 1
            end
        end
    end

    return count
end

-- Initializes the globals used to track the special spawn and player
-- status information
function Public.InitSpawnGlobalsAndForces()
    -- This contains each player's spawn point. Literally where they will respawn.
    -- There is a way in game to change this under one of the little menu features I added.
    if (global.playerSpawns == nil) then
        global.playerSpawns = {}
    end

    -- This is the most important table. It is a list of all the unique spawn points.
    -- This is what chunk generation checks against.
    -- Each entry looks like this: {pos={x,y},moat=bool,vanilla=bool}
    if (global.uniqueSpawns == nil) then
        global.uniqueSpawns = {}
    end

    -- List of available vanilla spawns
    if (global.vanillaSpawns == nil) then
        global.vanillaSpawns = {}
    end

    -- This keeps a list of any player that has shared their base.
    -- Each entry contains information about if it's open, spawn pos, and players in the group.
    if (global.sharedSpawns == nil) then
        global.sharedSpawns = {}
    end

    -- This seems to be unused right now, but I had plans to re-use spawn points in the past.
    -- if (global.unusedSpawns == nil) then
    --     global.unusedSpawns = {}
    -- end

    -- Each player has an option to change their respawn which has a cooldown when used.
    -- Other similar abilities/functions that require cooldowns could be added here.
    if (global.playerCooldowns == nil) then
        global.playerCooldowns = {}
    end

    -- List of players in the "waiting room" for a buddy spawn.
    -- They show up in the list to select when doing a buddy spawn.
    if (global.waitingBuddies == nil) then
        global.waitingBuddies = {}
    end

    -- Players who have made a spawn choice get put into this list while waiting.
    -- An on_tick event checks when it expires and then places down the base resources, and teleports the player.
    -- Go look at DelayedSpawnOnTick() for more info.
    if (global.delayedSpawns == nil) then
        global.delayedSpawns = {}
    end

    -- This is what I use to communicate a buddy spawn request between the buddies.
    -- This contains information of who is asking, and what options were selected.
    if (global.buddySpawnOptions == nil) then
        global.buddySpawnOptions = {}
    end

    -- Silo info
    if (global.siloPosition == nil) then
        global.siloPosition = {}
    end

    -- Name a new force to be the default force.
    -- This is what any new player is assigned to when they join, even before they spawn.
    local main_force_name = Public.CreateForce(global.main_force_name)
    main_force_name.set_spawn_position({x = 0, y = 0}, surface_name)
    main_force_name.worker_robots_storage_bonus = 5
    main_force_name.worker_robots_speed_modifier = 2
end

function Public.DoesPlayerHaveCustomSpawn(player)
    for name, _ in pairs(global.playerSpawns) do
        if (player.name == name) then
            return true
        end
    end
    return false
end

function Public.ChangePlayerSpawn(player, pos)
    global.playerSpawns[player.name] = pos
    global.playerCooldowns[player.name] = {setRespawn = game.tick}
end

function Public.QueuePlayerForDelayedSpawn(playerName, spawn, classic, moatChoice, vanillaSpawn, this)
    local global_data = MPS.get()
    if not this then
        this = false
    end
    -- If we get a valid spawn point, setup the area
    if ((spawn.x ~= 0) or (spawn.y ~= 0)) then
        global.uniqueSpawns[playerName] = {
            pos = spawn,
            layout = classic,
            moat = moatChoice,
            vanilla = vanillaSpawn,
            this = this
        }

        local delay_spawn_seconds = 2 * (math.ceil(global.scenario_config.gen_settings.land_area_tiles / global_data.chunk_size))
        game.players[playerName].surface.request_to_generate_chunks(spawn, 4)
        local delayedTick = game.tick + delay_spawn_seconds * global_data.ticks_per_second
        table.insert(
            global.delayedSpawns,
            {
                playerName = playerName,
                layout = classic,
                pos = spawn,
                moat = moatChoice,
                vanilla = vanillaSpawn,
                delayedTick = delayedTick,
                this = this
            }
        )

        Public.DisplayPleaseWaitForSpawnDialog(game.players[playerName], delay_spawn_seconds)
    else
        log('THIS SHOULD NOT EVER HAPPEN! Spawn failed!')
        Utils.SendBroadcastMsg('ERROR!! Failed to create spawn point for: ' .. playerName)
    end
end

-- Check a table to see if there are any players waiting to spawn
-- Check if we are past the delayed tick count
-- Spawn the players and remove them from the table.
function Public.DelayedSpawnOnTick()
    if ((game.tick % (30)) == 1) then
        if ((global.delayedSpawns ~= nil) and (#global.delayedSpawns > 0)) then
            for i = #global.delayedSpawns, 1, -1 do
                local delayedSpawn = global.delayedSpawns[i]

                if (delayedSpawn.delayedTick < game.tick) then
                    -- TODO, add check here for if chunks around spawn are generated surface.is_chunk_generated(chunkPos)
                    if (game.players[delayedSpawn.playerName] ~= nil) then
                        Public.SendPlayerToNewSpawnAndCreateIt(delayedSpawn)
                    end
                    table.remove(global.delayedSpawns, i)
                end
            end
        end
    end
end

function Public.SendPlayerToNewSpawnAndCreateIt(delayedSpawn)
    -- DOUBLE CHECK and make sure the area is super safe.
    Utils.ClearNearbyEnemies(delayedSpawn.pos, global.scenario_config.safe_area.safe_radius, game.surfaces[surface_name])
    local water_data
    if delayedSpawn.layout == 'classic' then
        water_data = global.scenario_config.water_classic
    elseif delayedSpawn.layout == 'new' then
        water_data = global.scenario_config.water_new
    end
    if (not delayedSpawn.vanilla) then
        -- Create the spawn resources here
        Utils.CreateWaterStrip(
            game.surfaces[surface_name],
            {x = delayedSpawn.pos.x + water_data.x_offset, y = delayedSpawn.pos.y + water_data.y_offset},
            water_data.length
        )
        Utils.CreateWaterStrip(
            game.surfaces[surface_name],
            {x = delayedSpawn.pos.x + water_data.x_offset, y = delayedSpawn.pos.y + water_data.y_offset + 1},
            water_data.length
        )
        if delayedSpawn.layout == 'classic' then
            Public.GenerateStartingResources_Classic(game.surfaces[surface_name], delayedSpawn.pos)
        elseif delayedSpawn.layout == 'new' then
            Public.GenerateStartingResources_New(game.surfaces[surface_name], delayedSpawn.pos)
        end
    end

    -- Send the player to that position
    local player = game.players[delayedSpawn.playerName]
    rendering.draw_text {
        text = player.name .. ' comfy home!',
        surface = surface_name,
        target = {delayedSpawn.pos.x, delayedSpawn.pos.y},
        color = {r = 0.98, g = 0.66, b = 0.22},
        scale = 6,
        font = 'heading-1',
        alignment = 'center',
        scale_with_zoom = false
    }
    player.teleport(delayedSpawn.pos, surface_name)
    Utils.GivePlayerStarterItems(game.players[delayedSpawn.playerName])
    if player and player.character and player.character.valid then
        player.character.active = true
    end

    -- Chart the area.
    --Utils.ChartArea(player.force, delayedSpawn.pos, math.ceil(global.scenario_config.gen_settings.land_area_tiles/global_data.chunk_size), player.surface)

    if (player.gui.screen.wait_for_spawn_dialog ~= nil) then
        player.gui.screen.wait_for_spawn_dialog.destroy()
    end
end

function Public.SendPlayerToSpawn(player)
    local pos
    local dest = global.playerSpawns[player.name]
    if not dest then
        pos = player.surface.find_non_colliding_position('character', {x = 0, y = 0}, 3, 0, 5)
    else
        pos = player.surface.find_non_colliding_position('character', dest, 3, 0, 5)
    end
    if (Public.DoesPlayerHaveCustomSpawn(player)) then
        if pos then
            player.teleport(pos, player.surface)
        else
            player.teleport(global.playerSpawns[player.name], player.surface)
        end
        if player and player.character and player.character.valid then
            player.character.active = true
        end
    else
        if not dest then
            player.teleport(player.surface.find_non_colliding_position('character', {x = 0, y = 0}, 3, 0, 5), player.surface)
        else
            player.teleport(player.surface.find_non_colliding_position('character', dest, 3, 0, 5), player.surface)
        end
        if player and player.character and player.character.valid then
            player.character.active = true
        end
    end
end

function Public.SendPlayerToRandomSpawn(player)
    local numSpawns = Utils.TableLength(global.uniqueSpawns)
    local rndSpawn = math.random(0, numSpawns)
    local counter = 0

    if (rndSpawn == 0) then
        player.teleport(game.forces[global.main_force_name].get_spawn_position(surface_name), surface_name)
        if player and player.character and player.character.valid then
            player.character.active = true
        end
    else
        counter = counter + 1
        for _, spawn in pairs(global.uniqueSpawns) do
            if (counter == rndSpawn) then
                player.teleport(spawn.pos)
                if player and player.character and player.character.valid then
                    player.character.active = true
                end
                break
            end
            counter = counter + 1
        end
    end
end

function Public.CreateForce(force_name)
    local global_data = MPS.get()
    local newForce = nil

    -- Check if force already exists
    if (game.forces[force_name] ~= nil) then
        -- Create a new force
        log('Force already exists!')
        return game.forces[global.main_force_name]
    elseif (Utils.TableLength(game.forces) < global_data.max_forces) then
        newForce = game.create_force(force_name)
        if global.enable_shared_team_vision then
            newForce.share_chart = true
        end
        if global.enable_r_queue then
            newForce.research_queue_enabled = true
        end
        newForce.worker_robots_storage_bonus = 5
        newForce.worker_robots_speed_modifier = 2
        -- Chart silo areas if necessary
        if global.frontier_rocket_silo_mode and global.enable_silo_vision then
            Silo.ChartRocketSiloAreas(game.surfaces[surface_name], newForce)
        end
        Utils.SetCeaseFireBetweenAllForces()
        Utils.SetFriendlyBetweenAllForces()
        newForce.friendly_fire = true
        if (global.enable_antigrief) then
            Utils.AntiGriefing(newForce)
        end
    else
        log('TOO MANY FORCES!!! - CreateForce()')
    end

    return newForce
end

function Public.CreatePlayerCustomForce(player)
    local newForce = Public.CreateForce(player.name)
    player.force = newForce

    if (newForce.name == player.name) then
        Utils.SendBroadcastMsg(player.name .. ' has started their own team!')
    else
        player.print('Sorry, no new teams can be created. You were assigned to the default team instead.')
    end

    return newForce
end

-- function to generate some map_gen_settings.starting_points
-- You should only use this at the start of the game really.
function Public.CreateVanillaSpawns(count, spacing)
    local points = {}

    -- Get an ODD number from the square of the input count.
    -- Always rounding up so we don't end up with less points that requested.
    local sqrt_count = math.ceil(math.sqrt(count))
    if (sqrt_count % 2 == 0) then
        sqrt_count = sqrt_count + 1
    end

    -- Need to know how much to offset the grid.
    local sqrt_half = math.floor((sqrt_count - 1) / 2)

    if (sqrt_count < 1) then
        log('CreateVanillaSpawns less than 1!!')
        return
    end

    if (global.vanillaSpawns == nil) then
        global.vanillaSpawns = {}
    end

    -- This should give me points centered around 0,0 I think.
    for i = -sqrt_half, sqrt_half, 1 do
        for j = -sqrt_half, sqrt_half, 1 do
            if (i ~= 0 or j ~= 0) then -- EXCEPT don't put 0,0
                table.insert(points, {x = i * spacing, y = j * spacing})
                table.insert(global.vanillaSpawns, {x = i * spacing, y = j * spacing})
            end
        end
    end

    -- Do something with the return value.
    return points
end

-- Useful when combined with something like CreateVanillaSpawns
-- Where it helps ensure ALL chunks generated use new map_gen_settings.
function Public.DeleteAllChunksExceptCenter(surface)
    -- Delete the starting chunks that make it into the game before settings are changed.
    for chunk in surface.get_chunks() do
        -- Don't delete the chunk that might contain players lol.
        -- This is really only a problem for launching AS the host. Not headless
        if ((chunk.x ~= 0) and (chunk.y ~= 0)) then
            surface.delete_chunk({chunk.x, chunk.y})
        end
    end
end

-- Find a vanilla spawn as close as possible to the given target_distance
function Public.FindUnusedVanillaSpawn(surface, target_distance)
    local best_key = nil
    local best_distance = nil

    for k, v in pairs(global.vanillaSpawns) do
        -- Check if chunks nearby are not generated.
        local chunk_pos = Utils.GetChunkPosFromTilePos(v)
        if Utils.IsChunkAreaUngenerated(chunk_pos, global.check_spawn_ungenerated_chunk_radius + 15, surface) then
            -- If it's not a valid spawn anymore, let's remove it.
            -- Is this our first valid find?
            if ((best_key == nil) or (best_distance == nil)) then
                -- Check if it is closer to target_distance than previous option.
                best_key = k
                best_distance = math.abs(math.sqrt((v.x ^ 2) + (v.y ^ 2)) - target_distance)
            else
                local new_distance = math.abs(math.sqrt((v.x ^ 2) + (v.y ^ 2)) - target_distance)
                if (new_distance < best_distance) then
                    best_key = k
                    best_distance = new_distance
                end
            end
        else
            log('Removing vanilla spawn due to chunks generated: x=' .. v.x .. ',y=' .. v.y)
            table.remove(global.vanillaSpawns, k)
        end
    end

    local spawn_pos = {x = 0, y = 0}
    if ((best_key ~= nil) and (global.vanillaSpawns[best_key] ~= nil)) then
        spawn_pos.x = global.vanillaSpawns[best_key].x
        spawn_pos.y = global.vanillaSpawns[best_key].y
        table.remove(global.vanillaSpawns, best_key)
    end
    log('Found unused vanilla spawn: x=' .. spawn_pos.x .. ',y=' .. spawn_pos.y)
    return spawn_pos
end

function Public.ValidateVanillaSpawns(surface)
    for k, v in pairs(global.vanillaSpawns) do
        -- Check if chunks nearby are not generated.
        local chunk_pos = Utils.GetChunkPosFromTilePos(v)
        if not Utils.IsChunkAreaUngenerated(chunk_pos, global.check_spawn_ungenerated_chunk_radius + 15, surface) then
            log('Removing vanilla spawn due to chunks generated: x=' .. v.x .. ',y=' .. v.y)
            table.remove(global.vanillaSpawns, k)
        end
    end
end

local SPAWN_GUI_MAX_WIDTH = 500
local SPAWN_GUI_MAX_HEIGHT = 1000

-- Use this for testing shared spawns...
-- local sharedSpawnExample1 = {openAccess=true,
--                             position={x=50,y=50},
--                             players={"ABC", "DEF"}}
-- local sharedSpawnExample2 = {openAccess=false,
--                             position={x=200,y=200},
--                             players={"ABC", "DEF"}}
-- local sharedSpawnExample3 = {openAccess=true,
--                             position={x=400,y=400},
--                             players={"A", "B", "C", "D"}}
-- global.sharedSpawns = {testName1=sharedSpawnExample1,
--                        testName2=sharedSpawnExample2,
--                        Oarc=sharedSpawnExample3}

-- A display gui message
-- Meant to be display the first time a player joins.
function Public.DisplayWelcomeTextGui(player)
    if
        ((player.gui.screen['global.welcome_msg'] ~= nil) or (player.gui.screen['spawn_opts'] ~= nil) or
            (player.gui.screen['shared_spawn_opts'] ~= nil) or
            (player.gui.screen['join_shared_spawn_wait_menu'] ~= nil) or
            (player.gui.screen['buddy_spawn_opts'] ~= nil) or
            (player.gui.screen['buddy_wait_menu'] ~= nil) or
            (player.gui.screen['buddy_request_menu'] ~= nil) or
            (player.gui.screen['wait_for_spawn_dialog'] ~= nil))
     then
        log('DisplayWelcomeTextGui called while some other dialog is already displayed!')
        return false
    end

    if player.gui.screen.welcome_msg then
        player.gui.screen.welcome_msg.destroy()
    end

    local wGui =
        player.gui.screen.add {
        name = 'welcome_msg',
        type = 'frame',
        direction = 'vertical',
        caption = global.welcome_msg_title,
        style = main_style
    }
    wGui.auto_center = true
    wGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    wGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Start with server message.
    UtilsGui.AddLabel(wGui, 'server_msg_lbl1', global.server_msg, UtilsGui.my_label_style)
    UtilsGui.AddSpacer(wGui)

    -- Informational message about the scenario
    UtilsGui.AddLabel(wGui, 'scenario_info_msg_lbl1', global.scenario_info_msg, UtilsGui.my_label_style)
    UtilsGui.AddSpacer(wGui)

    -- Warning about spawn creation time
    UtilsGui.AddLabel(wGui, 'spawn_time_msg_lbl1', {'oarc-spawn-time-warning-msg'}, UtilsGui.my_warning_style)

    -- Confirm button
    UtilsGui.AddSpacerLine(wGui)
    local button_flow = wGui.add {type = 'flow'}
    button_flow.style.horizontal_align = 'right'
    button_flow.style.horizontally_stretchable = true
    button_flow.add {
        name = 'welcome_okay_btn',
        type = 'button',
        caption = {'oarc-i-understand'},
        style = 'confirm_button'
    }

    return true
end

-- Handle the gui click of the welcome msg
function Public.WelcomeTextGuiClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.player_index]
    local buttonClicked = event.element.name

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (buttonClicked == 'welcome_okay_btn') then
        if (player.gui.screen.welcome_msg ~= nil) then
            player.gui.screen.welcome_msg.destroy()
        end
        Public.DisplaySpawnOptions(player)
    end
end

-- Display the spawn options and explanation
function Public.DisplaySpawnOptions(player)
    if (player == nil) then
        log('DisplaySpawnOptions with no valid player...')
        return
    end

    if (player.gui.screen.spawn_opts ~= nil) then
        log('Tried to display spawn options when it was already displayed!')
        return
    end
    player.gui.screen.add {
        name = 'spawn_opts',
        type = 'frame',
        direction = 'vertical',
        caption = {'oarc-spawn-options'},
        style = main_style
    }
    local sGui = player.gui.screen.spawn_opts
    sGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    sGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT
    sGui.auto_center = true

    -- Warnings and explanations...
    --local warn_msg = {"oarc-click-info-btn-help"}
    --UtilsGui.AddLabel(sGui, "warning_lbl1", warn_msg, UtilsGui.my_warning_style)
    --UtilsGui.AddLabel(sGui, "spawn_msg_lbl1", SPWN1, UtilsGui.my_label_style)

    -- Button and message about the regular vanilla spawn

    -- The main spawning options. Solo near and solo far.
    -- If enable, you can also choose to be on your own team.
    UtilsGui.AddLabel(sGui, 'warning_lbl1', 'You can choose between the classic layout or the new one.', UtilsGui.my_label_style)
    local layout_flow = sGui.add {name = 'layout', type = 'frame', direction = 'vertical', style = 'bordered_frame'}
    UtilsGui.AddLabel(layout_flow, 'normal_spawn_lbl1', {'oarc-layout'}, UtilsGui.my_label_style)
    layout_flow.add {
        name = 'layout_classic',
        type = 'radiobutton',
        caption = {'oarc-layout-old'},
        state = false,
        tooltip = 'The classic layout, a circle.'
    }
    layout_flow.add {
        name = 'layout_new',
        type = 'radiobutton',
        caption = {'oarc-layout-new'},
        state = true,
        tooltip = 'The new layout, rectangle-alike shape.'
    }

    local soloSpawnFlow =
        sGui.add {
        name = 'spawn_solo_flow',
        type = 'frame',
        direction = 'vertical',
        style = 'bordered_frame'
    }

    if global.enable_default_spawn then
        local vanilla =
            sGui.add {
            name = 'vanilla_flow',
            type = 'frame',
            direction = 'vertical',
            style = 'bordered_frame'
        }
        local normal_spawn_text = {'oarc-default-spawn-behavior'}
        UtilsGui.AddLabel(vanilla, 'normal_spawn_lbl1', normal_spawn_text, UtilsGui.my_label_style)

        vanilla.add {
            name = 'default_spawn_btn',
            type = 'button',
            caption = {'oarc-vanilla-spawn'}
        }
    end

    -- Radio buttons to pick your team.
    if (global.enable_separate_teams) then
        soloSpawnFlow.add {
            name = 'isolated_spawn_main_team_radio',
            type = 'radiobutton',
            caption = {'oarc-join-main-team-radio'},
            state = true
        }
        soloSpawnFlow.add {
            name = 'isolated_spawn_new_team_radio',
            type = 'radiobutton',
            caption = {'oarc-create-own-team-radio'},
            state = false
        }
    end

    -- OPTIONS frame
    -- UtilsGui.AddLabel(soloSpawnFlow, "options_spawn_lbl1",
    --     "Additional spawn options can be selected here. Not all are compatible with each other.", UtilsGui.my_label_style)

    -- Allow players to spawn with a moat around their area.
    if (global.scenario_config.gen_settings.moat_choice_enabled and not global.enable_vanilla_spawns) then
        soloSpawnFlow.add {
            name = 'isolated_spawn_moat_option_checkbox',
            type = 'checkbox',
            caption = {'oarc-moat-option'},
            state = false
        }
    end
    -- if (global.enable_vanilla_spawns and (#global.vanillaSpawns > 0)) then
    --     soloSpawnFlow.add{name = "isolated_spawn_vanilla_option_checkbox",
    --                     type = "checkbox",
    --                     caption="Use a pre-set vanilla spawn point. " .. #global.vanillaSpawns .. " available.",
    --                     state=false}
    -- end

    -- Isolated spawn options. The core gameplay of this scenario.
    local soloSpawnbuttons =
        soloSpawnFlow.add {
        name = 'spawn_solo_flow',
        type = 'flow',
        direction = 'horizontal'
    }
    --soloSpawnbuttons.style.horizontal_align = "center"
    soloSpawnbuttons.style.horizontally_stretchable = true
    soloSpawnbuttons.add {
        name = 'isolated_spawn_near',
        type = 'button',
        caption = {'oarc-solo-spawn-near'}
    }
    soloSpawnbuttons.add {
        name = 'isolated_spawn_far',
        type = 'button',
        caption = {'oarc-solo-spawn-far'}
    }

    if (global.enable_vanilla_spawns) then
        UtilsGui.AddLabel(soloSpawnFlow, 'isolated_spawn_lbl1', {'oarc-starting-area-vanilla'}, UtilsGui.my_label_style)
        UtilsGui.AddLabel(
            soloSpawnFlow,
            'vanilla_spawn_lbl2',
            {'oarc-vanilla-spawns-available', #global.vanillaSpawns},
            UtilsGui.my_label_style
        )
    else
        UtilsGui.AddLabel(soloSpawnFlow, 'isolated_spawn_lbl1', {'oarc-starting-area-normal'}, UtilsGui.my_label_style)
    end

    -- Spawn options to join another player's base.
    local sharedSpawnFrame =
        sGui.add {
        name = 'spawn_shared_flow',
        type = 'frame',
        direction = 'vertical',
        style = 'bordered_frame'
    }
    if global.enable_shared_spawns then
        local numAvailSpawns = Public.GetNumberOfAvailableSharedSpawns()
        if (numAvailSpawns > 0) then
            sharedSpawnFrame.add {
                name = 'join_other_spawn',
                type = 'button',
                caption = {'oarc-join-someone-avail', numAvailSpawns}
            }
            local join_spawn_text = {'oarc-join-someone-info'}
            UtilsGui.AddLabel(sharedSpawnFrame, 'join_other_spawn_lbl1', join_spawn_text, UtilsGui.my_label_style)
        else
            UtilsGui.AddLabel(sharedSpawnFrame, 'join_other_spawn_lbl1', {'oarc-no-shared-avail'}, UtilsGui.my_label_style)
            sharedSpawnFrame.add {
                name = 'join_other_spawn_check',
                type = 'button',
                caption = {'oarc-join-check-again'}
            }
        end
    else
        UtilsGui.AddLabel(sharedSpawnFrame, 'join_other_spawn_lbl1', {'oarc-shared-spawn-disabled'}, UtilsGui.my_warning_style)
    end

    -- Awesome buddy spawning system
    if (not global.enable_vanilla_spawns) then
        if global.enable_shared_spawns and global.enable_buddy_spawn then
            local buddySpawnFrame =
                sGui.add {
                name = 'spawn_buddy_flow',
                type = 'frame',
                direction = 'vertical',
                style = 'bordered_frame'
            }

            -- UtilsGui.AddSpacerLine(buddySpawnFrame, "buddy_spawn_msg_spacer")
            buddySpawnFrame.add {
                name = 'buddy_spawn',
                type = 'button',
                caption = {'oarc-buddy-spawn'}
            }
            UtilsGui.AddLabel(buddySpawnFrame, 'buddy_spawn_lbl1', {'oarc-buddy-spawn-info'}, UtilsGui.my_label_style)
        end
    end

    -- Some final notes
    if (global.max_players > 0) then
        UtilsGui.AddLabel(sGui, 'max_players_lbl2', {'oarc-max-players-shared-spawn', global.max_players - 1}, UtilsGui.my_note_style)
    end
    --local spawn_distance_notes={"oarc-spawn-dist-notes", global.near_min_dist, global.near_max_dist, global.far_min_dist, global.far_max_dist}
    --UtilsGui.AddLabel(sGui, "note_lbl1", spawn_distance_notes, UtilsGui.my_note_style)
end

-- This just updates the radio buttons/checkboxes when players click them.
function Public.SpawnOptsRadioSelect(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local elemName = event.element.name

    if (elemName == 'isolated_spawn_main_team_radio') then
        event.element.parent.isolated_spawn_new_team_radio.state = false
    elseif (elemName == 'isolated_spawn_new_team_radio') then
        event.element.parent.isolated_spawn_main_team_radio.state = false
    end

    if (elemName == 'layout_new') then
        event.element.parent.layout_classic.state = false
    elseif (elemName == 'layout_classic') then
        event.element.parent.layout_new.state = false
    end

    if (elemName == 'buddy_spawn_main_team_radio') then
        event.element.parent.buddy_spawn_new_team_radio.state = false
        event.element.parent.buddy_spawn_buddy_team_radio.state = false
    elseif (elemName == 'buddy_spawn_new_team_radio') then
        event.element.parent.buddy_spawn_main_team_radio.state = false
        event.element.parent.buddy_spawn_buddy_team_radio.state = false
    elseif (elemName == 'buddy_spawn_buddy_team_radio') then
        event.element.parent.buddy_spawn_main_team_radio.state = false
        event.element.parent.buddy_spawn_new_team_radio.state = false
    end
end

-- Handle the gui click of the spawn options
function Public.SpawnOptsGuiClick(event)
    local global_data = MPS.get()
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.player_index]
    local elemName = event.element.name
    local layout

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (player.gui.screen.spawn_opts == nil) then
        return -- Gui event unrelated to this gui.
    end

    local pgcs = player.gui.screen.spawn_opts

    local classic = pgcs.layout.layout_classic.state
    local new = pgcs.layout.layout_new.state

    local joinMainTeamRadio, joinOwnTeamRadio, moatChoice, vanillaChoice = false

    if classic then
        layout = 'classic'
    end
    if new then
        layout = 'new'
    end

    -- Check if a valid button on the gui was pressed
    -- and delete the GUI
    if
        ((elemName == 'default_spawn_btn') or (elemName == 'isolated_spawn_near') or (elemName == 'isolated_spawn_far') or
            (elemName == 'join_other_spawn') or
            (elemName == 'buddy_spawn') or
            (elemName == 'join_other_spawn_check'))
     then
        if (global.enable_separate_teams) then
            joinMainTeamRadio = pgcs.spawn_solo_flow.isolated_spawn_main_team_radio.state
            joinOwnTeamRadio = pgcs.spawn_solo_flow.isolated_spawn_new_team_radio.state
        else
            joinMainTeamRadio = true
            joinOwnTeamRadio = false
        end
        if
            (global.scenario_config.gen_settings.moat_choice_enabled and not global.enable_vanilla_spawns and
                (pgcs.spawn_solo_flow.isolated_spawn_moat_option_checkbox ~= nil))
         then
            moatChoice = pgcs.spawn_solo_flow.isolated_spawn_moat_option_checkbox.state
        end
        -- if (global.enable_vanilla_spawns and
        --     (pgcs.spawn_solo_flow.isolated_spawn_vanilla_option_checkbox ~= nil)) then
        --     vanillaChoice = pgcs.spawn_solo_flow.isolated_spawn_vanilla_option_checkbox.state
        -- end
        pgcs.destroy()
    else
        return -- Do nothing, no valid element item was clicked.
    end

    if (elemName == 'default_spawn_btn') then
        Utils.GivePlayerStarterItems(player)
        Public.ChangePlayerSpawn(player, player.force.get_spawn_position(surface_name))
        Utils.SendBroadcastMsg({'oarc-player-is-joining-main-force', player.name})
        Utils.ChartArea(
            player.force,
            player.position,
            math.ceil(global.scenario_config.gen_settings.land_area_tiles / global_data.chunk_size),
            player.surface
        )
        -- Unlock spawn control gui tab
        --Gui.set_tab(player, "Spawn Controls", true)
        if player and player.character and player.character.valid then
            player.character.active = true
        end
    elseif ((elemName == 'isolated_spawn_near') or (elemName == 'isolated_spawn_far')) then
        --game.permissions.get_group("Default").add_player(player)
        -- Create a new spawn point
        local newSpawn = {x = 0, y = 0}

        -- Create a new force for player if they choose that radio button
        if global.enable_separate_teams and joinOwnTeamRadio then
            local newForce = Public.CreatePlayerCustomForce(player)
        end

        -- Find an unused vanilla spawn
        -- if (vanillaChoice) then
        if (global.enable_vanilla_spawns) then
            -- Default OARC-type pre-set layout spawn.
            if (elemName == 'isolated_spawn_far') then
                newSpawn = Public.FindUnusedVanillaSpawn(game.surfaces[surface_name], global.far_max_dist * global_data.chunk_size)
            elseif (elemName == 'isolated_spawn_near') then
                newSpawn = Public.FindUnusedVanillaSpawn(game.surfaces[surface_name], global.near_min_dist * global_data.chunk_size)
            end
        else
            -- Find coordinates of a good place to spawn
            if (elemName == 'isolated_spawn_far') then
                newSpawn = Utils.FindUngeneratedCoordinates(global.far_min_dist, global.far_max_dist, player.surface)
            elseif (elemName == 'isolated_spawn_near') then
                newSpawn = Utils.FindUngeneratedCoordinates(global.near_min_dist, global.near_max_dist, player.surface)
            end
        end

        -- If that fails, find a random map edge in a rand direction.
        if ((newSpawn.x == 0) and (newSpawn.y == 0)) then
            newSpawn = Utils.FindMapEdge(Utils.GetRandomVector(), player.surface)
            log('Resorting to find map edge! x=' .. newSpawn.x .. ',y=' .. newSpawn.y)
        end

        -- Create that player's spawn in the global vars
        Public.ChangePlayerSpawn(player, newSpawn)

        local this = false

        -- Send the player there
        -- QueuePlayerForDelayedSpawn(player.name, newSpawn, moatChoice, vanillaChoice)
        Public.QueuePlayerForDelayedSpawn(player.name, newSpawn, layout, moatChoice, global.enable_vanilla_spawns, this)
        if (elemName == 'isolated_spawn_near') then
            Utils.SendBroadcastMsg({'oarc-player-is-joining-near', player.name})
        elseif (elemName == 'isolated_spawn_far') then
            Utils.SendBroadcastMsg({'oarc-player-is-joining-far', player.name})
        end

        -- Unlock spawn control gui tab
        Gui.set_tab(player, 'Spawn Controls', true)
    elseif (elemName == 'join_other_spawn') then
        -- Provide a way to refresh the gui to check if people have shared their
        -- bases.
        Public.DisplaySharedSpawnOptions(player)
    elseif (elemName == 'join_other_spawn_check') then
        -- Hacky buddy spawn system
        Public.DisplaySpawnOptions(player)
    elseif (elemName == 'buddy_spawn') then
        table.insert(global.waitingBuddies, player.name)
        Utils.SendBroadcastMsg({'oarc-looking-for-buddy', player.name})

        Public.DisplayBuddySpawnOptions(player)
    end
end

-- Display the spawn options and explanation
function Public.DisplaySharedSpawnOptions(player)
    player.gui.screen.add {
        name = 'shared_spawn_opts',
        type = 'frame',
        direction = 'vertical',
        caption = {'oarc-avail-bases-join'},
        style = main_style
    }

    local shGuiFrame = player.gui.screen.shared_spawn_opts
    shGuiFrame.style.minimal_height = 300
    shGuiFrame.auto_center = true
    local shGui = shGuiFrame.add {type = 'scroll-pane', name = 'spawns_scroll_pane', caption = ''}
    UtilsGui.ApplyStyle(shGui, UtilsGui.my_fixed_width_style)
    shGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    shGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT
    shGui.horizontal_scroll_policy = 'never'

    for spawnName, sharedSpawn in pairs(global.sharedSpawns) do
        if (sharedSpawn.openAccess or sharedSpawn.AlwaysAccess and (game.players[spawnName] ~= nil) and game.players[spawnName].connected) then
            local spotsRemaining = global.max_players - #global.sharedSpawns[spawnName].players
            if (global.max_players == 0) then
                shGui.add {type = 'button', caption = spawnName, name = spawnName}
            elseif (spotsRemaining > 0) then
                shGui.add {
                    type = 'button',
                    caption = {'oarc-spawn-spots-remaining', spawnName, spotsRemaining},
                    name = spawnName
                }
            end
            if (shGui.spawnName ~= nil) then
                -- UtilsGui.AddSpacer(buddyGui, spawnName .. "spacer_lbl")
                UtilsGui.ApplyStyle(shGui[spawnName], Utils.my_small_button_style)
            end
        end
    end

    shGui.add {
        name = 'shared_spawn_cancel',
        type = 'button',
        caption = {'oarc-cancel-return-to-previous'},
        style = 'back_button'
    }
end

-- Handle the gui click of the shared spawn options
function Public.SharedSpwnOptsGuiClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.player_index]
    local buttonClicked = event.element.name

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (event.element.parent) then
        if (event.element.parent.name ~= 'spawns_scroll_pane') then
            return
        end
    end

    -- Check for cancel button, return to spawn options
    if (buttonClicked == 'shared_spawn_cancel') then
        -- Else check for which spawn was selected
        -- If a spawn is removed during this time, the button will not do anything
        Public.DisplaySpawnOptions(player)
        if (player.gui.screen.shared_spawn_opts ~= nil) then
            player.gui.screen.shared_spawn_opts.destroy()
        end
    else
        for spawnName, sharedSpawn in pairs(global.sharedSpawns) do
            if ((buttonClicked == spawnName) and (game.players[spawnName] ~= nil) and (game.players[spawnName].connected)) then
                if global.sharedSpawns[spawnName].AlwaysAccess then
                    Utils.SendBroadcastMsg({'oarc-player-joining-base', player.name, spawnName})

                    -- Close the waiting players menu
                    if (player.gui.screen.shared_spawn_opts ~= nil) then
                        player.gui.screen.shared_spawn_opts.destroy()
                    end

                    -- Spawn the player
                    local joiningPlayer = player
                    Public.ChangePlayerSpawn(joiningPlayer, global.sharedSpawns[spawnName].position)
                    Public.SendPlayerToSpawn(joiningPlayer)
                    Utils.GivePlayerStarterItems(joiningPlayer)
                    table.insert(global.sharedSpawns[spawnName].players, joiningPlayer.name)
                    joiningPlayer.force = game.players[spawnName].force

                    -- Unlock spawn control gui tab
                    Gui.set_tab(joiningPlayer, 'Spawn Controls', true)
                    if joiningPlayer and joiningPlayer.character and joiningPlayer.character.valid then
                        joiningPlayer.character.active = true
                    end
                    return
                else
                    -- Add the player to that shared spawns join queue.
                    if (global.sharedSpawns[spawnName].joinQueue == nil) then
                        global.sharedSpawns[spawnName].joinQueue = {}
                    end
                    table.insert(global.sharedSpawns[spawnName].joinQueue, player.name)

                    -- Clear the shared spawn options gui.
                    if (player.gui.screen.shared_spawn_opts ~= nil) then
                        player.gui.screen.shared_spawn_opts.destroy()
                    end

                    -- Display wait menu with cancel button.
                    Public.DisplaySharedSpawnJoinWaitMenu(player)

                    -- Tell other player they are requesting a response.
                    game.players[spawnName].print({'oarc-player-requesting-join-you', player.name})
                    Gui.refresh(game.players[spawnName])
                    break
                end
            end
        end
    end
end

function Public.DisplaySharedSpawnJoinWaitMenu(player)
    local sGui =
        player.gui.screen.add {
        name = 'join_shared_spawn_wait_menu',
        type = 'frame',
        direction = 'vertical',
        caption = {'oarc-waiting-for-spawn-owner'},
        style = main_style
    }
    sGui.auto_center = true
    sGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    sGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Warnings and explanations...
    UtilsGui.AddLabel(sGui, 'warning_lbl1', {'oarc-you-will-spawn-once-host'}, UtilsGui.my_warning_style)
    sGui.add {
        name = 'cancel_shared_spawn_wait_menu',
        type = 'button',
        caption = {'oarc-cancel-return-to-previous'},
        style = 'back_button'
    }
end

-- Handle the gui click of the buddy wait menu
function Public.SharedSpawnJoinWaitMenuClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.player_index]
    local elemName = event.element.name

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (player.gui.screen.join_shared_spawn_wait_menu == nil) then
        return -- Gui event unrelated to this gui.
    end

    -- Check if player is cancelling the request.
    if (elemName == 'cancel_shared_spawn_wait_menu') then
        player.gui.screen.join_shared_spawn_wait_menu.destroy()
        Public.DisplaySpawnOptions(player)

        -- Find and remove the player from the joinQueue they were in.
        for spawnName, sharedSpawn in pairs(global.sharedSpawns) do
            if (sharedSpawn.joinQueue ~= nil) then
                for index, requestingPlayer in pairs(sharedSpawn.joinQueue) do
                    if (requestingPlayer == player.name) then
                        table.remove(global.sharedSpawns[spawnName].joinQueue, index)
                        game.players[spawnName].print({'oarc-player-cancel-join-request', player.name})
                        return
                    end
                end
            end
        end

        log('ERROR! Failed to remove player from joinQueue!')
    end
end

local function IsSharedSpawnActive(player)
    if ((global.sharedSpawns[player.name] == nil) or (global.sharedSpawns[player.name].openAccess == false)) then
        return false
    else
        return true
    end
end

local function IsSharedSpawnActiveAlways(player)
    if ((global.sharedSpawns[player.name] == nil) or (global.sharedSpawns[player.name].AlwaysAccess == false)) then
        return false
    else
        return true
    end
end

-- Get a random warp point to go to
function Public.GetRandomSpawnPoint()
    local numSpawnPoints = Utils.TableLength(global.sharedSpawns)
    if (numSpawnPoints > 0) then
        local randSpawnNum = math.random(1, numSpawnPoints)
        local counter = 1
        for _, sharedSpawn in pairs(global.sharedSpawns) do
            if (randSpawnNum == counter) then
                return sharedSpawn.position
            end
            counter = counter + 1
        end
    end

    return {x = 0, y = 0}
end

-- This is a toggle function, it either shows or hides the spawn controls
function Public.CreateSpawnCtrlGuiTab(player, frame)
    local global_data = MPS.get()
    frame.clear()
    local spwnCtrls =
        frame.add {
        type = 'scroll-pane',
        name = 'spwn_ctrl_panel',
        caption = ''
    }
    UtilsGui.ApplyStyle(spwnCtrls, UtilsGui.my_fixed_width_style)
    spwnCtrls.style.maximal_height = SPAWN_GUI_MAX_HEIGHT
    spwnCtrls.horizontal_scroll_policy = 'never'

    if global.enable_shared_spawns then
        if (global.uniqueSpawns[player.name] ~= nil) then
            -- This checkbox allows people to join your base when they first
            -- start the game.
            spwnCtrls.add {
                type = 'checkbox',
                name = 'accessToggle',
                caption = {'oarc-spawn-allow-joiners'},
                state = IsSharedSpawnActive(player)
            }
            if Public.DoesPlayerHaveCustomSpawn(player) then
                if (global.sharedSpawns[player.name] == nil) then
                    Public.CreateNewSharedSpawn(player)
                end
            end
            if global.sharedSpawns[player.name].openAccess then
                spwnCtrls.add {
                    type = 'checkbox',
                    name = 'alwaysallowaccessToggle',
                    caption = {'oarc-spawn-always-allow-joiners'},
                    state = IsSharedSpawnActiveAlways(player)
                }
            end
            UtilsGui.ApplyStyle(spwnCtrls['accessToggle'], UtilsGui.my_fixed_width_style)
        end
    end

    -- Sets the player's custom spawn point to their current location
    if ((game.tick - global.playerCooldowns[player.name].setRespawn) > (global.respawn_cooldown * global_data.ticks_per_minute)) then
        spwnCtrls.add {type = 'button', name = 'setRespawnLocation', caption = {'oarc-set-respawn-loc'}}
        spwnCtrls['setRespawnLocation'].style.font = 'default-small-semibold'
    else
        UtilsGui.AddLabel(
            spwnCtrls,
            'respawn_cooldown_note1',
            {
                'oarc-set-respawn-loc-cooldown',
                Utils.formattime(
                    (global.respawn_cooldown * global_data.ticks_per_minute) - (game.tick - global.playerCooldowns[player.name].setRespawn)
                )
            },
            UtilsGui.my_note_style
        )
    end
    UtilsGui.AddLabel(spwnCtrls, 'respawn_cooldown_note2', {'oarc-set-respawn-note'}, UtilsGui.my_note_style)

    -- Display a list of people in the join queue for your base.
    if (global.enable_shared_spawns and IsSharedSpawnActive(player)) then
        if ((global.sharedSpawns[player.name].joinQueue ~= nil) and (#global.sharedSpawns[player.name].joinQueue > 0)) then
            UtilsGui.AddLabel(spwnCtrls, 'drop_down_msg_lbl1', {'oarc-select-player-join-queue'}, UtilsGui.my_label_style)
            spwnCtrls.add {
                name = 'join_queue_dropdown',
                type = 'drop-down',
                items = global.sharedSpawns[player.name].joinQueue
            }
            spwnCtrls.add {
                name = 'accept_player_request',
                type = 'button',
                caption = {'oarc-accept'}
            }
            spwnCtrls.add {
                name = 'reject_player_request',
                type = 'button',
                caption = {'oarc-reject'}
            }
        else
            UtilsGui.AddLabel(spwnCtrls, 'empty_join_queue_note1', {'oarc-no-player-join-reqs'}, UtilsGui.my_note_style)
        end
        spwnCtrls.add {
            name = 'join_queue_spacer',
            type = 'label',
            caption = ' '
        }
    end
end

function Public.SpawnCtrlGuiOptionsSelect(event)
    if not (event and event.element and event.element.valid) then
        return
    end

    local player = game.players[event.element.player_index]
    local name = event.element.name

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    -- Handle changes to spawn sharing.
    if (name == 'accessToggle') then
        if event.element.state then
            if Public.DoesPlayerHaveCustomSpawn(player) then
                if (global.sharedSpawns[player.name] == nil) then
                    Public.CreateNewSharedSpawn(player)
                else
                    global.sharedSpawns[player.name].openAccess = true
                end

                Utils.SendBroadcastMsg({'oarc-start-shared-base', player.name})
            end
        else
            if (global.sharedSpawns[player.name] ~= nil) then
                global.sharedSpawns[player.name].openAccess = false
                global.sharedSpawns[player.name].AlwaysAccess = false
                Utils.SendBroadcastMsg({'oarc-stop-shared-base', player.name})
            end
        end
        Gui.refresh(player)
    end
    if (name == 'alwaysallowaccessToggle') then
        if event.element.state then
            if Public.DoesPlayerHaveCustomSpawn(player) then
                if (global.sharedSpawns[player.name] == nil) then
                    Public.CreateNewSharedSpawn(player)
                else
                    global.sharedSpawns[player.name].AlwaysAccess = true
                end

                Utils.SendBroadcastMsg({'oarc-start-always-shared-base', player.name})
            end
        else
            if (global.sharedSpawns[player.name] ~= nil) then
                global.sharedSpawns[player.name].AlwaysAccess = false
                Utils.SendBroadcastMsg({'oarc-stop-always-shared-base', player.name})
            end
        end
        Gui.refresh(player)
    end
end

function Public.SpawnCtrlGuiClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end

    local player = game.players[event.element.player_index]
    local elemName = event.element.name

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (event.element.parent) then
        if (event.element.parent.name ~= 'spwn_ctrl_panel') then
            return
        end
    end

    -- Sets a new respawn point and resets the cooldown.
    if (elemName == 'setRespawnLocation') then
        if Public.DoesPlayerHaveCustomSpawn(player) then
            Public.ChangePlayerSpawn(player, player.position)
            Gui.refresh(player)
            player.print({'oarc-spawn-point-updated'})
        end
    end

    -- Accept or reject pending player join requests to a shared base
    if ((elemName == 'accept_player_request') or (elemName == 'reject_player_request')) then
        if ((event.element.parent.join_queue_dropdown == nil) or (event.element.parent.join_queue_dropdown.selected_index == 0)) then
            player.print({'oarc-selected-player-not-wait'})
            Gui.refresh(player)
            return
        end

        local joinQueueIndex = event.element.parent.join_queue_dropdown.selected_index
        local joinQueuePlayerChoice = event.element.parent.join_queue_dropdown.get_item(joinQueueIndex)

        if ((game.players[joinQueuePlayerChoice] == nil) or (not game.players[joinQueuePlayerChoice].connected)) then
            player.print({'oarc-selected-player-not-wait'})
            Gui.refresh(player)
            return
        end

        if (elemName == 'reject_player_request') then
            player.print({'oarc-reject-joiner', joinQueuePlayerChoice})
            Utils.SendMsg(joinQueuePlayerChoice, {'oarc-your-request-rejected'})
            Gui.refresh(player)

            -- Close the waiting players menu
            if (game.players[joinQueuePlayerChoice].gui.screen.join_shared_spawn_wait_menu) then
                game.players[joinQueuePlayerChoice].gui.screen.join_shared_spawn_wait_menu.destroy()
                Public.DisplaySpawnOptions(game.players[joinQueuePlayerChoice])
            end

            -- Find and remove the player from the joinQueue they were in.
            for index, requestingPlayer in pairs(global.sharedSpawns[player.name].joinQueue) do
                if (requestingPlayer == joinQueuePlayerChoice) then
                    table.remove(global.sharedSpawns[player.name].joinQueue, index)
                    return
                end
            end
        elseif (elemName == 'accept_player_request') then
            -- Find and remove the player from the joinQueue they were in.
            for index, requestingPlayer in pairs(global.sharedSpawns[player.name].joinQueue) do
                if (requestingPlayer == joinQueuePlayerChoice) then
                    table.remove(global.sharedSpawns[player.name].joinQueue, index)
                end
            end
            Gui.refresh(player)
            -- If player exists, then do stuff.
            if (game.players[joinQueuePlayerChoice]) then
                -- Send an announcement
                Utils.SendBroadcastMsg({'oarc-player-joining-base', joinQueuePlayerChoice, player.name})

                -- Close the waiting players menu
                if (game.players[joinQueuePlayerChoice].gui.screen.join_shared_spawn_wait_menu) then
                    game.players[joinQueuePlayerChoice].gui.screen.join_shared_spawn_wait_menu.destroy()
                end

                -- Spawn the player
                local joiningPlayer = game.players[joinQueuePlayerChoice]
                Public.ChangePlayerSpawn(joiningPlayer, global.sharedSpawns[player.name].position)
                Public.SendPlayerToSpawn(joiningPlayer)
                Utils.GivePlayerStarterItems(joiningPlayer)
                table.insert(global.sharedSpawns[player.name].players, joiningPlayer.name)
                joiningPlayer.force = game.players[player.name].force

                -- Unlock spawn control gui tab
                Gui.set_tab(joiningPlayer, 'Spawn Controls', true)
                if joiningPlayer and joiningPlayer.character and joiningPlayer.character.valid then
                    joiningPlayer.character.active = true
                end
            else
                Utils.SendBroadcastMsg({'oarc-player-left-while-joining', joinQueuePlayerChoice})
            end
        end
    end
end

-- Display the buddy spawn menu
function Public.DisplayBuddySpawnOptions(player)
    local buddyGui =
        player.gui.screen.add {
        name = 'buddy_spawn_opts',
        type = 'frame',
        direction = 'vertical',
        caption = {'oarc-buddy-spawn-options'},
        style = main_style
    }
    buddyGui.auto_center = true
    buddyGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    buddyGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Warnings and explanations...
    UtilsGui.AddLabel(buddyGui, 'buddy_info_msg', {'oarc-buddy-spawn-instructions'}, UtilsGui.my_label_style)
    UtilsGui.AddSpacer(buddyGui)

    local layout_flow = buddyGui.add {name = 'layout', type = 'frame', direction = 'vertical', style = 'bordered_frame'}
    UtilsGui.AddLabel(layout_flow, 'normal_spawn_lbl1', {'oarc-layout'}, UtilsGui.my_label_style)
    layout_flow.add {name = 'layout_classic', type = 'radiobutton', caption = {'oarc-layout-old'}, state = true}
    layout_flow.add {name = 'layout_new', type = 'radiobutton', caption = {'oarc-layout-new'}, state = false}

    -- The buddy spawning options.
    local buddySpawnFlow =
        buddyGui.add {
        name = 'spawn_buddy_flow',
        type = 'frame',
        direction = 'vertical',
        style = 'bordered_frame'
    }

    global.buddyList = {}
    for _, buddyName in pairs(global.waitingBuddies) do
        if (buddyName ~= player.name) then
            table.insert(global.buddyList, buddyName)
        end
    end

    UtilsGui.AddLabel(buddySpawnFlow, 'drop_down_msg_lbl1', {'oarc-buddy-select-info'}, UtilsGui.my_label_style)
    buddySpawnFlow.add {
        name = 'waiting_buddies_dropdown',
        type = 'drop-down',
        items = global.buddyList
    }
    buddySpawnFlow.add {
        name = 'refresh_buddy_list',
        type = 'button',
        caption = {'oarc-buddy-refresh'}
    }
    -- UtilsGui.AddSpacerLine(buddySpawnFlow)

    -- Allow picking of teams
    if (global.enable_separate_teams) then
        buddySpawnFlow.add {
            name = 'buddy_spawn_main_team_radio',
            type = 'radiobutton',
            caption = {'oarc-join-main-team-radio'},
            state = true
        }
        buddySpawnFlow.add {
            name = 'buddy_spawn_new_team_radio',
            type = 'radiobutton',
            caption = {'oarc-create-own-team-radio'},
            state = false
        }
        buddySpawnFlow.add {
            name = 'buddy_spawn_buddy_team_radio',
            type = 'radiobutton',
            caption = {'oarc-create-buddy-team'},
            state = false
        }
    end
    --if (global.scenario_config.gen_settings.moat_choice_enabled) then
    --    buddySpawnFlow.add{name = "buddy_spawn_moat_option_checkbox",
    --                    type = "checkbox",
    --                    caption={"oarc-moat-option"},
    --                    state=false}
    --end

    -- UtilsGui.AddSpacerLine(buddySpawnFlow)
    buddySpawnFlow.add {
        name = 'buddy_spawn_request_near',
        type = 'button',
        caption = {'oarc-buddy-spawn-near'}
    }
    buddySpawnFlow.add {
        name = 'buddy_spawn_request_far',
        type = 'button',
        caption = {'oarc-buddy-spawn-far'}
    }

    UtilsGui.AddSpacer(buddyGui)
    buddyGui.add {
        name = 'buddy_spawn_cancel',
        type = 'button',
        caption = {'oarc-cancel-return-to-previous'},
        style = 'back_button'
    }

    -- Some final notes
    UtilsGui.AddSpacerLine(buddyGui)
    if (global.max_players > 0) then
        UtilsGui.AddLabel(
            buddyGui,
            'buddy_max_players_lbl1',
            {'oarc-max-players-shared-spawn', global.max_players - 1},
            UtilsGui.my_note_style
        )
    end
    local spawn_distance_notes = {
        'oarc-spawn-dist-notes',
        global.near_min_dist,
        global.near_max_dist,
        global.far_min_dist,
        global.far_max_dist
    }
    UtilsGui.AddLabel(buddyGui, 'note_lbl1', spawn_distance_notes, UtilsGui.my_note_style)
end

-- Handle the gui click of the spawn options
function Public.BuddySpawnOptsGuiClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.player_index]
    local elemName = event.element.name
    local layout

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (player.gui.screen.buddy_spawn_opts == nil) then
        return -- Gui event unrelated to this gui.
    end

    local pgcs = player.gui.screen.buddy_spawn_opts

    local waiting_buddies_dropdown = player.gui.screen.buddy_spawn_opts.spawn_buddy_flow.waiting_buddies_dropdown

    -- Just refresh the buddy list dropdown values only.
    if (elemName == 'refresh_buddy_list') then
        waiting_buddies_dropdown.clear_items()

        for _, buddyName in pairs(global.waitingBuddies) do
            if (player.name ~= buddyName) then
                waiting_buddies_dropdown.add_item(buddyName)
            end
        end
        return
    end

    local classic = pgcs.layout.layout_classic.state
    local new = pgcs.layout.layout_new.state

    if classic then
        layout = 'classic'
    end
    if new then
        layout = 'new'
    end

    -- Handle the cancel button to exit this menu
    if (elemName == 'buddy_spawn_cancel') then
        Utils.SendBroadcastMsg({'oarc-not-looking-for-buddy', player.name})
        player.gui.screen.buddy_spawn_opts.destroy()
        Public.DisplaySpawnOptions(player)

        -- Remove them from the buddy list when they cancel
        for i = #global.waitingBuddies, 1, -1 do
            local name = global.waitingBuddies[i]
            if (name == player.name) then
                table.remove(global.waitingBuddies, i)
            end
        end
    end

    local joinMainTeamRadio, joinOwnTeamRadio, joinBuddyTeamRadio, moatChoice = false
    local buddyChoice = nil

    -- Handle the spawn request button clicks
    if ((elemName == 'buddy_spawn_request_near') or (elemName == 'buddy_spawn_request_far')) then
        local buddySpawnGui = player.gui.screen.buddy_spawn_opts.spawn_buddy_flow

        local dropDownIndex = buddySpawnGui.waiting_buddies_dropdown.selected_index
        if ((dropDownIndex > 0) and (dropDownIndex <= #buddySpawnGui.waiting_buddies_dropdown.items)) then
            buddyChoice = buddySpawnGui.waiting_buddies_dropdown.get_item(dropDownIndex)
        else
            player.print({'oarc-invalid-buddy'})
            return
        end

        local buddyIsStillWaiting = false
        for _, buddyName in pairs(global.waitingBuddies) do
            if (buddyChoice == buddyName) then
                if (game.players[buddyChoice]) then
                    buddyIsStillWaiting = true
                end
                break
            end
        end
        if (not buddyIsStillWaiting) then
            player.print({'oarc-buddy-not-avail'})
            player.gui.screen.buddy_spawn_opts.destroy()
            Public.DisplayBuddySpawnOptions(player)
            return
        end

        if (global.enable_separate_teams) then
            joinMainTeamRadio = buddySpawnGui.buddy_spawn_main_team_radio.state
            joinOwnTeamRadio = buddySpawnGui.buddy_spawn_new_team_radio.state
            joinBuddyTeamRadio = buddySpawnGui.buddy_spawn_buddy_team_radio.state
        else
            joinMainTeamRadio = true
            joinOwnTeamRadio = false
            joinBuddyTeamRadio = false
        end
        --if (global.scenario_config.gen_settings.moat_choice_enabled) then
        --    moatChoice =  buddySpawnGui.buddy_spawn_moat_option_checkbox.state
        --end

        -- Save the chosen spawn options somewhere for later use.
        global.buddySpawnOptions[player.name] = {
            joinMainTeamRadio = joinMainTeamRadio,
            joinOwnTeamRadio = joinOwnTeamRadio,
            joinBuddyTeamRadio = joinBuddyTeamRadio,
            layout = layout,
            moatChoice = moatChoice,
            buddyChoice = buddyChoice,
            distChoice = elemName
        }

        player.gui.screen.buddy_spawn_opts.destroy()

        -- Display prompts to the players
        Public.DisplayBuddySpawnWaitMenu(player)
        Public.DisplayBuddySpawnRequestMenu(game.players[buddyChoice], player.name)
        if (game.players[buddyChoice].gui.screen.buddy_spawn_opts ~= nil) then
            game.players[buddyChoice].gui.screen.buddy_spawn_opts.destroy()
        end

        -- Remove them from the buddy list while they make up their minds.
        for i = #global.waitingBuddies, 1, -1 do
            local name = global.waitingBuddies[i]
            if ((name == player.name) or (name == buddyChoice)) then
                table.remove(global.waitingBuddies, i)
            end
        end
    else
        return -- Do nothing, no valid element item was clicked.
    end
end

function Public.DisplayBuddySpawnWaitMenu(player)
    local sGui =
        player.gui.screen.add {
        name = 'buddy_wait_menu',
        type = 'frame',
        direction = 'vertical',
        caption = {'oarc-waiting-for-buddy'},
        style = main_style
    }
    sGui.auto_center = true
    sGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    sGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Warnings and explanations...
    UtilsGui.AddLabel(sGui, 'warning_lbl1', {'oarc-wait-buddy-select-yes'}, UtilsGui.my_warning_style)
    UtilsGui.AddSpacer(sGui)
    sGui.add {
        name = 'cancel_buddy_wait_menu',
        type = 'button',
        caption = {'oarc-cancel-return-to-previous'}
    }
end

-- Handle the gui click of the buddy wait menu
function Public.BuddySpawnWaitMenuClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.player_index]
    local elemName = event.element.name

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (player.gui.screen.buddy_wait_menu == nil) then
        return -- Gui event unrelated to this gui.
    end

    -- Check if player is cancelling the request.
    if (elemName == 'cancel_buddy_wait_menu') then
        player.gui.screen.buddy_wait_menu.destroy()
        Public.DisplaySpawnOptions(player)

        local buddy = game.players[global.buddySpawnOptions[player.name].buddyChoice]

        if (buddy.gui.screen.buddy_request_menu ~= nil) then
            buddy.gui.screen.buddy_request_menu.destroy()
        end
        if (buddy.gui.screen.buddy_spawn ~= nil) then
            buddy.gui.screen.buddy_spawn_opts.destroy()
        end
        Public.DisplaySpawnOptions(buddy)

        buddy.print({'oarc-buddy-cancel-request', player.name})
    end
end

function Public.DisplayBuddySpawnRequestMenu(player, requestingBuddyName)
    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    local sGui =
        player.gui.screen.add {
        name = 'buddy_request_menu',
        type = 'frame',
        direction = 'vertical',
        caption = 'Buddy Request!',
        style = main_style
    }
    sGui.auto_center = true
    sGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    sGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Warnings and explanations...
    UtilsGui.AddLabel(sGui, 'warning_lbl1', {'oarc-buddy-requesting-from-you', requestingBuddyName}, UtilsGui.my_warning_style)

    local teamText = 'error!'
    if (global.buddySpawnOptions[requestingBuddyName].joinMainTeamRadio) then
        teamText = {'oarc-buddy-txt-main-team'}
    elseif (global.buddySpawnOptions[requestingBuddyName].joinOwnTeamRadio) then
        teamText = {'oarc-buddy-txt-new-teams'}
    elseif (global.buddySpawnOptions[requestingBuddyName].joinBuddyTeamRadio) then
        teamText = {'oarc-buddy-txt-buddy-team'}
    end

    local moatText = ' '
    if (global.buddySpawnOptions[requestingBuddyName].moatChoice) then
        moatText = {'oarc-buddy-txt-moat'}
    end

    local distText = 'error!'
    if (global.buddySpawnOptions[requestingBuddyName].distChoice == 'buddy_spawn_request_near') then
        distText = {'oarc-buddy-txt-near'}
    elseif (global.buddySpawnOptions[requestingBuddyName].distChoice == 'buddy_spawn_request_far') then
        distText = {'oarc-buddy-txt-far'}
    end

    local requestText = {
        '',
        requestingBuddyName,
        {'oarc-buddy-txt-would-like'},
        teamText,
        {'oarc-buddy-txt-next-to-you'},
        moatText,
        distText
    }
    UtilsGui.AddLabel(sGui, 'note_lbl1', requestText, UtilsGui.my_warning_style)
    UtilsGui.AddSpacer(sGui)

    sGui.add {
        name = 'accept_buddy_request',
        type = 'button',
        caption = {'oarc-accept'}
    }
    sGui.add {
        name = 'decline_buddy_request',
        type = 'button',
        caption = {'oarc-reject'}
    }
end

-- Handle the gui click of the buddy request menu
function Public.BuddySpawnRequestMenuClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.player_index]
    local elemName = event.element.name
    local requesterName = nil
    local requesterOptions = {}

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (player.gui.screen.buddy_request_menu == nil) then
        return -- Gui event unrelated to this gui.
    end

    -- Check if it's a button press and lookup the matching buddy info
    if ((elemName == 'accept_buddy_request') or (elemName == 'decline_buddy_request')) then
        for name, opts in pairs(global.buddySpawnOptions) do
            if (opts.buddyChoice == player.name) then
                requesterName = name
                requesterOptions = opts
            end
        end

        if (requesterName == nil) then
            player.print('Error! Invalid buddy info...')
            log('Error! Invalid buddy info...')

            player.gui.screen.buddy_request_menu.destroy()
            Public.DisplaySpawnOptions(player)
        end
    else
        return -- Not a button click
    end

    -- Handle player accepted
    if (elemName == 'accept_buddy_request') then
        if (game.players[requesterName].gui.screen.buddy_wait_menu ~= nil) then
            game.players[requesterName].gui.screen.buddy_wait_menu.destroy()
        end
        if (player.gui.screen.buddy_request_menu ~= nil) then
            player.gui.screen.buddy_request_menu.destroy()
        end

        -- Create a new spawn point
        local newSpawn = {x = 0, y = 0}

        -- Create a new force for each player if they chose that option
        if requesterOptions.joinOwnTeamRadio then
            -- Create a new force for the combined players if they chose that option
            local newForce = Public.CreatePlayerCustomForce(player)
            local buddyForce = Public.CreatePlayerCustomForce(game.players[requesterName])
        elseif requesterOptions.joinBuddyTeamRadio then
            local buddyForce = Public.CreatePlayerCustomForce(game.players[requesterName])
            player.force = buddyForce
        end

        -- Find coordinates of a good place to spawn
        if (requesterOptions.distChoice == 'buddy_spawn_request_far') then
            newSpawn = Utils.FindUngeneratedCoordinates(global.far_min_dist, global.far_max_dist, player.surface)
        elseif (requesterOptions.distChoice == 'buddy_spawn_request_near') then
            newSpawn = Utils.FindUngeneratedCoordinates(global.near_min_dist, global.near_max_dist, player.surface)
        end

        -- If that fails, find a random map edge in a rand direction.
        if ((newSpawn.x == 0) and (newSpawn.x == 0)) then
            newSpawn = Utils.FindMapEdge(Utils.GetRandomVector(), player.surface)
            log('Resorting to find map edge! x=' .. newSpawn.x .. ',y=' .. newSpawn.y)
        end

        -- Create that spawn in the global vars
        global.buddySpawn = {x = 0, y = 0}
        if (requesterOptions.moatChoice) then
            global.buddySpawn = {
                x = newSpawn.x + (global.scenario_config.gen_settings.land_area_tiles * 2) + 10,
                y = newSpawn.y
            }
        else
            global.buddySpawn = {
                x = newSpawn.x + (global.scenario_config.gen_settings.land_area_tiles * 2),
                y = newSpawn.y
            }
        end
        Public.ChangePlayerSpawn(player, newSpawn)
        Public.ChangePlayerSpawn(game.players[requesterName], global.buddySpawn)
        local this = true
        -- Send the player there
        Public.QueuePlayerForDelayedSpawn(player.name, newSpawn, requesterOptions.layout, requesterOptions.moatChoice, false, this)
        Public.QueuePlayerForDelayedSpawn(
            requesterName,
            global.buddySpawn,
            requesterOptions.layout,
            requesterOptions.moatChoice,
            false,
            this
        )
        Utils.SendBroadcastMsg(requesterName .. ' and ' .. player.name .. ' are joining the game together!')

        -- Unlock spawn control gui tab
        Gui.set_tab(player, 'Spawn Controls', true)
        Gui.set_tab(game.players[requesterName], 'Spawn Controls', true)
    --game.permissions.get_group("Default").add_player(player)
    --game.permissions.get_group("Default").add_player(requesterName)
    end

    -- Check if player is cancelling the request.
    if (elemName == 'decline_buddy_request') then
        player.gui.screen.buddy_request_menu.destroy()
        Public.DisplaySpawnOptions(player)

        local requesterBuddy = game.players[requesterName]

        if (requesterBuddy.gui.screen.buddy_wait_menu ~= nil) then
            requesterBuddy.gui.screen.buddy_wait_menu.destroy()
        end
        if (requesterBuddy.gui.screen.buddy_spawn ~= nil) then
            requesterBuddy.gui.screen.buddy_spawn_opts.destroy()
        end
        Public.DisplaySpawnOptions(requesterBuddy)

        requesterBuddy.print({'oarc-buddy-declined', player.name})
    end
end

function Public.DisplayPleaseWaitForSpawnDialog(player, delay_seconds)
    local pleaseWaitGui =
        player.gui.screen.add {
        name = 'wait_for_spawn_dialog',
        type = 'frame',
        direction = 'vertical',
        caption = {'oarc-spawn-wait'}
    }
    pleaseWaitGui.auto_center = true
    pleaseWaitGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    pleaseWaitGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Warnings and explanations...
    local wait_warning_text = {'oarc-wait-text', delay_seconds}

    UtilsGui.AddLabel(pleaseWaitGui, 'warning_lbl1', wait_warning_text, UtilsGui.my_warning_style)
end

Gui.tabs['Spawn Controls'] = Public.CreateSpawnCtrlGuiTab

return Public
