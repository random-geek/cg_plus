local F = minetest.formspec_escape

function cg.update_filter(player, context, filter, force)
    filter = filter or ""
    if not force and filter:lower() == (context.cg_filter or ""):lower() then
        return
    end

    context.cg_page = 0
    context.cg_filter = filter
    cg.filter_items(player, context.cg_filter)
end

function cg.update_selected_item(player, context, item, force)
    if not force and item == context.cg_selected_item then
        return
    end

    if item then
        context.cg_craft_page = 0
    end

    context.cg_selected_item = item
    context.cg_auto_menu = false
end

local function make_item_button(formspec, x, y, size, itemstring)
    if itemstring and itemstring ~= "" then
        local itemName = itemstring:match("^%S+") -- Remove quantity, etc. Note: may be a group item.

        local groups, shownItem, buttonID, buttonText
        if itemName:sub(1, 6) == "group:" then
            local groupString = itemName:sub(7)
            groups = groupString:split(",")
            if #groups == 1 then
                shownItem = cg.group_stereotypes[groups[1]] or ""
            elseif #groups > 1 then
                shownItem = cg.group_stereotypes[groupString] or ""
            end
            -- shownItem = (cg.group_stereotypes[groupString] or cg.group_stereotypes[groups[1]]) or ""
            buttonID = itemName:gsub(",", "/")
            buttonText = #groups == 1 and "G" or ("G " .. #groups)
        else
            shownItem = itemstring
            buttonID = itemName
            buttonText = ""
        end

        formspec[#formspec + 1] = string.format(
            "item_image_button[%.2f,%.2f;%.2f,%.2f;%s;cgitem_%s;%s]",
            x, y, size, size, shownItem, buttonID, buttonText
        )

        if groups then
            local tooltipText
            if #groups == 1 then
                tooltipText = F(cg.S(
                    "Any item in group: @1",
                    minetest.colorize("#72FF63", groups[1])
                ))
            else
                tooltipText = F(cg.S(
                    "Any item in groups: @1",
                    minetest.colorize("#72FF63", table.concat(groups, ", "))
                ))
            end

            formspec[#formspec + 1] = string.format("tooltip[cgitem_%s;%s]", buttonID, tooltipText)
        end
    else
        formspec[#formspec + 1] = string.format(
            "image[%.2f,%.2f;%.2f,%.2f;gui_hb_bg.png]",
            x, y, size, size
        )
    end
end

local function make_item_grid(formspec, player, context)
    local itemList = cg.get_item_list(player)
    context.cg_page = context.cg_page or 0

    -- Buttons
    formspec[#formspec + 1] =
        "real_coordinates[true]" ..
        "image_button[3.425,5.3;0.8,0.8;cg_plus_icon_search.png;cg_search;]" ..
        "image_button[4.325,5.3;0.8,0.8;cg_plus_icon_clear.png;cg_clear;]" ..
        "image_button[6.625,5.3;0.8,0.8;cg_plus_icon_prev.png;cg_prev;]" ..
        "image_button[9.325,5.3;0.8,0.8;cg_plus_icon_next.png;cg_next;]"

    -- Search box
    formspec[#formspec + 1] = string.format(
        "field[0.375,5.3;2.95,0.8;cg_filter;;%s]",
        F(context.cg_filter or "")
    )
    formspec[#formspec + 1] = "field_close_on_enter[cg_filter;false]"

    -- Page number
    formspec[#formspec + 1] = string.format("label[7.75,5.7;%i / %i]",
            context.cg_page + 1, itemList.num_pages)

    local startIdx = context.cg_page * cg.PAGE_ITEMS + 1
    local item

    for itemIdx = 0, cg.PAGE_ITEMS - 1 do
        item = itemList.list[startIdx + itemIdx]

        if item then
            formspec[#formspec + 1] = string.format(
                "item_image_button[%.2f,%.2f;1,1;%s;cgitem_%s;]",
                (itemIdx % cg.PAGE_WIDTH) * 1.25 + 0.375,
                math.floor(itemIdx / cg.PAGE_WIDTH) * 1.25 + 0.375,
                item, item
            )
        end
    end
end

local function make_craft_preview(formspec, player, context)
    formspec[#formspec + 1] =
        "real_coordinates[true]" ..
        "image_button[9.325,0.375;0.8,0.8;" ..
            "cg_plus_icon_clear.png;cg_craft_close;]" ..
        "image[0.375,0.375;0.8,0.8;gui_hb_bg.png]"

    local item = context.cg_selected_item

    -- Item image
    formspec[#formspec + 1] = string.format(
        "item_image[0.375,0.375;0.8,0.8;%s]",
        item
    )
    -- Item name
    formspec[#formspec + 1] = string.format(
        "label[1.5,0.6;%s]",
        cg.crafts[item] and minetest.registered_items[item].description or item
    )

    -- No recipes label, if applicable
    local crafts = cg.crafts[item]
    if not crafts or #crafts == 0 then
        formspec[#formspec + 1] = string.format("label[2.875,3.2;%s]",
                F(cg.S("There are no recipes for this item.")))
        return
    end

    -- Previous/next craft buttons, page number
    if #crafts > 1 then
        formspec[#formspec + 1] =
            "image_button[2.875,5.3;0.8,0.8;" ..
                "cg_plus_icon_prev.png;cg_craft_prev;]" ..
            "image_button[5.575,5.3;0.8,0.8;" ..
                "cg_plus_icon_next.png;cg_craft_next;]"
        formspec[#formspec + 1] = string.format("label[4,5.7;%i / %i]",
                context.cg_craft_page + 1, #crafts)
    end

    local craft = cg.parse_craft(crafts[context.cg_craft_page + 1])
    local template = cg.craft_methods[craft.method] or {}

    -- Auto-crafting buttons
    if cg.AUTOCRAFTING and template.uses_crafting_grid then
        formspec[#formspec + 1] = "image_button[0.375,5.3;0.8,0.8;" ..
                "cg_plus_icon_autocrafting.png;cg_auto_menu;]"
        formspec[#formspec + 1] = string.format("tooltip[cg_auto_menu;%s]",
                F(cg.S("Craft this recipe")))

        if context.cg_auto_menu then
            local num = 1
            local yPos = 4.3

            while true do
                num = math.min(num, context.cg_auto_max)
                formspec[#formspec + 1] = string.format(
                    "button[0.375,%.2f;0.8,0.8;cg_auto_%i;%i]",
                    yPos, num, num
                )
                formspec[#formspec + 1] = string.format(
                    "tooltip[cg_auto_%i;%s]",
                    num,
                    num == 1
                        and F(cg.S("Craft @1 item", num))
                        or F(cg.S("Craft @1 items", num))
                )

                if num < context.cg_auto_max then
                    num = num * 10
                    yPos = yPos - 1
                else
                    break
                end
            end
        end
    end

    -- Craft method/infotext
    formspec[#formspec + 1] = string.format("label[6.7,1.8;%s]", F(template.description) or "")
    formspec[#formspec + 1] = string.format("label[6.7,2.4;%s]", F(craft.infotext) or "")

    -- Draw craft item grid, feat. maths.

    -- Determine max number of grid slots that could fit on one side.
    -- Squares shouldn't take up more than a third of the grid area.
    local gridMax = math.max(math.max(craft.grid_size.x, craft.grid_size.y), 3)
    -- Determine distance between crafting grid slots.
    -- <grid area side length> / (<num slots per side> - <extra padding>)
    local slotDist = 3.5 / (gridMax - 0.2)

    -- Determine upper-left corner of crafting squares
    -- <right x of grid area> - (<grid width> - <extra padding>) * slotDist
    local xOffset = 6.375 - (craft.grid_size.x - 0.2) * slotDist
    -- <center y of grid area> -
    --      (<grid height> - <extra padding>) * slotDist * 0.5
    local yOffset = 3.2 - (craft.grid_size.y - 0.2) * slotDist * 0.5

    for idx = 1, craft.grid_size.x * craft.grid_size.y do
        make_item_button(
            formspec,
            ((idx - 1) % craft.grid_size.x) * slotDist + xOffset,
            math.floor((idx - 1) / craft.grid_size.y) * slotDist + yOffset,
            slotDist * 0.8, -- 1 - <padding amount>
            craft.items[idx]
        )
    end

    -- Craft arrow
    formspec[#formspec + 1] = string.format("image[6.625,2.7;1,1;%s]",
            template.arrow_icon or "cg_plus_arrow.png")

    -- Craft output
    make_item_button(formspec, 7.875, 2.7, 1, craft.output)
end

--[[
    sfinv registration
]]

local function page_get(self, player, context)
    local formspec = {}

    if context.cg_selected_item then
        make_craft_preview(formspec, player, context)
    else
        make_item_grid(formspec, player, context)
    end

    return sfinv.make_formspec(player, context, table.concat(formspec), true)
end

local function page_on_player_receive_fields(self, player, context, fields)
    if fields.cg_craft_close then
        context.cg_selected_item = nil
        context.cg_auto_menu = false
    elseif fields.cg_prev and context.cg_page then
        context.cg_page = context.cg_page - 1
    elseif fields.cg_next and context.cg_page then
        context.cg_page = context.cg_page + 1
    elseif fields.cg_craft_prev and context.cg_craft_page then
        context.cg_craft_page = context.cg_craft_page - 1
        context.cg_auto_menu = false
    elseif fields.cg_craft_next and context.cg_craft_page then
        context.cg_craft_page = context.cg_craft_page + 1
        context.cg_auto_menu = false
    elseif fields.cg_search or fields.key_enter_field == "cg_filter" then
        cg.update_filter(player, context, fields.cg_filter)
    elseif fields.cg_clear then
        cg.update_filter(player, context, "", true)
    elseif fields.cg_auto_menu and cg.AUTOCRAFTING then
        if not context.cg_auto_menu then
            -- Make sure the craft is valid, in case the client is sending
            -- fake formspec fields.
            local crafts = cg.crafts[context.cg_selected_item] or {}
            local craft = crafts[context.cg_craft_page + 1]

            if craft and cg.craft_methods[craft.method]
                    and cg.craft_methods[craft.method].uses_crafting_grid then
                context.cg_auto_menu = true
                context.cg_auto_max = cg.auto_get_craftable(player, craft)
            end
        else
            context.cg_auto_menu = false
        end
    else
        for field, _ in pairs(fields) do
            if field:sub(1, 7) == "cgitem_" then
                local item = string.sub(field, 8)

                if item:sub(1, 6) == "group:" then
                    item = item:gsub("/", ",")
                    if cg.GROUP_SEARCH then
                        cg.update_filter(player, context, item)
                        cg.update_selected_item(player, context, nil)
                    elseif cg.group_stereotypes[item:sub(7)] then
                        cg.update_selected_item(player, context,
                                cg.group_stereotypes[item:sub(7)])
                    end
                else
                    cg.update_selected_item(player, context, item)
                end

                break
            elseif field:sub(1, 8) == "cg_auto_"
                    and context.cg_auto_menu then
                -- No need to sanity check, we already did that when
                -- showing the autocrafting menu.
                local num = tonumber(field:sub(9))

                if num > 0 and num <= context.cg_auto_max then
                    cg.auto_craft(
                        player,
                        cg.crafts[context.cg_selected_item]
                            [context.cg_craft_page + 1],
                        num
                    )
                    sfinv.set_page(player, "sfinv:crafting")
                end

                context.cg_auto_menu = false
                break
            end
        end
    end

    -- Wrap around when the player presses the next button on the last
    -- page, or the previous button on the first.
    if context.cg_page then
        context.cg_page = context.cg_page %
                math.max(cg.get_item_list(player).num_pages, 1)
    end

    if context.cg_craft_page then
        context.cg_craft_page = context.cg_craft_page %
                math.max(#(cg.crafts[context.cg_selected_item] or {}), 1)
    end

    -- Update the formspec.
    sfinv.set_player_inventory_formspec(player, context)
end

local function page_on_leave(self, player, context)
    context.cg_auto_menu = false
end

if sfinv.pages["mtg_craftguide:craftguide"] ~= nil then
    -- Override MTG's crafting guide
    sfinv.override_page("mtg_craftguide:craftguide", {
        title = F(cg.S("Crafting Guide")),
        get = page_get,
        on_player_receive_fields = page_on_player_receive_fields,
        on_leave = page_on_leave
    })
else
    sfinv.register_page("cg_plus:crafting_guide", {
        title = F(cg.S("Crafting Guide")),
        get = page_get,
        on_player_receive_fields = page_on_player_receive_fields,
        on_leave = page_on_leave
    })
end
