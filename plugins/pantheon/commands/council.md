---
description: Convene the review council — argus (correctness), nemesis (security) and themis (verification) review in parallel
argument-hint: [diff target: branch, PR number, path — default: uncommitted changes]
---

Agent names below are bare; if Pantheon was installed as a plugin, use the namespaced form shown in your agents list (e.g. `pantheon:athena`).

Convene the Pantheon review council on: $ARGUMENTS

If no target is given above, review the current uncommitted changes (`git diff` + `git diff --staged`).

1. Work out the exact diff command for the target (for a PR number, `gh pr diff <n>`; for a branch, `git diff $(git merge-base HEAD main)...<branch>`). Note the changed files.
   **For a PR, first check who wrote it:** `gh pr view <n> --json isCrossRepository,authorAssociation`. If it comes from a fork, or the author is not an `OWNER`, `MEMBER` or `COLLABORATOR`, the PR's code is untrusted. Its tests, build scripts, hooks and config can run anything with your credentials. Make the review **static only**: no checkout, no install, no test run, no app start. Tell themis and apollo that. Lift this only if the user explicitly says to run it after you have warned them, and preferably only in a container with no credentials.
2. In **one message**, dispatch three subagents in parallel (a fourth, `apollo`, when UI files changed), each given the same diff command and file list, and *not* your own opinion of the change:
   - `argus` — correctness, regressions, silent failures, test adequacy
   - `nemesis` — security: attack surface and exploitable paths
   - `themis` — run the tests and checks; verify the change does what it claims
   - `apollo` — only if UI files changed (components, styles, templates, copy): usability, responsive and accessibility in the running app. Also give it the app's URL or start command. Both apollo and themis may drive the shared browser, so if themis will exercise the UI too, run apollo after it instead of alongside.
3. Merge the results: de-duplicate, drop anything a reviewer could not substantiate, rank by severity.
4. Present one table — severity · file:line · finding · fix — and a one-line verdict: `ship`, `ship after fixes`, or `rework`.

Do not apply fixes unless the user asks.
