---
name: setup
description: Install, repair, or upgrade the data-dict CLI. Use when a `data-dict` command is not found, fails with "Permission denied", or another data-dict skill needs the CLI checked.
---

# Set up the data-dict CLI

Every other data-dict skill drives this CLI, so it has to be installed, executable, and recent enough.

## Steps

1. **Check.** Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/setup/scripts/check-cli.sh"
   ```

   It prints `key: value` lines and exits with the status. Branch on the exit code:

   | Exit | `status` | Go to |
   | - | - | - |
   | 0 | `ok` | step 5 |
   | 1 | `missing` | step 2 |
   | 2 | `too-old` | step 3 |
   | 3 | `not-executable` | step 4 |

2. **Install.** Use the first installer the machine has, and tell the user which one you chose:

   - `uv tool install data-dict-yaml`
   - `pipx install data-dict-yaml`
   - From R: `pak::pak("tidyverse/data-dict/r")`, then `datadict::dd_install()`. The binary lands in R's user cache, off `PATH`; the check script finds it there and prints `on_path: no`, so call it by that full `path`.
   - None of these: the install script, `curl --proto '=https' --tlsv1.2 -LsSf https://github.com/tidyverse/data-dict/releases/latest/download/data-dict-cli-installer.sh | sh` (PowerShell on Windows: see <https://data-dict.tidyverse.org/install.html>). Ask before piping a script into the shell.

   Then go back to step 1.

3. **Upgrade** with the installer that owns the printed `path`: `uv tool upgrade data-dict-yaml`, `pipx upgrade data-dict-yaml`, `datadict::dd_install()` again, or the install script again for `~/.cargo/bin`. Back to step 1.

4. **Repair.** The PyPI wheel can install the binary without its execute bit. Run `chmod +x` on the printed `path`, then back to step 1.

5. **Record the command list.** The `commands:` block is this release's subcommands. Use those names, since they move between releases: 0.0.3 has `render` and `validate-* --html`, where the docs site describes the newer `render-spec` and `render-report`.

Done when the check script exits 0.
