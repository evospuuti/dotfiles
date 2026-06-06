# Persistent Context

This repository treats persistent context as an AI harness feature, not as a
Claude Projects dependency. Claude Projects are useful inspiration because they
combine project instructions with uploaded project knowledge, but this repo must
work for Claude Code and Codex on Windows, Linux, and macOS.

## What Matters

Keep these patterns:

- Structured instructions: write role, context, rules, output defaults, and
  verification expectations as separate sections instead of prose.
- Priority hierarchy: separate critical rules, standard workflows, and
  preferences so agents can resolve tension between instructions.
- Knowledge base files: keep stable reference material in descriptive files
  under `docs/`, `agents/`, `config/claude/`, and `config/codex/`.
- Living instructions: when an agent repeats a mistake, update the smallest
  durable artifact that would have prevented it.
- Calibration: after changing prompts, skills, MCP templates, hooks, or plugin
  notes, run the checks and at least one representative task or eval.
- Audits: periodically remove stale instructions, conflicting rules, and files
  that no longer match the current harness.

## Tool Mapping

For Claude Code:

- Shared project guidance belongs in `CLAUDE.md`, `.claude/CLAUDE.md`, imported
  markdown files, or path-scoped rules when using a live project.
- Personal preferences belong in ignored local files or the user-level Claude
  home, not in this repository.
- Repeatable workflows belong in skills, prompts, hooks, or subagents depending
  on whether they are knowledge, commands, enforcement, or delegation.

For Codex:

- Shared guidance belongs in `AGENTS.md`, user/repo Codex instructions, prompts,
  and skills.
- Repeatable work should be tested with `tests/eval/` or activation tests rather
  than described only in prose.
- Local machine assumptions, private MCP config, subscriptions, and secrets stay
  outside tracked files.

## What Not To Import

Do not treat Claude Projects web features as Claude Code or Codex features.
Project chat history, uploaded web-project files, and Claude web UI settings are
not automatically available to CLI agents unless the relevant content is copied
into the CLI-visible project files or passed in the prompt.

Do not commit:

- client-specific project knowledge
- personal writing samples
- private research notes
- real MCP config
- account-specific settings
- tokens, API keys, browser login codes, or secrets

## Review Checklist

Use this checklist when deciding whether a new context item belongs here:

1. Is it stable enough to help future sessions?
2. Is it useful to both Claude Code and Codex, or does it clearly belong in one
   adapter directory?
3. Can it be verified by a check, activation test, or eval?
4. Is it free of private paths, secrets, subscriptions, and personal machine
   assumptions?
5. Is it small enough to avoid bloating always-loaded agent context?

If the answer to any item is no, prefer an ignored local file, a temporary prompt,
or a per-task note instead of adding it to this repository.
