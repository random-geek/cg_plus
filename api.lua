-- TODO: aliases?

local get_drops = function(item, def)
    local normalDrops = {}
    local randomDrops = {}

    if type(def.drop) == "table" then
        -- Handle complex drops. This is the method used by Unified Inventory.
        local maxStart = true
        local itemsLeft = def.drop.max_items
        local dropTables = def.drop.items or {}

        local dStack, dName, dCount

        for _, dropTable in ipairs(dropTables) do
            if itemsLeft and itemsLeft <= 0 then break end

            for _, dropItem in ipairs(dropTable.items) do
                dStack = ItemStack(dropItem)
                dName = dStack:get_name()
                dCount = dStack:get_count()

                if dCount > 0 and dName ~= item then
                    if #dropTable.items == 1 and dropTable.rarity == 1 and maxStart then
                        normalDrops[dName] = (normalDrops[dName] or 0) + dCount

                        if itemsLeft then
                            itemsLeft = itemsLeft - 1
                            if itemsLeft <= 0 then break end
                        end
                    else
                        if itemsLeft then maxStart = false end

                        randomDrops[dName] = (randomDrops[dName] or 0) + dCount
                    end
                end
            end
        end
    else
        -- Handle simple, one-item drops.
        local dStack = ItemStack(def.drop)

        if not dStack:is_empty() and dStack:get_name() ~= item then
            normalDrops[dStack:get_name()] = dStack:get_count()
        end
    end

    return normalDrops, randomDrops
end

cg.build_item_list = function()
    local startTime = minetest.get_us_time()
    cg.items_all.list = {}

    for item, def in pairs(minetest.registered_items) do
        if def.description and def.description ~= "" and
                minetest.get_item_group(item, "not_in_creative_inventory") == 0 and
                minetest.get_item_group(item, "not_in_craft_guide") == 0 then
            table.insert(cg.items_all.list, item)
            cg.crafts[item] = minetest.get_all_craft_recipes(item) or {}
        end
    end

    local def, fuel, decremented

    for _, item in ipairs(cg.items_all.list) do
        def = minetest.registered_items[item]

        fuel, decremented = minetest.get_craft_result({method = "fuel", width = 0, items = {ItemStack(item)}})

        if fuel.time > 0 then
            table.insert(cg.crafts[item], {
                type = "fuel",
                items = {item},
                output = decremented.items[1]:to_string(),
                time = fuel.time,
            })
        end

        if def.drop then
            local normalDrops, randomDrops = get_drops(item, def)

            for dItem, dCount in pairs(normalDrops) do
                if cg.crafts[dItem] then
                    table.insert(cg.crafts[dItem], {
                            type = "digging",
                            width = 0,
                            items = {item},
                            output = ItemStack({name = dItem, count = dCount}):to_string()
                        })
                end
            end

            for dItem, dCount in pairs(randomDrops) do
                if cg.crafts[dItem] then
                    table.insert(cg.crafts[dItem], {
                            type = "digging_chance",
                            width = 0,
                            items = {item},
                            output = ItemStack({name = dItem, count = dCount}):to_string()
                        })
                end
            end
        end

        for group, _ in pairs(def.groups) do
            if not cg.group_stereotypes[group] then
                cg.group_stereotypes[group] = item
            end
        end
    end

    table.sort(cg.items_all.list)
    cg.items_all.num_pages = math.ceil(#cg.items_all.list / cg.PAGE_ITEMS)

    minetest.log("info", string.format("[cg_plus] Finished building item list in %.3f s.",
            (minetest.get_us_time() - startTime) / 1000000))
end

cg.filter_items = function(player, filter)
    local playerName = player:get_player_name()

    if not filter or filter == "" then
        cg.items_filtered[playerName] = nil
        return
    end

    cg.items_filtered[playerName] = {list = {}}

    local groupFilter = string.sub(filter, 1, 6) == "group:" and filter:sub(7)

    if groupFilter and cg.group_search then
        -- Search by group
        local groups = string.split(groupFilter, ",")
        local isInGroups

        for _, item in ipairs(cg.items_all.list) do
            isInGroups = true

            for idx = 1, math.min(#groups, cg.group_search_max) do
                if minetest.get_item_group(item, groups[idx]) == 0 then
                    isInGroups = false
                    break
                end
            end

            if isInGroups then
                table.insert(cg.items_filtered[playerName].list, item)
            end
        end
    else
        -- Regular search
        for _, item in ipairs(cg.items_all.list) do
            if item:lower():find(filter, 1, true) or
                minetest.registered_items[item].description:lower():find(filter, 1, true) then
                table.insert(cg.items_filtered[playerName].list, item)
            end
        end
    end

    cg.items_filtered[playerName].num_pages = math.ceil(#cg.get_item_list(player).list / cg.PAGE_ITEMS)
end

cg.parse_craft = function(craft)
    local type = craft.type
    local template = cg.craft_types[type] or {}

    if craft.width == 0 and template.alt_zero_width then
        type = template.alt_zero_width
        template = cg.craft_types[template.alt_zero_width] or {}
    end

    local newCraft = {
        type = type,
        items = {},
        output = craft.output,
    }

    if template.get_infotext then
        newCraft.infotext = template.get_infotext(craft) or ""
    end

    local width = math.max(craft.width or 0, 1)

    if template.get_grid_size then
        newCraft.grid_size = template.get_grid_size(craft)
    else
        newCraft.grid_size = {x = width, y = math.ceil(table.maxn(craft.items) / width)}
    end

    if template.inherit_width then
        -- For shapeless recipes, there is no need to modify the item list.
        newCraft.items = craft.items
    else
        -- The craft's width is not always the same as the grid size, so items need to be shifted around.
        for idx, item in pairs(craft.items) do
            newCraft.items[idx + (newCraft.grid_size.x - width) * math.floor((idx - 1) / width)] = item
        end
    end

    return newCraft
end

cg.get_item_list = function(player)
    return cg.items_filtered[player:get_player_name()] or cg.items_all
end

cg.register_craft_type = function(name, def)
    cg.craft_types[name] = def
end

cg.register_group_stereotype = function(group, item)
    cg.group_stereotypes[group] = item
end

minetest.register_on_mods_loaded(cg.build_item_list)

minetest.register_on_leaveplayer(function(player, timed_out)
  cg.items_filtered[player:get_player_name()] = nil
end)
