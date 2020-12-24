local global_data = require 'map_gen.multiplayer_spawn.lib.table'.get()

global.welcome_msg_title = 'We built this city!'
global.welcome_msg = ''
global.server_msg = 'Rules: Be polite. Ask before changing other players stuff. Have fun!\n' .. 'Discord: discord.io/wbtc'

global.scenario_info_msg =
    'This scenario gives you and/or your friends your own starting area.\n' ..
    'You can play towny (PVP) if you´d like, the main team or your own.\n' ..
        'All teams are friendly. Except if you play Towny (PVP)\n' ..
            'If you leave in the first 15 minutes, your base and character will be deleted!\n' .. 'Repeated joining and leaving will result in a temporary ban.'

global.enable_vanilla_spawns = false

global.enable_default_spawn = true

-- This allows 2 players to spawn next to each other in the wilderness,
-- each with their own starting point. It adds more GUI selection options.
global.enable_buddy_spawn = true

-- Enable Town-shape like when spawning?
global.enable_town_shape = true

-- Frontier style rocket silo mode
-- This means you can't build silos, but some spawn out in the wild for you to use.
global.frontier_rocket_silo_mode = true

-- Silo Islands
-- This options is only valid when used with global.enable_vanilla_spawns and global.frontier_rocket_silo_mode!
-- This spreads out rocket silos on every OTHER island/vanilla spawn
global.silo_island_mode = false

-- Enable Undecorator
-- Removes decorative items to reduce save file size.
global.enable_undecorator = false

global.enable_scramble = true

-- Enable Long Reach
global.enable_longreach = false

-- Enable Autofill
global.enable_autofill = false

-- Enable vanilla loaders
global.enable_loaders = true

-- Disable nukes
global.disable_nukes = true

-- Enable shared vision between teams (all teams are COOP regardless)
global.enable_shared_team_vision = true

-- Only works if you have the Unused Chunk Removal mod installed.
global.enable_base_removal = true

-- Enable the new 0.17 research queue by default for all forces.
global.enable_r_queue = true

global.enable_power_armor = true

--------------------------------------------------------------------------------
-- MAP CONFIGURATION OPTIONS
-- In past versions I had a way to config map settings here to be used for cmd
-- line launching, but now you should just be using --map-gen-settings and
-- --map-settings option since it works with --start-server-load-scenario
-- Read the README.md file for instructions.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Alien Options
--------------------------------------------------------------------------------

-- Adjust enemy spawning based on distance to spawns. All it does it make things
-- more balanced based on your distance and makes the game a little easier.
-- No behemoth worms everywhere just because you spawned far away.
-- If you're trying out the vanilla spawning, you might want to disable this.
global.modded_enemy = false -- disabled cause OE

---------------------------------------
-- Market
---------------------------------------
global.enable_market = true

---------------------------------------
-- Starting Items
---------------------------------------
-- Items provided to the player the first time they join
global.player_spawn_start_items = {
    {name = 'pistol', count = 1},
    {name = 'firearm-magazine', count = 16},
    {name = 'iron-plate', count = 8},
    {name = 'burner-mining-drill', count = 4},
    {name = 'stone-furnace', count = 4},
    {name = 'raw-fish', count = 10},
    {name = 'iron-plate', count = 20},
    {name = 'coal', count = 50},
    {name = 'stone', count = 50}
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
global.player_respawn_start_items = {
    {name = 'pistol', count = 1},
    {name = 'firearm-magazine', count = 8}
}

---------------------------------------
-- Distance Options
---------------------------------------

-- This is the radius, in chunks, that a spawn area is from any other generated
-- chunks. It ensures the spawn area isn't too near generated/explored/existing
-- area. The larger you make this, the further away players will spawn from
-- generated map area (even if it is not visible on the map!).
global.check_spawn_ungenerated_chunk_radius = 10

-- Near Distance in chunks
-- When a player selects "near" spawn, they will be in or as close to this range as possible.
global.near_min_dist = 0
global.near_max_dist = 50

-- Far Distance in chunks
-- When a player selects "far" spawn, they will be at least this distance away.
global.far_min_dist = 150
global.far_max_dist = 250

---------------------------------------
-- Vanilla spawn point options
-- (only applicable if global.enable_vanilla_spawns is enabled.)
---------------------------------------

-- Num total spawns pre-assigned (minimum number)
-- There is currently a bug in factorio that can cause desyncs if this number is much higher.
-- https://forums.factorio.com/viewtopic.php?f=7&t=68657
-- Not sure you need that much anyways....
-- Points are in an even grid layout.
global.vanilla_spawn_count = 60

-- Num tiles between each spawn. (I recommend at least 1000)
global.vanilla_spawn_distance = 1000

---------------------------------------
-- Resource & Spawn Circle Options
---------------------------------------

-- This is where you can modify what resources spawn, how much, where, etc.
-- Once you have a config you like, it's a good idea to save it for later use
-- so you don't lost it if you update the scenario.
global.scenario_config = {
    -- Misc spawn related config.
    gen_settings = {
        -- THIS IS WHAT SETS THE SPAWN CIRCLE SIZE!
        -- Create a circle of land area for the spawn
        -- If you make this much bigger than a few chunks, good luck.
        land_area_tiles = global_data.chunk_size * 2.5,
        -- Allow players to choose to spawn with a moat
        moat_choice_enabled = false,
        -- If you change the spawn area size, you might have to adjust this as well
        moat_size_modifier = 1,
        -- Start resource shape. true = circle, false = square.
        resources_circle_shape = false,
        -- Force the land area circle at the spawn to be fully grass
        force_grass = true,
        -- Spawn a circle/octagon of trees around the base outline.
        tree_circle = false,
        tree_octagon = false,
        tree_square = true,
        trees_enabled = true
    },
    -- Safe Spawn Area Options
    -- The default settings here are balanced for my recommended map gen settings (close to train world).
    safe_area = {
        -- Safe area has no aliens
        -- This is the radius in tiles of safe area.
        safe_radius = global_data.chunk_size * 8,
        -- Warning area has significantly reduced aliens
        -- This is the radius in tiles of warning area.
        warn_radius = global_data.chunk_size * 16,
        -- 1 : X (spawners alive : spawners destroyed) in this area
        warn_reduction = 20,
        -- Danger area has slightly reduce aliens
        -- This is the radius in tiles of danger area.
        danger_radius = global_data.chunk_size * 32,
        -- 1 : X (spawners alive : spawners destroyed) in this area
        danger_reduction = 5
    },
    -- Location of water strip (horizontal)
    water_new = {
        x_offset = -90,
        y_offset = -55,
        length = 10
    },
    water_classic = {
        x_offset = -4,
        y_offset = -65,
        length = 8
    },
    -- Handle placement of starting resources
    resource_rand_pos_settings = {
        -- Autoplace resources (randomly in circle)
        -- This will ignore the fixed x_offset/y_offset values in resource_tiles.
        -- Only works for resource_tiles at the moment, not oil patches/water.
        enabled = true,
        -- Distance from center of spawn that resources are placed.
        radius = 60,
        -- At what angle (in radians) do resources start.
        -- 0 means starts directly east.
        -- Resources are placed clockwise from there.
        angle_offset = 2.32, -- 2.32 is approx SSW.
        -- At what andle do we place the last resource.
        -- angle_offset and angle_final determine spacing and placement.
        angle_final = 4.46 -- 4.46 is approx NNW.
    },
    -- Randomize positions
    pos = {
        {x = -5, y = -45},
        {x = 20, y = -45},
        {x = -30, y = -45},
        {x = -56, y = -45}
    },
    -- Resource tiles
    -- If you are running with mods like bobs/angels, you'll want to customize this.
    resource_tiles_new = {
        [1] = {
            amount = 2500,
            size = 18
        },
        [2] = {
            amount = 2500,
            size = 18
        },
        [3] = {
            amount = 2500,
            size = 18
        },
        [4] = {
            amount = 2500,
            size = 18
        }
    },
    -- Resource tiles
    -- If you are running with mods like bobs/angels, you'll want to customize this.
    resource_tiles_classic = {
        ['iron-ore'] = {
            amount = 2500,
            size = 18,
            x_offset = -29,
            y_offset = 16
        },
        ['copper-ore'] = {
            amount = 2500,
            size = 18,
            x_offset = -28,
            y_offset = -3
        },
        ['stone'] = {
            amount = 2500,
            size = 18,
            x_offset = -27,
            y_offset = -34
        },
        ['coal'] = {
            amount = 2500,
            size = 18,
            x_offset = -27,
            y_offset = -20
        }
    },
    -- Special resource patches like oil
    resource_patches_new = {
        ['crude-oil'] = {
            num_patches = 2,
            amount = 900000,
            x_offset_start = 60,
            y_offset_start = -50,
            x_offset_next = 6,
            y_offset_next = 0
        }
    },
    resource_patches_classic = {
        ['crude-oil'] = {
            num_patches = 2,
            amount = 900000,
            x_offset_start = -3,
            y_offset_start = 60,
            x_offset_next = 6,
            y_offset_next = 0
        }
    }
}

---------------------------------------
-- Other Forces/Teams Options
---------------------------------------

-- Separate teams
-- This allows you to join your own force/team. Everyone is still COOP/PvE, all
-- teams are friendly and cease-fire.
global.enable_separate_teams = true

-- Main force is what default players join
global.main_force_name = 'Main Force'

-- Enable if players can allow others to join their base.
-- And specify how many including the host are allowed.
global.enable_shared_spawns = true
global.max_players = 10

-- Share local team chat with all teams
-- This makes it so you don't have to use /s
-- But it also means you can't talk privately with your own team.
global.team_chat = true

---------------------------------------
-- Special Action Cooldowns
---------------------------------------
global.respawn_cooldown = 15

-- Require playes to be online for at least X minutes
-- Else their character is removed and their spawn point is freed up for use
global.min_online = 15

--------------------------------------------------------------------------------
-- Frontier Rocket Silo Options
--------------------------------------------------------------------------------

-- Number of silos found in the wild.
-- These will spawn in a circle at given distance from the center of the map
-- If you set this number too high, you'll have a lot of delay at the start of the game.
global.silo_spawns = 5

-- How many chunks away from the center of the map should the silo be spawned
global.silo_distance = 200

-- If this is enabled, you get silos at the positions specified below.
-- (The other settings above are ignored in this case.)
global.silo_fixed_pos = false

-- If you want to set fixed spawn locations for some silos.
global.silo_pos = {
    {x = -1000, y = -1000},
    {x = -1000, y = 1000},
    {x = 1000, y = -1000},
    {x = 1000, y = 1000}
}

-- Set this to false so that you have to search for the silo's.
global.enable_silo_vision = true

-- Add beacons around the silo (Philip's mod)
global.enable_silo_beacon = false
global.enable_silo_radar = false

-- Allow silos to be built by the player, but forces them to build in
-- the fixed locations. If this is false, silos are built and assigned
-- only to the main force.
global.enable_silo_player_build = true

--------------------------------------------------------------------------------
-- Long Reach Options
--------------------------------------------------------------------------------
global.build_dist_bonus = 64
global.reach_dist_bonus = global.build_dist_bonus
global.resource_dist_bonus = 2

--------------------------------------------------------------------------------
-- Autofill Options
--------------------------------------------------------------------------------
global.autofill_ammo = 10

--------------------------------------------------------------------------------
-- ANTI-Griefing stuff ( I don't personally maintain this as I don't care for it.)
-- These things were added from other people's requests/changes and are disabled by default.
--------------------------------------------------------------------------------
-- Enable this to disable deconstructing from map view, and setting a time limit
-- on ghost placements.
global.enable_antigrief = false

-- Makes blueprint ghosts dissapear if they have been placed longer than this
-- ONLY has an effect if global.enable_antigrief is true!
global.ghost_ttl = 10 * global_data.ticks_per_minute
