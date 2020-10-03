local F = minetest.formspec_escape

cg.update_filter = function(player, context, filter, force)
    if not force and (filter or "") == context.cg_filter then return end

    context.cg_page = 0
    context.cg_filter = filter or ""
    cg.filter_items(player, context.cg_filter)
end

cg.update_selected_item = function(player, context, item, force)
    if not force and item == context.cg_selected_item then return end

    if item then context.cg_craft_page = 0 end

    context.cg_selected_item = item
    context.cg_auto_menu = false
end

local make_item_button = function(formspec, x, y, size, name)
    if name and name ~= "" then
        local groups, buttonText

        if name:sub(1, 6) == "group:" then
            groups = name:sub(7):split(",")
            buttonText = #groups > 1 and ("G " .. #groups) or "G"
            name = name:gsub(",", "/")
        end

        formspec[#formspec + 1] = string.format("item_image_button[%.2f,%.2f;%.2f,%.2f;%s;cgitem_%s;%s]",
                x, y, size, size,
                groups and (cg.group_stereotypes[groups[1]] or "") or name,
                name:match("^%S+"), -- Keep only the item name, not the quantity.
                buttonText or ""
            )

        if groups then
            formspec[#formspec + 1] = string.format("tooltip[cgitem_%s;%s]",
                    name,
                    #groups > 1 and
                    F(cg.S("Any item in groups: @1", minetest.colorize("#72FF63", table.concat(groups, ", ")))) or
                    F(cg.S("Any item in group: @1", minetest.colorize("#72FF63", groups[1])))
                )
        end
    else
        size = size * 0.8 + 0.2
        formspec[#formspec + 1] = string.format("image[%.2f,%.2f;%.2f,%.2f;gui_hb_bg.png]", x, y, size, size)
    end
end

local make_item_grid = function(formspec, player, context)
    local itemList = cg.get_item_list(player)
    context.cg_page = context.cg_page or 0

    formspec[#formspec + 1] = [[
            image_button[2.4,3.7;0.8,0.8;cg_plus_icon_search.png;cg_search;]
            image_button[3.1,3.7;0.8,0.8;cg_plus_icon_clear.png;cg_clear;]
            image_button[5.1,3.7;0.8,0.8;cg_plus_icon_prev.png;cg_prev;]
            image_button[7.1,3.7;0.8,0.8;cg_plus_icon_next.png;cg_next;]
        ]]

    formspec[#formspec + 1] = string.format("label[0,0;%s]", F(cg.S("Crafting Guide")))

    formspec[#formspec + 1] = string.format("field[0.3,3.9;2.5,1;cg_filter;;%s]", F(context.cg_filter or ""))
    formspec[#formspec + 1] = "field_close_on_enter[cg_filter;false]"
    formspec[#formspec + 1] = string.format("label[6,3.8;%i / %i]", context.cg_page + 1, itemList.num_pages)

    local startIdx = context.cg_page * cg.PAGE_ITEMS + 1
    local item

    for itemIdx = 0, cg.PAGE_ITEMS - 1 do
        item = itemList.list[startIdx + itemIdx]

        if item then
            formspec[#formspec + 1] = string.format("item_image_button[%.2f,%.2f;1,1;%s;cgitem_%s;]",
                    itemIdx % cg.PAGE_WIDTH,
                    math.floor(itemIdx / cg.PAGE_WIDTH) + 0.5,
                    item, item
                )
        end
    end
end

local make_craft_preview = function(formspec, player, context)
    formspec[#formspec + 1] = [[
            image_button[7.1,0.1;0.8,0.8;cg_plus_icon_prev.png;cg_craft_close;]
            image[0.1,0.1;0.8,0.8;gui_hb_bg.png]
        ]]
    local item = context.cg_selected_item

    formspec[#formspec + 1] = string.format("item_image[0.1,0.1;0.8,0.8;%s]", item)
    formspec[#formspec + 1] = string.format("label[1,0;%s]",
            cg.crafts[item] and minetest.registered_items[item].description or item)

    local crafts = cg.crafts[item]

    if not crafts or #crafts == 0 then
        formspec[#formspec + 1] = string.format("label[1,0.5;%s]", F(cg.S("There are no recipes for this item.")))
        return
    end

    if #crafts > 1 then
        formspec[#formspec + 1] = [[
                image_button[1.85,3.7;0.8,0.8;cg_plus_icon_prev.png;cg_craft_prev;]
                image_button[3.85,3.7;0.8,0.8;cg_plus_icon_next.png;cg_craft_next;]
            ]]
        formspec[#formspec + 1] = string.format("label[2.75,3.8;%i / %i]", context.cg_craft_page + 1, #crafts)
    end

    local craft = cg.parse_craft(crafts[context.cg_craft_page + 1])
    local template = cg.craft_types[craft.type] or {}

    if cg.autocrafting and template.uses_crafting_grid then
        formspec[#formspec + 1] = "image_button[0.1,3.7;0.8,0.8;cg_plus_icon_autocrafting.png;cg_auto_menu;]"
        formspec[#formspec + 1] = string.format("tooltip[cg_auto_menu;%s]", F(cg.S("Craft this recipe")))

        if context.cg_auto_menu then
            local num = 1
            local yPos = 3

            while true do
                num = math.min(num, context.cg_auto_max)
                formspec[#formspec + 1] = string.format("button[0.1,%.2f;0.8,0.8;cg_auto_%i;%i]", yPos, num, num)
                formspec[#formspec + 1] = string.format(
                        "tooltip[cg_auto_%i;%s]",
                        num,
                        num == 1 and F(cg.S("Craft @1 item", num)) or F(cg.S("Craft @1 items", num))
                    )

                if num < context.cg_auto_max then
                    num = num * 10
                    yPos = yPos - 0.7
                else
                    break
                end
            end
        end
    end

    formspec[#formspec + 1] = string.format("label[5,0.5;%s]", template.description or "")
    formspec[#formspec + 1] = string.format("label[5,1;%s]", craft.infotext or "")
    formspec[#formspec + 1] = string.format("image[4.75,1.5;1,1;%s]",
            template.arrow_icon or "cg_plus_arrow.png")

    local slotSize = math.min(3 / math.max(craft.grid_size.x, craft.grid_size.y), 1)
    local xOffset = 4.75 - craft.grid_size.x * slotSize
    local yOffset = 2 - craft.grid_size.y * slotSize * 0.5

    for idx = 1, craft.grid_size.x * craft.grid_size.y do
        make_item_button(formspec,
                (idx - 1) % craft.grid_size.x * slotSize + xOffset,
                math.floor((idx - 1) / craft.grid_size.y) * slotSize + yOffset,
                slotSize,
                craft.items[idx]
            )
    end

    make_item_button(formspec, 5.75, 1.5, 1, craft.output)
end

sfinv.register_page("cg_plus:crafting_guide", {
    title = "Crafting Guide",
    get = function(self, player, context)
        local formspec = {[[
                image[0,4.75;1,1;gui_hb_bg.png]
                image[1,4.75;1,1;gui_hb_bg.png]
                image[2,4.75;1,1;gui_hb_bg.png]
                image[3,4.75;1,1;gui_hb_bg.png]
                image[4,4.75;1,1;gui_hb_bg.png]
                image[5,4.75;1,1;gui_hb_bg.png]
                image[6,4.75;1,1;gui_hb_bg.png]
                image[7,4.75;1,1;gui_hb_bg.png]
            ]]}

        if context.cg_selected_item then
            make_craft_preview(formspec, player, context)
        else
            make_item_grid(formspec, player, context)
        end

        return sfinv.make_formspec(player, context, table.concat(formspec), true)
    end,

    on_player_receive_fields = function(self, player, context, fields)
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
        elseif fields.cg_auto_menu and cg.autocrafting then
            if not context.cg_auto_menu then
                -- Make sure the craft is valid, in case the client is sending fake formspec fields.
                local crafts = cg.crafts[context.cg_selected_item] or {}
                local craft = crafts[context.cg_craft_page + 1]

                if craft and cg.craft_types[craft.type] and cg.craft_types[craft.type].uses_crafting_grid then
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
                        if cg.group_search then
                            cg.update_filter(player, context, item:gsub("/", ","))
                            cg.update_selected_item(player, context, nil)
                        elseif cg.group_stereotypes[item:sub(7)] then
                            cg.update_selected_item(player, context, cg.group_stereotypes[item:sub(7)])
                        end
                    else
                        cg.update_selected_item(player, context, item)
                    end

                    break
                elseif field:sub(1, 8) == "cg_auto_" and context.cg_auto_menu then
                    -- No need to sanity check, we already did that when showing the autocrafting menu.
                    local num = tonumber(field:sub(9))

                    if num > 0 and num <= context.cg_auto_max then
                        cg.auto_craft(player, cg.crafts[context.cg_selected_item][context.cg_craft_page + 1], num)
                        sfinv.set_page(player, "sfinv:crafting")
                    end

                    context.cg_auto_menu = false
                    break
                end
            end
        end

        -- Wrap around when the player presses the next button on the last page, or the previous button on the first.
        if context.cg_page then
            context.cg_page = context.cg_page % math.max(cg.get_item_list(player).num_pages, 1)
        end

        if context.cg_craft_page then
            context.cg_craft_page = context.cg_craft_page % math.max(#(cg.crafts[context.cg_selected_item] or {}), 1)
        end

        -- Update the formspec.
        sfinv.set_player_inventory_formspec(player, context)
    end,

    on_leave = function(self, player, context)
        context.cg_auto_menu = false
    end,
})
