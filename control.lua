--! control stages
require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage
_DEBUG = false
_DUMP_ENV = false

local loaded = _G.package.loaded
local r = require
function require(path)
    local success, err = pcall(r, path)
    if not success then
        log(err)
    else
        return loaded[path] or log('Can only require files at runtime that have been required in the control stage.', 2)
    end
end

--! other stuff
local Event = require 'utils.event'

local m_gui = require 'mod-gui'
local mod = m_gui.get_button_flow
require 'utils.server_commands'
require 'utils.utils'
require 'utils.debug.command'
require 'utils.table'
require 'utils.surface'
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
require 'utils.biter_corpse_remover'

--! Role system
require 'utils.role.main'
local Role = require 'utils.role.permissions'
require 'utils.role.roles'
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
require 'features.modules.portable_surface.main'
require 'features.commands.repair'
require 'features.commands.bonus'
require 'features.commands.misc'
require 'features.commands.map_restart'
require 'features.modules.infinity_chest'
require 'features.modules.portable_chest'
require 'features.modules.bp'

---! load from config/map
require 'map_loader'
--require 'map_builder'

Event.add(
    defines.events.on_player_created,
    function(e)
        local player = game.get_player(e.player_index)
        mod(player).style = 'slot_table_spacing_horizontal_flow'
    end
)

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

if _DEBUG then
    require 'utils.profiler'
    function raw(string)
        return game.print(serpent.block(string))
    end
end

if _DUMP_ENV then
    require 'utils.dump_env'
end
