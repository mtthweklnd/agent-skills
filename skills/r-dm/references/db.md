# {dm} against a database

## Learning a model from a connection

```r
dm <- dm_from_con(con, learn_keys = TRUE)
```

`learn_keys = TRUE` reads PKs and FKs from the catalog, and works only on Postgres, SQL Server and MariaDB — elsewhere it errors. Everywhere else, take the tables and declare the keys yourself:

```r
dm <- dm_from_con(con, learn_keys = FALSE) |>
  dm_add_pk(accounts, id) |>
  dm_add_fk(loans, account_id, accounts)
```

Restrict up front when the schema is wide: `dm_from_con(con, table_names = c("accounts", "loans"))`, or `dm_from_con(con, schema = "sales")` through the dots.

A `dm` from a connection is lazy — every table is a `tbl_lazy`, nothing is fetched until you ask. `dm_nrow()` on a remote `dm` queries the database.

## Getting data in and out

| Goal | Call |
|---|---|
| Whole local model onto the DB | `copy_dm_to(con, dm, temporary = FALSE)` |
| Whole remote model into memory | `collect(dm)` |
| Remote results into new DB tables | `compute(dm, temporary = FALSE)` |
| One local data frame onto a remote `dm` | `copy_to(dm, df, "name")` |
| One table out | `pull_tbl(dm, tbl) |> collect()` |

`copy_dm_to()` and `compute()` default to `temporary = TRUE`, so the tables vanish when the session ends. Pass `temporary = FALSE` to persist.

`copy_dm_to()` does not overwrite existing tables. Against a populated database, rename on the way in:

```r
copy_dm_to(con, dm, temporary = FALSE, table_names = ~ paste0("stg_", .x))
```

`table_names` takes a named character vector (`c(dm_name = "db_name")`), a function, or a one-sided formula. `remote_name(dm$tbl)` tells you which database table a `dm` table is actually backed by — the `dm` name and the DB name diverge as soon as you use `table_names`.

Both calls need write access; without it they error. Dropping tables is out of scope for `dm` — use `DBI`.

## Inspecting generated SQL

```r
dm |> dm_get_tables() |> purrr::map(dbplyr::sql_render)
dm_sql(dm, con)   # the full create/load/constrain script
```

## Schemas

`db_schema_create()`, `db_schema_drop(force = )`, `db_schema_exists()`, `db_schema_list()` — all experimental, all taking `con` first.

## Modifying rows

`dm_rows_*()` change data in tables that already exist; they never create tables. All six take the same arguments and follow the same three steps:

1. **Build a changeset `dm`** — same table names and shape as the target, holding only the rows to change.
2. **Copy it into the same source as the target.** A local changeset against a remote target will not work; `copy_dm_to(con, changes)` first.
3. **Dry run, then commit.** `in_place = FALSE` (the default) returns a new `dm` and leaves the database untouched; verify with `dm_nrow()` and `dm_examine_constraints()`, then repeat with `in_place = TRUE`.

```r
changes <- copy_dm_to(con, dm(parent = new_parents, child = new_children))

target |> dm_rows_insert(changes, in_place = FALSE) |> dm_examine_constraints()

DBI::dbWithTransaction(con, {
  dm_rows_insert(target, changes, in_place = TRUE)
})
```

Which method to reach for:

| Call | Behaviour on primary-key match |
|---|---|
| `dm_rows_insert()` | existing PKs silently ignored |
| `dm_rows_append()` | inserts everything; only a DB constraint will stop a duplicate |
| `dm_rows_update()` | PKs must all match; overwrites values |
| `dm_rows_patch()` | PKs must all match; fills `NA`s only |
| `dm_rows_upsert()` | updates matches, inserts the rest |
| `dm_rows_delete()` | PKs must all match; deletes them |

`dm` orders the tables for you — parents before children when creating rows, children before parents for `dm_rows_delete()` — but it opens no transaction. Wrap every `in_place = TRUE` write in one (`DBI::dbWithTransaction()`), because a failure part-way through a multi-table write otherwise leaves orphans behind.

`dm_examine_constraints()` counts a missing FK (`NA` in R, `NULL` in SQL) as a match, and `dm` neither sets nor checks `NOT NULL`. If a column must be populated, enforce it in the database, or gate the changeset before it reaches the transaction.
