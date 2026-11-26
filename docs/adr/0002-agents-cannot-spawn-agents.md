# 0002. Agents cannot spawn agents; the main session orchestrates

- Status: Accepted
- Date: 2026-11-21 (no agent had `Agent` in its tools from the first commit; the rule was written into `pantheon-orchestration` on 2026-11-22)

## Context

Subagents start from zero context and report back a summary. If specialists could dispatch other specialists, briefs would degrade with every hop, costs would fan out with no single place to cap them, and no one would hold the user's intent end to end.

## Decision

No Pantheon agent has the `Agent` tool in its `tools` list. The main session (Zeus) does all delegation, following the `pantheon-orchestration` skill: it writes the briefs, runs agents in parallel, merges their results, and re-runs the decisive checks itself.

## Consequences

- One place decides parallelism, model choice per brief, fix-loop limits (5 rounds) and human checkpoints.
- Every handoff is one hop deep, so a brief is never a summary of a summary.
- Pipelines that need several agents must be written as commands (`/assemble`, `/council`, `/forge`, `/ship`). An agent can't improvise a sub-team.

## Alternatives considered

- **Let the architect dispatch builders.** This would save main-session context, but plans and their execution would no longer be visible in one place, and costs could fan out unchecked.
