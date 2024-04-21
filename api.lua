-- TODO: aliases?

local custom_crafts = {}

local function get_drops(item, def)
    local normalDrops = {}
    local randomDrops = {}

    if type(def.drop) == "table" then
        -- Handle complex drops. This is the method used by Unified Inventory.
        local maxStart = true
        local itemsLeft = def.drop.max_items
        local dropTables = def.drop.items or {}

        local dStack, dName, dCount

        for _, dropTable in ipairs(dropTables) do
            if itemsLeft and itemsLeft <= 0 then
                break
            end

            for _, dropItem in ipairs(dropTable.items) do
                dStack = ItemStack(dropItem)
                dName = dStack:get_name()
                dCount = dStack:get_count()

                if dCount > 0 and dName ~= item then
                    if #dropTable.items == 1 and dropTable.rarity == 1
                            and maxStart then
                        normalDrops[dName] = (normalDrops[dName] or 0) + dCount

                        if itemsLeft then
                            itemsLeft = itemsLeft - 1
                            if itemsLeft <= 0 then
                                break
                            end
                        end
                    else
                        if itemsLeft then
                            maxStart = false
                        end

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

local function build_group_stereotypes_list()
    -- Remember: Some group stereotypes are already registered
    local startTime = minetest.get_us_time()
    local usedMultiGroups = {}

    for _, recipes in pairs(cg.crafts) do
    for _, recipe in ipairs(recipes) do
    for _, item in ipairs(recipe.items) do
        if item:sub(1, 6) == "group:" then
            local groupsString = item:sub(7)
            local groupsTable = groupsString:split(",")
            if #groupsTable > 1 then
                usedMultiGroups[groupsString] = groupsTable
            end
        end
    end
    end
    end

    for _, item in ipairs(cg.items_all.list) do
        local groups = minetest.registered_items[item].groups

        for group, _ in pairs(groups) do
            if cg.group_stereotypes[group] == nil then
                cg.group_stereotypes[group] = item
            end
        end

        for clusterString, clusterTable in pairs(usedMultiGroups) do
            if cg.group_stereotypes[clusterString] == nil then
                local match = true
                for _, group in ipairs(clusterTable) do
                    if not groups[group] then
                        match = false
                        break
                    end
                end
                if match then
                    cg.group_stereotypes[clusterString] = item
                end
            end
        end
    end

    minetest.log("info", string.format("[cg_plus] Finished building group stereotype list in %.3f s.",
        (minetest.get_us_time() - startTime) / 1000000))
end

function cg.build_item_list()
    local startTime = minetest.get_us_time()
    cg.items_all.list = {}

    for item, def in pairs(minetest.registered_items) do
        if def.description and def.description ~= ""
                and minetest.get_item_group(item, "not_in_creative_inventory") == 0
                and minetest.get_item_group(item, "not_in_craft_guide") == 0 then
            table.insert(cg.items_all.list, item)
            cg.crafts[item] = minetest.get_all_craft_recipes(item) or {}
            table.insert_all(cg.crafts[item], custom_crafts[item] or {})
        end
    end

    local def, fuel, decremented

    for _, item in ipairs(cg.items_all.list) do
        def = minetest.registered_items[item]

        fuel, decremented = minetest.get_craft_result({
            method = "fuel",
            width = 0,
            items = {ItemStack(item)}
        })

        if fuel.time > 0 then
            table.insert(cg.crafts[item], {
                method = "fuel",
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
                        method = "digging",
                        width = 0,
                        items = {item},
                        output = ItemStack({
                            name = dItem,
                            count = dCount
                        }):to_string()
                    })
                end
            end

            for dItem, dCount in pairs(randomDrops) do
                if cg.crafts[dItem] then
                    table.insert(cg.crafts[dItem], {
                        method = "digging_chance",
                        width = 0,
                        items = {item},
                        output = ItemStack({
                            name = dItem,
                            count = dCount
                        }):to_string()
                    })
                end
            end
        end
    end

    table.sort(cg.items_all.list)
    cg.items_all.num_pages = math.ceil(#cg.items_all.list / cg.PAGE_ITEMS)

    minetest.log("info",
        string.format(
            "[cg_plus] Finished building item list in %.3f s.",
            (minetest.get_us_time() - startTime) / 1000000
        )
    )

    build_group_stereotypes_list()
end

function cg.filter_items(player, filter)
    local playerName = player:get_player_name()
    local playerData = cg.player_data[playerName]

    if not filter or filter == "" then
        playerData.items = nil
        return
    end

    playerData.items = {list = {}}

    filter = filter:lower()
    local groupFilter = string.sub(filter, 1, 6) == "group:" and filter:sub(7)

    if groupFilter and cg.GROUP_SEARCH then
        -- Search by group
        local groups = string.split(groupFilter, ",")
        local isInGroups

        for _, item in ipairs(cg.items_all.list) do
            isInGroups = true

            for idx = 1, math.min(#groups, cg.GROUP_SEARCH_MAX) do
                if minetest.get_item_group(item, groups[idx]) == 0 then
                    isInGroups = false
                    break
                end
            end

            if isInGroups then
                table.insert(playerData.items.list, item)
            end
        end
    else
        -- Regular search
        local langCode = playerData.lang_code

        for _, item in ipairs(cg.items_all.list) do
            if item:lower():find(filter, 1, true)
                    or minetest.get_translated_string(langCode,
                    minetest.registered_items[item].description)
                        :lower():find(filter, 1, true) then
                table.insert(playerData.items.list, item)
            end
        end
    end

    playerData.items.num_pages =
            math.ceil(#cg.get_item_list(player).list / cg.PAGE_ITEMS)
end

function cg.parse_craft(craft)
    local method
    if craft.method == "normal" and craft.width == 0 then -- Special rules for shapeless recipes
        method = "shapeless"
    else
        method = craft.method
    end

    local template = cg.craft_methods[method] or {}

    local gridSize = (template.get_grid_size and template.get_grid_size(craft)) or {x = 3, y = 3}
    local width = craft.width or 0
    local items = {}

    if width == 0 then
        -- Shapeless recipes
        items = craft.items
    else
        -- The craft's width is not always the same as the grid size, so items need to be shifted around.
        for i, item in pairs(craft.items) do
            items[i + (gridSize.x - width) * math.floor((i - 1) / width)] = item
        end
    end

    return {
        method = method,
        infotext = (template.get_infotext and template.get_infotext(craft)) or "",
        grid_size = gridSize,
        width = width,
        items = items,
        output = craft.output or "",
    }
end

function cg.get_item_list(player)
    return cg.player_data[player:get_player_name()].items or cg.items_all
end

function cg.register_crafting_method(name, def)
    cg.craft_methods[name] = def
end

function cg.register_craft(recipe, assign_to)
    local item = ItemStack(assign_to or recipe.output):get_name() -- Removes quantity, etc. from itemstring
    custom_crafts[item] = custom_crafts[item] or {}
    table.insert(custom_crafts[item], recipe)
end

function cg.register_group_stereotype(group, item)
    cg.group_stereotypes[group] = item
end

minetest.register_on_mods_loaded(cg.build_item_list)

minetest.register_on_joinplayer(function(player)
    local playerName = player:get_player_name()
    local langCode = minetest.get_player_information(playerName).lang_code

    cg.player_data[playerName] = {
        lang_code = langCode
    }
end)

minetest.register_on_leaveplayer(function(player, timed_out)
    cg.player_data[player:get_player_name()] = nil
end)
