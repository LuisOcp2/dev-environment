---
name: database-design
description: Design relational schemas, indexes, constraints and migrations with attention to access patterns, integrity and reversibility. Use this when creating or changing tables, adding indexes, modelling relationships, planning a migration, or diagnosing slow queries.
---

# Database Design

## Objective

Produce a schema whose integrity is enforced by the database, whose indexes
match real query patterns, and whose migrations can be rolled back or safely
forward-deployed.

## When to use

- Creating or altering tables, columns, constraints or indexes.
- Modelling relationships that the current schema forces awkwardly.
- Planning a migration on a table with live traffic.
- Diagnosing a slow query or a table that grows faster than expected.
- Choosing between normalisation and denormalisation.

## When not to use

- The data is genuinely ephemeral and the schema does not matter.
- A pure read-only cache or search index, where the source of truth is
  elsewhere.
- A query-only performance question on a query that is not on the critical
  path.

## Required inputs

- The entities involved and their relationships.
- The main operations: which queries run, how often, and with what latency
  target.
- The expected data volume and growth rate.
- The consistency requirement: how stale a read may be.
- The existing schema, when there is one.

## Procedure

1. **Model the domain first, not the tables.** Identify entities, attributes,
   relationships and invariants. Write each invariant as a sentence: "an
   order has at least one line".

2. **Normalise, then stop.** Apply normal forms until an actual access pattern
   or a measurable performance target requires denormalisation. Record which
   normal form was left and why.

3. **Choose the key strategy.**
   - Surrogate key versus natural key, and the trade-off.
   - UUIDv7 or a time-ordered ID for externally visible identifiers.
   - Never expose sequential IDs to end users without authorisation; they
     leak volume and enable enumeration.

4. **Write every invariant as a database constraint**, not as application
   code: `NOT NULL`, `UNIQUE`, `CHECK`, foreign key with a deliberate
   `ON DELETE` action, and an exclusion constraint where ranges overlap.
   Application-only validation drifts.

5. **Choose the nullability deliberately.** `NULL` means "unknown or not
   applicable". If the answer is always "no", the column is `NOT NULL` with a
   sensible default.

6. **Design for the queries, not for the theory.** List the actual queries with
   their filters, joins and sort orders. For each, name the index that serves
   it. If no query needs it, do not create it.

7. **Apply index rules.**
   - Composite index column order follows the query: equality columns first,
     then the range or sort column.
   - Covering indexes (`INCLUDE`) only when the read path is hot.
   - Every index has a write cost; partial and expression indexes reduce it.
   - Unused indexes are pure overhead and should be removed.

8. **Check the access path.** Walk the expected query plan for the critical
   queries. Confirm no full table scan on a growing table.

9. **Design the migration, not just the schema.**
   - Expand / migrate / contract: add the new column, backfill, switch reads,
     switch writes, drop the old column. Each phase is compatible with the
     previous code version.
   - Statement the backfill is idempotent and resumable.
   - Estimated duration and the lock it takes; use `CREATE INDEX CONCURRENTLY`
     where supported.
   - The rollback: either a real one, or an explicit statement that the change
     is forward-only and why.

10. **Estimate growth.** Record the projected row count and index size at 1x,
    12x and 36x, so partition or archival decisions are made before it is
    urgent.

## Constraints

- Never drop or rename a column that any running code still reads.
- Never add a non-nullable column without a default or a staged backfill.
- Never create an index without naming the query it serves.
- Never assume a foreign key is enforced; verify it in the schema.
- Never design for a write pattern without checking its cost against the index
  set.
- Never run migrations on production in this workflow. Produce the plan; a
  human runs it.

## Validation checklist

- [ ] Every domain invariant is expressed as a database constraint
- [ ] Key strategy chosen and justified
- [ ] Nullability decided per column
- [ ] Every index maps to a named query
- [ ] Composite index column order justified by the query
- [ ] Expected query plans avoid full scans on growing tables
- [ ] Migration follows expand / migrate / contract
- [ ] Backfill is idempotent and resumable
- [ ] Rollback defined, or forward-only is stated with a reason
- [ ] Growth projection recorded at 1x, 12x and 36x

## Mandatory output format

```markdown
## Domain model
- Entities and relationships
- Invariants (each as a sentence)

## Schema
```sql
<DDL for the proposed change>
```

## Constraints and their guarantees
| Invariant | Enforced by | Effect of violation |
|-----------|-------------|---------------------|

## Indexes
| Index | Serves query | Columns and why this order | Write cost |
|-------|-------------|--------------------------|------------|

## Query plans
| Query | Plan | Rows examined | Verdict |
|-------|------|---------------|---------|

## Migration plan
| Phase | Action | Compatible with previous code? | Lock | Reversible? |
|-------|--------|-------------------------------|------|-------------|
| 1 expand | | | | |
| 2 backfill | | | | |
| 3 switch reads | | | | |
| 4 switch writes | | | | |
| 5 contract | | | | |

## Backfill
- Command / script, idempotent, resumable, with a progress query.

## Rollback
<exact steps, or "forward only" with the reason>

## Growth projection
| Horizon | Rows | Table size | Index size | Action needed |
|---------|------|------------|------------|---------------|
| 1x | | | | |
| 12x | | | | |
| 36x | | | | |
```

## Completion criteria

- Every invariant is enforced by the database.
- Every index traces to a specific query.
- The migration is compatible with the previous code version at every phase.
- The rollback path is real, or forward-only is justified.
- No migration was executed.