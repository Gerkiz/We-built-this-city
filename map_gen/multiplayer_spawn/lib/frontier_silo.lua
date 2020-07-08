-- frontier_silo.lua
-- Jan 2018
-- My take on frontier silos for my Oarc scenario

require('map_gen.multiplayer_spawn.config')
local Utils = require('map_gen.multiplayer_spawn.lib.oarc_utils')
local surface_name = require 'utils.surface'.get_surface_name()
local MPS = require 'map_gen.multiplayer_spawn.lib.table'

--------------------------------------------------------------------------------
-- Frontier style rocket silo stuff
--------------------------------------------------------------------------------

local Public = {}

function Public.SpawnSilosAndGenerateSiloAreas()
    -- Special silo islands mode "boogaloo"
    if (global.silo_island_mode) then
        -- A set of fixed silo positions
        local num_spawns = #global.vanillaSpawns
        local new_spawn_list = {}

        -- Pick out every OTHER vanilla spawn for the rocket silos.
        for k, v in pairs(global.vanillaSpawns) do
            if ((k <= num_spawns / 2) and (k % 2 == 1)) then
                Public.SetFixedSiloPosition({x = v.x, y = v.y})
            elseif ((k > num_spawns / 2) and (k % 2 == 0)) then
                Public.SetFixedSiloPosition({x = v.x, y = v.y})
            else
                table.insert(new_spawn_list, v)
            end
        end
        global.vanillaSpawns = new_spawn_list
    elseif (global.silo_fixed_pos) then
        -- Random locations on a circle.
        for k, v in pairs(global.silo_pos) do
            Public.SetFixedSiloPosition(v)
        end
    else
        Public.SetRandomSiloPosition(global.silo_spawns)
    end

    -- Freezes the game at the start to generate all the chunks.
    Public.GenerateRocketSiloAreas(game.surfaces[surface_name])
end

-- This creates a random silo position, stored to global.siloPosition
-- It uses the config setting global.silo_distance and spawns the
-- silo somewhere on a circle edge with radius using that distance.
function Public.SetRandomSiloPosition(num_silos)
    local global_data = MPS.get()
    if (global.siloPosition == nil) then
        global.siloPosition = {}
    end

    global_data.random_angle_offset = math.random(0, math.pi * 2)

    for i = 1, num_silos do
        global_data.theta = ((math.pi * 2) / num_silos)
        global_data.angle = (global_data.theta * i) + global_data.random_angle_offset

        global_data.tx = (global.silo_distance * global_data.chunk_size * math.cos(global_data.angle))
        global_data.ty = (global.silo_distance * global_data.chunk_size * math.sin(global_data.angle))

        table.insert(global.siloPosition, {x = math.floor(global_data.tx), y = math.floor(global_data.ty)})

        --log("Silo position: " .. global_data.tx .. ", " .. global_data.ty .. ", " .. global_data.angle)
    end
end

-- Sets the global.siloPosition var to the set in the config file
function Public.SetFixedSiloPosition(pos)
    table.insert(global.siloPosition, pos)
end

-- Create a rocket silo at the specified positionmmmm
-- Also makes sure tiles and entities are cleared if required.
local function CreateRocketSilo(surface, siloPosition, force)
    local global_data = MPS.get()

    -- Delete any entities beneath the silo?
    for _, entity in pairs(
        surface.find_entities_filtered {
            area = {
                {
                    siloPosition.x - 5,
                    siloPosition.y - 6
                },
                {
                    siloPosition.x + 6,
                    siloPosition.y + 6
                }
            }
        }
    ) do
        entity.destroy()
    end

    -- Remove nearby enemies again
    for _, entity in pairs(
        surface.find_entities_filtered {
            area = {
                {
                    siloPosition.x - (global_data.chunk_size * 4),
                    siloPosition.y - (global_data.chunk_size * 4)
                },
                {
                    siloPosition.x + (global_data.chunk_size * 4),
                    siloPosition.y + (global_data.chunk_size * 4)
                }
            },
            force = 'enemy'
        }
    ) do
        entity.destroy()
    end

    -- Set tiles below the silo
    local tiles = {}
    for dx = -10, 10 do
        for dy = -10, 10 do
            if (game.active_mods['oarc-restricted-build']) then
                table.insert(
                    tiles,
                    {
                        name = global.ocfg.locked_build_area_tile,
                        position = {siloPosition.x + dx, siloPosition.y + dy}
                    }
                )
            else
                if ((dx % 2 == 0) or (dx % 2 == 0)) then
                    table.insert(
                        tiles,
                        {
                            name = 'concrete',
                            position = {siloPosition.x + dx, siloPosition.y + dy}
                        }
                    )
                else
                    table.insert(
                        tiles,
                        {
                            name = 'hazard-concrete-left',
                            position = {siloPosition.x + dx, siloPosition.y + dy}
                        }
                    )
                end
            end
        end
    end
    surface.set_tiles(tiles, true)

    -- Create indestructible silo and assign to a force
    if not global.enable_silo_player_build then
        local silo =
            surface.create_entity {
            name = 'rocket-silo',
            position = {siloPosition.x + 0.5, siloPosition.y},
            force = force
        }
        silo.destructible = false
        silo.minable = false
    end

    -- TAG it on the main force at least.
    game.forces[global.main_force_name].add_chart_tag(
        game.surfaces[surface_name],
        {
            position = siloPosition,
            text = 'Rocket Silo',
            icon = {type = 'item', name = 'rocket-silo'}
        }
    )

    if global.enable_silo_beacon then
        Public.PhilipsBeacons(surface, siloPosition, game.forces[global.main_force_name])
    end
    if global.enable_silo_radar then
        Public.PhilipsRadar(surface, siloPosition, game.forces[global.main_force_name])
    end
end

-- Generates all rocket silos, should be called after the areas are generated
-- Includes a crop circle
function Public.GenerateAllSilos(surface)
    -- Create each silo in the list
    for _, siloPos in pairs(global.siloPosition) do
        CreateRocketSilo(surface, siloPos, global.main_force_name)
    end
end

-- Validates any attempt to build a silo.
-- Should be call in on_built_entity and on_robot_built_entity
function Public.BuildSiloAttempt(event)
    -- Validation
    if (event.created_entity == nil) then
        return
    end

    local e_name = event.created_entity.name
    if (event.created_entity.name == 'entity-ghost') then
        e_name = event.created_entity.ghost_name
    end

    if (e_name ~= 'rocket-silo') then
        return
    end

    -- Check if it's in the right area.
    local epos = event.created_entity.position

    for k, v in pairs(global.siloPosition) do
        if (Utils.getDistance(epos, v) < 5) then
            Utils.SendBroadcastMsg('Rocket silo has been built!')
            return
        end
    end

    -- If we get here, means it wasn't in a valid position. Need to remove it.
    if (event.created_entity.last_user ~= nil) then
        Utils.FlyingText(
            "Can't build silo here! Check the map!",
            epos,
            Utils.my_color_red,
            event.created_entity.surface
        )
        if (event.created_entity.name == 'entity-ghost') then
            event.created_entity.destroy()
        else
            event.created_entity.last_user.mine_entity(event.created_entity, true)
        end
    else
        --log("ERROR! Rocket-silo had no valid last user?!?!")
    end
end

-- Generate clean land and trees around silo area on chunk generate event
function Public.GenerateRocketSiloChunk(event)
    local global_data = MPS.get()

    -- Silo generation can take awhile depending on the number of silos.
    if (game.tick < #global.siloPosition * 10 * global_data.ticks_per_second) then
        local surface = event.surface
        local chunkArea = event.area

        local chunkAreaCenter = {
            x = chunkArea.left_top.x + (global_data.chunk_size / 2),
            y = chunkArea.left_top.y + (global_data.chunk_size / 2)
        }

        for i, siloPos in pairs(global.siloPosition) do
            local safeArea = {
                left_top = {
                    x = siloPos.x - (global_data.chunk_size * 4),
                    y = siloPos.y - (global_data.chunk_size * 4)
                },
                right_bottom = {
                    x = siloPos.x + (global_data.chunk_size * 4),
                    y = siloPos.y + (global_data.chunk_size * 4)
                }
            }

            -- Clear enemies directly next to the rocket
            if Utils.CheckIfInArea(chunkAreaCenter, safeArea) then
                for _, entity in pairs(surface.find_entities_filtered {area = chunkArea, force = 'enemy'}) do
                    entity.destroy()
                end

                -- Remove trees/resources inside the spawn area
                Utils.RemoveInCircle(
                    surface,
                    chunkArea,
                    'tree',
                    siloPos,
                    global.scenario_config.gen_settings.land_area_tiles + 5
                )
                Utils.RemoveInCircle(
                    surface,
                    chunkArea,
                    'resource',
                    siloPos,
                    global.scenario_config.gen_settings.land_area_tiles + 5
                )
                Utils.RemoveInCircle(
                    surface,
                    chunkArea,
                    'cliff',
                    siloPos,
                    global.scenario_config.gen_settings.land_area_tiles + 5
                )
                Utils.RemoveDecorationsArea(surface, chunkArea)

                -- Create rocket silo
                Utils.CreateCropOctagon(surface, siloPos, chunkArea, global_data.chunk_size * 2, 'grass-1')
            end
        end
    end
end

-- Generate chunks where we plan to place the rocket silos.
function Public.GenerateRocketSiloAreas(surface)
    for _, siloPos in pairs(global.siloPosition) do
        surface.request_to_generate_chunks({siloPos.x, siloPos.y}, 3)
    end
    if (global.enable_silo_vision) then
        Public.ChartRocketSiloAreas(surface, game.forces[global.main_force_name])
    end
end

-- Chart chunks where we plan to place the rocket silos.
function Public.ChartRocketSiloAreas(surface, force)
    local global_data = MPS.get()
    for _, siloPos in pairs(global.siloPosition) do
        force.chart(
            surface,
            {
                {
                    siloPos.x - (global_data.chunk_size * 2),
                    siloPos.y - (global_data.chunk_size * 2)
                },
                {
                    siloPos.x + (global_data.chunk_size * 2),
                    siloPos.y + (global_data.chunk_size * 2)
                }
            }
        )
    end
end

global.oarc_silos_generated = false
function Public.DelayedSiloCreationOnTick(surface)
    local global_data = MPS.get()

    -- Delay the creation of the silos so we place them on already generated lands.
    if (not global.oarc_silos_generated and (game.tick >= #global.siloPosition * 10 * global_data.ticks_per_second)) then
        --log("Frontier silos generated!")
        Utils.SendBroadcastMsg('Rocket silos are now available and can be built!')
        global.oarc_silos_generated = true
        Public.GenerateAllSilos(surface)
    end
end

function Public.PhilipsBeacons(surface, siloPos, force)
    -- Add Beacons
    -- x = right, left; y = up, down
    -- top 1 left 1
    local beacon
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 8, siloPos.y - 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- top 2
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 5, siloPos.y - 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- top 3
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 2, siloPos.y - 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- top 4
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 2, siloPos.y - 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- top 5
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 5, siloPos.y - 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- top 6 right 1
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 8, siloPos.y - 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- left 2
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 8, siloPos.y - 5}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- left 3
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 8, siloPos.y - 2}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- left 4
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 8, siloPos.y + 2}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- left 5
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 8, siloPos.y + 5}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- left 6 bottom 1
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 8, siloPos.y + 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- left 7 bottom 2
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x - 5, siloPos.y + 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- right 2
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 8, siloPos.y - 5}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- right 3
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 8, siloPos.y - 2}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- right 4
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 8, siloPos.y + 2}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- right 5
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 8, siloPos.y + 5}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- right 6 bottom 3
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 5, siloPos.y + 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- right 7 bottom 4
    beacon = surface.create_entity {name = 'beacon', position = {siloPos.x + 8, siloPos.y + 8}, force = force}
    beacon.destructible = false
    beacon.minable = false
    -- substations
    local substation
    -- top left
    substation = surface.create_entity {name = 'substation', position = {siloPos.x - 5, siloPos.y - 5}, force = force}
    substation.destructible = false
    substation.minable = false
    -- top right
    substation = surface.create_entity {name = 'substation', position = {siloPos.x + 6, siloPos.y - 5}, force = force}
    substation.destructible = false
    substation.minable = false
    -- bottom left
    substation = surface.create_entity {name = 'substation', position = {siloPos.x - 5, siloPos.y + 6}, force = force}
    substation.destructible = false
    substation.minable = false
    -- bottom right
    substation = surface.create_entity {name = 'substation', position = {siloPos.x + 6, siloPos.y + 6}, force = force}
    substation.destructible = false
    substation.minable = false

    -- end adding beacons
end

function Public.PhilipsRadar(surface, siloPos, force)
    local radar
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 43, siloPos.y + 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 43, siloPos.y - 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 40, siloPos.y - 6}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 37, siloPos.y - 6}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 34, siloPos.y - 6}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 34, siloPos.y - 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 34, siloPos.y}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 34, siloPos.y + 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 43, siloPos.y - 6}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 40, siloPos.y + 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'solar-panel', position = {siloPos.x - 37, siloPos.y + 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'radar', position = {siloPos.x - 43, siloPos.y}, force = force}
    radar.destructible = false
    local substation =
        surface.create_entity {name = 'substation', position = {siloPos.x - 38, siloPos.y - 1}, force = force}
    substation.destructible = false
    radar = surface.create_entity {name = 'accumulator', position = {siloPos.x - 40, siloPos.y - 1}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'accumulator', position = {siloPos.x - 40, siloPos.y - 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'accumulator', position = {siloPos.x - 40, siloPos.y + 1}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'accumulator', position = {siloPos.x - 38, siloPos.y - 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'accumulator', position = {siloPos.x - 38, siloPos.y + 1}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'accumulator', position = {siloPos.x - 36, siloPos.y - 1}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'accumulator', position = {siloPos.x - 36, siloPos.y - 3}, force = force}
    radar.destructible = false
    radar = surface.create_entity {name = 'accumulator', position = {siloPos.x - 36, siloPos.y + 1}, force = force}
    radar.destructible = false
end

return Public
