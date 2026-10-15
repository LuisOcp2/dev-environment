---
description: Create a new reusable skill by following the skill-creator procedure.
agent: build
---

Create a new OpenCode skill.

Objective and triggers: `$ARGUMENTS`

## Required method

Use the `skill-creator` skill if it is available:

> Load the skill-creator skill and create a new skill for: $ARGUMENTS

If `skill-creator` is not available, follow this procedure directly. Either
way, the result must be a valid skill.

## Procedure

1. **Clarify the trigger.** What situation must make an agent load this skill
   automatically? Write it as a sentence that starts with "Use this when...".
   If it cannot be written, the skill is not needed yet.

2. **Propose the name.** Lowercase, single hyphens, no spaces, 1 to 64
   characters, matching the regex `^[a-z0-9]+(-[a-z0-9]+)*$`. The directory
   name and the frontmatter `name` must be identical. Confirm the name with
   Luis before creating files.

3. **Check for overlap.** List the existing skills under
   `~/.agents/skills/` and confirm the new one is not a duplicate. If it
   overlaps an existing skill, extend that one instead.

4. **Create the directory and `SKILL.md`** at
   `~/.agents/skills/<name>/SKILL.md`, with valid YAML frontmatter:

   ```yaml
   ---
   name: <name>
   description: <specific and detailed; this is what the model reads to decide>
   ---
   ```

   The body must contain: Objective, When to use, When not to use, Required
   inputs, Step-by-step procedure, Constraints, Validation checklist,
   Mandatory output format, Completion criteria.

5. **Add supporting files only if they earn their place**: a `references/`
   file for long material that would bloat `SKILL.md`, or a `scripts/` file
   for deterministic work. Skip them otherwise.

6. **Validate.**
   - The frontmatter parses as YAML.
   - `name` matches the directory name exactly.
   - The description is specific enough to select the skill automatically.

7. **Report activation examples**, for example:

   ```text
   Load the <name> skill for the current task.
   @<name>
   ```

8. **Reminders.** Remind Luis that skills are reloaded automatically by
   OpenCode; if the skill does not appear, run `opencode reload`.

## Required output

```markdown
## Proposed skill
- **Name**: <name>
- **Trigger**: <the "use this when" sentence>
- **Overlaps with**: <existing skill, or "nothing">

## Files created
- `~/.agents/skills/<name>/SKILL.md`
- <supporting files, with a reason for each>

## Validation
| Check | Result |
|-------|--------|
| Frontmatter parses | yes |
| name matches directory | yes |
| Description is specific | yes |

## Activation
```text
<example invocations>
```
```

## Completion criteria

- The name matches `^[a-z0-9]+(-[a-z0-9]+)*$` and equals the directory name.
- The frontmatter is valid YAML with `name` and `description`.
- The body contains every required section.
- The procedure is concrete and step by step, not a general description.
- Existing skills were checked for overlap first.