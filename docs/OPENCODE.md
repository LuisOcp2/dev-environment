# OpenCode

This repository manages a global OpenCode configuration through chezmoi.

| Managed path                          | Installed to                                  |
| ------------------------------------- | --------------------------------------------- |
| `home/dot_config/opencode/`           | `~/.config/opencode/`                         |
| `home/dot_agents/skills/`             | `~/.agents/skills/`                           |

## Version this was written against

Everything below was written against **OpenCode v2** (verified locally against
`opencode v2.0.29`) and the documentation at `https://opencode.ai/v2/docs/`.

Two consequences of the V2 migration are baked in and enforced by
`make validate`:

1. **Markdown agent frontmatter uses only V2 fields.** The removed V1 fields
   `tools`, `temperature`, `top_p`, `prompt`, `permission`, `maxSteps` and
   `disable` are rejected. The valid set is `description`, `mode`, `model`,
   `permissions`, `steps`, `hidden`, `color`, `disabled` and `request`.
2. **Permissions are an ordered list of rules**, not a nested object:

   ```jsonc
   { "action": "edit", "resource": "*", "effect": "deny" }
   ```

   The last matching rule wins, so broad rules come before narrow exceptions.

Where the V1 and V2 syntax differ, this repository uses V2. See the migration
guide at `https://opencode.ai/v2/docs/migrate-v1` when porting an existing
setup.

## Provider independence

`opencode.jsonc` deliberately sets **no** `model`, no `default_agent`, no
`providers` and no credentials. The provider and the model are a personal,
machine-local decision:

```bash
opencode auth login
```

Select the provider and the model interactively in the TUI. Nothing in this
repository pins either one.

If a value must be injected into configuration, use an environment reference,
never a literal:

```jsonc
{ "mcp": { "servers": { "x": { "headers": { "Authorization": "{env:TOKEN}" } } } } }
```

## Global instructions

`~/.config/opencode/AGENTS.md` is loaded into every session. It establishes:

- answer Luis in Spanish; keep code, identifiers and commits in English
- read the project instructions and the relevant files before changing code
- never invent files, APIs, flags, test names or command output
- present a plan before non-trivial changes
- prefer small, reviewable changes
- keep strict typing; validate input at system boundaries
- add tests in proportion to the risk
- run the formatter, linter, typecheck and tests that actually exist
- never claim something works without having validated it
- never read, print or commit a secret
- ask before anything destructive
- report files changed, commands run, validation performed and residual risk

Project-level `AGENTS.md` files are merged in addition to this one. A
template is available at `templates/project-agents/AGENTS.md`.

## Agents

Installed to `~/.config/opencode/agents/`.

| Agent                | Mode      | Can it edit files?   | Purpose                                     |
| -------------------- | --------- | ------------------- | ------------------------------------------- |
| `architect`          | subagent  | no, by policy       | alternatives, trade-offs, one recommendation |
| `reviewer`           | subagent  | no, by policy       | read-only review ordered by severity        |
| `debugger`           | subagent  | yes, carefully      | systematic root-cause investigation         |
| `security-auditor`   | subagent  | no, by policy       | read-only security audit, prioritized       |
| `test-engineer`      | subagent  | no, for test files  | test matrices, edge cases, risk ranking     |
| `documentation-writer`| subagent | no, for `.md` files | documentation that matches real behaviour    |

### Why no `model` field

Fixing a model in an agent makes the configuration provider-specific, which
contradicts the provider-independent goal. Without a `model`, a subagent
inherits the model of the session that launched it.

### How permissions are expressed

```yaml
---
description: Reviews code, never edits it
mode: subagent
permissions:
  - action: edit
    resource: "*"
    effect: deny
---
```

This is valid V2. The equivalent V1 object form (`permission: {edit: deny}`) is
removed and is rejected by `make validate`.

### `steps`

Bounded step counts keep a specialised agent from looping:

```yaml
steps: 24
```

On the final step OpenCode removes the tools and asks for a text summary.

## Commands

Installed to `~/.config/opencode/commands/`. In the TUI they appear as slash
commands.

| Command                | What it does                                                |
| ---------------------- | ----------------------------------------------------------- |
| `/doctor`              | diagnose the environment, changes nothing                    |
| `/plan`                | analyse a task and produce a plan, implements nothing       |
| `/review`              | review the current changes, read only                       |
| `/security-review`     | read-only security review                                   |
| `/new-skill`           | create a skill using `skill-creator`                        |
| `/update-environment`  | report available updates, upgrades nothing                   |
| `/verify-project`      | detect the stack and run the checks it actually defines     |

### Arguments

Commands accept arguments with `$ARGUMENTS`, or positionally with `$1`, `$2`:

```text
/review src/auth.ts
/security-review the payment module
/plan add OAuth login
```

Example of a command body:

```markdown
---
description: Review the current changes
agent: build
subagent: true
---

Review the current uncommitted changes.

Focus: $ARGUMENTS
```

Valid command frontmatter fields: `description`, `agent`, `model`, `subagent`.
`template` is JSON-only: in Markdown the body is the template.

### Shell blocks

A command can embed command output with a backtick block:

```markdown
Review this diff:

!`git diff --stat && git diff`
```

These run when OpenCode evaluates the command, outside the agent's permission
flow. Only put commands from sources you trust in here, and never place an
untrusted argument inside a shell block.

## Skills

Installed to `~/.agents/skills/`.

OpenCode discovers skills from several roots:

| Scope                 | Paths                                                  |
| --------------------- | ------------------------------------------------------ |
| global                | `~/.config/opencode/skills`                            |
| global compatibility  | `~/.claude/skills`, `~/.agents/skills`                 |
| project               | `.opencode/skills`                                     |
| project compatibility | `.claude/skills`, `.agents/skills`                     |

This repository uses **`~/.agents/skills`** as the canonical location because
it is the portability path: the same directory works for any tool that reads
the `.agents` convention.

`opencode.jsonc` grants `{ "action": "skill", "resource": "*", "effect":
"allow" }` so skills load without an extra prompt.

### The skill ID is the path

The ID is derived from the file path, not from the `name`:

| File                                    | ID              |
| --------------------------------------- | --------------- |
| `~/.agents/skills/code-review/SKILL.md` | `code-review`   |
| `~/.agents/skills/code-review.md`       | `code-review`   |

This repository keeps `name` identical to the directory anyway: one
identifier means there is nothing to confuse, and `make validate` enforces the
agreement.

### Loading a skill

```text
Use the code-review skill for the current diff.
@code-review
```

Only the ID, the name and the description are offered to the model. The body is
loaded on demand, which is why skills should be precise rather than long.

## Permissions

Global permissions live in `opencode.jsonc` and apply before the per-agent
rules, so an agent can refine them but not silently widen them.

The ordering in the file is deliberate:

1. **Deny** the irreversible: `rm -rf`, `sudo`, `git push --force`,
   `git reset --hard`, `git clean -fdx`, `mkfs`.
2. **Ask** for anything leaving the machine or rewriting history: `git push`,
   `terraform apply`, `docker push`, `gh release`, publishing.
3. **Ask** to read real environment files; **deny** `~/.ssh`, `~/.aws`,
   `~/.netrc`.
4. **Allow** the read-only commands that run on nearly every turn.

Because the last matching rule wins, order matters more than volume.

Project configuration can refine global rules, so treat this file as a
strong default, not a sandbox.

## Reloading changes

OpenCode reloads configuration, agents, commands and skills automatically.
If a session does not pick up a change:

```bash
opencode reload
```

Restarting the background service also works:

```bash
opencode service restart
```

## Diagnosing problems

```bash
# Which agents does OpenCode actually see?
opencode debug agents

# Which configuration files are loaded, and in what order?
opencode debug config

# Where is OpenCode keeping its data?
opencode debug paths

# Are the skills installed?
ls ~/.agents/skills/
find ~/.agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l

# Full environment diagnosis.
make doctor
```

### Common problems

| Symptom                                | Cause                                             | Fix                                                       |
| -------------------------------------- | ------------------------------------------------- | --------------------------------------------------------- |
| An agent is missing                    | frontmatter invalid, or the file is not applied   | `make validate`, then `chezmoi apply`                      |
| An agent still edits files             | its `permissions` do not deny `edit`               | add `{ "action": "edit", "resource": "*", "effect": "deny" }` |
| A skill is not offered                | no `description`, or `autoinvoke` is `false`       | add a trigger-bearing description                          |
| A skill has the wrong ID               | the ID comes from the path                         | check the directory name, not the `name` field              |
| A command does not appear              | not a `.md` file, or nested under `command/`       | use `commands/`, plural                                     |
| `$ARGUMENTS` is literal                | not in the body                                   | it must be in the Markdown body                            |
| `opencode debug config` errors         | invalid JSONC                                     | `make validate` reports it; strip trailing commas          |
| Changes are not picked up              | stale session                                     | `opencode reload`                                           |

Never report a config problem as fixed without running `opencode debug config`
or `opencode debug agents` and reading the real output.

## Adding to this configuration

| I want to...                | Create or edit                                    | Validate with        |
| --------------------------- | -------------------------------------------------- | -------------------- |
| add an agent                | `home/dot_config/opencode/agents/<name>.md`        | `make validate`       |
| add a command               | `home/dot_config/opencode/commands/<name>.md`      | `make validate`       |
| add a skill                 | `home/dot_agents/skills/<name>/SKILL.md`           | `make validate`       |
| change a permission         | `home/dot_config/opencode/opencode.jsonc`          | `make validate`       |
| change the always-on rules  | `home/dot_config/opencode/AGENTS.md`               | `make validate`       |

The frontmatter fields accepted by this repository are limited to what the
installed OpenCode version documents. If you upgrade OpenCode and a field
starts being ignored, check the V2 documentation before adding a workaround.

## Reference

| Topic        | URL                                        |
| ------------ | ------------------------------------------ |
| index        | https://opencode.ai/v2/docs/               |
| config       | https://opencode.ai/v2/docs/config         |
| agents       | https://opencode.ai/v2/docs/agents         |
| commands     | https://opencode.ai/v2/docs/commands       |
| skills       | https://opencode.ai/v2/docs/skills         |
| permissions  | https://opencode.ai/v2/docs/permissions    |
| migration    | https://opencode.ai/v2/docs/migrate-v1     |
| troubleshooting | https://opencode.ai/v2/docs/troubleshooting |