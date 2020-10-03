cg = {
    PAGE_WIDTH = 8,
    PAGE_ITEMS = 24,
    items_all = {},
    items_filtered = {},
    crafts = {},
    craft_types = {},
    group_stereotypes = {},
}

local settings = minetest.settings

cg.autocrafting = settings:get_bool("cg_plus_autocrafting", true)
cg.group_search = settings:get_bool("cg_plus_group_search", true)
cg.group_search_max = tonumber(settings:get("cg_plus_group_search_max")) or 5

cg.S = minetest.get_translator("cg_plus")
local F = minetest.formspec_escape

local path = minetest.get_modpath("cg_plus")

dofile(path .. "/api.lua")

if cg.autocrafting then
    dofile(path .. "/autocrafting.lua")
end

dofile(path .. "/inventory.lua")

cg.register_craft_type("normal", {
    description = F(cg.S("Crafting")),
    uses_crafting_grid = true,
    alt_zero_width = "shapeless",

    get_grid_size = function(craft)
        local width = math.max(craft.width, 1)
        local height = math.ceil(table.maxn(craft.items) / width)
        local sideLen = math.max(width, height)

        if sideLen < 3 then
            return {x = 3, y = 3}
        else
            return {x = sideLen, y = sideLen}
        end
    end,
})

cg.register_craft_type("shapeless", {
    description = F(cg.S("Mixing")),
    inherit_width = true,
    uses_crafting_grid = true,

    get_grid_size = function(craft)
        local numItems = table.maxn(craft.items)

        if table.maxn(craft.items) <= 9 then
            return {x = 3, y = 3}
        else
            local sideLen = math.ceil(math.sqrt(numItems))
            return {x = sideLen, y = sideLen}
        end
    end,
})

cg.register_craft_type("cooking", {
    description = F(cg.S("Cooking")),
    inherit_width = true,
    arrow_icon = "cg_plus_arrow_small.png^cg_plus_icon_cooking.png",

    get_grid_size = function(craft)
        return {x = 1, y = 1}
    end,

    get_infotext = function(craft)
        return minetest.colorize("#FFFF00", F(cg.S("Time: @1 s", craft.width or 0)))
    end,
})

cg.register_craft_type("fuel", {
    description = F(cg.S("Fuel")),
    inherit_width = true,
    arrow_icon = "cg_plus_arrow_small.png^cg_plus_icon_fuel.png",

    get_grid_size = function(craft)
        return {x = 1, y = 1}
    end,

    get_infotext = function(craft)
        return minetest.colorize("#FFFF00", F(cg.S("Time: @1 s", craft.time or 0)))
    end,
})

cg.register_craft_type("digging", {
    description = F(cg.S("Digging")),
    inherit_width = true,
    arrow_icon = "cg_plus_arrow_small.png^cg_plus_icon_digging.png",

    get_grid_size = function(craft)
        return {x = 1, y = 1}
    end,
})

cg.register_craft_type("digging_chance", {
    description = F(cg.S("Digging@n(by chance)")),
    inherit_width = true,
    arrow_icon = "cg_plus_arrow_small.png^cg_plus_icon_digging.png",

    get_grid_size = function(craft)
        return {x = 1, y = 1}
    end,
})

cg.register_group_stereotype("mesecon_conductor_craftable", "mesecons:wire_00000000_off")

if minetest.get_modpath("default") then
    cg.register_group_stereotype("stone", "default:stone")
    cg.register_group_stereotype("wood", "default:wood")
    cg.register_group_stereotype("sand", "default:sand")
    cg.register_group_stereotype("leaves", "default:leaves")
    cg.register_group_stereotype("tree", "default:tree")
end
