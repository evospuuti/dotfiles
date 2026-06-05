# Secrets

No real secrets belong in this repository.

## Ignored Secret Files

`.env` and `.env.*` are ignored by the global Git ignore template. A safe `.env.example` file may be tracked when it contains only placeholder keys and non-sensitive defaults.

## Local Directories

`_local` directories are for private machine-specific files and should remain ignored except for tracked `.gitkeep` placeholders. Do not commit local MCP config, tool credentials, personal shell profiles, private keys, or host-specific paths.

## Templates

Tracked templates must use placeholders, not real values. Prefer names like `${TOKEN_NAME}`, `${PROJECT_ID}`, or `<path-to-local-file>` so users know what to provide locally.

## Credential Storage

Credentials belong in environment variables, ignored local files, OS credential stores, password managers, or secret managers. Installers and agents should not print, persist, or copy secret values into tracked files.
