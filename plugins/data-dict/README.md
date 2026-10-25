# data-dict plugin for Claude Code

Skills for working with [`data-dict.yaml`](https://data-dict.tidyverse.org) data dictionaries through the `data-dict` CLI.

| Skill | Use it to |
| - | - |
| `data-dict:setup` | Install, repair, or upgrade the CLI |
| `data-dict:create` | Document a Parquet dataset, or extend an existing dictionary |
| `data-dict:read` | Ground analysis code and queries in a dictionary |
| `data-dict:validate` | Check a dictionary against the spec and its data, and set up CI |

Claude picks the right skill from your request; you can also invoke one by name.

## Design

The CLI bundles its own agent instructions (`data-dict skill-create`, `data-dict skill-read`, `data-dict spec`), versioned with the binary. `create` and `read` load those at run time and add only what they leave out, so the plugin stays in step with whichever CLI release is installed. Nothing from the spec is copied into the plugin.

## Install

```bash
claude plugin marketplace add /path/to/data-dict-plugin
claude plugin install data-dict@data-dict-tools
```

The `setup` skill installs the CLI on first use if it's missing. Tested against data-dict 0.0.3.
