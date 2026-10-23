# Project skills

This is the project-level skills location — the **single source** for skills that
apply only to this repository. It is read by Claude Code natively and by opencode
through the `.opencode/skill` symlink.

Each skill is a directory named after the skill, containing a `SKILL.md`:

```
.claude/skills/<name>/SKILL.md
```

`SKILL.md` frontmatter:

```markdown
---
name: <name>
description: One sentence: what the skill does AND when to trigger it.
---

# <Name>

(instructions, examples, references)
```

- `name` — lowercase, hyphen-separated; must match the folder name.
- `description` — required; this is what agents match against to decide relevance.

Machine-wide skills live in `~/.claude/skills/` (see `AGENTS.md`, section 1).
