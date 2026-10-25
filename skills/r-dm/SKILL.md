---
name: r-dm
description: Use when code loads or uses dm (library(dm), dm::), building relational data models in R, managing primary/foreign keys (PK/FK) across multiple data frames or tibbles, replacing manual left_join chains via dm_flatten_to_tbl() or dm_zoom_to(), cascading relational filters with dm_filter(), validating constraints with dm_examine_constraints(), drawing ER diagrams with dm_draw(), normalizing tables with decompose_table(), or syncing multi-table models with DBI databases via dm_from_con() and copy_dm_to().
---

# Relational Data Models in R with {dm}

Read `references/API.md` before writing code. Run `library(dplyr)` before `library(dm)`.

## Core Workflow

1. **Construct**: `dm(t1, t2)`, `as_dm(named_list)`, or `dm_from_con(con, learn_keys = TRUE)`.
2. **Keys**: Discover via `dm_enum_pk_candidates()` / `dm_enum_fk_candidates()`. Add via `dm_add_pk()`, `dm_add_uk()`, `dm_add_fk()` (`columns = c(a, b)` for compound keys).
3. **Validate**: `dm_examine_constraints()` checks uniqueness/referential integrity; `dm_examine_cardinalities()` checks `0_n`, `1_n`, `0_1`, `1_1` mappings.
4. **Query & Transform**:
   - **Cascade filter**: `dm_filter(dm, parent = (status == "active"))` filters `parent` and semi-joins connected child tables immediately.
   - **Zoom & mutate**: `dm_zoom_to(dm, tbl)` enables `dplyr` verbs (`mutate`, `summarize`, `left_join`, `filter`) while tracking keys. Exit via `dm_update_zoomed()`, `dm_insert_zoomed("new_tbl")`, or `dm_discard_zoomed()`.
   - **Flatten**: `dm_flatten_to_tbl(dm, .start = fact_tbl, .recursive = TRUE)` joins dimension tables into `.start` along FKs.
   - **Extract**: `pull_tbl(dm, tbl)` or `dm$tbl`.

## Quick Reference (`no mark`=req, `(opt)`=optional, `(adv)`=advanced)

|Function|Parameters|Purpose|
|---|---|---|
|`dm()` / `as_dm()`|`...`, `.name_repair`(opt), `.quiet`(adv) / `x`|Build `dm` from tables/list|
|`dm_from_con()`|`con`, `table_names`(opt), `learn_keys`(opt), `.names`(adv), `...`(adv:`schema`)|Load `dm` from DBI connection|
|`dm_add_pk()`/`uk()`|`dm`, `table`, `columns`, `autoincrement`(opt,pk), `check`(opt), `force`(adv,pk)|Define primary or unique key|
|`dm_add_fk()`|`dm`, `table`, `columns`, `ref_table`, `ref_columns`(opt), `check`(opt), `on_delete`(adv)|Define foreign key (defaults to `ref_table` PK)|
|`dm_enum_pk_candidates()`|`dm`, `table`|List candidate PK columns|
|`dm_enum_fk_candidates()`|`dm`, `table`, `ref_table`|List candidate FK columns referencing `ref_table`|
|`dm_examine_constraints()`|`.dm`, `.progress`(opt), `.max_value`(adv)|Tibble of PK/UK/FK constraint checks|
|`dm_examine_cardinalities()`|`.dm`, `.progress`(opt)|Inspect FK cardinalities|
|`dm_get_all_pks()`/`fks()`|`dm`, `table`/`parent_table`(opt)|Retrieve defined PKs/FKs|
|`dm_filter()`|`.dm`, `...` (`tbl = (expr)`)|Cascade filter across FK-linked tables|
|`dm_zoom_to()`|`dm`, `table`|Focus on `table` for `dplyr` verbs|
|`dm_update_zoomed()`|`dm`|Overwrite original table with zoomed table|
|`dm_insert_zoomed()`|`dm`, `new_tbl_name`(opt), `repair`(adv), `quiet`(adv)|Save zoomed table as new table|
|`dm_flatten_to_tbl()`|`dm`, `.start`, `...`(opt:tables), `.recursive`(opt), `.join`(opt)|Join direct (`.recursive=TRUE` for nested) parents|
|`pull_tbl()`|`dm`, `table`, `keyed`(adv)|Extract single table|
|`copy_dm_to()`|`dest`, `dm`, `set_key_constraints`(opt), `table_names`(opt), `temporary`(opt), `schema`(adv), `progress`(opt)|Deploy `dm` to DBI database|
|`collect.dm()`|`x`, `progress`(opt)|Materialize lazy DB `dm` locally|
|`dm_rows_insert()`/`upsert()`|`x`, `y`, `in_place`(opt), `progress`(opt)|Modify rows (`insert`,`update`,`patch`,`upsert`,`delete`)|
|`dm_draw()`|`dm`, `rankdir`(opt), `col_attr`(opt), `view_type`(opt:`"keys_only"`,`"all"`,`"title_only"`), `column_types`(opt)|Render ER diagram|
|`decompose_table()`|`.data`, `new_id_column`, `...` (cols)|Split flat table into `list(child_table, parent_table)`|
|`dm_paste()`|`dm`, `select`(opt), `tab_width`(adv), `options`(opt), `path`(opt)|Emit R code to recreate `dm`|

## Pitfalls & Edge Cases

- **`dm_filter()` syntax**: Pass named expressions `dm_filter(my_dm, orders = (year == 2024))`. Never use deprecated `dm_filter(dm, table, expr)` or `dm_apply_filters()`.
- **Exiting zoom**: Always finish `dm_zoom_to()` with `dm_update_zoomed()`, `dm_insert_zoomed()`, or `dm_discard_zoomed()` before calling `dm_*` functions or `pull_tbl()`.
- **Cycles/parallel FKs in `dm_flatten_to_tbl()`**: Multiple FK paths between tables (e.g., `flights -> airports` via `origin` and `dest`) error; specify tables in `...`, remove one FK with `dm_rm_fk()`, or join via `dm_zoom_to()`.
- **DB persistence**: `copy_dm_to()` defaults to `temporary = TRUE`; use `temporary = FALSE` to persist tables and `in_place = TRUE` in `dm_rows_*()` to persist row modifications.
