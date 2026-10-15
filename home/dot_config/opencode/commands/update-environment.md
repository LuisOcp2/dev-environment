---
description: Report available environment updates. Never performs a major upgrade without explicit confirmation.
agent: build
---

Report which updates are available for the development environment, and how
each would be applied.

Focus: `$ARGUMENTS`

## Rules

- **Report, do not apply.** Do not run `chezmoi update`, `chezmoi apply`,
  `git pull`, `mise install`, `apt upgrade`, `npm update -g` or
  `opencode upgrade`. Describe each as a command Luis can run.
- **Never upgrade a major version** of anything without explicit confirmation,
  including language runtimes.
- **Never upgrade inside a project** when the question is about the global
  environment.

## Steps

1. **Repository state.**

   ```bash
   ./scripts/update.sh --check-only
   ```

   This reports the current commit, the upstream, and how many commits behind
   `main` the checkout is. It changes nothing.

2. **chezmoi state.** Report the configured source directory, whether it points
   at this repository or at a remote clone, and whether `chezmoi diff` shows
   pending changes. Use `chezmoi diff` and `chezmoi verify`, which are both
   read only.

3. **Tool versions.** Compare the installed versions against
   `config/defaults.env` (`MIN_GIT_VERSION`, `MIN_CHEZMOI_VERSION`,
   `MIN_MISE_VERSION`, `MIN_DOCKER_VERSION`) and report each tool that is
   below its minimum.

4. **Runtime versions.** Compare the versions installed by mise against the
   ones declared in `~/.config/mise/config.toml` and in any `mise.toml` in the
   working directory. Report differences, marking each as patch, minor or
   major.

5. **System packages.** Report upgradable packages without installing
   anything:

   ```bash
   apt list --upgradable
   ```

6. **VS Code extensions.** Compare `code --list-extensions` against
   `config/vscode-extensions.txt` and report which recommendations are
   missing or outdated.

7. **OpenCode.** Report the installed version against the latest release
   visible in `opencode --version`. Do not upgrade.

8. **Classify every update** as:
   - `patch` — safe, no behaviour change expected
   - `minor` — new features, read the changelog first
   - `major` — breaking, requires migration

## Required output

```markdown
## Repository
- Current: <short sha> (<n> commits behind origin/main)

## Chezmoi
- Source: <path>
- Pending changes: <n files, or "none">

## Tool versions
| Tool | Installed | Minimum | Status |
|------|-----------|---------|--------|
| git  | ...       | ...     | ok / outdated |

## Runtimes
| Tool | Installed | Declared | Change type |
|------|-----------|----------|-------------|

## System packages
- <n> upgradable: <list, or "none">

## VS Code extensions
- Missing: <list, or "none">

## OpenCode
- Installed: <version>
- Latest known: <version>

## Recommended order
1. <step> — `command` — <why this order>
2. ...

## Breaking changes requiring confirmation
- <tool> <old> -> <new>: <what breaks, what to do>

## Commands, not executed
```bash
./scripts/update.sh --check-only
./scripts/backup.sh
./scripts/update.sh
make verify
```
```

## Completion criteria

- Nothing was upgraded, installed or applied.
- Every update is classified as patch, minor or major.
- Major updates are listed separately with their migration impact.
- Every suggested command is real and exists in this repository.