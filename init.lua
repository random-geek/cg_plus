cg = {
    PAGE_WIDTH = 8,
    PAGE_ITEMS = 32,
    items_all = {},
    player_data = {},
    crafts = {},
    craft_methods = {},
    group_stereotypes = {},
}

local settings = minetest.settings

cg.AUTOCRAFTING = settings:get_bool("cg_plus_autocrafting", true)
cg.GROUP_SEARCH = settings:get_bool("cg_plus_group_search", true)
cg.GROUP_SEARCH_MAX = tonumber(settings:get("cg_plus_group_search_max")) or 5

cg.S = minetest.get_translator("cg_plus")
local F = minetest.formspec_escape

local path = minetest.get_modpath("cg_plus")
dofile(path .. "/api.lua")

if cg.AUTOCRAFTING then
    dofile(path .. "/autocrafting.lua")
end

dofile(path .. "/inventory.lua")

cg.register_crafting_method("normal", {
    description = cg.S("Crafting"),
    uses_crafting_grid = true,

    get_grid_size = function(craft)
        local width = math.max(craft.width, 1)
        local height = math.ceil(table.maxn(craft.items) / width)
        local sideLen = math.max(width, height)

        if sideLen < 3 then
            return {x = 3, y = 3}
        else
            return {x = sideLen, y = sideLen}
        end
    end
})

cg.register_crafting_method("shapeless", {
    description = cg.S("Mixing"),
    uses_crafting_grid = true,

    get_grid_size = function(craft)
        local numItems = table.maxn(craft.items)

        if table.maxn(craft.items) <= 9 then
            return {x = 3, y = 3}
        else
            local sideLen = math.ceil(math.sqrt(numItems))
            return {x = sideLen, y = sideLen}
        end
    end
})

cg.register_crafting_method("cooking", {
    description = cg.S("Cooking"),
    arrow_icon = "cg_plus_arrow_bottom.png^cg_plus_icon_cooking.png",

    get_grid_size = function(craft)
        return {x = 1, y = 1}
    end,

    get_infotext = function(craft)
        return minetest.colorize("#FFFF00", cg.S("Time: @1 s", craft.width or 0))
    end
})

cg.register_crafting_method("fuel", {
    description = cg.S("Fuel"),
    arrow_icon = "cg_plus_arrow_bottom.png^cg_plus_icon_fuel.png",

    get_grid_size = function(craft)
        return {x = 1, y = 1}
    end,

    get_infotext = function(craft)
        return minetest.colorize("#FFFF00", cg.S("Time: @1 s", craft.time or 0))
    end
})

cg.register_crafting_method("digging", {
    description = cg.S("Digging"),
    arrow_icon = "cg_plus_arrow_bottom.png^cg_plus_icon_digging.png",

    get_grid_size = function(craft)
        return {x = 1, y = 1}
    end
})

cg.register_crafting_method("digging_chance", {
    description = cg.S("Digging@n(by chance)"),
    arrow_icon = "cg_plus_arrow_bottom.png^cg_plus_icon_digging.png",

    get_grid_size = function(craft)
        return {x = 1, y = 1}
    end
})

cg.register_group_stereotype("mesecon_conductor_craftable", "mesecons:wire_00000000_off")

if minetest.get_modpath("default") then
    cg.register_group_stereotype("stone", "default:stone")
    cg.register_group_stereotype("wood", "default:wood")
    cg.register_group_stereotype("sand", "default:sand")
    cg.register_group_stereotype("leaves", "default:leaves")
    cg.register_group_stereotype("tree", "default:tree")
end
