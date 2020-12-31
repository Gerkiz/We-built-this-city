local Color = require 'utils.color_presets'
local Groups = require 'utils.role.main'

local root =
    Groups.create_group {
    name = 'Root',
    disallow = {}
}
local admin =
    Groups.create_group {
    name = 'Admin',
    allow = {},
    disallow = {
        'edit_permission_group',
        'delete_permission_group',
        'add_permission_group'
    }
}
local trusted =
    Groups.create_group {
    name = 'Trusted',
    allow = {},
    disallow = {
        'edit_permission_group',
        'delete_permission_group',
        'add_permission_group'
    }
}
local user =
    Groups.create_group {
    name = 'User',
    allow = {},
    disallow = {
        'edit_permission_group',
        'delete_permission_group',
        'add_permission_group'
    }
}
local jail =
    Groups.create_group {
    name = 'Jail',
    allow = {},
    disallow = {
        'edit_permission_group',
        'delete_permission_group',
        'add_permission_group',
        'open_character_gui',
        'begin_mining',
        'start_walking',
        'open_blueprint_library_gui',
        'use_item',
        'select_item',
        'rotate_entity',
        'select_blueprint_entities',
        'open_train_gui',
        'open_train_station_gui',
        'open_gui',
        'open_item',
        'deconstruct',
        'build_rail',
        'cancel_research',
        'start_research',
        'set_train_stopped',
        'select_next_valid_gun',
        'open_technology_gui',
        'open_trains_gui',
        'edit_custom_tag',
        'craft',
        'setup_assembling_machine'
    }
}

Groups.add_role(
    root,
    {
        name = 'Root',
        short_hand = 'Root',
        tag = '',
        power = 1,
        colour = Color.white,
        is_root = true,
        is_admin = true,
        is_spectator = true,
        base_afk_time = false
    }
)

Groups.add_role(
    admin,
    {
        name = 'Admin',
        short_hand = 'Admin',
        tag = '',
        colour = {r = 233, g = 63, b = 233},
        is_admin = true,
        is_spectator = true,
        base_afk_time = false
    }
)

Groups.add_role(
    trusted,
    {
        name = 'Veteran',
        short_hand = 'Veteran',
        tag = '',
        time = 300,
        colour = {r = 26, g = 118, b = 156},
        base_afk_time = 120
    }
)

Groups.add_role(
    trusted,
    {
        name = 'Casual',
        short_hand = 'Casual',
        tag = '',
        time = 50,
        colour = {r = 26, g = 118, b = 156},
        base_afk_time = 60
    }
)

Groups.add_role(
    user,
    {
        name = 'Rookie',
        short_hand = '',
        tag = '',
        colour = {r = 185, g = 187, b = 160},
        is_default = true,
        disallow = {
            'build_terrain',
            'remove_cables',
            'launch_rocket',
            'reset_assembling_machine',
            'cancel_research'
        },
        base_afk_time = 30
    }
)

Groups.add_role(
    jail,
    {
        name = 'Jail',
        short_hand = 'Jail',
        tag = '[Jail]',
        colour = {r = 50, g = 50, b = 50},
        disallow = {},
        base_afk_time = false
    }
)
