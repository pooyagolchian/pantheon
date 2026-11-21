---
name: agentic-workflow
description: The core loop for agentic programming in Claude Code — explore, plan, implement, verify, commit — with the habits that keep long autonomous runs correct. Use when starting any coding task larger than a one-line fix, when a task feels like it is drifting, or when deciding how much to plan before coding.
---

# Agentic workflow

## The loop

1. **Explore** — read the relevant code, docs and git history *before* deciding anything. Find the closest existing example of what you're about to build and copy its patterns.
2. **Plan** — size the work:
   - one-liner / obvious fix → just do it;
   - a few files, clear outcome → a short plan in your head or a todo list;
   - multi-step or unclear → a written plan (`athena`, or the superpowers `writing-plans` skill) the user can approve.
3. **Implement** — smallest change that works, matching the surrounding code. Test first when a suite exists.
4. **Verify** — run the tests, type checker, linter, and the actual program. Read the output. Exercise the real behaviour, not just unit tests.
5. **Commit** — only when asked, in small logical commits with messages that say *why*.

## Habits that keep runs correct

- **Give yourself a target you can check.** A failing test, a reproduction command, an expected output. Without one, you're guessing when to stop.
- **Track multi-step work in a todo list** and keep exactly one item in progress.
- **Two strikes rule.** If the same fix fails twice, stop patching; re-read the error and re-examine the assumption.
- **Don't widen scope silently.** Unrelated problems get reported, not fixed.
- **Fresh docs over memory.** For any library, CLI or API: `npx ctx7@latest docs …` before writing code against it.
- **Never fake green.** No skipped tests, weakened assertions, `@ts-ignore`, or swallowed errors to make checks pass.
- **Say what you didn't do.** A final report lists what was verified, how, and what was skipped.

## Context hygiene on long tasks

- Delegate wide searches to a subagent (`Explore`, `metis`) and keep only the conclusion.
- Write durable state to files (plan, `HANDOFF.md`) so a compaction or a new session can resume — see `/handoff`.
- Prefer targeted reads (`offset`/`limit`, grep) over dumping whole large files.

## Done means

The goal is met, the checks you ran prove it, and the user knows exactly what changed and what wasn't verified.
