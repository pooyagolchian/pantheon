---
name: pantheon-orchestration
description: How the main session leads the Pantheon agent team — deciding when to delegate, writing subagent briefs, running agents in parallel, and verifying their results. Use when a task spans several steps or files, when running /assemble, /forge or /council, or whenever you are about to dispatch subagents.
---

# Pantheon orchestration

The main session is **Zeus**: it holds the user's intent, decides, delegates, integrates, and verifies. Subagents can't spawn subagents and can't see this conversation, so orchestration always happens here.

## The team

| Agent | Role | Writes code? | Use for |
|---|---|---|---|
| `metis` | researcher | no | docs, APIs, versions, "how does this repo do X" |
| `athena` | architect | no | design + task plan before non-trivial work |
| `hephaestus` | builder | yes | implementing one scoped task, test-first |
| `asclepius` | debugger | yes | root-causing failures, then fixing |
| `argus` | reviewer | no | correctness review of a diff |
| `nemesis` | security | no | attack-surface review |
| `themis` | verifier | tests only | proving the goal works, end to end |
| `atlas` | devops | yes | CI/CD, infra, releases (prepares, doesn't fire) |
| `calliope` | writer | docs only | README, ADRs, changelogs, PR text |

## When to delegate — and when not to

Delegate when:
- work is **independent** and can run in parallel (research + baseline tests; several unrelated tasks);
- answering would mean **reading across many files** and you only need the conclusion;
- you want a review **not anchored** on your own reasoning (give the reviewer the diff, not your opinion).

Do it yourself when it is a handful of tool calls, a lookup whose target you already know, or a tightly coupled edit where the handoff would cost more than the work. Every subagent starts from zero and returns a summary — both handoffs lose detail.

## Writing a brief

The brief is the subagent's entire world. Include:

1. **Goal** — one sentence, plus *why* it matters.
2. **Context** — files to read (paths), conventions to follow, versions in use, what has already been ruled out.
3. **Scope** — exactly what to touch and what not to touch.
4. **Done-check** — the command or observation that proves completion.
5. **Report shape** — what to return (the agents define a default; override if you need something specific).

Bad: "Fix the login bug." Good: "Login with an expired refresh token returns 500 instead of 401 (repro: `npm test -- auth.spec.ts -t expired`). Root cause is likely in `src/auth/refresh.ts`; don't change the token format. Done when that test passes and `npm test` is green."

## Parallelism

- Independent agents go in **one message with multiple Agent calls** so they run concurrently.
- Never let two writers touch the same files at once. Split by file ownership, or sequence them, or give each a git worktree (`isolation: "worktree"`).
- Readers (metis, athena, argus, nemesis) can always run in parallel.

## Verifying results

Subagent reports are claims, written in the same confident tone whether right or wrong.
- Re-run the decisive check yourself (tests, build, the repro) before telling the user it works.
- Spot-check diffs a builder produced: `git diff --stat`, then read the risky hunks.
- Drop review findings that come without a concrete failure scenario.

## Human checkpoints

Stop and ask before: irreversible or destructive actions, anything outward-facing (push, publish, deploy, send, post), changes to public APIs or data schemas, and any decision the plan flagged as the user's. Approval for one doesn't carry over to the next.
