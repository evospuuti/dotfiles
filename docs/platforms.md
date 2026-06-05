# Platforms

## Windows PowerShell

Use `scripts/install.ps1` from a PowerShell session. Prefer backup mode when installing into an existing `%USERPROFILE%`. Symlinks may require Developer Mode or elevated permissions, so use the copy fallback when links are not reliable.

The `-Shell` scope copies the PowerShell helper to `~/.config/ai-dots/` only. It does not overwrite `$PROFILE`; dot-source it manually if you want it active.

## WSL2

Run the Bash installer inside the Linux filesystem when possible. Avoid installing from `/mnt/c` unless you intentionally want Windows files touched from WSL2. Keep WSL2 and Windows tool configs separate unless the path mapping is well understood.

## Linux

Use `scripts/install.sh` from the repository root. Symlinks usually work well on native Linux, but backup existing files before replacing tool configuration.

## macOS

Use `scripts/install.sh` from Terminal. Git and shell helpers are optional; install them only when you want this repository to manage those files. macOS may create `.DS_Store`, which is covered by the global ignore template.

## Copy Fallback

If symlinks are blocked, unstable, or confusing across filesystems, copy files instead. Copy fallback is safer on locked-down Windows machines, synced folders, removable drives, and mixed Windows/WSL2 setups. Re-run the installer after repository updates to refresh copied files.
