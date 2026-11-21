---
name: context-engineering
description: Best practices for what goes into Claude's context — CLAUDE.md files, rules, skills, memory, and subagents — so sessions stay sharp and cheap. Use when writing or auditing a CLAUDE.md, deciding whether something should be a rule, skill, hook or memory, trimming a bloated setup, or when sessions feel slow or unfocused.
---

# Context engineering

Every token loaded at session start is paid for on every turn and competes for attention. Load little by default; let the rest arrive on demand.

## Where each kind of knowledge belongs

| Put it in… | When it is… | Loaded |
|---|---|---|
| `CLAUDE.md` (project) | true for all work in this repo: build/test commands, layout, conventions, gotchas | every session in the repo |
| `~/.claude/CLAUDE.md` / `~/.claude/rules/*.md` | your personal defaults across all projects | every session |
| a **skill** (`SKILL.md`) | a procedure or domain playbook needed sometimes | name + description always; body only when triggered |
| a **subagent** | a role that needs its own context window and tool limits | only when dispatched |
| a **hook** | a rule that must *always* happen (format, block, log) — not a suggestion | runs in the harness, costs no context |
| **memory** | facts learned about the user/project that aren't in the repo | index each session; files on demand |
| a **slash command** | a prompt you type repeatedly | only when invoked |

Rule of thumb: if the model *may* forget and that's fine → instructions. If it *must never* happen → hook or permission.

## Writing a good CLAUDE.md

- Under ~150 lines. Commands first (`build`, `test`, `lint`, run one test), then architecture in a few bullets, then conventions and gotchas.
- Specific and checkable: "Run `pnpm test:unit path` for a single file", not "write good tests".
- Don't repeat what the code or README already makes obvious; don't paste style guides a linter enforces.
- Use `@path/to/file.md` imports for detail that only some tasks need.
- Review it when the model repeatedly gets something wrong — that's a missing line, or a misleading one.

## Writing a skill that triggers

- The `description` is what the model sees to decide relevance: say **what it does and when to use it**, with the trigger phrases users actually type.
- Keep `SKILL.md` lean; move reference material to sibling files and link them (progressive disclosure).
- Bundle scripts for deterministic steps instead of describing them in prose.
- Too many overlapping skills dilute triggering: set rarely-needed ones to `name-only` or `off` via `skillOverrides` in `settings.json`.

## Keeping sessions lean

- Fan out wide searches to subagents and keep conclusions only.
- Start a new session per unrelated task; use `/handoff` to carry state across.
- Audit plugins and MCP servers: each adds tool definitions to every turn. `claude plugin details <name>` shows a plugin's token cost.
