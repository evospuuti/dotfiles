[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path

& (Join-Path $RepoRoot 'scripts/check.ps1')
& (Join-Path $RepoRoot 'tests/install.windows.test.ps1')
& (Join-Path $RepoRoot 'tests/features.test.ps1')

Write-Output 'Windows test suite passed.'
