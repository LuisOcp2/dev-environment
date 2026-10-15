# AGENTS.md - project instructions for AI agents

> Copy to the root of your project as `AGENTS.md` and delete this blockquote.
>
> This file is discovered automatically by OpenCode. Keep it short: everything
> here is loaded into every session, so a line that is always true and never
> useful is pure cost.
>
> If this project is also used with Claude Code, `CLAUDE.md` can simply contain
> `@AGENTS.md`.

## What this project is

<One or two sentences: what it does and who uses it.>

## Stack

| Layer | Technology | Version |
|-------|------------|---------|
| ...   | ...        | ...     |

## Commands that actually exist

<Only commands that exist in this repository. Never list a command you have
not seen in `package.json`, `Makefile` or `pyproject.toml`.>

```bash
# Install dependencies
<command>

# Run in development
<command>

# Format
<command>

# Lint
<command>

# Typecheck
<command>

# Test
<command>

# Build
<command>
```

## Project structure

| Path | Purpose |
|------|---------|
| ...  | ...     |

## Conventions

- **Naming**: <rule>
- **File layout**: <rule>
- **Imports**: <rule>
- **Error handling**: <rule>
- **Logging**: <rule>
- **Tests**: <where they live and how they are named>
- **Commits**: <message format, enforced by hooks or not>

## Things that must never be edited

- `<path>` — generated, regenerated with `<command>`
- `<path>` — vendored, upstream owns it
- `<path>` — migrations already applied

## Things that must never be committed

- `.env` and any file containing real credentials
- Generated build output
- IDE-specific settings not listed in the repository's own `.gitignore`

## Definition of done

- [ ] Formatter run
- [ ] Linter run, no new warnings
- [ ] Typecheck passes, no `any` or suppressed errors introduced
- [ ] Tests added or updated, and passing
- [ ] Public behaviour documented when it changed

## Boundaries

Do not, without an explicit request:

- <refactor beyond the current task>
- <add a dependency>
- <change formatting in files outside the current task>
- <modify CI, deployment or infrastructure>
- <commit, push, tag or release>