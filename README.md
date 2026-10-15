# dev-environment

A single source of truth that turns a fresh Linux workstation into a complete
AI-assisted development environment: tools, dotfiles, runtimes, editor
configuration and a reusable AI agent layer.

Everything is declarative, idempotent and reviewable. Adding a tool, a profile
or a skill never requires editing an existing script.

```bash
git clone https://github.com/LuisOcp2/dev-environment.git
cd dev-environment
./bootstrap.sh --profile fullstack --dry-run   # see the plan, change nothing
./bootstrap.sh --profile fullstack             # install
make verify                                    # prove it worked
```

---

## Contents

1. [Purpose](#1-purpose)
2. [Features](#2-features)
3. [Architecture](#3-architecture)
4. [Requirements](#4-requirements)
5. [Initial installation](#5-initial-installation)
6. [New machine setup](#6-new-machine-setup)
7. [Profiles](#7-profiles)
8. [Dry run](#8-dry-run)
9. [Verification](#9-verification)
10. [Updating](#10-updating)
11. [Rollback and restore](#11-rollback-and-restore)
12. [Adding configuration](#12-adding-configuration)
13. [Adding packages](#13-adding-packages)
14. [Adding a skill](#14-adding-a-skill)
15. [Security](#15-security)
16. [Troubleshooting](#16-troubleshooting)
17. [Roadmap](#17-roadmap)

---

## 1. Purpose

Rebuilding a development machine by hand is slow, error-prone and
undocumented. This repository makes the machine reproducible from a Git clone:

- **declarative** — packages come from manifests, tools from profiles
- **idempotent** — running the bootstrap twice changes nothing
- **inspectable** — `--dry-run` prints exactly what would happen
- **extensible** — one file per package, profile, skill, agent or command
- **safe** — no secrets, no destructive operations, confirmation before
  anything touches `$HOME`

## 2. Features

| Area              | What you get                                                      |
| ----------------- | ----------------------------------------------------------------- |
| Packages          | apt manifests per domain, optional entries, distro name mapping    |
| Profiles          | six cumulative profiles, from `minimal` to `fullstack`             |
| Dotfiles          | Git, Zsh, Bash, tmux, Starship, VS Code, managed by chezmoi        |
| Runtimes          | Node, Python, Java, pnpm, uv pinned through mise                   |
| Containers        | Docker and Compose, opt-in, only when the profile asks            |
| Editors           | VS Code settings, keybindings and a maintained extension list      |
| AI instructions   | a global `AGENTS.md` for OpenCode                                  |
| AI skills         | 16 reusable procedures in `~/.agents/skills`                       |
| AI agents         | 6 specialised subagents: architect, reviewer, debugger, security, testing, docs |
| AI commands       | 7 slash commands: doctor, plan, review, security, new-skill, update, verify |
| Verification      | repository validation, environment verification, environment doctor |
| Lifecycle         | safe update, backup and restore flows                              |
| CI                | syntax, lint, format, JSON, skills, frontmatter, secrets, permissions |

## 3. Architecture

Two systems in one Git tree:

```
dev-environment/
├── .chezmoiroot            contains `home`
├── bootstrap.sh            the single entry point
├── Makefile                discoverable wrappers
├── packages/               package manifests
├── config/                 defaults, profiles, extension list
├── scripts/
│   ├── lib/                shared logic (sourced, never executed)
│   └── *.sh                one responsibility per script
├── home/                   chezmoi source state -> $HOME
│   ├── dot_zshrc, dot_bashrc, dot_profile
│   ├── dot_gitconfig.tmpl
│   ├── dot_tmux.conf
│   ├── dot_agents/skills/
│   └── dot_config/         starship, mise, git, opencode, Code
├── templates/              copy-and-adapt starting points
├── docs/                   the documentation set
└── .github/                CI, issue forms, PR template
```

Because `.chezmoiroot` contains `home`, chezmoi manages **only** what is under
`home/`. The operational code stays outside the managed state.

Full detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## 4. Requirements

| Requirement        | Minimum | Notes                                    |
| ------------------ | ------- | ---------------------------------------- |
| Ubuntu / TuxedoOS  | 22.04+  | or Debian 12+; apt based                  |
| bash              | 4.4     | `bash --version`                          |
| git               | 2.34    | the only hard prerequisite                |
| curl              | any     | for every installer                       |
| make              | any     | optional; only for the convenience targets |

`chezmoi`, `mise` and Docker are installed by the bootstrap.

```bash
# On a fresh machine, before anything else:
sudo apt-get update
sudo apt-get install -y git curl ca-certificates
```

## 5. Initial installation

```bash
git clone https://github.com/LuisOcp2/dev-environment.git
cd dev-environment

# Preview. Always do this first on a machine you care about.
./bootstrap.sh --profile fullstack --dry-run

# Install.
./bootstrap.sh --profile fullstack

# Optional extras: starship, direnv hook, OpenCode CLI.
make dev-tools

# Verify.
make verify
```

Without `make`:

```bash
./bootstrap.sh --profile fullstack
./scripts/verify.sh --profile fullstack
./scripts/doctor.sh
```

### Alternative: chezmoi only

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

# Over HTTPS
chezmoi init --apply https://github.com/LuisOcp2/dev-environment.git

# Over SSH (the --ssh flag builds an SSH URL)
chezmoi init --apply --ssh LuisOcp2/dev-environment

# Private repository over SSH
chezmoi init --apply git@github.com:LuisOcp2/dev-environment.git
```

Full instructions, including a private repository with a dedicated deploy
key: [`docs/INSTALLATION.md`](docs/INSTALLATION.md).

## 6. New machine setup

```bash
git clone git@github.com:LuisOcp2/dev-environment.git
cd dev-environment
./bootstrap.sh --profile fullstack
make verify
```

On first run, `chezmoi init` asks for a Git email, a default branch, a pull
strategy, an editor and a login shell. The answers are stored in
`~/.config/chezmoi/chezmoi.toml`, which is local state and is never committed.

To be asked again:

```bash
chezmoi init --prompt
```

## 7. Profiles

```bash
./bootstrap.sh --list-profiles
```

| Profile     | Inherits             | Adds                                                     | Runtime tools                     |
| ----------- | -------------------- | -------------------------------------------------------- | --------------------------------- |
| `minimal`   | -                    | shell, git, curl, jq, zsh, tmux, fzf, bat, ripgrep, fd, shellcheck, direnv | `shfmt` |
| `frontend`  | `minimal`            | image and diagram tooling                                 | `node` 22, `pnpm` 10              |
| `backend`   | `minimal`            | PostgreSQL, MySQL and Redis **clients**                  | `node`, `pnpm`, `python` 3.12, `uv`, `java` 21 |
| `fullstack` | `frontend`, `backend`| native Node build dependencies                           | all of the above                  |
| `cloud`     | `minimal`            | JDK, optional `kubectl`                                  | `terraform`, `kubectl`            |
| `teaching`  | `minimal`            | JDK, git-gui, graphviz, pandoc                            | `node`, `pnpm`, `python`, `java`  |

```bash
./bootstrap.sh --profile minimal
./bootstrap.sh --profile frontend
./bootstrap.sh --profile backend
./bootstrap.sh --profile fullstack
./bootstrap.sh --profile cloud
./bootstrap.sh --profile teaching

# See exactly what a profile resolves to.
make packages PROFILE=fullstack
```

Profiles are cumulative and easy to extend: create
`config/profiles/<name>.env`. See [`docs/PROFILES.md`](docs/PROFILES.md).

## 8. Dry run

Nothing is ever installed before you see it.

```bash
# The whole plan for a profile.
./bootstrap.sh --profile fullstack --dry-run

# What the installers would do on their own.
./scripts/install-system-packages.sh --profile fullstack --dry-run
./scripts/install-docker.sh --dry-run
./scripts/install-chezmoi.sh --dry-run
./scripts/install-mise.sh --profile fullstack --dry-run

# What chezmoi would change in $HOME.
make diff
```

`--dry-run` is implemented through the `run` and `run_sudo` helpers in
`scripts/lib/common.sh`, so every side effect in every script honours it
automatically.

## 9. Verification

```bash
make validate   # this repository; never modifies anything
make verify     # this machine; never modifies anything
make doctor     # full environment diagnosis; read only
```

| Command         | Scope                     | Modifies |
| --------------- | ------------------------- | -------- |
| `make validate` | repository consistency    | no       |
| `make verify`   | the installed environment  | no       |
| `make doctor`   | full diagnosis             | no       |
| `make dry-run`  | the install plan           | no       |
| `make test`     | syntax plus self tests     | no       |
| `make lint`     | shellcheck and shfmt       | no       |

`make validate` runs: `bash -n`, shellcheck, shfmt, JSON and JSONC, skill
structure and frontmatter, agent and command frontmatter, secret patterns,
executable bits, and repository invariants. Checks whose tooling is missing
are reported as **SKIPPED**, never as a silent pass.

```bash
# Narrow it down.
./scripts/validate-repository.sh --only skills
./scripts/validate-repository.sh --only secrets
./scripts/validate-repository.sh --no-warnings
```

## 10. Updating

```bash
# Report what is available. Changes nothing.
make update-check
./scripts/update.sh --check-only

# Apply, confirming each step.
make update

# Non interactive, for a disposable VM.
./scripts/update.sh --yes
```

`scripts/update.sh` backs up first, then asks before each of: `git fetch`,
fast-forward, `chezmoi update`, `chezmoi apply`, `mise install` and
`apt-get update`. It **never** runs `apt upgrade`, never upgrades a major
runtime version without `--allow-major`, and never force-pushes.

## 11. Rollback and restore

```bash
# Back up the current chezmoi state.
make backup
make backup-list

# See what would change before touching anything.
chezmoi diff
make diff
```

A backup contains the chezmoi source directory, the local chezmoi config and
state, and a manifest of managed files. It never contains SSH keys, real
`.env` values, cloud credentials or AI tokens.

Restoring is described in the `RESTORE.md` written inside each backup:

```bash
mv "$(chezmoi source-path)" "$(chezmoi source-path).before-restore"
cp -a ./chezmoi-source "$(chezmoi source-path)"
chezmoi diff
chezmoi apply
```

To stop managing a single file without deleting it:

```bash
chezmoi rm ~/.zshrc
```

To detach chezmoi entirely, keeping your files:

```bash
chezmoi purge
```

## 12. Adding configuration

Each of these touches exactly one file. See
[`docs/ADDING-CONFIGURATION.md`](docs/ADDING-CONFIGURATION.md).

| I want to...             | Touch only                                  |
| ------------------------ | ------------------------------------------- |
| add a dotfile            | a new file under `home/`                    |
| adopt an existing one    | `chezmoi add <path>`, then commit `home/`   |
| machine-specific config  | `~/.zshrc.local`, `~/.profile.local`        |
| add a script             | `scripts/<name>.sh` + `chmod +x`            |
| add shared logic         | `scripts/lib/<name>.sh`                     |
| add a tool version       | `home/dot_config/mise/config.toml`          |
| add an OpenCode agent    | `home/dot_config/opencode/agents/<n>.md`    |
| add an OpenCode command  | `home/dot_config/opencode/commands/<n>.md`  |

```bash
make validate && make diff
```

## 13. Adding packages

```bash
echo 'libsqlite3-dev' >> packages/database.txt      # required
echo '?libsqlite3-dev' >> packages/database.txt     # optional

make validate
make packages PROFILE=backend
./bootstrap.sh --profile backend --dry-run
```

| Line        | Meaning                                          |
| ----------- | ------------------------------------------------ |
| `package`   | required; the bootstrap fails if apt lacks it     |
| `?package`  | optional; skipped silently when unavailable      |

No script changes required.

## 14. Adding a skill

Skills live in `~/.agents/skills/`, managed from `home/dot_agents/skills/`.

```bash
mkdir -p home/dot_agents/skills/my-skill
cp templates/skill/SKILL.md home/dot_agents/skills/my-skill/SKILL.md
$EDITOR home/dot_agents/skills/my-skill/SKILL.md

make validate
make diff && make apply

# Inside OpenCode, /new-skill follows the skill-creator skill for you.
```

Every skill needs frontmatter whose `name` equals its directory name, and a
description that carries the trigger:

```yaml
---
name: my-skill
description: What this does. Use this when <the concrete situation>.
---
```

Guide: [`docs/ADDING-SKILLS.md`](docs/ADDING-SKILLS.md).

## 15. Security

```bash
./scripts/validate-repository.sh --only secrets
```

- No secret is ever committed, applied or read.
- `.gitignore` blocks `.env`, `*.pem`, `*.key`, `id_rsa`, `auth.json`,
  `token*` and more; `.env.example` stays trackable.
- The scanner detects AWS keys, GitHub and GitLab tokens, OpenAI and Anthropic
  keys, Slack tokens, Google keys, PEM private key headers and JWTs. **It is a
  heuristic, not a guarantee.**
- Placeholder values in examples must be obviously fake.
- `opencode.jsonc` denies `rm -rf`, `sudo`, force-push and reads of
  `~/.ssh`, `~/.aws` and `~/.netrc`; it asks before anything destructive.
- The default shell is never changed without explicit confirmation.
- `chezmoi apply` never runs without `chezmoi diff` first.

Full policy, and how to respond to an accidental exposure:
[`docs/SECURITY.md`](docs/SECURITY.md).

## 16. Troubleshooting

```bash
make doctor
```

| Symptom                                  | First command                                  |
| ---------------------------------------- | ---------------------------------------------- |
| `command not found` after installing      | `echo "$PATH" \| tr ':' '\n'` and `exec "$SHELL" -l` |
| wrong runtime version                    | `mise current && mise ls`                       |
| chezmoi does not manage my new file      | `chezmoi source-path` and `chezmoi diff`        |
| Docker permission denied                 | `groups` and `newgrp docker`                   |
| a VS Code extension will not install      | `code --list-extensions`                        |
| an OpenCode agent is missing             | `opencode debug agents`                         |
| skills are not detected                  | `ls ~/.agents/skills/` and `make validate`     |

Full guide: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

## 17. Roadmap

Planned, in rough order:

- **WSL2** support: systemd, Docker path, file-watching caveats
- **macOS** support: a Homebrew manifest contract alongside the apt one
- **Dev Containers**: templates exist; automation next
- **CI**: wider matrix, auto-formatting, reusable workflow
- **VM test matrix**: Ubuntu 22.04, 24.04, Debian 12, TuxedoOS, asserting
  that `make verify` exits `0` and that a second bootstrap run changes nothing
- **Ansible** layer, once more than one machine needs this

Explicit non-goals: Nix, a plugin framework, automatic OS upgrades, secret
management, pinning an AI model or provider, and automatic pushing.

Full roadmap: [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Documentation

| Document                              | Contents                                    |
| ------------------------------------- | ------------------------------------------- |
| [`AGENTS.md`](AGENTS.md)              | rules for AI agents working on this repository |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | layers, responsibilities, decisions |
| [`docs/INSTALLATION.md`](docs/INSTALLATION.md) | every installation path, including private repositories |
| [`docs/PROFILES.md`](docs/PROFILES.md) | what each profile installs, how to add one |
| [`docs/ADDING-CONFIGURATION.md`](docs/ADDING-CONFIGURATION.md) | dotfiles, scripts, tools |
| [`docs/ADDING-SKILLS.md`](docs/ADDING-SKILLS.md) | skill anatomy and lifecycle |
| [`docs/OPENCODE.md`](docs/OPENCODE.md) | instructions, agents, skills, commands, permissions |
| [`docs/SECURITY.md`](docs/SECURITY.md) | secret policy and incident response        |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | every known failure mode          |
| [`docs/ROADMAP.md`](docs/ROADMAP.md)   | what is next and what is deliberately not   |
| [`CHANGELOG.md`](CHANGELOG.md)         | release history                             |

## Make targets

```bash
make help          # list every target (the default)
make bootstrap     # provision this machine
make dry-run       # print the plan, change nothing
make diff          # what chezmoi would change
make apply         # preview then apply the dotfiles
make verify        # verify the environment
make doctor        # diagnose the environment
make validate      # validate this repository
make update        # check for and apply updates
make backup        # back up the chezmoi state
make lint          # shellcheck and shfmt
make test          # syntax plus repository self tests
make profiles      # list the profiles
make packages      # the resolved package list for PROFILE
make tools         # installed tool versions
```

Every target accepts `PROFILE=<name>`:

```bash
make bootstrap PROFILE=minimal
make verify PROFILE=backend
```

## License

Private and personal. Not published, not licensed for redistribution.

## Maintainer

**Luis Miguel Ocampo Guerrero** - [@LuisOcp2](https://github.com/LuisOcp2)