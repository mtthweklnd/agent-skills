# Pivot tables, slicers, timelines

openxlsx2 writes pivot-table **instructions**, not values; cells stay empty until Excel evaluates them. openxlsx2 cannot check that the result opens, so verify against an independent calculation (dplyr, base R) and open the file in Excel.

## Workflow

1. Write the source data to a sheet.
2. `df <- wb_data(wb, sheet = "data")`: the `wb_data` object is the required `x`. Prefer a fixed range over whole-column `dims`.
3. `wb_add_pivot_table(wb, df, rows =, cols =, data =)`. By default it goes on a new sheet; a `sheet =` name must already exist. Leave the target region empty; writing into it causes warnings.
4. For slicers or timelines, name the table with `pivot_table =` and list every slicer column in `slicer =` (or the date column in `timeline =`) **at creation**; they cannot be added to a pivot later, or to one loaded with `wb_load()`.

## Arguments

| Argument | Meaning |
|---|---|
| `rows`, `cols`, `data` | row axis, column axis, aggregated value columns |
| `filter` | page-filter columns |
| `fun` | one per `data` column: `sum` (default), `average`, `count`, `counta`, `max`, `min`, `product`, `stdev`, `stdevp`, `var`, `varp` |
| `dims` | top-left anchor; default `"A3"` |
| `params` | `numfmts = c(formatCode = "#,##0")` (one per data column), `show_data_as = "percentOfRow"`, `table_style = "PivotStyleMedium28"`, `sort_item = list(col = levels)`, `choose = c(col = 'x > "25-34"')`, `compact`/`outline`, `row_grand_totals`/`col_grand_totals` |

Some `params` combinations crash Excel; test on a copy. Item matching is case-insensitive (`Berlin` = `BERLIN`).

## Examples

```r
wb <- wb_workbook()$add_worksheet("data")$add_data(x = mtcars)
df <- wb_data(wb, sheet = "data")

# Basic, one aggregation per data column
wb$add_pivot_table(df, rows = "cyl", cols = "gear",
  data = c("disp", "hp"), fun = c("sum", "average"))

# With slicer, placed on the pivot's sheet
wb$add_pivot_table(df, rows = "cyl", cols = "gear", data = "disp",
    pivot_table = "pt_mtcars", slicer = "vs")$
  add_slicer(x = df, dims = "H3:J10", slicer = "vs", pivot_table = "pt_mtcars",
    params = list(style = "SlicerStyleLight2"))

# Timeline on a date column
wb$add_pivot_table(df2, rows = "month", data = "sales",
    pivot_table = "pt_sales", timeline = "date")$
  add_timeline(x = df2, dims = "E3:I8", timeline = "date", pivot_table = "pt_sales",
    params = list(level = 2))   # 0 year, 1 quarter, 2 month
```

`wb_remove_slicer()` / `wb_remove_timeline()` remove **all** of them on the sheet.
