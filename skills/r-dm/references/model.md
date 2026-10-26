# Reshaping and drawing a model

## Normalizing a flat table

`decompose_table()` is the normalization primitive: split a lookup out of a wide table, linked by a new surrogate key.

```r
parts <- decompose_table(mtcars_tbl, am_gear_carb_id, am, gear, carb)
parts$parent_table   # distinct am/gear/carb combinations + am_gear_carb_id
parts$child_table    # original rows, those three columns replaced by the id
```

The inverse joins them back and drops the id column:

```r
reunite_parent_child(parts$child_table, parts$parent_table, id_column = am_gear_carb_id)
reunite_parent_child_from_list(parts, id_column = am_gear_carb_id)   # same, from the list
```

These three operate on loose tables, not on a `dm`. To land the result in a model, feed both tables to `dm()` and declare the key yourself:

```r
dm(cars = parts$child_table, specs = parts$parent_table) |>
  dm_add_pk(specs, am_gear_carb_id) |>
  dm_add_fk(cars, am_gear_carb_id, specs)
```

## Collapsing a model into nested columns

For sending a whole model through something that takes one table — an API payload, a JSON column, a single file:

```r
wrapped <- dm_wrap_tbl(dm, root = flights)   # one table, everything else nested inside
dm_unwrap_tbl(wrapped, ptype = dm_ptype(dm)) # back to the original shape
```

`dm_ptype(dm)` is the zero-row skeleton that tells `dm_unwrap_tbl()` what shape to rebuild, so capture it before wrapping.

One level at a time, with `dm_nest_tbl()` for the child side and `dm_pack_tbl()` for the parent side:

```r
dm_nest_tbl(dm, child_table)    # child -> list column on its parent; child must be a leaf
dm_pack_tbl(dm, parent_table)   # parent -> packed column on its child; parent must be a root
```

Their inverses, `dm_unnest_tbl()` and `dm_unpack_tbl()`, take a ptype **or** a set of keys, not both. The `json_*()` family (`json_nest()`, `json_pack()`, `json_nest_join()`, `json_pack_join()` and their inverses) does the same into JSON text columns, which is what you want when the destination is a database column rather than an R list.

## Drawing

```r
dm_draw(dm, view_type = "keys_only", rankdir = "LR")
```

`view_type` is the argument to reach for: `"keys_only"` (default) shows just the key columns, `"all"` every column, `"title_only"` table names alone. Draw a subset by selecting first — `dm_select_tbl(dm, flights, airports) |> dm_draw()`.

Colours group tables into families, assigned tidyselect-style as `colour = tables`:

```r
dm_set_colors(dm, maroon4 = flights, orange = starts_with("air"), "#5986C4" = planes)
```

Any hex code or R colour name works; `dm_get_available_colors()` lists the names, `dm_get_colors()` reads back what is set. Colours live on the `dm` as metadata, so they survive the rest of the pipeline. `dm_set_table_description()` adds per-table captions to the diagram.

To write the diagram to a file:

```r
dm_draw(dm) |> DiagrammeRsvg::export_svg() |> write("model.svg")
```

## Handing a model to code

```r
dm_paste(dm)              # prints the dm() + dm_add_pk() + dm_add_fk() calls that rebuild it
dm_paste(dm, path = "R/model.R")
dm_deconstruct(dm)        # prints pull_tbl(keyed = TRUE) assignments, one per table
```

`dm_paste()` is the fastest route from an explored model to a committed script or a test fixture — learn the keys once interactively, paste the generated code, and the model stops depending on `learn_keys`.
