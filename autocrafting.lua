local function add_or_create(t, i, n)
    t[i] = t[i] and t[i] + n or n
end

local function get_group_item(invCache, groups)
    local maxCount = 0
    local maxItem
    local isInGroups

    for item, count in pairs(invCache) do
        isInGroups = true

        for _, group in ipairs(groups) do
            if minetest.get_item_group(item, group) == 0 then
                isInGroups = false
                break
            end
        end

        if isInGroups and count > maxCount then
            maxItem = item
            maxCount = count
        end
    end

    return maxItem
end

function cg.auto_get_craftable(player, craft)
    local inv = player:get_inventory():get_list("main")
    local invCache = {}

    -- Create a cache of the inventory with itemName = count pairs.
    -- This speeds up searching for items.
    for _, stack in ipairs(inv) do
        if stack:get_count() > 0 then
            add_or_create(invCache, stack:get_name(), stack:get_count())
        end
    end

    local reqItems = {}
    local reqGroups = {}

    -- Find out how many of each item/group is required to craft one item.
    for _, item in pairs(craft.items) do
        if item:sub(1, 6) == "group:" then
            add_or_create(reqGroups, item, 1)
        else
            add_or_create(reqItems, item, 1)
        end
    end

    local gMaxItem

    -- For each group, find the item in that group from the player's inventory
    -- with the largest count.
    for group, count in pairs(reqGroups) do
        gMaxItem = get_group_item(invCache, group:sub(7):split(","))

        if gMaxItem then
            add_or_create(reqItems, gMaxItem, count)
        else
            return 0
        end
    end

    local craftable = 1000

    for item, count in pairs(reqItems) do
        if invCache[item] then
            craftable = math.min(craftable, math.floor(invCache[item] / count))
        else
            return 0
        end

        -- We can't craft more than the stack_max of our ingredients.
        if minetest.registered_items[item].stack_max then
            craftable = math.min(craftable,
                    minetest.registered_items[item].stack_max)
        end
    end

    return craftable
end

function cg.auto_craft(player, craft, num)
    local inv = player:get_inventory()

    if not inv:is_empty("craft") then
        -- Attempt to move items to the player's main inventory.
        for idx, stack in ipairs(inv:get_list("craft")) do
            if not stack:is_empty() then
                stack = inv:add_item("main", stack)
                inv:set_stack("craft", idx, stack)
            end
        end

        -- Check again, and return if not all items were moved.
        if not inv:is_empty("craft") then
            minetest.chat_send_player(player:get_player_name(),
                    cg.S("Item could not be crafted!"))
            return
        end
    end

    if craft.width > inv:get_width("craft")
            or table.maxn(craft.items) > inv:get_size("craft") then
        return
    end

    local invList = inv:get_list("main")
    local width = craft.width == 0 and inv:get_width("craft") or craft.width
    local stack, invCache
    local groupCache = {}

    for idx, item in pairs(craft.items) do
        -- Shift the indices so the items in the craft go to the right spots on
        -- the crafting grid.
        idx = (idx + (inv:get_width("craft") - width) *
                math.floor((idx - 1) / width))

        if item:sub(1, 6) == "group:" then
            -- Create an inventory cache.
            if not invCache then
                invCache = {}

                for _, stack in ipairs(invList) do
                    if stack:get_count() > 0 then
                        add_or_create(invCache, stack:get_name(),
                                stack:get_count())
                    end
                end
            end

            -- Get the most plentiful item in the group.
            if not groupCache[item] then
                groupCache[item] = get_group_item(invCache,
                        item:sub(7):split(","))
            end

            -- Move the selected item.
            if groupCache[item] then
                stack = inv:remove_item("main",
                        ItemStack({name = groupCache[item], count = num}))
                inv:set_stack("craft", idx, stack)
            end
        else
            -- Move the item.
            stack = inv:remove_item("main",
                    ItemStack({name = item, count = num}))
            inv:set_stack("craft", idx, stack)
        end
    end
end

minetest.register_on_player_inventory_action(
    function(player, action, inventory, inventory_info)
        -- Hide the autocrafting menu when the player drops an item.
        if cg.AUTOCRAFTING and inventory_info.listname == "main" then
            local context = sfinv.get_or_create_context(player)

            if context.cg_auto_menu then
                context.cg_auto_menu = false
                sfinv.set_player_inventory_formspec(player)
            end
        end
    end
)
