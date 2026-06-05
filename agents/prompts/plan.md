# plan

Turn the request into a concrete, scoped implementation plan before editing files.

Include:

- target outcome;
- assumptions;
- files likely to change;
- verification commands;
- risks or decisions that need user approval.

For installer or harness changes, always include both Windows and Unix paths:

- `scripts/install.ps1` and `scripts/install.sh`;
- `tests/install.windows.test.ps1` and `tests/install.linux.test.sh`;
- `scripts/test.ps1` and `scripts/test.sh`.

Do not stop at a clarification question when a conservative assumption is possible. State the assumption, keep the plan reversible, and call out where user approval is required.

For dotfiles plans, explicitly avoid writing into a real home directory during tests and avoid committing secrets, tokens, live MCP files, or local machine paths.

Keep the plan focused enough to complete in one development pass.
