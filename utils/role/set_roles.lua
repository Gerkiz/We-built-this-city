local Public = require 'utils.role.main'

local groups = Public.get_groups()

groups['Root']:add_role {
    name = 'Owner',
    short_hand = 'Owner',
    tag = '',
    time = nil,
    colour = {r = 170, g = 0, b = 0},
    disallow = {},
    is_admin = true,
    is_spectator = true,
    base_afk_time = false
}
groups['Admin']:add_role {
    name = 'Moderator',
    short_hand = 'Mod',
    tag = '',
    colour = {r = 0, g = 170, b = 0},
    disallow = {},
    is_admin = true,
    is_spectator = true,
    base_afk_time = false
}

local roles = Public.get_roles()

roles['Owner']:edit(
    'allow',
    false,
    {
        ['debugger'] = true,
        ['game-settings'] = true,
        ['always-warp'] = true,
        ['admin-items'] = true,
        ['admin-commands'] = true,
        ['interface'] = true,
        ['warp-list'] = true,
        ['pregen_map'] = true,
        ['dump_layout'] = true,
        ['creative'] = true
    }
)

roles['Moderator']:edit(
    'allow',
    false,
    {
        ['repair'] = true,
        ['spaghetti'] = true,
        ['tree-decon'] = true
    }
)

roles['Veteran']:edit(
    'allow',
    false,
    {
        ['bonus'] = true,
        ['bonus-respawn'] = true,
        ['clear_corpses'] = true
    }
)

roles['Casual']:edit(
    'allow',
    false,
    {
        ['trust'] = true,
        ['untrust'] = true,
        ['show-warp'] = true
    }
)

roles['Rookie']:edit(
    'allow',
    false,
    {
        ['global-chat'] = true
    }
)

Public.standard_roles {
    ['gerkiz'] = 'Owner',
    ['cko6o4ku'] = 'Moderator',
    ['userguide'] = 'Moderator',
    ['panterh3art'] = 'Moderator'
}
