[CmdletBinding()]
param(
    [switch]$RunModelCalls,
    [switch]$RequireGraphify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path

& (Join-Path $RepoRoot 'tests/activation.windows.test.ps1') -RunModelCalls:$RunModelCalls -RequireGraphify:$RequireGraphify

Write-Output 'Windows activation harness tests passed.'
