# Crafting Guide Plus developer documentation

## Groups

cg_plus respects the standard groups `not_in_creative_inventory` and `not_in_craft_guide`.
Adding either of these to an item/node definition will make it not appear in the crafting guide.

## API

### `cg.register_crafting_method(name, def)`

Adds or overrides a type of craft in cg_plus, for use with `cg.register_craft`. Default craft methods are `normal`,
`shapeless`, `cooking`, `fuel`, `digging`, and `digging_chance`.

#### Parameters

* `name` (string): The name of the new craft method. Matches the `method` field in craft definitions.
* `def` (table): A craft method definition with the following fields:
    * `description` (string): A human-readable name for the crafting method, which will be shown next to recipes in the
      crafting guide.
    * `arrow_icon` (string): Texture to use for the arrow icon in recipes. Default is a plain arrow.
    * `uses_crafting_grid` (bool): Setting to `true` allows crafts of this method to be automatically staged in the
      default crafting grid when autocrafting is enabled.
    * `get_grid_size = function(craft)`: Used to calculate the shape of the crafting grid displayed for each recipe.
      Takes a recipe defintion `craft` and returns a table in the format `{x = width, y = height}`.
    * `get_infotext = function(craft)`: Optional, used to add additional information to a recipe page, e.g. cooking or
      burning times. Takes a recipe defintion `craft` and returns a string.

#### Example

See below.

### `cg.register_craft(recipe, [assign_to])`

Registers a craft to appear only in the crafting guide, independent of `minetest.register_craft`. Useful for mods that
implement crafting outside the default crafting grid.

#### Parameters

* `recipe` (table): Possible keys:
    * `method` (string): Can be an official crafting method or one created with `cg.register_craft`.
    * `width` (integer): Width of the recipe inputs, which may be less than the width of the crafting grid. If zero, the
      recipe will expand to the full width of the crafting grid.
    * `items` (table): One-dimensional table of input item names, listed from left-to-right and top-to-bottom. May be
      groups such as `group:dye` or `group:dye,color_violet`.
    * `output` (string): Output itemstring, e.g. `default:stone` or `default:wood 4`.
    * Additional fields can be added (e.g. cooking time) which can be displayed using `get_infotext` in
      `cg.register_crafting_method`. The `items` and `width` fields are reserved.
* `assign_to` (string): Optional itemstring; if specified, the craft will be assigned to this item rather than the
  output item. Useful for fuel recipes that consume the input, etc.

#### Example

Register a craft for a theoretical mod `woodmod` which allows sawing of stairs using a table saw:

```lua
cg.register_crafting_method("woodmod_table_saw", {
    description = "Table Saw",
    arrow_icon = "cg_plus_arrow_bottom.png^woodmod_icon_saw.png",
    uses_crafting_grid = false,
    get_grid_size = function(craft)
        return {x = 4, y = 4}
    end,
    get_infotext = function(craft)
        return string.format("Cutting time: %i seconds", craft.cutting_time)
    end,
})

cg.register_craft({
    method = "woodmod_table_saw",
    width = 2,
    items = {"group:wood", "", "group:wood", "group:wood"},
    output = "stairs:stair_wood 4",
    cutting_time = 10,
})
```

### `cg.register_group_stereotype(group, item)`

Adds or overrides a group stereotype. When a recipe takes a generic item in the given group, the given item will be
displayed instead of a randomly-chosen item in that group. Clicking on the item button with group search disabled will
also search for the stereotype item.

`group` can be multiple comma-separated groups (e.g. `dye,color_blue`) for use by recipes with multi-group items. The
order of the groups *does* matter.

#### Example

Show yellow dye as the default for items in the `dye` group:

```lua
cg.register_group_stereotype("dye", "dye:yellow")
```
