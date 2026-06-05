[CmdletBinding()]
param(
    [switch]$RunModelCalls
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path

& (Join-Path $RepoRoot 'scripts/test.ps1')

if ($RunModelCalls) {
    & (Join-Path $RepoRoot 'scripts/test-live.ps1') -RunModelCalls
}
else {
    & (Join-Path $RepoRoot 'scripts/test-live.ps1')
}

Write-Output 'Complete harness tests passed.'
