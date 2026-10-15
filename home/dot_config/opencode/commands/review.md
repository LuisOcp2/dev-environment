---
description: Review the current changes for correctness, regressions, security and missing tests. Read only.
agent: build
subagent: true
---

Review the current uncommitted changes.

Focus: `$ARGUMENTS`

## Preferred method

Use the `reviewer` subagent if it is available:

> Use the reviewer subagent to review my current changes.

If the `reviewer` agent is not available, perform the review yourself following
the same checklist.

## Rules

- **Review only.** Do not fix anything, do not edit any file, even a typo.
- Do not commit, stage, stash, reset or push.
- Report findings; Luis decides what to change.

## Steps

1. **Establish the change set.**

   ```bash
   git status --short
   git diff
   git diff --cached
   ```

   If there is nothing to review, say so and stop.

2. **Get context before judging.** For each changed file, read enough of the
   surrounding code to know what the change is supposed to do. A diff without
   context produces false findings.

3. **Review on these axes**, stating explicitly when an axis is clean:
   correctness, regressions, security, concurrency and transactions, error
   handling, resource management, test coverage.

4. **Classify each finding** as `critical`, `high`, `medium` or `low`.

5. **Propose the smallest fix** for each finding, described in words.

## Required output

```markdown
## Change set
- <n> files changed, <n> insertions, <n> deletions

## Findings
### [severity] <title>
- **File**: path
- **Location**: line 42 or `functionName`
- **What**: the defect in one sentence
- **Impact**: the concrete consequence
- **Suggested fix**: the smallest correct change

## Review summary
- **Verdict**: request changes | approve with comments | approve
- **Findings**: n critical, n high, n medium, n low
- **Axes checked and clean**: <list>
- **Missing tests**: <list, or "none">

## Not reviewed
- <what was out of scope>
```

## Completion criteria

- Every finding has a file, a location and a concrete consequence.
- The axes that were checked and found clean are listed explicitly.
- No file was modified.