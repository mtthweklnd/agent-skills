# agent-skills

Skills and plugins for coding agents.

## Skills

Standalone skills in [`skills/`](skills/):

| Skill | Use it to |
| - | - |
| [`r-dm`](skills/r-dm/SKILL.md) | Build, query, validate, and diagram relational data models in R with [{dm}](https://dm.cynkra.com/) |
| [`r-S7`](skills/r-S7/SKILL.md) | Define S7 classes, properties, generics, and methods in R with [{S7}](https://rconsortium.github.io/S7/) |
| [`solutions-advisor`](skills/solutions-advisor/SKILL.md) | Evaluate technical and architecture options with weighted criteria, trade-offs, and a clear recommendation |

### Install

Install with the [`skills` CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add mtthweklnd/agent-skills
```

Or copy a skill folder directly into your project's `.claude/skills/` or `.agents/skills/` directory.

## Plugins

Multi-skill plugins in [`plugins/`](plugins/):

| Plugin | Description |
| - | - |
| [`data-dict`](plugins/data-dict/README.md) | Create, read, and validate [`data-dict.yaml`](https://data-dict.tidyverse.org) data dictionaries (`setup`, `create`, `read`, `validate`) |

See each plugin's `README.md` for installation and usage details.

