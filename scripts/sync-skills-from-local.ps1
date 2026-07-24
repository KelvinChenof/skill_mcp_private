param(
  [string]$CodexHome = "$HOME\.codex"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SkillSource = Join-Path $CodexHome "skills"
$SkillTarget = Join-Path $RepoRoot "plugins\personal-skill-mcp\skills"

if (-not (Test-Path -LiteralPath $SkillSource)) {
  throw "Codex skills directory not found: $SkillSource"
}

New-Item -ItemType Directory -Path $SkillTarget -Force | Out-Null
Get-ChildItem -Path $SkillSource -Directory | Where-Object { $_.Name -ne ".system" } | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $SkillTarget -Recurse -Force
  Write-Host "Synced skill: $($_.Name)"
}

Get-ChildItem -Path $SkillTarget -Recurse -Force -File -Include ".coverage", "coverage-*.json" | ForEach-Object {
  Remove-Item -LiteralPath $_.FullName -Force
  Write-Host "Removed generated test artifact: $($_.FullName)"
}

Write-Host "Skill sync complete. Review git diff before committing."
