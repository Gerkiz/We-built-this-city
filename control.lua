--! control stages
require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage
_DEBUG = false
_DUMP_ENV = false

local r = require
local loaded = _G.package.loaded
function require(path)
    if loaded[path] then
        return loaded[path] or log('Can only require files at runtime that have been required in the control stage.', 2)
    end
    if _DEBUG then
        return r(path)
    end
    local s, e = pcall(r, path)
    if not s then
        log('[ERROR] Failed to load file: ' .. path)
    elseif type(e) == 'string' and e:find('not found') then
        log('[ERROR] File not found: ' .. path)
    end
    return e
end

--! other stuff
local Event = require 'utils.event'
require 'utils.server_commands'
require 'utils.utils'
require 'utils.debug.command'
require 'utils.table'
require 'utils.spam_protection'
local Surface = require 'utils.surface'
Surface.bypass(false)
require 'utils.datastore.server_ups'
require 'utils.datastore.color_data'
require 'utils.datastore.session_data'
require 'utils.datastore.jail_data'
require 'utils.datastore.quickbar_data'
require 'utils.datastore.message_on_join_data'
require 'utils.datastore.player_tag_data'
require 'utils.player_modifiers'
require 'utils.command_handler'
require 'features.modules.rpg.main'

--! Role system
local Role = require 'utils.role.main'
require 'utils.role.set_permissions'
require 'utils.role.set_roles'
Role.adjust_permission()

--! gui and modules
require 'utils.gui.core'
require 'utils.gui.player_list'
require 'utils.gui.admin'
require 'utils.gui.poll'
require 'utils.gui.config'
require 'utils.gui.game_settings'
require 'utils.gui.warp_system'
local RPG_Settings = require 'features.modules.rpg.table'
require 'features.functions.auto_bot'
require 'features.functions.chatbot'
require 'features.functions.antigrief'
require 'features.modules.corpse_markers'
require 'features.modules.floaty_chat'
require 'features.modules.autohotbar'
require 'features.modules.autostash'
require 'features.modules.tree_decon'
require 'features.modules.autofill'
require 'features.modules.enable_loaders'
require 'features.modules.portable_surface.main'
require 'features.modules.spawn_ent.main'
require 'features.commands.repair'
require 'features.commands.bonus'
require 'features.commands.misc'
require 'features.commands.map_restart'
require 'features.modules.infinity_chest'
require 'features.modules.portable_chest'
require 'features.modules.bp'
-- require 'features.modules.winter'

---! load from config/map
-- require 'map_loader'
--require 'map_builder'

local function is_game_modded()
    local i = 0
    for k, _ in pairs(game.active_mods) do
        i = i + 1
        if i > 1 then
            return true
        end
    end
    return false
end

-- Event.add(
--     defines.events.on_player_joined_game,
--     function(e)
--         local player = game.get_player(e.player_index)
--         player.insert({name = 'car'})
--         player.insert({name = 'express-transport-belt', count = 100})
--         player.insert({name = 'coin', count = 100000})
--     end
-- )

Event.on_init(
    function()
        local is_modded = is_game_modded()
        game.forces.player.research_queue_enabled = true
        if is_modded then
            RPG_Settings.set_surface_name('nauvis')
        else
            RPG_Settings.set_surface_name('wbtc')
        end
        RPG_Settings.enable_health_and_mana_bars(true)
        RPG_Settings.enable_wave_defense(false)
        RPG_Settings.enable_mana(true)
        RPG_Settings.enable_flame_boots(true)
        RPG_Settings.personal_tax_rate(0.3)
        RPG_Settings.enable_stone_path(true)
        RPG_Settings.enable_one_punch(true)
        RPG_Settings.enable_one_punch_globally(false)
        RPG_Settings.enable_auto_allocate(true)
        RPG_Settings.disable_cooldowns_on_spells()
    end
)

--! DEBUG SETTINGS
if _DUMP_ENV then
    require 'utils.dump_env'
end

require 'utils.profiler'
