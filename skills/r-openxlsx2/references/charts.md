# Charts and images

| Goal | Function |
|---|---|
| Native, editable Excel chart | `wb_add_mschart(dims =, graph =)` with an {mschart} `ms_*chart()` |
| R / ggplot2 plot as image | `png(f, width =, height =, units = "in", res =)`, draw, `dev.off()`, then `wb_add_image(file = f)` |
| Image file | `wb_add_image(file =, dims =)` |
| Chart on its own tab | `wb_add_chartsheet()` then `wb_add_mschart(graph =)` |

For a native chart that stays linked to sheet cells, build it from `wb_data()`, not from the raw data frame:

```r
wb <- wb_workbook()$add_worksheet()$add_data(x = df)
dat <- wb_data(wb, dims = wb_dims(x = df))
chart <- mschart::ms_barchart(dat, x = "region", y = "sales")
wb$add_mschart(dims = "F2:L18", graph = chart)
```

Passing a plain data frame to `ms_*chart()` makes openxlsx2 write a second copy of the data next to the chart.

`wb_add_plot()` copies the open device with `dev.copy()`; headless (Rscript, R 4.6.2 on Linux) that copy writes no file and it fails with `file.exists(fileName) is not TRUE`. Render to PNG yourself and use `wb_add_image()`, which works everywhere.

## Sparklines

`create_sparklines()` takes `dims` = source range and `sqref` = the single target cell; `sheet` is the source sheet. Build one per row and combine:

```r
sp <- lapply(4:7, \(r) create_sparklines("Summary", dims = wb_dims(rows = r, cols = 2:7),
  sqref = wb_dims(rows = r, cols = 9), markers = "1"))
wb <- wb |> wb_add_sparklines("Summary", sparklines = do.call(c, sp))
```

`type = "column"` or `"stacked"` for bar or win/loss sparklines; flag arguments (`markers`, `high`, `low`) take `"1"`.
