[CmdletBinding()]
param(
    [switch]$Claude,
    [switch]$Codex,
    [switch]$Git,
    [switch]$Shell,
    [switch]$All,
    [switch]$DryRun,
    [switch]$Backup,
    [switch]$ListPrompts,
    [string[]]$Prompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$PromptRegistry = Join-Path $RepoRoot 'agents/prompts/registry.yaml'

function Get-Timestamp {
    Get-Date -Format 'yyyyMMddHHmmss'
}

function Join-RepoPath {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Parts
    )

    $path = $RepoRoot
    foreach ($part in $Parts) {
        $path = Join-Path $path $part
    }
    $path
}

function Join-HomePath {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Parts
    )

    $path = $HOME
    foreach ($part in $Parts) {
        $path = Join-Path $path $part
    }
    $path
}

function Convert-YamlScalar {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $trimmed = $Value.Trim()
    if ($trimmed.Length -ge 2) {
        $first = $trimmed.Substring(0, 1)
        $last = $trimmed.Substring($trimmed.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            return $trimmed.Substring(1, $trimmed.Length - 2)
        }
    }

    $trimmed
}

function Invoke-Action {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    if ($DryRun) {
        Write-Output "[dry-run] $Message"
    }
    else {
        & $Action
    }
}

function Backup-Existing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    if (Test-Path -LiteralPath $Target) {
        if ($Backup) {
            $backupTarget = "$Target.bak.$(Get-Timestamp)"
            Invoke-Action "Move existing $Target -> $backupTarget" {
                Move-Item -LiteralPath $Target -Destination $backupTarget
            }
        }
        elseif ($DryRun) {
            Write-Output "[dry-run] Target already exists and would require -Backup or manual removal: $Target"
        }
        else {
            throw "Target already exists: $Target. Use -Backup to move it aside before copying."
        }
    }
}

function Copy-FileSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Source file not found: $Source"
    }

    $parent = Split-Path -Parent $Target

    Backup-Existing -Target $Target
    Invoke-Action "Create directory $parent" {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Invoke-Action "Copy file $Source -> $Target" {
        Copy-Item -LiteralPath $Source -Destination $Target
    }
}

function Copy-DirectorySafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Target
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Source directory not found: $Source"
    }

    $parent = Split-Path -Parent $Target

    Backup-Existing -Target $Target
    Invoke-Action "Create directory $parent" {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Invoke-Action "Copy directory $Source -> $Target" {
        Copy-Item -LiteralPath $Source -Destination $Target -Recurse
    }
}

function Get-PromptEntries {
    if (-not (Test-Path -LiteralPath $PromptRegistry -PathType Leaf)) {
        throw "Prompt registry not found: $PromptRegistry"
    }

    $entries = @()
    $currentName = $null

    foreach ($rawLine in Get-Content -LiteralPath $PromptRegistry) {
        $line = $rawLine -replace "`r$", ''

        if ($line -match '^\s*-\s+name:\s*(.+?)\s*$') {
            $currentName = Convert-YamlScalar -Value $Matches[1]
            continue
        }

        if ($currentName -and $line -match '^\s*file:\s*(.+?)\s*$') {
            $entries += [pscustomobject]@{
                Name = $currentName
                File = Convert-YamlScalar -Value $Matches[1]
            }
            $currentName = $null
        }
    }

    $entries
}

function Show-Prompts {
    $entries = @(Get-PromptEntries)
    foreach ($entry in $entries) {
        Write-Output $entry.Name
    }
}

function Get-NormalizedPromptNames {
    $names = @()
    $seen = @{}

    if (-not $Prompt -or $Prompt.Count -eq 0) {
        return $names
    }

    foreach ($promptValue in $Prompt) {
        foreach ($promptName in ($promptValue -split ',')) {
            $trimmedName = $promptName.Trim()
            if (-not $trimmedName) {
                continue
            }

            if ($seen.ContainsKey($trimmedName)) {
                continue
            }

            $seen[$trimmedName] = $true
            $names += $trimmedName
        }
    }

    $names
}

function Get-SelectedPromptEntries {
    $entries = @(Get-PromptEntries)
    $entriesByName = @{}

    foreach ($entry in $entries) {
        $entriesByName[$entry.Name] = $entry
    }

    $promptNames = @(Get-NormalizedPromptNames)
    if ($promptNames.Count -gt 0) {
        $selected = @()
        foreach ($promptName in $promptNames) {
            if (-not $entriesByName.ContainsKey($promptName)) {
                $available = ($entries | ForEach-Object { $_.Name }) -join ', '
                throw "Prompt not found: $promptName. Available prompts: $available"
            }
            $selected += $entriesByName[$promptName]
        }
        return $selected
    }

    $entries
}

function Install-Prompts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetRoot,

        [Parameter(Mandatory = $true)]
        [object[]]$Entries
    )

    foreach ($entry in $Entries) {
        $source = Join-RepoPath 'agents' 'prompts' $entry.File
        $target = Join-Path $TargetRoot "$($entry.Name).md"
        Copy-FileSafe -Source $source -Target $target
    }
}

function Install-Skills {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetRoot
    )

    $sourceRoot = Join-RepoPath 'agents' 'skills'
    foreach ($skillDir in Get-ChildItem -LiteralPath $sourceRoot -Directory) {
        $target = Join-Path $TargetRoot $skillDir.Name
        Copy-DirectorySafe -Source $skillDir.FullName -Target $target
    }
}

function Install-Claude {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$PromptEntries
    )

    Copy-FileSafe -Source (Join-RepoPath 'config' 'claude' 'CLAUDE.md') -Target (Join-HomePath '.claude' 'CLAUDE.md')
    Copy-FileSafe -Source (Join-RepoPath 'config' 'claude' 'settings.json.template') -Target (Join-HomePath '.claude' 'settings.json.template')
    Copy-FileSafe -Source (Join-RepoPath 'config' 'claude' 'mcp.json.template') -Target (Join-HomePath '.claude' 'mcp.json.template')
    Install-Prompts -TargetRoot (Join-HomePath '.claude' 'commands') -Entries $PromptEntries
    Install-Skills -TargetRoot (Join-HomePath '.claude' 'skills')
}

function Install-Codex {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$PromptEntries
    )

    Copy-FileSafe -Source (Join-RepoPath 'config' 'codex' 'AGENTS.md') -Target (Join-HomePath '.codex' 'AGENTS.md')
    Copy-FileSafe -Source (Join-RepoPath 'config' 'codex' 'config.toml.template') -Target (Join-HomePath '.codex' 'config.toml.template')
    Copy-FileSafe -Source (Join-RepoPath 'config' 'codex' 'mcp.json.template') -Target (Join-HomePath '.codex' 'mcp.json.template')
    Install-Prompts -TargetRoot (Join-HomePath '.codex' 'prompts') -Entries $PromptEntries
    Install-Skills -TargetRoot (Join-HomePath '.codex' 'skills')
}

function Install-Git {
    Copy-FileSafe -Source (Join-RepoPath 'config' 'git' 'gitconfig.template') -Target (Join-HomePath '.gitconfig.ai-dots')
    Copy-FileSafe -Source (Join-RepoPath 'config' 'git' 'gitignore_global') -Target (Join-HomePath '.gitignore_global')
}

function Install-Shell {
    Copy-FileSafe -Source (Join-RepoPath 'config' 'shell' 'aliases.sh') -Target (Join-HomePath '.config' 'ai-dots' 'aliases.sh')
    Copy-FileSafe -Source (Join-RepoPath 'config' 'shell' 'env.sh') -Target (Join-HomePath '.config' 'ai-dots' 'env.sh')
    Copy-FileSafe -Source (Join-RepoPath 'config' 'powershell' 'Microsoft.PowerShell_profile.ps1') -Target (Join-HomePath '.config' 'ai-dots' 'Microsoft.PowerShell_profile.ps1')
}

try {
    if ($ListPrompts) {
        Show-Prompts
        exit 0
    }

    $scopeSelected = [bool]($Claude -or $Codex -or $Git -or $Shell -or $All)
    $installClaude = [bool]$Claude
    $installCodex = [bool]$Codex
    $installGit = [bool]$Git
    $installShell = [bool]$Shell

    if ($All) {
        $installClaude = $true
        $installCodex = $true
        $installGit = $true
        $installShell = $true
    }
    elseif (-not $scopeSelected) {
        $installClaude = $true
        $installCodex = $true
    }

    $promptEntries = @(Get-SelectedPromptEntries)

    if ($installClaude) {
        Install-Claude -PromptEntries $promptEntries
    }

    if ($installCodex) {
        Install-Codex -PromptEntries $promptEntries
    }

    if ($installGit) {
        Install-Git
    }

    if ($installShell) {
        Install-Shell
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
