# Skills

Skills are small, reusable workflows for Claude and Codex.

Each skill lives in its own folder and must contain `SKILL.md` with frontmatter:

```yaml
---
name: skill-name
description: Use when ...
---
```

Keep always-loaded instructions short. Put longer examples in `references/` when a skill needs them.
