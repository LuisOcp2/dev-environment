---
name: test-strategy
description: Decide what to test, at what level, and how to avoid brittle or over-mocked tests. Use this when adding tests to a new feature, reviewing test quality, reducing a slow or flaky suite, or defining coverage for a risky area.
---

# Test Strategy

## Objective

Produce a test suite that is fast, deterministic, resistant to refactoring,
and actually capable of failing when the code is wrong.

## When to use

- Adding tests for a new feature or a bug fix.
- Reviewing an existing suite for quality.
- A suite that is slow or flaky.
- Deciding what not to test.

## When not to use

- A single, obviously correct helper with no branching.
- Exploratory work that has not settled on a design yet.

## Required inputs

- The behaviour to be proven.
- The risk profile: what breaks if this is wrong, how often that path runs,
  how hard it is to detect in production, how hard it is to reverse.
- The existing test infrastructure and its conventions.

## Procedure

1. **Write the acceptance criteria first**, as checkable statements. Each one
   needs at least one test.

2. **Rank the risks.** For each behaviour, score impact, frequency, detection
   cost and reversibility. Test the top of that ranking first. Coverage
   percentage is not a ranking.

3. **Choose the level deliberately.**
   - **Unit**: pure logic, branching, validation rules, reducers. Fast, many.
   - **Integration**: contract between components, against a real database or
     container. Proves the query, the constraint and the transaction.
   - **Contract**: the shape the API actually produces or consumes.
   - **End to end**: critical user journeys only. Expensive; use sparingly.

4. **Enumerate the cases.** For every behaviour: nominal, both boundaries of
   every range, empty collection, single element, null, zero, negative,
   maximum length, unicode and accented text, very large value, and repeated
   or concurrent invocation.

5. **Name the edge cases explicitly.** "Invalid input" is not an edge case.
   "An empty array with a required first element" is.

6. **Make the tests deterministic.** Remove every source of nondeterminism:
   inject a clock instead of calling `now()`, seed randomness, sort before
   comparing collections, isolate the database per run, and never rely on
   execution order or on a shared fixture.

7. **Assert on observable behaviour, never on internals.** A test must survive
   renaming a private method, reordering private calls, and replacing the
   implementation. If it does not, it is testing the implementation.

8. **Avoid over-mocking.** Mock at the boundary you do not own: the network,
   the clock, the message broker. Do not mock the unit under test, and do not
   mock a collaborator and then assert on the mock's return value: that proves
   the wiring, not the behaviour.

9. **Write the bug regression first.** For a defect: the test that fails today,
   with the exact input that reproduces it. Do not fix the bug before this test
   exists and has been seen failing.

10. **Make failures informative.** The failure message must state what was
    expected and what happened, so the reader does not have to debug the test
    to understand the defect.

11. **Keep the suite fast.** Target: unit tests under 100 ms each, the full
    suite under a few minutes. Quarantine slow tests instead of ignoring them.

## Constraints

- Never delete or skip a test to make a build pass.
- Never weaken an assertion to make a test pass.
- Never assert on private state, private fields or internal call order.
- Never sleep to wait for a condition; wait for the condition.
- Never use snapshot tests over large structures nobody reads on failure.
- Never write one test asserting ten unrelated behaviours.
- Never leave a flaky test unfixed: either fix it or quarantine it with a
  ticket.

## Validation checklist

- [ ] Every acceptance criterion has at least one test
- [ ] Risks ranked; effort follows the ranking
- [ ] Level chosen per test, with a reason
- [ ] Edge cases named with concrete input and expected output
- [ ] No nondeterminism: time, randomness, ordering, shared state
- [ ] Assertions are on observable behaviour only
- [ ] Mocking happens at the boundary, not at the unit under test
- [ ] Each bug regression test was seen failing before the fix
- [ ] Failure messages are self-explanatory
- [ ] Suite runtime is measured

## Mandatory output format

```markdown
## Scope
- **Behaviour under test**:
- **Acceptance criteria**:
- **Risk ranking**:

## Test matrix
| Case | Input | Expected | Level | Rationale |
|------|-------|----------|-------|-----------|
| ...  | ...   | ...      | ...   | ...       |

## Edge cases
- **<named case>** — why it matters, expected behaviour

## Determinism
| Source of nondeterminism | How it is removed |
|--------------------------|-------------------|
| wall clock | injected clock |
| random | seeded generator |

## Mocking boundaries
| Mocked | Why | What must not be mocked |
|--------|-----|-------------------------|

## Bug regression tests
| Test | Input reproducing the bug | Fails without the fix |
|------|---------------------------|-----------------------|

## Flaky tests found
| Test | Source of flake | Plan |
|------|-----------------|------|

## Not tested, and why
| Behaviour | Reason | Residual risk |
|-----------|--------|---------------|

## Suite metrics
- Total tests: n
- Runtime: n s
- Slowest: n ms (<name>)
```

## Completion criteria

- Every acceptance criterion is covered.
- Every listed edge case has concrete input and expected output.
- No test asserts on internals.
- Every bug regression test was observed failing before the fix.
- The suite is deterministic, with nondeterminism sources documented.