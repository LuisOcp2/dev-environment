---
name: security-review
description: Audit code for authentication, authorization, input validation, injection, secrets, cryptography, transport, dependency and abuse vulnerabilities, and report prioritized findings with attack paths. Use this before a release, when touching security-sensitive code, or after a security incident.
---

# Security Review

## Objective

Find exploitable weaknesses before they reach production, and report each one
with a concrete attack path so it can be prioritised and fixed.

## When to use

- Before a production release.
- After changing authentication, authorisation, session handling, payment or
  file handling.
- When adding a dependency from a new source.
- After a security incident, to find the same class of bug elsewhere.
- When a system handles personal or financial data.

## When not to use

- As a substitute for threat modelling at design time.
- To prove that a system is secure. It cannot; report coverage and residual
  risk instead.

## Required inputs

- The scope: modules, endpoints, or the diff since the last review.
- The architecture context: trust boundaries, data classification, entry
  points.
- Deployment context: internet-facing or internal, single tenant or multi.

## Procedure

1. **Draw the trust boundaries.** Identify every entry point (HTTP, CLI, queue,
   webhook, file, environment) and every data store. Mark where untrusted
   data enters and where it is trusted again. Most findings live exactly on a
   boundary.

2. **Audit each area.** Report status for all ten; never leave one silent:
   1. Authentication: hashing algorithm and cost, session and token lifetime,
      refresh, revocation, MFA, rate limiting, user enumeration, password
      reset.
   2. Authorization: server-side enforcement, object-level checks (IDOR),
      per-request versus cached roles, default deny.
   3. Input validation: every boundary, type, range, length, format,
      allow-list versus deny-list.
   4. Injection: SQL, NoSQL, command, template, path traversal, LDAP, header,
      log.
   5. Secrets: hardcoded values, secrets in logs or errors, secrets in client
      code, rotation, key separation, git history.
   6. Cryptography: home-made crypto, deprecated algorithms, ECB, static IV,
      hardcoded salts, unsigned tokens, `alg: none`, missing audience or
      issuer checks.
   7. Transport and headers: TLS verification, HSTS, CSP, CORS with
      credentials, cookie flags, CSRF on state-changing routes.
   8. Dependencies: outdated runtime or framework, unmaintained packages,
      typosquatting, install scripts, lockfile integrity.
   9. Data exposure: PII in logs or analytics, over-broad responses, verbose
      production errors, backups, missing redaction.
   10. Concurrency and abuse: races in permission or balance checks, missing
      rate limits, replayable operations, unbounded resource consumption.

3. **Assess each finding.** Is there a plausible attacker? What do they
   already have? What do they gain? Is there a mitigating control elsewhere?

4. **Classify severity.**
   - `critical`: exploitable now; breach, auth bypass, RCE, privilege
     escalation.
   - `high`: exploitable with a precondition, or a serious weakness that
     becomes critical in a common configuration.
   - `medium`: hardening gap or missing defence in depth.
   - `low`: best-practice deviation with limited real impact.
   A finding without a plausible attack path is at best `low`.

5. **Write the remediation** as a specific change, plus how to verify the fix.

6. **State the coverage honestly.** List the files examined and the parts not
   reviewed. Name what could not be assessed without a running system.

7. **Note what is implemented well.** A report that only lists problems is
   less useful than one that also states which controls are sound.

## Constraints

- **Never read or print a real secret.** Environment files, keys and
  credential stores are out of bounds. Report their existence and location,
  never their contents.
- Never modify any file.
- Never run exploits, never send requests to third parties, never touch data.
- Never inflate severity to appear thorough.
- Never report a theoretical concern as a finding without saying it is
  theoretical.

## Validation checklist

- [ ] Trust boundaries and entry points identified
- [ ] All ten areas have an explicit status: finding, clean, or not reviewed
- [ ] Every finding has a location, an attack path and a remediation
- [ ] Severity assigned by exploitability, not by category
- [ ] Mitigating controls, where present, are credited
- [ ] Secrets referenced by location only, never by content
- [ ] Coverage stated: files examined and files not reviewed
- [ ] Positive controls listed
- [ ] No file modified and no exploit attempted

## Mandatory output format

```markdown
## Scope
- **Examined**: <modules, endpoints, files>
- **Not reviewed**: <what, and why>

## Trust boundaries
- **Entry points**: <list>
- **Data stores**: <list>
- **Critical boundaries**: <where untrusted data becomes trusted>

## Findings

### [critical] <short title>
- **Location**: `path:line` or `functionName`
- **Category**: authentication | authorization | validation | injection | secrets | crypto | transport | dependencies | data-exposure | abuse
- **Vulnerability**: <what is wrong>
- **Preconditions**: <what the attacker needs>
- **Attack path**: <concrete steps>
- **Impact**: <what the attacker gains>
- **Remediation**: <specific change>
- **Verification**: <how to confirm the fix>

## Coverage
| Area | Status | Note |
|------|--------|------|
| Authentication | finding / clean / not reviewed | ... |

## Positive observations
- <control implemented well>

## Residual risk
- <what needs a live system, a pentest, or a human decision>
```

## Completion criteria

- All ten audit areas have an explicit status.
- Every finding has a location, a realistic attack path and a remediation.
- Severity reflects exploitability.
- No secret was read or printed.
- Coverage and residual risk are stated without overclaiming.