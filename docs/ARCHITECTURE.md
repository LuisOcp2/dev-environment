# Architecture

This document explains how the repository is organised, what each layer is
responsible for, and which decisions were made so future changes extend the
system instead of rewriting it.

## The one-line summary

This repository is **two systems in one Git tree**:

1. **An operations system** (`bootstrap.sh`, `scripts/`, `packages/`,
   `config/`) that installs tools on a machine. It is *not* managed by chezmoi.
2. **A dotfiles source state** (`home/`) that chezmoi applies to `$HOME`. It
   is *not* executed by the bootstrap directly.

`scripts/apply-dotfiles.sh` is the single bridge between the two.

## Why `.chezmoiroot` contains `home`

```
.chezmoiroot   ->  home
```

chezmoi resolves `.chezmoiroot` relative to the repository root, then treats
everything below that directory as the source state.

Without it, chezmoi would treat the repository root as the source state and
manage `scripts/`, `docs/`, `.github/` and every other operational file into
`$HOME`. That would be wrong on three counts: files would land in unexpected
home locations, the operational code would become managed state, and every
script change would show up as a dotfile change.

The consequence: **any file added under `home/` is automatically managed by
chezmoi**; any file added anywhere else is invisible to chezmoi.

## Directory map

```
dev-environment/
├── .chezmoiroot            marks `home/` as the chezmoi source root
├── bootstrap.sh            single entry point, delegates to scripts/
├── Makefile                thin, discoverable wrappers around the scripts
├── packages/               package manifests, one domain per file
├── config/                 defaults and profile definitions
├── scripts/
│   ├── lib/                shared logic, no executable entry points
│   └── *.sh                one responsibility per script
├── home/                   chezmoi source state (managed into $HOME)
├── templates/              copy-and-adapt starting points
├── docs/                   the documentation set
└── .github/                CI, issue forms, pull request template
```

## Layers and responsibilities

### Layer 1 — Entry points

`bootstrap.sh` and the `scripts/*.sh` files.

Responsibilities: argument parsing, orchestration, confirmation, reporting.

Rules:

- Every script is independently executable and independently useful:
  `scripts/verify.sh` works without ever having run `bootstrap.sh`.
- Every script must work standalone: it resolves its own location, sources the
  libraries it needs, and reads `config/defaults.env` itself.
- No entry point defines a function that another entry point needs. Shared
  behaviour belongs in `scripts/lib/`.

### Layer 2 — Libraries (`scripts/lib/`)

| File                | Responsibility                                                 |
| ------------------- | -------------------------------------------------------------- |
| `logging.sh`        | levelled output, colour policy, the `ERR` trap                  |
| `platform.sh`       | OS/distro/arch detection, privilege helpers. Detects only.      |
| `common.sh`         | paths, XDG resolution, dry-run execution, confirmation, idempotency helpers |
| `packages.sh`       | manifest reading, cumulative profile resolution, apt naming     |

Rules:

- Libraries are only ever `source`d, never executed.
- Libraries define no behaviour that touches the system. Detection lives in
  `platform.sh`; installation lives in `install-system-packages.sh`.
- Libraries guard against double sourcing with a `*_LOADED` variable.
- A function is never duplicated between a library and an entry point.

### Layer 3 — Data (`packages/`, `config/`)

This is the extension point. Adding a package or a profile must never require
editing a script.

```
config/profiles/fullstack.env
   PROFILE_INHERITS="frontend backend"
   PACKAGE_SETS="fullstack"
   PROFILE_FLAGS="docker vscode"
             |
             v
packages/base.txt  packages/database.txt  packages/fullstack.txt
             |
             v
scripts/install-system-packages.sh  ->  apt
```

Profile resolution is a DAG walk in `packages.sh::_profile_collect`:
parents are resolved first, results are appended, and a visited set plus a
depth limit of 8 prevent a cycle from hanging the bootstrap.

Manifest syntax:

| Line        | Meaning                                                     |
| ----------- | ----------------------------------------------------------- |
| `package`   | required; an error if apt cannot resolve it                   |
| `?package`  | optional; silently skipped when apt does not provide it       |
| `# comment` | ignored                                                      |
| blank       | ignored                                                      |

### Layer 4 — Source state (`home/`)

Everything chezmoi applies to `$HOME`.

| Source path                             | Target                                 |
| --------------------------------------- | -------------------------------------- |
| `dot_gitconfig.tmpl`                     | `~/.gitconfig`                         |
| `dot_zshrc`                              | `~/.zshrc`                             |
| `dot_bashrc`                             | `~/.bashrc`                            |
| `dot_profile`                            | `~/.profile`                           |
| `dot_tmux.conf`                          | `~/.tmux.conf`                         |
| `dot_config/starship.toml`               | `~/.config/starship.toml`              |
| `dot_config/mise/config.toml`            | `~/.config/mise/config.toml`           |
| `dot_config/git/ignore`                  | `~/.config/git/ignore`                 |
| `dot_config/opencode/`                   | `~/.config/opencode/`                  |
| `dot_agents/skills/`                     | `~/.agents/skills/`                    |
| `dot_config/Code/User/`                  | `~/.config/Code/User/`                 |

Naming rules:

- `dot_` prefix for a dotfile at the home root.
- `dot_config/` for the whole XDG config tree.
- `_` in a name becomes `/` in the target, so
  `dot_config/mise/config.toml` becomes `~/.config/mise/config.toml`.
- `.tmpl` files are Go templates rendered by chezmoi.
- `private_` would be the prefix for a 0600 file; nothing in this repository
  uses it, because nothing here is secret.

### Layer 5 — Validation

Two independent entry points:

| Command            | Scope                | Modifies anything |
| ------------------ | -------------------- | ----------------- |
| `make validate`    | this repository only  | no                |
| `make verify`      | the local machine    | no                |

Both are read only. `make validate` is what CI runs; `make verify` is what
answers "is my machine ready".

## Control flow

```
bootstrap.sh
  1. parse arguments
  2. detect platform                 -> scripts/detect-platform.sh (inline call)
  3. load config/defaults.env
  4. resolve the profile             -> scripts/lib/packages.sh
  5. print the plan
  6. confirm                         (skipped by --yes and --dry-run)
  7. install system packages         -> scripts/install-system-packages.sh
  8. install chezmoi                 -> scripts/install-chezmoi.sh
  9. install mise and versions       -> scripts/install-mise.sh
 10. install Docker                  -> scripts/install-docker.sh      [flag: docker]
 11. install VS Code extensions      -> scripts/install-vscode-extensions.sh [flag: vscode]
 12. diff then apply dotfiles        -> scripts/apply-dotfiles.sh
 13. verify                          -> scripts/verify.sh
 14. summary
```

Each step delegates. `bootstrap.sh` contains orchestration only.

## The dry-run contract

`DRY_RUN=true` is an environment variable, exported by `bootstrap.sh`, and
honoured by every script through the `run` helper in `scripts/lib/common.sh`:

```bash
run git --version
```

prints `[DRY-RUN] git --version` instead of executing. `run_sudo` does the
same and omits the `sudo` prefix when the user is already root.

`--dry-run` must never modify the system. The only places that write directly
rather than through `run` are documented in the scripts themselves, and each
of them checks `DRY_RUN` first.

## Idempotency

Every installer checks for its own result before acting:

| Step            | Idempotency check                       |
| --------------- | ---------------------------------------- |
| apt packages    | `dpkg-query -W` before adding to the list |
| chezmoi         | `command -v chezmoi` before downloading   |
| mise            | `command -v mise` before downloading      |
| Docker          | `command -v docker` before running the installer |
| VS Code extensions | `code --list-extensions` before installing |
| dotfiles        | `chezmoi diff` before `chezmoi apply`     |
| shell default   | compares with `$SHELL` before calling `chsh` |
| PATH entries    | `append_once` greps before appending      |

Running the bootstrap twice must not duplicate a configuration entry or fail.

## The AI layer

Two separate mechanisms, both managed by chezmoi:

| Mechanism | Location                       | Discovery                |
| --------- | ------------------------------ | ------------------------ |
| Skills    | `~/.agents/skills/<id>/SKILL.md` | OpenCode compatibility path |
| Agents    | `~/.config/opencode/agents/*.md` | global agents directory    |
| Commands  | `~/.config/opencode/commands/*.md` | global commands directory |
| Config    | `~/.config/opencode/opencode.jsonc` | global configuration   |
| Rules     | `~/.config/opencode/AGENTS.md` | global instructions       |

The distinction matters: **skills are procedures, agents are personas,
commands are prompts, AGENTS.md is always-on policy.** They are kept in
separate directories precisely so they do not get confused.

`~/.agents/skills` is used rather than `~/.config/opencode/skills` because it
is the portability path: the same directory works for any tool that reads the
`.agents` convention.

## Decisions and rationale

| Decision                        | Rationale                                                        |
| ------------------------------- | ---------------------------------------------------------------- |
| `.chezmoiroot` = `home`         | keeps operational code out of the managed state                    |
| Profiles are a DAG, not a tree  | `fullstack` needs both `frontend` and `backend`                    |
| Manifests separate from profiles| adding a package is a one-line change                             |
| Optional packages marked `?`    | a missing optional tool never fails a bootstrap                   |
| Libraries source-guarded        | entry points can source them without ordering constraints          |
| Dry-run through `run`/`run_sudo`| one mechanism, impossible to forget in a new script                |
| No fixed AI model or provider   | the provider is a personal, machine-local decision                 |
| Skills in `~/.agents/skills`    | portable across tools, still discovered by OpenCode               |
| No `apt upgrade` automation    | a machine should never be upgraded behind the user's back          |
| Counts persisted to a state file| child processes cannot return values through `run`                  |

## Extension points

| I want to...                  | Edit                                          |
| ----------------------------- | --------------------------------------------- |
| add a system package          | `packages/*.txt`                              |
| add a profile                | `config/profiles/<name>.env`                  |
| change a default             | `config/defaults.env`                         |
| add a VS Code extension      | `config/vscode-extensions.txt`                |
| add a dotfile                | a file under `home/`                          |
| add a tool version           | `home/dot_config/mise/config.toml`            |
| add a skill                  | `home/dot_agents/skills/<name>/SKILL.md`      |
| add an agent                 | `home/dot_config/opencode/agents/<name>.md`   |
| add a command                | `home/dot_config/opencode/commands/<name>.md` |
| add a script                 | `scripts/<name>.sh`                           |
| add shared logic             | `scripts/lib/<name>.sh`                       |

Each of these requires no change to any other file. Documentation must be
updated in the same change; see `docs/ADDING-CONFIGURATION.md`.

## Platform support

| Platform                  | Status   | Notes                                        |
| ------------------------- | -------- | -------------------------------------------- |
| Ubuntu                    | supported | `packages/*.txt` install via apt              |
| TuxedoOS                  | supported | Ubuntu based; detected separately for reporting |
| Debian                    | supported | same code path as Ubuntu                      |
| WSL2                      | planned  | see `docs/ROADMAP.md`                         |
| macOS                     | planned  | Homebrew path not implemented                 |
| Windows (Git Bash / PowerShell) | refused | `bootstrap.sh` exits with a clear message   |

Adding a platform means: a detector in `scripts/lib/platform.sh`, a package
manager branch in `scripts/install-system-packages.sh`, and a row in this
table. No other layer changes.