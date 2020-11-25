local f = require 'features.tools.map_functions'
local math_random = math.random
local insert = table.insert

--------------------------------------------------------------------------------
-- Useful constants
--------------------------------------------------------------------------------
CHUNK_SIZE = 32
MAX_FORCES = 64
TICKS_PER_SECOND = 60
TICKS_PER_MINUTE = TICKS_PER_SECOND * 60
TICKS_PER_HOUR = TICKS_PER_MINUTE * 60
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- GUI Label Styles
--------------------------------------------------------------------------------
my_fixed_width_style = {
    minimal_width = 450,
    maximal_width = 450
}
my_label_style = {
    -- minimal_width = 450,
    -- maximal_width = 50,
    single_line = false,
    font_color = {r = 1, g = 1, b = 1},
    top_padding = 0,
    bottom_padding = 0
}
my_note_style = {
    -- minimal_width = 450,
    single_line = false,
    font = 'default-small-semibold',
    font_color = {r = 1, g = 0.5, b = 0.5},
    top_padding = 0,
    bottom_padding = 0
}
my_warning_style = {
    -- minimal_width = 450,
    -- maximal_width = 450,
    single_line = false,
    font_color = {r = 243, g = 184, b = 184},
    top_padding = 0,
    bottom_padding = 0
}
my_spacer_style = {
    minimal_height = 10,
    font_color = {r = 0, g = 0, b = 0},
    top_padding = 0,
    bottom_padding = 0
}
my_small_button_style = {
    font = 'default-small-semibold'
}
my_player_list_fixed_width_style = {
    minimal_width = 200,
    maximal_width = 400,
    maximal_height = 200
}
my_player_list_admin_style = {
    font = 'default-semibold',
    font_color = {r = 1, g = 0.5, b = 0.5},
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
my_player_list_style = {
    font = 'default-semibold',
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
my_player_list_offline_style = {
    -- font = "default-semibold",
    font_color = {r = 0.5, g = 0.5, b = 0.5},
    minimal_width = 200,
    top_padding = 0,
    bottom_padding = 0,
    single_line = false
}
my_player_list_style_spacer = {
    minimal_height = 20
}
my_color_red = {r = 1, g = 0.1, b = 0.1}

my_longer_label_style = {
    maximal_width = 600,
    single_line = false,
    font_color = {r = 1, g = 1, b = 1},
    top_padding = 0,
    bottom_padding = 0
}
my_longer_warning_style = {
    maximal_width = 600,
    single_line = false,
    font_color = {r = 0.8, g = 0.1, b = 0.4},
    top_padding = 0,
    bottom_padding = 0
}

---------------------------------------
-- Starting Items
---------------------------------------
-- Items provided to the player the first time they join
PLAYER_SPAWN_START_ITEMS = {
    --{name="pistol", count=1},
    --{name="firearm-magazine", count=10},
    {name = 'iron-plate', count = 32},
    {name = 'burner-mining-drill', count = 4},
    {name = 'stone-furnace', count = 4}
    -- {name="iron-plate", count=20},
    -- {name="burner-mining-drill", count = 1},
    -- {name="stone-furnace", count = 1},
    -- {name="power-armor", count=1},
    -- {name="fusion-reactor-equipment", count=1},
    -- {name="battery-mk2-equipment", count=3},
    -- {name="exoskeleton-equipment", count=1},
    -- {name="personal-roboport-mk2-equipment", count=3},
    -- {name="solar-panel-equipment", count=7},
    -- {name="construction-robot", count=100},
    -- {name="repair-pack", count=100},
}

-- Items provided after EVERY respawn (disabled by default)
PLAYER_RESPAWN_START_ITEMS = {
    {name = 'iron-plate', count = 32}
}

--------------------------------------------------------------------------------
-- General Helper Functions
--------------------------------------------------------------------------------

-- Print debug only to me while testing.
function DebugPrint(msg)
    if ((game.players['Gerkiz'] ~= nil) and (global.DebugEnabled)) then
        game.players['Gerkiz'].print('DEBUG: ' .. msg)
    end
end

-- Prints flying text.
-- Color is optional
function FlyingText(msg, pos, color, surface)
    if color == nil then
        surface.create_entity({name = 'flying-text', position = pos, text = msg})
    else
        surface.create_entity({name = 'flying-text', position = pos, text = msg, color = color})
    end
end

-- Broadcast messages to all connected players
function SendBroadcastMsg(msg)
    for name, player in pairs(game.connected_players) do
        player.print(msg)
    end
end

-- Send a message to a player, safely checks if they exist and are online.
function SendMsg(playerName, msg)
    if ((game.players[playerName] ~= nil) and (game.players[playerName].connected)) then
        game.players[playerName].print(msg)
    end
end

-- Special case for ensuring that if I create the server, my messages are
-- used instead of the generic insert msg warning.
function SetServerWelcomeMessages()
    global.welcome_msg = WELCOME_MSG
    global.welcome_msg_title = WELCOME_MSG_TITLE
end

-- Useful for displaying game time in mins:secs format
function formattime(ticks)
    local seconds = ticks / 60
    local minutes = math.floor((seconds) / 60)
    local seconds = math.floor(seconds - 60 * minutes)
    return string.format('%dm:%02ds', minutes, seconds)
end

-- Useful for displaying game time in mins:secs format
function formattime_hours_mins(ticks)
    local seconds = ticks / 60
    local minutes = math.floor((seconds) / 60)
    local hours = math.floor((minutes) / 60)
    local minutes = math.floor(minutes - 60 * hours)
    return string.format('%dh:%02dm', hours, minutes)
end

-- Simple function to get total number of items in table
function TableLength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

-- Simple function to get distance between two positions.
function getDistance(posA, posB)
    -- Get the length for each of the components x and y
    local xDist = posB.x - posA.x
    local yDist = posB.y - posA.y

    return math.sqrt((xDist ^ 2) + (yDist ^ 2))
end

-- Chart area for a force
function ChartArea(force, position, chunkDist, surface)
    force.chart(
        surface,
        {
            {
                position.x - (CHUNK_SIZE * chunkDist),
                position.y - (CHUNK_SIZE * chunkDist)
            },
            {
                position.x + (CHUNK_SIZE * chunkDist),
                position.y + (CHUNK_SIZE * chunkDist)
            }
        }
    )
end

-- Give player these default items.
function GivePlayerItems(player)
    for _, item in pairs(PLAYER_RESPAWN_START_ITEMS) do
        player.insert(item)
    end
end

-- Starter only items
function GivePlayerStarterItems(player)
    for _, item in pairs(PLAYER_SPAWN_START_ITEMS) do
        player.insert(item)
    end

    if ENABLE_POWER_ARMOR_QUICK_START then
        GiveQuickStartPowerArmor(player)
    end
end

-- Cheater's quick start
function GiveQuickStartPowerArmor(player)
    player.insert {name = 'power-armor', count = 1}

    if player and player.get_inventory(5) ~= nil and player.get_inventory(5)[1] ~= nil then
        local p_armor = player.get_inventory(5)[1].grid --defines.inventory.player_armor = 5?
        if p_armor ~= nil then
            p_armor.put({name = 'fusion-reactor-equipment'})
            p_armor.put({name = 'exoskeleton-equipment'})
            p_armor.put({name = 'battery-mk2-equipment'})
            p_armor.put({name = 'battery-mk2-equipment'})
            p_armor.put({name = 'personal-roboport-mk2-equipment'})
            p_armor.put({name = 'personal-roboport-mk2-equipment'})
            p_armor.put({name = 'personal-roboport-mk2-equipment'})
            p_armor.put({name = 'battery-mk2-equipment'})
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
function GetAreaFromPointAndDistance(point, dist)
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
function CheckIfInArea(point, area)
    if ((point.x >= area.left_top.x) and (point.x < area.right_bottom.x)) then
        if ((point.y >= area.left_top.y) and (point.y < area.right_bottom.y)) then
            return true
        end
    end
    return false
end

-- Set all forces to ceasefire
function SetCeaseFireBetweenAllForces()
    for name, team in pairs(game.forces) do
        if name ~= 'neutral' and name ~= 'enemy' then
            for x, y in pairs(game.forces) do
                if x ~= 'neutral' and x ~= 'enemy' then
                    team.set_cease_fire(x, true)
                end
            end
        end
    end
end

-- Set all forces to friendly
function SetFriendlyBetweenAllForces()
    for name, team in pairs(game.forces) do
        if name ~= 'neutral' and name ~= 'enemy' then
            for x, y in pairs(game.forces) do
                if x ~= 'neutral' and x ~= 'enemy' then
                    team.set_friend(x, true)
                end
            end
        end
    end
end

function spawn_protected(event)
    local entity = event.created_entity
    if not entity.valid then
        return
    end
    local distance_to_center = math.sqrt(entity.position.x ^ 2 + entity.position.y ^ 2)
    if distance_to_center > 20 then
        return
    end
    local surface = entity.surface
    surface.create_entity(
        {name = 'flying-text', position = entity.position, text = 'Spawn is protected from building.', color = {r = 0.88, g = 0.1, b = 0.1}}
    )
    local player = game.players[event.player_index]
    player.insert({name = entity.name, count = 1})
    entity.destroy()
end

-- For each other player force, share a chat msg.
function ShareChatBetweenForces(player, msg)
    if player.tag ~= '[Renegades]' then
        return
    end
    for _, p in pairs(game.connected_players) do
        if p.tag == '[Renegades]' and p.name ~= player.name then
            p.print(player.name .. '[Renegades]: ' .. msg)
        end
    end
end

-- Merges force2 INTO force1 but keeps all research between both forces.
function MergeForcesKeepResearch(force1, force2)
    for techName, luaTech in pairs(force2.technologies) do
        if (luaTech.researched) then
            force1.technologies[techName].researched = true
            force1.technologies[techName].level = luaTech.level
        end
    end
    game.merge_forces(force2, force1)
end

-- Undecorator
function RemoveDecorationsArea(surface, area)
    surface.destroy_decoratives(area)
end

-- Remove fish
function RemoveFish(surface, area)
    for _, entity in pairs(surface.find_entities_filtered {area = area, type = 'fish'}) do
        entity.destroy()
    end
end

-- Apply a style option to a GUI
function ApplyStyle(guiIn, styleIn)
    for k, v in pairs(styleIn) do
        guiIn.style[k] = v
    end
end

-- Shorter way to add a label with a style
function AddLabel(guiIn, name, message, style)
    if guiIn[name] then
        return
    end
    guiIn.add {
        name = name,
        type = 'label',
        caption = message
    }
    ApplyStyle(guiIn[name], style)
end

-- Shorter way to add a spacer
function AddSpacer(guiIn, name)
    guiIn.add {
        name = name,
        type = 'label',
        caption = ' '
    }
    ApplyStyle(guiIn[name], my_spacer_style)
end

-- Shorter way to add a spacer with a decorative line
function AddSpacerLine(guiIn, name)
    guiIn.add {
        name = name,
        type = 'label',
        caption = '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    }
    ApplyStyle(guiIn[name], my_spacer_style)
end

-- Get a random 1 or -1
function RandomNegPos()
    local math_random = math.random
    if (math_random(0, 1) == 1) then
        return 1
    else
        return -1
    end
end

-- Create a random direction vector to look in
function GetRandomVector()
    local math_random = math.random
    local randVec = {x = 0, y = 0}
    while ((randVec.x == 0) and (randVec.y == 0)) do
        randVec.x = math_random(-3, 3)
        randVec.y = math_random(-3, 3)
    end
    DebugPrint('direction: x=' .. randVec.x .. ', y=' .. randVec.y)
    return randVec
end

-- Check for ungenerated chunks around a specific chunk
-- +/- chunkDist in x and y directions
function IsChunkAreaUngenerated(chunkPos, chunkDist, surface)
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
function ClearNearbyEnemies(pos, safeDist, surface)
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

-- Function to find coordinates of ungenerated map area in a given direction
-- starting from the center of the map
function FindMapEdge(directionVec, surface)
    local position = {x = 0, y = 0}
    local chunkPos = {x = 0, y = 0}

    -- Keep checking chunks in the direction of the vector
    while (true) do
        -- Set some absolute limits.
        if ((math.abs(chunkPos.x) > 1000) or (math.abs(chunkPos.y) > 1000)) then
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
            if IsChunkAreaUngenerated(chunkPos, 10, surface) then
                position.x = (chunkPos.x * CHUNK_SIZE) + (CHUNK_SIZE / 2)
                position.y = (chunkPos.y * CHUNK_SIZE) + (CHUNK_SIZE / 2)
                break
            end
        end
    end

    -- DebugPrint("spawn: x=" .. position.x .. ", y=" .. position.y)
    return position
end

-- Find random coordinates within a given distance away
-- maxTries is the recursion limit basically.
function FindUngeneratedCoordinates(minDistChunks, maxDistChunks, surface)
    local position = {x = 0, y = 0}
    local chunkPos = {x = 0, y = 0}

    local maxTries = 15
    local tryCounter = 0

    local minDistSqr = minDistChunks ^ 2
    local maxDistSqr = maxDistChunks ^ 2
    local math_random = math.random
    local math_sqrt = math.sqrt

    while (true) do
        chunkPos.x = math_random(0, maxDistChunks) * RandomNegPos()
        chunkPos.y = math_random(0, maxDistChunks) * RandomNegPos()

        local distSqrd = chunkPos.x ^ 2 + chunkPos.y ^ 2

        -- Enforce a max number of tries
        tryCounter = tryCounter + 1
        if (tryCounter > maxTries) then
            -- Check that the distance is within the min,max specified
            DebugPrint('FindUngeneratedCoordinates - Max Tries Hit!')
            break
        elseif ((distSqrd < minDistSqr) or (distSqrd > maxDistSqr)) then
            -- Keep searching!
            -- Check there are no generated chunks in a 10x10 area.
        elseif IsChunkAreaUngenerated(chunkPos, CHECK_SPAWN_UNGENERATED_CHUNKS_RADIUS, surface) then
            position.x = (chunkPos.x * CHUNK_SIZE) + (CHUNK_SIZE / 2)
            position.y = (chunkPos.y * CHUNK_SIZE) + (CHUNK_SIZE / 2)
            break -- SUCCESS
        end
    end

    DebugPrint('spawn: x=' .. position.x .. ', y=' .. position.y)
    return position
end

-- General purpose function for removing a particular recipe
function RemoveRecipe(force, recipeName)
    local recipes = force.recipes
    if recipes[recipeName] then
        recipes[recipeName].enabled = false
    end
end

-- General purpose function for adding a particular recipe
function AddRecipe(force, recipeName)
    local recipes = force.recipes
    if recipes[recipeName] then
        recipes[recipeName].enabled = true
    end
end

-- Get an area given a position and distance.
-- Square length = 2x distance
function GetAreaAroundPos(pos, dist)
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

-- Removes the entity type from the area given
function RemoveInArea(surface, area, type)
    for key, entity in pairs(surface.find_entities_filtered({area = area, type = type})) do
        if entity.valid and entity and entity.position then
            entity.destroy()
        end
    end
end

-- Removes the entity type from the area given
-- Only if it is within given distance from given position.
function RemoveInCircle(surface, area, type, pos, dist)
    for key, entity in pairs(surface.find_entities_filtered({area = area, type = type})) do
        if entity.valid and entity and entity.position then
            if ((pos.x - entity.position.x) ^ 2 + (pos.y - entity.position.y) ^ 2 < dist ^ 2) then
                entity.destroy()
            end
        end
    end
end

-- Convenient way to remove aliens, just provide an area
function RemoveAliensInArea(surface, area)
    for _, entity in pairs(surface.find_entities_filtered {area = area, force = 'enemy'}) do
        entity.destroy()
    end
end

-- Make an area safer
-- Reduction factor divides the enemy spawns by that number. 2 = half, 3 = third, etc...
-- Also removes all big and huge worms in that area
function ReduceAliensInArea(surface, area, reductionFactor)
    local math_random = math.random
    for _, entity in pairs(surface.find_entities_filtered {area = area, force = 'enemy'}) do
        if (math_random(0, reductionFactor) > 0) then
            entity.destroy()
        end
    end

    -- Remove all big and huge worms
    for _, entity in pairs(surface.find_entities_filtered {area = area, name = 'medium-worm-turret'}) do
        entity.destroy()
    end
    for _, entity in pairs(surface.find_entities_filtered {area = area, name = 'big-worm-turret'}) do
        entity.destroy()
    end
end

-- Adjust alien params
function ConfigureAlienStartingParams()
    -- These are the default values for reference:
    -- "time_factor": 0.000004,
    -- "destroy_factor": 0.002,
    -- "pollution_factor": 0.000015

    if ENEMY_TIME_FACTOR_DISABLE then
        game.map_settings.enemy_evolution.time_factor = 0
    else
        game.map_settings.enemy_evolution.time_factor = game.map_settings.enemy_evolution.time_factor / ENEMY_TIME_FACTOR_DIVISOR
    end

    if ENEMY_POLLUTION_FACTOR_DISABLE then
        game.map_settings.enemy_evolution.pollution_factor = 0
    else
        game.map_settings.enemy_evolution.pollution_factor =
            game.map_settings.enemy_evolution.pollution_factor / ENEMY_POLLUTION_FACTOR_DIVISOR
    end

    if ENEMY_DESTROY_FACTOR_DISABLE then
        game.map_settings.enemy_evolution.destroy_factor = 0
    else
        game.map_settings.enemy_evolution.destroy_factor = game.map_settings.enemy_evolution.destroy_factor / ENEMY_DESTROY_FACTOR_DIVISOR
    end

    game.map_settings.enemy_expansion.enabled = ENEMY_EXPANSION
end

-- Add Long Reach to Character
function GivePlayerLongReach(player)
    player.character.character_build_distance_bonus = BUILD_DIST_BONUS
    player.character.character_reach_distance_bonus = REACH_DIST_BONUS
    -- player.character.character_resource_reach_distance_bonus  = RESOURCE_DIST_BONUS
end

--------------------------------------------------------------------------------
-- Player List GUI - My own version
--------------------------------------------------------------------------------
function CreatePlayerListGui(event)
    local player = game.players[event.player_index]
    if player.gui.top.playerList == nil then
        player.gui.top.add {name = 'playerList', type = 'button', caption = 'Player List'}
    end
end

local function ExpandPlayerListGui(player)
    local frame = player.gui.left['playerList-panel']
    if (frame) then
        frame.destroy()
    else
        local frame =
            player.gui.left.add {
            type = 'frame',
            name = 'playerList-panel',
            caption = 'Online:'
        }
        local scrollFrame =
            frame.add {
            type = 'scroll-pane',
            name = 'playerList-panel',
            direction = 'vertical'
        }
        ApplyStyle(scrollFrame, my_player_list_fixed_width_style)
        scrollFrame.horizontal_scroll_policy = 'never'
        for _, player in pairs(game.connected_players) do
            local caption_str = player.name .. ' [' .. player.force.name .. ']' .. ' (' .. formattime_hours_mins(player.online_time) .. ')'
            if (player.admin) then
                AddLabel(scrollFrame, player.name .. '_plist', caption_str, my_player_list_admin_style)
            else
                AddLabel(scrollFrame, player.name .. '_plist', caption_str, my_player_list_style)
            end
        end

        -- List offline players
        if (PLAYER_LIST_OFFLINE_PLAYERS) then
            AddLabel(scrollFrame, 'offline_title_msg', 'Offline Players:', my_label_style)
            for _, player in pairs(game.players) do
                if (not player.connected) then
                    local caption_str =
                        player.name .. ' [' .. player.force.name .. ']' .. ' (' .. formattime_hours_mins(player.online_time) .. ')'
                    local text = scrollFrame.add {type = 'label', caption = caption_str, name = player.name .. '_plist'}
                    ApplyStyle(text, my_player_list_offline_style)
                end
            end
        end
        local spacer = scrollFrame.add {type = 'label', caption = '     ', name = 'plist_spacer_plist'}
        ApplyStyle(spacer, my_player_list_style_spacer)
    end
end

function PlayerListGuiClick(event)
    if not (event and event.element and event.element.valid) then
        return
    end
    local player = game.players[event.element.player_index]
    local name = event.element.name

    if (name == 'playerList') then
        ExpandPlayerListGui(player)
    end
end

--------------------------------------------------------------------------------
-- Anti-griefing Stuff & Gravestone (My own version)
--------------------------------------------------------------------------------
function AntiGriefing(force)
    force.zoom_to_world_deconstruction_planner_enabled = false
    force.friendly_fire = false
    force.recipes['loader'].enabled = true
    force.recipes['fast-loader'].enabled = true
    force.recipes['express-loader'].enabled = true
    SetForceGhostTimeToLive(force)
    game.surfaces[g_surface].always_day = false
    game.surfaces[g_surface].daytime = 0.7505
end

function SetForceGhostTimeToLive(force)
    if GHOST_TIME_TO_LIVE ~= 0 then
        force.ghost_time_to_live = GHOST_TIME_TO_LIVE + 1
    end
end

function SetItemBlueprintTimeToLive(event)
    local type = event.created_entity.type
    if type == 'entity-ghost' or type == 'tile-ghost' then
        if GHOST_TIME_TO_LIVE ~= 0 then
            event.created_entity.time_to_live = GHOST_TIME_TO_LIVE
        end
    end
end

--------------------------------------------------------------------------------
-- Gravestone soft mod. With my own modifications/improvements.
--------------------------------------------------------------------------------
-- Return steel chest entity (or nil)
function DropEmptySteelChest(player)
    local pos = player.surface.find_non_colliding_position('steel-chest', player.position, 15, 1)
    if not pos then
        return nil
    end
    local grave = player.surface.create_entity {name = 'steel-chest', position = pos, force = 'neutral'}
    return grave
end

function DropGravestoneChests(player)
    local grave
    local count = 0

    -- Make sure we save stuff we're holding in our hands.
    player.clear_cursor()

    -- Loop through a players different inventories
    -- Put it all into a chest.
    -- If the chest is full, create a new chest.
    for i, id in ipairs {
        defines.inventory.player_armor,
        defines.inventory.player_main,
        defines.inventory.player_quickbar,
        defines.inventory.player_guns,
        defines.inventory.player_ammo,
        defines.inventory.player_tools,
        defines.inventory.player_trash
    } do
        local inv = player.get_inventory(id)

        if ((#inv > 0) and not inv.is_empty()) then
            for j = 1, #inv do
                if inv[j].valid_for_read then
                    -- Create a chest when counter is reset
                    if (count == 0) then
                        grave = DropEmptySteelChest(player)
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

    if (grave ~= nil) then
        player.print('Successfully dropped your items into a chest! Go get them quick!')
    end
end

--------------------------------------------------------------------------------
-- Autofill Stuff
--------------------------------------------------------------------------------

-- Transfer Items Between Inventory
-- Returns the number of items that were successfully transferred.
-- Returns -1 if item not available.
-- Returns -2 if can't place item into destInv (ERROR)
function TransferItems(srcInv, destEntity, itemStack)
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
function TransferItemMultipleTypes(srcInv, destEntity, itemNameArray, itemCount)
    local ret = 0
    for _, itemName in pairs(itemNameArray) do
        ret = TransferItems(srcInv, destEntity, {name = itemName, count = itemCount})
        if (ret > 0) then
            return ret -- Return the value succesfully transferred
        end
    end
    return ret -- Return the last error code
end

-- Autofills a turret with ammo
function AutofillTurret(player, turret)
    local mainInv = player.get_inventory(defines.inventory.player_main)

    -- Attempt to transfer some ammo
    local ret =
        TransferItemMultipleTypes(
        mainInv,
        turret,
        {'uranium-rounds-magazine', 'piercing-rounds-magazine', 'firearm-magazine'},
        AUTOFILL_TURRET_AMMO_QUANTITY
    )

    -- Check the result and print the right text to inform the user what happened.
    if (ret > 0) then
        -- Inserted ammo successfully
        -- FlyingText("Inserted ammo x" .. ret, turret.position, my_color_red, player.surface)
    elseif (ret == -1) then
        FlyingText('Out of ammo!', turret.position, my_color_red, player.surface)
    elseif (ret == -2) then
        FlyingText('Autofill ERROR! - Report this bug!', turret.position, my_color_red, player.surface)
    end
end

-- Autofills a vehicle with fuel, bullets and shells where applicable
function AutoFillVehicle(player, vehicle)
    local mainInv = player.get_inventory(defines.inventory.player_main)

    -- Attempt to transfer some fuel
    if ((vehicle.name == 'car') or (vehicle.name == 'tank') or (vehicle.name == 'locomotive')) then
        TransferItemMultipleTypes(mainInv, vehicle, {'nuclear-fuel', 'rocket-fuel', 'solid-fuel', 'coal'}, 50)
    end

    -- Attempt to transfer some ammo
    if ((vehicle.name == 'car') or (vehicle.name == 'tank')) then
        TransferItemMultipleTypes(mainInv, vehicle, {'uranium-rounds-magazine', 'piercing-rounds-magazine', 'firearm-magazine'}, 100)
    end

    -- Attempt to transfer some tank shells
    if (vehicle.name == 'tank') then
        TransferItemMultipleTypes(
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
function CreateCropCircle(surface, centerPos, chunkArea, tileRadius)
    local tileRadSqr = tileRadius ^ 2

    local dirtTiles = {}
    for i = chunkArea.left_top.x, chunkArea.right_bottom.x, 1 do
        for j = chunkArea.left_top.y, chunkArea.right_bottom.y, 1 do
            -- This ( X^2 + Y^2 ) is used to calculate if something
            -- is inside a circle area.
            local distVar = math.floor((centerPos.x - i) ^ 2 + (centerPos.y - j) ^ 2)

            -- Fill in all unexpected water in a circle
            if (distVar < tileRadSqr) then
                if (surface.get_tile(i, j).collides_with('water-tile')) then
                    table.insert(dirtTiles, {name = 'grass-1', position = {i, j}})
                end
            end

            -- Create a circle of trees around the spawn point.
            if ((distVar < tileRadSqr - 200) and (distVar > tileRadSqr - 400)) then
                surface.create_entity({name = 'tree-02', amount = 1, position = {i, j}})
            end
        end
    end

    surface.set_tiles(dirtTiles)
end

function CreateCropOctagon(surface, centerPos, chunkArea, tileRadius)
    local dirtTiles = {}
    for i = chunkArea.left_top.x, chunkArea.right_bottom.x, 1 do
        for j = chunkArea.left_top.y, chunkArea.right_bottom.y, 1 do
            local distVar1 = math.floor(math.max(math.abs(centerPos.x - i), math.abs(centerPos.y - j)))
            local distVar2 = math.floor(math.abs(centerPos.x - i) + math.abs(centerPos.y - j))
            local distVar = math.max(distVar1, distVar2 * 0.707)

            -- Fill in all unexpected water in a circle
            if (distVar < tileRadius + 2) then
                if (surface.get_tile(i, j).collides_with('water-tile') or ENABLE_SPAWN_FORCE_GRASS) then
                    table.insert(dirtTiles, {name = 'grass-1', position = {i, j}})
                end
            end

            -- Create a tree ring
            if ((distVar < tileRadius) and (distVar > tileRadius - 2)) then
                surface.create_entity({name = 'tree-01', amount = 1, position = {i, j}})
            end
        end
    end
    surface.set_tiles(dirtTiles)
end

-- Add a circle of water
function CreateMoat(surface, centerPos, chunkArea, tileRadius)
    local waterTiles = {}
    for i = chunkArea.left_top.x, chunkArea.right_bottom.x - 1, 1 do
        for j = chunkArea.left_top.y, chunkArea.right_bottom.y - 1, 1 do
            local distVar = math.floor(math.max(math.abs(centerPos.x - i) - 5, math.abs(centerPos.y - j) + 85))

            -- Create a water ring
            if ((distVar < tileRadius + (20 * MOAT_SIZE_MODIFIER)) and (distVar > tileRadius)) then
                insert(waterTiles, {name = 'deepwater', position = {i, j}})
            end
        end
    end
    surface.set_tiles(waterTiles)
end

-- Create a horizontal line of water
function CreateWaterStrip(surface, leftPos, length)
    local waterTiles = {}
    for i = 0, length, 1 do
        insert(waterTiles, {name = 'water', position = {leftPos.x + i, leftPos.y}})
    end
    surface.set_tiles(waterTiles)
end

-- Function to generate a resource patch, of a certain size/amount at a pos.
function GenerateResourcePatch(surface, resourceName, diameter, pos, amount)
    local midPoint = math.floor(diameter / 2)
    if (diameter == 0) then
        return
    end
    for y = 0, diameter do
        for x = -10, diameter do
            if (not ENABLE_RESOURCE_SHAPE_CIRCLE or ((x - midPoint) ^ 2 + (y - midPoint) ^ 2 < midPoint ^ 2)) then
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

-- Generate the basic starter resource around a given location.
function GenerateStartingResources(surface, pos)
    local surface = game.surfaces[g_surface]
    -- Generate stone
    local stonePos = {
        x = pos.x + START_RESOURCE_STONE_POS_X,
        y = pos.y + START_RESOURCE_STONE_POS_Y
    }

    -- Generate coal
    local coalPos = {
        x = pos.x + START_RESOURCE_COAL_POS_X,
        y = pos.y + START_RESOURCE_COAL_POS_Y
    }

    -- Generate copper ore
    local copperOrePos = {
        x = pos.x + START_RESOURCE_COPPER_POS_X,
        y = pos.y + START_RESOURCE_COPPER_POS_Y
    }

    -- Generate iron ore
    local ironOrePos = {
        x = pos.x + START_RESOURCE_IRON_POS_X,
        y = pos.y + START_RESOURCE_IRON_POS_Y
    }

    -- Generate uranium
    local uraniumOrePos = {
        x = pos.x + START_RESOURCE_URANIUM_POS_X,
        y = pos.y + START_RESOURCE_URANIUM_POS_Y
    }

    -- Tree generation is taken care of in chunk generation

    -- Generate oil patches
    oil_patch_x = pos.x + START_RESOURCE_OIL_POS_X
    oil_patch_y = pos.y + START_RESOURCE_OIL_POS_Y
    for i = 1, START_RESOURCE_OIL_NUM_PATCHES do
        surface.create_entity(
            {
                name = 'crude-oil',
                amount = START_OIL_AMOUNT,
                position = {oil_patch_x, oil_patch_y}
            }
        )
        oil_patch_x = oil_patch_x + START_RESOURCE_OIL_X_OFFSET
        oil_patch_y = oil_patch_y + START_RESOURCE_OIL_Y_OFFSET
    end

    -- Generate Stone
    GenerateResourcePatch(surface, 'stone', START_RESOURCE_STONE_SIZE, stonePos, START_STONE_AMOUNT)

    -- Generate Coal
    GenerateResourcePatch(surface, 'coal', START_RESOURCE_COAL_SIZE, coalPos, START_COAL_AMOUNT)

    -- Generate Copper
    GenerateResourcePatch(surface, 'copper-ore', START_RESOURCE_COPPER_SIZE, copperOrePos, START_COPPER_AMOUNT)
    --GenerateResourcePatch(surface, "iron-ore", START_RESOURCE_COPPER_SIZE, copperOrePos, START_COPPER_AMOUNT)

    -- Generate Iron
    GenerateResourcePatch(surface, 'iron-ore', START_RESOURCE_IRON_SIZE, ironOrePos, START_IRON_AMOUNT)
    --GenerateResourcePatch(surface, "copper-ore", START_RESOURCE_IRON_SIZE, ironOrePos, START_IRON_AMOUNT)

    -- Generate Uranium
    GenerateResourcePatch(surface, 'uranium-ore', START_RESOURCE_URANIUM_SIZE, uraniumOrePos, START_URANIUM_AMOUNT)
end

-- Clear the spawn areas.
-- This should be run inside the chunk generate event and be given a list of all
-- unique spawn points.
-- This clears enemies in the immediate area, creates a slightly safe area around it,
-- It no LONGER generates the resources though as that is now handled in a delayed event!
function SetupAndClearSpawnAreas(event)
    local surface = game.surfaces[g_surface]
    local chunkArea = event.area
    local localforce = {x = 0, y = 0}
    -- Create a bunch of useful area and position variables
    local landArea = GetAreaAroundPos(localforce, ENFORCE_LAND_AREA_TILE_DIST + CHUNK_SIZE)
    local safeArea = GetAreaAroundPos(localforce, SAFE_AREA_TILE_DIST)
    local warningArea = GetAreaAroundPos(localforce, WARNING_AREA_TILE_DIST)
    local chunkAreaCenter = {
        x = chunkArea.left_top.x + (CHUNK_SIZE / 2),
        y = chunkArea.left_top.y + (CHUNK_SIZE / 2)
    }
    local forcePosOffset = {
        x = localforce.x + ENFORCE_LAND_AREA_TILE_DIST,
        y = localforce.y + ENFORCE_LAND_AREA_TILE_DIST
    }

    -- Make chunks near a force safe by removing enemies
    if CheckIfInArea(chunkAreaCenter, safeArea) then
        -- Create a warning area with reduced enemies
        RemoveAliensInArea(surface, chunkArea)
    elseif CheckIfInArea(chunkAreaCenter, warningArea) then
        ReduceAliensInArea(surface, chunkArea, WARN_AREA_REDUCTION_RATIO)
    end

    -- If the chunk is within the main land area, then clear trees/resources
    -- and create the land force areas (guaranteed land with a circle of trees)
    if CheckIfInArea(chunkAreaCenter, landArea) then
        -- Remove trees/resources inside the force area
        RemoveInCircle(surface, chunkArea, 'tree', localforce, ENFORCE_LAND_AREA_TILE_DIST)
        RemoveInCircle(surface, chunkArea, 'resource', localforce, ENFORCE_LAND_AREA_TILE_DIST + 10)
        RemoveInCircle(surface, chunkArea, 'cliff', localforce, ENFORCE_LAND_AREA_TILE_DIST + 5)
        RemoveDecorationsArea(surface, chunkArea)
        RemoveInCircle(surface, chunkArea, 'simple-entity', localforce, ENFORCE_LAND_AREA_TILE_DIST + 10)

        --CreateCropCircle(surface, localforce, chunkArea, ENFORCE_LAND_AREA_TILE_DIST)

        if (force_MOAT_CHOICE_ENABLED) then
            if (force.moat) then
                CreateMoat(surface, localforce, chunkArea, ENFORCE_LAND_AREA_TILE_DIST)
            end
        end
    end

    -- Provide starting resources
    -- This is run on the bottom, right chunk of the force area which should be
    -- generated last, so it should work everytime.
    --if CheckIfInArea(forcePosOffset,chunkArea) then
    --CreateWaterStrip(surface,
    --               {x=localforce.x+WATER_SPAWN_OFFSET_X, y=localforce.y+WATER_SPAWN_OFFSET_Y},
    --               WATER_force_LENGTH)
    --CreateWaterStrip(surface,
    --                {x=localforce.x+WATER_SPAWN_OFFSET_X, y=localforce.y+WATER_SPAWN_OFFSET_Y+1},
    --                WATER_force_LENGTH)
    --GenerateStartingResources(surface, localforce)
    --end
end

--------------------------------------------------------------------------------
-- Surface Generation Functions
--------------------------------------------------------------------------------

RSO_MODE = 1
VANILLA_MODE = 2

function CreateGameSurface(mode)
    local mapSettings = game.surfaces[g_surface]

    if CMD_LINE_MAP_GEN then
        mapSettings.terrain_segmentation = global.clMapGen.terrain_segmentation
        mapSettings.water = global.clMapGen.water
        mapSettings.starting_area = global.clMapGen.starting_area
        mapSettings.peaceful_mode = global.clMapGen.peaceful_mode
        mapSettings.seed = global.clMapGen.seed
        mapSettings.autoplace_controls = global.clMapGen.autoplace_controls
        mapSettings.cliff_settings = global.clMapGen.cliff_settings
    end

    -- To use RSO resources, we have to disable vanilla ore generation
    if (mode == RSO_MODE) then
        mapSettings.water = global.clMapGen.water
        mapSettings.autoplace_controls['coal'].size = 'none'
        mapSettings.autoplace_controls['copper-ore'].size = 'none'
        mapSettings.autoplace_controls['iron-ore'].size = 'none'
        mapSettings.autoplace_controls['stone'].size = 'none'
        mapSettings.autoplace_controls['uranium-ore'].size = 'none'
        mapSettings.autoplace_controls['crude-oil'].size = 'none'
        mapSettings.autoplace_controls['enemy-base'].size = 'none'
    end
end

--------------------------------------------------------------------------------
-- Holding pen for new players joining the map
--------------------------------------------------------------------------------
function CreateWall(surface, pos)
    local wall = surface.create_entity({name = 'stone-wall', position = pos, force = 'Protectors'})
    if wall then
        wall.destructible = true
        wall.minable = true
    end
end

function CreateHoldingPen(surface, chunkArea, sizeTiles, walls)
    if (((chunkArea.left_top.x == -32) or (chunkArea.left_top.x == 0)) and ((chunkArea.left_top.y == -32) or (chunkArea.left_top.y == 0))) then
        walls = true

        -- Remove stuff
        RemoveAliensInArea(surface, chunkArea)
        RemoveInArea(surface, chunkArea, 'tree')
        RemoveInArea(surface, chunkArea, 'resource')
        RemoveInArea(surface, chunkArea, 'cliff')
        RemoveInArea(surface, chunkArea, 'simple-entity')

        -- This loop runs through each tile
        local grassTiles = {}
        local waterTiles = {}
        for i = chunkArea.left_top.x, chunkArea.right_bottom.x, 1 do
            for j = chunkArea.left_top.y, chunkArea.right_bottom.y, 1 do
                if ((i > -sizeTiles) and (i < (sizeTiles - 1)) and (j > -sizeTiles) and (j < (sizeTiles - 1))) then
                    -- Fill all area with grass only
                    --insert(grassTiles, {name = "dirt-1", position ={i,j}})

                    -- Create the spawn box walls
                    --if not ENABLE_DEFAULT_SPAWN then
                    if (j < (sizeTiles - 1) and j > -sizeTiles) then
                        -- Create horizontal sides of center spawn box
                        if
                            (((j > -sizeTiles and j < -(sizeTiles - 4)) or (j < (sizeTiles - 1) and j > (sizeTiles - 5))) and
                                (i < (sizeTiles - 1) and i > -sizeTiles))
                         then
                            if walls then
                                CreateWall(surface, {i, j})
                            else
                                insert(waterTiles, {name = 'water', position = {i, j}})
                            end
                        end
                    end

                    -- Create vertical sides of center spawn box
                    if ((i > -sizeTiles and i < -(sizeTiles - 4)) or (i < (sizeTiles - 1) and i > (sizeTiles - 5))) then
                        if walls then
                            CreateWall(surface, {i, j})
                        else
                            insert(waterTiles, {name = 'water', position = {i, j}})
                        end
                    end
                end
                --end
            end
        end
        surface.set_tiles(grassTiles)
        surface.set_tiles(waterTiles)
    end
end

--------------------------------------------------------------------------------
-- EVENT SPECIFIC FUNCTIONS
--------------------------------------------------------------------------------

-- Remove decor to save on file size
function UndecorateOnChunkGenerate(event)
    local surface = event.surface
    local chunkArea = event.area
    RemoveDecorationsArea(surface, chunkArea)
    RemoveFish(surface, chunkArea)
end

-- Give player items on respawn
-- Intended to be the default behavior when not using separate spawns
function PlayerRespawnItems(event)
    GivePlayerItems(game.players[event.player_index])
end

function PlayerSpawnItems(event)
    GivePlayerStarterItems(game.players[event.player_index])
end

-- Autofill softmod
function Autofill(event)
    local player = game.players[event.player_index]
    local eventEntity = event.created_entity

    if (eventEntity.name == 'gun-turret') then
        AutofillTurret(player, eventEntity)
    end

    if ((eventEntity.name == 'car') or (eventEntity.name == 'tank') or (eventEntity.name == 'locomotive')) then
        AutoFillVehicle(player, eventEntity)
    end
end

function ShowSpawns(player, t)
    if t ~= nil then
        for key, spawn in pairs(t) do
            player.print(
                'spawn ' ..
                    key .. ': ' .. spawn.radius .. ' sector ' .. spawn.sector .. ' seq ' .. spawn.seq .. ' ' .. spawn.x .. ',' .. spawn.y
            )
        end
    end
end

function ShowPlayerSpawns(player)
    ShowSpawns(player, global.playerSpawns)
end

function EraseArea(position, chunkDist)
    local surface = game.surfaces[g_surface]
    local eraseArea = {
        left_top = {
            x = position.x - chunkDist * CHUNK_SIZE,
            y = position.y - chunkDist * CHUNK_SIZE
        },
        right_bottom = {
            x = position.x + chunkDist * CHUNK_SIZE,
            y = position.y + chunkDist * CHUNK_SIZE
        }
    }
    for chunk in surface.get_chunks() do
        local chunkArea = {
            left_top = {
                x = chunk.x * CHUNK_SIZE,
                y = chunk.y * CHUNK_SIZE
            },
            right_bottom = {
                x = chunk.x * CHUNK_SIZE + CHUNK_SIZE,
                y = chunk.y * CHUNK_SIZE + CHUNK_SIZE
            }
        }
        if CheckIfInChunk(chunkArea, eraseArea) then
            surface.delete_chunk(chunk)
        end
    end
end

function SurfaceSettings(surface)
    local settings = surface.map_gen_settings
    game.player.print('surface terrain_segmentation=' .. settings.terrain_segmentation)
    game.player.print('surface water=' .. settings.water)
    game.player.print('surface seed=' .. settings.seed)
end

function gen_on_chunk_generated(event)
    local surface = event.surface
    local left_top = event.area.left_top
    for x = 0, 31, 1 do
        for y = 0, 31, 1 do
            local pos = {x = left_top.x + x, y = left_top.y + y}
            if math_random(1, 120000) == 1 and pos.x ^ 2 + pos.y ^ 2 > 160000 then
                f.draw_entity_circle(pos, 'stone', surface, 6, true, 1000000)
                f.draw_entity_circle(pos, 'coal', surface, 12, true, 1000000)
                f.draw_entity_circle(pos, 'copper-ore', surface, 18, true, 1000000)
                f.draw_entity_circle(pos, 'iron-ore', surface, 24, true, 1000000)
                f.draw_noise_tile_circle(pos, 'water', surface, 4)
            end
        end
    end
end

function replace_spawn_water(surface)
    if global.spawn_water_replaced then
        return
    end
    if not surface.is_chunk_generated({5, 5}) then
        return
    end
    local tilename = 'grass-1'
    for x = -50, 50, 1 do
        for y = -50, 50, 1 do
            local tile = surface.get_tile(x, y)
            if tile.name ~= 'water' and tile.name ~= 'deepwater' then
                tilename = tile.name
            end
        end
    end
    local tiles = {}
    for x = -128, 128, 1 do
        for y = -128, 128, 1 do
            local tile = surface.get_tile(x, y)
            if tile.name == 'water' or tile.name == 'deepwater' then
                insert(tiles, {name = tilename, position = {x = tile.position.x, y = tile.position.y}})
            end
        end
    end
    surface.set_tiles(tiles, true)
    global.spawn_water_replaced = true
end
