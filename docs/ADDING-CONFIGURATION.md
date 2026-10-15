# Adding configuration

Everything in this repository is designed so that adding something should not
require editing an existing script. This document is the map.

## Where does my change go?

| I want to add...                | Edit                                                |
| ------------------------------- | --------------------------------------------------- |
| a system package                | `packages/*.txt`                                     |
| an installation profile         | `config/profiles/<name>.env`                         |
| a default value                 | `config/defaults.env`                                |
| a VS Code extension             | `config/vscode-extensions.txt`                       |
| a dotfile                       | a file under `home/`                                 |
| a tool version                  | `home/dot_config/mise/config.toml`                   |
| a skill                         | `home/dot_agents/skills/<name>/SKILL.md`             |
| an OpenCode agent               | `home/dot_config/opencode/agents/<name>.md`          |
| an OpenCode command             | `home/dot_config/opencode/commands/<name>.md`        |
| a script                        | `scripts/<name>.sh`                                  |
| shared script logic             | `scripts/lib/<name>.sh`                              |
| a template to copy              | `templates/<kind>/`                                  |
| documentation                   | `docs/` and `README.md`                              |

---

## Adding a dotfile

### 1. Create the source file under `home/`

chezmoi translates names to targets:

| Source file                        | Target                             |
| ---------------------------------- | ---------------------------------- |
| `home/dot_config/foo/bar.conf`     | `~/.config/foo/bar.conf`           |
| `home/dot_zshrc`                   | `~/.zshrc`                         |
| `home/dot_config/app/settings.json`| `~/.config/app/settings.json`      |
| `home/dot_local/bin/mytool`        | `~/.local/bin/mytool`              |

Rules:

- `dot_` marks a dotfile. `_` in a name becomes `/` in the target.
- `executables_` marks a file that must be `0755`, for example
  `executables_local/bin/mytool`.
- `private_` marks a file that must be `0600`. **Nothing in this repository
  uses it**, because nothing here is secret.
- `exact_` marks a filename that would otherwise be interpreted, for example
  `exact_.gitignore`.
- Suffix a file with `.tmpl` to make chezmoi render it as a Go template.

### 2. Add it to `.chezmoiignore` if it should never be applied

`home/.chezmoiignore` is the right place for anything that would otherwise be
swept up by `chezmoi add $HOME`, such as caches or machine-local state.

### 3. Review before applying

```bash
chezmoi managed                       # what chezmoi knows about
chezmoi diff                          # what would change in $HOME
chezmoi cat ~/.config/foo/bar.conf    # the rendered content, without writing it
```

### 4. Apply

```bash
chezmoi apply
```

Or, from this repository:

```bash
make diff      # preview only
make apply     # preview, then apply
```

### 5. Commit the source, never the target

```bash
git add home/dot_config/foo/bar.conf
git commit -m "feat(dotfiles): add foo configuration"
```

`~/.config/foo/bar.conf` is output. Committing it would create a second source
of truth that immediately drifts.

## Adopting an existing dotfile

For a file that already exists on the machine and you want chezmoi to own:

```bash
# 1. Preview what would be added.
chezmoi add --dry-run ~/.config/foo/bar.conf

# 2. Add it.
chezmoi add ~/.config/foo/bar.conf

# 3. Look at what was created, adjust the comments, then confirm.
chezmoi diff

# 4. Apply and commit.
chezmoi apply
git add home/
git commit -m "feat(dotfiles): adopt existing foo configuration"
```

Do this one file at a time. Adding `$HOME` wholesale in a single command
creates an unreviewable diff.

## Adding configuration manually

Sometimes a file must not be managed, because it is machine-specific or
because it contains a value only this machine should have.

This repository provides three such escape hatches, and they are the only
three:

| File                       | Loaded by          | Managed by chezmoi |
| -------------------------- | ------------------ | ------------------ |
| `~/.profile.local`         | `~/.profile`       | no                 |
| `~/.zshrc.local`           | `~/.zshrc`         | no                 |
| `~/.bashrc.local`          | `~/.bashrc`        | no                 |

Create them once:

```bash
touch ~/.zshrc.local
```

**Never put a secret in these files.** They are untracked but not protected;
use a password manager or an exported environment variable. See
`docs/SECURITY.md`.

## Adding a script

```bash
#!/usr/bin/env bash
#
# my-script.sh - one sentence describing what it does.
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

enable_error_trap

usage() {
  cat <<'EOF'
Usage: ./scripts/my-script.sh [options]
...
EOF
}

main() {
  log_step "My script"
  # Use run / run_sudo so --dry-run works automatically.
  run git --version
  log_success "done"
}

main "$@"
```

Checklist for a new script:

- [ ] `#!/usr/bin/env bash` and `set -Eeuo pipefail`
- [ ] Sources `scripts/lib/common.sh` by absolute path, with a shellcheck
      directive
- [ ] `enable_error_trap`
- [ ] A `usage()` function and a `--help` flag
- [ ] Every side effect goes through `run`, `run_sudo` or `run_shell`
- [ ] Idempotent: check for the result before creating it
- [ ] `chmod +x`
- [ ] `make validate` passes
- [ ] Documented in `README.md`

## Adding shared logic

If two scripts need the same function, it belongs in `scripts/lib/`:

1. Create `scripts/lib/<name>.sh`.
2. Guard it against double sourcing:

   ```bash
   if [[ -n "${DEV_ENV_MYNAME_LOADED:-}" ]]; then
     return 0
   fi
   DEV_ENV_MYNAME_LOADED=1
   ```

3. Source it from `common.sh` if it needs `logging`, or from the entry points
   that need it.
4. Document it in the library table in `docs/ARCHITECTURE.md`.

Never copy a function between scripts. Duplication is how two environments
drift.

## Adding a tool version

```bash
# 1. Edit the global config.
$EDITOR home/dot_config/mise/config.toml

# 2. Check what it now declares.
mise ls

# 3. Install.
mise install

# 4. Preview the dotfile change.
make diff
make apply
```

Pin to a major version (`node = "22"`), not `latest`, unless the tool is
pre-1.0 where the major line is not meaningful.

## Adding a package

```bash
# 1. Append to the right manifest, using `?` when optional.
echo '?libsqlite3-dev' >> packages/database.txt

# 2. Validate that no profile points at a missing manifest.
make validate

# 3. Preview the resolved list.
make packages PROFILE=backend
```

## Adding a profile

See `docs/PROFILES.md`. In short:

```bash
cat >config/profiles/myprofile.env <<'EOF'
PROFILE_DESCRIPTION="myprofile - what this machine is for"
PROFILE_INHERITS="minimal"
PACKAGE_SETS="base"
MISE_TOOLS="node"
PROFILE_FLAGS=""
EOF

make validate
./bootstrap.sh --profile myprofile --dry-run
```

Then update the profile tables in `README.md`, `docs/PROFILES.md` and the
`--help` output of `bootstrap.sh`.

## Testing on a clean machine

The only honest test of a dotfiles change is a clean machine.

### Using a VM

```bash
# Ubuntu Server 22.04 or later, minimal install, no desktop.
# Then, inside the VM:
sudo apt-get update && sudo apt-get install -y git curl
git clone https://github.com/LuisOcp2/dev-environment.git
cd dev-environment
./bootstrap.sh --profile fullstack
make verify
```

### Using a container

```bash
docker run --rm -it \
  -v "$PWD:/repo" \
  -v "$HOME/.ssh:/root/.ssh:ro" \
  ubuntu:24.04 bash -c '
    apt-get update -qq && apt-get install -y -qq git curl ca-certificates &&
    cd /repo &&
    ./bootstrap.sh --profile minimal --dry-run
  '
```

The container test validates the *plan* and the scripts; it does not validate
systemd, Docker or a desktop environment.

### What to check after any change

```bash
make validate          # the repository is still consistent
make diff              # chezmoi will do what you expect
make apply             # apply it
make verify            # the machine is still healthy
./bootstrap.sh --dry-run --profile minimal   # idempotent re-run is a no-op
```

The last one is the idempotency test: running the bootstrap again must not
duplicate a configuration entry and must not fail.

## Definition of done for any change

See `AGENTS.md` at the repository root for the full checklist. In short:

- [ ] `make validate` passes
- [ ] `make dry-run` shows the expected plan and modifies nothing
- [ ] The README describes the real behaviour
- [ ] The change is idempotent
- [ ] Validations that could not run are reported, not assumed