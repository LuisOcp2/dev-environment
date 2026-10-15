---
name: api-design
description: Design HTTP and other interfaces with consistent resource naming, explicit versioning, error contracts, pagination, idempotency and security boundaries. Use this when creating or reviewing endpoints, designing a public API, or fixing an inconsistent interface.
---

# API Design

## Objective

Produce an interface that is predictable for its consumers, safe to evolve,
and impossible to misuse accidentally.

## When to use

- Creating any new endpoint, RPC, GraphQL operation or webhook.
- Reviewing an existing interface for consistency or security.
- A public or cross-team API that will outlive the current implementation.
- Deciding between REST, RPC and event-driven for a boundary.

## When not to use

- An internal function signature.
- A CLI interface; use the tool's own conventions instead.
- Changing one field of an existing endpoint with no other impact.

## Required inputs

- The consumers: first-party clients, third-party clients, internal services,
  mobile apps that cannot be updated quickly.
- The operations required, with their expected frequency and payload size.
- The authentication and authorisation model.
- The compatibility promise: can clients be forced to update?

## Procedure

1. **Define the resource, not the action.** The URL names a noun; the HTTP
   method names the operation. `POST /orders/{id}/cancel` is an action
   endpoint: justify it, because it usually signals a missing resource, such
   as a cancellation.

2. **Choose the HTTP method by semantics**, and honour idempotency:
   `GET` safe, `HEAD` safe, `PUT` idempotent replacement, `DELETE`
   idempotent, `POST` neither, `PATCH` partial update.

3. **Design the request and response shapes.**
   - Naming: plural for collections, `camelCase` in JSON by convention.
   - Timestamps in RFC 3339 UTC.
   - Money as integer minor units plus a currency code, never a float.
   - Identifiers as opaque strings; never expose a database sequence.
   - Nullability in the response means the same thing as in the request.

4. **Design the error contract once and use it everywhere.** A single shape
   with a stable machine-readable code, a human-readable message, a field
   pointer for validation errors, and a request id for tracing. Error messages
   never leak stack traces or internal identifiers.

5. **Define validation at the boundary.** Reject unknown fields where a typo
   would otherwise be silent. Enforce maximum sizes on every string, array
   and body.

6. **Design pagination.** Cursor-based for data that changes; offset-based only
   for small, stable, administrative lists. Return a `nextCursor`, and make
   the cursor opaque.

7. **Design idempotency.** Any `POST` that creates something, or that charges,
   accepts an `Idempotency-Key`. Store the key with the response and replay it
   on a retry.

8. **Design authorisation per operation.** State who may call it and under
   what condition, and make the default deny. Authorisation is checked on the
   object, not only on the route.

9. **Design versioning and compatibility.** Adding an optional field is
   compatible; removing a field, renaming it, narrowing its type, or changing
   its meaning is not. Say which changes require a new version and which do
   not.

10. **Design the non-functional contract:** authentication method, rate limits,
    timeouts, payload limits, caching and cache-control, idempotency window.

11. **Write the negative cases.** What does an unauthorised caller see, what
    does a missing resource look like, what does a rate limit return, what
    does a malformed body return.

## Constraints

- Never expose internal error messages, stack traces, SQL or host names.
- Never return a list without pagination unless the set is provably bounded
  and small.
- Never let a client control the sort or filter on an unindexed field without
  a bound.
- Never use `PUT` for a partial update; that is `PATCH`.
- Never break an existing field's meaning. Add, deprecate, then remove.
- Never require the client to know internal identifiers.

## Validation checklist

- [ ] URLs name resources; action endpoints are justified
- [ ] Methods match semantics; `PUT` and `DELETE` are idempotent
- [ ] Request and response shapes follow one consistent convention
- [ ] A single error contract is defined with a machine-readable code
- [ ] Unknown fields and size limits are handled at the boundary
- [ ] Pagination strategy is chosen and justified
- [ ] `POST` creation accepts an idempotency key
- [ ] Authorisation is specified per operation with a deny default
- [ ] Compatibility rules for future changes are written down
- [ ] Negative cases are documented

## Mandatory output format

```markdown
## Interface summary
| Method | Path | Purpose | Auth | Idempotent |
|--------|------|---------|------|------------|

## Resources
### <resource>
- Identity: how it is identified and why
- Fields: name | type | nullable | meaning
- Relationships:

## Endpoints
### <METHOD> <path>
- **Purpose**:
- **Authorisation**: who, and under what condition
- **Request**: body or query parameters, with limits
- **Response**: shape, with a realistic example
- **Errors**: status, code, when it occurs
- **Idempotency**: safe to retry?
- **Rate limit**:

## Error contract
```json
{ "error": { "code": "...", "message": "...", "details": [...], "requestId": "..." } }
```
| Code | HTTP status | Meaning | Client should |
|------|-------------|---------|---------------|

## Pagination
- Strategy: cursor | offset
- Parameters and default page size
- Cursor semantics and expiry

## Idempotency
- Header name, storage, retention window, replay behaviour

## Compatibility rules
- Safe additive change:
- Breaking change:
- Deprecation policy and minimum notice:

## Rate limits and timeouts
| Endpoint family | Limit | Timeout | Response on breach |
|-----------------|-------|---------|--------------------|

## Non-functional contract
- Auth:
- Transport:
- Payload limits:
- Caching:

## Open questions
- <question and who answers it>
```

## Completion criteria

- Every endpoint has an authorisation rule and an error contract.
- Every response shape has a realistic example.
- Pagination and idempotency are specified wherever they apply.
- Compatibility rules distinguish additive from breaking changes.
- No endpoint relies on the client knowing internal identifiers.