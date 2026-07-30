param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "D:\.codex" }),
  [string]$RepoUrl = "https://github.com/mattpocock/skills.git",
  [string]$Ref = "main",
  [string]$ManifestPath = $(Join-Path (Split-Path -Parent $PSScriptRoot) "sources\mattpocock-skills.json"),
  [switch]$AdoptExistingDestinations,
  [switch]$SkipNormalizeDisableModelInvocation,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SkillTargetRoot = Join-Path $CodexHome "skills"

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

function Invoke-RobocopyChecked {
  param(
    [string]$Source,
    [string]$Destination,
    [switch]$ListOnly
  )

  $args = @($Source, $Destination, "/MIR", "/NFL", "/NDL", "/NJH", "/NJS", "/NP")
  if ($ListOnly) {
    $args += "/L"
  }
  & robocopy @args | Out-Host
  $code = $LASTEXITCODE
  if ($code -gt 7) {
    throw "robocopy failed with exit code $code."
  }
}

function Get-RelativePath {
  param(
    [string]$Root,
    [string]$Path
  )

  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  return $pathFull.Substring($rootFull.Length).Replace('\', '/')
}

function Get-TreeFingerprint {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return ""
  }

  $items = Get-ChildItem -LiteralPath $Path -Recurse -File -Force |
    Sort-Object FullName |
    ForEach-Object {
      $relative = Get-RelativePath -Root $Path -Path $_.FullName
      $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
      "$relative=$hash"
    }

  return ($items -join "`n")
}

function Normalize-SkillFrontmatter {
  param([string]$SkillPath)

  $skillFile = Join-Path $SkillPath "SKILL.md"
  if (-not (Test-Path -LiteralPath $skillFile)) {
    return
  }

  $text = [System.IO.File]::ReadAllText($skillFile)
  $newText = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    '(?m)^(disable-model-invocation:\s*)true\s*$',
    '${1}false'
  )

  if ($newText -ne $text) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($skillFile, $newText, $encoding)
  }
}

Require-Command "git"
Require-Command "robocopy"

if (-not (Test-Path -LiteralPath $SkillTargetRoot)) {
  throw "Codex skills directory not found: $SkillTargetRoot"
}

$manifest = $null
if (Test-Path -LiteralPath $ManifestPath) {
  $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
}

$knownNames = @{}
if ($manifest -and $manifest.skills) {
  foreach ($skill in $manifest.skills) {
    $knownNames[$skill.name] = $true
  }
}

$tempRoot = Join-Path $env:TEMP ("mattpocock-skills-sync-" + [System.Guid]::NewGuid().ToString("N"))
$changed = New-Object System.Collections.Generic.List[string]
$added = New-Object System.Collections.Generic.List[string]
$updated = New-Object System.Collections.Generic.List[string]
$skippedCollisions = New-Object System.Collections.Generic.List[string]
$syncedManifestSkills = New-Object System.Collections.Generic.List[object]

try {
  Invoke-Checked "git clone" { git clone --depth 1 --branch $Ref $RepoUrl $tempRoot }
  $commit = (& git -C $tempRoot rev-parse HEAD).Trim()

  $skillDirs = Get-ChildItem -LiteralPath $tempRoot -Recurse -Filter SKILL.md |
    ForEach-Object { $_.Directory } |
    Sort-Object FullName

  foreach ($skillDir in $skillDirs) {
    $skillName = Split-Path -Leaf $skillDir.FullName
    $sourcePath = $skillDir.FullName
    $sourceRelative = Get-RelativePath -Root $tempRoot -Path $sourcePath
    $destinationPath = Join-Path $SkillTargetRoot $skillName
    $destinationExists = Test-Path -LiteralPath $destinationPath
    $isKnown = $knownNames.ContainsKey($skillName)

    if ($destinationExists -and -not $isKnown -and -not $AdoptExistingDestinations) {
      $skippedCollisions.Add("$skillName ($sourceRelative)") | Out-Null
      continue
    }

    if (-not $SkipNormalizeDisableModelInvocation) {
      Normalize-SkillFrontmatter -SkillPath $sourcePath
    }

    $sourceFingerprint = Get-TreeFingerprint -Path $sourcePath
    $destinationFingerprint = Get-TreeFingerprint -Path $destinationPath
    $needsSync = $sourceFingerprint -ne $destinationFingerprint

    if ($needsSync) {
      $changed.Add($skillName) | Out-Null
      if ($destinationExists) {
        $updated.Add($skillName) | Out-Null
      }
      else {
        $added.Add($skillName) | Out-Null
      }

      if (-not $DryRun) {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        Invoke-RobocopyChecked -Source $sourcePath -Destination $destinationPath
      }
    }

    $syncedManifestSkills.Add([pscustomobject]@{
      name = $skillName
      path = $sourceRelative
    }) | Out-Null
  }

  if (-not $DryRun) {
    $manifestDir = Split-Path -Parent $ManifestPath
    New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null

    $payload = [pscustomobject]@{
      repo = "mattpocock/skills"
      url = $RepoUrl
      ref = $Ref
      lastSyncedCommit = $commit
      normalizeDisableModelInvocation = (-not $SkipNormalizeDisableModelInvocation.IsPresent)
      skills = @($syncedManifestSkills | Sort-Object name)
      skippedCollisions = @($skippedCollisions)
    }

    $json = $payload | ConvertTo-Json -Depth 8
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ManifestPath, $json + [Environment]::NewLine, $encoding)
  }

  Write-Host "mattpocock/skills commit: $commit"
  Write-Host "Checked upstream skills: $($skillDirs.Count)"
  Write-Host "Changed local skills: $($changed.Count)"
  if ($added.Count -gt 0) {
    Write-Host "Added: $($added -join ', ')"
  }
  if ($updated.Count -gt 0) {
    Write-Host "Updated: $($updated -join ', ')"
  }
  if ($skippedCollisions.Count -gt 0) {
    Write-Host "Skipped possible local-name collisions: $($skippedCollisions -join ', ')"
  }
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
    $resolvedBase = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if ($resolvedTemp.StartsWith($resolvedBase, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
  }
}
