# Skill MCP Private Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a private GitHub repository that stores personal Codex skills and portable MCP installation defaults.

**Architecture:** Use a repo-local Codex plugin for skills and plugin-level MCP defaults. Use PowerShell scripts for machine-specific MCP installation because filesystem roots, database credentials, SSH config, and Feishu credentials vary per computer.

**Tech Stack:** Codex plugin manifest, Codex MCP CLI, PowerShell, Git, `npx`, `uvx`.

## Global Constraints

- Do not commit `auth.json`, OAuth tokens, model provider secrets, Feishu secrets, database passwords, logs, sessions, sqlite state, or machine-specific Codex runtime paths.
- Store non-system skills only; `.system` skills are excluded because they are managed by Codex.
- MCP definitions must use portable commands (`npx`, `uvx`) or environment variables, not absolute local paths.

---

### Task 1: Repository Scaffold

**Files:**
- Create: `.agents/plugins/marketplace.json`
- Create: `plugins/personal-skill-mcp/.codex-plugin/plugin.json`
- Create: `plugins/personal-skill-mcp/.mcp.json`

**Interfaces:**
- Produces: a repo-local plugin named `personal-skill-mcp`

- [x] Scaffold plugin with skills, MCP, scripts, and marketplace support.
- [x] Replace scaffold metadata with private repo metadata.
- [x] Keep marketplace source path as `./plugins/personal-skill-mcp`.

### Task 2: Skill Snapshot

**Files:**
- Create/modify: `plugins/personal-skill-mcp/skills/*`

**Interfaces:**
- Consumes: local `C:\Users\a2833\.codex\skills`
- Produces: a portable copy of non-system skills

- [x] Copy every local skill directory except `.system`.
- [x] Preserve each skill's `SKILL.md`, `references/`, `assets/`, and `scripts/`.
- [x] Avoid copying Codex plugin caches or runtime state.

### Task 3: MCP Portability

**Files:**
- Create: `mcp/servers.portable.json`
- Create: `scripts/install.ps1`

**Interfaces:**
- Produces: one install command for common MCP servers and opt-in flags for Docker, databases, SSH, and Feishu

- [x] Define common MCP servers with `npx` and `uvx`.
- [x] Represent Feishu and database credentials as environment variables.
- [x] Avoid committing literal secrets from local `config.toml`.

### Task 4: Documentation And Verification

**Files:**
- Create: `README.md`
- Create: `.gitignore`

**Interfaces:**
- Produces: clone/install/update instructions for other computers

- [x] Document prerequisites and install commands.
- [x] Document excluded secrets and local state.
- [x] Validate plugin manifest and JSON files before commit.
