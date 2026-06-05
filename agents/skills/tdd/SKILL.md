---
name: tdd
description: Use when implementing a feature or bugfix with a red-green-refactor loop.
---

# TDD

1. Define the expected behavior in a focused test.
2. Run the test and confirm it fails for the expected reason.
3. Implement the smallest change that makes it pass.
4. Rerun the focused test.
5. Rerun the nearest broader verification command.

Prefer behavior tests over implementation-detail tests.
