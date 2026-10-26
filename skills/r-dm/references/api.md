# {dm} function reference (v1.1.2)

Signatures with defaults, grouped by job. `*` = experimental.

## Naming grammar

The names are systematic, so a guessed name is usually right — and a wrong guess is usually a class error.

| Prefix | Meaning |
|---|---|
| `dm_` | takes a `dm` first, or builds one |
| `check_` | throws on failure, returns its first argument invisibly on success |
| `examine_` | returns a tibble describing the results instead of throwing |
| `dm_add_` / `dm_rm_` | add or remove keys or tables |
| `dm_get_` | retrieve metadata |

| Suffix | Meaning |
|---|---|
| `_dm` | validator, checker or coercer |
| `_to_tbl` | returns a tibble, not a `dm` |
| `_tbl` | acts on a whole table within a `dm` |
| `_candidates` | returns candidate keys as a tibble |
| `_pk(s)` / `_fk(s)` / `_uk(s)` | primary / foreign / unique keys |
| `_zoomed` | first argument is a `dm_zoomed` |
| `_colors` | diagram colours |

No function accepts both a `dm` and a `dm_zoomed`. A zoomed `dm` behaves like a table and takes dplyr verbs instead of `dm_*` functions.

## Construct

```r
dm(..., .name_repair = c("check_unique", "unique", "universal", "minimal"), .quiet = FALSE)
as_dm(x, ...)            # named list of tables -> dm
is_dm(x); new_dm(tables = list())
dm_from_con(con = NULL, table_names = NULL, learn_keys = NULL, .names = NULL, ...)  # ... takes schema=
dm_get_con(dm)                       # errors unless tables are on a DB
dm_get_tables(x, ..., keyed = FALSE) # named list of tbls
dm_nrow(dm)                          # named vector of row counts
dm_ptype(dm)                         # same keys, zero rows
dm_validate(x)                       # internal consistency of the dm object itself
glimpse(x, width = NULL, ...)        # dims, types, keys, per table
```

## Keys

```r
dm_add_pk(dm, table, columns, ..., autoincrement = FALSE, check = FALSE, force = FALSE)
dm_add_uk(dm, table, columns, ..., check = FALSE)
dm_add_fk(dm, table, columns, ref_table, ref_columns = NULL, ...,
          check = FALSE, on_delete = c("no_action", "cascade"))
dm_rm_pk(dm, table = NULL, columns = NULL, ..., fail_fk = NULL)
dm_rm_uk(dm, table = NULL, columns = NULL, ...)
dm_rm_fk(dm, table = NULL, columns = NULL, ref_table = NULL, ref_columns = NULL, ...)

dm_enum_pk_candidates(dm, table)                 # * columns that are unique
dm_enum_fk_candidates(dm, table, ref_table)      # * columns that could reference ref_table's PK
dm_get_all_pks(dm, table = NULL, ...)
dm_get_all_uks(dm, table = NULL, ...)            # includes implicit UKs
dm_get_all_fks(dm, parent_table = NULL, ...)
dm_has_pk(dm, table, ...)
```

Compound keys: `columns = c(col1, col2)`. `ref_columns` defaults to `ref_table`'s PK. An FK pointing at non-key columns creates an *implicit unique key*, visible only through `dm_get_all_uks()` — it arises when an FK is added with no PK/UK in the parent, or when the PK/UK is removed without removing the FK first.

## Validate

```r
dm_examine_constraints(.dm, ..., .progress = NA, .max_value = 6L)  # tibble: is_key TRUE/FALSE per constraint
dm_examine_cardinalities(.dm, ..., .progress = NA)                 # * 0_n / 1_n / 0_1 / 1_1 per FK
```

Standalone checks on plain data frames, outside any `dm`. Each throws on failure and returns `x` invisibly on success, so they chain in a pipe:

```r
check_key(x, ...)                                        # named columns are a unique key of x
check_subset(x, y, ..., x_select = NULL, y_select = NULL, by_position = NULL)
check_set_equality(x, y, ..., x_select = NULL, y_select = NULL, by_position = NULL)
check_cardinality_0_n(x, y, ...)   # same args as check_subset for all five
check_cardinality_1_n(x, y, ...)
check_cardinality_0_1(x, y, ...)
check_cardinality_1_1(x, y, ...)
examine_cardinality(x, y, ...)     # returns a description instead of throwing
```

`x` is the parent (key side), `y` the child. All four `check_cardinality_*()` require `x`'s rows to be unique and determine the rest from how `y`'s values map onto them.

## Filter and query

```r
dm_filter(.dm, ...)                 # named exprs: dm_filter(dm, tbl = (expr), tbl2 = (expr))
dm_flatten_to_tbl(dm, .start, ..., .recursive = FALSE, .join = left_join)
dm_flatten(dm, table, ..., parent_tables = NULL, recursive = FALSE,
           allow_deep = FALSE, join = left_join)   # * joins parents in place, drops them from the dm
dm_disambiguate_cols(dm, .sep = ".", ..., .quiet = FALSE, .position = c("suffix", "prefix"))
pull_tbl(dm, table, ..., keyed = FALSE)
dm$table                            # same as pull_tbl()
```

`.join` accepts `left_join`, `inner_join`, `full_join`, `right_join`, `semi_join`, `anti_join`. `.recursive = TRUE` follows FKs beyond direct parents.

## Zoom

```r
dm_zoom_to(dm, table)
dm_update_zoomed(dm)                # overwrite the original table
dm_insert_zoomed(dm, new_tbl_name = NULL, repair = "unique", quiet = FALSE)
dm_discard_zoomed(dm)
pull_tbl(dm)                         # while zoomed: the zoomed table itself
```

While zoomed, call `dplyr` and `tidyr` verbs directly on the `dm` — unsuffixed, with their usual signatures: `filter`, `filter_out`, `mutate`, `transmute`, `select`, `relocate`, `rename`, `distinct`, `arrange`, `slice`, `group_by`, `ungroup`, `summarise`, `reframe`, `count`, `tally`, `pull`, `compute`, `head`, `tail`, `unite`, `separate`, and the joins `left_join`, `inner_join`, `full_join`, `right_join`, `semi_join`, `anti_join`, `nest_join`, `cross_join`. Joins on a zoomed table take an extra `select = NULL` for picking columns from the other table. `slice()` takes `.keep_pk = NULL`.

`dm_keyed_tbl` is the alternative to zooming: the same verb set (minus `pull`, `compute`, `nest_join`) on a loose table that still carries its keys.

```r
pull_tbl(dm, table, keyed = TRUE)   # a dm_keyed_tbl
dm_deconstruct(dm, dm_name = NULL)  # * emits code assigning every table as a keyed tbl
dm(...)                             # reassemble keyed tbls, keys intact
```

## Tables and columns

```r
dm_select_tbl(dm, ...)               # keep/reorder/rename tables, relationships preserved
dm_rename_tbl(dm, ...)
dm_select(dm, table, ...)            # dplyr::select on one table's columns
dm_rename(dm, table, ...)
dm_mutate_tbl(dm, ...)               # * replace table data, identical column names required
```

## Normalize and reshape

```r
decompose_table(.data, new_id_column, ...)       # * -> list(child_table, parent_table)
reunite_parent_child(child_table, parent_table, id_column)        # * inverse
reunite_parent_child_from_list(list_of_parent_child_tables, id_column)

dm_wrap_tbl(dm, root, strict = TRUE, progress = NA)   # * collapse whole dm into one nested table
dm_unwrap_tbl(dm, ptype, progress = NA)               # * inverse, guided by a ptype dm
dm_nest_tbl(dm, child_table, into = NULL)             # * child -> nested column in parent
dm_unnest_tbl(dm, parent_table, col, ptype)           # * inverse
dm_pack_tbl(dm, parent_table, into = NULL)            # * parent -> packed column in child
dm_unpack_tbl(dm, child_table, col, ptype)            # * inverse
```

`dm_nest_tbl()` needs a leaf child; `dm_pack_tbl()` needs a root parent. Pass a ptype or a set of keys to the inverses, not both.

JSON-column variants, for round-tripping nested data through a database:

```r
json_nest(.data, ..., .names_sep = NULL)
json_unnest(data, cols, ..., names_sep = NULL, names_repair = "check_unique")
json_pack(.data, ..., .names_sep = NULL)
json_unpack(data, cols, ..., names_sep = NULL, names_repair = "check_unique")
pack_join(x, y, by = NULL, ..., copy = FALSE, keep = FALSE, name = NULL)  # * packed matches from y
json_nest_join(x, y, by = NULL, ..., copy = FALSE, keep = FALSE, name = NULL)   # *
json_pack_join(x, y, by = NULL, ..., copy = FALSE, keep = FALSE, name = NULL)   # *
```

## Draw

```r
dm_draw(dm, rankdir = "LR", ..., col_attr = NULL,
        view_type = c("keys_only", "all", "title_only"),
        column_types = NULL, backend = c("DiagrammeR"), backend_opts = list())
dm_set_colors(dm, ...)               # colour = c(tbl1, tbl2) or "#hex" = c(...)
dm_get_colors(dm); dm_get_available_colors()
dm_set_table_description(dm, ...)    # shown by dm_draw()
dm_get_table_description(dm, table = NULL, ...); dm_reset_table_description(dm, table = NULL, ...)
```

`dm_draw()` is the only argument-heavy function with a long tail of deprecated arguments (`columnArrows`, `graph_attrs`, `node_attrs`, `edge_attrs`, `focus`, `graph_name`, `font_size`) — use the current six.

## Database

```r
copy_dm_to(dest, dm, ..., set_key_constraints = TRUE, table_names = NULL,
           temporary = TRUE, schema = NULL, progress = NA)
compute(dm, ..., temporary = TRUE)   # materialize as new DB tables
collect(dm, ..., progress = NA)      # download as local tibbles

dm_sql(dm, dest, table_names = NULL, temporary = TRUE)   # * full script
dm_ddl_pre(dm, dest, ...); dm_dml_load(dm, dest, ...); dm_ddl_post(dm, dest, ...)   # * its three phases

db_schema_create(con, schema, ...)                       # *
db_schema_drop(con, schema, force = FALSE, ...)          # *
db_schema_exists(con, schema, ...); db_schema_list(con, include_default = TRUE, ...)  # *
```

## Row modification

```r
dm_rows_insert(x, y, ..., in_place = NULL, progress = NA)   # * new rows, PK must not exist
dm_rows_append(x, y, ...)                                   # * new rows, no key check
dm_rows_update(x, y, ...)                                   # * overwrite matched rows
dm_rows_patch(x, y, ...)                                    # * fill only NAs in matched rows
dm_rows_upsert(x, y, ...)                                   # * update matched, insert the rest
dm_rows_delete(x, y, ...)                                   # * delete matched rows
```

`x` is the target `dm`, `y` a `dm` of the same shape holding the changes. `in_place = TRUE` writes to the database; `FALSE` returns a new `dm` and leaves the source untouched.

## Code generation and examples

```r
dm_paste(dm, select = NULL, ..., tab_width = 2, options = NULL, path = NULL)
dm_nycflights13(..., cycle = FALSE, color = TRUE, subset = TRUE,
                compound = TRUE, table_description = FALSE)
dm_pixarfilms(..., color = TRUE, consistent = FALSE, version = "v1")
dm_financial(); dm_financial_sqlite()   # remote DB, connection made once per session
dm_gui(..., dm = NULL, select_tables = TRUE, debug = FALSE)   # * Shiny app for building a dm
```

`dm_paste()` prints the code that recreates a `dm` — the fastest way to hand a model to a script or a test.

## Superseded names

Current call for each name the package no longer wants:

| Old | Current |
|---|---|
| `cdm_*` (any) | the same name with `dm_` |
| `dm_apply_filters()`, `dm_apply_filters_to_tbl()`, `dm_get_filters()` | nothing — `dm_filter()` applies immediately |
| `dm_filter(dm, table, expr)` | `dm_filter(dm, table = (expr))` |
| `dm_join_to_tbl()` | `dm_flatten_to_tbl()` or `dm_zoom_to()` + a join |
| `dm_squash_to_tbl()` | `dm_flatten_to_tbl(.recursive = TRUE)` |
| `dm_from_src()` | `dm_from_con()` |
| `dm_get_pk()`, `dm_has_fk()`, `dm_get_fk()` | `dm_get_all_pks()`, `dm_get_all_fks()` |
| `dm_add_tbl()`, `dm_rm_tbl()`, `dm_bind()` | `dm()` with the tables you want |
| `validate_dm()` | `dm_validate()` |
| `sql_schema_*()` | `db_schema_*()` |
| `dm_rows_truncate()`, `rows_truncate()` | `dm_rows_delete()` |
| `check_if_subset()`, `check_cardinality()` | `check_subset()`, `check_cardinality_*()` |
| `dm_is_referenced()`, `dm_get_referencing_tables()` | `dm_get_all_fks()` |
| `dm_get_src()`, `src_tbls()` | `dm_get_con()`, `dm_get_tables()` |
