-- control stages
require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage
_DEBUG = false
_DUMP_ENV = false

--require 'map_gen.custom_maps.test'
local loaded = _G.package.loaded
local require_return_err = true
local _require = require
require = function(path)
    local _path = path
    local _return = {pcall(_require, path)}
    if not table.remove(_return, 1) then
        local __return = {pcall(_require, path)}
        if not table.remove(__return, 1) then
            if _DEBUG then
                log('Failed to load: ' .. _path .. ' (' .. _return[1] .. ')')
                log('Also Attemped: ' .. path .. ' (' .. __return[1] .. ')')
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
    return unpack(_return) and loaded[path]
end

-- other stuff
local Event = require 'utils.event'
require 'utils.server'
require 'utils.server_commands'
require 'utils.utils'
require 'utils.table'
require 'utils.color_data'
require 'utils.session_data'
require 'utils.player_modifiers'
require 'utils.surface'

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
require 'features.modules.rpg'

--- load from config/map
-- Oarc
--require 'config'

-- generated maps
require 'map_builder'

-- lua profiler by boodals
if _DEBUG then
    require 'utils.debug.command'
    require 'utils.profiler'
    function raw(string)
        return game.print(serpent.block(string))
    end
end

if not _DEBUG then
    require 'utils.debug.safe.command'
end

if _DUMP_ENV then
    require 'utils.dump_env'
end

local function on_init()
    game.forces.player.research_queue_enabled = true
end

Event.on_init(on_init)
