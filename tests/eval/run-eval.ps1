[CmdletBinding()]
param(
    [ValidateSet('claude', 'codex')]
    [string]$Tool,

    [switch]$RepoMode,

    [string]$TaskId = 'plan-install-change',

    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $PSScriptRoot 'outputs'
}
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

function Get-TextSnippet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [int]$MaxLines = 80
    )

    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return "Missing file: $RelativePath"
    }

    $lines = @(Get-Content -LiteralPath $path | Select-Object -First $MaxLines)
    "### $RelativePath`n" + ($lines -join "`n")
}

function Get-SharedContext {
    param([string]$TaskId)

    $common = @(
        Get-TextSnippet 'README.md' 80
        Get-TextSnippet 'docs/llms.md' 80
        Get-TextSnippet 'docs/install.md' 80
        Get-TextSnippet 'docs/secrets.md' 80
    )

    if ($TaskId -eq 'plan-install-change') {
        $common += Get-TextSnippet 'scripts/install.ps1' 120
        $common += Get-TextSnippet 'scripts/install.sh' 120
    }
    elseif ($TaskId -eq 'review-dotfiles-safety') {
        $common += Get-TextSnippet '.gitignore' 80
        $common += Get-TextSnippet 'scripts/check.ps1' 140
        $common += Get-TextSnippet 'scripts/check.sh' 140
    }
    elseif ($TaskId -eq 'mcp-template-advice') {
        $common += Get-TextSnippet 'docs/mcp.md' 120
        $common += Get-TextSnippet 'config/claude/mcp.json.template' 80
        $common += Get-TextSnippet 'config/codex/mcp.json.template' 80
    }

    $common -join "`n`n"
}

function Get-RepoModeInstructions {
    param([string]$TaskId)

    $instructions = @(
        Get-TextSnippet 'AGENTS.md' 80
        Get-TextSnippet 'agents/AGENTS.md' 80
    )

    if ($TaskId -eq 'plan-install-change') {
        $instructions += Get-TextSnippet 'agents/prompts/plan.md' 80
    }
    elseif ($TaskId -eq 'review-dotfiles-safety') {
        $instructions += Get-TextSnippet 'agents/prompts/gh-review.md' 80
        $instructions += Get-TextSnippet 'agents/skills/code-review/SKILL.md' 80
    }
    elseif ($TaskId -eq 'mcp-template-advice') {
        $instructions += Get-TextSnippet 'agents/skills/mcp-safety/SKILL.md' 100
    }

    $instructions -join "`n`n"
}

$sharedContext = Get-SharedContext -TaskId $TaskId
$taskText = $taskPrompts[$TaskId]

if ($RepoMode) {
    $repoInstructions = Get-RepoModeInstructions -TaskId $TaskId
    $prompt = @"
You are evaluating this dotfiles repository.

Use the repository-specific instructions below when answering.

$repoInstructions

Repository context:

$sharedContext

Task:

$taskText
"@
}
else {
    $prompt = @"
You are evaluating this dotfiles repository.

Do not use repository-specific prompt or skill instructions. Use only general engineering best practices.

Repository context:

$sharedContext

Task:

$taskText
"@
}

$promptFile = Join-Path $OutputDirectory "$Tool-$mode-$TaskId.prompt.txt"
Set-Content -LiteralPath $promptFile -Value $prompt

if ($Tool -eq 'claude') {
    $args = @('-p', '--model', 'sonnet', '--permission-mode', 'dontAsk', '--tools', '', '--max-budget-usd', '0.35', '--no-session-persistence')
    Get-Content -LiteralPath $promptFile -Raw | & claude @args | Tee-Object -FilePath $outputFile
}
elseif ($Tool -eq 'codex') {
    $codex = Get-Command 'codex.cmd' -ErrorAction SilentlyContinue
    if (-not $codex) {
        throw 'codex.cmd not found'
    }

    $args = @('exec', '-C', $RepoRoot, '--sandbox', 'read-only', '-c', 'approval_policy="never"', '--ephemeral', '-')
    if (-not $RepoMode) {
        $args = @('exec', '-C', $RepoRoot, '--sandbox', 'read-only', '-c', 'approval_policy="never"', '--ephemeral', '--ignore-rules', '-')
    }
    Get-Content -LiteralPath $promptFile -Raw | & $codex.Source @args | Tee-Object -FilePath $outputFile
}

Write-Output "Wrote eval output: $outputFile"
