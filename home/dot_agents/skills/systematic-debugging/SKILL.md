---
name: systematic-debugging
description: Find the root cause of a failure using reproduction, evidence, and one hypothesis at a time. Use this when something is broken, failing intermittently, behaving differently than expected, or when the cause of a defect is unknown.
---

# Systematic Debugging

## Objective

Find and fix the actual cause of a failure, prove it with evidence, and leave
a regression test that fails without the fix.

## When to use

- A test fails and the reason is not obvious.
- An error appears in production or in a specific environment.
- Behaviour differs between environments, users or data sets.
- Performance is much worse than expected.
- Any situation where the intuitive explanation is a guess.

## When not to use

- The cause is already known and only the edit is needed.
- The "bug" is actually a misconfiguration you have just read.
- The system is so small that reading it end to end is faster than
  instrumenting it. Read it.

## Required inputs

- The observed failure: the exact error text and the exact command or request.
- The expected behaviour, stated as a checkable statement.
- When it started, whether anything changed around that time.
- The environment: runtime version, dependency versions, configuration.

## Procedure

1. **Reproduce.** Find the smallest command, test or request that fails. If it
   does not reproduce, that is itself the finding: record the conditions under
   which it does and does not appear, and treat non-determinism as the
   primary problem to solve.

2. **Record both behaviours** as checkable statements:

   ```text
   Expected: <what must happen>
   Actual:   <what happens>
   ```

3. **Collect evidence before theorising.**
   - The complete error and stack trace, not the summary line.
   - Relevant logs, with timestamps and the correlation id.
   - Versions of the runtime and of every dependency involved.
   - The names of the environment variables that matter, never their values.
   - The input that triggers it, and an input that does not.

4. **Narrow the search.** Use bisection along whatever axis separates working
   from failing:
   - recent commits or deployments
   - environment or configuration
   - input size, shape or value
   - concurrency, ordering or timing
   Record each step and its result. Keep a written log.

5. **State one hypothesis, falsifiably.** "The failure occurs because X, which
   predicts that Y will also happen." Then write down the cheapest experiment
   that could disprove it.

6. **Test one hypothesis at a time.** Change exactly one variable per
   experiment. If two things change together, no result is attributable. Add
   logging or a debugger rather than guessing.

7. **Confirm the root cause.** A root cause is confirmed when it explains:
   - every observed symptom
   - why the failure does not occur elsewhere
   - why it started when it started
   If it does not explain all of that, the investigation is not finished.

8. **Fix the cause, not the symptom.** Enumerate the possible fixes, choose
   one, and record why the others were rejected. Prefer the fix that removes
   the class of bug over the patch that fixes this instance.

9. **Remove the instrumentation** you added, unless it earns its place in
   production logs.

10. **Write the regression test.** It must fail before the fix and pass after
    it. State the exact input that reproduces the original failure.

11. **Run the full validation set** and report the real results, including
    anything that still fails.

## Constraints

- Never change more than one variable per experiment.
- Never delete, skip or weaken a failing test.
- Never hide an error: no swallowing exceptions, no lowered log levels, no
  retry used to mask a race.
- Never claim a fix works without running the reproduction after the change.
- Never add a temporary workaround and describe it as a fix.

## Validation checklist

- [ ] Failure reproduced, or its non-reproducibility documented as the finding
- [ ] Expected and actual behaviour recorded as checkable statements
- [ ] Evidence collected before any hypothesis was formed
- [ ] Search narrowed by recorded bisection steps
- [ ] Root cause stated as a falsifiable sentence and confirmed
- [ ] Root cause explains why it started when it started
- [ ] Exactly one variable changed per experiment
- [ ] Fix targets the cause; rejected alternatives recorded
- [ ] Regression test fails without the fix and passes with it
- [ ] Full validation run; real output reported

## Mandatory output format

```markdown
## Reproduction
- **Command / test**:
- **Expected**:
- **Actual**:
- **Reproduces reliably**: yes | no | intermittently (<details>)

## Evidence
- **Error output**:
  ```
  <verbatim, trimmed>
  ```
- **Relevant log lines**: <with timestamps>
- **Versions**: runtime, framework, dependencies
- **Environment variable names involved**: <names only>
- **Triggering vs non-triggering input**:

## Investigation log
| Step | Experiment | Result | Conclusion |
|------|-----------|--------|------------|
| 1 | | | |

## Hypotheses tested
| Hypothesis | Experiment | Confirmed | Rejected |
|------------|-----------|-----------|----------|

## Root cause
<the falsifiable statement>
**Confirmed by**: <the evidence>
**Explains**: symptoms, location, start date

## Fix
- **Files changed**:
- **What changed**:
- **Rejected alternatives**: <option and reason>

## Regression test
- **File**:
- **Input that triggers the original bug**:
- **Fails before the fix**: yes | no
- **Passes after the fix**: yes | no

## Validation
| Command | Result |
|---------|--------|

## Residual risk
- <what is still unexplained or unverified>
```

## Completion criteria

- The root cause is confirmed by evidence, not by plausibility.
- Exactly one variable changed per experiment.
- The regression test demonstrably fails without the fix.
- Every claimed result was actually produced by a command that ran.
- No error was hidden and no test was weakened.