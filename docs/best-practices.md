# Claude Code best practices encoded in Pantheon

These are the working practices behind this harness, and where each one lives. Re-check details against current docs before changing harness config (`npx ctx7@latest docs` for Claude Code, or ask the `claude-code-guide` agent). Syntax moves between releases.

## 1. Explore → plan → implement → verify → commit
Read before writing, plan anything non-trivial, keep diffs small, verify with real commands, and commit only when asked.
→ `agentic-workflow` skill · `athena` · `/assemble` · `core/rules/pantheon.md`

## 2. Give Claude a target it can check
Tests, a reproduction command or an expected output turn "looks done" into "is done". Builders write the failing test first. Verifiers run the real program.
→ `hephaestus`, `themis`, `asclepius`

## 3. Keep context lean
CLAUDE.md is short and specific. Procedures live in skills (descriptions always loaded, bodies on demand). Roles live in subagents (separate context windows). Must-happen rules are hooks, not prose. Rarely used skills are `name-only` or `off`.
→ `context-engineering` skill · `skillOverrides` in `core/settings.json` · skill profiles

## 4. Delegate deliberately
Use subagents for independent work run in parallel, for wide searches where only the conclusion matters, and for unanchored reviews. Write self-contained briefs: goal, context, scope, done-check and report shape. Verify what they return.
→ `pantheon-orchestration` skill · `/council` · `/forge`

## 5. Least privilege
Reviewers and planners have no Edit/Write. Builders don't commit, push or deploy unless told. Permissions use narrow allow-lists. A guard hook blocks catastrophic commands deterministically.
→ agent `tools:` frontmatter · `plugins/pantheon/hooks/guard.sh` · `harness-engineering` skill

## 6. Humans decide the irreversible
Ask before anything outward-facing or hard to reverse: push, publish, deploy, send, delete, or change shared infrastructure. One approval doesn't carry over to the next action.
→ `core/rules/pantheon.md` · `atlas` ("prepares, never fires")

## 7. Fresh docs over memory
For any library, framework, CLI or cloud API, fetch current documentation (ctx7) before writing code against it.
→ `core/rules/context7.md` · `metis`

## 8. Durable state for long work
Plans, todo lists and handoff notes live in files, so compaction or a fresh session can resume without loss. Start a new session for each unrelated task.
→ `/handoff`

## 9. Parallel sessions without collisions
Run independent work in separate git worktrees (`isolation: "worktree"` for subagents, or `claude --worktree`) so writers never share files.
→ `pantheon-orchestration` skill

## 10. Reproducible harness
Your whole setup (rules, agents, commands, skills, plugins, settings fragments) is in version control and installable with one command. It is captured back from a working machine with `make capture` and tested with `make test`.
→ this repository
