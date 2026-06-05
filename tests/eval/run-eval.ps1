[CmdletBinding()]
param(
    [ValidateSet('claude', 'codex')]
    [string]$Tool,

    [switch]$RepoMode,

    [string]$TaskId = 'plan-install-change',

    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'outputs')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$taskPrompts = @{
    'plan-install-change' = 'Create a scoped plan to add a new installer option without changing unrelated files.'
    'review-dotfiles-safety' = 'Review this dotfiles repository for safety issues and missing tests.'
    'mcp-template-advice' = 'Explain how to add a private MCP server safely to this repo.'
}

if (-not $taskPrompts.ContainsKey($TaskId)) {
    throw "Unknown task id: $TaskId"
}

$mode = if ($RepoMode) { 'repo' } else { 'baseline' }
$outputFile = Join-Path $OutputDirectory "$Tool-$mode-$TaskId.txt"
$prompt = $taskPrompts[$TaskId]

if ($RepoMode) {
    $prompt = "Use the repository instructions and relevant prompts or skills before answering.`n`n$prompt"
}
else {
    $prompt = "Ignore repository-specific instructions and answer using only general best practices.`n`n$prompt"
}

if ($Tool -eq 'claude') {
    $args = @('-p', $prompt, '--permission-mode', 'dontAsk', '--tools', '', '--max-budget-usd', '0.10')
    if (-not $RepoMode) {
        $args += @('--bare')
    }
    & claude @args | Tee-Object -FilePath $outputFile
}
elseif ($Tool -eq 'codex') {
    $codex = Get-Command 'codex.cmd' -ErrorAction SilentlyContinue
    if (-not $codex) {
        throw 'codex.cmd not found'
    }

    $args = @('exec', '-C', $RepoRoot, '--sandbox', 'read-only', '-c', 'approval_policy="never"', '--ephemeral', $prompt)
    if (-not $RepoMode) {
        $args = @('exec', '-C', $RepoRoot, '--sandbox', 'read-only', '-c', 'approval_policy="never"', '--ephemeral', '--ignore-rules', $prompt)
    }
    & $codex.Source @args | Tee-Object -FilePath $outputFile
}

Write-Output "Wrote eval output: $outputFile"
