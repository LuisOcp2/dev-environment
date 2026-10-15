---
description: Run a read-only security review of the code or the current changes. Never modifies files.
agent: build
subagent: true
---

Run a security review.

Scope: `$ARGUMENTS`

## Preferred method

Use the `security-auditor` subagent if it is available:

> Use the security-auditor subagent to review <scope>.

## Rules

- **Read only.** Do not modify any file. Do not run commands that change
  state, do not send requests to third parties, do not touch any data.
- **Never read or print a secret.** Real `.env` values, keys, tokens and
  credential files are out of bounds. Report their existence and location,
  never their contents.
- **No exploitation.** Analyse statically.
- **No inflated severity.** A finding without a plausible attack path is low
  severity at best.

## Steps

1. **Establish the scope.** If no scope was given, audit the current changes
   first, then the authentication and authorization paths, then the input
   boundaries, then the dependencies.

2. **Audit each area**, reporting status for all ten even when clean:
   authentication, authorization, input validation, injection, secrets,
   cryptography, transport and headers, dependencies, data exposure,
   concurrency and abuse.

3. **For each finding**, state the concrete attack path and the concrete
   remediation.

4. **Separate what is real from what is a hardening suggestion.** Do not mix
   a vulnerability with a best practice.

5. **State what could not be assessed** without running the system.

## Required output

```markdown
## Scope
- **Examined**: <files, modules>
- **Not reviewed**: <what, and why>

## Findings
### [severity] <title>
- **Location**: path:line or `functionName`
- **Category**: authentication | authorization | validation | injection | secrets | crypto | transport | dependencies | data-exposure | abuse
- **Vulnerability**: what is wrong
- **Attack path**: how it would be exploited
- **Impact**: what the attacker gains
- **Remediation**: the specific change
- **Verification**: how to confirm the fix

## Coverage
| Area | Status | Note |
|------|--------|------|

## Positive observations
- <controls implemented well>

## Residual risk
- <what needs a live system or a human decision>
```

## Completion criteria

- All ten audit areas have an explicit status.
- Every finding has a location, an attack path and a remediation.
- No secret was read or printed.
- No file was modified and no request was sent anywhere.