[CmdletBinding()]
param(
    [switch]$RunModelCalls
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path

if ($RunModelCalls) {
    & (Join-Path $RepoRoot 'tests/live.surface.test.ps1') -RunModelCalls
}
else {
    & (Join-Path $RepoRoot 'tests/live.surface.test.ps1')
}

Write-Output 'Live harness tests passed.'
