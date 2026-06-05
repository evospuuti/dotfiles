[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-dots-win-test-$([System.Guid]::NewGuid().ToString('N'))"
$shellHome = $null

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Assert-True -Condition (Test-Path -LiteralPath $Path -PathType Leaf) -Message "Expected file missing: $Path"
}

function Assert-NoFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Assert-True -Condition (-not (Test-Path -LiteralPath $Path -PathType Leaf)) -Message "Unexpected file exists: $Path"
}

try {
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

    & (Join-Path $RepoRoot 'scripts/install.ps1') -HomeRoot $TempRoot -Claude -Codex -Prompt plan

    Assert-File (Join-Path $TempRoot '.claude/CLAUDE.md')
    Assert-File (Join-Path $TempRoot '.claude/commands/plan.md')
    Assert-NoFile (Join-Path $TempRoot '.claude/commands/fix-ci.md')
    Assert-File (Join-Path $TempRoot '.codex/AGENTS.md')
    Assert-File (Join-Path $TempRoot '.codex/prompts/plan.md')
    Assert-NoFile (Join-Path $TempRoot '.codex/prompts/fix-ci.md')

    Assert-NoFile (Join-Path $TempRoot '.claude/agents/code-reviewer.md')
    Assert-NoFile (Join-Path $TempRoot '.claude/settings.json')
    Assert-NoFile (Join-Path $TempRoot '.codex/config.toml')

    & (Join-Path $RepoRoot 'scripts/install.ps1') -HomeRoot $TempRoot -DryRun -Claude | Out-Null

    $shellHome = Join-Path ([System.IO.Path]::GetTempPath()) "ai-dots-win-shell-test-$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $shellHome -Force | Out-Null
    & (Join-Path $RepoRoot 'scripts/install.ps1') -HomeRoot $shellHome -Shell
    Assert-File (Join-Path $shellHome '.config/ai-dots/Microsoft.PowerShell_profile.ps1')
    Assert-NoFile (Join-Path $shellHome 'Documents/PowerShell/Microsoft.PowerShell_profile.ps1')

    Write-Output 'Windows install tests passed.'
}
finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    if ($shellHome) {
        Remove-Item -LiteralPath $shellHome -Recurse -Force -ErrorAction SilentlyContinue
    }
}
