local Roles = require 'utils.role.main'

local groups = Roles.get_groups()

Roles.add_role(
    groups['Root'],
    {
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
)

Roles.add_role(
    groups['Admin'],
    {
        name = 'Moderator',
        short_hand = 'Mod',
        tag = '',
        colour = {r = 0, g = 170, b = 0},
        disallow = {},
        is_admin = true,
        is_spectator = true,
        base_afk_time = false
    }
)

local roles = Roles.get_roles()

Roles.edit(
    roles['Owner'],
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

Roles.edit(
    roles['Moderator'],
    'allow',
    false,
    {
        ['repair'] = true,
        ['spaghetti'] = true,
        ['tree-decon'] = true
    }
)

Roles.edit(
    roles['Veteran'],
    'allow',
    false,
    {
        ['trust'] = true,
        ['untrust'] = true,
        ['bonus'] = true,
        ['bonus-respawn'] = true,
        ['clear_corpses'] = true
    }
)

Roles.edit(
    roles['Casual'],
    'allow',
    false,
    {
        ['show-warp'] = true
    }
)

Roles.edit(
    roles['Rookie'],
    'allow',
    false,
    {
        ['global-chat'] = true
    }
)

Roles.standard_roles {
    ['gerkiz'] = 'Owner',
    ['cko6o4ku'] = 'Moderator',
    ['userguide'] = 'Moderator',
    ['panterh3art'] = 'Moderator'
}
