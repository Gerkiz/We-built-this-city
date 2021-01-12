local Global = require 'utils.global'
local Event = require 'utils.event'
local Gui = require 'utils.gui.core'

local insert = table.insert
local remove = table.remove

local this = {}
local Public = {}

Global.register(
    this,
    function(tbl)
        this = tbl
    end
)

local function included(tbl, key, val, string_to_find)
    local newKey = false
    local newValue = false
    for index, value in pairs(tbl) do
        if index == val or value == val then
            if key then
                if type(value) == 'table' then
                    for i, v in pairs(value) do
                        if string_to_find and v == string_to_find then
                            newKey = i
                            newValue = v
                        end
                    end
                end
            else
                newKey = index
                newValue = value
            end
        end
    end

    return newKey, newValue
end

local function removeKeyValue(tbl, string_to_find)
    for index, value in pairs(tbl) do
        if index == string_to_find then
            tbl[index] = nil
        end

        if type(value) == 'table' then
            for i, v in pairs(value) do
                if v == string_to_find then
                    tbl[index][i] = nil
                end
            end
        end
    end
end

local function insert_into_pvp_forces(value)
    if not included(this.towny.pvp_forces, false, value) then
        insert(this.towny.pvp_forces, value)
    end
end

local function remove_from_pvp_forces(value)
    local index = included(this.towny.pvp_forces, false, value)
    if index then
        remove(this.towny.pvp_forces, index)
    end
end

local function insert_into_alliance(requesting_force, target_force)
    if not this.towny.alliances[requesting_force.name] then
        this.towny.alliances[requesting_force.name] = {}
    end
    insert(this.towny.alliances[requesting_force.name], target_force.name)
end

local function remove_from_alliances(requesting_force, string_to_find)
    local index = included(this.towny.alliances, true, requesting_force.name, string_to_find)
    if index then
        remove(this.towny.alliances[requesting_force.name], index)
    end
end

function Public.form_alliances()
    for source_team, dest_team in pairs(this.towny.alliances) do
        for i = 1, #dest_team do
            local source_force = game.forces[source_team]
            local dest_force = game.forces[dest_team[i]]
            if source_force and dest_force then
                source_force.set_friend(dest_force, true)
            end
        end
    end
end

function Public.set_pvp_for_forces()
    if next(this.towny.pvp_forces) then
        for i = 1, #this.towny.pvp_forces do
            if next(this.towny.pvp_forces) then
                for ii = 1, #this.towny.pvp_forces do
                    local f1 = game.forces[this.towny.pvp_forces[i]]
                    local f2 = game.forces[this.towny.pvp_forces[ii]]
                    if f1 and f2 then
                        f1.set_cease_fire('player', true)
                        f1.set_friend('player', false)
                        f1.set_cease_fire('enemy', false)
                        f1.set_friend('enemy', false)
                        f1.set_cease_fire(f2, false)
                        f1.set_friend(f2, false)
                        f2.set_cease_fire('player', true)
                        f2.set_friend('player', false)
                        f2.set_cease_fire('enemy', false)
                        f2.set_friend('enemy', false)
                        f2.set_cease_fire(f1, false)
                        f2.set_friend(f1, false)
                    end
                end
            end
        end
    end
end

function Public.reset_force_with_players(force, killed)
    for _, player in pairs(force.players) do
        removeKeyValue(this.towny.alliances, player.name)
        removeKeyValue(this.towny.alliances, player.force.name)
        remove_from_pvp_forces(player.force.name)
        local pvp_player = this.towny.town_centers[tostring(player.name)]
        local pvp_force = this.towny.town_centers[tostring(player.force.name)]
        local pvp_placeholder_player = this.towny.town_centers_placeholders[tostring(player.name)]
        local pvp_placeholder_force = this.towny.town_centers_placeholders[tostring(player.force.name)]
        local Team = is_loaded('features.modules.towny.team')

        if pvp_player or pvp_force then
            if pvp_player then
                this.towny.town_centers[tostring(player.name)] = nil
                this.towny.size_of_town_centers = this.towny.size_of_town_centers - 1
            elseif pvp_force then
                if Team and not killed then
                    Team.kill_force(player.force.name)
                end
                this.towny.town_centers[tostring(player.force.name)] = nil
                this.towny.size_of_town_centers = this.towny.size_of_town_centers - 1
            end
            if this.towny.size_of_town_centers <= 0 then
                this.towny.size_of_town_centers = 0
            end
        elseif pvp_placeholder_player or pvp_placeholder_force then
            if pvp_placeholder_player then
                this.towny.town_centers_placeholders[tostring(player.name)] = nil
                this.towny.size_of_placeholders_towns = this.towny.size_of_placeholders_towns - 1
            elseif pvp_placeholder_force then
                if Team and not killed then
                    Team.kill_force(player.force.name)
                end
                this.towny.town_centers_placeholders[tostring(player.force.name)] = nil
                this.towny.size_of_placeholders_towns = this.towny.size_of_placeholders_towns - 1
            end
            if this.towny.size_of_placeholders_towns <= 0 then
                this.towny.size_of_placeholders_towns = 0
            end
        end

        local sS = is_loaded('map_gen.multiplayer_spawn.separate_spawns')
        if sS then
            sS.SeparateSpawnsPlayerCreated(player.index)
        end

        if Gui.get_button_flow(player)['towny_map_intro_button'] then
            Gui.get_button_flow(player)['towny_map_intro_button'].destroy()
        end

        Public.add_to_reset_player(player)
    end

    Public.set_pvp_for_forces()
    Public.form_alliances()
end

function Public.reset_table()
    this.towny = {
        build_isolation = false,
        requests = {},
        request_cooldowns = {},
        town_centers_placeholders = {},
        town_centers = {},
        pvp = {},
        pvp_forces = {},
        alliances = {},
        players_to_reset = {},
        cooldowns = {},
        size_of_town_centers = 0,
        size_of_placeholders_towns = 0,
        swarms = {},
        disable_wipe_units_out_of_evo_range = false,
        towny_enabled = false
    }
end

function Public.get(key)
    if key then
        return this[key]
    else
        return this
    end
end

function Public.add_to_pvp(player)
    if player and player.valid then
        this.towny.pvp[player.index] = true
        return this.towny.pvp[player.index]
    end
    return false
end

function Public.add_to_reset_player(player)
    if player and player.valid then
        this.towny.players_to_reset[player.index] = true
        return this.towny.players_to_reset[player.index]
    end
    return false
end

function Public.remove_player_to_reset(player)
    if player and player.valid then
        if this.towny.players_to_reset[player.index] then
            this.towny.players_to_reset[player.index] = nil
            return true
        else
            return false
        end
    end
    return false
end

function Public.get_reset_player(player)
    if player and player.valid then
        if this.towny.players_to_reset[player.index] then
            return true
        else
            return false
        end
    end
    return false
end

function Public.add_to_pvp_forces(force)
    insert_into_pvp_forces(force.name)
    return this.towny.pvp_forces
end

function Public.remove_from_pvp_forces(force)
    remove_from_pvp_forces(force.name)
    return this.towny.pvp_forces
end

function Public.add_to_alliances(requesting_force, target_force)
    insert_into_alliance(requesting_force, target_force)
    Public.form_alliances()
    return this.towny.alliances
end

function Public.remove_from_alliances(requesting_force, string_to_find)
    remove_from_alliances(requesting_force, string_to_find)
    Public.set_pvp_for_forces()
    return this.towny.alliances
end

function Public.disable_pvp(player)
    if player and player.valid then
        this.towny.pvp[player.index] = false
        return this.towny.pvp[player.index]
    end
end

function Public.get_pvp(player, name)
    if player and player.valid then
        if this.towny.pvp[player.index] then
            if name then
                return player.name
            else
                return this.towny.pvp[player.index]
            end
        end
        return false
    end
end

function Public.get_build_isolation()
    return this.towny.build_isolation
end

function Public.set_build_isolation(value)
    this.towny.build_isolation = value or false
    return this.towny.build_isolation
end

function Public.get_towny_enabled()
    return this.towny.towny_enabled
end

function Public.set_towny_enabled(value)
    this.towny.towny_enabled = value or false
    return this.towny.towny_enabled
end

function Public.get_pvp_tbl()
    return this.towny.pvp_forces
end

function Public.get_alliances_tbl()
    return this.towny.alliances
end

function Public.set(key, value)
    if key and (value or value == false) then
        this[key] = value
        return this[key]
    elseif key then
        return this[key]
    else
        return this
    end
end

local on_init = function()
    Public.reset_table()
end

Event.on_init(on_init)

return Public
