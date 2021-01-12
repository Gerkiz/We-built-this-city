-- oarc_enemies_tick_logic.lua
-- Aug 2019
--
-- Holds all the code related to the the on_tick "state machine"
-- Where we process on going attacks step by step.
local MPS = require 'map_gen.multiplayer_spawn.table'
local OE_Table = require 'features.modules.oarc_enemies.table'
local Utils = require 'map_gen.multiplayer_spawn.oarc_utils'
local OE = require 'features.modules.oarc_enemies.oarc_enemies'
local Evo = require 'features.modules.oarc_enemies.oarc_enemies_evo'
local Surface = require 'utils.surface'

local Public = {}

function Public.OarcEnemiesOnTick()
    local global_data = MPS.get()
    local gd = OE_Table.get_table()

    if gd.disable then
        gd.attacks = {}
        goto continue
    end

    -- Cleanup attacks that have died or somehow become invalid.
    if ((game.tick % (global_data.ticks_per_second)) == 20) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackCleanupInvalidGroups(key, attack) then
                break
            end
        end
    end

    -- Process player timers
    if ((game.tick % (global_data.ticks_per_second)) == 21) then
        Public.ProcessPlayerTimersEverySecond()
    end

    -- process_find_target
    -- Find target given request type
    if ((game.tick % (global_data.ticks_per_second)) == 22) then
        for key, attack in pairs(gd.attacks) do
            if not key then
                break
            end
            if not attack then
                break
            end
            if Public.ProcessAttackFindTarget(key, attack) then
                break
            end
        end
    end

    -- process_find_spawn
    -- Find spawn location
    if ((game.tick % (global_data.ticks_per_second)) == 23) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackFindSpawn(key, attack) then
                break
            end
        end
    end

    -- process_find_spawn_path_req
    -- Find path
    if ((game.tick % (global_data.ticks_per_second)) == 24) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackCheckPathFromSpawn(key, attack) then
                break
            end
        end
    end

    -- process_find_spawn_path_calc -- WAIT FOR EVENT
    -- Event Function: ProcessAttackCheckPathComplete(event)

    -- process_find_create_group
    -- Spawn group
    if ((game.tick % (global_data.ticks_per_second)) == 25) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackCreateGroup(key, attack) then
                break
            end
        end
    end

    -- process_find_command_group
    -- Send group on attack
    if ((game.tick % (global_data.ticks_per_second)) == 26) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackCommandGroup(key, attack) then
                break
            end
        end
    end

    -- process_find_group_active -- ACTIVE STATE, WAIT FOR EVENT
    -- Event Function: OarcEnemiesGroupCmdFailed(event)

    -- process_find_command_failed
    -- Handle failed groups?
    if ((game.tick % (global_data.ticks_per_second)) == 27) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackCommandFailed(key, attack) then
                break
            end
        end
    end

    -- process_find_fallback_attack
    -- Attempt fallback attack on general area of target
    if ((game.tick % (global_data.ticks_per_second)) == 28) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackFallbackAttack(key, attack) then
                break
            end
        end
    end

    -- process_find_fallback_final
    -- Final fallback just abandons attack and sets the group to autonomous
    if ((game.tick % (global_data.ticks_per_second)) == 29) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackFallbackAuto(key, attack) then
                break
            end
        end
    end

    -- process_find_retry_path_req
    -- Handle pathing retries
    if ((game.tick % (global_data.ticks_per_second)) == 30) then
        for key, attack in pairs(gd.attacks) do
            if Public.ProcessAttackRetryPath(key, attack) then
                break
            end
        end
    end

    --if ((game.tick % (global_data.ticks_per_second)) == 31) then
    --    for _, p in pairs(game.connected_players) do
    --    if gd.buildings[p.name] == nil then return end
    --        for k, v in pairs(gd.buildings[p.name]) do
    --            if not v.valid then
    --                gd.buildings[p.name][k] = nil
    --            end
    --        end
    --    end
    --end

    -- process_find_retry_path_calc -- WAIT FOR EVENT
    -- Event Function: ProcessAttackCheckPathComplete(event)

    ::continue::
end

function Public.ProcessAttackCleanupInvalidGroups(key, attack)
    local gd = OE_Table.get_table()
    if (attack.process_stg ~= gd.process_find_group_active) and (attack.process_stg ~= gd.process_find_build_base) then
        return false
    end

    if (not attack.group or not attack.group.valid) then
        if gd.debug then
            log('ProcessAttackCleanupInvalidGroups - Group killed?')
        end
        gd.attacks[key] = nil
        return true
    elseif (attack.group.state == defines.group_state.wander_in_group) then
        if gd.debug then
            log('ProcessAttackCleanupInvalidGroups - Group done (wandering)?')
        end
        OE.EnemyGroupBuildBaseThenWander(attack.group, attack.group.position)
        gd.attacks[key].process_stg = gd.process_find_build_base
        return true
    end

    for k, group in pairs(gd.groups) do
        if not group.valid then
            gd.groups[k] = nil
        end
    end

    return false
end

function Public.ProcessPlayerTimersEverySecond()
    local gd = OE_Table.get_table()
    local global_data = MPS.get()
    for name, timer_table in pairs(gd.p_time) do
        if (game.players[name] and game.players[name].connected) then
            for timer_name, timer in pairs(timer_table) do
                if (timer > 0) then
                    gd.p_time[name][timer_name] = timer - 1
                else
                    if (timer_name == 'next_wave_player') then
                        OE.OarcEnemiesPlayerAttackCharacter(name)
                        if _DEBUG then
                            gd.p_time[name][timer_name] = 50
                        else
                            gd.p_time[name][timer_name] =
                                (Evo.GetRandomizedPlayerTimer(
                                game.players[name].online_time / global_data.ticks_per_second,
                                0
                            ) + gd.next_wave)
                        end

                    --elseif (timer_name == "next_wave_buildings") then
                    --    OE.OarcEnemiesBuildingAttack(name, gd.enemy_targets)
                    --    gd.p_time[name][timer_name] = (Evo.GetRandomizedPlayerTimer(game.players[name].online_time/global_data.ticks_per_second, 0) + gd.next_wave)
                    end
                end
            end
        end
    end
end

function Public.ProcessAttackFindTarget(key, attack)
    local gd = OE_Table.get_table()
    local s_name = Surface.get_surface_name()

    if (attack.process_stg ~= gd.process_find_target) then
        return false
    end

    -- log("tick_log ProcessAttackFindTarget " .. game.tick)

    if (attack.attempts == 0) then
        if gd.debug then
            log('attack.attempts = 0 - ATTACK FAILURE')
        end
        gd.attacks[key] = nil
        return false
    end

    if (attack.target_player and attack.target_type) then
        local player = game.players[attack.target_player]

        -- Attack a building of the player, given a certain building type
        if (attack.target_type == gd.type_target_player) then
            gd.attacks[key].target_entity = player.character

            local e, s =
                Evo.GetEnemyGroup {
                player = player,
                force_name = player.force.name,
                surface = game.surfaces[s_name],
                target_pos = player.position
            }

            gd.attacks[key].size = s
            gd.attacks[key].evo = e
            gd.attacks[key].process_stg = gd.process_find_spawn
            return true
        end
    else
        if gd.debug then
            log('ERROR - Missing info in attack - target_player or target_type!' .. key)
        end
    end

    return false
end

function Public.ProcessAttackFindSpawn(key, attack)
    local gd = OE_Table.get_table()

    if (attack.process_stg ~= gd.process_find_spawn) then
        return false
    end

    -- log("tick_log ProcessAttackFindSpawn " .. game.tick)

    if (attack.attempts == 0) then
        if gd.debug then
            log('attack.attempts = 0 - ProcessAttackFindSpawn FAILURE')
        end
        gd.attacks[key] = nil
        return false
    end

    if (attack.target_entity or attack.target_chunk) then
        -- Invalid entity check?
        if (attack.target_entity and not attack.target_entity.valid) then
            gd.attacks[key].target_entity = nil
            gd.attacks[key].attempts = attack.attempts - 1
            gd.attacks[key].process_stg = gd.process_find_target
            return false
        end

        -- Use entity or target chunk info to start search
        local c_pos
        if (attack.target_entity) then
            c_pos = Utils.GetChunkPosFromTilePos(attack.target_entity.position)
            gd.attacks[key].target_chunk = c_pos -- ALWAYS SET FOR BACKUP
        elseif (attack.target_chunk) then
            c_pos = attack.target_chunk
        end
        local spawns = OE.SpiralSearch(c_pos, gd.search_radius_chunks, 500)

        if (spawns ~= nil) then
            gd.attacks[key].spawn_chunk = spawns[Utils.GetRandomKeyFromTable(spawns)]
            gd.attacks[key].process_stg = gd.process_find_spawn_path_req
        else
            if gd.debug then
                log('Could not find a spawn near target...')
            end
            gd.attacks[key].target_entity = nil
            gd.attacks[key].attempts = attack.attempts - 1
            gd.attacks[key].process_stg = gd.process_find_target
        end

        return true
    else
        if gd.debug then
            log('Missing attack info: target_entity or target_chunk!' .. key)
        end
    end

    return false
end

function Public.ProcessAttackCheckPathFromSpawn(key, attack)
    local gd = OE_Table.get_table()
    local s_name = Surface.get_surface_name()

    if (attack.process_stg ~= gd.process_find_spawn_path_req) then
        return false
    end

    -- log("tick_log ProcessAttackCheckPathFromSpawn " .. game.tick)

    if (attack.attempts == 0) then
        if gd.debug then
            log('attack.attempts = 0 - ProcessAttackCheckPathFromSpawn FAILURE')
        end
        gd.attacks[key] = nil
        return false
    end

    if (attack.spawn_chunk) then
        -- Check group doesn't already exist
        if (attack.group and attack.group_id and attack.group.valid) then
            if gd.debug then
                log('ERROR - group should not be valid - ProcessAttackCheckPathFromSpawn!')
            end
            gd.attacks[key] = nil
            return false
        end

        -- Find a large area that is free to spawn biters in
        local spawn_pos =
            game.surfaces[s_name].find_non_colliding_position(
            'rocket-silo',
            Utils.GetCenterTilePosFromChunkPos(attack.spawn_chunk),
            32,
            1
        )
        gd.attacks[key].spawn_pos = spawn_pos

        if (not spawn_pos) then
            if gd.debug then
                log('No space to spawn? ProcessAttackCheckPathFromSpawn')
            end
            gd.attacks[key].attempts = attack.attempts - 1
            return false
        end

        local target_pos = nil
        if (attack.target_entity and attack.target_entity.valid) then
            target_pos = attack.target_entity.position
        elseif (attack.target_chunk) then
            target_pos = Utils.GetCenterTilePosFromChunkPos(attack.target_chunk)
        end

        if (not target_pos) then
            if gd.debug then
                log('Lost target during ProcessAttackCheckPathFromSpawn')
            end
            gd.attacks[key].target_entity = nil
            gd.attacks[key].target_chunk = nil
            gd.attacks[key].attempts = attack.attempts - 1
            gd.attacks[key].process_stg = gd.process_find_target
            return false
        end

        gd.attacks[key].path_id =
            game.surfaces[s_name].request_path {
            bounding_box = {{0, 0}, {0, 0}},
            collision_mask = {'player-layer'},
            start = spawn_pos,
            goal = target_pos,
            force = game.forces['enemy'],
            radius = 8,
            pathfind_flags = {low_priority = true},
            can_open_gates = false,
            path_resolution_modifier = -1
        }
        gd.attacks[key].process_stg = gd.process_find_spawn_path_calc
        return true
    else
        if gd.debug then
            log('ERROR - Missing attack info: spawn_chunk or path_id!' .. key)
        end
    end

    return false
end

function Public.ProcessAttackCheckPathComplete(event)
    local gd = OE_Table.get_table()
    local global_data = MPS.get()
    if (not event.id) then
        return
    end
    local path_success = (event.path ~= nil)

    -- Debug help info
    if (path_success) then
        if (gd.render_paths) then
            Utils.RenderPath(event.path, global_data.ticks_per_minute, game.connected_players)
        end
    else
        if gd.debug then
            log('ERROR - on_script_path_request_finished: FAILED')
            if (event.try_again_later) then
                log('ERROR - on_script_path_request_finished: TRY AGAIN LATER?')
            end
        end
    end

    for key, attack in pairs(gd.attacks) do
        if (attack.path_id == event.id) then
            local group_exists_already = (attack.group and attack.group_id and attack.group.valid)

            -- First time path check before a group is spawned
            if (attack.process_stg == gd.process_find_spawn_path_calc) then
                -- Retry path check on a command failure
                if (group_exists_already) then
                    if gd.debug then
                        log('ERROR - gd.process_find_spawn_path_calc has a valid group?!')
                    end
                end

                if (path_success) then
                    gd.attacks[key].path = event.path
                    gd.attacks[key].process_stg = gd.process_find_create_group
                else
                    gd.attacks[key].path_id = nil
                    gd.attacks[key].attempts = attack.attempts - 1
                    gd.attacks[key].process_stg = gd.process_find_target
                end
            elseif (attack.process_stg == gd.process_find_retry_path_calc) then
                if (not group_exists_already) then
                    if gd.debug then
                        log('ERROR - process_find_retry_path_calc has NO valid group?!')
                    end
                end

                if (path_success) then
                    gd.attacks[key].path = event.path
                    gd.attacks[key].process_stg = gd.process_find_command_group
                else
                    if gd.debug then
                        log(
                            'Group can no longer path to target. Performing fallback attack instead' ..
                                attack.group.group_id
                        )
                    end
                    gd.attacks[key].path_id = nil
                    gd.attacks[key].attempts = attack.attempts - 1
                    gd.attacks[key].process_stg = gd.process_find_fallback_attack
                end
            else
                if gd.debug then
                    log('Path calculated but process stage is wrong!??!')
                end
            end

            return
        end
    end
end

function Public.ProcessAttackCreateGroup(key, attack)
    local gd = OE_Table.get_table()
    local s_name = Surface.get_surface_name()
    if (attack.process_stg ~= gd.process_find_create_group) then
        return false
    end

    -- log("tick_log ProcessAttackCreateGroup " .. game.tick)

    if (attack.attempts == 0) then
        if gd.debug then
            log('attack.attempts = 0 - ProcessAttackCreateGroup FAILURE')
        end
        gd.attacks[key] = nil
        return false
    end

    if (attack.group_id == nil) then
        local group =
            OE.CreateEnemyGroupGivenEvoAndCount(game.surfaces[s_name], attack.spawn_pos, attack.evo, attack.size)
        gd.attacks[key].group_id = group.group_number
        gd.attacks[key].group = group
        gd.attacks[key].process_stg = gd.process_find_command_group

        -- On the first time the player has a direct attack, warn them?
        if (attack.target_type == gd.type_target_player) and (not gd.player_sbubbles[attack.target_player].uh_oh) then
            if
                (gd.player_sbubbles[attack.target_player].wave < 10) or
                    ((gd.player_sbubbles[attack.target_player].wave < 50) and
                        ((gd.player_sbubbles[attack.target_player].wave % 5) == 0)) or
                    ((gd.player_sbubbles[attack.target_player].wave % 25) == 0)
             then
                gd.player_sbubbles[attack.target_player].wave = gd.player_sbubbles[attack.target_player].wave + 1
                Utils.DisplaySpeechBubble(
                    game.players[attack.target_player],
                    '>> Biters are headed my way! Round: ' .. gd.player_sbubbles[attack.target_player].wave .. ' <<',
                    15
                )
            end
        end

        return true
    else
        if gd.debug then
            log('ERROR - ProcessAttackCreateGroup already has a group?' .. key)
        end
    end

    return false
end

function Public.ProcessAttackCommandGroup(key, attack)
    local gd = OE_Table.get_table()
    local global_data = MPS.get()
    if (attack.process_stg ~= gd.process_find_command_group) then
        return false
    end

    -- log("tick_log ProcessAttackCommandGroup " .. game.tick)

    if (attack.attempts == 0) then
        if gd.debug then
            log('attack.attempts = 0 - ProcessAttackCommandGroup FAILURE')
        end
        gd.attacks[key] = nil
        return false
    end

    -- Sanity check we have a group and a path
    if (attack.group_id and attack.group and attack.group.valid) then
        -- If we have a target entity, attack that.
        if (attack.target_entity and attack.target_entity.valid and attack.path_id) then
            -- If we have a target chunk, attack that area.
            OE.EnemyGroupGoAttackEntityThenWander(attack.group, attack.target_entity, attack.path)
            gd.attacks[key].process_stg = gd.process_find_group_active
            return true
        elseif (attack.target_chunk) then
            -- Otherwise, shit's fucked
            OE.EnemyGroupAttackAreaThenWander(
                attack.group,
                Utils.GetCenterTilePosFromChunkPos(attack.target_chunk),
                global_data.chunk_size * 2
            )
            gd.attacks[key].process_stg = gd.process_find_group_active
            return true
        else
            if gd.debug then
                log('ProcessAttackCommandGroup invalid target?' .. key)
            end
            gd.attacks[key].path_id = nil
            gd.attacks[key].attempts = attack.attempts - 1
            gd.attacks[key].process_stg = gd.process_find_target
            return false
        end
    else
        if gd.debug then
            log('ProcessAttackCommandGroup invalid group?' .. key)
        end
    end

    return false
end

function Public.OarcEnemiesGroupCmdFailed(event)
    local gd = OE_Table.get_table()
    local attack_key = OE.FindAttackKeyFromGroupIdNumber(event.unit_number)

    -- This group cmd failure is not associated with an attack. Must be a unit or something.
    if (not attack_key) then
        return
    end

    local attack = gd.attacks[attack_key]

    -- Is group no longer valid?
    if (not attack.group or not attack.group.valid) then
        if gd.debug then
            log('OarcEnemiesGroupCmdFailed group not valid anymore')
        end
        gd.attacks[attack_key] = nil
        return
    end

    -- Check if it's a fallback attack.
    if (attack.target_type == gd.type_target_area) then
        -- Else handle failure based on attack type.
        gd.attacks[attack_key].process_stg = gd.process_find_fallback_final
    else
        gd.attacks[attack_key].process_stg = gd.process_find_command_failed
    end
end

function Public.ProcessAttackCommandFailed(key, attack)
    local gd = OE_Table.get_table()
    if (attack.process_stg ~= gd.process_find_command_failed) then
        return false
    end

    -- log("tick_log ProcessAttackCommandFailed " .. game.tick)

    if (attack.attempts == 0) then
        if gd.debug then
            log('attack.attempts = 0 - ProcessAttackCommandFailed FAILURE')
        end
        gd.attacks[key] = nil
        return false
    end

    -- If we fail to attack the player, it likely means the player moved.
    -- So we try to retry pathing so we can "chase" the player.
    if (attack.target_type == gd.type_target_player) then
        -- Fallback for all other attack types is to attack the general area instead.
        -- Might add other special cases here later.
        gd.attacks[key].process_stg = gd.process_find_retry_path_req
        return true
    else
        if gd.debug then
            log('ProcessAttackCommandFailed - performing fallback now?')
        end
        gd.attacks[key].attempts = attack.attempts - 1
        gd.attacks[key].process_stg = gd.process_find_fallback_attack
        return true
    end
end

function Public.ProcessAttackFallbackAttack(key, attack)
    local gd = OE_Table.get_table()
    local global_data = MPS.get()
    if (attack.process_stg ~= gd.process_find_fallback_attack) then
        return false
    end

    -- log("tick_log ProcessAttackFallbackAttack " .. game.tick)

    if (attack.group_id and attack.group and attack.group.valid and attack.target_chunk) then
        OE.EnemyGroupAttackAreaThenWander(
            attack.group,
            Utils.GetCenterTilePosFromChunkPos(attack.target_chunk),
            global_data.chunk_size * 2
        )
        gd.attacks[key].target_type = gd.type_target_area
        gd.attacks[key].process_stg = gd.process_find_group_active
        return true
    else
        if gd.debug then
            log('ProcessAttackFallbackAttack invalid group or target?' .. key)
            gd.attacks[key] = nil
        end
    end

    return false
end

function Public.ProcessAttackFallbackAuto(key, attack)
    local gd = OE_Table.get_table()
    if (attack.process_stg ~= gd.process_find_fallback_final) then
        return false
    end

    -- log("tick_log ProcessAttackFallbackAuto " .. game.tick)

    if (attack.group and attack.group.valid) then
        if gd.debug then
            log('ProcessAttackFallbackAuto - Group now autonomous...')
        end
        attack.group.set_autonomous()
    else
        if gd.debug then
            log('ProcessAttackFallbackAuto - Group no longer valid!')
        end
    end

    gd.attacks[key] = nil
    return true
end

function Public.ProcessAttackRetryPath(key, attack)
    local gd = OE_Table.get_table()
    local s_name = Surface.get_surface_name()

    if (attack.process_stg ~= gd.process_find_retry_path_req) then
        return false
    end

    -- log("tick_log ProcessAttackRetryPath " .. game.tick)

    -- Validation checks
    if
        ((attack.target_type ~= gd.type_target_player) or (attack.attempts == 0) or (not attack.target_entity) or
            (not attack.target_entity.valid))
     then
        if gd.debug then
            log('ProcessAttackRetryPath FAILURE')
        end
        if (attack.group and attack.group.valid) then
            attack.group.set_autonomous()
        end
        gd.attacks[key] = nil
        return false
    end

    -- Check group still exists
    if (attack.group and attack.group_id and attack.group.valid and attack.group.members) then
        if not (attack.group.members[1] and attack.group.members[1].valid) then
            return
        end

        -- Path request
        gd.attacks[key].path_id =
            game.surfaces[s_name].request_path {
            bounding_box = {{0, 0}, {0, 0}},
            collision_mask = {'player-layer'},
            start = attack.group.members[1].position,
            goal = attack.target_entity.position,
            force = game.forces['enemy'],
            radius = 8,
            pathfind_flags = {low_priority = true},
            can_open_gates = false,
            path_resolution_modifier = -1
        }
        gd.attacks[key].process_stg = gd.process_find_retry_path_calc
        return true
    else
        if gd.debug then
            log('ERROR - group should BE valid - ProcessAttackRetryPath!')
        end
        gd.attacks[key] = nil
        return false
    end
end

return Public
