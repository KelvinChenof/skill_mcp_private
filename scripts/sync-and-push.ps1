param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "D:\.codex" }),
  [string]$Branch = "main",
  [string]$CommitMessage = "chore: sync personal Codex skills and MCP",
  [switch]$SyncMattPocock
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found on PATH: $Name"
  }
}

function Invoke-Checked {
  param(
    [string]$Label,
    [scriptblock]$Command
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE."
  }
}

Require-Command "git"

Push-Location $RepoRoot
try {
  $currentBranch = (& git branch --show-current).Trim()
  if ($currentBranch -ne $Branch) {
    throw "Expected branch '$Branch' but current branch is '$currentBranch'."
  }

  $preSyncStatus = @(& git status --porcelain)
  if ($preSyncStatus.Count -gt 0) {
    throw "Working tree is not clean before sync. Commit, stash, or review local changes first."
  }

  Invoke-Checked "git fetch" { git fetch origin $Branch }
  Invoke-Checked "git pull" { git pull --ff-only origin $Branch }

  if ($SyncMattPocock) {
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "sync-mattpocock-skills.ps1") -CodexHome $CodexHome
    if ($LASTEXITCODE -ne 0) {
      throw "mattpocock/skills sync failed with exit code $LASTEXITCODE."
    }
  }

  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "sync-skills-from-local.ps1") -CodexHome $CodexHome
  if ($LASTEXITCODE -ne 0) {
    throw "Skill sync failed with exit code $LASTEXITCODE."
  }

  Invoke-Checked "git add" { git add -- `
    "plugins/personal-skill-mcp/skills" `
    "plugins/personal-skill-mcp/.mcp.json" `
    "mcp/servers.portable.json" `
    "scripts/install.ps1" `
    "scripts/sync-skills-from-local.ps1" `
    "scripts/sync-and-push.ps1" `
    "scripts/sync-mattpocock-skills.ps1" `
    "sources/mattpocock-skills.json" `
    "README.md" }

  & git diff --cached --quiet
  $diffExitCode = $LASTEXITCODE
  if ($diffExitCode -eq 0) {
    Write-Host "No managed skill or MCP changes to commit."
    exit 0
  }
  if ($diffExitCode -ne 1) {
    throw "git diff failed with exit code $diffExitCode."
  }

  Invoke-Checked "git commit" { git commit -m $CommitMessage }
  Invoke-Checked "git push" { git push origin $Branch }
  Write-Host "Synced, committed, and pushed managed skill/MCP changes."
}
finally {
  Pop-Location
}
