# 0006. Effort is pinned per agent; builders of variable scope inherit

- Status: Accepted
- Date: 2026-11-22

## Context

Seven agents set `effort:` in their frontmatter and four didn't: hephaestus, asclepius, themis and atlas. Nothing recorded whether those four were left unset on purpose.

## Decision

- Pin effort where the work has a consistent depth: asclepius `high` (root-causing rewards depth), themis `medium` (designing cases and running suites), alongside the existing settings (argus and athena high, nemesis xhigh, proteus high, metis and apollo medium, calliope low).
- Leave hephaestus and atlas unset on purpose. Their tasks range from a one-line config change to a multi-file feature, so the session's setting is the better guide. This is documented in `pantheon-orchestration`.

## Consequences

- Debugging and verification no longer vary with whatever effort the session runs at.
- Builder cost still follows the session's effort. The main session can choose a cheaper model per brief through the Agent call's `model` parameter.

## Alternatives considered

- **Pin every agent.** Simple and predictable, but it over- or under-spends on builder tasks whose size varies widely.
