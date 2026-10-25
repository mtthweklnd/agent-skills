---
name: create
description: Create or extend a data-dict.yaml data dictionary for Parquet data. Use when asked to document a dataset, write or update a data dictionary, or add tables to an existing data-dict.yaml.
---

# Create a data dictionary

The CLI ships the authoritative creation procedure, versioned with the binary. This skill runs it and adds what it leaves out.

## Steps

1. **Load the procedure.** Run `data-dict skill-create` and `data-dict spec`. If `data-dict` is missing or fails, run the `setup` skill first. The printed skill is your procedure from here on; follow its steps with the amendments below.

2. **Scrub examples right after `draft`.** `draft` copies real values into `examples`, PII included (email addresses, names, IDs tied to people). Before any other edit, and before the file is shared or committed, find every column that identifies or could contact a person, mark it `display: restricted`, and replace its `examples` with plausible fakes. Ask the user about any column you can't classify.

3. **Interview one question per message.** Attach your best guess as the default answer ("`amount` looks like cents — confirm?") so the user can reply in a word. Record each open question as a `todo` on the exact node it concerns before you ask it, so an unanswered question survives the session.

4. **Extending an existing dictionary.** `draft` appends tables only for Parquet files the dictionary doesn't have yet, and keeps existing text byte for byte. Columns added to an already-documented table come from `validate-meta`'s `M03` warnings instead; add those entries by hand, using `data-dict describe <file> <column>` for type and examples.

5. **Validate by cost.** The procedure's final step runs `validate-data` repeatedly. Run `validate-spec` after each batch of edits, `validate-meta` once the tables are typed, and `validate-data` only at the end. Use the `validate` skill to triage what they report.

## Done

- `validate-spec` and `validate-data` report zero errors.
- Every remaining `S31` todo is one the user said they can't answer yet.

Close with a short report: tables documented, restricted columns, and the open todos with the question each one asks.
