---
name: skill-creator
description: Create a new reusable OpenCode skill with valid frontmatter, a concrete step-by-step procedure, and a description that lets an agent select it automatically. Use this when a task has been solved twice in the same way, when onboarding a new recurring workflow, or when a skill needs to be updated.
---

# Skill Creator

## Objective

Produce a skill that an agent will select at the right moment and that
actually changes the behaviour, rather than a document nobody loads.

## When to use

- The same multi-step process has been performed twice by hand.
- A recurring workflow should become reusable.
- An existing skill is incomplete or has drifted from reality.
- A domain-specific procedure needs to be preserved.

## When not to use

- A one-step instruction. Put it in `AGENTS.md`.
- A lookup table. Keep it in a reference document.
- Something OpenCode already does better natively.
- The task has been done once and the procedure is still being discovered.

## Required inputs

- The objective: what problem the skill solves.
- The triggers: the situation in which an agent must load it.
- The procedure that actually worked, with its real steps.
- The constraints that were violated while learning it.

## Procedure

1. **Collect the evidence first.** Do not create a skill from an idea. Find
   the conversation, the plan or the run where this process was performed, and
   extract the steps that actually happened, including the mistakes.

2. **Write the trigger as a single sentence.** It must start with "Use this
   when..." and describe a *situation*, not a *topic*. Compare:

   - Weak: "Helps with debugging."
   - Strong: "Use this when a test fails and the cause is not obvious, when a
     failure is intermittent, or when behaviour differs between environments."

   If the trigger cannot be written, the skill is not needed.

3. **Propose the name.** Lowercase, single hyphens, no spaces, 1 to 64
   characters, matching `^[a-z0-9]+(-[a-z0-9]+)*$`. The directory name and the
   frontmatter `name` must be identical, because that is what keeps the skill
   identifiable across sources. Present the name to Luis before creating
   files.

4. **Check for overlap.** List the skills already present and read their
   descriptions. If the new skill covers ground an existing one already
   covers, extend that one instead. Two skills with overlapping triggers
   compete for the same slot and both are used less often.

5. **Write the description.** One or two sentences that say what the skill
   does *and* when to use it. This is the only text the model sees before
   deciding to load it, so it must carry the trigger. Vague descriptions
   produce skills that are never selected.

6. **Create the directory and `SKILL.md`:**

   ```text
   ~/.agents/skills/<name>/
   └── SKILL.md
   ```

7. **Write the body** with these sections, in this order:
   - `## Objective` — one or two sentences
   - `## When to use` — concrete situations
   - `## When not to use` — the boundary, including the neighbouring skill
   - `## Required inputs` — what must be known before starting
   - `## Procedure` — numbered steps, imperative voice, each one concrete
   - `## Constraints` — what must never happen
   - `## Validation checklist` — checkboxes that can actually be checked
   - `## Mandatory output format` — a template to fill in
   - `## Completion criteria` — when the skill has done its job

8. **Make the procedure executable, not descriptive.** Every step must be an
   action with an observable result. "Understand the problem" is not a step.
   "Run `git bisect` between the last known good commit and the current one and
   record each step" is.

9. **Add supporting files only when they earn their place.**
   - `references/` for material too long for `SKILL.md`, such as a checklist
     or a table.
   - `scripts/` for deterministic work worth reusing verbatim.
   Do not add either one to fill space.

10. **Validate.**
    - The frontmatter parses as YAML.
    - `name` matches the directory name exactly.
    - The description contains a trigger, not just a topic.
    - Every required section is present.
    - No step depends on a tool that may not exist.

11. **Report activation examples**, for example:

    ```text
    Use the code-review skill for the current diff.
    @code-review
    ```

12. **Note the reload behaviour.** OpenCode picks up skills automatically; if a
    new skill does not appear, `opencode reload` forces a refresh.

## Constraints

- Never create a skill without a real trigger sentence.
- Never duplicate an existing skill; extend it.
- Never write a procedure of vague verbs.
- Never leave `name` different from the directory name.
- Never add an `example` invocation that would not actually trigger the skill.
- Never put secrets, credentials or customer data in a skill.
- Never make a skill longer than it needs to be: unused sections are noise in
  every context where the skill is loaded.

## Validation checklist

- [ ] Built from a real procedure, not from an idea
- [ ] Trigger written as a "use this when" sentence describing a situation
- [ ] Name matches `^[a-z0-9]+(-[a-z0-9]+)*$`
- [ ] Directory name equals the frontmatter `name`
- [ ] Existing skills checked for overlap
- [ ] Description carries the trigger, not just the topic
- [ ] All nine required sections present
- [ ] Every procedure step is concrete and has an observable result
- [ ] Frontmatter parses as YAML
- [ ] Activation examples provided
- [ ] No secrets in the content

## Mandatory output format

```markdown
## Proposed skill
- **Name**: <name>
- **Directory**: `~/.agents/skills/<name>/`
- **Trigger**: <the "use this when" sentence>
- **Overlaps with**: <existing skill, or "nothing">

## Frontmatter
```yaml
name: <name>
description: <what it does and when to use it>
```

## Files created
| Path | Purpose |
|------|---------|
| `~/.agents/skills/<name>/SKILL.md` | the procedure |
| `~/.agents/skills/<name>/references/<file>.md` | <why this earns its place> |

## Sections included
- [ ] Objective
- [ ] When to use
- [ ] When not to use
- [ ] Required inputs
- [ ] Procedure
- [ ] Constraints
- [ ] Validation checklist
- [ ] Mandatory output format
- [ ] Completion criteria

## Validation
| Check | Result |
|-------|--------|
| Frontmatter parses as YAML | yes |
| name matches directory | yes |
| Name matches the kebab-case regex | yes |
| Description contains a trigger | yes |
| No duplicate skill | yes |

## Activation
```text
<example invocations that would actually select this skill>
```
```

## Completion criteria

- The name matches the kebab-case pattern and equals the directory name.
- The frontmatter is valid YAML with `name` and `description`.
- The description states both what the skill does and when to use it.
- The body contains all nine required sections.
- Every procedure step is concrete, with an observable result.
- Overlap with existing skills was checked before writing.
- Activation examples are provided and would genuinely trigger the skill.