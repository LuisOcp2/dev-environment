---
name: replace-with-kebab-case-name
description: Replace with one or two sentences stating what this skill does AND the concrete situation in which an agent must load it. The model reads only this field before deciding, so a vague description means the skill is never selected.
---

# Replace With The Skill Title

> Copy this file to `~/.agents/skills/<name>/SKILL.md`, then work through every
> section. Delete this blockquote before using it.
>
> Conventions and validation: `docs/ADDING-SKILLS.md`.

## Objective

<One or two sentences: what problem this skill solves and what a correct
result looks like.>

## When to use

- <A concrete situation, written so an agent recognises it.>
- <Another situation, not the same one reworded.>
- <A borderline case, so the skill is used instead of the neighbour.>

## When not to use

- <The case this skill looks like but is not.>
- <The neighbouring skill by name, and what to use instead.>
- <The situation that is too simple for a procedure.>

## Required inputs

- <What must be known before starting.>
- <What must exist in the repository.>
- <What must be decided by a human.>

## Procedure

1. <First action, imperative, with an observable result.>
2. <Second action. Never change more than one variable per step.>
3. <Record the result, so the next step has evidence to work from.>
4. <Verify, with the exact command that proves it.>
5. <Stop condition: what ends the procedure.>

## Constraints

- <What must never happen.>
- <What must never be modified.>
- <What must always be confirmed before doing it.>

## Validation checklist

- [ ] <Something that can actually be checked.>
- [ ] <Another check.>
- [ ] <The final proof that the objective was met.>

## Mandatory output format

```markdown
## Summary
<what was done, in two sentences>

## Evidence
| Claim | How verified | Result |
|-------|--------------|--------|
| ...   | ...          | ...    |

## Findings
- <what matters, or "none">

## Next steps
- <what remains, or "none">
```

## Completion criteria

- <The objective is met, stated as a checkable condition.>
- <Every claim is backed by evidence.>
- <The constraints held throughout.>