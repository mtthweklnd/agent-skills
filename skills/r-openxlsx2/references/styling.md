# Styling

## Cell-range helpers

```r
hdr <- wb_dims(x = mtcars, select = "col_names")
wb$add_fill(dims = hdr, color = wb_color("cyan2"))
wb$add_font(dims = hdr, name = "Arial", bold = TRUE, size = 12)
wb$add_cell_style(dims = hdr, horizontal = "center", wrap_text = TRUE)
wb$add_border(dims = hdr, bottom_border = "double",
              top_border = NULL, left_border = NULL, right_border = NULL)
wb$add_numfmt(dims = wb_dims(x = mtcars, cols = "disp"), numfmt = "#,##0.0")
```

- **Replace vs merge.** `wb_add_font()` and `wb_add_border()` replace the cell's existing font/border by default. To change only some properties, pass `update = c("color", "size")` (font) or `update = TRUE` (border). `update = NULL` clears.
- **Borders** treat `dims` as one block: `top_/left_/right_/bottom_*` draw the outer edge, `inner_hgrid`/`inner_vgrid` (with `inner_hcolor`/`inner_vcolor`) draw inside. A side set to `NULL` is left unset.
- **Colors** are ARGB (alpha first): `wb_color(hex = "FFFF0000")` is red. `wb_color("red")` takes R names; `wb_color(theme = 4, tint = 0.4)` takes theme colors.
- **Number formats**: `numfmt` is a built-in integer ID (1-4, 9-22, 37-40, 45-49) or a format-code string. Workbook-wide defaults: `options(openxlsx2.dateFormat =, openxlsx2.datetimeFormat =, openxlsx2.numFmt =)`.
- `wb_add_fill(every_nth_row = 2)` bands rows. `wb_set_col_widths(widths = "auto")` fits content.
- `locked`/`hidden` in `wb_add_cell_style()` only take effect after `wb_protect_worksheet()`. Input-form pattern: `wb_add_cell_style(dims = inputs, locked = FALSE)`, then protect the sheet.
- `wb_protect_worksheet(properties =)`: an unnamed vector lists actions to lock; a named logical vector sets each one, where `FALSE` means users may still do it (`c(formatColumns = FALSE, autoFilter = FALSE)`). Sheet and workbook (`wb_protect(lock_structure = TRUE)`) protection only deter edits; for confidentiality, encrypt with {msoc}.
- Hide gridlines with `wb_add_worksheet(grid_lines = FALSE)`.

## Copying styles

```r
s <- wb$get_cell_style(sheet = 1, dims = "A1:B2")
wb$set_cell_style(sheet = 2, dims = "A1:B2", style = s)   # source and target same shape
```

`wb_clone_sheet_style()` copies all styling between sheets.

## Rich text in one cell

```r
txt <- paste0(fmt_txt("bold ", bold = TRUE), fmt_txt("red", color = wb_color("red"), size = 14))
wb$add_data(x = txt)
```

`wb_add_font()` does not alter `fmt_txt()` runs.

## Custom table styles

Table styles are built from dxfs, referenced by ID:

```r
wb$add_style(create_dxfs_style(font_color = wb_color("white"), bg_fill = wb_color("navy"), text_bold = TRUE), "hdr")
wb$add_style(create_dxfs_style(bg_fill = wb_color("grey90")), "stripe")
wb$add_style(create_tablestyle(
  name = "myTable",
  header_row = wb$styles_mgr$get_dxf_id("hdr"),
  first_row_stripe = wb$styles_mgr$get_dxf_id("stripe")))
wb$add_data_table(x = mtcars, table_style = "myTable")
```

Built-in names: `TableStyleLight1`-`21`, `TableStyleMedium1`-`28`, `TableStyleDark1`-`11`.
