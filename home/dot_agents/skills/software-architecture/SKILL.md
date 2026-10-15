---
name: software-architecture
description: Design system structure and evaluate architectural options with explicit trade-offs and one recommendation. Use this when starting a new project, splitting a module, choosing between competing designs, or when a change would have architectural consequences.
---

# Software Architecture

## Objective

Produce an architecture that fits the actual constraints, with the rejected
alternatives written down so the decision can be revisited when the constraints
change.

## When to use

- Starting a new project or a new bounded context.
- A module has become a place where every change goes.
- Choosing between competing designs: monolith versus services, SQL versus
  document store, sync versus async, build versus buy.
- A change would create a dependency that is awkward to reverse.
- Refactoring is needed and the target shape is not obvious.

## When not to use

- The problem is local and the existing structure already answers it.
- Choosing a library. That is research, not architecture.
- Performance tuning of a known hotspot.
- Deciding before the requirements are known; at that point it is guessing.

## Required inputs

- The functional requirements, however rough.
- The non-functional requirements: expected load, latency target, availability,
  data volume, compliance.
- The hard constraints: stack, team size and skill, budget, existing systems
  that cannot be replaced.
- The current architecture, if the project exists.

## Procedure

1. **Write down the constraints as testable statements.** "Under 200 ms for
   the p95 read" is a constraint. "Fast" is not.

2. **Draw the current state**, in as much detail as is known: components,
   data stores, external systems, and the flows between them. Mark what is
   verified and what is assumed.

3. **Identify the quality attributes that actually matter here.** Rank them.
   An architecture optimises for a priority order; an unranked list produces
   an incoherent design.

4. **Identify the coupling.** What changes together? What must change
   together? Shared database tables and shared code are the usual answers and
   are usually the real problem.

5. **Generate at least three genuinely different options.** An option nobody
   would pick is not an option. Every option must be implementable with the
   actual stack.

6. **Evaluate each option on the same axes**, so the comparison is fair:
   - fit to the ranked quality attributes
   - implementation complexity and time to first value
   - operational cost: deployment, monitoring, backup, on-call
   - failure modes: blast radius, detection, recovery
   - testability, including contract and integration testing
   - data ownership and migration cost
   - reversibility: what it costs to undo in six months
   - team fit: familiarity, on-call burden

7. **Recommend exactly one**, explicitly, and state what would have to change
   for a different option to win.

8. **State the consequences.** What becomes harder. Which coupling is
   accepted, and why. Which decision is genuinely expensive to reverse, so it
   gets the most scrutiny now.

9. **Design the first increment.** The smallest slice that exercises the main
   assumption, plus the metric that would prove it wrong.

10. **Record the decision** as a short document: context, decision,
    consequences, and what would trigger revisiting it. Undocumented
    decisions are re-litigated every quarter.

## Constraints

- Do not design for hypothetical scale. Design for the stated scale and state
  the point at which the design would need to change.
- Do not introduce a technology that no one on the team can operate.
- Do not add a network hop, a service or a cache without naming the failure
  mode it introduces.
- Never present a single option as a decision.
- Never hide a trade-off to make a recommendation look cleaner.

## Validation checklist

- [ ] Constraints stated as testable statements
- [ ] Current architecture described, assumptions marked
- [ ] Quality attributes ranked
- [ ] Coupling identified
- [ ] Three or more genuinely different options
- [ ] All options evaluated on the same axes
- [ ] Exactly one recommendation, with the condition that would change it
- [ ] Consequences and accepted coupling stated
- [ ] Reversibility assessed for the hard-to-reverse parts
- [ ] First increment defined with its success signal
- [ ] No code written

## Mandatory output format

```markdown
## Constraints
| Constraint | Testable statement | Fixed or negotiable |
|------------|--------------------|---------------------|

## Quality attribute priorities
1. <attribute> — <why it is first>
2. ...

## Current architecture
- Components
- Data stores
- External systems
- Verified vs assumed

## Coupling analysis
| Coupled thing | Why | Cost of keeping | Cost of breaking |
|---------------|-----|-----------------|------------------|

## Options

### Option A - <name>
- Approach
- Fit to ranked attributes
- Complexity and time to value
- Operational cost
- Failure modes
- Testability
- Migration cost
- Reversibility
- Team fit

### Option B - <name>
<same fields>

### Option C - <name>
<same fields>

## Recommendation
<one option>
**Why it wins**: <argument>
**What would change this**: <condition>

## Consequences
- Accepted coupling:
- Now harder:
- Expensive to reverse:
- Must be monitored:

## First increment
- Change:
- Success signal:
- Failure signal:

## Decision record
- **Context**:
- **Decision**:
- **Consequences**:
- **Revisit when**:
```

## Completion criteria

- At least three real options, compared on identical axes.
- One clear recommendation.
- The consequence most likely to cause pain is named explicitly.
- No code was written and no technology was chosen for hypothetical scale.