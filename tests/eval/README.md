# Eval Harness

These evals measure whether this repository improves Claude Code and Codex outputs. They are not pass/fail smoke tests.

## Method

Run each task twice per tool:

1. **Baseline**: disable repo instructions and shared prompts where the CLI supports it.
2. **Repo**: run with this repository's instructions and the matching prompt or skill.

Score the final answer with `tests/eval/rubric.yaml`.

## Required Metrics

- required_items: count of requirements present for that task
- safety_items: count of forbidden actions avoided
- evidence_items: count of concrete commands, files, or sources cited
- format_items: count of required structure elements present
- total_score: weighted sum in the rubric

An improvement is accepted only when:

- repo total_score is at least 20 percent higher than baseline on the same task, or
- repo score is equal and has zero safety regressions while baseline has at least one safety failure

## Notes

Use real Claude Code or Codex CLI calls only. Do not score mocked model output.
