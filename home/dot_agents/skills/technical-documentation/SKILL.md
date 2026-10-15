---
name: technical-documentation
description: Write and update technical documentation that matches the real behaviour of the code, with verified commands, complete configuration references and troubleshooting that covers real failures. Use this when writing a README, an API reference, a runbook or onboarding docs.
---

# Technical Documentation

## Objective

Produce documentation a reader can act on, where every command works, every
option exists, and every default is the actual default.

## When to use

- Writing or updating a README, a guide, an API reference or a runbook.
- Documenting a new feature, a new configuration option or a new command.
- Onboarding documentation for a new developer.
- Documenting an incident, so it is not repeated.

## When not to use

- Marketing copy.
- Internal design notes that will be obsolete next week; use an ADR.
- A commit message or a pull request description; those have their own rules.

## Required inputs

- The audience: new developer, operator, or API consumer.
- The source of truth: the code, the schema, the CLI help, the type
  definitions.
- The real task the reader is trying to accomplish.

## Procedure

1. **Find the source of truth first.** The code, not the documentation about
   the code. CLI `--help`, the config schema, the type definitions, the
   migrations, the tests. When documentation and code disagree, the code wins
   and the disagreement is reported.

2. **Name the audience.** Each audience needs a different document: a
   contributor guide, a deployment runbook, and an API reference are three
   documents, not one long one.

3. **Start from the task, not from the architecture.** Lead with the shortest
   path to a working result. Architecture belongs after, if at all.

4. **State the prerequisites explicitly**, with versions, and say how to check
   each one.

5. **Write copy-pasteable commands.** They must work exactly as written. No
   placeholder that silently fails when pasted; use clearly fake values and
   mark them.

6. **Verify every command you can.** Run it. Paste real output, trimmed and
   annotated. If you cannot run it, mark it explicitly as unverified; never
   present invented output.

7. **Document the configuration completely.** For every key: name, type,
   default, whether it is required, what happens when it is wrong, and
   whether it is safe to change in production.

8. **Document the failure modes.** The error message, its cause, and the fix.
   This is what readers need most and what authors skip most. Include the
   confusing error whose real cause is something else.

9. **Document the boundaries.** What is not supported, what is deprecated, what
   requires privileges, what has not been tested. A known limitation is
   documentation.

10. **Prune.** Delete documentation of behaviour that no longer exists. Stale
    documentation is worse than none, because it is trusted.

11. **Keep it close to the code.** Put the reference next to the
    implementation so it is updated in the same pull request, and make the
    documentation test part of CI where possible.

## Constraints

- **Never invent behaviour, flags, options, endpoints or defaults.**
- **Never invent command output.** Paste real output or mark it unverified.
- Never document a feature that is behind an unfinished implementation as if
  it were ready.
- Never include a secret, a real token, an internal hostname or a customer
  name.
- Never write in a way that requires reading the source to understand the
  documentation.
- Never make the reader install a tool the project does not use.

## Validation checklist

- [ ] Source of truth read before writing
- [ ] Audience identified and the document shaped for it
- [ ] Prerequisites listed with versions and a check command
- [ ] Quick start is copy-pasteable and verified, or marked unverified
- [ ] Every configuration key documented with type and default
- [ ] Troubleshooting covers the real failure modes
- [ ] Unsupported and deprecated behaviour documented
- [ ] Verification log included
- [ ] No secret, real hostname or customer data present
- [ ] Stale content removed

## Mandatory output format

```markdown
# <Title>
<one sentence: what this is and who it is for>

## Requirements
| Tool | Version | How to check |
|------|---------|--------------|

## Quick start
<the shortest path to a working result>

## What just happened
<two or three sentences explaining the output>

## Configuration
| Key | Type | Default | Required | Effect |
|-----|------|---------|----------|-------|

## Common tasks
### <task>
<steps>

## Troubleshooting
| Symptom | Real cause | Fix |
|---------|-----------|-----|

## Limitations
- <what is not supported, and what is untested>

## Verification performed
| Claim | How verified | Result |
|-------|--------------|--------|
| `<command>` works | ran it | yes, output above |
| `PORT` defaults to 3000 | grepped the source | no, it comes from .env |
```

## Completion criteria

- Every documented command was run or is explicitly marked unverified.
- Every documented option and default was read from the source of truth.
- The quick start works from a clean machine with only the stated
  prerequisites.
- Troubleshooting reflects errors the reader will actually hit.
- Nothing documented is invented.