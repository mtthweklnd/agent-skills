# Validation in CI

Run validation as its own job. The exit code is `1` on any error and `0` on warnings only, so unresolved `todo`s and undocumented columns don't fail the build.

Pin the CLI version: the spec is pre-1.0 and releases rename subcommands.

## GitHub Actions

```yaml
name: data-dict
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v6
      - name: Validate dictionary and data
        run: |
          uvx --from data-dict-yaml==0.0.3 data-dict validate-spec
          uvx --from data-dict-yaml==0.0.3 data-dict validate-data --html data-dict-report.html
      - name: Upload report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: data-dict-report
          path: data-dict-report.html
```

`validate-data` implies the spec and meta levels, so the separate `validate-spec` step only makes a broken YAML fail fast with a clearer log.

Archiving the report is safe for restricted columns: their values are withheld from reports and diagnostics.

## Adapting it

- **Data not in the repo.** `validate-data` needs every table's `source` file to exist. If the data lives elsewhere, either fetch it in an earlier step or run `validate-spec` alone in CI.
- **Large data.** Use `validate-meta` on every push and `validate-data` on a schedule.
- **One table.** Add `--table <name>`.
