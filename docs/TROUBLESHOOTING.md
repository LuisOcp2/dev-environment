# Troubleshooting

Start here:

```bash
make doctor     # full environment diagnosis, read only
make verify     # what is installed and what is missing
make validate   # is this repository still consistent
```

`make doctor` never modifies anything.

---

## PATH

**A tool is installed but the shell says `command not found`.**

```bash
# What is actually on PATH?
echo "$PATH" | tr ':' '\n'

# Where is it really?
command -v chezmoi || find "$HOME/.local/bin" -maxdepth 1 -name chezmoi

# Does it exist and is it executable?
ls -l "$HOME/.local/bin/chezmoi"
```

Fix: user-scoped binaries go in `~/.local/bin`, which `~/.profile` adds to
`PATH`. Start a new login shell:

```bash
exec "$SHELL" -l
```

If it still is not there, check that `~/.profile` contains the block that adds
it. It looks like:

```bash
if [ -d "$HOME/.local/bin" ]; then
    case ":${PATH}:" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$HOME/.local/bin:${PATH}" ;;
    esac
fi
```

**`sudo` does not see the PATH.**

That is expected: `sudo` resets `PATH` by default. Nothing here depends on
running `mise` or `chezmoi` under `sudo`.

**PATH entries are duplicated.**

```bash
echo "$PATH" | tr ':' '\n' | sort | uniq -d
```

`make doctor` reports duplicates too. `.profile` and `.zshrc` both guard their
appends, so duplicates should not appear; if they do, something else is
appending to `PATH` in a `.local` file.

---

## mise

**`mise: command not found` after a successful install.**

```bash
ls -l "$HOME/.local/bin/mise"
mise --version
exec "$SHELL" -l
```

**A tool is installed by mise but the wrong version is active.**

```bash
mise current           # active version per tool
mise ls                # configured and installed
mise where node        # where the active node lives
```

The priority is: global `~/.config/mise/config.toml`, then `mise.toml` in the
project, then `mise.local.toml`. A project-level file wins.

```bash
cat mise.toml mise.local.toml 2>/dev/null
```

**`mise install` downloads but the version does not change.**

A project `mise.toml` is overriding the global config. Delete or correct the
local override, or use:

```bash
mise use -g node@22     # change the global default
mise use -p node@22     # write into this project's mise.toml
```

**Shims are not being used.**

```bash
echo "$PATH" | tr ':' '\n' | grep mise
```

`~/.profile` prepends `~/.local/share/mise/shims`. `.zshrc` also runs
`mise activate zsh --shims`, which is the more complete option.

**A tool from the global config is missing entirely.**

```bash
cat "$HOME/.config/mise/config.toml"
ls -l "$HOME/.config/mise/config.toml"
```

If it is missing, the dotfiles were never applied:

```bash
make diff
make apply
```

**`mise` is a much older version than expected.**

```bash
mise --version
./scripts/update.sh --check-only
```

---

## chezmoi

**`chezmoi: command not found`.**

```bash
ls -l "$HOME/.local/bin/chezmoi"
./scripts/install-chezmoi.sh
exec "$SHELL" -l
```

**`chezmoi source-path` fails: chezmoi is not initialised.**

```bash
./scripts/apply-dotfiles.sh --init-only
```

Or the direct equivalent:

```bash
chezmoi init --source "$PWD"
```

**chezmoi initialises but `chezmoi apply` changes nothing.**

```bash
chezmoi source-path     # is it pointing at this repository?
chezmoi managed | head -30
chezmoi diff            # is there anything to apply?
```

`apply-dotfiles.sh` initialises chezmoi with `--source`, so the source is the
local checkout. If `source-path` points somewhere else, you are in the
"chezmoi only" flow from `docs/INSTALLATION.md`, and the local edits are not
part of the source state.

**`chezmoi` wants a Git email every time.**

The answer is stored in `~/.config/chezmoi/chezmoi.toml` under `[data]`.
Force the questions again, or edit that file directly:

```bash
chezmoi init --prompt      # ask again
chezmoi edit-config        # edit the values
```

**A file I created in `$HOME` is not managed.**

```bash
chezmoi add ~/.config/foo/bar.conf
chezmoi diff
chezmoi apply
```

Commit the file under `home/`, not the one in `$HOME`.

**`chezmoi apply` overwrote a local change.**

```bash
chezmoi diff             # see what the managed state expects
git diff --no-index ~/.myfile /tmp/expected   # compare
```

Restore your copy, then re-apply the change properly:

```bash
chezmoi edit ~/.myfile     # change the source, not the target
```

**`chezmoi doctor` reports a problem.**

```bash
chezmoi doctor
```

It usually means the source state has an entry whose target is not writable,
or an `encrypted_` entry without a configured key. This repository uses no
encrypted entries.

---

## Docker

**`docker: command not found`.**

```bash
command -v docker
systemctl status docker
./scripts/install-docker.sh
```

**`permission denied while trying to connect to the Docker daemon`.**

You are not in the `docker` group, or the session predates the change:

```bash
groups
sudo usermod -aG docker "$USER"
```

Then log out and back in, or:

```bash
newgrp docker
```

Note that membership in the `docker` group is equivalent to root access.

**`Cannot connect to the Docker daemon`.**

```bash
sudo systemctl enable --now docker
systemctl status docker
sudo journalctl -u docker -n 50 --no-pager
```

**The Compose plugin is missing.**

```bash
docker compose version
```

`docker-compose` (with a hyphen) is the older Python implementation. The
scripts expect the `docker compose` plugin from `docker-compose-plugin`.

**A container will not start and the log is unhelpful.**

```bash
docker compose ps -a
docker compose logs --tail 50 <service>
```

Check that the port is free:

```bash
ss -tulpn | grep -E '3000|5432|6379'
```

---

## Permissions

**`bootstrap.sh: Permission denied`.**

```bash
chmod +x bootstrap.sh
./bootstrap.sh --dry-run
```

`make validate` fails when a required script is not executable.

**`sudo: command not found`, or a password prompt loops.**

```bash
id -u                       # 0 means root
command -v sudo
```

Inside WSL or a container the user is frequently already root, and
`run_sudo` in `scripts/lib/common.sh` skips `sudo` automatically. If `sudo` is
genuinely missing and the user is not root, a privileged step cannot run.

**`apt-get install` fails with "Unable to locate package".**

```bash
apt-cache policy <package>
```

Optional packages, marked `?` in `packages/*.txt`, are skipped when they are
unavailable. A required package that cannot be resolved is reported by
`install-system-packages.sh` and by `make verify`; either remove it from the
manifest or mark it optional.

**A file in `$HOME` is not writable by chezmoi.**

```bash
ls -l ~/.zshrc
sudo chown "$USER":"$USER" ~/.zshrc
```

---

## VS Code

**`code: command not found`.**

```bash
command -v code
```

On Linux the `code` command comes from the "Shell Command: Install 'code'
command in PATH" option in VS Code, or from the package. When it is absent,
`install-vscode-extensions.sh` skips with a warning instead of failing.

**Extensions were installed but the settings did not apply.**

```bash
ls -l "$HOME/.config/Code/User/settings.json"
```

On some Linux distributions the user settings live at
`~/.config/Code - OSS/User/settings.json` for the OSS build. Apply the file
to the directory VS Code actually reports under *Help -> Open Settings
Folder*.

**An extension ID is not found.**

```bash
code --install-extension <id> --force
```

A deprecated or renamed extension fails with `Unknown extension`. Remove the
entry from `config/vscode-extensions.txt` and reinstall the replacement.

**Two extensions are fighting over formatting.**

That is what `"editor.formatOnSave": false` globally plus an explicit
`"[language]"` block is for. Only one extension is the `defaultFormatter` for
any given language.

---

## OpenCode

Start with the built-in diagnostics, which are read only:

```bash
opencode --version
opencode debug paths      # where data, config, cache and state live
opencode debug config     # which config files load, and in what order
opencode debug agents     # which agents OpenCode actually sees
opencode reload           # force a reload of config, agents, commands, skills
```

| Symptom                              | Cause                                            | Fix                                                     |
| ------------------------------------ | ------------------------------------------------ | ------------------------------------------------------- |
| An agent is missing                  | invalid frontmatter, or the file was never applied | `make validate`, then `chezmoi apply`                  |
| An agent still edits files           | its permissions do not deny `edit`                | add `{ "action": "edit", "resource": "*", "effect": "deny" }` |
| An agent field seems ignored         | a removed V1 field such as `tools`                | use the V2 field set; see `docs/OPENCODE.md`            |
| A skill is never offered             | no `description`, or `metadata.opencode/autoinvoke: false` | rewrite the description with a trigger         |
| A skill has an unexpected ID         | the ID comes from the file path                   | the ID is the directory name, not the `name` field      |
| A command does not appear            | not a `.md` file, or placed in `command/`         | use `commands/`, plural                                 |
| `$ARGUMENTS` appears literally       | it was placed in the frontmatter                  | it must be in the Markdown body                          |
| Configuration errors on start        | invalid JSONC, often a trailing comma             | `make validate` reports the exact file                   |
| Changes not picked up                | stale session or background service               | `opencode reload`, then `opencode service restart`       |
| The service is unresponsive          | the background service is stuck                   | `opencode service status`, `opencode service restart`    |
| A permission is not taking effect    | a project configuration refined it                 | check `opencode debug config` for the effective merge    |

Logs: `~/.local/share/opencode/log/opencode.log`. Filter for `role=server` to
see configuration and permission decisions. Redact API keys, tokens and file
contents before sharing anything from it.

---

## Skills are not detected

```bash
# 1. Are the files actually installed?
ls ~/.agents/skills/
find ~/.agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l

# 2. Is the frontmatter valid?
head -n 5 ~/.agents/skills/code-review/SKILL.md

# 3. Does the repository agree?
./scripts/validate-repository.sh --only skills
```

`make validate` checks, per skill:

- the directory name matches `^[a-z0-9]+(-[a-z0-9]+)*$`
- `SKILL.md` exists and starts with `---`
- `name` exists and equals the directory name
- `description` exists and is long enough to be useful
- all nine required sections are present

If a skill exists in the repository but not in `~/.agents/skills`:

```bash
make diff
make apply
```

Then:

```bash
opencode reload
```

---

## The bootstrap

**Re-running the bootstrap fails or duplicates things.**

It should not: every installer checks for its result first. If it does:

```bash
./bootstrap.sh --dry-run --profile fullstack
```

and read the plan. Report what was duplicated.

**A tool is installed but a stale version is still active.**

```bash
hash -r
command -v <tool>
```

**`make` is not installed.**

```bash
sudo apt-get install -y make
```

The scripts do not need `make`; only the convenience wrappers do.

**The bootstrap refuses to run.**

```bash
./bootstrap.sh --help
```

It exits with an explanation on an unsupported platform, and on Git Bash for
Windows, which is not a target this repository manages.

---

## Still stuck

Collect evidence before asking:

```bash
make doctor            # environment
make verify            # what is installed
make validate          # repository consistency
./scripts/detect-platform.sh
```

When reporting a problem, include the **real output** of those commands and
the exact command you ran. Never include a secret, and never paste the
contents of a real `.env`.