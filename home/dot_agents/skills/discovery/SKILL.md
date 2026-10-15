---
name: discovery
description: Investigate an unfamiliar codebase or repository before changing anything. Use this when you need to understand what a project does, where a feature lives, how components connect, or what conventions an existing codebase follows before proposing a change.
---

# Discovery

## Objective

Build an accurate, evidence-based mental model of an unfamiliar codebase
before writing a line of code, so that later changes match reality instead of
an assumption.

## When to use

- First contact with a repository you have never seen.
- A request that mentions behaviour ("the checkout flow") instead of a file
  path.
- Before estimating work, so the estimate is based on what exists.
- Before adding a feature, to find the existing pattern that already solves a
  similar problem.

## When not to use

- You already know the exact file and the exact change.
- The task is a one-line typo fix with an obvious location.
- The user has already described the structure and asked for an immediate
  edit.

## Required inputs

- The repository root or the path to explore.
- The goal: what the discovery is supposed to enable.
- Optionally, a time or depth budget.

## Procedure

1. **Anchor on the documentation.** Read, in this order: `README.md`,
   `AGENTS.md`, `CONTRIBUTING.md`, `docs/`, the changelog. Extract: what the
   project is for, how it is built, how it is tested, and what conventions
   are stated.

2. **Identify the stack from evidence.** Look for `package.json`,
   `pyproject.toml`, `go.mod`, `pom.xml`, `Cargo.toml`, `composer.json`,
   `requirements.txt`, lockfiles, `Dockerfile`, CI workflow files. Record the
   file that proves each detection.

3. **Map the directory structure one or two levels deep.** For each top-level
   directory, answer in one line: what lives here and why. Ignore
   `node_modules`, `dist`, `build`, `target`, `vendor`, `.git`.

4. **Find the entry points.** The `main`, the CLI definition, the server
   bootstrap, the framework config, the `package.json` `bin` field.

5. **Locate the subsystem in question.** Use `glob` for structure and `grep`
   for symbols. Find at least one existing implementation of something
   similar; it is the pattern you must follow.

6. **Trace one path end to end.** Follow a single realistic request or command
   from entry point to persistence and back. This reveals the layering that
   no README describes.

7. **Identify the conventions.** Naming, file layout, error handling, logging,
   test style, dependency injection, commit style. Cite a file for each.

8. **Identify the hazards.** Generated files that must not be edited, code
   generators, migrations, vendored code, monorepo boundaries, anything with
   a "do not edit" header.

9. **Summarise, then stop.** Do not start implementing. Return the model.

## Constraints

- Never edit, create or delete a file during discovery.
- Never install a dependency to explore a project.
- Never claim a file or symbol exists without having read or grepped it.
- Prefer reading real code over reading documentation about the code. When
  they disagree, the code wins and the disagreement is reported.

## Validation checklist

- [ ] README and project instructions read
- [ ] Stack detected, each with the file that proves it
- [ ] Entry points identified
- [ ] The relevant subsystem located, with file paths
- [ ] At least one similar existing implementation found
- [ ] One end-to-end path traced
- [ ] Conventions listed, each with a citation
- [ ] Hazards listed (generated files, boundaries, migrations)
- [ ] No file was modified

## Mandatory output format

```markdown
## What this project is
<two sentences, in the project's own terms>

## Stack
| Component | Technology | Evidence (file) |
|-----------|------------|-----------------|

## Structure
| Path | Purpose |
|------|---------|

## Entry points
- `<path>` — <what starts here>

## Where the requested work lives
- `<path>` — <responsibility>

## Similar existing implementation to follow
- `<path>` — <why it is the right pattern>

## End-to-end path traced
1. `<file:line>` — <what happens>

## Conventions observed
- **Naming**: <rule> — evidence `<path>`
- **Error handling**: <rule> — evidence `<path>`
- **Tests**: <rule> — evidence `<path>`

## Hazards
- `<path>` — generated / vendored / migration — <do not edit because>

## Unknowns
- <what could not be determined and what would resolve it>
```

## Completion criteria

- Every path mentioned was actually read or listed.
- The reader could now navigate to the right place without re-searching.
- No file was modified.
- Unknowns are stated explicitly rather than filled with assumptions.