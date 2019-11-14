STARTING_RADIUS = 100
EASY_ORE_RADIUS = 200

if MODULE_LIST then
	module_list_add("dangOreus")
end

--Sprinkle ore everywhere
function gOre(event)
    local oldores = event.surface.find_entities_filtered{type="resource", area=event.area}
    local oils = {}
    for k, v in pairs(oldores) do
        if v.prototype.resource_category == "basic-solid" then
            v.destroy()
        else
			table.insert(oils, v)
		end
    end

    --Generate our random once for the whole chunk.
    local rand = math.random()

    --What kind of chunk are we generating?  Biased, ore, or random?
    --Check our global table of nearby chunks.
    --If any nearby chunks use the biased table, we must use the matching that ore to determine ore type.
    -- chunk_type starts off as a table in case it borders multiple biased patches, then we collapse it after checking neighbors
    local chunk_type = {}
    local biased = false
    local chunkx = event.area.left_top.x
    local chunky = event.area.left_top.y

    local function check_chunk_bias(x,y)
        if global.ore_chunks[x] then
            if global.ore_chunks[x][y] then
                if global.ore_chunks[x][y].biased then
                    table.insert(chunk_type, global.ore_chunks[x][y].type)
                end
            end
        end
    end

    local function check_chunk_type(x,y)
        if global.ore_chunks[x] then
            if global.ore_chunks[x][y] then
                table.insert(chunk_type, global.ore_chunks[x][y].type)
                return
            end
        end
        -- Still here? Insert random.
        table.insert(chunk_type, "random")
    end

    --starting from top, clockwise
    check_chunk_bias(chunkx, chunky-32)
    check_chunk_bias(chunkx+32, chunky)
    check_chunk_bias(chunkx, chunky+32)
    check_chunk_bias(chunkx-32, chunky)

    --Collapse table
    if #chunk_type > 0 then
        chunk_type = chunk_type[math.random(#chunk_type)]
        -- chance this chunk is also biased.
        if math.random() < 0.25 then
            biased = true
        end
    else
        --Repeat process for non-biased chunks
        check_chunk_type(chunkx, chunky-32)
        check_chunk_type(chunkx+32, chunky)
        check_chunk_type(chunkx, chunky+32)
        check_chunk_type(chunkx-32, chunky)

        chunk_type = chunk_type[math.random(#chunk_type)]
        --If type is not random, chance chunk is biased.
        --If type is random, chance chunk type is different.
        if chunk_type == "random" then
            if math.random() < 0.25 then
                chunk_type = global.diverse_ore_list[math.random(#global.diverse_ore_list)]
            end
        else
            if math.random() < 0.25 then
                biased = true
            end
        end
    end

    --Set global table with this type/bias
    if not global.ore_chunks[chunkx] then
        global.ore_chunks[chunkx] = {}
    end
    global.ore_chunks[chunkx][chunky] = {type=chunk_type, biased=biased}

    for x = event.area.left_top.x, event.area.left_top.x + 31 do
        for y = event.area.left_top.y, event.area.left_top.y + 31 do
            local bbox = {{ x, y}, {x+0.5, y+0.5}}
            if event.surface.get_tile(x,y).collides_with("ground-tile") and event.surface.count_entities_filtered{type="cliff", area=bbox} == 0 then
                local amount = (x^2 + y^2)^0.75 / 8
                if x^2 + y^2 >= STARTING_RADIUS^2 then
                    --Build the ore list.  Uranium can only appear in uranium chunks.
                    local ore_list = {}
                    for k, v in pairs(global.easy_ore_list) do
                        table.insert(ore_list, v)
                    end
                    if not (chunk_type == "random") then
                        --Build the ore list.  non-baised chunks get 3 instances, biased chunks get 6.  Except uranium, which has no default instance in the table.
                        table.insert(ore_list, chunk_type)
                        --table.insert(ore_list, chunk_type)
                        if biased then
                            table.insert(ore_list, chunk_type)
                            table.insert(ore_list, chunk_type)
                            --table.insert(ore_list, chunk_type)
                        end
                        --game.print(serpent.line(ore_list))
                    end

                    local type = ore_list[math.random(#ore_list)]
                    --With noise
                    event.surface.create_entity{name=type, amount=amount, position={x, y}, enable_tree_removal=false, enable_cliff_removal=false}
                end
            end
        end
    end

    --Ore blocks oil from rendering the resource radius.  Clean up any resources around oil.
	for k, v in pairs(oils) do
		local overlap = v.surface.find_entities_filtered{type="resource", area=v.bounding_box}
		for n, p in pairs(overlap) do
			if p.prototype.resource_category == "basic-solid" then
				p.destroy()
			end
		end
	end
end

--Auto-destroy non-mining drills.
function dangOre(event)
    if not (event.created_entity and event.created_entity.valid) then
        return
    end
    if event.created_entity.type == "mining-drill" or event.created_entity.type == "car" or not event.created_entity.health then
        return
    end
    --Some entities have no bounding box area.  Not sure which.
    if event.created_entity.bounding_box.left_top.x == event.created_entity.bounding_box.right_bottom.x or event.created_entity.bounding_box.left_top.y == event.created_entity.bounding_box.right_bottom.y then
        return
    end
    if false then --Dificulty setting
		if event.created_entity.type == "transport-belt" or
		event.created_entity.type == "underground-belt" or
		event.created_entity.type == "splitter" or
		event.created_entity.type == "electric-pole" or
		event.created_entity.type == "container" or
		event.created_entity.type == "logistic-container" then
			return
		end
	end
    local last_user = event.created_entity.last_user
    local ores = event.created_entity.surface.count_entities_filtered{type="resource", area=event.created_entity.bounding_box}
    if ores > 0 then
        --Need to turn off ghosts left by dead buildings so construction bots won't keep placing buildings and having them blow up.
        local ttl = event.created_entity.force.ghost_time_to_live
        local force = event.created_entity.force
        event.created_entity.force.ghost_time_to_live = 0
        event.created_entity.die()
        force.ghost_time_to_live = ttl
        if last_user then
            last_user.print("Cannot build non-miners on resources!")
        end
    end
end

--Destroying chests causes any contained ore to spill onto the ground.
function ore_rly(event)
    local items = {"stone", "coal", "iron-ore", "copper-ore", "uranium-ore"}
    if event.entity.type == "container" or event.entity.type == "cargo-wagon" then
        --Let's spill all items instead.
        for k,v in pairs(event.entity.get_inventory(defines.inventory.chest).get_contents()) do
            event.entity.surface.spill_item_stack(event.entity.position, {name=k, count=v})
        end
        -- for k, v in pairs(items) do
        --     if event.entity.get_item_count(v) > 0 then
        --         event.entity.surface.spill_item_stack(event.entity.position, {name=v, count=event.entity.get_item_count(v)})
        --     end
        -- end
    end
end

--Unchart one random chunk per minute to keep the map remotely sane.
function unchOret(event)
    if not (event.tick % (60*60) == 0) then
        return
    end

    local chunks = {}
    for chunk in game.surfaces[1].get_chunks() do
        if game.forces.player.is_chunk_charted("1", {chunk.x, chunk.y}) then
            if not game.forces.player.is_chunk_visible("1", {chunk.x, chunk.y}) then
                table.insert(chunks, {x=chunk.x, y=chunk.y})
            end
        end
    end

    if #chunks > 0 then
        local chunk = chunks[math.random(#chunks)]
        game.forces.player.unchart_chunk({chunk.x, chunk.y}, "1")
    end
end

--Limit exploring
function flOre_is_lava(event)
    if not (event.tick % (300) == 31) then
        return
    end
    for n, p in pairs(game.connected_players) do
        if not p.character then --Spectator or admin
            return
        end
        if math.abs(p.position.x) > EASY_ORE_RADIUS or math.abs(p.position.y) > EASY_ORE_RADIUS then
            --Check for nearby ore.
            local count = p.surface.count_entities_filtered{type="resource", area={{p.position.x-10, p.position.y-10}, {p.position.x+10, p.position.y+10}}}
            if count > 350 then
                if p.vehicle then
                    p.surface.create_entity{name="acid-projectile-purple", target=p.vehicle, position=p.vehicle.position, speed=10}
                    p.vehicle.health = p.vehicle.health - 50
                else
                    p.surface.create_entity{name="acid-projectile-purple", target=p.character, position=p.character.position, speed=10}
                    p.character.health = p.character.health - 10
                end
            end
        end
    end
end

--Build the list of ores
function divOresity_init()
    --Each chunk picks a table to generate from.  Each table has either 3 copies of one ore, or 6 copies.
    global.easy_ore_list = {}
	global.diverse_ore_list = {}

    global.ore_chunks = {}

    --These are depreciated.
    -- global.easy_ores = {}
    -- global.diverse_ores = {}
    

	for k,v in pairs(game.entity_prototypes) do
        if v.type == "resource" and v.resource_category == "basic-solid" then--[ and not (game.surfaces[1].map_gen_settings.autoplace_controls[v.name].size == "none") then
            table.insert(global.diverse_ore_list, v.name)
            if v.mineable_properties.required_fluid == nil then
			    table.insert(global.easy_ore_list, v.name)
            end
		end
	end

    --Check to see if we're playing normal.  Marathon requires more copper.
    if game.difficulty_settings.recipe_difficulty == 0 then
        --This is a hack to make the ratios easier to handle.
        --This hack only makes sense for vanilla ores.
        local vanilla_ores = false
        for k,v in pairs(global.easy_ore_list) do
            if v == "iron-ore" then
                vanilla_ores = true
                break
            end
        end
        if vanilla_ores then
            --1:1:1:1 creates way too much copper, stone.  Coal at least can be liquefied.
            --This changes it to a 3:2:2:1 ratio
            --table.insert(global.diverse_ore_list, "iron-ore")
            table.insert(global.easy_ore_list, "iron-ore")
            table.insert(global.easy_ore_list, "iron-ore")
            table.insert(global.easy_ore_list, "copper-ore")
            table.insert(global.easy_ore_list, "coal")
        end
    end

    --Easy ores
    -- for k, v in pairs(global.easy_ore_list) do
    --     local ore = {}
    --     local biased = {}
    --     local random = {}
        
    --     for i = 1, 2 do
    --         table.insert(ore, v)
    --         table.insert(biased, v)
    --     end
    --     for i = 1, 3 do
    --         table.insert(biased, v)
    --     end
    --     for n, p in pairs(global.easy_ore_list) do
    --         table.insert(ore, p)
    --         table.insert(biased, p)
    --         table.insert(random, p)
    --     end
    --     table.insert(global.easy_ores, ore)
    --     table.insert(global.easy_ores, biased)
    --     table.insert(global.easy_ores, random)
    -- end

    -- --Diverse ores
    -- for k, v in pairs(global.diverse_ore_list) do
    --     local ore = {}
    --     local biased = {}
    --     local random = {}
        
    --     for i = 1, 2 do
    --         table.insert(ore, v)
    --         table.insert(biased, v)
    --     end
    --     for i = 1, 3 do
    --         table.insert(biased, v)
    --     end
    --     for n, p in pairs(global.diverse_ore_list) do
    --         table.insert(ore, p)
    --         table.insert(biased, p)
    --         table.insert(random, p)
    --     end
    --     table.insert(global.diverse_ores, ore)
    --     table.insert(global.diverse_ores, biased)
    --     table.insert(global.diverse_ores, random)
    -- end

end

Event.register(defines.events.on_built_entity, dangOre)
Event.register(defines.events.on_robot_built_entity, dangOre)
Event.register(defines.events.on_chunk_generated, gOre)
Event.register(defines.events.on_entity_died, ore_rly)
Event.register(defines.events.on_tick, unchOret)
Event.register(defines.events.on_tick, flOre_is_lava)
Event.register(-1, divOresity_init)