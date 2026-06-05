# Platforms

## Windows PowerShell

Use `scripts/install.ps1` from a PowerShell session. Prefer backup mode when installing into an existing `%USERPROFILE%`. Symlinks may require Developer Mode or elevated permissions, so use the copy fallback when links are not reliable.

The `-Shell` scope copies the PowerShell helper to `~/.config/ai-dots/` only. It does not overwrite `$PROFILE`; dot-source it manually if you want it active.

Use `scripts/test.ps1` to verify the Windows installer with an isolated temporary home.

Use `scripts/test-live.ps1` to verify installed Claude Code and Codex CLI command surfaces. Add `-RunModelCalls` only when authenticated and willing to spend subscription or API budget.

## WSL2

Run the Bash installer inside the Linux filesystem when possible. Avoid installing from `/mnt/c` unless you intentionally want Windows files touched from WSL2. Keep WSL2 and Windows tool configs separate unless the path mapping is well understood.

`scripts/test.sh` verifies the Linux installer and checks Claude, Codex, and CodeRabbit CLI surfaces when the commands are available in `PATH`. Missing optional CLIs are reported as skips.

## Linux

Use `scripts/install.sh` from the repository root. Symlinks usually work well on native Linux, but backup existing files before replacing tool configuration.

Use `scripts/test.sh` to verify the Linux installer with an isolated temporary home.

The Linux test path does not make model calls. Use the Windows PowerShell live test with `-RunModelCalls` for authenticated Claude and Codex calls unless you have installed both CLIs inside the Linux environment.

## macOS

Use `scripts/install.sh` from Terminal. Git and shell helpers are optional; install them only when you want this repository to manage those files. macOS may create `.DS_Store`, which is covered by the global ignore template.

## Copy Fallback

If symlinks are blocked, unstable, or confusing across filesystems, copy files instead. Copy fallback is safer on locked-down Windows machines, synced folders, removable drives, and mixed Windows/WSL2 setups. Re-run the installer after repository updates to refresh copied files.
