# Adding skills

A skill is a reusable, self-contained procedure that an agent loads when the
situation matches. It lives at:

```text
~/.agents/skills/<skill-id>/SKILL.md
```

In this repository that path is:

```text
home/dot_agents/skills/<skill-id>/SKILL.md
```

## Anatomy of SKILL.md

```markdown
---
name: <skill-id>
description: <what it does and when to use it>
---

# Title

## Objective
## When to use
## When not to use
## Required inputs
## Procedure
## Constraints
## Validation checklist
## Mandatory output format
## Completion criteria
```

### The frontmatter

| Field         | Required | Purpose                                                |
| ------------- | -------- | ------------------------------------------------------ |
| `name`        | yes      | display name. **Must equal the directory name.**        |
| `description` | yes      | the only text the model sees before deciding to load it |

The `description` is the single most important field. A vague description means
the skill is never selected, and a skill that is never selected is dead code.

Compare:

- Weak: `Helps with debugging.`
- Strong: `Investigates failures using reproduction, evidence and one
  hypothesis at a time. Use this when a test fails and the cause is not
  obvious, when a failure is intermittent, or when behaviour differs between
  environments.`

Note how the strong description carries the trigger: it tells the model *when*
to reach for the skill, not only *what* it is about.

## Conventions

| Rule                                    | Reason                                        |
| --------------------------------------- | --------------------------------------------- |
| directory name is `^[a-z0-9]+(-[a-z0-9]+)*$` | portable, matches the tool ID            |
| `name` equals the directory name        | one identifier, no ambiguity                  |
| lowercase, single hyphens, no spaces    | the ID is used verbatim in prompts            |
| start the body with `#` and a real title | readability                                   |
| every section present                   | `make validate` enforces this                 |
| procedures use imperative verbs         | a procedure is an action list, not prose      |
| no secrets, no customer data            | these files load into every session           |
| English                                 | matches the rest of the technical repository  |

## Creating a skill

### 1. Decide whether a skill is the right tool

| Need                              | Use instead                |
| --------------------------------- | -------------------------- |
| a single rule that always applies | `AGENTS.md`                |
| a lookup table                    | a reference document       |
| a one-time answer                 | just answer the question   |
| a multi-step process, done twice  | **a skill**                |

### 2. Gather the evidence first

Do not write a skill from an idea. Find the run where the process actually
worked and extract the real steps, including the mistakes.

### 3. Choose the name

```bash
# Must match ^[a-z0-9]+(-[a-z0-9]+)*$
echo "database-design" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' && echo "valid"
```

### 4. Check for overlap

```bash
ls -1 home/dot_agents/skills/
head -n 4 home/dot_agents/skills/*/SKILL.md
```

If the new skill covers ground an existing one covers, extend the existing
skill instead. Two skills with overlapping triggers compete for the same slot.

### 5. Create it

```bash
mkdir -p home/dot_agents/skills/my-skill
cp templates/skill/SKILL.md home/dot_agents/skills/my-skill/SKILL.md
$EDITOR home/dot_agents/skills/my-skill/SKILL.md
```

Or from inside OpenCode, using the command:

```text
/new-skill create a skill for <what it should do>
```

which follows the `skill-creator` skill and validates the result.

### 6. Validate

```bash
make validate
```

This checks, for every skill:

- the directory name matches `^[a-z0-9]+(-[a-z0-9]+)*$`
- `SKILL.md` exists
- the YAML frontmatter is delimited correctly
- `name` exists and equals the directory name
- `description` exists and is long enough to be useful
- all nine required sections are present

### 7. Preview the change and apply

```bash
make diff
make apply
```

### 8. Commit

```bash
git add home/dot_agents/skills/my-skill/
git commit -m "feat(skills): add my-skill"
```

## Supporting files

Add them only when they earn their place:

```text
home/dot_agents/skills/my-skill/
├── SKILL.md            the procedure itself
├── references/
│   └── checklist.md    long material that would bloat SKILL.md
└── scripts/
    └── validate.sh     deterministic work worth reusing verbatim
```

Paths written inside a skill are relative to the directory containing
`SKILL.md`. Supporting file contents are not loaded automatically; the skill
must tell the agent when to read them.

## Testing a skill

```bash
# 1. Structural validation.
make validate

# 2. Confirm it is installed.
ls ~/.agents/skills/my-skill/SKILL.md

# 3. Confirm OpenCode sees it.
opencode debug agents

# 4. Trigger it in a real session.
opencode
> use the my-skill skill for <a realistic task>
```

Test the *trigger*, not just the content. If you cannot describe a realistic
situation where an agent should reach for this skill, the description needs
work and the skill may not be needed at all.

## Modifying a skill

```bash
$EDITOR home/dot_agents/skills/my-skill/SKILL.md
make validate
make diff && make apply
```

When changing a procedure, keep the parts that still apply. A skill that
accumulates contradictory steps is worse than no skill, because it is trusted.

If a procedure has become stale, narrow the trigger in the description so it
is only offered where it still applies.

## Disabling a skill

OpenCode frontmatter supports hiding a skill from the model without deleting
it. Add this to the frontmatter:

```yaml
---
name: my-skill
description: What it does and when to use it.
metadata:
  opencode/autoinvoke: false
---
```

The skill stays registered and can still be loaded explicitly by name, but it
is no longer advertised. The equivalent field is `disable-model-invocation:
true`; when both are present, `metadata.opencode/autoinvoke` wins.

After changing this, the skill is no longer offered automatically. Re-enabling
means removing the metadata block.

A second option, without touching the file: add a permission rule to
`~/.config/opencode/opencode.jsonc`:

```jsonc
{
  "permissions": [{ "action": "skill", "resource": "my-skill", "effect": "deny" }]
}
```

## Deleting a skill

```bash
git rm -r home/dot_agents/skills/my-skill/
make validate
make diff && make apply

# Remove the files that were applied to $HOME.
rm -rf ~/.agents/skills/my-skill
```

Prefer disabling to deleting when the skill might be needed again.

## Where each piece lives

| Location                                        | Managed by chezmoi | Purpose                    |
| ----------------------------------------------- | ------------------ | -------------------------- |
| `home/dot_agents/skills/<id>/SKILL.md`           | yes                | the canonical skill source |
| `templates/skill/SKILL.md`                      | no                 | the starting template      |
| `docs/ADDING-SKILLS.md`                          | no                 | this document              |

Edit the source under `home/`, never `~/.agents/skills/` directly. A direct
edit is removed on the next `chezmoi apply`.

## Troubleshooting

| Problem                            | Cause                                     | Fix                                                |
| ---------------------------------- | ----------------------------------------- | -------------------------------------------------- |
| Skill does not appear              | not applied, or `~/.agents/skills` missing | `chezmoi apply`, then confirm the path exists        |
| Skill appears but is never used    | the description lacks a trigger            | rewrite it as "Use this when ..."                    |
| `make validate` reports a name mismatch | `name` differs from the directory       | make them identical                                  |
| Body loads without the frontmatter | expected behaviour                        | frontmatter is metadata, not content                |
| Supporting files are missing       | the skill never says to read them         | add an explicit step referencing the path            |

Run `opencode reload` after changing skills if a running session does not pick
them up. See `docs/OPENCODE.md`.