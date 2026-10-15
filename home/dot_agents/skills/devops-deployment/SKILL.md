---
name: devops-deployment
description: Build reproducible deployments with infrastructure as code, automated pipelines, safe rollouts and verifiable rollback. Use this when creating CI/CD pipelines, deployment manifests, container images, release automation or environment configuration.
---

# DevOps and Deployment

## Objective

Make a deployment reproducible, observable and reversible: the same input
produces the same result, its state is visible, and rolling it back is a
routine operation rather than an incident.

## When to use

- Creating or modifying a CI/CD pipeline.
- Writing a Dockerfile or a compose file.
- Defining deployment manifests, infrastructure as code, or environments.
- Setting up observability: logs, metrics, alerts, health checks.
- Preparing a release.

## When not to use

- Running a one-off command on a developer machine.
- Local development compose files that never leave a laptop.
- Choosing the hosting platform, before the constraints are known.

## Required inputs

- The artefact: what is deployed, and how it is built.
- The target environment: where, with what access, with what constraints.
- The availability and performance requirements.
- The rollback requirement: how fast, and to what state.
- Compliance constraints, if any: audit, data residency, secrets handling.

## Procedure

1. **Make the build reproducible.** Pin every base image by digest, every
   dependency by lockfile, and every tool version. The same commit must
   produce the same artefact.

2. **Build a small, minimal image.** Multi-stage build, run as a non-root user,
   one layer for dependencies that changes rarely, no package manager, no
   source, no secrets in any layer. Set a `.dockerignore` that excludes the
   build context you do not need.

3. **Keep secrets out of everything.** Inject at runtime from the platform's
   secret store. Never bake them into an image, never pass them as build
   arguments (they persist in the layer), never commit them. Rotate on
   exposure, do not delete and move on.

4. **Make the pipeline trustworthy.**
   - Lint, typecheck and test before the build.
   - Only protected branches build a release artefact.
   - Pin third-party actions to a commit SHA, not to a moving tag.
   - Give the job the minimum `permissions:` it needs.
   - Separate the pull request pipeline from the release pipeline.

5. **Design the rollout.** Define the strategy: rolling, blue-green or
   canary. Define the health check that gates the rollout, the threshold that
   halts it, and the observation window before the next step.

6. **Make migrations safe.** Apply the `expand / migrate / contract` pattern
   from the `database-design` skill. The migration must be compatible with both
   the previous and the new application version, because during a rolling
   deployment both run simultaneously.

7. **Make it observable.** Structured logs with a correlation id propagated
   from the request; the metrics needed to answer "is it healthy and for
   whom"; alerts tied to user-visible symptoms, not to CPU. Define the health
   and readiness endpoints separately: readiness is what removes the instance
   from the load balancer.

8. **Make rollback routine.** The previous artefact must remain deployable.
   Rollback must be a documented command, not a procedure reconstructed under
   pressure. Test it. Note explicitly when a database migration makes rollback
   impossible, and how to roll forward instead.

9. **Define environments.** Configuration per environment, injected, never
   baked. Name the three or four differences that actually vary, and accept
   that everything else is identical.

10. **Document the runbook.** How to deploy, how to verify, how to roll back,
    the common alerts and what each means, and who to escalate to.

## Constraints

- Never commit a secret or bake one into an image.
- Never use a mutable image tag, such as `latest`, in a deployment manifest.
- Never deploy straight from a developer machine.
- Never grant a CI job broader permissions than it needs.
- Never make a migration that the running previous version cannot tolerate.
- Never claim a deployment is verified without checking the running version
  and the health endpoint.
- Never delete the previous artefact until the new one is confirmed healthy.

## Validation checklist

- [ ] Base image pinned by digest; dependencies pinned by lockfile
- [ ] Multi-stage build, non-root user, minimal final image
- [ ] `.dockerignore` present; no source or secrets in the image
- [ ] Secrets injected at runtime; none in layers, build args or git
- [ ] Pipeline runs checks before building; actions pinned to SHAs
- [ ] Job permissions are minimal; protected branches enforced
- [ ] Rollout strategy, health gate and halt threshold defined
- [ ] Migrations compatible with the previous and the new version
- [ ] Logging, metrics and user-symptom alerts defined
- [ ] Rollback is a documented command and has been tested
- [ ] Runbook exists

## Mandatory output format

```markdown
## Artefact
- **Name and tag**:
- **Reproducible**: how it is pinned

## Image
- **Base**: <image@sha256:...>
- **Stages**: <build / runtime>
- **User**: <non-root user>
- **Size**:
- **Secrets**: none baked; injected from <source>

## Pipeline
| Stage | Trigger | Checks | Outputs |
|-------|---------|--------|---------|
| ...  | ...     | ...    | ...     |

- **Action pinning**: SHAs, not tags
- **Job permissions**: <minimum>

## Deployment
- **Strategy**: rolling | blue-green | canary
- **Health gate**:
- **Halt threshold**:
- **Observation window**:

## Database
- **Migration phase**: expand / migrate / contract
- **Compatible with previous version**: yes | no
- **Reversible**: yes | forward-only, because ...

## Observability
| Signal | What it tells us | Alert threshold |
|--------|------------------|-----------------|

## Rollback
```bash
<the exact command>
```
- **Time to roll back**:
- **Tested**: when, and how

## Runbook
1. Deploy
2. Verify
3. Roll back when
4. Common alerts and what they mean

## Not covered
- <what is not automated yet, and the residual risk>
```

## Completion criteria

- The build is reproducible from pinned references.
- No secret exists in the repository, in the image, or in a build argument.
- The rollout has a health gate, a halt threshold and a tested rollback.
- Migrations are compatible with both application versions.
- The runbook contains a rollback command that was actually executed at least
  once.