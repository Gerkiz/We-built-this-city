-- oarc_enemies_defines.lua
-- Aug 2019
-- Some hard settings and general definitions and stuff.

-- Max number of ongoing attacks at any time.

local Global = require 'utils.global'

local Public = {}

local global_data = {
    max_attacks = 30,
    max_attacks_retal = 150,
    safe_area_radius = 50,
    search_radius_chunks = 200,
    type_target_player = 1,
    type_target_area = 2,
    type_target_building = 3,
    type_target_unknown = 4,
    type_target_entity = 5,
    process_find_target = 0,
    process_find_spawn = 1,
    process_find_spawn_path_req = 2,
    process_find_spawn_path_calc = 3,
    process_find_create_group = 4,
    process_find_command_group = 5,
    process_find_group_active = 6,
    process_find_command_failed = 7,
    process_find_fallback_attack = 8,
    process_find_fallback_final = 9,
    process_find_retry_path_req = 10,
    process_find_retry_path_calc = 11,
    process_find_build_base = 12,
    debug = true,
    disable = false,
    next_wave = 3600,
    groups = {},
    tech_levels = {},
    p_time = {},
    player_sbubbles = {},
    attacks = {},
    render_paths = true,
    params = {
        attack_size_min = 1,
        attack_size_max = 150,
        player_time_evo_factor = 0.5,
        player_time_size_factor = 30,
        player_time_peak_hours = 20,
        pollution_evo_factor = 0.3,
        pollution_size_factor = 80,
        pollution_peak_amnt = 4000,
        tech_evo_factor = 0.85,
        tech_size_factor = 30,
        tech_peak_count = 180,
        rand_evo_amnt = 0.15, -- Up to + this amount
        rand_size_amnt = 10, -- Up to + this amount
        seconds_between_attacks_min = 5 * 6,
        seconds_between_attacks_max = 30 * 6,
        seconds_between_attacks_rand = 4 * 6,
        radar_scan_attack_chance = 500 -- 1 in X change to trigger an attack due to a radar ping.
    }
}

Global.register(
    global_data,
    function(tbl)
        global_data = tbl
    end
)

function Public.get_table()
    return global_data
end

return Public
