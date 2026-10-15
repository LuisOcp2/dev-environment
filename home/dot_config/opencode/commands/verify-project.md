---
description: Detect the project stack and run its formatter, linter, typecheck and tests. Never invents scripts.
agent: build
---

Verify this project: detect its stack, run the checks it actually defines, and
report the real results.

Target: `$ARGUMENTS`

## Rules

- **Never invent a command.** Every script you run must be found in the
  project: a `package.json` script, a `Makefile` target, a `pyproject.toml`
  tool, or a documented command in the README or contributing guide.
- **Never modify files** to make a check pass.
- **Never delete, skip or weaken a failing test.**
- Never install a dependency that the project does not already declare.
- If a required tool is missing, report it instead of installing it.

## Procedure

1. **Detect the stack from evidence.** Read, in this order:
   - `package.json` (scripts, package manager field, dependencies)
   - `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lockb`
   - `pyproject.toml`, `requirements.txt`, `uv.lock`, `Pipfile`
   - `pom.xml`, `build.gradle`, `go.mod`, `Cargo.toml`, `composer.json`
   - `Makefile`, `justfile`, `Taskfile.yml`
   - `tsconfig.json`, `.eslintrc*`, `ruff.toml`, `mypy.ini`
   - `Dockerfile`, `docker-compose.yml`, `.github/workflows/`

   Report the detected stack with the file that proves each detection.

2. **Determine the checks that exist**, by reading the actual definitions. Do
   not assume. Report each check as `available` or `not configured`.

3. **Confirm the tooling is installed.** Use `mise current`, `command -v` and
   the lockfiles. If a tool is declared in the lockfile but missing from the
   machine, report it and stop for that check.

4. **Run only the checks that exist**, in this order:
   1. formatter (in check mode, if it supports it)
   2. linter
   3. typecheck
   4. unit and integration tests
   5. build, only if it is cheap and already part of the normal flow

5. **Capture the real output.** Do not summarise a failure as "some warnings".

6. **Stop at the first hard failure** for the dependent steps: if the
   formatter fails, still run the linter, but do not run tests against code
   that failed to format, and say why you stopped.

## Required output

```markdown
## Stack detected
| Signal | File | Finding |
|--------|------|---------|
| Node.js | package.json | present, v22 |
| Package manager | pnpm-lock.yaml | pnpm |
| Python | pyproject.toml | present, ruff + pytest |
| Java | - | absent |

## Checks available in this project
| Check | Command | Source | Status |
|-------|---------|--------|--------|
| format | `pnpm lint:check` | package.json scripts | available |
| typecheck | - | not configured | skipped |

## Results
### `pnpm test`
<real output, trimmed>

## Summary
- Passed: n
- Failed: n
- Not configured: n
- Could not run: <n> — <reason>

## Blockers
- <what must be fixed before the checks can pass>
```

## Completion criteria

- Every command run exists in the project, and the file that defines it is
  cited.
- Every reported result is the real output of a command that ran.
- Checks with no configuration are reported as "not configured", never
  invented.
- No file was modified, no dependency installed, no test deleted.