---
description: Analyse a task and produce a plan. Identify files, risks, tests and phases. Does not implement anything.
agent: plan
---

Produce an implementation plan for the following task.

Task: `$ARGUMENTS`

## Rules

- **Do not implement.** Do not edit, create or delete any file. Do not write
  the code that the plan describes.
- Do not run commands that change state.
- Read whatever you need in order to be accurate, then stop.

## Procedure

1. **Clarify the goal.** Restate the task in one or two sentences. If the
   request is ambiguous in a way that changes the solution, list the
   interpretations instead of guessing.

2. **Inspect the real codebase.** Find the modules, services, tables,
   endpoints and tests involved. Read them. Do not plan against an imagined
   structure.

3. **List the affected files.** Separate:
   - files to create
   - files to modify, with what changes in each
   - files to read but not change
   - generated files that must never be edited by hand

4. **Identify the design decisions.** Anything where two reasonable choices
   exist. State the choice you recommend and why, in one line each. These are
   the decisions Luis should review before you start.

5. **Identify the risks.**
   - breaking change to an existing contract
   - data migration or backfill
   - concurrency or transaction concerns
   - performance or memory impact
   - security or privacy
   - dependency additions
   - rollout and rollback

6. **Define the tests** that will prove the change works, and the ones that
   will prove it does not regress anything. Name the file each will live in.

7. **Define the validation commands** by inspecting the project for what
   actually exists. Never invent a script name.

8. **Split into phases**, each independently reviewable and revertible. The
   first phase should be the smallest thing that produces real signal.

9. **Define done.** Objective, checkable conditions.

## Required output

```markdown
## Goal
<restatement>

## Assumptions
- <assumption, and what breaks if it is wrong>

## Scope
### Create
- `path` — <what it holds>

### Modify
- `path` — <what changes, in one line>

### Read only
- `path`

## Design decisions
| Decision | Options | Recommendation | Why |
|----------|---------|----------------|-----|

## Risks
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|

## Tests
| Test | File | Proves |
|------|------|--------|
| ...  | ...  | ...    |

## Validation commands
```bash
<only commands that exist in the project>
```

## Phases
1. <phase> — <outcome, why it is safe>
2. ...

## Definition of done
- [ ] <checkable condition>

## Open questions
- <what needs an answer from Luis before starting>
```

## Completion criteria

- Every file in the plan was actually read.
- Each phase is independently revertible.
- Every risk has a mitigation.
- Validation commands exist in the project.
- No file was created or modified.