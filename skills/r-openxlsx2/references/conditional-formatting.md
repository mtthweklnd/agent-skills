# Conditional formatting

Styles are dxfs, registered by name first, then passed as `style = "name"`. Omitting `style` gives dark red on light red.

```r
wb$add_dxfs_style(name = "neg", font_color = wb_color(hex = "FF9C0006"), bg_fill = wb_color(hex = "FFFFC7CE"))
wb$add_dxfs_style(name = "pos", font_color = wb_color(hex = "FF006100"), bg_fill = wb_color(hex = "FFC6EFCE"))
```

| `type` | `rule` | `style` | `params` |
|---|---|---|---|
| `"expression"` (default) | formula or operator string (`">2"`, `"$A1<0"`) | dxfs name | none |
| `"colorScale"` | optional values, one per color | 2 or 3 colors | none |
| `"dataBar"` | optional `c(min, max)` | 1-2 colors | `showValue`, `gradient`, `border`, `axisPosition` |
| `"iconSet"` | none | none | `showValue`, `reverse`, `percent`, icon set |
| `"duplicatedValues"`, `"uniqueValues"`, `"containsErrors"`, `"containsBlanks"` (and `not*` forms) | none | dxfs name | none |
| `"containsText"`, `"notContainsText"`, `"beginsWith"`, `"endsWith"` | text to match | dxfs name | none |
| `"between"` | `c(lo, hi)`, inclusive | dxfs name | none |
| `"topN"`, `"bottomN"` | none | dxfs name | `rank`, `percent` |

```r
rng <- wb_dims(x = df, select = "data")

# Whole row highlighted from column A's value: $ pins the column, row floats
wb$add_conditional_formatting(dims = rng, rule = "$A2<0", style = "neg")

wb$add_conditional_formatting(dims = wb_dims(x = df, cols = "score"),
  type = "colorScale", style = c("white", "#63BE7B"))

wb$add_conditional_formatting(dims = wb_dims(x = df, cols = "score"),
  type = "topN", style = "pos", params = list(rank = 10, percent = TRUE))
```

- Expression references are relative to the **top-left cell of `dims`** and shift across the range like a filled-down formula. Write the rule for that first cell; use `$` to pin.
- Non-contiguous `dims` (`"A1:B2,D1:F2"`) form one rule anchored at the first block.
- Use `dims`; the `cols`/`rows` arguments are deprecated.
