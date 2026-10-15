---
description: Diagnose the development environment. Read only, changes nothing.
agent: build
---

Diagnose the development environment and report what is wrong.

Arguments: `$ARGUMENTS`

## Rules

- **Change nothing.** Do not install, update, edit, move or delete anything.
- Do not run `chezmoi apply`, `mise install`, `apt install` or `npm install`.
- Do not modify any file, including generated ones.

## Procedure

1. **Collect facts about the machine.**

   Run the environment diagnostics available in this repository:

   ```bash
   ./scripts/detect-platform.sh
   ./scripts/doctor.sh
   ./scripts/verify.sh
   ```

   If any of them is missing, gather the equivalent facts directly:
   `uname -a`, `cat /etc/os-release`, `echo "$PATH"`, `command -v <tool>` and
   `<tool> --version` for each expected tool.

2. **Check the configuration files** (existence and contents, never secrets):
   - `~/.gitconfig` and `git config --list --show-origin`
   - `~/.zshrc`, `~/.bashrc`, `~/.profile`
   - `~/.config/mise/config.toml`
   - `~/.config/starship.toml`
   - `~/.config/opencode/opencode.jsonc` and `~/.config/opencode/AGENTS.md`
   - `~/.agents/skills/` for installed skills
   - `~/.config/Code/User/settings.json`

3. **Check the tool chain**, when the tools are present:
   - `git --version`, `chezmoi --version`, `mise --version`
   - `mise ls --installed`
   - `docker --version`, `docker compose version`, `docker info`
   - `opencode --version`, `opencode debug agents`, `opencode debug config`
   - `code --version`, `code --list-extensions`

4. **Classify each finding** as one of:
   - **blocker** — a required tool is missing or broken
   - **misconfiguration** — a value is wrong or inconsistent
   - **warning** — optional, degrades experience
   - **info** — worth knowing

5. **Recommend the smallest fix** for each finding, as a command Luis can run.
   Do not run it.

## Required output

```markdown
## Summary
<one paragraph: is the environment usable, and what is the single biggest problem>

## Findings

### [blocker] <title>
- **Evidence**: the exact command and its real output
- **Cause**: why this happens
- **Fix**: `command to run`
- **Risk**: what happens if it stays unfixed

## Checks that could not run
- <command> — <reason: not installed, needs privileges, needs network>

## Not verified
- <claim that would need a human or a live system>
```

## Completion criteria

- Every finding cites real command output, not an assumption.
- Commands that could not run are listed explicitly with the reason.
- Nothing on the machine was modified.
- Recommendations are concrete commands, not prose.