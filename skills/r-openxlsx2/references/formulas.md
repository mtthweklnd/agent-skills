# Formulas

Formulas are written as text, never evaluated. Reading back returns the cached value, which is stale or empty until Excel recalculates; `wb_to_df(show_formula = TRUE)` returns the formula text.

```r
wb$add_formula(x = "SUM(A2:B2)", dims = "D2")
wb$add_formula(x = "A2:A7 * B2:B7", dims = "C2:C7", array = TRUE)    # dims = full output range
```

A whole column of formulas: give a character column class `"formula"` and write it with `wb_add_data()` / `wb_add_data_table()`.

## The `x` vector

- `x` must be a plain character vector; a matrix (e.g. `t(v)` to make a row) errors with "x must be class character". A vector fills the `dims` range directly, column by column, so `dims = "B8:H8"` takes a row.
- Names on `x` define named formulas (`c(YESTERDAY = "_xlfn.LAMBDA(...)")`), so an accidentally named vector errors with "the condition has length > 1". `sapply()`/`vapply()` over a character vector add names: pass `USE.NAMES = FALSE` or `unname()`.

## Array and dynamic-array formulas

`array = TRUE` writes a legacy Ctrl+Shift+Enter array. `cm = TRUE` writes a dynamic array that spills (`UNIQUE`, `SORT`, `FILTER`, `SEQUENCE`); use it also when Excel inserts a stray `@` into a formula.

## Function prefixes

openxlsx2 writes formula text verbatim. Functions added in Excel 2010 or later must carry the file-format prefix Excel hides in its UI; without it the cell shows `#NAME?` or, for a `cm = TRUE` dynamic array (observed with `SORT(UNIQUE())`), Excel reports the file needs repair and deletes the formula:

| Excel | Write as |
|---|---|
| `UNIQUE`, `SEQUENCE`, `XLOOKUP`, `XMATCH`, `SORTBY`, `IFS`, `MAXIFS`, `MINIFS`, `SWITCH`, `TEXTJOIN`, `CONCAT`, `LET`, `LAMBDA`, `IFNA`, `STDEV.S` | `_xlfn.` + name |
| `SORT`, `FILTER` | `_xlfn._xlws.` + name |
| `LAMBDA`/`LET` parameters | `_xlpm.` + name |

```r
wb$add_formula(x = "_xlfn._xlws.SORT(_xlfn.UNIQUE(sales[rep]))", dims = "D2", cm = TRUE)
```

Pre-2010 functions (`SUMIFS`, `IFERROR`, `INDEX`, `MATCH`) need no prefix.

## Structured references to Excel tables

Excel's `[@col]` shorthand errors; supply the XML form for this-row references. Plain `table[col]` works as typed (confirmed in Excel and LibreOffice) and keeps working when rows are added, which makes it the right choice for summary formulas such as `SUMIFS(sales[revenue], sales[region], $A4)`.

| Excel | openxlsx2 |
|---|---|
| `[@price]` (inside table) | `sales[[#This Row],[price]]` |
| `sales[price]` (outside) | `sales[price]` or `sales[[#Data],[price]]` |
| header row | `sales[[#Headers],[price]:[qty]]` |

```r
wb$add_formula(x = "SUM(sales[[#Data],[price]] * sales[[#Data],[qty]])", dims = "B3", array = TRUE)
```
