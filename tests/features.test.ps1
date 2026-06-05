[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $Failures.Add($Message) | Out-Null
}

function Get-RepoPath {
    param([string]$RelativePath)
    Join-Path $RepoRoot $RelativePath
}

foreach ($skillFile in Get-ChildItem -LiteralPath (Get-RepoPath 'agents/skills') -Directory | ForEach-Object { Join-Path $_.FullName 'SKILL.md' }) {
    $content = Get-Content -LiteralPath $skillFile -Raw
    if ($content -notmatch '(?m)^description:\s*Use when\b') {
        Add-Failure "Skill description must start with 'Use when': $skillFile"
    }
}

foreach ($agentFile in Get-ChildItem -LiteralPath (Get-RepoPath 'config/claude/agents') -File -Filter '*.md' | Where-Object { $_.Name -ne 'README.md' }) {
    $content = Get-Content -LiteralPath $agentFile.FullName -Raw
    foreach ($field in @('name', 'description', 'tools')) {
        if ($content -notmatch "(?m)^$field\s*:") {
            Add-Failure "Claude subagent missing frontmatter field '$field': $($agentFile.FullName)"
        }
    }
    if ($content -notmatch '(?m)^description:\s*Use when\b') {
        Add-Failure "Claude subagent description must start with 'Use when': $($agentFile.FullName)"
    }
}

$hookTemplate = Get-RepoPath 'config/claude/hooks/settings.hooks.json.template'
$hookJson = Get-Content -LiteralPath $hookTemplate -Raw | ConvertFrom-Json
$hookText = Get-Content -LiteralPath $hookTemplate -Raw
foreach ($blockedPattern in @('rm -rf', 'git reset', 'git clean', 'git push', 'plugin install', 'curl ', 'Invoke-WebRequest')) {
    if ($hookText -like "*$blockedPattern*") {
        Add-Failure "Hook template contains unsafe command pattern '$blockedPattern': $hookTemplate"
    }
}

$pluginNotes = Get-Content -LiteralPath (Get-RepoPath 'config/claude/plugins.md') -Raw
foreach ($requiredText in @('does not vendor plugin code', 'installers do not run plugin install commands', 'Keep plugin activation manual')) {
    if ($pluginNotes -notlike "*$requiredText*") {
        Add-Failure "Plugin notes missing safety text: $requiredText"
    }
}

if ($Failures.Count -gt 0) {
    throw "Feature tests failed:`n - $($Failures -join "`n - ")"
}

Write-Output 'Feature tests passed.'
