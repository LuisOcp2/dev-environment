# Changelog

All notable changes to this repository are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing yet.

## [1.0.0] - 2026-10-14

First stable release: a complete, idempotent, self-documenting development
environment.

### Added

#### Bootstrap

- `bootstrap.sh` as the single entry point, with `--profile`, `--yes`,
  `--dry-run`, `--skip-docker`, `--skip-vscode`, `--skip-dotfiles`,
  `--list-profiles` and `--help`.
- Four-phase separation of concerns: detection, installation, configuration and
  validation.
- Dry-run support implemented through the `run` and `run_sudo` helpers, so every
  side effect in every script honours it automatically.
- Colour output that is disabled when stdout is not a TTY, when `NO_COLOR` is
  set, or when `TERM` is `dumb`.
- Explicit `INFO`, `SUCCESS`, `WARNING`, `ERROR` and `SKIPPED` levels.
- Confirmation before any operation that touches `$HOME` or the system, and
  before changing the default shell.
- A final summary with the counts reported by each installer.

#### Shell libraries

- `scripts/lib/logging.sh`: levelled output, colour policy, `ERR` trap with
  the failing line and command.
- `scripts/lib/platform.sh`: OS, distribution, architecture, WSL and privilege
  detection. Detects only; installs nothing.
- `scripts/lib/common.sh`: repository path resolution, XDG-aware path helpers,
  dry-run execution, confirmation, and idempotent shell mutations
  (`append_once`, `set_shell_default`).
- `scripts/lib/packages.sh`: manifest reading, cumulative DAG profile
  resolution with cycle detection, and per-distribution apt name mapping.

#### Scripts

- `scripts/detect-platform.sh`, `install-system-packages.sh`,
  `install-chezmoi.sh`, `install-mise.sh`, `install-docker.sh`,
  `install-development-tools.sh`, `install-vscode-extensions.sh`,
  `apply-dotfiles.sh`, `verify.sh`, `update.sh`, `backup.sh`, `doctor.sh`.
- `scripts/validate-repository.sh`: the repository validator that CI runs.
  Reports unavailable tooling as `SKIPPED` rather than as a silent pass.
- Installers download third-party scripts to a temporary file over forced TLS
  1.2, and never pipe a download directly into a shell.
- Every installer checks for its own result before acting.

#### Packages and profiles

- Manifests: `base`, `fullstack`, `database`, `cloud`, `design`, `teaching`.
- Optional entries marked with `?` are skipped silently when apt cannot resolve
  them.
- Six cumulative profiles: `minimal`, `frontend`, `backend`, `fullstack`,
  `cloud`, `teaching`. `fullstack` inherits from both `frontend` and `backend`.
- Feature flags `docker`, `vscode`, `cloud` and `teaching` decide which script
  the bootstrap calls; they never install anything by themselves.

#### Dotfiles (chezmoi)

- `.chezmoiroot` containing `home`, keeping operational code out of the managed
  state.
- `.chezmoi.toml.tmpl` with `promptStringOnce` and `promptChoiceOnce` for the
  Git email, default branch, pull strategy, editor and login shell.
- `.chezmoiignore` excluding secrets, caches and machine-local state.
- Git configuration with the default branch `main`, `autocrlf=input`, fetch
  pruning, a configurable rebase strategy, rerere, `zdiff3` and transparent
  aliases only.
- A global Git excludes file with no destructive defaults.
- `~/.profile` with a single, guarded `PATH` append and XDG exports.
- `~/.zshrc` as the recommended shell: no downloads at startup, no duplicated
  `PATH`, every optional integration guarded, documented functions.
- `~/.bashrc` as a dependency-free fallback shell.
- tmux configuration with the documented `C-a` prefix, mouse support and no
  mandatory plugins.
- Starship prompt showing Git, language and command duration, restrained to
  stay readable at 80 columns.
- VS Code settings with per-language formatters, no universal global
  formatter, and a separately maintained extension list.

#### mise

- A conservative global configuration in `~/.config/mise/config.toml`:
  Node 22, Python 3.12, pnpm 10, Temurin 21, shfmt, uv.
- Versions pinned to major lines rather than `latest`, with the exception of
  uv, which is pre-1.0.
- `templates/mise/mise.toml` as a reusable per-project starting point.

#### AI layer

- A global `AGENTS.md` in Spanish for the conversation and English for code,
  commits and technical terms, with explicit rules on honesty, validation,
  security, destructive operations and reporting.
- A provider-independent `opencode.jsonc`: no `model`, no `default_agent`, no
  credentials. Only documented V2 properties are used.
- Conservative layered permissions: deny the irreversible, ask before anything
  leaving the machine or rewriting history, and allow only the read-only
  commands needed on most turns.
- 16 global skills in `~/.agents/skills/`, each a concrete procedure with
  frontmatter, inputs, constraints, a validation checklist, a mandatory output
  format and completion criteria:
  `discovery`, `implementation-plan`, `software-architecture`,
  `database-design`, `api-design`, `frontend-feature`, `backend-feature`,
  `systematic-debugging`, `test-strategy`, `code-review`, `security-review`,
  `performance-review`, `devops-deployment`, `technical-documentation`,
  `release-management`, `skill-creator`.
- 6 specialised OpenCode agents using V2 frontmatter and read-only permissions
  where appropriate: `architect`, `reviewer`, `debugger`, `security-auditor`,
  `test-engineer`, `documentation-writer`.
- 7 reusable slash commands: `doctor`, `plan`, `review`, `security-review`,
  `new-skill`, `update-environment`, `verify-project`.

#### Tooling

- `Makefile` with `help` as the default target, and a `PROFILE` override on
  every profile-aware target.
- GitHub Actions workflow running on pull requests and pushes to `main`,
  covering bash syntax, shellcheck, shfmt, JSON and JSONC, skill structure,
  frontmatter, secret patterns and executable permissions. It never applies
  dotfiles and never installs software.
- Bug and configuration issue forms, and a pull request template.
- Templates for skills, project `AGENTS.md`, mise project files and Dev
  Containers.

#### Documentation

- `README.md` with seventeen sections and copy-pasteable commands.
- `docs/ARCHITECTURE.md`, `INSTALLATION.md`, `PROFILES.md`,
  `ADDING-CONFIGURATION.md`, `ADDING-SKILLS.md`, `OPENCODE.md`, `SECURITY.md`,
  `TROUBLESHOOTING.md`, `ROADMAP.md`.
- `AGENTS.md` at the repository root with conventions, security rules,
  extension points and a Definition of Done.

### Security

- `.gitignore` blocking `.env`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`,
  `id_ed25519`, `credentials*`, `secrets*`, `token*` and `auth.json`, while
  keeping `.env.example` trackable.
- A local secret scanner for high-confidence credential formats and
  secret-like filenames, wired into `make validate` and CI, documented as a
  heuristic rather than a guarantee.
- No secret, token, credential or private key anywhere in this repository.
- No real `.env` is read by any script.
- No AI provider token is configured; `opencode auth login` owns credentials.

[Unreleased]: https://github.com/LuisOcp2/dev-environment/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/LuisOcp2/dev-environment/releases/tag/v1.0.0