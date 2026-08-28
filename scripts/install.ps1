param(
  [string]$CodexHome = "$HOME\.codex",
  [string]$Timezone = "Asia/Shanghai",
  [string[]]$FilesystemRoots = @(),
  [string]$GitRepository = "",
  [switch]$SkipSkills,
  [switch]$SkipMcp,
  [switch]$IncludeDocker,
  [switch]$IncludeDatabases,
  [switch]$IncludeSsh,
  [switch]$IncludeFeishu
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$PluginRoot = Join-Path $RepoRoot "plugins\personal-skill-mcp"
$SkillSource = Join-Path $PluginRoot "skills"
$SkillTarget = Join-Path $CodexHome "skills"

function Require-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found on PATH: $Name"
  }
}

function Add-Mcp {
  param(
    [string]$Name,
    [string[]]$CommandArgs,
    [hashtable]$EnvVars = @()
  )

  $existing = & codex mcp get $Name 2>$null
  if ($LASTEXITCODE -eq 0 -and $existing) {
    & codex mcp remove $Name | Out-Null
  }

  $args = @("mcp", "add", $Name)
  foreach ($key in $EnvVars.Keys) {
    $args += @("--env", "$key=$($EnvVars[$key])")
  }
  $args += "--"
  $args += $CommandArgs
  & codex @args
}

function Add-McpUrl {
  param(
    [string]$Name,
    [string]$Url
  )

  $existing = & codex mcp get $Name 2>$null
  if ($LASTEXITCODE -eq 0 -and $existing) {
    & codex mcp remove $Name | Out-Null
  }

  & codex mcp add $Name --url $Url
}

Require-Command "codex"

if (-not $SkipSkills) {
  New-Item -ItemType Directory -Path $SkillTarget -Force | Out-Null
  Get-ChildItem -Path $SkillSource -Directory | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $SkillTarget -Recurse -Force
    Write-Host "Installed skill: $($_.Name)"
  }
}

if (-not $SkipMcp) {
  Require-Command "npx"
  Require-Command "uvx"

  $defaultRoots = @($HOME, $CodexHome)
  $downloads = Join-Path $HOME "Downloads"
  if (Test-Path -LiteralPath $downloads) {
    $defaultRoots += $downloads
  }
  $allRoots = @($defaultRoots + $FilesystemRoots) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

  Add-Mcp "filesystem" (@("npx", "-y", "@modelcontextprotocol/server-filesystem") + $allRoots)
  Add-Mcp "memory" @("npx", "-y", "@modelcontextprotocol/server-memory")
  Add-Mcp "sequential_thinking" @("npx", "-y", "@modelcontextprotocol/server-sequential-thinking")
  Add-Mcp "context7" @("npx", "-y", "@upstash/context7-mcp")
  Add-Mcp "fetch" @("uvx", "mcp-server-fetch")
  Add-Mcp "time" @("uvx", "mcp-server-time", "--local-timezone", $Timezone)
  Add-Mcp "playwright" @("npx", "-y", "@playwright/mcp", "--browser", "chrome", "--headless")
  Add-Mcp "chrome_devtools" @("npx", "-y", "chrome-devtools-mcp", "--headless", "--isolated", "--no-usage-statistics", "--no-performance-crux")
  Add-McpUrl "openaiDeveloperDocs" "https://developers.openai.com/mcp"
  Add-McpUrl "figma" "https://mcp.figma.com/mcp"

  if ($GitRepository) {
    Add-Mcp "git" @("uvx", "mcp-server-git", "--repository", $GitRepository)
  }

  if ($IncludeDocker) {
    Add-Mcp "docker" @("npx", "-y", "mcp-docker-server")
  }

  if ($IncludeDatabases) {
    $mysqlEnv = @{
      MYSQL_HOST = if ($env:MYSQL_HOST) { $env:MYSQL_HOST } else { "127.0.0.1" }
      MYSQL_PORT = if ($env:MYSQL_PORT) { $env:MYSQL_PORT } else { "3306" }
      MYSQL_USER = if ($env:MYSQL_USER) { $env:MYSQL_USER } else { "root" }
      MYSQL_PASS = if ($env:MYSQL_PASS) { $env:MYSQL_PASS } else { "" }
      MYSQL_DB   = if ($env:MYSQL_DB) { $env:MYSQL_DB } else { "mysql" }
    }
    Add-Mcp "mysql" @("npx", "-y", "@benborla29/mcp-server-mysql") $mysqlEnv

    if ($env:POSTGRES_URL) {
      Add-Mcp "postgres" @("npx", "-y", "@modelcontextprotocol/server-postgres", $env:POSTGRES_URL)
    } else {
      Write-Warning "Skipping postgres MCP because POSTGRES_URL is not set."
    }

    if ($env:REDIS_URL) {
      Add-Mcp "redis" @("npx", "-y", "@modelcontextprotocol/server-redis", $env:REDIS_URL)
    } else {
      Write-Warning "Skipping redis MCP because REDIS_URL is not set."
    }
  }

  if ($IncludeSsh) {
    $sshConfig = if ($env:SSH_CONFIG_PATH) { $env:SSH_CONFIG_PATH } else { Join-Path $CodexHome "ssh-config.toml" }
    Add-Mcp "ssh" @("npx", "-y", "mcp-ssh-manager") @{ SSH_CONFIG_PATH = $sshConfig }
  }

  if ($IncludeFeishu) {
    if (-not $env:FEISHU_APP_ID -or -not $env:FEISHU_APP_SECRET) {
      throw "Set FEISHU_APP_ID and FEISHU_APP_SECRET before using -IncludeFeishu."
    }
    Add-Mcp "feishu" @("npx", "-y", "@larksuiteoapi/lark-mcp", "mcp", "-a", $env:FEISHU_APP_ID, "-s", $env:FEISHU_APP_SECRET, "-l", "zh")
  }
}

Write-Host "Install complete. Start a new Codex task to load newly installed skills and MCP tools."
