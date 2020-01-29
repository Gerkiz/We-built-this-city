local Session = require 'utils.session_data'
local Modifiers = require 'utils.player_modifiers'
local Server = require 'utils.server'
local Color = require 'utils.color_presets'
local Roles = require 'utils.role.table'
local Event = require 'utils.event'

commands.add_command(
    'spaghetti',
    'Does spaghett.',
    function(cmd)
		local p_modifer = Modifiers.get_table()
        local player = game.player
        local _a = p_modifer
        local param = tostring(cmd.parameter)
        local force = game.forces["player"]
        local p

        if player then
            if player ~= nil then
                if not Roles.get_role(player):allowed('spaghetti') then
                    p = Server.player_return
                    p("[ERROR] Only admins are allowed to run this command!", Color.fail, player)
                    return
                end
            end
        end

        if param == nil then Server.player_return("[ERROR] Arguments are true/false", Color.yellow, player) return end
        if param == "true" then
			if not _a.spaghetti_are_you_sure then
				_a.spaghetti_are_you_sure = true
				Server.player_return("Spaghetti is not enabled, run this command again to enable spaghett", Color.yellow, player)
				return
			end
			if _a.spaghetti_enabled == true then Server.player_return("Spaghetti is already enabled.", Color.yellow, player) return end
			game.print("The world has been spaghettified!", Color.success)
			force.technologies["logistic-system"].enabled = false
			force.technologies["construction-robotics"].enabled = false
			force.technologies["logistic-robotics"].enabled = false
			force.technologies["robotics"].enabled = false
			force.technologies["personal-roboport-equipment"].enabled = false
			force.technologies["personal-roboport-mk2-equipment"].enabled = false
			force.technologies["character-logistic-trash-slots-1"].enabled = false
			force.technologies["character-logistic-trash-slots-2"].enabled = false
			force.technologies["auto-character-logistic-trash-slots"].enabled = false
			force.technologies["worker-robots-storage-1"].enabled = false
			force.technologies["worker-robots-storage-2"].enabled = false
			force.technologies["worker-robots-storage-3"].enabled = false
			force.technologies["character-logistic-slots-1"].enabled = false
			force.technologies["character-logistic-slots-2"].enabled = false
			force.technologies["character-logistic-slots-3"].enabled = false
			force.technologies["character-logistic-slots-4"].enabled = false
			force.technologies["character-logistic-slots-5"].enabled = false
			force.technologies["character-logistic-slots-6"].enabled = false
			force.technologies["worker-robots-speed-1"].enabled = false
			force.technologies["worker-robots-speed-2"].enabled = false
			force.technologies["worker-robots-speed-3"].enabled = false
			force.technologies["worker-robots-speed-4"].enabled = false
			force.technologies["worker-robots-speed-5"].enabled = false
			force.technologies["worker-robots-speed-6"].enabled = false
			_a.spaghetti_enabled = true
        elseif param == "false" then
			if _a.spaghetti_enabled == false or _a.spaghetti_enabled == nil then player.print("Spaghetti is already disabled.", Color.yellow) return end
			game.print("The world is no longer spaghett!", Color.yellow)
			force.technologies["logistic-system"].enabled = true
			force.technologies["construction-robotics"].enabled = true
			force.technologies["logistic-robotics"].enabled = true
			force.technologies["robotics"].enabled = true
			force.technologies["personal-roboport-equipment"].enabled = true
			force.technologies["personal-roboport-mk2-equipment"].enabled = true
			force.technologies["character-logistic-trash-slots-1"].enabled = true
			force.technologies["character-logistic-trash-slots-2"].enabled = true
			force.technologies["auto-character-logistic-trash-slots"].enabled = true
			force.technologies["worker-robots-storage-1"].enabled = true
			force.technologies["worker-robots-storage-2"].enabled = true
			force.technologies["worker-robots-storage-3"].enabled = true
			force.technologies["character-logistic-slots-1"].enabled = true
			force.technologies["character-logistic-slots-2"].enabled = true
			force.technologies["character-logistic-slots-3"].enabled = true
			force.technologies["character-logistic-slots-4"].enabled = true
			force.technologies["character-logistic-slots-5"].enabled = true
			force.technologies["character-logistic-slots-6"].enabled = true
			force.technologies["worker-robots-speed-1"].enabled = true
			force.technologies["worker-robots-speed-2"].enabled = true
			force.technologies["worker-robots-speed-3"].enabled = true
			force.technologies["worker-robots-speed-4"].enabled = true
			force.technologies["worker-robots-speed-5"].enabled = true
			force.technologies["worker-robots-speed-6"].enabled = true
			_a.spaghetti_enabled = false
	end
end)

commands.add_command(
    'generate_map',
    'Pregenerates map.',
    function(cmd)
		local p_modifer = Modifiers.get_table()
		local _a = p_modifer
        local player = game.player
        local param = tonumber(cmd.parameter)
        local p

        if player then
            if player ~= nil then
                if not Roles.get_role(player):allowed('pregen_map') then
                    p = Server.player_return
                    p("[ERROR] Only admins are allowed to run this command!", Color.fail, player)
                    return
                end
            end
        end
        if param == nil then Server.player_return("[ERROR] Must specify radius!", Color.fail, player) return end
        if param > 50 then Server.player_return("[ERROR] Value is too big.", Color.fail, player) return end

		if not _a.generate_map then
            _a.generate_map = true
            Server.player_return("[WARNING] This command will make the server LAG, run this command again if you really want to do this!", Color.yellow, player)
            return
        end
        local radius = param
		local surface = game.players[1].surface
			if surface.is_chunk_generated({radius, radius}) then
				game.print("Map generation done!", Color.success)
				_a.generate_map = nil
			return
		end
		surface.request_to_generate_chunks({0,0}, radius)
		surface.force_generate_chunk_requests()
		for _, pl in pairs(game.connected_players) do
			pl.play_sound{path="utility/new_objective", volume_modifier=1}
		end
		game.print("Map generation done!", Color.success)
		_a.generate_map = nil
end)

commands.add_command(
    'dump_layout',
    'Dump the current map-layout.',
    function()
		local p_modifer = Modifiers.get_table()
		local _a = p_modifer
        local player = game.player
        local p

        if player then
            if player ~= nil then
                if not Roles.get_role(player):allowed('dump_layout') then
                    p = Server.player_return
                    p("[ERROR] Only admins are allowed to run this command!", Color.fail, player)
                    return
                end
            end
        end
		if not _a.dump_layout then
            _a.dump_layout = true
            Server.player_return("[WARNING] This command will make the server LAG, run this command again if you really want to do this!", Color.yellow, player)
            return
        end
		local surface = game.players[1].surface
		game.write_file("layout.lua", "" , false)

		local area = {
				left_top = {x = 0, y = 0},
				right_bottom = {x = 32, y = 32}
		}

		local entities = surface.find_entities_filtered{area = area}
		local tiles = surface.find_tiles_filtered{area = area}

		for _, e in pairs(entities) do
			local str = "{position = {x = " ..  e.position.x
			str = str .. ", y = "
			str = str .. e.position.y
			str = str .. '}, name = "'
			str = str .. e.name
			str = str .. '", direction = '
			str = str .. tostring(e.direction)
			str = str .. ', force = "'
			str = str .. e.force.name
			str = str .. '"},'
			if e.name ~= "character" then
				game.write_file("layout.lua", str .. '\n' , true)
			end
		end

		game.write_file("layout.lua",'\n' , true)
		game.write_file("layout.lua",'\n' , true)
		game.write_file("layout.lua",'Tiles: \n' , true)

		for _, t in pairs(tiles) do
			local str = "{position = {x = " ..  t.position.x
			str = str .. ", y = "
			str = str .. t.position.y
			str = str .. '}, name = "'
			str = str .. t.name
			str = str .. '"},'
			game.write_file("layout.lua", str .. '\n' , true)
			Server.player_return("Dumped layout as file: layout.lua", Color.success, player)
		end
		_a.dump_layout = false
end)

commands.add_command(
    'creative',
    'Enables creative_mode.',
    function()
		local p_modifer = Modifiers.get_table()
		local _a = p_modifer
        local player = game.player
        local p

        if player then
            if player ~= nil then
                if not Roles.get_role(player):allowed('creative') then
                    p = Server.player_return
                    p("[ERROR] Only admins are allowed to run this command!", Color.fail, player)
                    return
                end
            end
        end
		if not _a.creative_are_you_sure then
            _a.creative_are_you_sure = true
            Server.player_return("[WARNING] This command will enable creative/cheat-mode for all connected players, run this command again if you really want to do this!", Color.yellow, player)
            return
        end
		if _a.creative_enabled == true then Server.player_return("[ERROR] Creative/cheat-mode is already active!", Color.fail, player) return end

        game.print(player.name .. " has activated creative-mode!", Color.warning)
        Server.to_discord_bold(table.concat{'[Creative] ' .. player.name .. ' has activated creative-mode!'})

        for k, v in pairs(game.connected_players) do
	        v.cheat_mode = true
	        v.insert{name="power-armor-mk2", count = 1}
			if v.character ~= nil then
		        local p_armor = v.get_inventory(5)[1].grid
		        p_armor.put({name = "fusion-reactor-equipment"})
		        p_armor.put({name = "fusion-reactor-equipment"})
		        p_armor.put({name = "fusion-reactor-equipment"})
		        p_armor.put({name = "exoskeleton-equipment"})
		        p_armor.put({name = "exoskeleton-equipment"})
		        p_armor.put({name = "exoskeleton-equipment"})
		        p_armor.put({name = "energy-shield-mk2-equipment"})
		        p_armor.put({name = "energy-shield-mk2-equipment"})
		        p_armor.put({name = "energy-shield-mk2-equipment"})
		        p_armor.put({name = "energy-shield-mk2-equipment"})
		        p_armor.put({name = "personal-roboport-mk2-equipment"})
		        p_armor.put({name = "night-vision-equipment"})
		        p_armor.put({name = "battery-mk2-equipment"})
		        p_armor.put({name = "battery-mk2-equipment"})
				local proto = game.item_prototypes
				local i = 0
				for name, item in pairs(proto) do
					i = i + 1
					if name and item.type ~= "mining-tool" then
						_a[k].character_inventory_slots_bonus["creative"] = tonumber(i)
						v.character_inventory_slots_bonus = _a[k].character_inventory_slots_bonus["creative"]
						v.insert{name=name, count=item.stack_size}
						Server.player_return("Inserted all base items.", Color.success, v)
						_a.creative_enabled = true
					end
				end
			end
		end
end)

commands.add_command(
    'clear-corpses',
    'Clears all the biter corpses..',
    function(cmd)
        local player = game.player
        local param = tonumber(cmd.parameter)
        local p

        if player then
            if player ~= nil then
                if not Roles.get_role(player):allowed('clear_corpses') then
                    p = Server.player_return
                    p("[ERROR] Only admins and trusted weebs are allowed to run this command!", Color.fail, player)
                    return
                end
            end
        end
	    if param == nil then Server.player_return("[ERROR] Must specify radius!", Color.fail, player) return end
	    if param > 500 then Server.player_return("[ERROR] Value is too big.", Color.fail, player) return end
	    local pos = player.position

        local radius = {{x = (pos.x + -param), y = (pos.y + -param)}, {x = (pos.x + param), y = (pos.y + param)}}
		for _, entity in pairs(player.surface.find_entities_filtered{area = radius, type = "corpse"}) do
			entity.destroy()
		end
		Server.player_return("Cleared biter-corpses.", Color.success, player)
end)

commands.add_command(
    'trust',
    'Promotes a player to trusted!',
    function(cmd)
        local trusted = Session.get_trusted_table()
        local server = 'Server'
        local player = game.player
        local p

        if player then
            if player ~= nil then
                if not Roles.get_role(player):allowed('trust') then
                    p = Server.player_return
                    p("[ERROR] Only admins and trusted weebs are allowed to run this command!", Color.fail, player)
                    return
                end
            end

            if cmd.parameter == nil then return end
            local target_player = game.players[cmd.parameter]
            if not target_player then return end
            if target_player then
                --if target_player.name == player.name then game.print("You can't trust yourself ;)", Color.info) return end
                if trusted[target_player.name] == true then Server.player_return(target_player.name .. " is already trusted!", Color.info, player) return end
                local target_role = Roles.get_role(target_player)
                local source_role = Roles.get_role(player)
                if source_role.power <= target_role.power then
                    Roles.give_role(target_player, 'Casual', player.name)
                end
                trusted[target_player.name] = true
                game.print(target_player.name .. " is now a trusted player.", Color.success)
                for _, a in pairs(game.connected_players) do
                    if a.admin == true and a.name ~= player.name then
                        a.print("[INFO]: " .. player.name .. " trusted " .. target_player.name, Color.info)
                        Server.to_admin_embed(table.concat{'[Info] ', player.name, ' has trusted ', target_player.name, '.'})
                    end
                end
            end
        else
            if cmd.parameter == nil then return end
            local target_player = game.players[cmd.parameter]
            if target_player then
                if trusted[target_player.name] == true then log(target_player.name .. " is already trusted!") return end
                trusted[target_player.name] = true
                game.print(target_player.name .. " is now a trusted player.", Color.success)
                Server.to_admin_embed(table.concat{'[Info] ', server, ' has trusted ', target_player.name, '.'})
            end
        end
    end
)

commands.add_command(
    'untrust',
    'Demotes a player from trusted!',
    function(cmd)
        local trusted = Session.get_trusted_table()
        local server = 'server'
        local player = game.player
        local p

        if player then
            if player ~= nil then
                if not Roles.get_role(player):allowed('untrust') then
                    p = Server.player_return
                    p("[ERROR] Only admins and trusted weebs are allowed to run this command!", Color.fail, player)
                    return
                end
            end

            if cmd.parameter == nil then return end
            local target_player = game.players[cmd.parameter]
            if not target_player then return end
            if target_player then
                if target_player.name == player.name then Server.player_return("You can't untrust yourself ;)", Color.info, player) return end
                if trusted[target_player.name] == false then Server.player_return(target_player.name .. " is already untrusted!", Color.info, player) return end
                local target_role = Roles.get_role(target_player)
                local source_role = Roles.get_role(player)
                if source_role.power <= target_role.power then
                    Roles.give_role(target_player, 'Rookie', player.name)
                end
                trusted[target_player.name] = false
                game.print(target_player.name .. " is now untrusted.", Color.success)
                for _, a in pairs(game.connected_players) do
                    if a.admin == true and a.name ~= player.name then
                        a.print("[ADMIN]: " .. player.name .. " untrusted " .. target_player.name, Color.info)
                        Server.to_admin_embed(table.concat{'[Info] ', player.name, ' has untrusted ', target_player.name, '.'})
                    end
                end
            end
        else
            if cmd.parameter == nil then return end
            local target_player = game.players[cmd.parameter]
            if target_player then
                if trusted[target_player.name] == false then log(target_player.name .. " is already untrusted!") return end
                trusted[target_player.name] = false
                game.print(target_player.name .. " is now untrusted.", Color.success)
                Server.to_admin_embed(table.concat{'[Info] ', server,  ' has untrusted ', target_player.name, '.'})
            end
        end
    end
)

local function on_console_command(event)
    local cmd = event.command
    if not event.player_index then return end
    local player = game.players[event.player_index]
    local reason = event.parameters
    if not reason then return end
    if cmd == 'ban' then
        if player then
            Server.to_banned_embed(table.concat{player.name .. ' banned ' .. reason})
            return
        else
            Server.to_banned_embed(table.concat{'Server banned ' .. reason})
            return
        end
    elseif cmd == 'unban' then
        if player then
            Server.to_banned_embed(table.concat{player.name .. ' unbanned ' .. reason})
            return
        else
            Server.to_banned_embed(table.concat{'Server unbanned ' .. reason})
            return
        end
    end
end

Event.add(defines.events.on_console_command, on_console_command)