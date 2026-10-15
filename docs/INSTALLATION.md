# Installation

Every command below is copy-pasteable. Replace the profile where it says so.

## Supported platforms

| Platform                 | Status    | Package manager |
| ------------------------ | --------- | --------------- |
| Ubuntu                   | supported | `apt`           |
| TuxedoOS (Ubuntu based)  | supported | `apt`           |
| Debian                   | supported | `apt`           |
| WSL2 Ubuntu              | planned   | see `ROADMAP.md`|
| macOS                    | planned   | not implemented |
| Windows Git Bash         | refused   | `bootstrap.sh` exits with an explanation |

To check what the scripts detect on your machine:

```bash
./scripts/detect-platform.sh
```

## Prerequisites

On a fresh Ubuntu or TuxedoOS installation you already have everything except
`git`:

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates
```

| Requirement | Minimum | Check with         |
| ----------- | ------- | ------------------ |
| bash        | 4.4     | `bash --version`   |
| git         | 2.34    | `git --version`    |
| curl        | -       | `curl --version`   |
| Ubuntu / TuxedoOS | 22.04+ | `lsb_release -ds` |

`git` and `curl` are the only hard requirements. `chezmoi` and `mise` are
installed by the bootstrap.

## Method A — clone and bootstrap (recommended)

This is the flow the repository is designed around. It keeps a normal Git
checkout that you can edit, and points chezmoi at it.

```bash
git clone https://github.com/LuisOcp2/dev-environment.git
cd dev-environment

# See the plan without changing anything. Always do this first.
./bootstrap.sh --profile fullstack --dry-run

# Install for real.
./bootstrap.sh --profile fullstack

# Confirm the result.
make verify
```

Using SSH instead of HTTPS, when SSH keys are already configured:

```bash
git clone git@github.com:LuisOcp2/dev-environment.git
cd dev-environment
./bootstrap.sh --profile fullstack
```

### What the bootstrap does

1. Detects the OS, distribution and architecture.
2. Loads `config/defaults.env` and resolves the profile.
3. Prints the plan and asks for confirmation.
4. Installs the apt packages declared by the profile's manifests.
5. Installs `chezmoi` into `~/.local/bin`.
6. Installs `mise` into `~/.local/bin` and the declared tool versions.
7. Installs Docker, only when the profile enables the `docker` flag.
8. Installs VS Code extensions, only when the profile enables `vscode`.
9. Shows `chezmoi diff`, then applies after a second confirmation.
10. Runs `scripts/verify.sh` and prints a summary.

### Non-interactive runs

```bash
./bootstrap.sh --profile fullstack --yes
```

`--yes` approves every confirmation. Use it only in a throwaway VM or a CI
image.

### Options

| Option              | Effect                                              |
| ------------------- | --------------------------------------------------- |
| `--profile <name>`  | `minimal`, `frontend`, `backend`, `fullstack`, `cloud`, `teaching` |
| `--yes`, `-y`        | assume yes for every confirmation                    |
| `--dry-run`         | print the plan, change nothing                      |
| `--skip-docker`     | do not install or configure Docker                  |
| `--skip-vscode`     | do not install VS Code extensions                   |
| `--skip-dotfiles`   | do not apply the dotfiles                            |
| `--list-profiles`   | print the profiles and exit                         |
| `--help`, `-h`      | print the help                                       |

## Method B — chezmoi only

Use this when you want chezmoi to own the dotfiles and you do not need the
package installation, or when the machine already has the tools.

### Public repository, over HTTPS

```bash
# Install chezmoi first if it is not present.
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

chezmoi init --apply https://github.com/LuisOcp2/dev-environment.git
```

### Over SSH

```bash
# The --ssh flag tells chezmoi to build an SSH URL instead of an HTTPS one.
chezmoi init --apply --ssh LuisOcp2/dev-environment
```

The full SSH form is equivalent:

```bash
chezmoi init --apply git@github.com:LuisOcp2/dev-environment.git
```

### Private repository, over SSH

This is the flow to use for a private dotfiles repository. It requires a
deploy key on GitHub or a key already registered on the account.

1. Create a dedicated key. Do not reuse a personal key for automation.

   ```bash
   ssh-keygen -t ed25519 -C "dev-environment-chezmoi" -f ~/.ssh/chezmoi_deploy_key
   ```

2. Add the **public** key (`~/.ssh/chezmoi_deploy_key.pub`) as a deploy key in
   the GitHub repository under *Settings -> Deploy keys*. Do not enable write
   access; chezmoi only needs read.

3. Add the host key so chezmoi uses this key without prompting:

   ```bash
   ssh-keyscan github.com >> ~/.ssh/known_hosts
   ```

4. Initialise:

   ```bash
   chezmoi init --apply \
     --config "$HOME/.config/chezmoi/chezmoi.toml" \
     git@github.com:LuisOcp2/dev-environment.git
   ```

5. Tell chezmoi which host and key to use by adding a host block to
   `~/.ssh/config` — this file is intentionally **not** managed by chezmoi:

   ```ini
   Host github.com
     HostName github.com
     User git
     IdentityFile ~/.ssh/chezmoi_deploy_key
     IdentitiesOnly yes
   ```

6. Verify:

   ```bash
   chezmoi source-path
   chezmoi diff
   make verify
   ```

### Private repository, over HTTPS with a token

Supported by chezmoi, but the token must never be stored in this repository:

```bash
chezmoi init --apply \
  https://<YOUR_GITHUB_TOKEN>@github.com/LuisOcp2/dev-environment.git
```

Better, when a credential helper is configured:

```bash
gh auth login
chezmoi init --apply https://github.com/LuisOcp2/dev-environment.git
```

After initialisation, run `chezmoi edit-config` and set `repo = "origin"` so
subsequent `chezmoi update` calls do not carry the token in the URL.

## What the dotfiles install

| Target                                  | Purpose                                   |
| --------------------------------------- | ----------------------------------------- |
| `~/.gitconfig`                          | identity, `main`, prune, safe aliases      |
| `~/.zshrc`                              | recommended interactive shell              |
| `~/.bashrc`                             | working fallback shell                    |
| `~/.profile`                            | shared login environment                  |
| `~/.tmux.conf`                          | multiplexer, `C-a` prefix                 |
| `~/.config/starship.toml`               | prompt                                     |
| `~/.config/mise/config.toml`            | global tool versions                      |
| `~/.config/git/ignore`                  | global Git excludes                       |
| `~/.config/opencode/`                   | AI configuration, agents, commands        |
| `~/.agents/skills/`                     | reusable AI skills                         |
| `~/.config/Code/User/`                  | VS Code settings and keybindings           |

On first `chezmoi init` you are asked for a Git email, a default branch, a
pull strategy, an editor and a login shell. The answers are stored in
`~/.config/chezmoi/chezmoi.toml`, which is local state and is never committed.

To be asked again:

```bash
chezmoi init --prompt
```

## After installing

```bash
# Load the new shell configuration.
exec "$SHELL" -l

# Install the developer tooling that apt cannot provide.
make dev-tools

# Install VS Code extensions.
make vscode-extensions

# Confirm everything is in place.
make verify
make doctor
```

`make dev-tools` installs starship, the direnv hook and the OpenCode CLI. All
three are optional: the environment works without them.

## Troubleshooting the installation

```bash
# Full environment diagnosis, read only.
make doctor

# What would chezmoi change?
make diff
```

Common problems are documented in `docs/TROUBLESHOOTING.md`.

## Uninstalling

Nothing here is destructive by default. To detach chezmoi from this
repository without deleting your dotfiles:

```bash
chezmoi purge
```

To remove a single managed file:

```bash
chezmoi rm ~/.zshrc
```

To see exactly what chezmoi manages:

```bash
chezmoi managed
```

Removing the packages themselves is deliberately manual: this repository never
uninstalls software, because it cannot know what else depends on it.