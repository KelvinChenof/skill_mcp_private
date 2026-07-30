# Personal Codex Skills and MCP

Private repository for keeping the same Codex skills and MCP defaults available across machines.

## What Is Stored

- `plugins/personal-skill-mcp/skills/`: non-system skills copied from `D:\.codex\skills`
- `plugins/personal-skill-mcp/.mcp.json`: portable plugin-level MCP defaults
- `mcp/servers.portable.json`: full MCP reference manifest with common and optional servers
- `scripts/install.ps1`: install skills and MCP servers on another Windows machine
- `scripts/sync-skills-from-local.ps1`: refresh this repo from the current machine's local skills
- `scripts/sync-and-push.ps1`: refresh skills, commit changed managed files, and push

## What Is Not Stored

The repo intentionally excludes secrets and local runtime state:

- `auth.json`
- OAuth tokens
- model provider credentials
- literal Feishu app secrets
- database passwords
- logs, sessions, sqlite state, cache directories
- machine-specific Codex runtime paths

## Install On Another Windows Machine

Prerequisites:

- Codex CLI available as `codex`
- Node.js with `npx`
- Python `uv` with `uvx`
- Git

Clone the repo:

```powershell
git clone https://github.com/Kelvin2334/skill_mcp_private.git
cd skill_mcp_private
```

Install common skills and MCP servers:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

Install with optional tools:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 `
  -GitRepository "D:\path_for" `
  -IncludeDocker `
  -IncludeDatabases `
  -IncludeSsh
```

Install Feishu MCP only after setting credentials in the shell:

```powershell
$env:FEISHU_APP_ID = "your_app_id"
$env:FEISHU_APP_SECRET = "your_app_secret"
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -IncludeFeishu
```

Start a new Codex task after installation so skills and MCP tools are reloaded.

## Use As A Codex Plugin Marketplace

This repo also contains a repo-local marketplace:

```text
.agents/plugins/marketplace.json
plugins/personal-skill-mcp/
```

If Codex on another machine supports local marketplaces, add the repo marketplace root and install `personal-skill-mcp` from it. The script-based install remains the most explicit path because it also configures machine-specific MCP roots.

## Update From This Machine

After adding or editing local skills:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-skills-from-local.ps1
git status
git add .
git commit -m "chore: sync personal Codex skills"
git push
```

For the scheduled sync job, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-and-push.ps1 -CodexHome "D:\.codex"
```

MCP entries are kept as portable manifests. Do not copy `D:\.codex\config.toml` into this repo; update `mcp/servers.portable.json`, `plugins/personal-skill-mcp/.mcp.json`, and `scripts/install.ps1` only after removing secrets and machine-specific paths.
