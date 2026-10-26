---
name: r-dm
description: dm in R — relational data models over many tables. Use for library(dm)/dm::, declaring PK/UK/FK across tibbles or a DBI database, dm_filter() cascades, dm_flatten_to_tbl()/dm_zoom_to() in place of left_join chains, dm_examine_constraints(), dm_draw(), decompose_table() normalization, dm_from_con()/copy_dm_to() round-trips, dm_rows_* writes.
---

# Relational data models in R with {dm}

A `dm` is a list of tables plus the key metadata that relates them. Once the keys are declared, filtering, joining and validating happen across the whole model instead of table by table.

Read [`references/api.md`](references/api.md) before writing `dm` code — it carries every signature with its defaults, plus the naming grammar that makes a guessed function name usually right.

## Workflow

Attach `dplyr` before `dm`, since `dm` masks several dplyr generics.

1. **Construct.** `dm(t1, t2)` from loose tables, `as_dm(named_list)` from a list, `dm_from_con(con)` from a database.
2. **Declare keys.** Discover candidates with `dm_enum_pk_candidates(dm, tbl)` and `dm_enum_fk_candidates(dm, tbl, ref_tbl)`, then `dm_add_pk()`, `dm_add_uk()`, `dm_add_fk()`. Compound keys take `columns = c(a, b)`.
3. **Validate before relying on the model.** `dm_examine_constraints()` returns a row per constraint with `is_key` TRUE or FALSE; `dm_examine_cardinalities()` reports each FK as `0_n`, `1_n`, `0_1` or `1_1`. Every constraint accounted for before step 4 — a silently violated FK turns every later cascade and flatten into quietly wrong data.
4. **Query.** `dm_filter()` to subset the model, `dm_flatten_to_tbl()` to get one wide table, `dm_zoom_to()` to run dplyr verbs on one table in place, `pull_tbl(dm, tbl)` or `dm$tbl` to extract one.

Freeze a model you explored interactively with `dm_paste()`, which prints the code that rebuilds it.

## Pitfalls

- **`dm_filter()` takes named expressions**, one per table: `dm_filter(dm, orders = (year == 2024))`. The old positional form `dm_filter(dm, table, expr)` and the separate `dm_apply_filters()` step are both gone — filters apply on the spot.
- **Always leave a zoom by the front door.** `dm_update_zoomed()`, `dm_insert_zoomed("name")` or `dm_discard_zoomed()`, before any `dm_*` call or `pull_tbl(dm, tbl)`.
- **A `mutate()` over a key column drops the key**, by design. Re-add it after the manipulation.
- **Parallel FK paths break `dm_flatten_to_tbl()`.** Two routes between the same pair of tables (`flights -> airports` by `origin` and by `dest`) error out; name the tables you want in `...`, drop one FK with `dm_rm_fk()`, or join explicitly under a zoom.
- **Nothing persists by default.** `copy_dm_to()` and `compute()` default to `temporary = TRUE`; `dm_rows_*()` default to `in_place = FALSE`. Opt in explicitly, and wrap every real write in a transaction.
- **`learn_keys = TRUE` is Postgres, SQL Server and MariaDB only.** Elsewhere `dm_from_con()` errors — take the tables and declare the keys by hand.

## Reference

- [`references/api.md`](references/api.md) — every exported function: signature, defaults, naming grammar, and the current call for each superseded name (`cdm_*`, `dm_apply_filters()`, `dm_squash_to_tbl()`, …).
- [`references/db.md`](references/db.md) — a `dm` backed by a DBI connection: `dm_from_con()`, `copy_dm_to()`/`collect()`/`compute()`, `table_names` collisions, schemas, inspecting generated SQL, and the `dm_rows_*()` changeset process.
- [`references/query.md`](references/query.md) — how `dm_filter()` cascades and when it errors, `dm_flatten_to_tbl()` against `dm_zoom_to()` against `dm_keyed_tbl`, and the full zoomed verb set.
- [`references/model.md`](references/model.md) — `decompose_table()` normalization, `dm_wrap_tbl()`/`dm_nest_tbl()`/`dm_pack_tbl()` nesting, `dm_draw()` views and colours, `dm_paste()`.
