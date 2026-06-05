# Agent Loops

Agent loops are bounded workflows for iterative work. Every loop needs:

- a goal
- a max iteration count or time budget
- a checkpoint cadence
- a verification command
- a stop condition
- a human handoff condition

## Patterns

### Build Loop

Research the request, write a plan, implement one small slice, verify it, review it, then either stop or start the next bounded slice.

### Monitor Loop

Check the target, summarize the observed state, compare it with the stop condition, then stop when the condition is met or the budget is exhausted.

### Subagent Loop

Dispatch narrow independent tasks, review outputs in the main thread, merge only the useful changes, then verify the integrated result.

## Rules

- Do not run infinite loops.
- Do not leave background work running without a visible checkpoint.
- Do not perform destructive writes inside a loop.
- Do not let a subagent activate hooks, plugins, secrets, or machine config.
- Record the final state and remaining risk before handoff.
