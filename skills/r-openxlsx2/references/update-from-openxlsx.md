# Porting from openxlsx

| openxlsx | openxlsx2 |
|---|---|
| `createWorkbook()` / `loadWorkbook()` / `saveWorkbook()` | `wb_workbook()` / `wb_load()` / `wb_save()` |
| `addWorksheet()` | `wb_add_worksheet()` |
| `writeData()` / `writeDataTable()` | `wb_add_data()` / `wb_add_data_table()` |
| `createStyle()` + `addStyle()` | `wb_add_font()`, `wb_add_fill()`, `wb_add_border()`, `wb_add_numfmt()`, `wb_add_cell_style()` (no style objects) |
| `conditionalFormatting()` | `wb_add_conditional_formatting()` with dxfs styles |
| `dataValidation()` | `wb_add_data_validation()` |
| `setColWidths()` | `wb_set_col_widths()` |
| `read.xlsx()` / `write.xlsx()` / `openXL()` | `read_xlsx()` / `write_xlsx()` / `wb_open()` |

- Arguments are snake_case (`col_names`, not `colNames`).
- Ranges are `dims` strings (from `wb_dims()`), not `cols`/`rows` pairs.
- openxlsx functions modify the workbook in place; openxlsx2 `wb_*()` wrappers return a copy that must be reassigned (or use `wb$method()`).
- `read_xlsx()` row names are spreadsheet row numbers, and error cells come back as text.
