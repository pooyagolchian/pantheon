---
name: harness-engineering
description: How to configure the Claude Code harness itself — settings.json, permissions, hooks, subagents, slash commands, plugins, marketplaces and MCP servers — safely and reproducibly. Use when adding a hook, writing an agent or command, packaging a plugin, tuning permissions, or extending the Pantheon repo.
---

# Harness engineering

Always check current syntax before editing harness config — it changes between releases: `npx ctx7@latest docs` for Claude Code, or the `claude-code-guide` agent.

## Settings layers (later wins)

`~/.claude/settings.json` (user) → `.claude/settings.json` (project, committed) → `.claude/settings.local.json` (project, git-ignored) → managed/enterprise policy. Put team conventions in the project file and personal taste in the user file.

## Permissions

- Allow-list read-only and routine commands (`Bash(npm test *)`, `Bash(git status)`), not broad wildcards.
- Deny what must never run (`Bash(rm -rf *)`, `Read(./.env)`) with `permissions.deny`; denies beat allows and apply in every mode.
- Bash rules match the command *as written*: `Bash(rm *)` does not catch `/bin/rm` or `cd x && rm`. For anything that must hold, back the rule with a PreToolUse hook that parses the command.
- Prefer a narrow allow-list plus auto mode over bypassing permissions entirely.

## Hooks

Hooks are deterministic: they run every time, cost no context, and can block.
- `PreToolUse` — validate or block a tool call (exit code `2` blocks; stderr is shown to Claude).
- `PostToolUse` — format, lint, or log after edits.
- `UserPromptSubmit`, `SessionStart` — inject context; `Stop` — final checks.
- Keep hooks fast (< 1s), idempotent, and quiet on success. Read the JSON payload from stdin with `jq`. Never run untrusted content from the payload through a shell.
- Example: Pantheon's `plugins/pantheon/hooks/guard.sh` blocks catastrophic Bash commands.

## Subagents (`agents/*.md`)

Frontmatter: `name`, `description` (when to use it — this drives auto-delegation), `tools` (least privilege: reviewers get no Edit/Write) or `disallowedTools`, `model` (`opus` for judgment, `sonnet` for research/writing, `inherit` for builders). Also available: `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `isolation`, `effort`, `color`. The body is the system prompt: role, method, report format, and hard "never" rules.

## Slash commands (`commands/*.md`)

Commands are skills without `name`/`paths`: frontmatter `description`, optional `argument-hint`, `allowed-tools`, `model`, `effort`, `disable-model-invocation`. Use `$ARGUMENTS` in the body (plain substitution — no shell-style defaults). In a plugin they are namespaced `/plugin:command`.

## Plugins and marketplaces

A plugin directory holds `.claude-plugin/plugin.json` plus any of `agents/`, `commands/`, `skills/`, `hooks/hooks.json`, `.mcp.json`. Use `${CLAUDE_PLUGIN_ROOT}` for paths inside hooks. A marketplace is a repo with `.claude-plugin/marketplace.json` listing plugins. Validate with `claude plugin validate <path>` before publishing.

## Extending Pantheon

- New agent → `plugins/pantheon/agents/<name>.md`; new command → `plugins/pantheon/commands/`; new skill → `plugins/pantheon/skills/<name>/SKILL.md`.
- New third-party skill → `make skill-add SRC=owner/repo SKILL=name PROFILE=x`.
- Then `make validate test` and `make install-team` (links are symlinks, so edits to existing files are live immediately).
