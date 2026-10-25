---
name: validate
description: Validate a data-dict.yaml against the spec and its data, triage the findings, and set validation up in CI. Use when asked to validate or check data against a data dictionary, after editing a data-dict.yaml, or when a validation report needs explaining.
---

# Validate a data dictionary

## Levels

Each level implies the ones before it, and a run stops at the first level with errors.

| Level | Command | Reads | Cost |
| - | - | - | - |
| spec | `data-dict validate-spec` | the YAML only | free |
| meta | `data-dict validate-meta` | Parquet footers | cheap |
| data | `data-dict validate-data` | every value | grows with the data |

All three take a dictionary file or directory (default: current directory). `meta` and `data` also take `--table <name>`. Exit code is `1` on any error and `0` on warnings only.

## Steps

1. **Run the levels in order** and stop at the first that reports errors. If `data-dict` is missing or fails, run the `setup` skill first. Write each report as JSON to a scratch file:

   ```bash
   data-dict validate-spec --json > spec.json
   jq '{status, problems: [.problems[] | {code, severity, table, columns, message, expected, hint, rows, count, values, redacted}]}' spec.json
   ```

   Failed and unevaluated steps: `jq '.steps[] | select(.outcome != "pass")'`.

   If the command prints `no report written`, the file isn't parseable YAML: fix the syntax error it names and rerun.

2. **Triage each problem by its code prefix.** The prefix says which side is wrong:

   - **`S##` or `Q-…`: the dictionary is wrong.** `Q-` codes are YAML-level problems such as duplicate keys. Fix the YAML yourself. When a problem has a `suggestion`, splice its `replacement` at its `location` (0-based line and column). `S31` is an unresolved `todo`: resolve it with the `create` skill or leave it for the user.
   - **`M##`: the schema has drifted.** Ask the user which side is right.
     - `M01` type mismatch or `M02` missing column: did the data change upstream, or is the dictionary wrong?
     - `M03` extra column: propose a column entry from `data-dict describe <file> <column>` and confirm its meaning.
     - `M04` or `M05`: fix the `source` path if it's a typo; otherwise ask.
   - **`D##`: the data breaks a claim.** Report it as a finding: code, table, columns, `count` (exact), `rows` (1-based Parquet row numbers, capped at the first 5), and `values`. Edit the dictionary only when the user confirms the claim itself was wrong; loosening a constraint to pass hides a data bug. `D03`, `D06`, and `D08` mean the check could not run (see `reason`), so treat the step as unevaluated, not passed.

3. **Keep redaction intact.** A problem on a restricted column has `redacted: true`: it keeps `rows` but drops `values`. Report the rows and leave the values unread.

4. **Human-readable report, if asked.** Add `--html report.html` to any level.

For CI setup, read [`references/ci.md`](references/ci.md).

## Done

Every problem is fixed or listed for the user with the decision it needs, and `validate-spec` reports zero errors.
