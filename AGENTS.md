# AGENTS.md - instructions for AI agents working on this repository

This file applies to the whole repository. Project-level rules inside other
repositories override nothing here; if you are working on a project that has
its own `AGENTS.md`, that file adds to these rules.

## 1. What this repository is

A single source of truth that provisions a Linux development machine:

- installs tools declaratively from manifests and profiles
- manages dotfiles with chezmoi
- manages runtimes with mise
- configures Git, Zsh, Starship, tmux and VS Code
- ships global AI agent instructions, skills, agents and commands

Owner: Luis Miguel Ocampo Guerrero. GitHub: `LuisOcp2`. Primary system:
TuxedoOS on Ubuntu. Communication: Spanish. Code, identifiers and commits:
English.

## 2. Architecture in one paragraph

This repository is **two systems in one Git tree**. An *operations system*
(`bootstrap.sh`, `scripts/`, `packages/`, `config/`) installs tools and is never
managed by chezmoi. A *dotfiles source state* (`home/`) is managed by chezmoi
and applied to `$HOME`. `.chezmoiroot` contains `home`, which is what keeps
the two from mixing. `scripts/apply-dotfiles.sh` is the only bridge. Full
detail in `docs/ARCHITECTURE.md`.

## 3. What chezmoi manages

Everything under `home/`, and nothing else.

| Source                                     | Target                        |
| ------------------------------------------ | ----------------------------- |
| `home/dot_gitconfig.tmpl`                   | `~/.gitconfig`                |
| `home/dot_zshrc`, `dot_bashrc`, `dot_profile` | the shell configuration   |
| `home/dot_tmux.conf`                         | `~/.tmux.conf`                |
| `home/dot_config/`                           | `~/.config/`                  |
| `home/dot_agents/skills/`                   | `~/.agents/skills/`           |
| `home/.chezmoi.toml.tmpl`, `.chezmoiignore` | chezmoi's own special files   |

If a file is under `home/`, editing `$HOME` directly is wrong: the change is
overwritten on the next `chezmoi apply`. Edit the source under `home/`.

## 4. Bash conventions

Non-negotiable. CI enforces them.

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

enable_error_trap
```

| Rule                                                | Reason                                  |
| --------------------------------------------------- | --------------------------------------- |
| `set -Eeuo pipefail` in every script                 | fail fast, no unset expansion            |
| lower-case snake_case function names                 | consistent with shellcheck defaults      |
| `local` for every variable inside a function         | no leakage between scripts              |
| functions defined before they are called             | works when sourced                      |
| `scripts/lib/` is only sourced, never executed       | single definition, no drift             |
| libraries guard against double sourcing              | entry points can source freely           |
| a function is never duplicated                       | duplication is how environments drift    |
| every side effect goes through `run` / `run_sudo`    | `--dry-run` works automatically          |
| every installer checks for its result first          | idempotency                             |
| `shellcheck` clean at `warning` severity             | CI runs it                              |
| formatted with `shfmt -i 2 -ci -sr -kp`             | CI runs it                              |

Never write `echo` for user-facing output. Use `log_info`, `log_success`,
`log_warn`, `log_error` or `log_skip`, so the level is machine-readable and
the colour policy is respected.

## 5. Security rules

These are not preferences.

- **Never commit a secret.** No API keys, tokens, passwords, cookies, private
  keys, cloud credentials or AI provider tokens.
- **Never read a real `.env`**, even to check whether one exists.
- **Never copy an SSH private key** into the repository.
- **Never configure an AI provider token.** `opencode auth login` owns
  credentials.
- **Never hardcode a machine-specific path.** Use `$HOME`, `XDG_CONFIG_HOME`
  and computed paths. `scripts/lib/common.sh` provides `config_home()`,
  `data_home()`, `state_home()`, `cache_home()` and `user_bin_dir()`.
- **Never run `git push`.** Never force-push. Committing locally is allowed
  after validation passes.
- **Never change the default shell without explicit confirmation.** Use
  `set_shell_default` from `common.sh`, which asks first.
- **Never run `chezmoi apply` on the user's machine** without showing
  `chezmoi diff` first and asking.
- **Never perform a destructive install** as part of normal work.
- Placeholder values in examples must be obviously fake.

Full detail in `docs/SECURITY.md`.

## 6. Adding packages

Edit a manifest under `packages/`. Never edit a script.

```
package-name     # required
?package-name    # optional, skipped when apt cannot resolve it
```

Then:

```bash
make validate
make packages PROFILE=fullstack
```

Distro naming differences (currently only `fd` to `fd-find`) belong in
`resolve_package_name` in `scripts/lib/packages.sh`, not in the manifests.

## 7. Adding profiles

Create `config/profiles/<name>.env`:

```bash
PROFILE_DESCRIPTION="myprofile - what this machine is for"
PROFILE_INHERITS="minimal"
PACKAGE_SETS="base"
MISE_TOOLS="node python"
PROFILE_FLAGS="vscode"
```

Then validate, preview and document:

```bash
make validate
./bootstrap.sh --profile myprofile --dry-run
```

`make validate` fails if a profile references a manifest that does not exist,
so a typo cannot reach a machine.

Then update the profile tables in `README.md`, `docs/PROFILES.md` and the
`--help` output of `bootstrap.sh`. Documentation is part of the change.

## 8. Adding dotfiles

Create the file under `home/`, using chezmoi's naming:

- `dot_` for a dotfile at the home root
- `dot_config/` for the XDG config tree
- `_` becomes `/` in the target
- `.tmpl` suffix renders it as a Go template
- `executables_` marks `0755`; `private_` marks `0600` and is **never used
  here**, because nothing in this repository is secret

Preview, apply, commit the **source**:

```bash
chezmoi diff
chezmoi apply
git add home/
```

See `docs/ADDING-CONFIGURATION.md`.

## 9. Adding skills

Create `home/dot_agents/skills/<name>/SKILL.md`, starting from
`templates/skill/SKILL.md`.

Required frontmatter:

```yaml
---
name: <name>
description: <what it does and the situation in which to use it>
---
```

`name` must equal the directory name, and the directory name must match
`^[a-z0-9]+(-[a-z0-9]+)*$`.

Required sections: Objective, When to use, When not to use, Required inputs,
Procedure, Constraints, Validation checklist, Mandatory output format,
Completion criteria.

`make validate` enforces all of it. See `docs/ADDING-SKILLS.md`.

## 10. Adding OpenCode agents and commands

Use **V2 frontmatter only**. The removed V1 fields `tools`, `temperature`,
`top_p`, `prompt`, `permission`, `maxSteps` and `disable` are rejected by
`make validate`.

Valid agent fields: `description`, `mode`, `model`, `permissions`, `steps`,
`hidden`, `color`, `disabled`, `request`.

Valid command fields: `description`, `agent`, `model`, `subagent`.
`template` is JSON-only.

Never pin a `model`: the provider and model are a personal, machine-local
decision. Permissions are an ordered list of `{action, resource, effect}`
rules, and the **last** matching rule wins.

Reference: `docs/OPENCODE.md`.

## 11. Validating changes

```bash
make validate      # the repository only; never modifies the machine
make dry-run       # the full bootstrap plan; never modifies the system
make verify        # the local machine; never modifies anything
make doctor        # full environment diagnosis; never modifies anything
```

`make validate` runs, in order: `bash -n`, shellcheck, shfmt, JSON and JSONC,
skill structure and frontmatter, agent and command frontmatter, secret
patterns, executable bits, and structure invariants.

Any check whose tooling is unavailable is reported as **SKIPPED**, never as a
silent pass. Report skipped checks in your summary.

## 12. What an agent must not do here

- Commit, push, tag or release without being asked.
- Change the user's default shell, Git identity, or system configuration
  directly. Use the scripts, which ask first.
- Run `chezmoi apply`, `mise install`, `apt install`, `npm install -g` or
  `docker` install as part of normal work.
- Disable, skip or weaken a test, a linter or a type check to make something
  pass.
- Edit a generated file, a lockfile or anything under `.git/`.
- Reformat files outside the scope of the task.
- Add a dependency without saying in one sentence why the existing ones are
  insufficient.
- Invent a flag, an option, a schema property or a command output.
- Modify a file in `$HOME` directly instead of its source under `home/`.
- Claim a validation passed when it could not run.

## 13. Definition of Done

A change is done when every one of these is true.

### Repository integrity

- [ ] `bash -n` passes on every `.sh`
- [ ] shellcheck reports no errors or warnings
- [ ] shfmt reports no diff with `-i 2 -ci -sr -kp`
- [ ] Every JSON file parses; every JSONC file parses after comment stripping
- [ ] Every skill has valid frontmatter with `name` and `description`
- [ ] Every skill's `name` equals its directory name
- [ ] Every skill directory matches `^[a-z0-9]+(-[a-z0-9]+)*$`
- [ ] Every agent and command uses only OpenCode V2 frontmatter fields
- [ ] `make validate` exits `0`

### Behaviour

- [ ] `--dry-run` modifies nothing
- [ ] Running the change twice is a no-op: no duplicated configuration and no
      error
- [ ] The README describes the real behaviour, not the intended behaviour
- [ ] Documentation was updated in the same change
- [ ] The change is additive unless a breaking change was explicitly intended

### Security

- [ ] No secret, token, key or credential was introduced
- [ ] No real `.env` was read
- [ ] No machine-specific absolute path was hardcoded
- [ ] No destructive operation runs without a confirmation prompt

### Reporting

- [ ] Every validation that ran is reported with its real result
- [ ] Every validation that could **not** run is reported, with the reason
- [ ] Residual risks are stated

### Git

- [ ] The commit message is in English, imperative mood, under 72 characters
- [ ] `git status` is clean
- [ ] Nothing was pushed

## 14. When this repository is extended

Every one of these must be possible **without editing an existing script**:

| Change                | Touch only                                          |
| --------------------- | --------------------------------------------------- |
| a package             | `packages/*.txt`                                     |
| a profile             | `config/profiles/<name>.env`                         |
| a default             | `config/defaults.env`                                |
| an extension          | `config/vscode-extensions.txt`                       |
| a dotfile             | a new file under `home/`                             |
| a tool version        | `home/dot_config/mise/config.toml`                   |
| a skill               | a new directory under `home/dot_agents/skills/`      |
| an agent              | a new file under `home/dot_config/opencode/agents/`  |
| a command             | a new file under `home/dot_config/opencode/commands/`|
| a script              | `scripts/<name>.sh`                                  |
| shared logic          | `scripts/lib/<name>.sh`                              |

If a change requires touching more than one of these, the design is wrong.
Stop and fix the design instead.