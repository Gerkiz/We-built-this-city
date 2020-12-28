local Event = require 'utils.event'
local TownyTable = require 'features.modules.towny.table'
local Biters = require 'features.modules.towny.biters'
local Combat_balance = require 'features.modules.towny.combat_balance'
local Building = require 'features.modules.towny.building'
local Info = require 'features.modules.towny.info'
local Market = require 'features.modules.towny.market'
local Team = require 'features.modules.towny.team'
local Town_center = require 'features.modules.towny.town_center'
require 'features.modules.towny.commands'

local function on_player_respawned(event)
    local player = game.players[event.player_index]
    if player.force.index ~= 1 then
        return
    end
    Team.set_player_to_outlander(player)
    Team.give_outlander_items(player)
    Biters.clear_spawn_for_player(player)
end

local function on_player_used_capsule(event)
    Combat_balance.fish(event)
end

local function on_built_entity(event)
    if Building.prevent_isolation(event) then
        return
    end
    Building.restrictions(event)
end

local function on_robot_built_entity(event)
    if Building.prevent_isolation(event) then
        return
    end
    Building.restrictions(event)
end

local function on_player_built_tile(event)
    Building.prevent_isolation_landfill(event)
end

local function on_robot_built_tile(event)
    Building.prevent_isolation_landfill(event)
end

local function on_entity_died(event)
    local entity = event.entity
    if entity.name == 'market' then
        Team.kill_force(entity.force.name)
    end
end

local function on_entity_damaged(event)
    local entity = event.entity
    if not (entity and entity.valid) then
        return
    end
    if entity.name == 'market' then
        Town_center.set_market_health(entity, event.final_damage_amount)
    end
end

local function on_player_repaired_entity(event)
    local entity = event.entity
    if not (entity and entity.valid) then
        return
    end
    if entity.name == 'market' then
        Town_center.set_market_health(entity, -4)
    end
end

local function on_player_dropped_item(event)
    local player = game.players[event.player_index]
    local entity = event.entity
    if not (entity and entity.valid) then
        return
    end
    if entity.stack.name == 'raw-fish' then
        Team.ally_town(player, entity)
        return
    end
    if entity.stack.name == 'coal' then
        Team.declare_war(player, entity)
        return
    end
end

local function on_console_command(event)
    Team.set_town_color(event)
end

local function on_market_item_purchased(event)
    Market.offer_purchased(event)
    Market.refresh_offers(event)
end

local function on_gui_opened(event)
    Market.refresh_offers(event)
end

local function on_gui_click(event)
    Info.close(event)
    Info.toggle(event)
end

local function on_research_finished(event)
    Combat_balance.research(event)
    local towny = TownyTable.get('towny')
    local town_center = towny.town_centers[event.research.force.name]
    if town_center then
        town_center.research_counter = town_center.research_counter + 1
    end

    local town_centers_placeholders = towny.town_centers_placeholders[event.research.force.name]
    if town_centers_placeholders then
        town_centers_placeholders.research_counter = town_centers_placeholders.research_counter + 1
    end
end

local function on_player_died(event)
    local player = game.players[event.player_index]
    if not player.character then
        return
    end
    if not player.character.valid then
        return
    end
    Team.reveal_entity_to_all(player.character)
end

local tick_actions = {
    [60 * 5] = Team.update_town_chart_tags,
    [60 * 10] = Team.set_all_player_colors,
    -- [60 * 20] = Biters.wipe_units_out_of_evo_range,
    [60 * 25] = Biters.unit_groups_start_moving,
    [60 * 40] = Biters.validate_swarms,
    [60 * 45] = Biters.swarm,
    [60 * 50] = Biters.swarm_non_markets
}

local function on_nth_tick()
    local tick = game.tick % 3600
    if not tick_actions[tick] then
        return
    end
    tick_actions[tick]()
end

local function on_init()
    game.difficulty_settings.technology_price_multiplier = 1.4
    game.map_settings.pollution.enabled = true
    game.map_settings.enemy_expansion.enabled = true

    Team.setup_player_force()
end

Event.on_init(on_init)
Event.on_nth_tick(60, on_nth_tick)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_console_command, on_console_command)
Event.add(defines.events.on_entity_damaged, on_entity_damaged)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_opened, on_gui_opened)
Event.add(defines.events.on_market_item_purchased, on_market_item_purchased)
Event.add(defines.events.on_player_died, on_player_died)
Event.add(defines.events.on_player_dropped_item, on_player_dropped_item)
Event.add(defines.events.on_player_repaired_entity, on_player_repaired_entity)
Event.add(defines.events.on_player_respawned, on_player_respawned)
Event.add(defines.events.on_player_used_capsule, on_player_used_capsule)
Event.add(defines.events.on_research_finished, on_research_finished)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_robot_built_tile, on_robot_built_tile)
Event.add(defines.events.on_player_built_tile, on_player_built_tile)
