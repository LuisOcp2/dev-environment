# Roadmap

Status legend:

- **Planned** — designed, not implemented
- **In progress** — partially implemented
- **Done** — shipped

Nothing on this list is required to use the repository today.

---

## Done

| Item                                     | Where                                              |
| ---------------------------------------- | -------------------------------------------------- |
| Bash bootstrap with profiles and dry-run | `bootstrap.sh`                                      |
| Cumulative profile resolution            | `scripts/lib/packages.sh`                           |
| Package manifests with optional entries  | `packages/`                                         |
| chezmoi-managed dotfiles                 | `home/`                                             |
| Global runtime versions                  | `home/dot_config/mise/config.toml`                  |
| 16 global AI skills                      | `home/dot_agents/skills/`                           |
| 6 specialised OpenCode agents            | `home/dot_config/opencode/agents/`                  |
| 7 OpenCode commands                      | `home/dot_config/opencode/commands/`                |
| Provider-independent OpenCode config     | `home/dot_config/opencode/opencode.jsonc`           |
| Repository validation in CI              | `scripts/validate-repository.sh`, `.github/workflows/validate.yml` |
| Environment verification and diagnosis   | `scripts/verify.sh`, `scripts/doctor.sh`            |
| Safe update and backup flows             | `scripts/update.sh`, `scripts/backup.sh`            |

---

## WSL2

**Status: planned.** The blockers are real, not cosmetic.

### Why not yet

WSL2 has no systemd by default, the Docker daemon needs a different
installation path, file watching across the `/mnt/c` boundary is slow, and
`chsh` behaves differently. Supporting it properly means modelling the package
manager layer differently rather than adding a flag.

### What it needs

1. `platform.sh` already detects WSL and sets `DETECTED_WSL=true`. Extend
   `is_supported_os` once the install path exists.
2. A `wsl` branch in `scripts/install-system-packages.sh` that enables
   systemd and installs `docker-desktop` or the native engine.
3. Document the `/mnt/c` file-watching limitation and the recommended
   workspace location.
4. Add a `wsl.env` profile that does not assume systemd.

### Interim workaround

Develop inside the Linux filesystem, never on the Windows mount:

```bash
# Slow: crossing the 9p boundary
cd /mnt/c/Users/you/projects

# Fast: native ext4
cd ~/projects
```

---

## macOS

**Status: planned.**

### Why not yet

There is a genuine fork in the road: Homebrew versus `mise` for system tools,
and `chezmoi` handles the dotfiles identically either way. Guessing now would
produce a Linux-shaped solution that is awkward on macOS.

### What it needs

1. `detect_platform` already returns `macos`; add a `macos` case to
   `SUPPORTED_DISTROS` once install works.
2. A `scripts/lib/packages-brew.sh` implementing the manifest contract over
   `brew bundle`.
3. `packages/base.txt` needs a second naming table, like the `fd` to `fd-find`
   mapping that already exists for Debian.
4. macOS-specific dotfiles: `brew` shellenv in `~/.zprofile`, a
   `gnu-sed`/`gawk` shim, no `readlink -f`.
5. A `macos` path in `scripts/install-docker.sh` using the official `.dmg`
   instead of the apt repository.

### Deliberately out of scope

No Homebrew bundle will be generated from the Linux manifests. The two are
different systems; pretending otherwise is how a config becomes unmaintainable.

---

## Ansible

**Status: planned, low priority.**

This repository deliberately does **not** use Nix and does not currently use
Ansible. That is a considered choice, not an oversight.

### What already exists that makes Ansible easy

- Profiles are declarative and cumulative.
- Package manifests are plain text.
- Every script is idempotent and has a dry-run mode.
- There is no mutable state to reconcile.

### What an Ansible layer would add

```yaml
# roles/dev-environment/tasks/main.yml
- name: Include the profile variables
  include_vars: "{{ profile }}.yml"

- name: Install system packages
  apt:
    name: "{{ packages }}"
    state: present
    update_cache: true
```

The value would be for **several machines at once**: a laptop, a workstation,
a lab VM, a CI runner. For a single machine, `bootstrap.sh` is faster to read
and easier to debug.

### When to adopt it

When the fourth machine appears, or when a team shares the configuration.

---

## Dev Containers

**Status: templates shipped, automation planned.**

Available now:

- `templates/devcontainer/devcontainer.json`
- `templates/devcontainer/compose.yml`
- `templates/mise/mise.toml`

### Next

- [ ] A `make devcontainer` target that copies the templates into the current
      project
- [ ] A profile flag `devcontainers` that installs the extension
- [ ] Validation that a `devcontainer.json` is valid JSONC before commit
- [ ] A prebuilt image published for the standard full-stack toolchain, so a
      project does not install Node and Python on every cold start

---

## CI improvements

**Status: partial.** `.github/workflows/validate.yml` runs the full validation
suite on pull requests and pushes to `main`.

Already covered:

- [x] `bash -n` over every shell file
- [x] shellcheck
- [x] shfmt formatting
- [x] JSON and JSONC validity
- [x] skill structure, frontmatter and name/directory agreement
- [x] agent and command frontmatter, including rejection of removed V1 fields
- [x] obvious secret patterns and secret-like filenames
- [x] executable bits on required scripts
- [x] repository structure invariants

Planned:

- [ ] `shfmt -w` auto-fix on push, so formatting is never a review comment
- [ ] A reusable workflow, so other repositories can run the same suite
- [ ] A scheduled weekly job that re-runs validation on `main` with current
      tool versions, to catch a breaking shellcheck release
- [ ] Dependency update automation with a human review gate
- [ ] A matrix job that runs `bootstrap.sh --dry-run` on `ubuntu-22.04`,
      `ubuntu-24.04` and `tuxedo`-equivalent images
- [ ] A `codespell` pass
- [ ] Markdown link checking
- [ ] Action pinning enforced by a policy check

### Deliberately never added

- No step applies dotfiles to the runner.
- No step installs software on the runner.
- No step reaches a personal account or credential store.

---

## Virtual machine test matrix

**Status: planned.**

The most valuable missing test: does the bootstrap actually produce a working
machine?

### Target matrix

| Image                          | Profiles                    | Runner            |
| ------------------------------ | --------------------------- | ----------------- |
| Ubuntu 22.04 LTS, minimal      | `minimal`, `fullstack`      | GitHub Actions    |
| Ubuntu 24.04 LTS, minimal      | `minimal`, `fullstack`      | GitHub Actions    |
| TuxedoOS 4, minimal            | `minimal`                   | self-hosted VM    |
| Debian 12, minimal             | `minimal`                   | GitHub Actions    |

### What each run asserts

```bash
./bootstrap.sh --profile <p> --yes
make verify
```

- `make verify` exits `0`
- `git`, `chezmoi`, `mise`, `zsh`, `fzf` are on `PATH`
- `chezmoi source-path` resolves and `chezmoi diff` is empty
- a second `./bootstrap.sh --dry-run` reports nothing to change
- `~/.zshrc` and `~/.profile` are byte-identical to the source state

### Idempotency assertion

```bash
./bootstrap.sh --profile minimal --yes
state_before="$(find "$HOME" -maxdepth 2 -newer /tmp/marker | sort)"
./bootstrap.sh --profile minimal --yes
state_after="$(find "$HOME" -maxdepth 2 -newer /tmp/marker | sort)"
diff <(echo "$state_before") <(echo "$state_after")
```

An empty diff is the pass condition. This is the test that actually matters
and the one that does not exist yet.

---

## Smaller improvements

- [ ] `bootstrap.sh --uninstall` that reports what it would remove, without
      removing anything automatically
- [ ] `scripts/sync-documentation.sh` that checks every profile and manifest
      is mentioned in `README.md`
- [ ] Shell completion for `bootstrap.sh` and the `scripts/`
- [ ] `justfile` for people who prefer `just` to `make`
- [ ] Per-skill smoke tests that assert the required sections appear in the
      loaded output
- [ ] A `templates/opencode/` set mirroring `templates/project-agents/`
- [ ] Spanish and English READMEs, linked from each other

---

## Explicit non-goals

Stating these prevents scope creep as much as a roadmap does.

| Not doing                                   | Why                                                      |
| ------------------------------------------- | -------------------------------------------------------- |
| Nix                                          | a different mental model; the manifests already work    |
| A framework or a plugin system for this repo | the scripts are the interface and they are readable      |
| Auto-upgrading the operating system          | never run unattended                                     |
| Managing secrets                             | a password manager is the right tool                     |
| Pinning an AI model or provider             | a personal, machine-local decision                       |
| Auto-pushing from a validation script       | a human decides what leaves the machine                  |
| Generating the docs from the code           | generated documentation nobody reads is worse than none   |