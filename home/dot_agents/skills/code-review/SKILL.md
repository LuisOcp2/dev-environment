---
name: code-review
description: Review code or a diff for correctness, regressions, security, concurrency, error handling and missing tests, and report findings by severity. Use this before merging, when reviewing a pull request, or when auditing a module you did not write.
---

# Code Review

## Objective

Find the defects that a merge should block, report them with enough evidence
to act on, and leave the codebase unchanged.

## When to use

- Before merging a change.
- Reviewing a pull request from another developer, or from another agent.
- Auditing a module you did not write.
- Before a release, on the diff since the last tag.

## When not to use

- The author is asking for help implementing, not reviewing.
- A purely mechanical change with no logic, such as a lockfile bump. Check it
  is consistent and stop.
- You are reviewing code you just wrote and have not run; run it first.

## Required inputs

- The change set: `git diff`, `git diff --cached`, or the pull request.
- Enough surrounding context to understand the intent.
- The stated intent, from the commit message, the issue or the author.

## Procedure

1. **Establish the change set.**

   ```bash
   git status --short
   git diff --stat
   git diff
   git diff --cached
   ```

   If there is nothing to review, say so and stop.

2. **Read for intent first.** The commit message, the issue, the description.
   A defect that the author clearly did not intend is still a defect, but the
   framing changes whether it is a misunderstanding or a mistake.

3. **Gather context before judging.** Read the whole function, not the hunk.
   Read the callers and the tests. A diff without context produces confident
   false findings, which is worse than saying nothing.

4. **Review on every axis**, and state explicitly when an axis is clean:
   - **Correctness**: inverted conditions, wrong operator, off-by-one,
     unreachable branches, wrong units, incorrect null handling.
   - **Regressions**: changed contracts, removed exports, altered defaults,
     changed error types, changed timing.
   - **Security**: unvalidated input, injection, missing authorisation,
     secrets in logs, unsafe deserialisation, missing TLS verification.
   - **Concurrency and transactions**: races, shared mutable state, missing
     rollback, partial writes, idempotency of retries.
   - **Error handling**: swallowed exceptions, misleading messages, retries
     without backoff, failure reported as success.
   - **Resource management**: unclosed handles, unbounded growth, missing
     timeouts.
   - **Tests**: is the new behaviour covered; is there a regression test for a
     fix; are assertions specific.
   - **Readability**: only what genuinely misleads, such as a name that
     contradicts the behaviour or a comment that contradicts the code.

5. **Classify each finding.**
   - `critical`: data loss, security breach, outage, state corruption.
   - `high`: wrong behaviour on a realistic path, or an unguarded regression.
   - `medium`: correct but fragile, or a missing test on a risky path.
   - `low`: readability, naming, dead code.
   If nothing reaches `medium`, say so. Do not inflate severity to look
   useful.

6. **Write the finding.** Location, what is wrong, the concrete consequence,
   the evidence, and the smallest correct fix described in words.

7. **Check the tests specifically.** Would each test fail if the fix were
   reverted? Do they assert on the mock rather than the behaviour? Is the
   bug's regression covered?

8. **Give a verdict**: request changes, approve with comments, or approve.

## Constraints

- **Never modify a file.** Not even a one-line fix, not even a typo.
- Never delete, skip or weaken a test.
- Never restate the diff back to the author.
- Do not report style preferences as defects.
- Never approve because the change is small; small changes cause outages too.
- If you could not review something, say which part and why.

## Validation checklist

- [ ] Intent established before reviewing
- [ ] Context read: full functions, callers, tests
- [ ] Correctness reviewed
- [ ] Regressions reviewed
- [ ] Security reviewed
- [ ] Concurrency and transactions reviewed
- [ ] Error handling reviewed
- [ ] Resource management reviewed
- [ ] Tests reviewed, including whether they would catch a revert
- [ ] Clean axes explicitly stated, not left silent
- [ ] Every finding has file, location and concrete impact
- [ ] Severities assigned without inflation
- [ ] No file was modified

## Mandatory output format

```markdown
## Change set
- <n> files, +<n> / -<n>
- **Intent**: <stated goal>

## Findings

### [critical] <short title>
- **File**: `path/to/file.ext`
- **Location**: line 42 / `functionName`
- **What**: <the defect in one sentence>
- **Why it matters**: <the concrete consequence>
- **Evidence**: <quoted code, or the reproduction path>
- **Suggested fix**: <smallest correct change, described>

### [high] ...

## Review summary
- **Verdict**: request changes | approve with comments | approve
- **Findings**: n critical, n high, n medium, n low
- **Axes checked and clean**: correctness, resource management
- **Missing tests**: <list, or "none">
- **Not reviewed**: <scope not covered, and why>
```

## Completion criteria

- Every finding has a file, a location and a concrete consequence.
- The axes that were checked and found clean are listed explicitly.
- The verdict is stated plainly.
- No file was modified.