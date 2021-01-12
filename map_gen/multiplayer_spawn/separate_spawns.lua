local Utils = require 'map_gen.multiplayer_spawn.oarc_utils'
local UtilsGui = require 'map_gen.multiplayer_spawn.oarc_gui_utils'
local Silo = require 'map_gen.multiplayer_spawn.frontier_silo'
local MT = require 'map_gen.multiplayer_spawn.table'
local Surface = require 'utils.surface'
local Gui = require 'utils.gui.core'
require 'map_gen.multiplayer_spawn.config'

local Public = {}

local main_style = 'changelog_subheader_frame'
local insert = table.insert

--------------------------------------------------------------------------------
-- EVENT RELATED FUNCTIONS
--------------------------------------------------------------------------------

-- When a new player is created, present the spawn options
-- Assign them to the main force so they can communicate with the team
-- without shouting.
function Public.SeparateSpawnsPlayerCreated(player_index)
    local player = game.players[player_index]
    local this = MT.get()

    -- Make sure spawn control tab is disabled
    Gui.set_tab(player, 'Spawn Controls', false)

    -- This checks if they have just joined the server.
    -- No assigned force yet.
    if (player.force.name ~= 'player') then
        Public.FindUnusedSpawns(player, false)
    end

    if game.forces[player.name] then
        game.merge_forces(player.name, this.main_force_name)
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

    if player.connected then
        if player.character and player.character.valid then
            player.character.active = false
        else
            player.set_controller({type = defines.controllers.god})
            player.create_character()
            player.character.active = false
        end
    end

    player.force = this.main_force_name
    Public.DisplayWelcomeTextGui(player)

    return this.main_force_name
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
    local this = MT.get()

    -- Modify enemies first.
    if this.modded_enemy then
        Utils.DowngradeWormsDistanceBasedOnChunkGenerate(event)
    end

    -- This handles chunk generation near player spawns
    -- If it is near a player spawn, it does a few things like make the area
    -- safe and provide a guaranteed area of land and water tiles.
    Public.SetupAndClearSpawnAreas(surface, chunkArea)
end

local function remove_area(pos, chunk_radius)
    local data = {}
    local c_pos = Utils.GetChunkPosFromTilePos(pos)
    for i = -chunk_radius, chunk_radius do
        for k = -chunk_radius, chunk_radius do
            local x = c_pos.x + i
            local y = c_pos.y + k
            insert(data, {pos = {x = x, y = y}})
        end
    end

    local function init_remove()
        local surface_name = Surface.get_surface_name()
        while (#data > 0) do
            local c_remove = table.remove(data)
            local remove_pos = c_remove.pos
            game.surfaces[surface_name].delete_chunk(remove_pos)
        end
    end

    init_remove()
end

-- Call this if a player leaves the game or is reset
function Public.FindUnusedSpawns(player, remove_player)
    local surface_name = Surface.get_surface_name()
    if not player then
        log('ERROR - FindUnusedSpawns on NIL Player!')
        return
    end

    local this = MT.get()

    if (player.online_time < (this.min_online * this.ticks_per_minute)) then
        -- If this player is staying in the game, lets make sure we don't delete them
        -- along with the map chunks being cleared.
        player.teleport({x = 0, y = 0}, surface_name)
        if player and player.character and player.character.valid then
            player.character.active = true
        end

        -- Clear out global variables for that player
        if (this.playerSpawns[player.name] ~= nil) then
            this.playerSpawns[player.name] = nil
        end

        -- Remove them from the delayed spawn queue if they are in it
        for i = #this.delayedSpawns, 1, -1 do
            local delayedSpawn = this.delayedSpawns[i]

            if (player.name == delayedSpawn.playerName) then
                if (delayedSpawn.vanilla) then
                    log('Returning a vanilla spawn back to available.')
                    insert(this.vanillaSpawns, {x = delayedSpawn.pos.x, y = delayedSpawn.pos.y})
                end

                table.remove(this.delayedSpawns, i)
                log('Removing player from delayed spawn queue: ' .. player.name)
            end
        end

        local surface = game.surfaces[surface_name]

        -- Transfer or remove a shared spawn if player is owner
        if (this.sharedSpawns[player.name] ~= nil) then
            local teamMates = this.sharedSpawns[player.name].players

            if (#teamMates >= 1) then
                local newOwnerName = table.remove(teamMates)
                Public.TransferOwnershipOfSharedSpawn(player.name, newOwnerName)
            else
                this.sharedSpawns[player.name] = nil
            end
        end

        -- If a uniqueSpawn was created for the player, mark it as unused.
        if (this.uniqueSpawns[player.name] ~= nil) then
            local spawnPos = this.uniqueSpawns[player.name].pos

            local area = Utils.GetAreaAroundPos(spawnPos, 50)
            local nearOtherSpawn = false

            for _, e in pairs(surface.find_entities_filtered({area = area})) do
                if e and e.valid and e.name == 'character' and e.player then
                    -- e.player.teleport(surface.find_non_colliding_position('character', e.player.force.get_spawn_position(surface), 3, 0, 5), surface)
                    log("Won't remove base as a player is close to spawn: " .. e.player.name)
                    nearOtherSpawn = true
                end
            end

            -- Check if it was near someone else's base.
            for spawnPlayerName, otherSpawnPos in pairs(this.uniqueSpawns) do
                if ((spawnPlayerName ~= player.name) and (Utils.getDistance(spawnPos, otherSpawnPos.pos) < (this.scenario_config.gen_settings.land_area_tiles * 3))) then
                    log("Won't remove base as it's close to another spawn: " .. spawnPlayerName)
                    nearOtherSpawn = true
                end
            end

            if (this.uniqueSpawns[player.name].vanilla) then
                log('Returning a vanilla spawn back to available.')
                insert(this.vanillaSpawns, {x = spawnPos.x, y = spawnPos.y})
            end

            this.uniqueSpawns[player.name] = nil

            if not nearOtherSpawn then
                log('Removing base: ' .. spawnPos.x .. ',' .. spawnPos.y)
                remove_area(spawnPos, this.check_spawn_ungenerated_chunk_radius + 5)
            end
        end

        -- remove that player's cooldown setting
        if (this.playerCooldowns[player.name] ~= nil) then
            this.playerCooldowns[player.name] = nil
        end

        -- Remove from shared spawn player slots (need to search all)
        for _, sharedSpawn in pairs(this.sharedSpawns) do
            for key, playerName in pairs(sharedSpawn.players) do
                if (player.name == playerName) then
                    sharedSpawn.players[key] = nil
                end
            end
        end

        -- Remove a force if this player created it and they are the only one on it
        if ((#player.force.players <= 1) and (player.force.name ~= this.main_force_name) and (player.force.name ~= 'player')) then
            game.merge_forces(player.force, this.main_force_name)
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
    local this = MT.get()

    for _, spawn in pairs(this.uniqueSpawns) do
        -- Create a bunch of useful area and position variables
        local landArea = Utils.GetAreaAroundPos(spawn.pos, this.scenario_config.gen_settings.land_area_tiles + this.chunk_size)
        local safeArea = Utils.GetAreaAroundPos(spawn.pos, this.scenario_config.safe_area.safe_radius)
        local warningArea = Utils.GetAreaAroundPos(spawn.pos, this.scenario_config.safe_area.warn_radius)
        local reducedArea = Utils.GetAreaAroundPos(spawn.pos, this.scenario_config.safe_area.danger_radius)
        local chunkAreaCenter = {
            x = chunkArea.left_top.x + (this.chunk_size / 2),
            y = chunkArea.left_top.y + (this.chunk_size / 2)
        }

        -- Make chunks near a spawn safe by removing enemies
        if Utils.CheckIfInArea(chunkAreaCenter, safeArea) then
            -- Create a warning area with heavily reduced enemies
            Utils.RemoveAliensInArea(surface, chunkArea)
        elseif Utils.CheckIfInArea(chunkAreaCenter, warningArea) then
            -- Create a third area with moderatly reduced enemies
            Utils.ReduceAliensInArea(surface, chunkArea, this.scenario_config.safe_area.warn_reduction)
            -- DowngradeWormsInArea(surface, chunkArea, 100, 100, 100)
            Utils.RemoveWormsInArea(surface, chunkArea, false, true, true, true) -- remove all non-small worms.
        elseif Utils.CheckIfInArea(chunkAreaCenter, reducedArea) then
            Utils.ReduceAliensInArea(surface, chunkArea, this.scenario_config.safe_area.danger_reduction)
            -- DowngradeWormsInArea(surface, chunkArea, 50, 100, 100)
            Utils.RemoveWormsInArea(surface, chunkArea, false, false, true, true) -- remove all huge/behemoth worms.
        end

        if (not spawn.vanilla) then
            -- If the chunk is within the main land area, then clear trees/resources
            -- and create the land spawn areas (guaranteed land with a circle of trees)
            if Utils.CheckIfInArea(chunkAreaCenter, landArea) then
                if spawn.buddy_spawn then
                    -- Remove trees/resources inside the spawn area
                    if (spawn.layout == 'circle_shape') then
                        Utils.RemoveInCircle(surface, chunkArea, 'tree', spawn.pos, this.scenario_config.gen_settings.land_area_tiles)
                    else
                        Utils.RemoveInCircle(surface, chunkArea, 'tree', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 5)
                    end
                    Utils.RemoveInCircle(surface, chunkArea, 'resource', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 5)
                    Utils.RemoveInCircle(surface, chunkArea, 'cliff', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'market', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'container', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'simple-entity', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveDecorationsArea(surface, chunkArea)
                else
                    -- Remove trees/resources inside the spawn area
                    Utils.RemoveInCircle(surface, chunkArea, 'tree', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'resource', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'cliff', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'market', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'container', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveInCircle(surface, chunkArea, 'simple-entity', spawn.pos, this.scenario_config.gen_settings.land_area_tiles + 50)
                    Utils.RemoveDecorationsArea(surface, chunkArea)
                end

                -- local fill_tile = 'dirt-' .. math.random(1, 6)
                local fill_tile = 'tutorial-grid'

                if (spawn.layout == 'circle_shape') then
                    Utils.CreateCropCircle(surface, spawn.pos, chunkArea, this.scenario_config.gen_settings.land_area_tiles, fill_tile)
                    if (spawn.moat) then
                        Utils.CreateMoat(surface, spawn.pos, chunkArea, this.scenario_config.gen_settings.land_area_tiles, fill_tile)
                    end
                end
                if (spawn.layout == 'square_shape') then
                    Utils.CreateCropSquare(surface, spawn.pos, chunkArea, this.chunk_size * 3, fill_tile)
                    if (spawn.moat) then
                        Utils.CreateMoatSquare(surface, spawn.pos, chunkArea, this.scenario_config.gen_settings.land_area_tiles, fill_tile)
                    end
                end
            end
        end
    end
end

-- Same as GetClosestPosFromTable but specific to this.uniqueSpawns
function Public.GetClosestUniqueSpawn(pos)
    local closest_dist = nil
    local closest_key = nil
    local this = MT.get()

    for k, s in pairs(this.uniqueSpawns) do
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

    return this.uniqueSpawns[closest_key]
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

    local this = MT.get()

    -- No enemies inside safe radius!
    if (Utils.getDistance(enemy_pos, closest_spawn.pos) < this.scenario_config.safe_area.safe_radius) then
        -- Warn distance is all SMALL only.
        event.entity.destroy()
    elseif (Utils.getDistance(enemy_pos, closest_spawn.pos) < this.scenario_config.safe_area.warn_radius) then
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
    elseif (Utils.getDistance(enemy_pos, closest_spawn.pos) < this.scenario_config.safe_area.danger_radius) then
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
    local this = MT.get()

    local g_res = this.scenario_config.resource_tiles_new
    local g_pos = this.scenario_config.pos

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
    for p_name, p_data in pairs(this.scenario_config.resource_patches_new) do
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
    local this = MT.get()

    local rand_settings = this.scenario_config.resource_rand_pos_settings

    -- Generate all resource tile patches
    if (not rand_settings.enabled) then
        for t_name, t_data in pairs(this.scenario_config.resource_tiles_classic) do
            local p = {x = pos.x + t_data.x_offset, y = pos.y + t_data.y_offset}
            Utils.GenerateResourcePatch(surface, t_name, t_data.size, p, t_data.amount)
        end
    else
        -- Create list of resource tiles
        local r_list = {}
        for k, _ in pairs(this.scenario_config.resource_tiles_classic) do
            if (k ~= '') then
                insert(r_list, k)
            end
        end
        local shuffled_list = Utils.shuffle(r_list)

        -- This places resources in a semi-circle
        -- Tweak in config.lua
        local angle_offset = rand_settings.angle_offset
        local num_resources = Utils.TableLength(this.scenario_config.resource_tiles_classic)
        local theta = ((rand_settings.angle_final - rand_settings.angle_offset) / num_resources)
        local count = 0

        for _, k_name in pairs(shuffled_list) do
            local angle = (theta * count) + angle_offset

            local tx = (rand_settings.radius * math.cos(angle)) + pos.x
            local ty = (rand_settings.radius * math.sin(angle)) + pos.y

            local p = {x = math.floor(tx), y = math.floor(ty)}
            Utils.GenerateResourcePatch(surface, k_name, this.scenario_config.resource_tiles_classic[k_name].size, p, this.scenario_config.resource_tiles_classic[k_name].amount)
            count = count + 1
        end
    end

    -- Generate special resource patches (oil)
    for p_name, p_data in pairs(this.scenario_config.resource_patches_classic) do
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
    local this = MT.get()

    this.sharedSpawns[player.name] = {
        openAccess = false,
        AlwaysAccess = false,
        position = this.playerSpawns[player.name],
        players = {}
    }
end

function Public.TransferOwnershipOfSharedSpawn(prevOwnerName, newOwnerName)
    local this = MT.get()

    -- Transfer the shared spawn global
    this.sharedSpawns[newOwnerName] = this.sharedSpawns[prevOwnerName]
    this.sharedSpawns[newOwnerName].openAccess = false
    this.sharedSpawns[newOwnerName].AlwaysAccess = false
    this.sharedSpawns[prevOwnerName] = nil

    -- Transfer the unique spawn global
    this.uniqueSpawns[newOwnerName] = this.uniqueSpawns[prevOwnerName]
    this.uniqueSpawns[prevOwnerName] = nil

    game.players[newOwnerName].print('You have been given ownership of this base!')
end

-- Returns the number of players currently online at the shared spawn
function Public.GetOnlinePlayersAtSharedSpawn(ownerName)
    local this = MT.get()

    if (this.sharedSpawns[ownerName] ~= nil) then
        -- Does not count base owner
        local count = 0

        -- For each player in the shared spawn, check if online and add to count.
        for _, player in pairs(game.connected_players) do
            if (ownerName == player.name) then
                count = count + 1
            end

            for _, playerName in pairs(this.sharedSpawns[ownerName].players) do
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
    local this = MT.get()

    local count = 0

    for ownerName, sharedSpawn in pairs(this.sharedSpawns) do
        if (sharedSpawn.openAccess or sharedSpawn.AlwaysAccess and (game.players[ownerName] ~= nil) and game.players[ownerName].connected) then
            if ((this.max_players == 0) or (#this.sharedSpawns[ownerName].players < this.max_players)) then
                count = count + 1
            end
        end
    end

    return count
end

-- Initializes the globals used to track the special spawn and player
-- status information
function Public.InitSpawnGlobalsAndForces()
    local surface_name = Surface.get_surface_name()
    local this = MT.get()

    -- Name a new force to be the default force.
    -- This is what any new player is assigned to when they join, even before they spawn.
    local main_force_name = Public.CreateForce(this.main_force_name)
    main_force_name.set_spawn_position({x = 0, y = 0}, surface_name)
    main_force_name.worker_robots_storage_bonus = 5
    main_force_name.worker_robots_speed_modifier = 2
end

function Public.DoesPlayerHaveCustomSpawn(player)
    local this = MT.get()
    for name, _ in pairs(this.playerSpawns) do
        if (player.name == name) then
            return true
        end
    end
    return false
end

function Public.ChangePlayerSpawn(player, pos)
    local this = MT.get()

    this.playerSpawns[player.name] = pos
    this.playerCooldowns[player.name] = {setRespawn = game.tick}
end

function Public.QueuePlayerForDelayedSpawn(playerName, spawn, classic, moatChoice, vanillaSpawn, own_team, buddy_spawn)
    local this = MT.get()
    if not buddy_spawn then
        buddy_spawn = false
    end

    -- If we get a valid spawn point, setup the area
    if ((spawn.x ~= 0) or (spawn.y ~= 0)) then
        this.uniqueSpawns[playerName] = {
            pos = spawn,
            layout = classic,
            moat = moatChoice,
            vanilla = vanillaSpawn,
            player = playerName,
            own_team = own_team,
            buddy_spawn = buddy_spawn
        }

        local delay_spawn_seconds = 2 * (math.ceil(this.scenario_config.gen_settings.land_area_tiles / this.chunk_size))
        game.players[playerName].surface.request_to_generate_chunks(spawn, 4)
        local delayedTick = game.tick + delay_spawn_seconds * this.ticks_per_second
        insert(
            this.delayedSpawns,
            {
                playerName = playerName,
                layout = classic,
                pos = spawn,
                moat = moatChoice,
                vanilla = vanillaSpawn,
                delayedTick = delayedTick,
                own_team = own_team,
                buddy_spawn = buddy_spawn
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
    local delayedSpawns = MT.get('delayedSpawns')
    if #delayedSpawns <= 0 then
        return
    end

    local this = MT.get()

    if ((game.tick % (30)) == 1) then
        if ((this.delayedSpawns ~= nil) and (#this.delayedSpawns > 0)) then
            for i = #this.delayedSpawns, 1, -1 do
                local delayedSpawn = this.delayedSpawns[i]

                if (delayedSpawn.delayedTick < game.tick) then
                    -- TODO, add check here for if chunks around spawn are generated surface.is_chunk_generated(chunkPos)
                    if (game.players[delayedSpawn.playerName] ~= nil) then
                        if not game.players[delayedSpawn.playerName].connected then
                            table.remove(this.delayedSpawns, i)
                            return
                        else
                            Public.SendPlayerToNewSpawnAndCreateIt(delayedSpawn)
                            table.remove(this.delayedSpawns, i)
                        end
                    end
                end
            end
        end
    end
end

function Public.SendPlayerToNewSpawnAndCreateIt(delayedSpawn)
    local this = MT.get()
    -- DOUBLE CHECK and make sure the area is super safe.
    local surface_name = Surface.get_surface_name()
    Utils.ClearNearbyEnemies(delayedSpawn.pos, this.scenario_config.safe_area.safe_radius, game.surfaces[surface_name])
    local water_data

    if delayedSpawn.layout == 'circle_shape' then
        water_data = this.scenario_config.water_classic
    elseif delayedSpawn.layout == 'square_shape' then
        water_data = this.scenario_config.water_new
    end
    local player = game.players[delayedSpawn.playerName]

    if (not delayedSpawn.vanilla) then
        if delayedSpawn.layout == 'circle_shape' then
            Utils.GivePlayerStarterItems(player)
            Utils.CreateWaterStrip(game.surfaces[surface_name], {x = delayedSpawn.pos.x + water_data.x_offset, y = delayedSpawn.pos.y + water_data.y_offset}, water_data.length)
            Utils.CreateWaterStrip(game.surfaces[surface_name], {x = delayedSpawn.pos.x + water_data.x_offset, y = delayedSpawn.pos.y + water_data.y_offset + 1}, water_data.length)
            Public.GenerateStartingResources_Classic(game.surfaces[surface_name], delayedSpawn.pos)
        elseif delayedSpawn.layout == 'square_shape' then
            Utils.GivePlayerStarterItems(player)
            Utils.CreateWaterStrip(game.surfaces[surface_name], {x = delayedSpawn.pos.x + water_data.x_offset, y = delayedSpawn.pos.y + water_data.y_offset}, water_data.length)
            Utils.CreateWaterStrip(game.surfaces[surface_name], {x = delayedSpawn.pos.x + water_data.x_offset, y = delayedSpawn.pos.y + water_data.y_offset + 1}, water_data.length)
            Public.GenerateStartingResources_New(game.surfaces[surface_name], delayedSpawn.pos)
        end
    end

    Gui.toggle_visibility(player)

    -- Send the player to that position
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

    local pos = player.surface.find_non_colliding_position('character', delayedSpawn.pos, 10, 5)
    if not pos then
        pos = player.surface.find_non_colliding_position('character', delayedSpawn.pos, 20, 5)
    end

    player.teleport(pos, surface_name)

    if player and player.character and player.character.valid then
        player.character.active = true
    end

    -- Chart the area.
    --Utils.ChartArea(player.force, delayedSpawn.pos, math.ceil(this.scenario_config.gen_settings.land_area_tiles/this.chunk_size), player.surface)

    if (player.gui.screen.wait_for_spawn_dialog ~= nil) then
        player.gui.screen.wait_for_spawn_dialog.destroy()
    end
end

function Public.SendPlayerToSpawn(player)
    local pos
    local this = MT.get()

    local dest = this.playerSpawns[player.name]
    if not dest then
        pos = player.surface.find_non_colliding_position('character', {x = 0, y = 0}, 3, 0, 5)
    else
        pos = player.surface.find_non_colliding_position('character', dest, 3, 0, 5)
    end
    if (Public.DoesPlayerHaveCustomSpawn(player)) then
        if pos then
            player.teleport(pos, player.surface)
        else
            player.teleport(this.playerSpawns[player.name], player.surface)
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
    local this = MT.get()
    local numSpawns = Utils.TableLength(this.uniqueSpawns)
    local rndSpawn = math.random(0, numSpawns)
    local counter = 0

    local surface_name = Surface.get_surface_name()

    if (rndSpawn == 0) then
        player.teleport(game.forces[this.main_force_name].get_spawn_position(surface_name), surface_name)
        if player and player.character and player.character.valid then
            player.character.active = true
        end
    else
        counter = counter + 1
        for _, spawn in pairs(this.uniqueSpawns) do
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
    local newForce = nil
    local surface_name = Surface.get_surface_name()
    local this = MT.get()

    -- Check if force already exists
    if (game.forces[force_name] ~= nil) then
        -- Create a new force
        log('Force already exists!')
        return game.forces[this.main_force_name]
    elseif (Utils.TableLength(game.forces) < this.max_forces) then
        newForce = game.create_force(force_name)
        if this.enable_shared_team_vision then
            newForce.share_chart = true
        end
        if this.enable_r_queue then
            newForce.research_queue_enabled = true
        end
        newForce.worker_robots_storage_bonus = 5
        newForce.worker_robots_speed_modifier = 2
        -- Chart silo areas if necessary
        if this.frontier_rocket_silo_mode and this.enable_silo_vision then
            Silo.ChartRocketSiloAreas(game.surfaces[surface_name], newForce)
        end

        Utils.SetCeaseFireBetweenAllForces()

        newForce.friendly_fire = true
        newForce.zoom_to_world_deconstruction_planner_enabled = false
        if (this.enable_antigrief) then
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
    local this = MT.get()

    if (this.vanillaSpawns == nil) then
        this.vanillaSpawns = {}
    end

    -- This should give me points centered around 0,0 I think.
    for i = -sqrt_half, sqrt_half, 1 do
        for j = -sqrt_half, sqrt_half, 1 do
            if (i ~= 0 or j ~= 0) then -- EXCEPT don't put 0,0
                insert(points, {x = i * spacing, y = j * spacing})
                insert(this.vanillaSpawns, {x = i * spacing, y = j * spacing})
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
    local this = MT.get()

    for k, v in pairs(this.vanillaSpawns) do
        -- Check if chunks nearby are not generated.
        local chunk_pos = Utils.GetChunkPosFromTilePos(v)
        if Utils.IsChunkAreaUngenerated(chunk_pos, this.check_spawn_ungenerated_chunk_radius + 15, surface) then
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
            table.remove(this.vanillaSpawns, k)
        end
    end

    local spawn_pos = {x = 0, y = 0}
    if ((best_key ~= nil) and (this.vanillaSpawns[best_key] ~= nil)) then
        spawn_pos.x = this.vanillaSpawns[best_key].x
        spawn_pos.y = this.vanillaSpawns[best_key].y
        table.remove(this.vanillaSpawns, best_key)
    end
    log('Found unused vanilla spawn: x=' .. spawn_pos.x .. ',y=' .. spawn_pos.y)
    return spawn_pos
end

function Public.ValidateVanillaSpawns(surface)
    local this = MT.get()
    for k, v in pairs(this.vanillaSpawns) do
        -- Check if chunks nearby are not generated.
        local chunk_pos = Utils.GetChunkPosFromTilePos(v)
        if not Utils.IsChunkAreaUngenerated(chunk_pos, this.check_spawn_ungenerated_chunk_radius + 15, surface) then
            log('Removing vanilla spawn due to chunks generated: x=' .. v.x .. ',y=' .. v.y)
            table.remove(this.vanillaSpawns, k)
        end
    end
end

local SPAWN_GUI_MAX_WIDTH = 500
local SPAWN_GUI_MAX_HEIGHT = 1000

function Public.DisplayWelcomeTextGui(player)
    if
        ((player.gui.screen['welcome_msg'] ~= nil) or (player.gui.screen['spawn_opts'] ~= nil) or (player.gui.screen['shared_spawn_opts'] ~= nil) or
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

    local this = MT.get()

    local wGui =
        player.gui.screen.add {
        name = 'welcome_msg',
        type = 'frame',
        direction = 'vertical',
        caption = this.welcome_msg_title,
        style = main_style
    }
    Gui.ignored_visibility(wGui.name)
    wGui.auto_center = true
    wGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    wGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Start with server message.
    UtilsGui.AddLabel(wGui, 'server_msg_lbl1', this.server_msg, UtilsGui.my_label_style)
    UtilsGui.AddSpacer(wGui)

    -- Informational message about the scenario
    UtilsGui.AddLabel(wGui, 'scenario_info_msg_lbl1', this.scenario_info_msg, UtilsGui.my_label_style)
    UtilsGui.AddSpacer(wGui)

    -- Warning about spawn creation time
    UtilsGui.AddLabel(wGui, 'spawn_time_msg_lbl1', '', UtilsGui.my_warning_style)

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

    if (player.gui.screen.welcome_msg ~= nil) then
        player.gui.screen.welcome_msg.destroy()
    end

    if (player.gui.screen.spawn_opts ~= nil) then
        player.gui.screen.spawn_opts.destroy()
    end

    local elem =
        player.gui.screen.add {
        name = 'spawn_opts',
        type = 'frame',
        direction = 'vertical',
        caption = {'oarc-spawn-options'},
        style = main_style
    }
    Gui.ignored_visibility(elem.name)
    local sGui = player.gui.screen.spawn_opts
    sGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    sGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT
    sGui.auto_center = true

    UtilsGui.AddLabel(sGui, 'warning_lbl1', 'You can choose between the classic layout or the new one.', UtilsGui.my_label_style)

    local sTable = sGui.add {type = 'table', column_count = 3, name = 'upper_table'}
    local layout_flow = sTable.add {name = 'layout', type = 'frame', direction = 'vertical', style = 'bordered_frame'}

    UtilsGui.AddLabel(layout_flow, 'normal_spawn_lbl1', {'oarc-layout'}, UtilsGui.my_label_style)
    layout_flow.add {
        name = 'layout_circle',
        type = 'radiobutton',
        caption = {'oarc-layout-circle'},
        state = false,
        tooltip = 'The classic layout, a circle.'
    }
    layout_flow.add {
        name = 'layout_square',
        type = 'radiobutton',
        caption = {'oarc-layout-square'},
        state = true,
        tooltip = 'Rectangle-alike shape.'
    }

    local soloSpawnFlow =
        sGui.add {
        name = 'spawn_solo_flow',
        type = 'frame',
        direction = 'vertical',
        style = 'bordered_frame'
    }

    local this = MT.get()

    if this.enable_default_spawn then
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
    if (this.enable_separate_teams) then
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
    if (this.scenario_config.gen_settings.moat_choice_enabled and not this.enable_vanilla_spawns) then
        soloSpawnFlow.add {
            name = 'isolated_spawn_moat_option_checkbox',
            type = 'checkbox',
            caption = {'oarc-moat-option'},
            state = false
        }
    end
    -- if (this.enable_vanilla_spawns and (#this.vanillaSpawns > 0)) then
    --     soloSpawnFlow.add{name = "isolated_spawn_vanilla_option_checkbox",
    --                     type = "checkbox",
    --                     caption="Use a pre-set vanilla spawn point. " .. #this.vanillaSpawns .. " available.",
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

    if (this.enable_vanilla_spawns) then
        UtilsGui.AddLabel(soloSpawnFlow, 'isolated_spawn_lbl1', {'oarc-starting-area-vanilla'}, UtilsGui.my_label_style)
        UtilsGui.AddLabel(soloSpawnFlow, 'vanilla_spawn_lbl2', {'oarc-vanilla-spawns-available', #this.vanillaSpawns}, UtilsGui.my_label_style)
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
    if this.enable_shared_spawns then
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
    if (not this.enable_vanilla_spawns) then
        if this.enable_shared_spawns and this.enable_buddy_spawn then
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
    if (this.max_players > 0) then
        UtilsGui.AddLabel(sGui, 'max_players_lbl2', {'oarc-max-players-shared-spawn', this.max_players - 1}, UtilsGui.my_note_style)
    end
    --local spawn_distance_notes={"oarc-spawn-dist-notes", this.near_min_dist, this.near_max_dist, this.far_min_dist, this.far_max_dist}
    --UtilsGui.AddLabel(sGui, "note_lbl1", spawn_distance_notes, UtilsGui.my_note_style)
end

-- This just updates the radio buttons/checkboxes when players click them.
function Public.SpawnOptsRadioSelect(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local element = event.element
    local elemName = element.name

    if (elemName == 'isolated_spawn_main_team_radio') then
        element.parent.isolated_spawn_new_team_radio.state = false
    elseif (elemName == 'isolated_spawn_new_team_radio') then
        element.parent.isolated_spawn_main_team_radio.state = false
    end

    local layout_elem = element.parent

    if (elemName == 'layout_square') then
        if layout_elem.layout_circle then
            layout_elem.layout_circle.state = false
        end
    elseif (elemName == 'layout_circle') then
        if layout_elem.layout_square then
            layout_elem.layout_square.state = false
        end
    end

    if (elemName == 'buddy_spawn_main_team_radio') then
        element.parent.buddy_spawn_new_team_radio.state = false
        element.parent.buddy_spawn_buddy_team_radio.state = false
    elseif (elemName == 'buddy_spawn_new_team_radio') then
        element.parent.buddy_spawn_main_team_radio.state = false
        element.parent.buddy_spawn_buddy_team_radio.state = false
    elseif (elemName == 'buddy_spawn_buddy_team_radio') then
        element.parent.buddy_spawn_main_team_radio.state = false
        element.parent.buddy_spawn_new_team_radio.state = false
    end
end

-- Handle the gui click of the spawn options
function Public.SpawnOptsGuiClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.player_index]
    local elemName = event.element.name
    local layout
    local surface_name = Surface.get_surface_name()

    if not player then
        log('Another gui click happened with no valid player...')
        return
    end

    if (player.gui.screen.spawn_opts == nil) then
        return -- Gui event unrelated to this gui.
    end

    local pgcs = player.gui.screen.spawn_opts

    local circle_shape = pgcs.upper_table.layout.layout_circle.state
    local square_shape = pgcs.upper_table.layout.layout_square.state

    local moatChoice = false

    if circle_shape then
        layout = 'circle_shape'
    end
    if square_shape then
        layout = 'square_shape'
    end

    local this = MT.get()

    -- Check if a valid button on the gui was pressed
    -- and delete the GUI
    if
        ((elemName == 'default_spawn_btn') or (elemName == 'isolated_spawn_near') or (elemName == 'isolated_spawn_far') or (elemName == 'join_other_spawn') or
            (elemName == 'buddy_spawn') or
            (elemName == 'join_other_spawn_check'))
     then
        if (this.scenario_config.gen_settings.moat_choice_enabled and not this.enable_vanilla_spawns and (pgcs.spawn_solo_flow.isolated_spawn_moat_option_checkbox ~= nil)) then
            moatChoice = pgcs.spawn_solo_flow.isolated_spawn_moat_option_checkbox.state
        end
    else
        return -- Do nothing, no valid element item was clicked.
    end

    local own_team = false

    if (elemName == 'default_spawn_btn') then
        Utils.GivePlayerStarterItems(player)
        Public.ChangePlayerSpawn(player, player.force.get_spawn_position(surface_name))
        Utils.SendBroadcastMsg({'oarc-player-is-joining-main-force', player.name})
        Utils.ChartArea(player.force, player.position, math.ceil(this.scenario_config.gen_settings.land_area_tiles / this.chunk_size), player.surface)
        -- Unlock spawn control gui tab
        --Gui.set_tab(player, "Spawn Controls", true)
        if player and player.character and player.character.valid then
            player.character.active = true
        end
    elseif ((elemName == 'isolated_spawn_near') or (elemName == 'isolated_spawn_far')) then
        --game.permissions.get_group("Default").add_player(player)
        -- Create a new spawn point
        local newSpawn = {x = 0, y = 0}

        local goto_main_team = pgcs.spawn_solo_flow.isolated_spawn_main_team_radio.state
        local goto_new_team = pgcs.spawn_solo_flow.isolated_spawn_new_team_radio.state

        -- Create a new force for player if they choose that radio button
        if this.enable_separate_teams then
            if goto_new_team then
                Public.CreatePlayerCustomForce(player)
                own_team = true
            elseif goto_main_team then
                own_team = false
            end
        end

        -- Find an unused vanilla spawn
        -- if (vanillaChoice) then
        if (this.enable_vanilla_spawns) then
            -- Default OARC-type pre-set layout spawn.
            if (elemName == 'isolated_spawn_far') then
                newSpawn = Public.FindUnusedVanillaSpawn(game.surfaces[surface_name], this.far_max_dist * this.chunk_size)
            elseif (elemName == 'isolated_spawn_near') then
                newSpawn = Public.FindUnusedVanillaSpawn(game.surfaces[surface_name], this.near_min_dist * this.chunk_size)
            end
        else
            -- Find coordinates of a good place to spawn
            if (elemName == 'isolated_spawn_far') then
                newSpawn = Utils.FindUngeneratedCoordinates(this.far_min_dist, this.far_max_dist, player.surface)
            elseif (elemName == 'isolated_spawn_near') then
                newSpawn = Utils.FindUngeneratedCoordinates(this.near_min_dist, this.near_max_dist, player.surface)
            end
        end

        -- If that fails, find a random map edge in a rand direction.
        if ((newSpawn.x == 0) and (newSpawn.y == 0)) then
            newSpawn = Utils.FindMapEdge(Utils.GetRandomVector(), player.surface)
            log('Resorting to find map edge! x=' .. newSpawn.x .. ',y=' .. newSpawn.y)
        end

        -- Create that player's spawn in the global vars
        Public.ChangePlayerSpawn(player, newSpawn)

        -- Send the player there
        -- QueuePlayerForDelayedSpawn(player.name, newSpawn, moatChoice, vanillaChoice)
        Public.QueuePlayerForDelayedSpawn(player.name, newSpawn, layout, moatChoice, this.enable_vanilla_spawns, own_team, false)
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
        insert(this.waitingBuddies, player.name)
        Utils.SendBroadcastMsg({'oarc-looking-for-buddy', player.name})

        Public.DisplayBuddySpawnOptions(player)
    end
    if pgcs and pgcs.valid then
        pgcs.destroy()
    end
end

-- Display the spawn options and explanation
function Public.DisplaySharedSpawnOptions(player)
    local elem =
        player.gui.screen.add {
        name = 'shared_spawn_opts',
        type = 'frame',
        direction = 'vertical',
        caption = {'oarc-avail-bases-join'},
        style = main_style
    }
    Gui.ignored_visibility(elem.name)

    local shGuiFrame = player.gui.screen.shared_spawn_opts
    shGuiFrame.style.minimal_height = 300
    shGuiFrame.auto_center = true
    local shGui = shGuiFrame.add {type = 'scroll-pane', name = 'spawns_scroll_pane', caption = ''}
    UtilsGui.ApplyStyle(shGui, UtilsGui.my_fixed_width_style)
    shGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    shGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT
    shGui.horizontal_scroll_policy = 'never'

    local this = MT.get()

    for spawnName, sharedSpawn in pairs(this.sharedSpawns) do
        if (sharedSpawn.openAccess or sharedSpawn.AlwaysAccess and (game.players[spawnName] ~= nil) and game.players[spawnName].connected) then
            local spotsRemaining = this.max_players - #this.sharedSpawns[spawnName].players
            if (this.max_players == 0) then
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

    local this = MT.get()

    -- Check for cancel button, return to spawn options
    if (buttonClicked == 'shared_spawn_cancel') then
        -- Else check for which spawn was selected
        -- If a spawn is removed during this time, the button will not do anything
        Public.DisplaySpawnOptions(player)
        if (player.gui.screen.shared_spawn_opts ~= nil) then
            player.gui.screen.shared_spawn_opts.destroy()
        end
    else
        for spawnName, _ in pairs(this.sharedSpawns) do
            if ((buttonClicked == spawnName) and (game.players[spawnName] ~= nil) and (game.players[spawnName].connected)) then
                if this.sharedSpawns[spawnName].AlwaysAccess then
                    local joiningPlayer = player

                    Utils.SendBroadcastMsg({'oarc-player-joining-base', player.name, spawnName})

                    -- Close the waiting players menu
                    if (player.gui.screen.shared_spawn_opts ~= nil) then
                        player.gui.screen.shared_spawn_opts.destroy()
                    end

                    -- Spawn the player
                    Public.ChangePlayerSpawn(joiningPlayer, this.sharedSpawns[spawnName].position)
                    Public.SendPlayerToSpawn(joiningPlayer)
                    Utils.GivePlayerStarterItems(joiningPlayer)
                    insert(this.sharedSpawns[spawnName].players, joiningPlayer.name)
                    joiningPlayer.force = game.players[spawnName].force

                    -- Unlock spawn control gui tab
                    Gui.set_tab(joiningPlayer, 'Spawn Controls', true)
                    if joiningPlayer and joiningPlayer.character and joiningPlayer.character.valid then
                        joiningPlayer.character.active = true
                    end
                    return
                else
                    -- Add the player to that shared spawns join queue.
                    if (this.sharedSpawns[spawnName].joinQueue == nil) then
                        this.sharedSpawns[spawnName].joinQueue = {}
                    end
                    insert(this.sharedSpawns[spawnName].joinQueue, player.name)

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
    Gui.ignored_visibility(sGui.name)
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
        local this = MT.get()

        -- Find and remove the player from the joinQueue they were in.
        for spawnName, sharedSpawn in pairs(this.sharedSpawns) do
            if (sharedSpawn.joinQueue ~= nil) then
                for index, requestingPlayer in pairs(sharedSpawn.joinQueue) do
                    if (requestingPlayer == player.name) then
                        table.remove(this.sharedSpawns[spawnName].joinQueue, index)
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
    local this = MT.get()
    if ((this.sharedSpawns[player.name] == nil) or (this.sharedSpawns[player.name].openAccess == false)) then
        return false
    else
        return true
    end
end

local function IsSharedSpawnActiveAlways(player)
    local this = MT.get()
    if ((this.sharedSpawns[player.name] == nil) or (this.sharedSpawns[player.name].AlwaysAccess == false)) then
        return false
    else
        return true
    end
end

-- Get a random warp point to go to
function Public.GetRandomSpawnPoint()
    local this = MT.get()
    local numSpawnPoints = Utils.TableLength(this.sharedSpawns)
    if (numSpawnPoints > 0) then
        local randSpawnNum = math.random(1, numSpawnPoints)
        local counter = 1
        for _, sharedSpawn in pairs(this.sharedSpawns) do
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
    local this = MT.get()

    if this.enable_shared_spawns then
        if (this.uniqueSpawns[player.name] ~= nil) then
            -- This checkbox allows people to join your base when they first
            -- start the game.
            spwnCtrls.add {
                type = 'checkbox',
                name = 'accessToggle',
                caption = {'oarc-spawn-allow-joiners'},
                state = IsSharedSpawnActive(player)
            }
            if Public.DoesPlayerHaveCustomSpawn(player) then
                if (this.sharedSpawns[player.name] == nil) then
                    Public.CreateNewSharedSpawn(player)
                end
            end
            if this.sharedSpawns[player.name].openAccess then
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
    if ((game.tick - this.playerCooldowns[player.name].setRespawn) > (this.respawn_cooldown * this.ticks_per_minute)) then
        spwnCtrls.add {type = 'button', name = 'setRespawnLocation', caption = {'oarc-set-respawn-loc'}}
        spwnCtrls['setRespawnLocation'].style.font = 'default-small-semibold'
    else
        UtilsGui.AddLabel(
            spwnCtrls,
            'respawn_cooldown_note1',
            {
                'oarc-set-respawn-loc-cooldown',
                Utils.formattime((this.respawn_cooldown * this.ticks_per_minute) - (game.tick - this.playerCooldowns[player.name].setRespawn))
            },
            UtilsGui.my_note_style
        )
    end
    UtilsGui.AddLabel(spwnCtrls, 'respawn_cooldown_note2', {'oarc-set-respawn-note'}, UtilsGui.my_note_style)

    -- Display a list of people in the join queue for your base.
    if (this.enable_shared_spawns and IsSharedSpawnActive(player)) then
        if ((this.sharedSpawns[player.name].joinQueue ~= nil) and (#this.sharedSpawns[player.name].joinQueue > 0)) then
            UtilsGui.AddLabel(spwnCtrls, 'drop_down_msg_lbl1', {'oarc-select-player-join-queue'}, UtilsGui.my_label_style)
            spwnCtrls.add {
                name = 'join_queue_dropdown',
                type = 'drop-down',
                items = this.sharedSpawns[player.name].joinQueue
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

    local this = MT.get()

    -- Handle changes to spawn sharing.
    if (name == 'accessToggle') then
        if event.element.state then
            if Public.DoesPlayerHaveCustomSpawn(player) then
                if (this.sharedSpawns[player.name] == nil) then
                    Public.CreateNewSharedSpawn(player)
                else
                    this.sharedSpawns[player.name].openAccess = true
                end

                Utils.SendBroadcastMsg({'oarc-start-shared-base', player.name})
            end
        else
            if (this.sharedSpawns[player.name] ~= nil) then
                this.sharedSpawns[player.name].openAccess = false
                this.sharedSpawns[player.name].AlwaysAccess = false
                Utils.SendBroadcastMsg({'oarc-stop-shared-base', player.name})
            end
        end
        Gui.refresh(player)
    end
    if (name == 'alwaysallowaccessToggle') then
        if event.element.state then
            if Public.DoesPlayerHaveCustomSpawn(player) then
                if (this.sharedSpawns[player.name] == nil) then
                    Public.CreateNewSharedSpawn(player)
                else
                    this.sharedSpawns[player.name].AlwaysAccess = true
                end

                Utils.SendBroadcastMsg({'oarc-start-always-shared-base', player.name})
            end
        else
            if (this.sharedSpawns[player.name] ~= nil) then
                this.sharedSpawns[player.name].AlwaysAccess = false
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

        local this = MT.get()

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
            for index, requestingPlayer in pairs(this.sharedSpawns[player.name].joinQueue) do
                if (requestingPlayer == joinQueuePlayerChoice) then
                    table.remove(this.sharedSpawns[player.name].joinQueue, index)
                    return
                end
            end
        elseif (elemName == 'accept_player_request') then
            -- Find and remove the player from the joinQueue they were in.
            for index, requestingPlayer in pairs(this.sharedSpawns[player.name].joinQueue) do
                if (requestingPlayer == joinQueuePlayerChoice) then
                    table.remove(this.sharedSpawns[player.name].joinQueue, index)
                end
            end
            Gui.refresh(player)
            -- If player exists, then do stuff.
            if (game.players[joinQueuePlayerChoice]) then
                local joiningPlayer = game.players[joinQueuePlayerChoice]

                -- Send an announcement
                Utils.SendBroadcastMsg({'oarc-player-joining-base', joinQueuePlayerChoice, player.name})

                -- Close the waiting players menu
                if (joiningPlayer.gui.screen.join_shared_spawn_wait_menu) then
                    joiningPlayer.gui.screen.join_shared_spawn_wait_menu.destroy()
                end

                -- Spawn the player
                Public.ChangePlayerSpawn(joiningPlayer, this.sharedSpawns[player.name].position)
                Public.SendPlayerToSpawn(joiningPlayer)
                Utils.GivePlayerStarterItems(joiningPlayer)
                insert(this.sharedSpawns[player.name].players, joiningPlayer.name)
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
    Gui.ignored_visibility(buddyGui.name)
    buddyGui.auto_center = true
    buddyGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    buddyGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Warnings and explanations...
    UtilsGui.AddLabel(buddyGui, 'buddy_info_msg', {'oarc-buddy-spawn-instructions'}, UtilsGui.my_label_style)
    UtilsGui.AddSpacer(buddyGui)

    local layout_flow = buddyGui.add {name = 'layout', type = 'frame', direction = 'vertical', style = 'bordered_frame'}
    UtilsGui.AddLabel(layout_flow, 'normal_spawn_lbl1', {'oarc-layout'}, UtilsGui.my_label_style)
    layout_flow.add {name = 'layout_circle', type = 'radiobutton', caption = {'oarc-layout-circle'}, state = true}
    layout_flow.add {name = 'layout_square', type = 'radiobutton', caption = {'oarc-layout-square'}, state = false}

    -- The buddy spawning options.
    local buddySpawnFlow =
        buddyGui.add {
        name = 'spawn_buddy_flow',
        type = 'frame',
        direction = 'vertical',
        style = 'bordered_frame'
    }

    local this = MT.get()

    this.buddyList = {}
    for _, buddyName in pairs(this.waitingBuddies) do
        if (buddyName ~= player.name) then
            insert(this.buddyList, buddyName)
        end
    end

    UtilsGui.AddLabel(buddySpawnFlow, 'drop_down_msg_lbl1', {'oarc-buddy-select-info'}, UtilsGui.my_label_style)
    buddySpawnFlow.add {
        name = 'waiting_buddies_dropdown',
        type = 'drop-down',
        items = this.buddyList
    }
    buddySpawnFlow.add {
        name = 'refresh_buddy_list',
        type = 'button',
        caption = {'oarc-buddy-refresh'}
    }
    -- UtilsGui.AddSpacerLine(buddySpawnFlow)

    -- Allow picking of teams
    if (this.enable_separate_teams) then
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
    --if (this.scenario_config.gen_settings.moat_choice_enabled) then
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
    if (this.max_players > 0) then
        UtilsGui.AddLabel(buddyGui, 'buddy_max_players_lbl1', {'oarc-max-players-shared-spawn', this.max_players - 1}, UtilsGui.my_note_style)
    end
    local spawn_distance_notes = {
        'oarc-spawn-dist-notes',
        this.near_min_dist,
        this.near_max_dist,
        this.far_min_dist,
        this.far_max_dist
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

    local this = MT.get()

    -- Just refresh the buddy list dropdown values only.
    if (elemName == 'refresh_buddy_list') then
        waiting_buddies_dropdown.clear_items()

        for _, buddyName in pairs(this.waitingBuddies) do
            if (player.name ~= buddyName) then
                waiting_buddies_dropdown.add_item(buddyName)
            end
        end
        return
    end

    local circle_shape = pgcs.layout.layout_circle.state
    local square_shape = pgcs.layout.layout_square.state

    if circle_shape then
        layout = 'circle_shape'
    end
    if square_shape then
        layout = 'square_shape'
    end

    -- Handle the cancel button to exit this menu
    if (elemName == 'buddy_spawn_cancel') then
        Utils.SendBroadcastMsg({'oarc-not-looking-for-buddy', player.name})
        player.gui.screen.buddy_spawn_opts.destroy()
        Public.DisplaySpawnOptions(player)

        -- Remove them from the buddy list when they cancel
        for i = #this.waitingBuddies, 1, -1 do
            local name = this.waitingBuddies[i]
            if (name == player.name) then
                table.remove(this.waitingBuddies, i)
            end
        end
    end

    local joinMainTeamRadio, joinOwnTeamRadio, joinBuddyTeamRadio
    local moatChoice = false
    local buddyChoice

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
        for _, buddyName in pairs(this.waitingBuddies) do
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

        if (this.enable_separate_teams) then
            joinMainTeamRadio = buddySpawnGui.buddy_spawn_main_team_radio.state
            joinOwnTeamRadio = buddySpawnGui.buddy_spawn_new_team_radio.state
            joinBuddyTeamRadio = buddySpawnGui.buddy_spawn_buddy_team_radio.state
        else
            joinMainTeamRadio = true
            joinOwnTeamRadio = false
            joinBuddyTeamRadio = false
        end
        --if (this.scenario_config.gen_settings.moat_choice_enabled) then
        --    moatChoice =  buddySpawnGui.buddy_spawn_moat_option_checkbox.state
        --end

        -- Save the chosen spawn options somewhere for later use.
        this.buddySpawnOptions[player.name] = {
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
        for i = #this.waitingBuddies, 1, -1 do
            local name = this.waitingBuddies[i]
            if ((name == player.name) or (name == buddyChoice)) then
                table.remove(this.waitingBuddies, i)
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
    Gui.ignored_visibility(sGui.name)
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

    local this = MT.get()

    -- Check if player is cancelling the request.
    if (elemName == 'cancel_buddy_wait_menu') then
        player.gui.screen.buddy_wait_menu.destroy()
        Public.DisplaySpawnOptions(player)

        local buddy = game.players[this.buddySpawnOptions[player.name].buddyChoice]

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
    Gui.ignored_visibility(sGui.name)
    sGui.auto_center = true
    sGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    sGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Warnings and explanations...
    UtilsGui.AddLabel(sGui, 'warning_lbl1', {'oarc-buddy-requesting-from-you', requestingBuddyName}, UtilsGui.my_warning_style)

    local this = MT.get()

    local teamText = 'error!'
    if (this.buddySpawnOptions[requestingBuddyName].joinMainTeamRadio) then
        teamText = {'oarc-buddy-txt-main-team'}
    elseif (this.buddySpawnOptions[requestingBuddyName].joinOwnTeamRadio) then
        teamText = {'oarc-buddy-txt-new-teams'}
    elseif (this.buddySpawnOptions[requestingBuddyName].joinBuddyTeamRadio) then
        teamText = {'oarc-buddy-txt-buddy-team'}
    end

    local moatText = ' '
    if (this.buddySpawnOptions[requestingBuddyName].moatChoice) then
        moatText = {'oarc-buddy-txt-moat'}
    end

    local distText = 'error!'
    if (this.buddySpawnOptions[requestingBuddyName].distChoice == 'buddy_spawn_request_near') then
        distText = {'oarc-buddy-txt-near'}
    elseif (this.buddySpawnOptions[requestingBuddyName].distChoice == 'buddy_spawn_request_far') then
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

    local this = MT.get()

    -- Check if it's a button press and lookup the matching buddy info
    if ((elemName == 'accept_buddy_request') or (elemName == 'decline_buddy_request')) then
        for name, opts in pairs(this.buddySpawnOptions) do
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
            Public.CreatePlayerCustomForce(player)
            Public.CreatePlayerCustomForce(game.players[requesterName])
        elseif requesterOptions.joinBuddyTeamRadio then
            local buddyForce = Public.CreatePlayerCustomForce(game.players[requesterName])
            player.force = buddyForce
        end

        -- Find coordinates of a good place to spawn
        if (requesterOptions.distChoice == 'buddy_spawn_request_far') then
            newSpawn = Utils.FindUngeneratedCoordinates(this.far_min_dist, this.far_max_dist, player.surface)
        elseif (requesterOptions.distChoice == 'buddy_spawn_request_near') then
            newSpawn = Utils.FindUngeneratedCoordinates(this.near_min_dist, this.near_max_dist, player.surface)
        end

        -- If that fails, find a random map edge in a rand direction.
        if ((newSpawn.x == 0) and (newSpawn.x == 0)) then
            newSpawn = Utils.FindMapEdge(Utils.GetRandomVector(), player.surface)
            log('Resorting to find map edge! x=' .. newSpawn.x .. ',y=' .. newSpawn.y)
        end

        -- Create that spawn in the global vars
        this.buddySpawn = {x = 0, y = 0}
        if (requesterOptions.moatChoice) then
            this.buddySpawn = {
                x = newSpawn.x + (this.scenario_config.gen_settings.land_area_tiles * 2) + 10,
                y = newSpawn.y
            }
        else
            this.buddySpawn = {
                x = newSpawn.x + (this.scenario_config.gen_settings.land_area_tiles * 2),
                y = newSpawn.y
            }
        end
        Public.ChangePlayerSpawn(player, newSpawn)
        Public.ChangePlayerSpawn(game.players[requesterName], this.buddySpawn)
        -- Send the player there
        Public.QueuePlayerForDelayedSpawn(player.name, newSpawn, requesterOptions.layout, requesterOptions.moatChoice, false, false, true, false)
        Public.QueuePlayerForDelayedSpawn(requesterName, this.buddySpawn, requesterOptions.layout, requesterOptions.moatChoice, false, false, true, false)
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
    Gui.ignored_visibility(pleaseWaitGui.name)
    pleaseWaitGui.auto_center = true
    pleaseWaitGui.style.maximal_width = SPAWN_GUI_MAX_WIDTH
    pleaseWaitGui.style.maximal_height = SPAWN_GUI_MAX_HEIGHT

    -- Warnings and explanations...
    local wait_warning_text = {'oarc-wait-text', delay_seconds}

    UtilsGui.AddLabel(pleaseWaitGui, 'warning_lbl1', wait_warning_text, UtilsGui.my_warning_style)
end

Gui.tabs['Spawn Controls'] = Public.CreateSpawnCtrlGuiTab

return Public
