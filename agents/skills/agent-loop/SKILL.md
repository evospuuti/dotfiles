---
name: agent-loop
description: Use when a user asks for loops autonomous agents recurring checks or iterative background work with bounded stop conditions.
---

# Agent Loop

Run only bounded loops with explicit checkpoints and stop conditions.

## Required Fields

- goal
- maximum iterations or time budget
- checkpoint cadence
- verification command
- stop condition
- handoff condition

## Workflow

1. State the loop contract before starting.
2. Execute one iteration at a time.
3. Check the stop condition after every iteration.
4. Report progress at each checkpoint.
5. Stop when the goal, budget, or handoff condition is reached.

## Common Mistakes

- Starting an open-ended loop.
- Leaving background commands running without a checkpoint.
- Letting a loop activate plugins, hooks, secrets, or machine config.
