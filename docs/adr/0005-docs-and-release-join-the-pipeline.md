# 0005. Docs and release join the pipeline

- Status: Accepted
- Date: 2026-11-22

## Context

No command dispatched `calliope` or `atlas`. `/assemble` ended at "Report", so documentation and release preparation happened only if the main session remembered to do them, and user-facing changes could ship with stale docs.

## Decision

- `/assemble` gains step 7, **Document**: when user-facing behaviour, configuration, commands or a public API changed, `calliope` updates the README, docs, CHANGELOG and, where a real design choice was made, an ADR. Internal-only changes skip the step, and the report says so.
- A new `/ship` command gates on the full test, lint and typecheck suite, then runs `atlas` (version bump, local validation, exact release commands, rollback) and `calliope` (changelog, PR or release text) in parallel. It stops for the user to approve the specific outward-facing commands.

## Consequences

- Every agent now has at least one command that calls it.
- `/assemble` takes a little longer when docs are affected.
- Releases always present exact commands and a rollback before anything is tagged or published, which makes "prepare, don't fire" structural rather than advisory.

## Alternatives considered

- **Make docs a permanent step.** This would waste an agent run on internal refactors.
- **Let `/ship` run the release after one approval.** That conflicts with the rule that one approval never covers the next outward-facing action.
