# Querying a `dm`: filter, flatten, zoom

Three ways to get at the data, each with a different blast radius.

## `dm_filter()` — filter that cascades

```r
dm_filter(dm, airports = (name == "John F Kennedy Intl"), flights = (month == 1))
```

Conditions are named by table and passed to `dplyr::filter()`; several conditions on one table combine with `&`. Each condition is applied immediately — since dm 1.0.0 nothing is stored on the `dm`, so `dm_apply_filters()` is gone.

The cascade works by successive semi-joins along the FK paths out of each filtered table, so every table in the `dm` is reduced to rows still related to what survived. **It requires a cycle-free FK graph** and errors otherwise.

Two idioms worth knowing:

```r
# Keep only parent rows that are actually referenced by a child
dm_filter(dm, flights = (1 == 1))

# Filter one table WITHOUT touching its relatives
dm |> dm_zoom_to(flights) |> filter(month == 1) |> dm_update_zoomed()
```

## `dm_flatten_to_tbl()` — one wide table

```r
dm_flatten_to_tbl(dm, .start = flights, .recursive = TRUE, .join = left_join)
```

Joins parent tables into `.start` along the FKs, disambiguating column names as it goes. `.recursive = FALSE` (the default) takes direct parents only; `TRUE` follows the chain. Name tables in `...` to restrict which parents come along. `.join` takes any of `left_join`, `inner_join`, `full_join`, `right_join`, `semi_join`, `anti_join`.

`dm_flatten()` (experimental) does the same thing in place: the parents are folded into the table and removed from the `dm`.

## `dm_zoom_to()` — dplyr verbs on one table

```r
dm |>
  dm_zoom_to(flights) |>
  mutate(before_noon = dep_time < 1200) |>
  dm_update_zoomed()
```

While zoomed, the `dm` behaves like the table: `filter`, `mutate`, `select`, `summarise`, `group_by`, `arrange`, `distinct`, `count`, the joins, `unite`, `separate` and friends all work unsuffixed. Joins get an extra argument the plain dplyr ones lack:

```r
left_join(planes, select = c(tailnum, plane_type = type))   # pick columns from the other table
```

Exit by one of three doors, every time, before any `dm_*` call or `pull_tbl(dm, tbl)`:

| Exit | Result |
|---|---|
| `dm_update_zoomed()` | overwrite the original table |
| `dm_insert_zoomed("name")` | keep both, FKs carried to the new table |
| `dm_discard_zoomed()` | throw the work away |

`pull_tbl()` with no table argument returns the zoomed table mid-pipeline without exiting.

**Keys drop when you touch their columns.** A `mutate()` or `select()` over a key column removes the key, deliberately — re-add it with `dm_add_pk()`/`dm_add_fk()` after the manipulation. Not every dplyr verb has a zoomed method either; for an unsupported one, `pull_tbl()`, transform, and `dm()` the result back in.

## `dm_keyed_tbl` — the loose-table alternative

Instead of zooming one table at a time, pull them all out as key-carrying tibbles, work in plain dplyr, and reassemble:

```r
tbls <- dm_get_tables(dm, keyed = TRUE)
# or: dm_deconstruct(dm)   # emits the assignment code for every table
flights2 <- tbls$flights |> mutate(before_noon = dep_time < 1200)
dm(flights = flights2, planes = tbls$planes)   # keys that could be tracked survive
```

`dm_keyed_tbl` inherits from `tbl`/`tbl_lazy`, so most dplyr and tidyr verbs work untouched and joins use the tracked keys. Reach for it over zooming when the work spans several tables at once or ends in a loose analysis table rather than a `dm`.
