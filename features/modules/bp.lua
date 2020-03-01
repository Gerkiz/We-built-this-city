local event  = require "utils.event"
local MAX_CONFIG_SIZE = 16
local MAX_STORAGE_SIZE = 12
local in_range_check_is_annoying = true
local available_storage_entries = {}

-- these items are checked as 'to' and disallow being set.
local banned_targets = {"landfill"} --"landfill" }

function global_init()
  global.config = global["config"] or {}
  global["config-tmp"] = global["config-tmp"] or {}
  global.storage = global["storage"] or {}
  global.storage_index = global["storage_index"] or {}
end

function get_type(entity)
    if game.entity_prototypes[entity] then
        return game.entity_prototypes[entity].type
    end
    if game.item_prototypes[entity] then
        return game.item_prototypes[entity].type
    end
    return ""
end

function count_keys(hashmap)

  local result = 0

  for _, __ in pairs(hashmap) do
    result = result + 1
  end

  return result

end

function get_config_item(player, index, type)

  if not global["config-tmp"][player.name]
  or index > #global["config-tmp"][player.name]
  or global["config-tmp"][player.name][index][type] == "" then
    return nil
  end
  if not game.item_prototypes[global["config-tmp"][player.name][index][type]] then
    return nil
  end
  if not game.item_prototypes[global["config-tmp"][player.name][index][type]].valid then
    return nil
  end

  return game.item_prototypes[global["config-tmp"][player.name][index][type]].name

end

function gui_init(player)
  local flow = mod_gui.get_frame_flow(player)
  if not flow.upgrade_planner_config_button then
    local button = flow.add
    {
      type = "sprite-button",
      name = "upgrade_planner_config_button",
      style = mod_gui.button_style,
      sprite = "item/fast-transport-belt",
      tooltip = {"upgrade-planner.button-tooltip"}
    }
    button.style.visible = true
  end
end

function gui_open_frame(player)

  local flow = player.gui.center

  local frame = flow.upgrade_planner_config_frame

      if frame then
        frame.destroy()
        if storage_frame then
            storage_frame.destroy()
        end
        global["config-tmp"][player.name] = nil
        return
    end

    -- If player config does not exist, we need to create it.

    global["config"][player.name] = global["config"][player.name] or {}

    -- Temporary config lives as long as the frame is open, so it has to be created
    -- every time the frame is opened.

    global["config-tmp"][player.name] = {}

    -- We need to copy all items from normal config to temporary config.

    local i = 0

    for i = 1, MAX_CONFIG_SIZE do

        if i > #global["config"][player.name] then
            global["config-tmp"][player.name][i] = { from = "", to = "" }
        else
            global["config-tmp"][player.name][i] = {
                is_module = global["config"][player.name][i].is_module,
                is_rail = global["config"][player.name][i].is_rail,
                from = global["config"][player.name][i].from,
                to = global["config"][player.name][i].to,
                from_curved_rail = global["config"][player.name][i].from_curved_rail,
                from_straight_rail = global["config"][player.name][i].from_straight_rail,
                to_curved_rail = global["config"][player.name][i].to_curved_rail,
                to_straight_rail = global["config"][player.name][i].to_straight_rail
            }
        end
        
    end

  -- Now we can build the GUI.
  frame = flow.add{
    type = "frame",
    caption = {"upgrade-planner.config-frame-title"},
    name = "upgrade_planner_config_frame",
    direction = "vertical"
  }
  if not global.storage_index then global.storage_index = {} end
  if not global.storage_index[player.name] then
    global.storage_index[player.name] = 1
  end
  local storage_flow = frame.add{type = "table", name = "upgrade_planner_storage_flow", column_count = 3}
  --storage_flow.style.horizontal_spacing = 2
  local drop_down = storage_flow.add{type = "drop-down", name = "upgrade_planner_drop_down"}
  --drop_down.style.minimal_height = 50
  drop_down.style.minimal_width = 164
  drop_down.style.maximal_width = 0
  if not global.storage then
    global.storage = {}
  end
  if not global.storage[player.name] then
    global.storage[player.name] = {}
  end
  for key, _ in pairs(global.storage[player.name]) do
    drop_down.add_item(key)
  end
  if not global.storage[player.name]["New storage"] then
    drop_down.add_item("New storage")
  end
  local items = drop_down.items
  local index = math.min(global.storage_index[player.name], #items)
  index = math.max(index, 1)
  drop_down.selected_index = index
  global.storage_index[player.name] = index
  local storage_to_restore = drop_down.get_item(drop_down.selected_index)
  local rename_button = storage_flow.add{type="sprite-button", name = "upgrade_planner_storage_rename", sprite = "utility/rename_icon_normal", tooltip = {"upgrade-planner.rename-button-tooltip"}}
  rename_button.style = "slot_button"
  rename_button.style.maximal_width = 24
  rename_button.style.minimal_width = 24
  rename_button.style.maximal_height = 24
  rename_button.style.minimal_height = 24
  local remove_button = storage_flow.add{type="sprite-button", name = "upgrade_planner_storage_delete", sprite = "utility/trash", tooltip = {"upgrade-planner.delete-storage-button-tooltip"} }
  remove_button.style = "red_slot_button"
  remove_button.style.maximal_width = 24
  remove_button.style.minimal_width = 24
  remove_button.style.maximal_height = 24
  remove_button.style.minimal_height = 24
  local rename_field = storage_flow.add{type = "textfield", name = "upgrade_planner_storage_rename_textfield", text = drop_down.get_item(drop_down.selected_index)}
  rename_field.style.visible = false
  local confirm_button = storage_flow.add{type="sprite-button", name = "upgrade_planner_storage_confirm", sprite = "utility/confirm_slot", tooltip = {"upgrade-planner.confirm-storage-name"} }
  confirm_button.style = "green_slot_button"
  confirm_button.style.maximal_width = 24
  confirm_button.style.minimal_width = 24
  confirm_button.style.maximal_height = 24
  confirm_button.style.minimal_height = 24
  confirm_button.style.visible = false
  local cancel_button = storage_flow.add{type="sprite-button", name = "upgrade_planner_storage_cancel", sprite = "utility/set_bar_slot", tooltip = {"upgrade-planner.cancel-storage-name"} }
  cancel_button.style = "red_slot_button"
  cancel_button.style.maximal_width = 24
  cancel_button.style.minimal_width = 24
  cancel_button.style.maximal_height = 24
  cancel_button.style.minimal_height = 24
  cancel_button.style.visible = false
  local ruleset_grid = frame.add{
    type = "table",
    column_count = 6,
    name = "upgrade_planner_ruleset_grid",
    style = "slot_table"
  }

  ruleset_grid.add{
    type = "label",
    caption = {"upgrade-planner.config-header-1"}
  }
  ruleset_grid.add{
    type = "label",
    caption = {"upgrade-planner.config-header-2"}
  }
  ruleset_grid.add{
    type = "label",
    caption = {"upgrade-planner.config-clear", "    "}
  }
  ruleset_grid.add{
    type = "label",
    caption = {"upgrade-planner.config-header-1"}
  }
  ruleset_grid.add{
    type = "label",
    caption = {"upgrade-planner.config-header-2"}
  }
  ruleset_grid.add{
    type = "label",
    caption = {"upgrade-planner.config-clear", ""}
  }
  local items = game.item_prototypes
  for i = 1, MAX_CONFIG_SIZE do
    local sprite = nil
    local tooltip = nil
    local from = get_config_item(player, i, "from")
    if from then
      --sprite = "item/"..get_config_item(player, i, "from")
      tooltip = items[from].localised_name
    end
    local elem = ruleset_grid.add{
      type = "choose-elem-button",
      name = "upgrade_planner_from_" .. i,
      style = "slot_button",
      --sprite = sprite,
      elem_type = "item",
      tooltip = tooltip
    }
    elem.elem_value = from
    local sprite = nil
    local tooltip = nil
    local to = get_config_item(player, i, "to")
    if to then
      --sprite = "item/"..get_config_item(player, i, "to")
      tooltip = items[to].localised_name
    end
    local elem = ruleset_grid.add{
      type = "choose-elem-button",
      name = "upgrade_planner_to_" .. i,
      --style = "slot_button",
      --sprite = sprite,
      elem_type = "item",
      tooltip = tooltip
    }
    elem.elem_value = to
    ruleset_grid.add{
      type = "sprite-button",
      name = "upgrade_planner_clear_" .. i,
      style = "red_slot_button",
      sprite = "utility/trash",
      tooltip = {"upgrade-planner.config-clear", ""}
    }
  end

  local button_grid = frame.add{
    type = "table",
    column_count = 4
  }
  button_grid.add{
    type = "sprite-button",
    name = "upgrade_blueprint",
    sprite = "item/blueprint-book",
    tooltip = {"upgrade-planner.config-button-upgrade-blueprint"},
    style = mod_gui.button_style
  }
  button_grid.add{
    type = "sprite-button",
    name = "give_upgrade_tool",
    sprite = "item/dummy-selection-tool",
    tooltip = {"upgrade-planner.config-button-give-upgrade-tool"},
    style = mod_gui.button_style
  }
  button_grid.add{
    type = "sprite-button",
    name = "upgrade_planner_import_config",
    sprite = "utility/import_slot",
    tooltip = {"upgrade-planner.config-button-import-config"},
    style = mod_gui.button_style
  }
  button_grid.add{
    type = "sprite-button",
    name = "upgrade_planner_export_config",
    sprite = "utility/export_slot",
    tooltip = {"upgrade-planner.config-button-export-config"},
    style = mod_gui.button_style
  }
  gui_restore(player, storage_to_restore)
  player.opened = frame
end

function gui_save_changes(player)

  -- Saving changes consists in:
  --   1. copying config-tmp to config
  --   2. removing config-tmp

  if global["config-tmp"][player.name] then
    local i = 0
    global.config[player.name] = {}
    for i = 1, #global["config-tmp"][player.name] do
      global.config[player.name][i] = {
        from = global["config-tmp"][player.name][i].from,
        to = global["config-tmp"][player.name][i].to
      }
    end
  end
  if not global.storage then
    global.storage = {}
  end
  if not global.storage[player.name] then
    global.storage[player.name] = {}
  end
  local gui = player.gui.center.upgrade_planner_config_frame
  if not gui then return end
  local drop_down = gui.upgrade_planner_storage_flow.children[1]
  local name = drop_down.get_item(global.storage_index[player.name])
  global.storage[player.name][name] = global.config[player.name]
end

function gui_set_rule(player, type, index, element)
  local items = game.item_prototypes
  local name = element.elem_value
  local frame = player.gui.center.upgrade_planner_config_frame
  local ruleset_grid = frame["upgrade_planner_ruleset_grid"]
  local storage_name = element.parent.parent.upgrade_planner_storage_flow.children[1].get_item(global.storage_index[player.name])
  local storage = global["config-tmp"][player.name]
  if not frame or not storage then return end
  local is_module = false;
  local is_rail = false;
  local curved_rail = nil;
  local straight_rail = nil;
  
  if type == "to" or type == "from" then 
    for _,to_type in pairs(banned_targets) do
        if element.elem_value == to_type then
        if storage[index][type] ~= '' then
            element.elem_value = storage[index][type]
        else
            element.elem_value = nil
        end
			player.print({"upgrade-planner.item-not-valid"})
        return
        end
    end
  end

  if not name then
    ruleset_grid["upgrade_planner_" .. type .. "_" .. index].tooltip = ""
    storage[index][type] = ""
    gui_save_changes(player)
    return
  end
  
  if name ~= "deconstruction-planner" or type ~= "to" then
  local opposite = "from"
  local i = 0
  if type == "from" then
  local opposite = "to"
    for i = 1, #storage do
      if index ~= i and storage[i].from == name then
        player.print({"upgrade-planner.item-already-set"})
        gui_restore(player, storage_name)
        return
      end
    end
  end
  local related = storage[index][opposite]
  if related ~= "" then
    if related == name then
      player.print({"upgrade-planner.item-is-same"})
      gui_restore(player, storage_name)
      return
    end
  if get_type(name) ~= get_type(related) and (not is_exception(get_type(name), get_type(related))) then
      player.print({"upgrade-planner.item-not-same-type"})
      if storage[index][type] ~= '' then
      element.elem_value = storage[index][type]
      else
      element.elem_value = nil;
      end
      return
    end
  end
 
    --game.write_file( 'planner.log', '(set config-tmp)Module is:'..tostring(is_module)..'\n',true,1);
    storage[index][type] = name
    storage[index]["is_module"] = is_module
    storage[index]["is_rail"] = is_rail
    storage[index][type.."_curved_rail"] = curved_rail
    storage[index][type.."_straight_rail"] = straight_rail

    
    ruleset_grid["upgrade_planner_" .. type .. "_" .. index].tooltip = game.item_prototypes[name].localised_name 
    --ruleset_grid["upgrade_planner_" .. type .. "_" .. index].tooltip = game.item_prototypes[name].localised_name 
 
  --global["config-tmp"][player.name][index][type] = name
  --storage[index][type] = name
  --ruleset_grid["upgrade_planner_" .. type .. "_" .. index].tooltip = game.item_prototypes[name].localised_name
  gui_save_changes(player)
end
end

function gui_clear_rule(player, index)
  local frame = player.gui.center.upgrade_planner_config_frame
  if not frame or not global["config-tmp"][player.name] then return end
  local ruleset_grid = frame["upgrade_planner_ruleset_grid"]
  global["config-tmp"][player.name][index] = { from = "", to = "" }
  ruleset_grid["upgrade_planner_from_" .. index].elem_value = nil
  ruleset_grid["upgrade_planner_from_" .. index].tooltip = ""
  ruleset_grid["upgrade_planner_to_" .. index].elem_value = nil
  ruleset_grid["upgrade_planner_to_" .. index].tooltip = ""
  gui_save_changes(player)
end

function gui_restore(player, name)

    local frame = player.gui.center.upgrade_planner_config_frame
  if not frame then return end
  if not global.storage[player.name] then return end
  local storage = global.storage[player.name][name]
  if not storage and name == "New storage" then
    storage = {}
  end
  if not storage then return end

    global["config-tmp"][player.name] = {}

    local i = 0
    local ruleset_grid = frame["upgrade_planner_ruleset_grid"]
    local items = game.item_prototypes
    for i = 1, MAX_CONFIG_SIZE do
    if i > #storage then
            global["config-tmp"][player.name][i] = { from = "", to = "" }
        else
            local storage = global["storage"][player.name][name][i];
            --game.write_file( 'planner.log', '(set config_tmp from storage)Module is:'..tostring( storage.is_module)..'\n',true,1);
            global["config-tmp"][player.name][i] = {
                from = storage.from,
                to = storage.to,
                is_module = storage.is_module,
                is_rail = storage.is_rail,
                from_curved_rail = storage.from_curved_rail,
                from_straight_rail = storage.from_straight_rail,
                to_curved_rail = storage.to_curved_rail,
                to_straight_rail = storage.to_straight_rail
            }
        end
        --local sprite = ""
        local name = get_config_item(player, i, "from")
        local tooltip = '';
        if( name ) then tooltip = items[name].localised_name end
        --if name then sprite = "item/"..items[name].name end
        ruleset_grid["upgrade_planner_from_" .. i].elem_value = name
        ruleset_grid["upgrade_planner_from_" .. i].tooltip = tooltip
        --local sprite = ""
        local name = get_config_item(player, i, "to")
        local tooltip = '';
        if( name ) then tooltip = items[name].localised_name end
        --if name then sprite = "item/"..items[name].name end
        ruleset_grid["upgrade_planner_to_" .. i].elem_value = name
        ruleset_grid["upgrade_planner_to_" .. i].tooltip = tooltip
    end
	--global.config[player.name] = global["config-tmp"][player.name]
    --gui_display_message(storage_frame, true, "")

end

event.add(defines.events.on_gui_click, function(event)

  local element = event.element
  --print_full_gui_name(element)
  local name = element.name
  local player = game.players[event.player_index]
  --game.print(element.type)
  --game.print(element.name)
  if name == "upgrade_blueprint" then
    upgrade_blueprint(player)
    return
  end
  if name == "give_upgrade_tool" then
    player.clean_cursor()
    player.cursor_stack.set_stack({name = "dummy-selection-tool"})
    return
  end

  if name == "upgrade_planner_storage_rename" then
    local children = element.parent.children
    for k, child in pairs (children) do
      child.style.visible = true
    end
    children[4].text = children[1].get_item(children[1].selected_index)
    if children[4].text == "New storage" then
      children[4].text = ""
    end
    return
  end

  if name == "upgrade_planner_storage_cancel" then
    local children = element.parent.children
    for k = 4, 6 do
      children[k].style.visible = false
    end
    children[4].text = children[1].get_item(children[1].selected_index)
    return
  end

  if name == "upgrade_planner_storage_confirm" then
    local index = global.storage_index[player.name]
    local children = element.parent.children
    local new_name = children[4].text
    local length = string.len(new_name)
    if length < 1 then
      player.print({"upgrade-planner.storage-name-too-short"})
      return
    end
    for k = 4, 6 do
      children[k].style.visible = false
    end
    local items = children[1].items
    if index > #items then
      index = #items
    end
    local old_name = items[index]
    if old_name == "New storage" then
      children[1].add_item("New storage")
    end
    if not global.storage then
      global.storage = {}
    end
    if not global.storage[player.name] then
      global.storage[player.name] = {}
    end
    if global.storage[player.name][old_name] then
      global.storage[player.name][new_name] = global.storage[player.name][old_name]
    else
      global.storage[player.name][new_name] = {}
    end
    global.storage[player.name][old_name] = nil
    --game.print(serpent.block(global.storage[player.name][new_name]))
    children[1].set_item(index, new_name)
    children[1].selected_index = 0
    children[1].selected_index = index
    global.storage_index[player.name] = index
    return
  end

  if name == "upgrade_planner_storage_delete" then
    local children = element.parent.children
    local dropdown = children[1]
    local index = dropdown.selected_index
    local name = dropdown.get_item(index)
    global.storage[player.name][name] = nil
    if name ~= "New storage" then
      dropdown.remove_item(index)
    end
    if index > 1 then
      index = index - 1
    end
    dropdown.selected_index = 0
    dropdown.selected_index = index
    gui_restore(player, dropdown.get_item(index))
    global.storage_index[player.name] = index
    return
  end
  if name == "upgrade_planner_config_button" then
    gui_open_frame(player)
    return
  end
  if name == "upgrade_planner_export_config" then
    export_config(player)
    return
  end
  if name == "upgrade_planner_import_config" then
    import_config(player)
    return
  end
  if name == "upgrade_planner_frame_close" then
    player.opened.destroy()
    gui_open_frame(player)
    return
  end
  if name == "upgrade_planner_import_config_button" then
    import_config_action(player)
    return
  end
  local type, index = string.match(name, "(%a+)%_(%d+)")
  if type and index then
    if type == "clear" then
      gui_clear_rule(player, tonumber(index))
      return
    end
  end

end)

event.add(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element
  local player = game.players[event.player_index]
  if not string.find(element.name, "upgrade_planner_") then return end
  if element.selected_index > 0 then
    global.storage_index[player.name] = element.selected_index
    local name = element.get_item(element.selected_index)
    gui_restore(player, name)
    global.config[player.name] = global.storage[player.name][name]
  end
end)

event.add(defines.events.on_gui_elem_changed, function(event)

  local element = event.element
  local player = game.players[event.player_index]
  local type, index = string.match(element.name, "(%a+)%_(%d+)")
  if type and index then
    if type == "from" or type == "to" then
      gui_set_rule(player, type, tonumber(index), element)
    end
  end

end)

local function on_start()
  global_init()
  --for k, player in pairs (game.players) do
    --gui_init(player)
  --end
end
event.on_init(on_start)

event.add(defines.events.on_player_selected_area, function(event)
  if BP_HAND then
  on_selected_area(event)
  end
  if BP_BOT then
  on_alt_selected_area(event)
  end
end)

function on_selected_area(event)
  log( "selcted_area..."..event.item );
  if event.item ~= "dummy-selection-tool" then return end--If its a upgrade builder 
  
  local player = game.players[event.player_index]
  local config = global["config"][player.name]
  log( "config?"..tostring(config))
  if config == nil then return end
  
  local surface = player.surface
  global.temporary_ignore = {}
  if event.tiles then
    local new_tiles = {};
    for _, tile in pairs( event.tiles ) do 
      local proto = game.tile_prototypes[tile.name];
      local placed_by_list = proto.items_to_place_this;
      for __, entry in pairs( config ) do
        if entry and entry.from then
          if not global.temporary_ignore[entry.from] then 
            for ___,placed_by in pairs(placed_by_list) do
               if placed_by.name == entry.from then
                  log( "Found replacable...".. entry.from );
                  if player.get_item_count(entry.from) > 0 or player.cheat_mode then 
                  -- can't mine tiles?
                  --   script.raise_event(defines.events.on_preplayer_mined_item,{player_index = player.index, tile = tile})
                    new_tiles[#new_tiles+1] = { name = game.item_prototypes[entry.to].place_as_tile_result.result.name
                                              , position = tile.position };
                    player.remove_item{name = entry.to, count = 1}
                    player.insert{name = entry.from, count = 1}
                    --script.raise_event(defines.events.on_player_mined_item,{player_index = player.index, item_stack = {name = orig_inv_name, count = item_count}})
                  else
                    global.temporary_ignore[entry.from] = true
                    surface.create_entity{name = "flying-text", position = {tile.position.x-1.3,tile.position.y-0.5}, text = "You don't have enough items to do this!", color = {r=1,g=0.6,b=0.6}}
                  end
      
               end
            end
          end
        end
      end    
    end
    if #new_tiles > 0 then
      surface.set_tiles( new_tiles );
      local positions = {};
      for _, tile in pairs(new_tiles) do
        positions[#positions+1] = tile.position;
      end
      --log_keys( positions )
      script.raise_event(defines.events.on_player_mined_tile,{player_index = player.index, surface_index=surface.index, positions=positions})
      script.raise_event(defines.events.on_player_built_tile,{player_index = player.index, surface_index=surface.index, positions=positions})
    end
  end

  for k, belt in pairs (event.entities) do --Get the items that are set to be upgraded
    if belt.valid then
      local upgrade = nil;
      local upgrade_to = nil;
      local is_curved_rail = false;
      for i = 1, #config do
        -- insufficient items already, check ignore
        if global.temporary_ignore[config[i].from] then break end

        if config[i].is_rail then
          if config[i].from_curved_rail == belt.name then
              upgrade = config[i];
              upgrade_to = config[i].to_curved_rail;
              is_curved_rail = true;
              break
          elseif config[i].from_straight_rail == belt.name then
              upgrade = config[i];
              upgrade_to = config[i].to_straight_rail;
              break
          end
        elseif config[i].is_module then
          if player.get_item_count(config[i].to) > 0 or player.cheat_mode then 
            player_module_upgrade(player,belt,config[i].from,config[i].to);
          else
            global.temporary_ignore[config[i].from] = true
            surface.create_entity{name = "flying-text", position = {belt.position.x-1.3,belt.position.y-0.5}, text = "You don't have enough items to do this!", color = {r=1,g=0.6,b=0.6}}
          end
        else
          --log( "is "..config[i].from..'='..belt.name )
          if config[i].from == belt.name then
              upgrade = config[i];
              upgrade_to = config[i].to;
              break;
          end
        end
      end
      if upgrade_to ~= nil then
        player_upgrade(player,upgrade.from,belt,upgrade.to,upgrade_to,true,is_curved_rail)
      end
    end
  end
  global.temporary_ignore = nil
end

function get_hashmap(config)
  local items = game.item_prototypes
  local hashmap = {}
  for k, entry in pairs (config) do
    local item_from = items[entry.from]
    local item_to = items[entry.to]
    if item_to and item_from then
      hashmap[entry.from] = {item_to = entry.to}
      local entity_from = item_from.place_result
      local entity_to = item_to.place_result
      if entity_from and entity_to then
        hashmap[entity_from.name] = {entity_to = entity_to.name, item_to = entry.to, item_from = entry.from}
      end
      if item_from.type == "rail-planner" and item_to.type == "rail-planner" then
        hashmap[item_from.straight_rail.name] = {entity_to = item_to.straight_rail.name, item_to = entry.to, item_from = entry.from}
        hashmap[item_from.curved_rail.name] = {entity_to = item_to.curved_rail.name, item_to = entry.to, item_from = entry.from, item_amount = 4}
      end
    end
  end
  return hashmap
end

function player_module_upgrade(player,belt,from,to)
  local m_inv = belt.get_module_inventory();
  if m_inv then
     local m_content = m_inv.get_contents();
     for item, count in pairs (m_content) do
       if player.get_item_count(to) >= count or player.cheat_mode then 
         if( item == from ) then
           m_inv.remove( {name=from, count=count} );
           m_inv.insert( {name=to, count=count} );
           player.insert( {name=from, count=count} );
           player.remove_item( {name=to, count=count} );
         end
       else
          surface.create_entity{name = "flying-text", position = {belt.position.x-1.3,belt.position.y-0.5}, text = "You don't have enough items to do this!", color = {r=1,g=0.6,b=0.6}}
          global.temporary_ignore[from] = true
       end
     end
  else
     -- belt entity doesn't support modules  
  end
end

local zero_delta = { x = 0,   y = 0, origx = 0, origy = 0, posx = 0, posy =  0 }
local curved_track_deltas = { { x = -3,   y = -3, origx = 1, origy =-1, posx = -2, posy =  0 },
                              { x = 1,    y = -3, origx =-1, origy =-1, posx =  0, posy =  0 },
                              { x = 0.5,  y = -3, origx = 1, origy = 1, posx = -2, posy = -2 },
                              { x = 1,    y = 1,  origx = 1, origy =-1, posx = -2, posy =  0 },
                              { x = 1,    y = 1,  origx =-1, origy = 1, posx =  0, posy = -2 },
                              { x = -3,   y = 1,  origx = 1, origy = 1, posx = -2, posy = -2 },
                              { x = -2.5, y = 1,  origx =-1, origy =-1, posx =  0, posy =  0 },
                              { x = -2.5, y = -3, origx =-1, origy = 1, posx =  0, posy = -2 } };

function player_upgrade(player,orig_inv_name,belt,inv_name,upgrade,bool,is_curved_rail)
  local item_count = 1;
  if not belt then return end
  if global.temporary_ignore[belt.name] then return end
  local surface = player.surface
  if is_curved_rail then item_count=4 end
  if player.get_item_count(inv_name) >= item_count or player.cheat_mode then 
    local d = belt.direction
    local f = belt.force
    local p = belt.position
    local inserter_pickup = nil
    local inserter_drop = nil
    local pdel = zero_delta

    if is_curved_rail then
      item_count = 4;
      pdel = curved_track_deltas[d+1]
      p = { x=p.x + pdel.posx, y = p.y + pdel.posy };
    end

    if player.can_reach_entity(belt) or in_range_check_is_annoying then
      local new_item              
      script.raise_event(defines.events.on_pre_player_mined_item,{player_index = player.index, entity = belt})
      if upgrade ~="deconstruction-planner" then --Goddamn legacy features
        if belt.type == "underground-belt" then 
          if belt.neighbours and bool then
            player_upgrade(player,orig_inv_name,belt.neighbours,inv_name,upgrade,false,is_curved_rail)
          end
          new_item = surface.create_entity
          {
            name = upgrade, 
            position = p, 
            force = belt.force, 
            fast_replace = true, 
            direction = belt.direction, 
            type = belt.belt_to_ground_type, 
            spill=false
          }
          
        elseif belt.type == "loader" then 
          new_item = surface.create_entity
          {
            name = upgrade, 
            position = p, 
            force = belt.force, 
            fast_replace = true, 
            direction = belt.direction, 
            type = belt.loader_type, 
            spill=false
          }
        else
          if( belt.type == "inserter" ) then
            inserter_pickup = belt.pickup_position;
            inserter_drop = belt.drop_position;
          end
          new_item = surface.create_entity
          {
            name = upgrade, 
            position = p, 
            force = belt.force, 
            fast_replace = true, 
            direction = belt.direction, 
            spill=false
          }
        end
        if belt.valid then
          if new_item then 
            if new_item.valid then new_item.destroy() end
          end
          local a = belt.bounding_box;
          --local a = {left_top={x=(p.x-0.5)-pdel.x,y=(p.y-0.5)-pdel.y},right_bottom={x=(p.x+0.5)-pdel.x,y=(p.y+0.5)-pdel.y}}
          --If the create entity fast replace didn't work, we use this blueprint technique
          player.cursor_stack.set_stack{name = "blueprint", count = 1}
          player.cursor_stack.create_blueprint{surface = surface, force = belt.force,area = a}
          local old_blueprint = player.cursor_stack.get_blueprint_entities()
          local record_index = nil
          for index, entity in pairs (old_blueprint) do
            if( entity.direction == nil ) then entity.direction = 0; end
            if (entity.name == belt.name and entity.direction==belt.direction) then
              record_index = index
              entity.position.x = pdel.origx;
              entity.position.y = pdel.origy;
            else
              old_blueprint[index] = nil
            end
          end
          if record_index == nil then player.print("Blueprint index error line "..debug.getinfo(1).currentline) return end
          old_blueprint[record_index].name = upgrade
          player.cursor_stack.set_stack{name = "blueprint", count = 1}
          player.cursor_stack.set_blueprint_entities(old_blueprint)
          if not player.cheat_mode then
            player.insert{name = orig_inv_name, count = item_count}
          end
          script.raise_event
          (
            defines.events.on_player_mined_item,
            {
              player_index = player.index,
              item_stack = 
              {
                name = orig_inv_name,
                count = item_count
              }
            }
          )
          --And then copy the inventory to some table
          local inventories = {}
          for index = 1,10 do
            if belt.get_inventory(index) ~= nil then
              inventories[index] = {}
              inventories[index].name = index
              inventories[index].contents = belt.get_inventory(index).get_contents()
            end
          end

          belt.destroy()

          player.cursor_stack.build_blueprint{surface = surface, force_build=true, force = f, position = p}
          local ghost = surface.find_entities_filtered{area = a, name = "entity-ghost"}

          player.remove_item{name = inv_name, count = item_count}
          if ghost[1]~= nil then
            local p_x = player.position.x
            local p_y = player.position.y

            while ghost[1]~= nil do
              ghost[1].revive()
              player.teleport({math.random(p_x -5, p_x +5),math.random(p_y -5, p_y +5)})
              ghost = surface.find_entities_filtered{area = a, name = "entity-ghost"}
            end
            player.teleport({p_x,p_y})
          end
          local assembling = surface.find_entities_filtered{area = a, name = upgrade}
          if not assembling[1] then 
            player.print("This won't work!")
            player.cursor_stack.set_stack{name = "dummy-selection-tool", count = 1}
            player.insert{name = orig_inv_name, count = item_count}
            return 
          end
   log( "raise event?" );
          script.raise_event(defines.events.on_built_entity,{player_index = player.index, created_entity = assembling[1]})
    log( "raised event?" );
          --Give back the inventory to the new entity
          for j, items in pairs (inventories) do
            for l, contents in pairs (items.contents) do
              if assembling[1] ~= nil then
              assembling[1].get_inventory(items.name).insert{name = l, count = contents}
              end
            end
          end
          inventories = nil
          local proxy = surface.find_entities_filtered{area = a, name = "item-request-proxy"}
          if proxy[1]~= nil then
            proxy[1].destroy()
          end
          player.cursor_stack.set_stack{name = "dummy-selection-tool", count = 1}      
        else 
          if( new_item.type == "inserter" ) then
             new_item.pickup_position = inserter_pickup;
             new_item.drop_position = inserter_drop;
          end
          player.remove_item{name = inv_name, count = item_count}
          player.insert{name = orig_inv_name, count = item_count}
          script.raise_event(defines.events.on_player_mined_item,{player_index = player.index, item_stack = {name = orig_inv_name, count = item_count}})
          script.raise_event(defines.events.on_built_entity,{player_index = player.index, created_entity = new_item})
        end
      else
        player.insert{name = orig_inv_name, count = item_count}
        script.raise_event(defines.events.on_player_mined_item,{player_index = player.index, item_stack = {name = orig_inv_name, count = item_count}})
        belt.destroy()
      end
    else 
      surface.create_entity{name = "flying-text", position = {belt.position.x-1.3,belt.position.y-0.5}, text = "Out of range",color = {r=1,g=0.6,b=0.6}}
    end
  else
    global.temporary_ignore[orig_inv_name] = true
    surface.create_entity{name = "flying-text", position = {belt.position.x-1.3,belt.position.y-0.5}, text = "You don't have enough items to do this!", color = {r=1,g=0.6,b=0.6}}
  end
end

function on_alt_selected_area(event)
  --this is a lot simpler... but less cool
  if event.item ~= "dummy-selection-tool" then return end
  local player = game.players[event.player_index]
  local config = global.config[player.name]
  if not config then return end
  local hashmap = get_hashmap(config)
  local surface = player.surface
  for k, belt in pairs (event.entities) do
    if belt.valid then
      local upgrade = hashmap[belt.name]
      if upgrade and upgrade ~= "" then
        bot_upgrade(player,belt,upgrade,true, hashmap)
      end
      if belt.valid and belt.get_module_inventory() then
        robot_upgrade_modules(belt.get_module_inventory(), hashmap, belt)
      end
    end
  end
end

function robot_upgrade_modules(inventory, map, owner)
  if not owner then return end
  if not owner.valid then return end
  local surface = owner.surface
  local modules = {}
  local proxy = false
  for k = 1, #inventory do
    local slot = inventory[k]
    if slot.valid and slot.valid_for_read then
      local upgrade = map[slot.name]
      local recipe = get_recipe(owner)
      if upgrade and upgrade.item_to and recipe and check_module_eligibility(upgrade.item_to, recipe) then
        local entity = surface.create_entity{name = "item-on-ground", stack = {name = slot.name, count = slot.count}, position = owner.position, force = owner.force}
        entity.order_deconstruction(owner.force)
        if modules[upgrade.item_to] then
          modules[upgrade.item_to] = modules[upgrade.item_to] + slot.count
        else
          modules[upgrade.item_to] = slot.count
        end
        proxy = true
        slot.clear()
      end
    end
  end
  if proxy then
    surface.create_entity{name = "item-request-proxy", force = owner.force, position = owner.position, modules = modules, target = owner}
  end
end

function get_recipe(owner)
  local recipe
  if not owner.valid then return end
  if owner.type == "beacon" then
    recipe = game.recipe_prototypes["stone-furnace"] --Some dummy recipe to get correct limitation
  elseif owner.type == "assembling-machine" or owner.type == "furnace" then
    recipe = owner.get_recipe() or "iron-gear-wheel"
  end
  return recipe
end

function bot_upgrade(player, belt, upgrade, bool, hashmap)
  if not (belt and belt.valid) then return end
  if not upgrade.entity_to then
    log("Tried to upgrade when entry had no entity: "..serpent.line(upgrade))
    return
  end
  local surface = player.surface
  local p = belt.position
  local d = belt.direction
  local f = belt.force
  local p = belt.position
  local a = {{p.x-0.5,p.y-0.5},{p.x+0.5,p.y+0.5}}

  if belt.to_be_deconstructed(f) then
    return
  end

  if belt.type == "underground-belt" then
    if belt.neighbours and bool then
      bot_upgrade(player,belt.neighbours, upgrade, false)
    end
  end
  if belt.type == "straight-rail" or belt.type == "curved-rail" then
    belt.order_deconstruction(f)
    local new_ghost = surface.create_entity{
      name = "entity-ghost",
      inner_name = upgrade.entity_to,
      position = p,
      force = f,
      direction = d,
      expires = false
    }
    return
  end
  player.cursor_stack.set_stack{name = "blueprint", count = 1}
  player.cursor_stack.create_blueprint{surface = surface, force = belt.force,area = a}
  local old_blueprint = player.cursor_stack.get_blueprint_entities()
  local blueprint_index = nil
  for k, entity in pairs (old_blueprint) do
    if entity.name == belt.name then
      blueprint_index = k
      break
    end
  end
  if not blueprint_index then
    player.print("Upgrade planner bot upgrade blueprint index error - Upgrade unsuccessful: "..belt.name.." -> "..serpent.block(upgrade))
    player.cursor_stack.set_stack{name = "dummy-selection-tool", count = 1}
    return
  end
  --game.print(serpent.block(old_blueprint))
  local blueprint_entity = old_blueprint[blueprint_index]
  blueprint_entity.name = upgrade.entity_to
  local new_items = {}
  if blueprint_entity.items then
    for item, count in pairs (blueprint_entity.items) do
      local new = hashmap[item]
      if new then
        if new_items[new] then
          new_items[new] = new_items[new] + count
        else
          new_items[new] = count
        end
      end
    end
  end
  blueprint_entity.items = new_items
  player.cursor_stack.set_stack{name = "blueprint", count = 1}
  player.cursor_stack.set_blueprint_entities({blueprint_entity})
  belt.order_deconstruction(f)
  player.cursor_stack.build_blueprint{surface = surface, force = f, position = p}
  player.cursor_stack.set_stack{name = "dummy-selection-tool", count = 1}
end

script.on_configuration_changed(function(data)
  if not data or not data.mod_changes then
    return
  end
  verify_all_configs()
  nuke_all_guis()
  if data.mod_changes["upgrade-planner"] then
    if not global.storage_index then
      global.storage_index = {}
    end
    if not global.storage then
      global.storage = {}
    end
    for k, player in pairs (game.players) do
      if not global.storage_index[player.name] then
        global.storage[player.name] = global.storage[player.name] or {}
        global.storage[player.name]["New storage"] = global.config[player.name]
        gui_open_frame(player)
        gui_open_frame(player)
      end
    end
  end
end)

function verify_all_configs()
  local items = game.item_prototypes
  local verify_config = function (config)
    for k, entry in pairs (config) do
      local to = items[entry.to]
      local from = items[entry.from]
      if not (to and from) then
        log("Deleted invalid config: "..k..serpent.line(entry))
        entry[k] = nil
      end
    end
  end
  for name, config in pairs (global.config) do
    verify_config(config)
  end
  for name, config in pairs (global["config-tmp"]) do
    verify_config(config)
  end
  for name, storage in pairs (global.storage) do
    for storage_name, config in pairs (storage) do
      verify_config(config)
    end
  end
end

--event.add(defines.events.on_player_joined_game, function(event)
--  local player = game.players[event.player_index]
--  gui_init(player)
--end)


function update_blueprint_entities(stack, hashmap)
  if not (stack and stack.valid and stack.valid_for_read and stack.is_blueprint_setup()) then return end
  local entities = stack.get_blueprint_entities()
  if entities then
    for k, entity in pairs (entities) do
      local new = hashmap[entity.name]
      if new and new.entity_to then
        entities[k].name = new.entity_to
      end
      if entity.items then
        local new_items = {}
        for item, count in pairs (entity.items) do
          new_items[item] = count
        end
        for item, count in pairs (entity.items) do
          local new = hashmap[item]
          if new and new.item_to then
            if new_items[new.item_to] then
              new_items[new.item_to] = new_items[new.item_to] + count
            else
              new_items[new.item_to] = count
            end
            new_items[item] = new_items[item] - count
          end
        end
        for item, count in pairs (new_items) do
          if count == 0 then
            new_items[item] = nil
          end
        end
        entities[k].items = new_items
      end
    end
    stack.set_blueprint_entities(entities)
  end
  local tiles = stack.get_blueprint_tiles()
  if tiles then
    local tile_prototypes = game.tile_prototypes
    local items = game.item_prototypes
    for k, tile in pairs (tiles) do
      local prototype = tile_prototypes[tile.name]
      local items_to_place = prototype.items_to_place_this
      local item = nil
      if items_to_place then
        for name, to_place in pairs (items_to_place) do
          item = hashmap[name]
          if item and item.item_to then
            break
          end
        end
      end
      if item then
        local tile_item = items[item.item_to]
        if tile_item then
          local result = tile_item.place_as_tile_result
          if result then
            new_tile = tile_prototypes[result.result.name]
            if new_tile and new_tile.can_be_part_of_blueprint then
              tiles[k].name = result.result.name
            end
          end
        end
      end
    end
    stack.set_blueprint_tiles(tiles)
  end
  local icons = stack.blueprint_icons
  for k, icon in pairs (icons) do
    local new = hashmap[icon.signal.name]
    if new and new.item_to then icons[k].signal.name = new.item_to end
  end
  stack.blueprint_icons = icons
  return true
end

function upgrade_blueprint(player)
  local stack = player.cursor_stack
  if not (stack.valid and stack.valid_for_read) then return end

  local config = global.config[player.name]
  if not config then return end
  local hashmap = get_hashmap(config)

  if stack.is_blueprint then
    if update_blueprint_entities(stack, hashmap) then
      player.print({"upgrade-planner.blueprint-upgrade-successful"})
    end
    return
  end

  if stack.is_blueprint_book then
    local inventory = stack.get_inventory(defines.inventory.item_main)
    local success = 0
    for k = 1, #inventory do
      if update_blueprint_entities(inventory[k], hashmap) then
        success = success + 1
      end
    end
    player.print({"upgrade-planner.blueprint-book-upgrade-successful", success})
    return
  end
end

function is_exception(from, to)
  local exceptions =
  {
    {from = "container", to = "logistic-container"},
    {from = "logistic-container", to = "container"}
  }
  for k, exception in pairs (exceptions) do
    if from == exception.from and to == exception.to then
      return true
    end
  end
  return false
end

function print_full_gui_name(gui)
  local string = gui.name or "No_name"
  while gui.parent do
    local name = gui.parent.name or "No_name"
    string = name.."."..string
    gui = gui.parent
  end
  game.print(string)
end

function find_gui_recursive(gui, name)
  for k, child in pairs (gui.children) do
    if child.name == name then return child end
    find_gui_recursive(child, name)
  end
end

function nuke_all_guis()
  for k, player in pairs (game.players) do
    for j, name in pairs ({"upgrade-planner.storage-frame", "upgrade-planner-config-button"}) do
      local found = find_gui_recursive(player.gui, name)
      if found then found.destroy() end
    end
  end
end

function export_config(player)
  player.opened = nil
  local gui = player.gui.center
  local frame = gui.add{type = "frame", caption = {"upgrade-planner.export-config"}, name = "upgrade_planner_export_frame", direction = "vertical"}
  local textfield = frame.add{type = "text-box"}
  textfield.word_wrap = true
  textfield.read_only = true
  textfield.style.minimal_width = 500
  textfield.style.minimal_height = 200
  textfield.style.maximal_height = 500
  textfield.text = enc(serpent.dump(global.storage[player.name]))
  frame.add{type = "button", caption = {"gui.close"}, name = "upgrade_planner_frame_close", style = mod_gui.button_style}
  frame.style.visible = true
  player.opened = frame
end

function import_config(player)
  player.opened = nil
  local gui = player.gui.center
  local frame = gui.add{type = "frame", caption = {"upgrade-planner.import-config"}, name = "upgrade_planner_export_frame", direction = "vertical"}
  local textfield = frame.add{type = "text-box"}
  textfield.word_wrap = true
  textfield.read_only = false
  textfield.style.minimal_width = 500
  textfield.style.minimal_height = 200
  textfield.style.maximal_height = 500
  local flow = frame.add{type = "flow"}
  flow.add{type = "button", caption = {"upgrade-planner.import-button"}, name = "upgrade_planner_import_config_button", style = mod_gui.button_style}
  flow.add{type = "button", caption = {"gui.close"}, name = "upgrade_planner_frame_close", style = mod_gui.button_style}
  frame.style.visible = true
  player.opened = frame
end

function import_config_action(player)
  if not player.opened then return end
  local frame = player.opened
  if not (frame.name and frame.name == "upgrade_planner_export_frame") then return end
  local textbox = frame.children[1]
  if not textbox.type == "text-box" then return end
  local text = textbox.text
  local result = loadstring(dec(text))
  if result then
    new_config = result()
  else
    player.print({"upgrade-planner.import-failed"})
    return
  end
  if new_config then
    for name, config in pairs (new_config) do
      if name == "New storage" then
        global.storage[player.name]["Imported storage"] = config
      else
        global.storage[player.name][name] = config
      end
    end
    player.print({"upgrade-planner.import-sucessful"})
    player.opened.destroy()
    local count = 0
    for k, storage in pairs (global.storage[player.name]) do
      count = count + 1
    end
    global.storage_index[player.name] = count
    gui_open_frame(player)
  else
    player.print({"upgrade-planner.import-failed"})
  end
end

-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function enc(data)
  return ((data:gsub('.', function(x)
    local r,b='',x:byte()
    for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
    return r;
  end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if (#x < 6) then return '' end
    local c=0
    for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
    return b:sub(c+1,c+1)
  end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function dec(data)
  data = string.gsub(data, '[^'..b..'=]', '')
  return (data:gsub('.', function(x)
    if (x == '=') then return '' end
    local r,f='',(b:find(x)-1)
    for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
    return r;
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    if (#x ~= 8) then return '' end
    local c=0
    for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
    return string.char(c)
  end))
end