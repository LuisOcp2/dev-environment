---
name: backend-feature
description: Implement a backend change end to end with validation at the boundary, transactional correctness, authorization checks and tests at the right level. Use this when building or modifying APIs, services, jobs, integrations or data access code.
---

# Backend Feature

## Objective

Deliver a backend change that is validated at its edges, correct under
concurrency and partial failure, authorised per request, and covered by tests
that would catch a regression.

## When to use

- Adding or modifying an endpoint, service, use case, worker or repository.
- Integrating a third-party API.
- Changing transaction boundaries or background processing.
- Fixing a defect in server-side code.

## When not to use

- A pure UI change.
- A configuration-only change with no behaviour.
- A change confined to a pure function with existing complete coverage.

## Required inputs

- The requirement, plus the error cases that must be handled.
- The data model: tables, existing constraints, existing migrations.
- The authorisation model: who may perform this operation.
- The existing patterns: layering, error types, validation, logging, tests.

## Procedure

1. **Follow the existing layering.** Match the project's structure exactly:
   route, controller, service, repository. If the project has no service
   layer, do not invent one for a single feature.

2. **Validate at the boundary.** Parse and validate every input where it
   enters: request body, query, headers, path parameters, webhooks, queue
   messages, uploaded files. Reject unknown fields. Enforce maximum lengths,
   counts and sizes. Validation belongs here, not in the service, because the
   service may have other callers.

3. **Type the domain.** Use the project's typed primitives: DTOs, schemas,
   entities. Convert at the boundary, work with domain types inside, and never
   leak a database row or a framework request object into the domain.

4. **Authorise every operation, on the object.** A route-level role check is
   not enough when the caller passes an id. Check ownership or permission on
   the loaded record. Default deny.

5. **Get transactions right.**
   - One transaction per business operation, opened at the service boundary.
   - The shortest possible scope: no HTTP call inside a transaction.
   - `rollback` on any error, including partial writes.
   - Decide explicitly whether a failure mid-operation leaves partial state,
     and make the operation either atomic or idempotent.

6. **Design for concurrency.** Identify the read-modify-write windows:
   counters, balances, unique keys, stock, status transitions. Use a unique
   constraint, an atomic statement, a row lock, or an optimistic version
   column. Never rely on a check followed by an insert.

7. **Make external calls safe.** Every outbound call has a timeout, a bounded
   retry with exponential backoff and jitter, and a defined behaviour when it
   fails. Never retry a non-idempotent call without an idempotency key.

8. **Make background work reliable.** A queued job must be idempotent, because
   it will run twice. Persist a correlation id. Define what happens on poison
   messages and how many attempts are allowed.

9. **Define the error contract.** Reuse the project's error type. Never return
   a stack trace, a raw database message or an internal identifier. Log the
   detail server-side with a correlation id and return the id to the client.

10. **Test at the right level.**
    - Unit: domain logic, branching, validation rules.
    - Integration: the real database or a faithful container, proving the
      constraint, the transaction and the query.
    - Contract: the shape the API actually returns.
    - Concurrency: at least one test that exercises the race you identified.

11. **Verify.** Run the project's own format, lint, typecheck and test
    commands. Report the real output, including failures.

## Constraints

- Never trust input because the caller is internal; internal callers change.
- Never perform I/O inside a database transaction.
- Never catch an exception and return a success response.
- Never log a secret, a token, a full request body or personal data.
- Never disable a test, a type check or a linter to make the build pass.
- Never add a dependency without stating why the standard library and the
  existing dependencies are insufficient.

## Validation checklist

- [ ] Layering matches the project; no layer invented for one feature
- [ ] Every input validated at the boundary, with size limits
- [ ] Boundary types converted to domain types
- [ ] Authorisation checked on the object, default deny
- [ ] Transaction scope is minimal and rolls back on error
- [ ] Concurrency risks addressed with a constraint, lock or atomic statement
- [ ] External calls have timeouts, bounded retries and idempotency
- [ ] Background jobs are idempotent
- [ ] Errors return a stable contract; internals stay in the logs
- [ ] Tests cover the failure paths and the identified race
- [ ] Format, lint, typecheck and tests run; real output reported

## Mandatory output format

```markdown
## Summary
<what was built, in two sentences>

## Files changed
| Path | Change |
|------|--------|

## API surface
| Method | Path | Authorisation | Errors |
|--------|------|---------------|--------|

## Validation rules
| Input | Rule | Error on violation |
|-------|------|-----------------|

## Data and transactions
- Entities touched:
- Transaction boundary:
- Rollback behaviour:
- Concurrency control:

## External calls
| Call | Timeout | Retry | Idempotency key |
|------|---------|-------|-----------------|

## Security
- Authorisation rule:
- Validation at the boundary:
- Secrets handling:
- What is logged:

## Tests added
| Test | Level | Proves |
|------|-------|--------|

## Validation run
| Command | Result |
|---------|--------|

## Deployment notes
- Migrations: <forward compatible? reversible?>
- Feature flag: <needed?>
- Rollback plan:

## Residual risk
- <what is untested and what would break>
```

## Completion criteria

- Inputs are validated at the boundary and authorisations checked per object.
- Transaction scope and concurrency handling are explicit.
- External calls cannot hang indefinitely or double-charge.
- Tests cover the failure paths, including the identified race.
- All validation commands ran and the real output is reported.