# Agent Loop

Run a bounded agent loop.

Before starting define:

- goal
- maximum iterations or time budget
- checkpoint cadence
- verification command
- stop condition
- handoff condition

Execute one iteration at a time. Stop when the goal, budget, or handoff condition is reached. Never run an infinite loop.
