local Event = require 'utils.event'
local market_items = require 'features.modules.map_market_items'
local Tabs = require 'utils.gui.main'
local RPG = require 'features.modules.rpg'
local Fish = require 'features.modules.launch_fish_to_win'
local Ores = require 'features.modules.scramble'
local Autostash = require 'features.modules.autostash'
require 'features.modules.spawn_ent.main'
require 'features.modules.biters_yield_coins'
require 'features.modules.dangerous_goods'
require 'features.modules.biter_pets'
--require 'features.modules.enhancedbiters'
require 'features.modules.surrounded_by_worms'
require 'features.modules.autodecon_when_depleted'
--require 'features.modules.spawners_contain_biters'
require 'features.modules.backpack_research'
require 'features.modules.biters_double_damage'
require 'features.modules.infinity_chest'
require 'features.modules.custom_death_messages'
--require 'features.modules.explosive_biters'
require 'features.modules.spawn_area'
--require 'features.modules.splice'
--require 'features.modules.oarc_enemies.main'

local Map = require 'features.modules.map_info'
local Utils = require 'map_gen.mps_0_17.lib.oarc_utils'
local Silo = require 'map_gen.mps_0_17.lib.frontier_silo'
local R_launch = require 'map_gen.mps_0_17.lib.rocket_launch'
local Config = require 'map_gen.mps_0_17.config'
local Surface = require 'utils.surface'.get_surface_name()
local SS = require 'map_gen.mps_0_17.lib.separate_spawns'
local math_random = math.random

----------------------------------------
-- On Init - only runs once the first
--   time the game starts
----------------------------------------
local function on_start()
    Autostash.insert_into_furnace(true)
    local T = Map.Pop_info()
    T.main_caption = 'Shrine of the Ancients'
    T.sub_caption = '    launch the rocket!    '
    T.text =
        table.concat(
        {
            'Choose between playing solo or joining the main-team.\n',
            "If you don't feel like playing solo, join someones base.\n",
            '\n',
            'The main task is to launch a rocket, there are 5 designated areas.\n',
            'Look at the minimap to find these.\n',
            '\n',
            'Launching a rocket will not be an easy task,\n',
            'since worms are spawned everywhere,\n',
            'their strength and numbers increase over time.\n',
            '\n',
            'Biters have gotten increased scent,\n',
            'they will spawn some chunks outside your base and try to destroy you.\n',
            '\n',
            'Delve deep for greater treasures, but also face increased dangers.\n',
            'Mining productivity research, will overhaul your mining equipment,\n',
            'reinforcing your pickaxe as well as increasing the size of your backpack.\n',
            '\n',
            'Biters drop coin when defeated,\n',
            'Use these coins to purchase loot from markets that spawn around the map.\n',
            '\n',
            'Good luck, over and out!'
        }
    )
    T.main_caption_color = {r = 150, g = 150, b = 0}
    T.sub_caption_color = {r = 0, g = 150, b = 0}

    -- Create new game surface
    Utils.CreateGameSurface()

    -- MUST be before other stuff, but after surface creation.
    SS.InitSpawnGlobalsAndForces()

    -- Frontier Silo Area Generation
    if (global.frontier_rocket_silo_mode) then
        Silo.SpawnSilosAndGenerateSiloAreas()
    end
    -- Everyone do the shuffle. Helps avoid always starting at the same location.
    global.vanillaSpawns = Utils.shuffle(global.vanillaSpawns)
    --log ("Vanilla spawns:")
    --log(serpent.block(global.vanillaSpawns))
end
Event.on_init(on_start)

----------------------------------------
-- Rocket launch event
-- Used for end game win conditions / unlocking late game stuff
----------------------------------------
Event.add(
    defines.events.on_rocket_launched,
    function(event)
        if global.frontier_rocket_silo_mode then
            R_launch.RocketLaunchEvent(event)
        end
    end
)

Event.add(
    defines.events.on_marked_for_deconstruction,
    function(event)
        if event.entity.name == 'fish' then
            event.entity.cancel_deconstruction(game.players[event.player_index].force.name)
        end
    end
)

----------------------------------------
-- Chunk Generation
----------------------------------------
Event.add(
    defines.events.on_chunk_generated,
    function(event)
        if event.surface.index == 1 then
            return
        end
        --
        --[[local surface = event.surface
    local table_insert = table.insert
    local left_top = event.area.left_top
    local tiles = {}
    for x = 0, 31, 1 do
        for y = 0, 31, 1 do
            local pos = {x = left_top.x + x, y = left_top.y + y}
            local t_name = surface.get_tile(pos).name == "dirt-" .. math.random(1, 6)
            if t_name then
                table_insert(tiles, {name = "dirt-" .. math.random(1, 6), position = pos})
            end
        end
    end

    surface.set_tiles(tiles, true)]] if
            global.enable_scramble
         then
            Ores.scramble(event)
        end

        if global.enable_undecorator then
            Utils.UndecorateOnChunkGenerate(event)
        end

        Silo.GenerateRocketSiloChunk(event)

        SS.SeparateSpawnsGenerateChunk(event)

        --CreateHoldingPen(event.surface, event.area, 16, 32)
    end
)

----------------------------------------
-- Gui Click
----------------------------------------
Event.add(
    defines.events.on_gui_click,
    function(event)
        -- Don't interfere with other mod related stuff.

        SS.WelcomeTextGuiClick(event)
        SS.SpawnOptsGuiClick(event)
        SS.SpawnCtrlGuiClick(event)
        SS.SharedSpwnOptsGuiClick(event)
        SS.BuddySpawnOptsGuiClick(event)
        SS.BuddySpawnWaitMenuClick(event)
        SS.BuddySpawnRequestMenuClick(event)
        SS.SharedSpawnJoinWaitMenuClick(event)
    end
)

Event.add(
    defines.events.on_gui_checked_state_changed,
    function(event)
        SS.SpawnOptsRadioSelect(event)
        SS.SpawnCtrlGuiOptionsSelect(event)
    end
)

----------------------------------------
-- Player Events
----------------------------------------
Event.add(
    defines.events.on_player_joined_game,
    function(event)
        Utils.PlayerJoinedMessages(event)
    end
)

Event.add(
    defines.events.on_player_created,
    function(event)
        local player = game.players[event.player_index]

        -- Move the player to the game surface immediately.
        local pos = game.surfaces[Surface].find_non_colliding_position('character', {x = 0, y = 0}, 3, 0, 5)
        player.teleport(pos, Surface)

        if global.enable_longreach then
            Utils.GivePlayerLongReach(player)
        end

        SS.SeparateSpawnsPlayerCreated(event.player_index)
    end
)

Event.add(
    defines.events.on_player_respawned,
    function(event)
        SS.SeparateSpawnsPlayerRespawned(event)

        Utils.PlayerRespawnItems(event)

        if global.enable_longreach then
            Utils.GivePlayerLongReach(game.players[event.player_index])
        end
    end
)

Event.add(
    defines.events.on_player_left_game,
    function(event)
        SS.FindUnusedSpawns(game.players[event.player_index], true)
    end
)

----------------------------------------
-- On BUILD entity. Don't forget on_robot_built_entity too!
----------------------------------------
Event.add(
    defines.events.on_built_entity,
    function(event)
        if global.enable_autofill then
            Utils.Autofill(event)
        end

        if global.frontier_rocket_silo_mode then
            Silo.BuildSiloAttempt(event)
        end
    end
)

----------------------------------------
-- On script_raised_built. This should help catch mods that
-- place items that don't count as player_built and robot_built.
-- Specifically FARL.
----------------------------------------
--Event.add(defines.events.script_raised_built, function(event)
--
--end)

----------------------------------------
-- On tick events. Stuff that needs to happen at regular intervals.
-- Delayed events, delayed spawns, ...
----------------------------------------
Event.add(
    defines.events.on_tick,
    function()
        SS.DelayedSpawnOnTick()

        if global.frontier_rocket_silo_mode then
            Silo.DelayedSiloCreationOnTick(game.surfaces[Surface])
        end

        if global.enable_market then
            if game.tick == 150 then
                local surface = game.surfaces[Surface]
                local pos = {{x = -10, y = -10}, {x = 10, y = 10}, {x = -10, y = -10}, {x = 10, y = -10}}
                local _pos = Utils.shuffle(pos)
                local p = game.surfaces[Surface].find_non_colliding_position('market', {_pos[1].x, _pos[1].y}, 60, 2)

                global.market = surface.create_entity {name = 'market', position = p, force = 'player'}

                rendering.draw_text {
                    text = 'Market',
                    surface = surface,
                    target = global.market,
                    target_offset = {0, 2},
                    color = {r = 0.98, g = 0.66, b = 0.22},
                    alignment = 'center'
                }

                global.market.destructible = false

                for _, item in pairs(market_items.spawn) do
                    global.market.add_market_item(item)
                end
            end
        end
    end
)

--Event.add(defines.events.on_sector_scanned, function (event)
--end)

Event.add(
    defines.events.on_player_mined_entity,
    function(event)
        local player = game.players[event.player_index]
        if not player then
            return
        end
        local e = event.entity
        if e.type ~= 'tree' then
            return
        end
        if e and e.valid and math_random(1, 4) == 1 then
            player.insert({name = 'coin', count = math_random(1, 3)})
        end
    end
)

----------------------------------------
--
----------------------------------------
Event.add(
    defines.events.on_robot_built_entity,
    function(event)
        if global.frontier_rocket_silo_mode then
            local e = event.entity
            if e and e.valid then
                Silo.BuildSiloAttempt(event)
            end
        end
    end
)

----------------------------------------
-- Shared chat, so you don't have to type /s
-- But you do lose your player colors across forces.
----------------------------------------
Event.add(
    defines.events.on_console_chat,
    function(event)
        if (global.team_chat) then
            if (event.player_index ~= nil) then
                Utils.ShareChatBetweenForces(game.players[event.player_index], event.message)
            end
        end
    end
)

----------------------------------------
-- On Research Finished
-- This is where you can permanently remove researched techs
----------------------------------------
Event.add(
    defines.events.on_research_finished,
    function(event)
        local research = event.research
        local force_name = research.force.name
        if research.name == 'rocket-silo' then
            game.forces[force_name].print(
                'Note! Rocket-silos can only be built on designated areas! You can find these on the mini-map.',
                {r = 0, g = 255, b = 171}
            )
            game.forces[force_name].play_sound {path = 'utility/new_objective', volume_modifier = 0.75}
        end

        -- Never allows players to build rocket-silos in "frontier" mode.
        if global.frontier_rocket_silo_mode and not global.enable_silo_player_build then
            Utils.RemoveRecipe(event.research.force, 'rocket-silo')
        end

        if global.enable_loaders then
            Utils.EnableLoaders(event)
        end

        if global.disable_nukes then
            Utils.DisableTech(research.force, 'atomic-bomb')
        end
    end
)

----------------------------------------
-- On Entity Spawned and On Biter Base Built
-- This is where I modify biter spawning based on location and other factors.
----------------------------------------
Event.add(
    defines.events.on_entity_spawned,
    function(event)
        if (global.modded_enemy) then
            SS.ModifyEnemySpawnsNearPlayerStartingAreas(event)
        end
    end
)
Event.add(
    defines.events.on_biter_base_built,
    function(event)
        if (global.modded_enemy) then
            SS.ModifyEnemySpawnsNearPlayerStartingAreas(event)
        end
    end
)

----------------------------------------
-- On Corpse Timed Out
-- Save player's stuff so they don't lose it if they can't get to the corpse fast enough.
----------------------------------------
Event.add(
    defines.events.on_character_corpse_expired,
    function(event)
        Utils.DropGravestoneChestFromCorpse(event.corpse)
    end
)

--[[
setmetatable(_G, {
    __newindex = function(_, n, v)
        log ("Desync warning: attempt to write to undeclared var " .. n)
        --game.print ("Attempt to write to undeclared var " .. n)
        global[n] = v;
    end,
    __index = function(_, n)
        return global[n];
    end
})
]]
--
