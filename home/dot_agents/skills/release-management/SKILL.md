---
name: release-management
description: Plan and execute a software release with versioning, changelog, branching, approval gates and rollback. Use this when cutting a release, preparing a version bump, tagging, publishing artefacts or managing a hotfix.
---

# Release Management

## Objective

Ship a release that someone can understand, verify and roll back: a correct
version, an honest changelog, an immutable artefact and a documented way back.

## When to use

- Cutting a release or preparing to cut one.
- Deciding the version number.
- Tagging, publishing a package or a container image.
- Cutting a hotfix outside the normal cycle.
- Retracting a release that turned out to be broken.

## When not to use

- Deciding the version number before the scope is frozen.
- Deciding what goes **into** the next release. That is scope management, not
  release management.
- A live incident on a production system: use the incident runbook first, then
  come back here for the follow-up release.
- Publishing a container image or a package nobody asked for.
- A release with no rollback plan is not a release this skill can approve. Say
  so instead of proceeding.

## Required inputs

- The scope: what is included, and what is explicitly excluded.
- The target: which branch, which tag format, which artefact registry.
- The audience: who consumes this, and how do they upgrade.
- The rollback requirement and the window during which rollback is possible.

## Procedure

1. **Freeze the scope.** Everything merged to the release branch is in. New
   work goes to the next cycle. Write the scope down and stop adding.

2. **Verify the release candidate.** On the exact commit that will be tagged:
   full test suite, typecheck, lint, build, and the security checks. Run them
   in CI, not locally, and use the artefact CI produced.

3. **Choose the version, using semantic versioning.**
   - `MAJOR`: an incompatible API change, or a change that forces consumers
     to act.
   - `MINOR`: backwards-compatible functionality.
   - `PATCH`: backwards-compatible bug or security fix.
   When the rules do not fit, say so and write the rule you used in the
   changelog. Never skip a version to appear current.

4. **Write the changelog for the reader, not for the author.** Group by
   `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`. For each
   entry, state the user-visible effect and, when it is not obvious, the action
   the reader must take. No commit hashes as the only reference.

5. **Verify the upgrade and downgrade paths.** Does a consumer upgrade from the
   previous version cleanly? Are the migrations compatible with the previous
   version running? Can the previous artefact still be deployed?

6. **Run the pre-release checks.**
   - All migrations apply forward and, where claimed, backward.
   - The build is reproducible from the released commit.
   - Configuration changes are backward compatible.
   - Deprecations announced at least one cycle earlier are now honoured.

7. **Tag immutably.** Annotated tag, correct format, on the release commit,
   pushed with `--follow-tags` and protected so it cannot move.

8. **Publish the artefact** from CI, not from a workstation. Record the digest.

9. **Announce**, including what is deprecated, what is removed, and the action
   required.

10. **Watch the release.** Error rate, latency and support signals for the
    observation window. Know the abort threshold before you start.

11. **Retract if needed.** Deprecate rather than delete a broken release, mark
    it, publish a fixed patch version, and communicate clearly.

## Constraints

- Never tag a commit that has not passed the full verification suite.
- Never publish an artefact built on a developer machine.
- Never move or force-update a published tag.
- Never publish a secret, a private URL or a draft configuration.
- Never perform the release without explicit confirmation from Luis.
- Never combine the release with an unrelated change.
- Never delete a broken release silently.

## Validation checklist

- [ ] Scope frozen and written down
- [ ] Full suite green on the exact release commit, in CI
- [ ] Version chosen by a stated rule and justified
- [ ] Changelog written from the reader's point of view
- [ ] Upgrade and downgrade paths verified
- [ ] Migrations compatible with the previous version
- [ ] Configuration changes backward compatible
- [ ] Annotated tag on the release commit, protected
- [ ] Artefact published from CI, digest recorded
- [ ] Abort threshold defined before publishing
- [ ] Rollback command documented and tested

## Mandatory output format

```markdown
## Release
- **Version**: 1.2.3
- **Rule applied**: major | minor | patch — <why>
- **Tag**: v1.2.3 (annotated)
- **Commit**: <sha>
- **Artefact**: <name@sha256:...>

## Scope
**Included**: <summary>
**Excluded**: <what is deliberately not in this release>

## Verification
| Check | Where it ran | Result |
|-------|--------------|--------|
| Tests | CI | passed |
| Typecheck | CI | passed |
| Build | CI | passed |
| Migrations forward | CI | passed |
| Migrations backward | CI | failed — reason |
| Downgrade deploy | staging | passed |

## Changelog
### Added
- <user-visible effect>

### Changed
- <user-visible effect> (breaking? action required: ...)

### Deprecated
- <what, and until when>

### Removed
- <what, and the migration path>

### Fixed
- <the symptom that is gone>

### Security
- <the class of issue fixed, without disclosing exploitable detail>

## Rollout
- **Strategy**: rolling | blue-green | canary
- **Observation window**:
- **Abort threshold**:
- **Rollback command**:
  ```bash
  <exact command>
  ```

## Known issues in this release
- <issue> — <workaround or planned fix>

## Post-release
- [ ] Tag protected
- [ ] Changelog published
- [ ] Monitoring watch scheduled for the observation window
```

## Completion criteria

- The version follows a stated rule.
- The changelog describes user-visible effects and required actions.
- Every verification row was actually executed, with its real result.
- The tag is annotated, immutable and on the verified commit.
- The rollback command is documented and has been tested.