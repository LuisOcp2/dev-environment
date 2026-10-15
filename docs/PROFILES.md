# Profiles

A profile is a declarative, cumulative description of what a development
machine needs. Profiles reference package manifests and declare tool
versions; they never contain a list of packages directly.

## Available profiles

```bash
./bootstrap.sh --list-profiles
```

| Profile     | Inherits             | Installers                                                                 | Runtime tools                          |
| ----------- | -------------------- | ------------------------------------------------------------------------- | -------------------------------------- |
| `minimal`   | -                    | Git, curl, wget, jq, build-essential, zsh, tmux, fzf, bat, ripgrep, fd, shellcheck, direnv | `shfmt`                |
| `frontend`  | `minimal`            | minimal + image and diagram tooling                                        | `node` 22, `pnpm` 10                   |
| `backend`   | `minimal`            | minimal + PostgreSQL, MySQL and Redis clients                              | `node`, `pnpm`, `python` 3.12, `uv`, `java` 21 |
| `fullstack` | `frontend`, `backend`| all of the above + native build dependencies for Node modules              | all of the above                       |
| `cloud`     | `minimal`            | minimal + JDK 21, optional `kubectl`                                       | `terraform`, `kubectl`                 |
| `teaching`  | `minimal`            | minimal + JDK, git-gui, graphviz, pandoc                                   | `node`, `pnpm`, `python`, `java`       |

`fullstack` is the default.

## How profiles accumulate

```
minimal
  ├── frontend ──┐
  │              ├── fullstack
  └── backend ───┘

minimal ─── cloud
minimal ─── teaching
```

`fullstack` inherits from two profiles. Resolution walks the parents first,
appends their manifests, tools and flags, and de-duplicates the result.
`bootstrap.sh` prints the resolved result before doing anything:

```bash
./bootstrap.sh --profile fullstack --dry-run
```

## Profile variables

Defined in `config/profiles/<name>.env`:

| Variable             | Meaning                                                        |
| -------------------- | -------------------------------------------------------------- |
| `PROFILE_DESCRIPTION`| one-line summary shown by `--list-profiles`                     |
| `PROFILE_INHERITS`   | space-separated parent profiles, applied first                  |
| `PACKAGE_SETS`       | space-separated manifests from `packages/`                      |
| `MISE_TOOLS`         | space-separated tool identifiers for mise                      |
| `PROFILE_FLAGS`      | space-separated feature flags                                   |

### Feature flags

| Flag        | Effect                                                        |
| ----------- | ------------------------------------------------------------- |
| `docker`    | `bootstrap.sh` runs `scripts/install-docker.sh`               |
| `vscode`    | `bootstrap.sh` runs `scripts/install-vscode-extensions.sh`    |
| `cloud`     | marks the profile as infrastructure oriented                   |
| `teaching`  | marks the profile as classroom oriented                        |

A flag never installs anything by itself. It only decides which script the
bootstrap calls, and that script still asks for confirmation.

## Package manifests

| Manifest      | Contents                                                     |
| ------------- | ------------------------------------------------------------ |
| `base.txt`    | the minimum useful machine: shell, git, search tools          |
| `fullstack.txt` | native dependencies for Node modules and containers           |
| `database.txt`| PostgreSQL, MySQL and Redis **clients** only, never servers   |
| `cloud.txt`   | lightweight cloud tooling; heavy CLIs are optional            |
| `design.txt`  | image, diagram and headless-browser tooling                    |
| `teaching.txt`| classroom tooling: JDK, git-gui, pandoc                       |

### Manifest syntax

```
# A comment. Blank lines are ignored.
build-essential          # required: an error if apt cannot resolve it
?pkg-config              # optional: skipped silently when unavailable
```

| Prefix | Meaning                                                      |
| ------ | ------------------------------------------------------------ |
| none   | required; the bootstrap fails if apt does not provide it       |
| `?`    | optional; skipped with a `SKIPPED` message when unavailable    |

This is what keeps `cloud.txt` honest: `?kubectl` is present in the manifest,
so the intent is documented, but a machine without `kubectl` in its
repositories installs cleanly.

### Distro naming

`scripts/lib/packages.sh` maps manifest names to the package name on the local
distribution. Today the only mapping is `fd` to `fd-find` on Debian
derivatives, plus a user-level `fd` shim created in `~/.local/bin` so the
command name is consistent everywhere.

## Creating a new profile

### 1. Create the manifest, if the packages are new

`packages/dataeng.txt`:

```
# dataeng.txt - data engineering tooling.
duckdb-tools
?dbt-core
python3-pandas
```

### 2. Create the profile

`config/profiles/dataeng.env`:

```bash
# dataeng.env - data engineering workstation.

PROFILE_DESCRIPTION="dataeng - Python data stack with DuckDB"

PROFILE_INHERITS="backend"
PACKAGE_SETS="dataeng"
MISE_TOOLS="python uv duckdb"
PROFILE_FLAGS="vscode"
```

`MISE_TOOLS` is a declaration of intent: it is printed in the plan and used
by `scripts/install-mise.sh` for reporting. The versions themselves come from
`home/dot_config/mise/config.toml`.

### 3. Validate

```bash
make validate
./bootstrap.sh --profile dataeng --dry-run
```

`make validate` fails if a profile references a manifest that does not exist,
so a typo is caught before it reaches a machine.

### 4. Document it

Add a row to the table at the top of this file and update the profile list in
`README.md` and in `bootstrap.sh --help`.

## Adding a package to an existing profile

1. Append the package to the right manifest under `packages/`.
2. Mark it `?` if it may be unavailable.
3. Validate and preview:

   ```bash
   make validate
   ./bootstrap.sh --profile fullstack --dry-run
   ```

No script changes are required.

## Installing optional cloud tooling

Deliberately not part of any profile, because each has a different supported
installation path:

```bash
# kubectl and Terraform through the mise registry plugins.
mise use -g kubectl@latest
mise use -g terraform@latest

# AWS CLI through pipx or uv, both of which keep it out of the system python.
uv tool install awscli
pipx install awscli

# Azure CLI through its own repository or snap.
snap install azure-cli --classic
```

Once installed, add the tool name to `MISE_TOOLS` in the profile so
`make verify` reports it.

## Skipping parts of a profile

| Need                          | Command                                  |
| ----------------------------- | ---------------------------------------- |
| No Docker                     | `./bootstrap.sh --profile fullstack --skip-docker` |
| No VS Code extensions         | `./bootstrap.sh --profile fullstack --skip-vscode` |
| Tools only, no dotfiles       | `./bootstrap.sh --profile fullstack --skip-dotfiles` |
| Completely non interactive    | `./bootstrap.sh --profile fullstack --yes` |
| See it all, change nothing    | `./bootstrap.sh --profile fullstack --dry-run` |

## Listing what a profile resolves to

```bash
make packages PROFILE=fullstack
```

This prints the exact package list the installer would process, in order.