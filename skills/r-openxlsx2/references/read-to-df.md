# Reading to a data frame

`read_xlsx()` and `wb_read()` wrap `wb_to_df(file_or_wb, sheet, ...)`. Defaults that surprise:

- Row names are the spreadsheet row numbers.
- `#N/A` becomes `NA` (the default `na = "#N/A"`); other error codes such as `#DIV/0!` come back as text. Add them to `na` as needed.
- Styled but empty cells (fills, merges, header styles copied to spare cells) extend the used range, adding all-`NA` columns. Pass `dims` to read only the data.
- Formula cells return the cached value (empty if the file was written by openxlsx2 and never opened in Excel).
- An empty range returns a data frame of the requested size.

Useful arguments: `dims` (or `rows`/`cols`), `start_row`, `col_names = FALSE`, `detect_dates = FALSE`, `convert = FALSE`, `skip_empty_rows`, `skip_empty_cols`, `types = c(id = 0, amount = 1, date = 2)` (0 character, 1 numeric, 2 date), `show_formula = TRUE`.
