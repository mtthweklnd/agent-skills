---
name: r-openxlsx2
description: openxlsx2 for reading, writing, and styling .xlsx files from R. Use when code uses openxlsx2, when building native Excel pivot tables, slicers, or conditional formatting from R, or when migrating from openxlsx.
---

# openxlsx2

Successor to {openxlsx}; unlike it, openxlsx2 creates **native Excel pivot tables, slicers, and timelines**. Look up any signature with `args(openxlsx2::fn)` or `?fn`; this skill holds only what those lookups don't tell you.

| Task | File |
|---|---|
| Fonts, fills, borders, number formats, table styles, rich text | `references/styling.md` |
| Conditional formatting rules, color scales, data bars, top-N | `references/conditional-formatting.md` |
| Pivot tables, slicers, timelines | `references/pivot-tables.md` |
| Formulas, structured table references | `references/formulas.md` |
| Charts and images | `references/charts.md` |
| Reading a sheet into a data frame | `references/read-to-df.md` |
| Porting {openxlsx} code | `references/update-from-openxlsx.md` |

## Core pattern

```r
library(openxlsx2)
wb <- wb_workbook() |>
  wb_add_worksheet("data") |>
  wb_add_data(x = mtcars) |>
  wb_add_font(dims = wb_dims(x = mtcars, select = "col_names"), bold = TRUE) |>
  wb_set_col_widths(cols = 1:11, widths = "auto") |>
  wb_freeze_pane(first_row = TRUE)
wb_save(wb, "out.xlsx")
```

Two equivalent styles: `wb_*()` wrappers return a copy and **must be reassigned**; `wb$method()` (R6, no `wb_` prefix, no `wb` argument) modifies in place. A wrapper call left unassigned is silently lost, and the next call fails with "no worksheet". `sheet` defaults to the most recently added worksheet.

## Addressing with `wb_dims()`

Build every data-sized range with `wb_dims()`, so ranges track the data instead of hand-typed A1 strings.

```r
wb_dims(x = mtcars)                        # "A1:K33"  data plus header
wb_dims(x = mtcars, select = "data")       # "A2:K33"
wb_dims(x = mtcars, select = "col_names")  # "A1:K1"
wb_dims(x = mtcars, cols = "cyl")          # "B2:B33"  column by name
wb_dims(rows = 4:10, cols = 5:9)           # "E4:I10"
wb_dims(x = mtcars, from_col = "B", from_row = 2)   # offset origin
```

When data is written at an offset, pass the same `from_col`/`from_row` to every `wb_dims()` call that styles it.

With `x`, `rows` counts **data rows** (`wb_dims(x = df, rows = 2)` is sheet row 3) and takes positive integers only; wrap a condition in `which()`. A vector `x` has no header row.

## Writing data

- `wb_add_data()` styles by R class: Date, POSIXct, logical, and the classes `"currency"`, `"accounting"`, `"percentage"`, `"scientific"`, `"hyperlink"`, `"formula"`. Set the class on a column to get the format.
- `NA` is written as the error `#N/A` by default, and a formula reading such a cell returns `#N/A`. Pass `na = NULL` for truly blank cells; `na = ""` writes empty *text*, even in numeric columns, so `ISBLANK()` is FALSE.
- Strings starting with `<r>` or `<r/>` must be wrapped in `fmt_txt()`.
- `wb_add_data_table()` makes an Excel table. `table_name` must be unique per workbook and must not parse as a cell address (`t1`, `tbl1`, `ab12` all error); a `tbl_` prefix is safe. `total_row = c(text = "Total", "none", "sum")` labels the row and sets one function per column.
- Datetimes are stored without timezone.
- A `"hyperlink"`-class vector uses its `names()` as display text. For links to another sheet, write `create_hyperlink(sheet =, row =, col =, text =)` (a `HYPERLINK()` formula) with `wb_add_formula()`.
- `wb_add_data_validation(type = "list")`: an inline list needs embedded quotes, `value = '"A,B,C"'`; a named range is passed bare, `value = "lst_regions"`.

## Gotchas

- Formulas and pivot tables are written as instructions, not values: their cells stay empty until the file is opened in Excel.
- Conditional formatting and custom table styles take dxfs styles registered by name, never cell styles. See `references/conditional-formatting.md`.
- `wb_load()` keeps existing styles, but loaded pivot tables cannot be modified.
- `wb_save()` overwrites by default; pass `overwrite = FALSE` to refuse.
- Excel "We found a problem with some content" / *Removed Records: Formula from /xl/worksheets/sheetN.xml*: a common cause is an unprefixed modern function (see `references/formulas.md`). `sheetN` is creation order, not tab order. Unzip the file and search that sheet's `<f>` elements.

## Verifying output without Excel

LibreOffice recalculates on conversion, so formula and pivot values can be checked from R:

```sh
soffice --headless -env:UserInstallation=file:///tmp/lo-profile --convert-to xlsx --outdir /tmp/recalc out.xlsx
```

Then `wb_to_df("/tmp/recalc/out.xlsx", sheet =)` returns computed values. LibreOffice before 24.8 shows `#NAME?` for dynamic-array functions (`SORT`, `UNIQUE`, `FILTER`) that Excel 365 evaluates; it does not flag a missing `_xlfn.` prefix, so Excel remains the final check.
