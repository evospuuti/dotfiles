[CmdletBinding()]
param(
    [switch]$RunModelCalls
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $Failures.Add($Message) | Out-Null
}

function Invoke-Capture {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    $exitCode = 0
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Command 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Text = ($output | Out-String)
    }
}

function Assert-CommandContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    $result = Invoke-Capture -Command $Command
    if ($result.ExitCode -ne 0) {
        Add-Failure "$Label exited with code $($result.ExitCode): $($result.Text)"
        return
    }

    foreach ($pattern in $Patterns) {
        if ($result.Text -notmatch $pattern) {
            Add-Failure "$Label output missing pattern '$pattern'. Output: $($result.Text)"
        }
    }
}

$claude = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
$codex = Get-Command codex.cmd -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $claude) {
    Add-Failure 'claude command not found.'
}
else {
    Assert-CommandContains -Label 'claude --version' -Command { claude --version } -Patterns @('Claude Code')
    Assert-CommandContains -Label 'claude plugin --help' -Command { claude plugin --help } -Patterns @('install', 'list')
    Assert-CommandContains -Label 'claude agents --help' -Command { claude agents --help } -Patterns @('agents')
    Assert-CommandContains -Label 'claude mcp --help' -Command { claude mcp --help } -Patterns @('mcp')
}

if (-not $codex) {
    Add-Failure 'codex.cmd command not found.'
}
else {
    Assert-CommandContains -Label 'codex --version' -Command { & $codex.Source --version } -Patterns @('codex-cli')
    Assert-CommandContains -Label 'codex plugin --help' -Command { & $codex.Source plugin --help } -Patterns @('plugin')
    Assert-CommandContains -Label 'codex mcp --help' -Command { & $codex.Source mcp --help } -Patterns @('mcp')
    Assert-CommandContains -Label 'codex exec --help' -Command { & $codex.Source exec --help } -Patterns @('Run Codex non-interactively')
}

$hookTemplate = Join-Path $RepoRoot 'config/claude/hooks/settings.hooks.json.template'
$hookJson = Get-Content -LiteralPath $hookTemplate -Raw | ConvertFrom-Json
if (-not $hookJson.hooks.PostToolUse) {
    Add-Failure 'Claude hook template missing PostToolUse hook.'
}

$pluginNotes = Get-Content -LiteralPath (Join-Path $RepoRoot 'config/claude/plugins.md') -Raw
foreach ($pluginName in @('claude-code-setup', 'superpowers')) {
    if ($pluginNotes -notmatch [regex]::Escape($pluginName)) {
        Add-Failure "Plugin notes missing $pluginName."
    }
}

foreach ($agentName in @('code-reviewer', 'planner', 'researcher', 'test-runner')) {
    $agentPath = Join-Path $RepoRoot "config/claude/agents/$agentName.md"
    $agentText = Get-Content -LiteralPath $agentPath -Raw
    foreach ($field in @('name', 'description', 'tools')) {
        if ($agentText -notmatch "(?m)^$field\s*:") {
            Add-Failure "Subagent $agentName missing frontmatter field $field."
        }
    }
}

if ($RunModelCalls) {
    if ($claude) {
        $claudeResult = Invoke-Capture -Command { claude -p 'Return exactly: live-claude-ok' --model sonnet --permission-mode dontAsk --max-budget-usd 0.30 --no-session-persistence }
        if ($claudeResult.ExitCode -ne 0 -or $claudeResult.Text -notmatch 'live-claude-ok') {
            Add-Failure "Claude live model call failed: $($claudeResult.Text)"
        }
    }

    if ($codex) {
        $codexResult = Invoke-Capture -Command { & $codex.Source exec -C $RepoRoot --sandbox read-only -c 'approval_policy="never"' --ephemeral 'Return exactly: live-codex-ok' }
        if ($codexResult.ExitCode -ne 0 -or $codexResult.Text -notmatch 'live-codex-ok') {
            Add-Failure "Codex live model call failed: $($codexResult.Text)"
        }
    }
}

if ($Failures.Count -gt 0) {
    throw "Live surface tests failed:`n - $($Failures -join "`n - ")"
}

Write-Output 'Live surface tests passed.'
