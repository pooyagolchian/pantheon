# 0003. Defer inner-loop techniques to existing plugins

- Status: Accepted
- Date: 2026-11-22

## Context

Popular plugins such as `superpowers` already ship well-tested skills for test-driven development, writing and executing plans, systematic debugging and git worktrees. Re-implementing them in Pantheon would duplicate work and leave two competing sets of instructions loaded at once.

## Decision

Pantheon supplies the team and the pipeline. When an inner-loop skill is installed, the agents use it (passed by name in the brief); the mapping lives in `pantheon-orchestration`. Each agent's own instructions are written to be enough on their own when no such plugin is present.

## Consequences

- Pantheon stays small, with less always-loaded context and fewer conflicting instructions.
- Behaviour varies slightly depending on whether `superpowers` is installed.
- The mapping table has to be kept up to date when those plugins rename their skills.

## Alternatives considered

- **Vendor the techniques into Pantheon skills.** Behaviour would be consistent everywhere, but the skills would drift from upstream and duplicate them whenever both are installed.
