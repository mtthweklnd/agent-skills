---
name: read
description: Use a data-dict.yaml as context before querying, analysing, or writing R, SQL, or Python against the data it describes. Use when a project contains a data-dict.yaml and the task touches its tables.
---

# Read a data dictionary

The CLI ships the authoritative reading procedure. This skill runs it, then swaps hand-parsing the YAML for the CLI's resolved outputs.

## Steps

1. **Load the procedure.** Run `data-dict skill-read` and follow it, including its orientation summary and its rules for `display: restricted` columns. If `data-dict` is missing or fails, run the `setup` skill first.

2. **Load the resolved model.** Run `data-dict export-spec --pretty`. It reads only the YAML and resolves what the file leaves implicit:
   - implied constraints (`primary_key` expands to `unique` and `required`)
   - `references` and `referenced_by` on every key column
   - `value_labels` for enums written as maps
   - relationships normalized to many-to-one, with column `pairs` and aliases resolved
   - each definition's `kind` (filter, metric, derived) and its `translations`

   For a large dictionary, slice it with `jq`, e.g. `jq '.tables[] | select(.name == "orders")'`.

3. **Check for drift.** Run `data-dict validate-meta`. It reads only Parquet footers, so it is cheap.
   - Errors: tell the user that code written against the dictionary may not match the data.
   - `M03` warnings: the data has columns the dictionary doesn't describe. Treat their meaning as unknown and ask.

4. **Reuse the dictionary's logic in code.**
   - **Metrics and filters.** When a table's `definitions` covers the concept, use that definition's translation from `export-spec` (`translations[]`, target `R(tidyverse)` or `SQL(duckdb)`) and name the definition in a code comment. Read its `notes`: they list the NA and NaN cases where the target language diverges.
   - **Assertions as row filters.** Run `data-dict translate --table <t> --target 'R(tidyverse)'`. A bare `--target R` yields base R. `translate` covers assertions only; definitions come from step 2.
   - **Units.** Carry `units` from `number(quantity)` columns into axis labels and column names.

## Done

Every column, join, and metric in the code traces to the dictionary, or is named to the user as undocumented.
