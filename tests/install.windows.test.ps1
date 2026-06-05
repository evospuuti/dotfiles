[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-dots-win-test-$([System.Guid]::NewGuid().ToString('N'))"
$shellHome = $null
$backupHome = $null

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
    Assert-File (Join-Path $TempRoot '.claude/skills/tdd/SKILL.md')
    Assert-File (Join-Path $TempRoot '.codex/skills/tdd/SKILL.md')

    Assert-NoFile (Join-Path $TempRoot '.claude/agents/code-reviewer.md')
    Assert-NoFile (Join-Path $TempRoot '.claude/settings.json')
    Assert-NoFile (Join-Path $TempRoot '.claude/mcp.json')
    Assert-NoFile (Join-Path $TempRoot '.codex/config.toml')
    Assert-NoFile (Join-Path $TempRoot '.codex/mcp.json')
    Assert-NoFile (Join-Path $TempRoot '.gitconfig.ai-dots')
    Assert-NoFile (Join-Path $TempRoot '.gitignore_global')

    & (Join-Path $RepoRoot 'scripts/install.ps1') -HomeRoot $TempRoot -DryRun -Claude | Out-Null

    $shellHome = Join-Path ([System.IO.Path]::GetTempPath()) "ai-dots-win-shell-test-$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $shellHome -Force | Out-Null
    & (Join-Path $RepoRoot 'scripts/install.ps1') -HomeRoot $shellHome -Shell
    Assert-File (Join-Path $shellHome '.config/ai-dots/Microsoft.PowerShell_profile.ps1')
    Assert-NoFile (Join-Path $shellHome 'Documents/PowerShell/Microsoft.PowerShell_profile.ps1')

    $backupHome = Join-Path ([System.IO.Path]::GetTempPath()) "ai-dots-win-backup-test-$([System.Guid]::NewGuid().ToString('N'))"
    $existingTarget = Join-Path $backupHome '.claude/CLAUDE.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $existingTarget) -Force | Out-Null
    Set-Content -LiteralPath $existingTarget -Value 'sentinel-existing-claude'

    $failed = $false
    try {
        & (Join-Path $RepoRoot 'scripts/install.ps1') -HomeRoot $backupHome -Claude -Prompt plan 2>$null
    }
    catch {
        $failed = $true
    }
    Assert-True -Condition $failed -Message 'Expected install without -Backup to fail when target exists.'
    Assert-True -Condition ((Get-Content -LiteralPath $existingTarget -Raw).Trim() -eq 'sentinel-existing-claude') -Message 'Install without backup changed existing target content.'

    & (Join-Path $RepoRoot 'scripts/install.ps1') -HomeRoot $backupHome -Claude -Prompt plan -Backup
    $backupFiles = @(Get-ChildItem -LiteralPath (Split-Path -Parent $existingTarget) -Filter 'CLAUDE.md.bak.*')
    Assert-True -Condition ($backupFiles.Count -eq 1) -Message 'Expected one CLAUDE.md backup file.'
    Assert-True -Condition ((Get-Content -LiteralPath $backupFiles[0].FullName -Raw).Trim() -eq 'sentinel-existing-claude') -Message 'Backup file did not preserve existing content.'
    Assert-True -Condition ((Get-Content -LiteralPath $existingTarget -Raw).Trim() -ne 'sentinel-existing-claude') -Message 'Backup install did not replace target content.'

    Write-Output 'Windows install tests passed.'
}
finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    if ($shellHome) {
        Remove-Item -LiteralPath $shellHome -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($backupHome) {
        Remove-Item -LiteralPath $backupHome -Recurse -Force -ErrorAction SilentlyContinue
    }
}
