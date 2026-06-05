[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$Failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $Failures.Add($Message) | Out-Null
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

function Assert-RequiredFiles {
    $requiredFiles = @(
        '.gitignore',
        'README.md',
        'AGENTS.md',
        'agents/AGENTS.md',
        'agents/prompts/README.md',
        'agents/prompts/registry.yaml',
        'agents/prompts/plan.md',
        'agents/prompts/fix-ci.md',
        'agents/prompts/gh-review.md',
        'agents/prompts/make-tests.md',
        'agents/prompts/html-report.md',
        'agents/prompts/youtube-transcript.md',
        'agents/prompts/excalidraw.md',
        'agents/prompts/subagent-review.md',
        'agents/prompts/agent-loop.md',
        'agents/skills/README.md',
        'agents/skills/agent-loop/SKILL.md',
        'agents/skills/code-review/SKILL.md',
        'agents/skills/diagnose/SKILL.md',
        'agents/skills/excalidraw/SKILL.md',
        'agents/skills/html-report/SKILL.md',
        'agents/skills/mcp-safety/SKILL.md',
        'agents/skills/subagent-review/SKILL.md',
        'agents/skills/tdd/SKILL.md',
        'agents/skills/youtube-transcript/SKILL.md',
        'config/claude/README.md',
        'config/claude/CLAUDE.md',
        'config/claude/plugins.md',
        'config/claude/agents/README.md',
        'config/claude/agents/code-reviewer.md',
        'config/claude/agents/researcher.md',
        'config/claude/agents/planner.md',
        'config/claude/agents/test-runner.md',
        'config/claude/hooks/README.md',
        'config/claude/hooks/settings.hooks.json.template',
        'config/claude/settings.json.template',
        'config/claude/mcp.json.template',
        'config/codex/README.md',
        'config/codex/AGENTS.md',
        'config/codex/config.toml.template',
        'config/codex/mcp.json.template',
        'config/git/gitconfig.template',
        'config/git/gitignore_global',
        'config/powershell/Microsoft.PowerShell_profile.ps1',
        'config/shell/aliases.sh',
        'config/shell/env.sh',
        'docs/install.md',
        'docs/agent-loops.md',
        'docs/llms.md',
        'docs/mcp.md',
        'docs/platforms.md',
        'docs/secrets.md',
        'scripts/install.ps1',
        'scripts/install.sh',
        'scripts/check.ps1',
        'scripts/check.sh',
        'scripts/test.ps1',
        'scripts/test.sh',
        'tests/install.windows.test.ps1',
        'tests/install.linux.test.sh',
        'tests/features.test.ps1',
        'tests/eval/README.md',
        'tests/eval/rubric.yaml',
        'tests/eval/run-eval.ps1'
    )

    foreach ($relativePath in $requiredFiles) {
        $path = Join-RepoPath $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Add-Failure "Missing required file: $path"
        }
    }
}

function Test-JsonTemplates {
    $jsonTemplates = @(
        Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter '*.json.template' |
            Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.FullName -notmatch '[\\/]_local[\\/]' }
    )

    foreach ($template in $jsonTemplates) {
        try {
            Get-Content -LiteralPath $template.FullName -Raw | ConvertFrom-Json | Out-Null
        }
        catch {
            Add-Failure "Invalid JSON template: $($template.FullName) ($($_.Exception.Message))"
        }
    }
}

function Test-TomlWithPython {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TomlPath
    )

    $pythonScript = @'
import sys

if sys.version_info < (3, 11):
    sys.exit(2)

import tomllib

with open(sys.argv[1], chr(114) + chr(98)) as template:
    tomllib.load(template)
'@

    foreach ($pythonName in @('python3', 'python')) {
        $python = Get-Command $pythonName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $python) {
            continue
        }

        try {
            & $python.Source -c $pythonScript $TomlPath
            $exitCode = $LASTEXITCODE
        }
        catch {
            continue
        }

        if ($exitCode -eq 0) {
            return $true
        }

        if ($exitCode -eq 2) {
            continue
        }

        Add-Failure "Invalid TOML template: $TomlPath (Python tomllib exited with code $exitCode)"
        return $true
    }

    $false
}

function Test-TomlTemplate {
    $tomlPath = Join-RepoPath 'config/codex/config.toml.template'
    if (-not (Test-Path -LiteralPath $tomlPath -PathType Leaf)) {
        return
    }

    if (Test-TomlWithPython -TomlPath $tomlPath) {
        return
    }

    $requiredLines = @(
        'approval_policy = "on-request"',
        'sandbox_mode = "workspace-write"',
        '[features]',
        'child_agents_md = true'
    )
    $actualLines = @(Get-Content -LiteralPath $tomlPath)

    foreach ($requiredLine in $requiredLines) {
        if ($actualLines -notcontains $requiredLine) {
            Add-Failure "TOML template missing required literal line in ${tomlPath}: $requiredLine"
        }
    }
}

function Get-FrontmatterField {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Frontmatter,

        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )

    foreach ($line in $Frontmatter) {
        if ($line -match "^\s*$([regex]::Escape($FieldName)):\s*(.+?)\s*$") {
            return Convert-YamlScalar -Value $Matches[1]
        }
    }

    $null
}

function Test-SkillFrontmatter {
    $skillsRoot = Join-RepoPath 'agents/skills'
    if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
        return
    }

    $skillFiles = @(
        Get-ChildItem -LiteralPath $skillsRoot -Directory |
            ForEach-Object { Join-Path $_.FullName 'SKILL.md' }
    )

    if ($skillFiles.Count -eq 0) {
        Add-Failure "No skill files found under: $skillsRoot"
        return
    }

    foreach ($skillFile in $skillFiles) {
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            Add-Failure "Missing skill file: $skillFile"
            continue
        }

        $lines = @(Get-Content -LiteralPath $skillFile)
        if ($lines.Count -eq 0 -or $lines[0].TrimEnd("`r") -ne '---') {
            Add-Failure "Skill file must start with frontmatter delimiter: $skillFile"
            continue
        }

        $frontmatterEnd = $null
        for ($index = 1; $index -lt $lines.Count; $index++) {
            if ($lines[$index].TrimEnd("`r") -eq '---') {
                $frontmatterEnd = $index
                break
            }
        }

        if ($null -eq $frontmatterEnd) {
            Add-Failure "Skill file missing closing frontmatter delimiter: $skillFile"
            continue
        }

        if ($frontmatterEnd -le 1) {
            $frontmatter = @()
        }
        else {
            $frontmatter = $lines[1..($frontmatterEnd - 1)]
        }

        $name = Get-FrontmatterField -Frontmatter $frontmatter -FieldName 'name'
        $description = Get-FrontmatterField -Frontmatter $frontmatter -FieldName 'description'

        if ([string]::IsNullOrWhiteSpace($name)) {
            Add-Failure "Skill frontmatter missing non-empty name: $skillFile"
        }

        if ([string]::IsNullOrWhiteSpace($description)) {
            Add-Failure "Skill frontmatter missing non-empty description: $skillFile"
        }
    }
}

function Get-PromptRegistryEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegistryPath
    )

    $entries = @()
    $current = $null
    $inTools = $false

    foreach ($rawLine in Get-Content -LiteralPath $RegistryPath) {
        $line = $rawLine -replace "`r$", ''

        if ($line -match '^\s*-\s+name:\s*(.+?)\s*$') {
            if ($current) {
                $entries += [pscustomobject]$current
            }

            $current = [ordered]@{
                Name = Convert-YamlScalar -Value $Matches[1]
                File = $null
                Tools = @()
            }
            $inTools = $false
            continue
        }

        if (-not $current) {
            continue
        }

        if ($line -match '^\s*file:\s*(.+?)\s*$') {
            $current.File = Convert-YamlScalar -Value $Matches[1]
            continue
        }

        if ($line -match '^\s*tools:\s*$') {
            $inTools = $true
            continue
        }

        if ($inTools -and $line -match '^\s*-\s*(.+?)\s*$') {
            $current.Tools += Convert-YamlScalar -Value $Matches[1]
        }
    }

    if ($current) {
        $entries += [pscustomobject]$current
    }

    $entries
}

function Test-PromptRegistry {
    $registryPath = Join-RepoPath 'agents/prompts/registry.yaml'
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        return
    }

    $promptRoot = Join-RepoPath 'agents/prompts'
    $entries = @(Get-PromptRegistryEntries -RegistryPath $registryPath)

    if ($entries.Count -eq 0) {
        Add-Failure "No prompts registered in: $registryPath"
        return
    }

    foreach ($entry in $entries) {
        if ([string]::IsNullOrWhiteSpace($entry.Name)) {
            Add-Failure "Prompt registry entry has an empty name: $registryPath"
        }

        if ([string]::IsNullOrWhiteSpace($entry.File)) {
            Add-Failure "Prompt registry entry '$($entry.Name)' missing file field: $registryPath"
        }
        else {
            $promptPath = Join-Path $promptRoot $entry.File
            if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
                Add-Failure "Prompt registry references missing file: $promptPath (prompt: $($entry.Name), registry: $registryPath)"
            }
        }

        if ($entry.Tools -notcontains 'claude') {
            Add-Failure "Prompt registry entry '$($entry.Name)' missing tool 'claude': $registryPath"
        }

        if ($entry.Tools -notcontains 'codex') {
            Add-Failure "Prompt registry entry '$($entry.Name)' missing tool 'codex': $registryPath"
        }
    }
}

function Get-SourceFilesForSecretScan {
    $git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($git) {
        $gitFiles = @(& $git.Source -C $RepoRoot ls-files --cached --others --exclude-standard 2>$null)
        if ($LASTEXITCODE -eq 0) {
            foreach ($relativePath in $gitFiles) {
                if (-not $relativePath) {
                    continue
                }

                $normalized = $relativePath -replace '\\', '/'
                if ($normalized -match '(^|/)\.git(/|$)' -or $normalized -match '(^|/)_local(/|$)') {
                    continue
                }

                $path = Join-Path $RepoRoot $relativePath
                if (Test-Path -LiteralPath $path -PathType Leaf) {
                    $path
                }
            }
            return
        }
    }

    Get-ChildItem -LiteralPath $RepoRoot -Recurse -File |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.FullName -notmatch '[\\/]_local[\\/]' } |
        ForEach-Object { $_.FullName }
}

function Test-SecretPatterns {
    $secretChecks = @(
        @{ Label = 'OpenAI-style key prefix'; Pattern = ('s' + 'k-') },
        @{ Label = 'GitHub token prefix'; Pattern = ('g' + 'hp_') },
        @{ Label = 'Slack bot token prefix'; Pattern = ('x' + 'oxb-') },
        @{ Label = 'PEM block header'; Pattern = ('-' * 5 + 'BEGIN') }
    )

    foreach ($filePath in @(Get-SourceFilesForSecretScan)) {
        foreach ($secretCheck in $secretChecks) {
            try {
                $match = Select-String -LiteralPath $filePath -SimpleMatch -Pattern $secretCheck.Pattern -ErrorAction Stop | Select-Object -First 1
                if ($match) {
                    Add-Failure "Secret-like pattern ($($secretCheck.Label)) found in: $filePath"
                    break
                }
            }
            catch {
                Add-Failure "Could not scan file for secrets: $filePath ($($_.Exception.Message))"
                break
            }
        }
    }
}

function Test-LiveConfigFiles {
    $forbiddenRelativePaths = @(
        'config/claude/settings.json',
        'config/claude/mcp.json',
        'config/codex/config.toml',
        'config/codex/mcp.json'
    )

    $repoPrefix = $RepoRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    foreach ($filePath in @(Get-SourceFilesForSecretScan)) {
        if (-not $filePath.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $relativePath = $filePath.Substring($repoPrefix.Length) -replace '\\', '/'
        if ($forbiddenRelativePaths -contains $relativePath) {
            Add-Failure "Live local config file must not be tracked or staged: $relativePath"
        }
    }
}

Assert-RequiredFiles
Test-JsonTemplates
Test-TomlTemplate
Test-SkillFrontmatter
Test-PromptRegistry
Test-SecretPatterns
Test-LiveConfigFiles

if ($Failures.Count -gt 0) {
    $message = "Repository check failed:`n - " + ($Failures -join "`n - ")
    throw $message
}

Write-Output "Repository check passed."
