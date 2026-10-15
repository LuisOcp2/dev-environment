---
name: performance-review
description: Find real performance bottlenecks using measurement before optimisation, and fix them without harming correctness or readability. Use this when a system is slow, when latency or memory has grown, or before a traffic increase.
---

# Performance Review

## Objective

Find the actual bottleneck with measurement, fix it with the smallest change,
and prove the improvement with a number rather than an intuition.

## When to use

- A measured latency or throughput problem.
- Memory growth or a suspected leak.
- Before a traffic increase that is expected to matter.
- After an infrastructure change that should have improved things.

## When not to use

- No measurement exists and none can be obtained. Profile first.
- Code that is not on a hot path. Readability wins there.
- The "problem" is a slow query on a report nobody runs.

## Required inputs

- The symptom: which operation, which latency or throughput, since when.
- The target: the latency or throughput the system must reach.
- The environment: representative data volume and traffic shape.
- Access to measurement: profiling, tracing, query plans, or at minimum
  timing of the actual operation.

## Procedure

1. **Define the target.** "Under 200 ms at p95 for the order list, with 50k
   orders." A target without a percentile and a volume is not a target.

2. **Measure before touching anything.** Build a repeatable benchmark: a
   script, a query with real data volume, a load test, or a flame graph.
   Record the baseline number and the environment.

3. **Find where the time goes.** Use the profiler or the tracing output. The
   bottleneck is usually not where the intuition says:
   - N+1 queries in an ORM
   - a missing index causing a sequential scan
   - an unindexed sort or a `LIKE '%x%'`
   - serialisation of a large payload
   - a synchronous call inside a request
   - connection pool exhaustion or per-request TLS setup
   - lock contention
   - an unbounded loop, or an accidental O(n squared)
   - memory growth from an unbounded cache or listener leak
   - cold start dominating a short-lived workload

4. **Confirm with a single hypothesis.** Measure the candidate bottleneck in
   isolation. If removing the suspected cause does not change the number, it
   was not the bottleneck; go back to step 3.

5. **Choose the cheapest fix that moves the number.**
   - Add or correct an index.
   - Rewrite one query: select fewer columns, avoid the N+1, paginate.
   - Cache a value with an explicit invalidation rule.
   - Batch, or make the calls concurrent with a bound.
   - Return less data: pagination, field selection, compression.
   - Fix the algorithm.
   Do not reach for a new cache before understanding the real cost.

6. **Verify correctness was not traded away.** The optimisation must not skip
   authorisation, weaken a constraint, change an error path, or introduce a
   stale-read window that matters. Re-run the tests.

7. **Measure again, in the same environment.** Report before, after, and the
   ratio. If it did not improve materially, revert and report that the
   hypothesis was wrong.

8. **Check the trade-offs.** More memory for a bigger cache. Higher write cost
   for a faster read. More complexity for a large gain. Record them.

9. **Prevent regression** with a benchmark in CI or a performance budget in
   the test suite, only when the regression would be silent.

## Constraints

- Never optimise without a baseline measurement.
- Never claim a speedup that was not measured.
- Never trade correctness for speed: no skipped authorisation, no weakened
  constraint, no swallowed error.
- Never introduce unbounded caching; every cache needs a size and an
  invalidation rule.
- Never micro-optimise code that profiling shows is irrelevant.
- Never tune a query without reading its plan.

## Validation checklist

- [ ] A numeric target defined, with percentile and data volume
- [ ] Baseline measured before any change
- [ ] Profiling evidence identifying the bottleneck
- [ ] Bottleneck confirmed by isolating it
- [ ] Fix chosen from real options, not from habit
- [ ] Correctness re-verified; tests re-run
- [ ] After-measurement taken in the same environment
- [ ] Trade-offs of the fix recorded
- [ ] Regression guard added if the regression would be silent

## Mandatory output format

```markdown
## Target
<metric, percentile, data volume, deadline>

## Baseline
| Scenario | Before | How measured |
|----------|--------|--------------|

## Where the time goes
| Component | Share | Evidence |
|-----------|-------|----------|

## Root cause
<the confirmed bottleneck, and the measurement that confirmed it>

## Fix
| Change | Rationale | Alternatives rejected |
|--------|-----------|------------------------|

## Results
| Scenario | Before | After | Change |
|----------|--------|-------|--------|
| ...      | ...    | ...   | ...    |

## Correctness impact
- <what was verified and how; which tests were re-run>

## Trade-offs
- Memory, write cost, complexity, staleness window.

## Regression guard
- <benchmark, budget or alert; or why none is needed>

## Not measured
- <paths not profiled, and the risk that remains>
```

## Completion criteria

- Every number reported was actually measured, in a stated environment.
- The bottleneck is confirmed, not suspected.
- Correctness was re-verified after the change.
- Trade-offs are explicit, including the cost the optimisation introduces.
- Nothing was optimised without evidence.