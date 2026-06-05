# Shared Agent Assets

The `agents/` directory contains reusable material for Claude and Codex.

- Prompts are source files. Installers copy selected prompts into Claude commands and Codex prompts.
- Skills are small folders with a required `SKILL.md`.
- `_local/` is ignored except for `.gitkeep` and is reserved for private local material.

Keep prompts and skills tool-neutral unless a file explicitly documents a Claude or Codex adapter.
