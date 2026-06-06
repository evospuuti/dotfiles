[CmdletBinding()]
param(
    [switch]$RunModelCalls,
    [switch]$RequireGraphify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Failures = [System.Collections.Generic.List[string]]::new()
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ai-dots-activation-win-$([System.Guid]::NewGuid().ToString('N'))"
$ProbeServer = Join-Path $RepoRoot 'tests/fixtures/mcp/ai_dots_probe_server.py'

function Add-Failure {
    param([string]$Message)
    $Failures.Add($Message) | Out-Null
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        Add-Failure $Message
    }
}

function Assert-File {
    param([string]$Path)
    Assert-True -Condition (Test-Path -LiteralPath $Path -PathType Leaf) -Message "Expected file: $Path"
}

function Invoke-Capture {
    param([Parameter(Mandatory = $true)][scriptblock]$Command)

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
    param([string]$Label, [scriptblock]$Command, [string[]]$Patterns)

    $result = Invoke-Capture -Command $Command
    if ($result.ExitCode -ne 0) {
        Add-Failure "$Label exited with code $($result.ExitCode): $($result.Text)"
        return
    }

    foreach ($pattern in $Patterns) {
        if ($result.Text -notmatch $pattern) {
            Add-Failure "$Label missing '$pattern'. Output: $($result.Text)"
        }
    }
}

function Test-InstalledHarness {
    & (Join-Path $RepoRoot 'scripts/install.ps1') -HomeRoot $TempRoot -All | Out-Null

    foreach ($relativePath in @(
        '.claude/CLAUDE.md',
        '.claude/commands/graphify.md',
        '.claude/skills/graphify/SKILL.md',
        '.codex/AGENTS.md',
        '.codex/prompts/graphify.md',
        '.codex/skills/graphify/SKILL.md',
        '.gitconfig.ai-dots',
        '.gitignore_global',
        '.config/ai-dots/aliases.sh',
        '.config/ai-dots/env.sh',
        '.config/ai-dots/Microsoft.PowerShell_profile.ps1'
    )) {
        Assert-File (Join-Path $TempRoot $relativePath)
    }
}

function Test-ClaudePlugins {
    $claude = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
    Assert-True -Condition ($null -ne $claude) -Message 'claude command not found.'
    if (-not $claude) { return }

    Assert-CommandContains -Label 'claude plugin list' -Command { claude plugin list } -Patterns @(
        'claude-code-setup',
        'superpowers'
    )
    Assert-CommandContains -Label 'claude plugin details claude-code-setup' -Command { claude plugin details claude-code-setup } -Patterns @('claude-code-setup')
    Assert-CommandContains -Label 'claude plugin details superpowers' -Command { claude plugin details superpowers } -Patterns @('superpowers')
}

function Test-CodexPlugins {
    $codex = Get-Command codex.cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    Assert-True -Condition ($null -ne $codex) -Message 'codex.cmd command not found.'
    if (-not $codex) { return }

    Assert-CommandContains -Label 'codex plugin marketplace help' -Command { & $codex.Source plugin marketplace --help } -Patterns @('add', 'upgrade', 'remove')
    $codexConfig = Join-Path $env:USERPROFILE '.codex/config.toml'
    if (Test-Path -LiteralPath $codexConfig -PathType Leaf) {
        $configText = Get-Content -LiteralPath $codexConfig -Raw
        Assert-True -Condition ($configText -match 'superpowers@openai-curated') -Message 'Codex user config missing superpowers plugin.'
        Assert-True -Condition ($configText -match 'coderabbit@openai-curated') -Message 'Codex user config missing coderabbit plugin.'
    }
}

function Test-CodexMcpConfig {
    $codex = Get-Command codex.cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $codex) { return }

    $python = (Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1)
    Assert-True -Condition ($null -ne $python) -Message 'python command not found for MCP probe server.'
    if (-not $python) { return }

    $result = Invoke-Capture -Command {
        & $codex.Source mcp list --json `
            -c "mcp_servers.ai_dots_probe.command='$($python.Source)'" `
            -c "mcp_servers.ai_dots_probe.args=['$($ProbeServer.Replace('\', '\\'))']"
    }
    if ($result.ExitCode -ne 0) {
        Add-Failure "codex mcp list with probe config failed: $($result.Text)"
        return
    }

    Assert-True -Condition ($result.Text -match 'ai_dots_probe') -Message "Codex MCP list missing probe server: $($result.Text)"
}

function Test-Graphify {
    $graphify = Get-Command graphify -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $graphify) {
        if ($RequireGraphify) {
            Add-Failure 'graphify command not found.'
        }
        else {
            Write-Output 'Skipping Graphify activation: graphify not found.'
        }
        return
    }

    $graphRoot = Join-Path $TempRoot 'graphify-project'
    New-Item -ItemType Directory -Path $graphRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $graphRoot 'probe.py') -Value 'def probe(): return "graphify-ok"'

    Assert-CommandContains -Label 'graphify install --help' -Command { & $graphify.Source install --help } -Patterns @('Platforms')
    $runResult = Invoke-Capture -Command { Push-Location $graphRoot; try { & $graphify.Source . } finally { Pop-Location } }
    if ($runResult.ExitCode -ne 0) {
        Add-Failure "graphify . failed: $($runResult.Text)"
        return
    }
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $graphRoot 'graphify-out') -PathType Container) -Message 'Graphify did not create graphify-out/.'
}

function Test-ClaudeHookModelCall {
    $claude = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $claude) { return }

    $hookRoot = Join-Path $TempRoot 'claude-hook'
    New-Item -ItemType Directory -Path $hookRoot -Force | Out-Null
    $marker = Join-Path $hookRoot 'hook-marker.txt'
    $hookScript = Join-Path $hookRoot 'hook.ps1'
    $settingsPath = Join-Path $hookRoot 'settings.json'

    Set-Content -LiteralPath $hookScript -Value "Add-Content -LiteralPath '$($marker.Replace("'", "''"))' -Value 'post-tool-use'"
    $settings = @{
        hooks = @{
            PostToolUse = @(
                @{
                    matcher = 'Bash'
                    hooks = @(
                        @{
                            type = 'command'
                            command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$hookScript`""
                        }
                    )
                }
            )
        }
    }
    $settings | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $settingsPath

    $result = Invoke-Capture -Command {
        claude -p 'Use the Bash tool exactly once to run: echo ai-dots-hook-tool. Then return exactly: claude-hook-ok' `
            --model sonnet `
            --permission-mode dontAsk `
            --allowedTools Bash `
            --settings $settingsPath `
            --include-hook-events `
            --output-format stream-json `
            --verbose `
            --max-budget-usd 0.40 `
            --no-session-persistence
    }

    if ($result.ExitCode -ne 0 -or $result.Text -notmatch 'claude-hook-ok') {
        Add-Failure "Claude hook model call failed: $($result.Text)"
    }
    Assert-True -Condition (Test-Path -LiteralPath $marker -PathType Leaf) -Message 'Claude PostToolUse hook did not write marker.'
}

function Test-ClaudeMcpModelCall {
    $claude = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
    $python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $claude -or -not $python) { return }

    $mcpPath = Join-Path $TempRoot 'claude-mcp.json'
    @{
        mcpServers = @{
            ai_dots_probe = @{
                command = $python.Source
                args = @($ProbeServer)
            }
        }
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $mcpPath

    $result = Invoke-Capture -Command {
        claude -p 'Use the MCP tool named mcp__ai_dots_probe__probe exactly once. Return exactly the tool result text and nothing else.' `
            --model sonnet `
            --permission-mode dontAsk `
            --allowedTools mcp__ai_dots_probe__probe `
            --mcp-config $mcpPath `
            --strict-mcp-config `
            --max-budget-usd 0.50 `
            --no-session-persistence
    }

    if ($result.ExitCode -ne 0 -or $result.Text -notmatch 'ai-dots-mcp-ok') {
        Add-Failure "Claude MCP model call failed: $($result.Text)"
    }
}

function Test-ClaudeSkillAndSubagentModelCalls {
    $claude = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $claude) { return }

    $skillProject = Join-Path $TempRoot 'claude-skill-project'
    New-Item -ItemType Directory -Path (Join-Path $skillProject '.claude/skills') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'agents/skills/graphify') -Destination (Join-Path $skillProject '.claude/skills/graphify') -Recurse

    $skillResult = Invoke-Capture -Command {
        Push-Location $skillProject
        try {
            claude -p '/graphify Return exactly: graphify-skill-ok' --model sonnet --permission-mode dontAsk --tools '' --max-budget-usd 0.30 --no-session-persistence
        }
        finally {
            Pop-Location
        }
    }
    if ($skillResult.ExitCode -ne 0 -or $skillResult.Text -notmatch 'graphify-skill-ok') {
        Add-Failure "Claude graphify skill invocation failed: $($skillResult.Text)"
    }

    $agentsJson = '{"ai-dots-test":{"description":"Return the requested marker.","prompt":"You are an activation-test subagent. Always return exactly claude-subagent-ok and nothing else."}}'
    $agentResult = Invoke-Capture -Command {
        claude -p 'Return exactly: claude-subagent-ok' --model sonnet --permission-mode dontAsk --tools '' --agents $agentsJson --agent ai-dots-test --max-budget-usd 0.30 --no-session-persistence
    }
    if ($agentResult.ExitCode -ne 0 -or $agentResult.Text -notmatch 'claude-subagent-ok') {
        Add-Failure "Claude subagent invocation failed: $($agentResult.Text)"
    }
}

function Test-CodexMcpModelCall {
    $codex = Get-Command codex.cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    $python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $codex -or -not $python) { return }

    $configPath = Join-Path $env:USERPROFILE '.codex/config.toml'
    $backupPath = $null
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        $backupPath = "$configPath.ai-dots-activation.bak"
        Copy-Item -LiteralPath $configPath -Destination $backupPath -Force
    }

    try {
        Invoke-Capture -Command { & $codex.Source mcp remove ai_dots_probe } | Out-Null
        $addResult = Invoke-Capture -Command { & $codex.Source mcp add ai_dots_probe -- $python.Source $ProbeServer }
        if ($addResult.ExitCode -ne 0) {
            Add-Failure "Codex MCP add failed: $($addResult.Text)"
            return
        }

        $result = Invoke-Capture -Command {
            & $codex.Source exec -C $RepoRoot --sandbox read-only -c 'approval_policy="never"' --ephemeral `
                -c "mcp_servers.ai_dots_probe.default_tools_approval_mode='approve'" `
                'Use the MCP tool mcp__ai_dots_probe__probe exactly once. Return exactly the tool result text and nothing else.'
        }

        if ($result.ExitCode -ne 0 -or $result.Text -notmatch 'ai-dots-mcp-ok') {
            Add-Failure "Codex MCP model call failed: $($result.Text)"
        }
    }
    finally {
        Invoke-Capture -Command { & $codex.Source mcp remove ai_dots_probe } | Out-Null
        if ($backupPath -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            Copy-Item -LiteralPath $backupPath -Destination $configPath -Force
            Remove-Item -LiteralPath $backupPath -Force
        }
    }
}

function Test-CodexPromptAndSkillModelCall {
    $codex = Get-Command codex.cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $codex) { return }

    $context = Get-Content -LiteralPath (Join-Path $RepoRoot 'agents/prompts/graphify.md') -Raw
    $context += "`n`n"
    $context += Get-Content -LiteralPath (Join-Path $RepoRoot 'agents/skills/graphify/SKILL.md') -Raw
    $prompt = @"
Use this installed prompt and skill context.

$context

Return exactly: codex-graphify-skill-ok
"@

    $result = Invoke-Capture -Command {
        $prompt | & $codex.Source exec -C $RepoRoot --sandbox read-only -c 'approval_policy="never"' --ephemeral --ignore-rules -
    }
    if ($result.ExitCode -ne 0 -or $result.Text -notmatch 'codex-graphify-skill-ok') {
        Add-Failure "Codex prompt and skill model call failed: $($result.Text)"
    }
}

try {
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

    Test-InstalledHarness
    Test-ClaudePlugins
    Test-CodexPlugins
    Test-CodexMcpConfig
    Test-Graphify

    if ($RunModelCalls) {
        Test-ClaudeHookModelCall
        Test-ClaudeMcpModelCall
        Test-ClaudeSkillAndSubagentModelCalls
        Test-CodexMcpModelCall
        Test-CodexPromptAndSkillModelCall
    }

    if ($Failures.Count -gt 0) {
        throw "Windows activation tests failed:`n - $($Failures -join "`n - ")"
    }

    Write-Output 'Windows activation tests passed.'
}
finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
