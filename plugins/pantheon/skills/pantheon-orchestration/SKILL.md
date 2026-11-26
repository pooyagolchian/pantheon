---
name: pantheon-orchestration
description: How the main session leads the Pantheon agent team — deciding when to delegate, writing subagent briefs, running agents in parallel, and verifying their results. Use when a task spans several steps or files, when running /assemble, /forge or /council, or whenever you are about to dispatch subagents.
---

# Pantheon orchestration

The main session is **Zeus**: it holds the user's intent, decides, delegates, integrates, and verifies. Subagents can't see this conversation, and Pantheon agents deliberately leave `Agent` out of their tool lists so they can't spawn subagents of their own. Orchestration always happens here.

## The team

| Agent | Role | Writes code? | Use for |
|---|---|---|---|
| `metis` | researcher | no | docs, APIs, versions, "how does this repo do X" |
| `athena` | architect | no | design + task plan before non-trivial work |
| `hephaestus` | builder | yes | implementing one scoped task, test-first |
| `proteus` | refactorer | yes | restructuring with no behaviour change: extract, rename, dedupe, strangle legacy |
| `asclepius` | debugger | yes | root-causing failures, then fixing |
| `argus` | reviewer | no | correctness review of a diff |
| `nemesis` | security | no | attack-surface review |
| `apollo` | UI critic | no | usability, responsive and WCAG 2.2 AA checks in the running app, when UI changes |
| `themis` | verifier | tests only | proving the goal works, end to end |
| `atlas` | devops | yes | CI/CD, infra, releases (prepares, doesn't fire) |
| `calliope` | writer | docs only | README, ADRs, changelogs, PR text |

**Names depend on how Pantheon was installed.** Via `make install-team` the names are bare (`athena`, `pantheon-orchestration`). Via `/plugin install pantheon@pantheon` they are namespaced: agents are `pantheon:athena`, skills `pantheon:pantheon-orchestration`, commands `/pantheon:assemble`. Use whichever form appears in your available agents list.

## Working alongside other plugins

Pantheon supplies the **team and the pipeline**. It deliberately doesn't re-implement inner-loop techniques that popular plugins already do well. When one of these is installed, the agents use it rather than improvising:

| Need | Use if installed |
|---|---|
| Test-first implementation (hephaestus) | `superpowers:test-driven-development` |
| Written plans (athena) and executing them (/forge) | `superpowers:writing-plans`, `superpowers:executing-plans` |
| Root-causing failures (asclepius) | `superpowers:systematic-debugging` |
| Isolated parallel work | `superpowers:using-git-worktrees`, or the Agent tool's `isolation: "worktree"` |
| Writing or evaluating skills | `skill-creator`, `claude plugin eval` |

If none of these is installed, the agents' own instructions are enough. Pass the relevant skill name in the brief so the subagent loads it.

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

**Choose the model per brief.** An agent with `model: inherit` (or no model) runs on the session's model, often the most expensive one. Mechanical 1–2 file tasks can take a cheaper model through the Agent call's `model` parameter; design and subtle review get the most capable one. The parameter takes an alias (`haiku`, `sonnet`, `opus`, `fable`), not a full model ID or `inherit`, and overrides the agent's frontmatter `model`.

**Effort is set per agent on purpose.** Readers and reviewers pin it (`argus` and `athena` high, `nemesis` xhigh, `metis` and `apollo` medium, `calliope` low), as do `proteus` and `asclepius` (high) and `themis` (medium). `hephaestus` and `atlas` deliberately inherit the session's effort: their tasks range from a one-line config change to a multi-file feature, so the session's setting is the better guide.

Bad: "Fix the login bug." Good: "Login with an expired refresh token returns 500 instead of 401 (repro: `npm test -- auth.spec.ts -t expired`). Root cause is likely in `src/auth/refresh.ts`; don't change the token format. Done when that test passes and `npm test` is green."

## Parallelism

- Independent agents go in **one message with multiple Agent calls** so they run concurrently.
- Never let two writers touch the same files at once. Split by file ownership, or sequence them, or give each a git worktree (`isolation: "worktree"`).
- Readers (metis, athena, argus, nemesis, apollo) can always run in parallel. One exception: the browser is shared, so don't run two browser-driving agents (apollo, or themis exercising a UI) at the same time.

## Acting on a report's status

Builders (hephaestus, proteus, asclepius, themis, atlas) end their report with a status:

- `DONE` — re-run the decisive check yourself, then move on.
- `DONE_WITH_CONCERNS` — read the concerns before moving on. Fix the ones that affect correctness or scope; surface the rest to the user in the final report.
- `BLOCKED` — don't re-dispatch the same brief. Remove the blocker (a decision, access, a failing dependency), or take it to the user if the decision is theirs.
- `NEEDS_CONTEXT` — answer the questions and resume the same agent (`SendMessage`) rather than starting a fresh one; if it can't be resumed, dispatch a fresh one with its previous report and your answers in the brief.

Fix loops are capped at 5 rounds: rounds 1–3 resume the same builder (`SendMessage`), rounds 4–5 go to a fresh builder (optionally a stronger model). After round 5, stop and report to the user. If `SendMessage` can't resume the agent, dispatch a fresh builder with its previous report and the findings in the brief.

## Verifying results

Subagent reports are claims, written in the same confident tone whether right or wrong.
- Re-run the decisive check yourself (tests, build, the repro) before telling the user it works.
- Spot-check diffs a builder produced: `git diff --stat`, then read the risky hunks.
- Drop review findings that come without a concrete failure scenario.

## Human checkpoints

Stop and ask before: irreversible or destructive actions, anything outward-facing (push, publish, deploy, send, post), changes to public APIs or data schemas, and any decision the plan flagged as the user's. Approval for one doesn't carry over to the next.
