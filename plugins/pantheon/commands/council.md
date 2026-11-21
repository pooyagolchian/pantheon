---
description: Convene the review council — argus (correctness), nemesis (security) and themis (verification) review in parallel
argument-hint: [diff target: branch, PR number, path — default: uncommitted changes]
---

Agent names below are bare; if Pantheon was installed as a plugin, use the namespaced form shown in your agents list (e.g. `pantheon:athena`).

Convene the Pantheon review council on: $ARGUMENTS

If no target is given above, review the current uncommitted changes (`git diff` + `git diff --staged`).

1. Work out the exact diff command for the target (for a PR number, `gh pr diff <n>`; for a branch, `git diff $(git merge-base HEAD main)...<branch>`). Note the changed files.
2. In **one message**, dispatch three subagents in parallel, each given the same diff command and file list, and *not* your own opinion of the change:
   - `argus` — correctness, regressions, silent failures, test adequacy
   - `nemesis` — security: attack surface and exploitable paths
   - `themis` — run the tests and checks; verify the change does what it claims
3. Merge the results: de-duplicate, drop anything a reviewer could not substantiate, rank by severity.
4. Present one table — severity · file:line · finding · fix — and a one-line verdict: `ship`, `ship after fixes`, or `rework`.

Do not apply fixes unless the user asks.
