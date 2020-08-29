-- control stages
require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage
_DEBUG = false
_DUMP_ENV = false

--require 'map_gen.custom_maps.test'
local loaded = _G.package.loaded
local require_return_err = false
local _require = require
function require(path)
    local _path = path
    local _return = {pcall(_require, path)}
    if not table.remove(_return, 1) then
        local __return = {pcall(_require, path)}
        if not table.remove(__return, 1) then
            if _DEBUG then
                log('Failed to load: ' .. _path .. ' (' .. _return[1] .. ')')
            end
            if require_return_err then
                error(unpack(_return))
            end
        else
            if _DEBUG then
                log('Loaded: ' .. _path)
                return unpack(__return)
            end
        end
    else
        if _DEBUG then
            log('Loaded: ' .. _path)
        end
    end
    return unpack(_return) and loaded[path] or
        error('Can only require files at runtime that have been required in the control stage.', 2)
end

-- other stuff
local Event = require 'utils.event'
local GameSurface = require 'utils.surface'
require 'utils.server_commands'
require 'utils.utils'
require 'utils.debug.command'
require 'utils.table'
require 'utils.datastore.color_data'
require 'utils.datastore.session_data'
require 'utils.datastore.jail_data'
require 'utils.datastore.quickbar_data'
require 'utils.datastore.message_on_join_data'
require 'utils.datastore.player_tag_data'
require 'utils.player_modifiers'
require 'utils.command_handler'
require 'utils.biter_corpse_remover'

-- Role system
require 'utils.role.main'
local Role = require 'utils.role.permissions'
require 'utils.role.roles'
Role.adjust_permission()

-- gui and modules
require 'utils.gui.main'
require 'utils.gui.player_list'
require 'utils.gui.admin'
require 'utils.gui.group'
require 'utils.gui.poll'
require 'utils.gui.score'
require 'utils.gui.config'
require 'utils.gui.game_settings'
require 'utils.gui.warp_system'
require 'features.functions.auto_bot'
require 'features.functions.chatbot'
require 'features.functions.antigrief'
require 'features.modules.corpse_markers'
require 'features.modules.floaty_chat'
require 'features.modules.autohotbar'
require 'features.modules.autostash'
require 'features.modules.tree_decon'
require 'features.commands.repair'
require 'features.commands.bonus'
require 'features.commands.misc'
require 'features.commands.map_restart'
require 'features.modules.bp'

--- load from config/map
-- Oarc
require 'map_loader'
-- GameSurface.set_modded(true)

-- generated maps
--require 'map_builder'

-- RPG
local RPG_Settings = require 'features.modules.rpg.table'
require 'features.modules.rpg.main'

-- lua profiler by boodals
if _DEBUG then
    require 'utils.profiler'
    function raw(string)
        return game.print(serpent.block(string))
    end
end

if _DUMP_ENV then
    require 'utils.dump_env'
end

Event.on_init(
    function()
        game.forces.player.research_queue_enabled = true
        RPG_Settings.set_surface_name('wbtc')
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
