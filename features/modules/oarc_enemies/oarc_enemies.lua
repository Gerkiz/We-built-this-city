-- oarc_enemies.lua
-- Oarc Sep 2018
-- My crude attempts at changing enemy experience.

-- This is what an attack request should look like:
-- attack_request_example = {
--      target_player=player_name,      -- REQUIRED (Player Name)
--      target_type=TYPE,               -- REQUIRED (OE_ATTACK_TYPE)
--      attempts=3,                     -- REQUIRED (Must be at least 1! Otherwise it won't do anything.)
--      process_stg=TYPE,               -- REQUIRED (Normally starts with process_find_target)
--      building_types=entity_types,    -- REQUIRED if attack request is for a building.
--      surface_idx=surface_index       -- REQUIRED (Tracking of different surfaces)
--      target_entity=lua_entity,       -- Depends on attack type. Calculated during request processing.
--      target_chunk=c_pos,             -- Depends on attack type. Calculated during request processing.
--      size=x,                         -- Calculated during request processing.
--      evo=x,                          -- Calculated during request processing.
--      spawn_chunk=spawn_chunk,        -- Calculated during request processing.
--      path_id=path_request_id,        -- Set during request processing.
--      path=path,                      -- Set by on_script_path_request_finished.
--      group_id=group_id,              -- Set during request processing.
--      group=lua_unit_group            -- The group created to handle the attack
--      group_age=tick_spawned          -- The tick when the group was created
-- }

local Evo = require 'features.modules.oarc_enemies.oarc_enemies_evo'
local Utils = require 'map_gen.multiplayer_spawn.lib.oarc_utils'
local OE_Table = require 'features.modules.oarc_enemies.table'
local MPS = require 'map_gen.multiplayer_spawn.lib.table'
local Surface = require 'utils.surface'
local validate = require 'utils.validate_player'
local insert = table.insert

local Public = {}

function Public.SpiralSearch(starting_c_pos, max_radius, max_count)
    local gd = OE_Table.get_table()

    local dx = 1
    local dy = 0
    local segment_length = 1

    local x = starting_c_pos.x
    local y = starting_c_pos.y
    local segment_passed = 0

    local found = {}

    for i = 1, (math.pow(max_radius * 2 + 1, 2)) do
        --if (true == check_function({x=x, y=y})) then
        insert(found, {x = x, y = y})
        if (#found >= max_count) then
            return found
        end
        --end

        x = x + dx
        y = y + dy
        segment_passed = segment_passed + 1

        if (segment_passed == segment_length) then
            segment_passed = 0

            local buffer = dx
            dx = -dy
            dy = buffer

            if (dy == 0) then
                segment_length = segment_length + 1
            end
        end
    end

    if (#found == 0) then
        if gd.debug then
            log('SpiralSearch Failed? ' .. x .. ',' .. y)
        end
        return nil
    else
        game.print(serpent.block(found))
        return found
    end
end

function Public.OarcEnemiesDoesChunkHaveSpawner(c_pos)
    local s_name = Surface.get_surface_name()

    local w_chunk = {}

    if (w_chunk[c_pos.x] == nil) then
        w_chunk[c_pos.x] = {}
    end

    if not w_chunk[c_pos.x][c_pos.y] then
        w_chunk[c_pos.x][c_pos.y] = {
            player_building = false,
            near_building = false,
            valid_spawn = true,
            enemy_spawners = true
        }
    end

    -- Chunk should exist.
    if (game.surfaces[s_name].is_chunk_generated(c_pos) == false) then
        return false
    end

    -- Get entry
    local chunk = w_chunk[c_pos.x][c_pos.y]

    -- Check basic flags
    if (not chunk.valid_spawn) then
        return false
    end

    -- Check for spawners
    local has_spawners = false
    if (not chunk.enemy_spawners) then
        return false
    else
        has_spawners = true
    end

    return true
end

function Public.OarcEnemiesSectorScanned(event)
    local gd = OE_Table.get_table()
    if (not event.radar.last_user) then
        return
    end
    local player = event.radar.last_user

    if not player.connected then
        return
    end

    -- 1 in a X chance of triggering an attack on radars?
    if (math.random(1, gd.params.radar_scan_attack_chance) == 1) then
        Public.OarcEnemiesBuildingAttack(player.name, 'radar')
    end
end

function Public.OarcEnemiesRocketLaunched(event)
    local gd = OE_Table.get_table()
    if (not event.rocket_silo) then
        return
    end
    local player = event.rocket_silo.last_user
    if (not player) then
        if gd.debug then
            log('Error? No last user on the silo.')
        end
        return
    end

    local silo = event.rocket_silo

    local e, s =
        Evo.GetEnemyGroup {
        player = player,
        force_name = player.force.name,
        surface = silo.surface,
        target_pos = silo.position
    }

    local rocket_launch_attack = {
        target_player = player.name,
        target_type = gd.type_target_entity,
        attempts = 1,
        process_stg = gd.process_find_spawn,
        building_types = nil,
        evo = e,
        size = s
    }
    if gd.debug then
        log('SILO ATTACK')
    end
    insert(gd.attacks, rocket_launch_attack)
end

function Public.OarcEnemiesForceCreated(event)
    local gd = OE_Table.get_table()
    if (not event.force) then
        return
    end
    gd.tech_levels[event.force.name] = 0
end

function Public.CountForceTechCompleted(force)
    local gd = OE_Table.get_table()
    if (not force.technologies) then
        if gd.debug then
            log('ERROR - CountForceTechCompleted needs a valid force please.')
        end
        return 0
    end

    local tech_done = 0
    for _, tech in pairs(force.technologies) do
        if tech.researched then
            tech_done = tech_done + 1
        end
    end

    return tech_done
end

-- Track each force's amount of research completed.
function Public.OarcEnemiesResearchFinishedEvent(event)
    local gd = OE_Table.get_table()
    if not (event.research and event.research.force) then
        return
    end

    local force_name = event.research.force.name
    if (gd.tech_levels[force_name] == nil) then
        gd.tech_levels[force_name] = Public.CountForceTechCompleted(game.forces[force_name])
    else
        gd.tech_levels[force_name] = gd.tech_levels[force_name] + 1
    end

    -- Trigger an attack on science!
    Public.OarcEnemiesScienceLabAttack(event.research.force.name)
end

-- Attack science labs of a given force!
function Public.OarcEnemiesScienceLabAttack(force_name)
    -- For each player (connected only), find a random science lab,
    for _, player in pairs(game.connected_players) do
        if (player.force.name == force_name) then
            Public.OarcEnemiesBuildingAttack(player.name, 'lab')
        end
    end
end

-- Request an attack on a given player's building type.
function Public.OarcEnemiesBuildingAttack(player_name, entity_type)
    local gd = OE_Table.get_table()
    -- Make sure player exists and is connected.
    if (not game.players[player_name] or not game.players[player_name].connected) then
        return
    end

    -- Check we don't have too many ongoing attacks.
    if (#gd.attacks >= gd.max_attacks) then
        if gd.debug then
            log('Max number of simulataneous attacks reached.')
        end
        return
    end

    local building_attack = {
        target_player = player_name,
        target_type = gd.type_target_building,
        attempts = 3,
        process_stg = gd.process_find_target,
        building_types = entity_type
    }
    if gd.debug then
        log('Building Attack Request: ' .. serpent.line(entity_type))
    end
    insert(gd.attacks, building_attack)
end

-- Attack a player's character
function Public.OarcEnemiesPlayerAttackCharacter(player_name)
    local gd = OE_Table.get_table()

    -- Validation checks.
    if
        (not game.players[player_name] or not game.players[player_name].connected or
            not game.players[player_name].character or
            not game.players[player_name].character.valid)
     then
        if gd.debug then
            log('OarcEnemiesPlayerAttackCharacter - player not connected or is dead?')
        end
        return
    end

    -- Check we don't have too many ongoing attacks.
    if (#gd.attacks >= gd.max_attacks) then
        if gd.debug then
            log('Max number of simulataneous attacks reached.')
        end
        return
    end

    -- Create the attack request
    local player_attack = {
        target_player = player_name,
        target_type = gd.type_target_player,
        attempts = 3,
        process_stg = gd.process_find_target
    }
    if gd.debug then
        log('Player Attack!')
    end
    insert(gd.attacks, player_attack)
end

-- First time player init stuff
function Public.OarcEnemiesPlayerCreatedEvent(event)
    local gd = OE_Table.get_table()
    local player = event.player_index

    if not player then
        return
    end
    --validate(p_name)

    if not gd.p_time[player] then
        if _DEBUG then
            gd.p_time[player] = {next_wave_player = 50}
        else
            gd.p_time[player] = {next_wave_player = 3600}
        end
    end

    --if not gd.p_time[player] then
    --    gd.p_time[player] = {next_wave_player=7200, next_wave_buildings=7200}
    --end

    --if (gd.buildings[player] == nil) then
    --    gd.buildings[player] = {}
    --end

    local force = game.players[event.player_index].force
    if (gd.tech_levels[force.name] == nil) then
        gd.tech_levels[force.name] = Public.CountForceTechCompleted(force)
    end

    -- Setup tracking of first time chat bubble displays
    if (gd.player_sbubbles[player] == nil) then
        gd.player_sbubbles[player] = {uh_oh = false, rocket = false, wave = 0}
    end
end

function Public.OarcEnemiesChunkIsNearPlayerBuilding(c_pos)
    local gd = OE_Table.get_table()
    if (gd.w_attack.w_chunk[c_pos.x] == nil) then
        gd.w_attack.w_chunk[c_pos.x] = {}
    end
    if (gd.w_attack.w_chunk[c_pos.x][c_pos.y] == nil) then
        gd.w_attack.w_chunk[c_pos.x][c_pos.y] = {
            player_building = false,
            near_building = true,
            valid_spawn = true,
            enemy_spawners = {}
        }
    else
        gd.w_attack.w_chunk[c_pos.x][c_pos.y].near_building = true
    end
end

function Public.OarcEnemiesChunkHasPlayerBuilding()
    return true
end

function Public.OarcEnemiesEntityDiedEvent(event)
    local gd = OE_Table.get_table()
    local s_name = Surface.get_surface_name()

    -- Validate
    if (not event.entity or not (event.entity.force.name == 'enemy') or not (event.cause or event.force)) then
        return
    end

    -- Enemy spawners only.
    if (not (event.entity.type == 'unit-spawner')) then
        return
    end

    -- Check we don't have too many ongoing attacks.
    if (#gd.attacks >= gd.max_attacks_retal) then
        if gd.debug then
            log('Max number of simulataneous attacks reached (retaliation).')
        end
        return
    end

    local death_attack = {
        attempts = 1,
        spawn_chunk = Utils.GetChunkPosFromTilePos(event.entity.position)
    }

    -- If there is just a force, then just attack the area.
    if (not event.cause) then
        -- If we have a cause, go attack that cause.
        death_attack.process_stg = gd.process_find_create_group
        death_attack.spawn_pos = event.entity.position
        death_attack.target_type = gd.type_target_area
        death_attack.target_chunk = Utils.GetChunkPosFromTilePos(event.entity.position)

        death_attack.evo, death_attack.size =
            Evo.GetEnemyGroup {
            player = nil,
            force_name = event.force.name,
            surface = game.surfaces[s_name],
            target_pos = event.entity.position,
            min_size = 8,
            min_evo = 0.25
        }
    else
        local player = nil
        if (event.cause.type == 'character') then
            player = event.cause.player
        elseif (event.cause.last_user) then
            player = event.cause.last_user
        end

        -- No attacks on offline players??
        -- if (not player or not player.connected) then return end

        death_attack.process_stg = gd.process_find_spawn_path_req
        death_attack.target_player = player.name
        death_attack.target_type = gd.type_target_entity
        death_attack.target_entity = event.cause
        death_attack.target_chunk = Utils.GetChunkPosFromTilePos(player.character.position)

        death_attack.evo, death_attack.size =
            Evo.GetEnemyGroup {
            player = player,
            force_name = event.force.name,
            surface = game.surfaces[s_name],
            target_pos = event.entity.position,
            min_size = 8,
            min_evo = 0.25
        }
    end

    insert(gd.attacks, death_attack)
end

function Public.OarcEnemiesTrackBuildings(e)
    local gd = OE_Table.get_table()
    local targets = gd.target_types
    if targets[e.type] then
        if (e.last_user == nil) then
            if gd.debug then
                log('ERROR - OarcEnemiesTrackBuildings - entity.last_user is nil! ' .. e.name)
            end
            return
        end

        if (gd.buildings[e.last_user.name] == nil) then
            gd.buildings[e.last_user.name] = {}
        end

        insert(gd.buildings[e.last_user.name], e)
    end
end

function Public.GetRandomBuildingAny(player_name, entity_type_or_types)
    if (type(entity_type_or_types) == 'table') then
        return Public.GetRandomBuildingMultipleTypes(player_name, entity_type_or_types)
    else
        return Public.GetRandomBuildingSingleType(player_name, entity_type_or_types)
    end
end

function Public.GetRandomBuildingMultipleTypes(player_name, entity_types)
    local rand_list = {}
    for _, e_type in pairs(entity_types) do
        local rand_building = Public.GetRandomBuildingSingleType(player_name, e_type)
        if (rand_building) then
            insert(rand_list, rand_building)
        end
    end
    if (#rand_list > 0) then
        return rand_list[math.random(#rand_list)]
    else
        return nil
    end
end

function Public.GetRandomBuildingSingleType(player_name, entity_type, count)
    local gd = OE_Table.get_table()

    -- We only use this if there are lots of invalid entries, likely from destroyed buildings
    local count_internal = 0
    if (count == nil) then
        count_internal = 20
    else
        count_internal = count
    end

    if (count_internal == 0) then
        if gd.debug then
            log('WARN - GetRandomBuildingSingleType - recursive limit hit')
        end
        return nil
    end

    if (not gd.buildings[player_name][entity_type] or (#gd.buildings[player_name][entity_type] == 0)) then
        if gd.debug then
            log('GetRandomBuildingSingleType - none found ' .. entity_type)
        end
        return nil
    end

    local rand_key = Utils.GetRandomKeyFromTable(gd.buildings[player_name][entity_type])
    local random_building = gd.buildings[player_name][entity_type][rand_key]

    if (not random_building or not random_building.valid) then
        gd.buildings[player_name][entity_type][rand_key] = nil
        return Public.GetRandomBuildingSingleType(player_name, entity_type, count_internal - 1)
    else
        return random_building
    end
end

function Public.CreateEnemyGroupGivenEvoAndCount(surface, position, evo, count)
    local biter_list = Evo.CalculateEvoChanceListBiters(evo)
    local spitter_list = Evo.CalculateEvoChanceListSpitters(evo)

    -- Spitters will be between 10-50% of the size
    local rand_spitter_count = math.random(math.ceil(count / 10), math.ceil(count / 2))

    local enemy_units = {}
    for i = 1, count do
        if (i < rand_spitter_count) then
            insert(enemy_units, Evo.GetEnemyFromChanceList(spitter_list))
        else
            insert(enemy_units, Evo.GetEnemyFromChanceList(biter_list))
        end
    end

    return Public.CreateEnemyGroup(surface, position, enemy_units)
end

-- Create an enemy group at given position, with array of unit names provided.
function Public.CreateEnemyGroup(surface, position, units)
    local gd = OE_Table.get_table()
    local new_unit

    -- Create new group at given position
    local new_enemy_group = surface.create_unit_group {position = position}

    -- Attempt to spawn all units nearby
    for k, biter_name in pairs(units) do
        local unit_position =
            surface.find_non_colliding_position(
            biter_name,
            {position.x + math.random(-5, 5), position.y + math.random(-5, 5)},
            32,
            1
        )
        if (unit_position) then
            new_unit = surface.create_entity {name = biter_name, position = unit_position}
            new_enemy_group.add_member(new_unit)
        -- insert(gd.units, new_unit)
        end
    end
    insert(gd.groups, new_enemy_group)
    -- Return the new group
    return new_enemy_group
end

-- function Public.OarcEnemiesGroupCreatedEvent(event)
--     if gd.debug then
--     log("Unit group created: " .. event.group.group_number)
--     end
--     -- if (gd.groups == nil) then
--     --     gd.groups = {}
--     -- end
--     -- if (gd.groups[event.group.group_number] == nil) then
--     --     gd.groups[event.group.group_number] = event.group
--     -- else
--        if gd.debug then
--     --     log("A group with this ID was already created???" .. event.group.group_number)
--        end
--     -- end
-- end

function Public.OarcEnemiesUnitRemoveFromGroupEvent(event)
    local gd = OE_Table.get_table()

    if event.group and event.group.valid then
        -- Force the unit back into its group if possible, only while that group is navigating/moving
        if
            ((gd.groups[event.group.group_number] ~= nil) and event.group and event.group.valid and
                ((event.group.state == defines.group_state.moving) or
                    (event.group.state == defines.group_state.pathfinding)))
         then
            -- Re-add a unit back if it's on the move.
            event.group.add_member(event.unit)
            return
        end
    end

    -- Otherwise, ask the unit to build a base.
    Public.EnemyUnitBuildBaseThenWander(event.unit, event.unit.position)
end

function Public.FindAttackKeyFromGroupIdNumber(id)
    local gd = OE_Table.get_table()
    for key, attack in pairs(gd.attacks) do
        if (attack.group_id and (attack.group_id == id)) then
            return key
        end
    end
    return nil
end

function Public.EnemyGroupAttackAreaThenWander(group, target_pos, radius)
    local gd = OE_Table.get_table()

    if (not group or not group.valid or not target_pos or not radius) then
        if gd.debug then
            log('EnemyGroupAttackAreaThenWander - Missing params!')
        end
        return
    end

    local combined_commands = {}

    -- Attack the target.
    insert(
        combined_commands,
        {
            type = defines.command.attack_area,
            destination = target_pos,
            radius = radius,
            distraction = defines.distraction.by_enemy
        }
    )

    -- Then wander and attack anything in the area
    insert(
        combined_commands,
        {
            type = defines.command.wander,
            distraction = defines.distraction.by_anything
        }
    )

    -- Execute all commands in sequence regardless of failures.
    local compound_command = {
        type = defines.command.compound,
        structure_type = defines.compound_command.return_last,
        commands = combined_commands
    }

    group.set_command(compound_command)
end

function Public.EnemyGroupGoAttackEntityThenWander(group, target, path)
    local gd = OE_Table.get_table()
    local global_data = MPS.get()

    if (not group or not group.valid or not target or not path) then
        if gd.debug then
            log('EnemyGroupPathAttandThenWander - Missing params!')
        end
        return
    end

    local combined_commands = {}

    -- Add waypoints for long paths.
    -- Based on number of segments in the path.
    local i = 100
    while (path[i] ~= nil) do
        if gd.debug then
            log('Adding path ' .. i)
        end
        insert(
            combined_commands,
            {
                type = defines.command.go_to_location,
                destination = path[i].position,
                pathfind_flags = {low_priority = true},
                radius = 5,
                distraction = defines.distraction.by_damage
            }
        )
        i = i + 100
    end

    -- Then attack the target.
    insert(
        combined_commands,
        {
            type = defines.command.attack,
            target = target,
            distraction = defines.distraction.by_damage
        }
    )
    -- Then attack anything in the area.
    insert(
        combined_commands,
        {
            type = defines.command.attack_area,
            destination = target.position,
            radius = global_data.chunk_size * 2,
            distraction = defines.distraction.by_enemy
        }
    )

    -- Then wander and attack anything in the area
    insert(
        combined_commands,
        {
            type = defines.command.wander,
            distraction = defines.distraction.by_anything
        }
    )

    -- Execute all commands in sequence regardless of failures.
    local compound_command = {
        type = defines.command.compound,
        structure_type = defines.compound_command.return_last,
        commands = combined_commands
    }

    group.set_command(compound_command)
end

function Public.EnemyGroupBuildBaseThenWander(group, target_pos)
    local gd = OE_Table.get_table()
    local global_data = MPS.get()

    if (not group or not group.valid or not target_pos) then
        if gd.debug then
            log('EnemyGroupBuildBase - Invalid group or missing target!')
        end
        return
    end

    local combined_commands = {}

    -- Build a base (a few attempts, with randomized locations.)
    insert(
        combined_commands,
        {
            type = defines.command.build_base,
            destination = target_pos,
            ignore_planner = true,
            distraction = defines.distraction.by_enemy
        }
    )
    insert(
        combined_commands,
        {
            type = defines.command.build_base,
            destination = {
                x = target_pos.x + math.random(-global_data.chunk_size, global_data.chunk_size),
                y = target_pos.y + math.random(-global_data.chunk_size, global_data.chunk_size)
            },
            ignore_planner = true,
            distraction = defines.distraction.by_enemy
        }
    )
    insert(
        combined_commands,
        {
            type = defines.command.build_base,
            destination = {
                x = target_pos.x + math.random(-global_data.chunk_size, global_data.chunk_size),
                y = target_pos.y + math.random(-global_data.chunk_size, global_data.chunk_size)
            },
            ignore_planner = true,
            distraction = defines.distraction.by_enemy
        }
    )

    -- Last resort is wander and attack anything in the area
    insert(
        combined_commands,
        {
            type = defines.command.wander,
            distraction = defines.distraction.by_anything
        }
    )

    -- Execute all commands in sequence regardless of failures.
    local compound_command = {
        type = defines.command.compound,
        structure_type = defines.compound_command.return_last,
        commands = combined_commands
    }

    group.set_command(compound_command)
end

function Public.EnemyUnitBuildBaseThenWander(unit, target_pos)
    local gd = OE_Table.get_table()

    if (not unit or not unit.valid or not target_pos) then
        if gd.debug then
            log('EnemyUnitBuildBaseThenWander - Invalid or missing target!')
        end
        return
    end

    -- Temporary fix?
    local temp_group = unit.surface.create_unit_group {position = unit.position}
    temp_group.add_member(unit)

    local combined_commands = {}

    -- Build a base (a few attempts)
    insert(
        combined_commands,
        {
            type = defines.command.build_base,
            destination = target_pos,
            ignore_planner = true,
            distraction = defines.distraction.by_enemy
        }
    )
    insert(
        combined_commands,
        {
            type = defines.command.build_base,
            destination = {
                x = target_pos.x + math.random(-64, 64),
                y = target_pos.y + math.random(-64, 64)
            },
            ignore_planner = true,
            distraction = defines.distraction.by_enemy
        }
    )
    insert(
        combined_commands,
        {
            type = defines.command.build_base,
            destination = {
                x = target_pos.x + math.random(-64, 64),
                y = target_pos.y + math.random(-64, 64)
            },
            ignore_planner = true,
            distraction = defines.distraction.by_enemy
        }
    )

    -- Last resort is wander and attack anything in the area
    insert(
        combined_commands,
        {
            type = defines.command.wander,
            distraction = defines.distraction.by_anything
        }
    )

    -- Execute all commands in sequence regardless of failures.
    local compound_command = {
        type = defines.command.compound,
        structure_type = defines.compound_command.return_last,
        commands = combined_commands
    }

    -- Temporary fix?
    temp_group.set_command(compound_command)
end

return Public
