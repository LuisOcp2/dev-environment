# Pull request

## What this changes

<!-- One or two sentences. What is the user-visible effect? -->

## Why

<!-- The problem being solved. Link the issue if there is one. -->

Closes #

## Type of change

- [ ] Package or profile
- [ ] Dotfile or configuration
- [ ] Script or library
- [ ] AI skill
- [ ] OpenCode agent or command
- [ ] Documentation
- [ ] CI or tooling

## How it was validated

<!-- Paste the real output. Do not describe it. -->

```bash
make validate
make dry-run
make verify
```

- [ ] `make validate` exits `0`
- [ ] `make dry-run` shows the expected plan and modifies nothing
- [ ] Running the change twice is a no-op
- [ ] The README describes the real behaviour

## Files touched

<!--
  The design goal is that an addition edits exactly one file.
  If this PR touches more than one, explain why the design required it.
-->

-

## Checklist

### Correctness

- [ ] `bash -n` passes on every `.sh`
- [ ] shellcheck reports no warnings or errors
- [ ] `shfmt -i 2 -ci -sr -kp` reports no diff
- [ ] JSON and JSONC files parse
- [ ] The change is idempotent

### AI layer

- [ ] Skill frontmatter is valid and `name` equals the directory name
- [ ] Agent and command frontmatter uses OpenCode V2 fields only
- [ ] No `model` or provider is pinned
- [ ] Permissions default to deny for anything destructive

### Security

- [ ] No secret, token, key or credential was added
- [ ] No real `.env` was read
- [ ] No machine-specific absolute path was hardcoded
- [ ] Anything destructive asks for confirmation first
- [ ] I checked the diff for anything that looks like a credential

### Documentation

- [ ] Documentation was updated in this same change
- [ ] New behaviour is documented where a reader would look for it

### Git

- [ ] The commit message is in English, imperative mood, under 72 characters
- [ ] Nothing was pushed automatically

## Notes for the reviewer

<!--
  Anything a reviewer should know: a decision you were unsure about,
  a risk you accepted, or something you deliberately left out.
-->