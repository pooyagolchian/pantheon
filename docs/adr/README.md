# Architecture decision records

Each record captures one decision: the context that forced it, what was decided, what follows from it, and the alternatives that were turned down. Records are immutable once accepted. To change a decision, add a new record that supersedes the old one and set the old one's status to `Superseded by NNNN`.

| # | Decision | Status |
|---|---|---|
| [0001](0001-installer-changes-are-recorded-and-reversible.md) | Every installer change is recorded and reversible | Accepted |
| [0002](0002-agents-cannot-spawn-agents.md) | Agents cannot spawn agents; the main session orchestrates | Accepted |
| [0003](0003-defer-inner-loop-techniques-to-existing-plugins.md) | Defer inner-loop techniques to existing plugins | Accepted |
| [0004](0004-every-agent-treats-untrusted-content-as-data.md) | Every agent treats untrusted content as data, enforced by lint | Accepted |
| [0005](0005-docs-and-release-join-the-pipeline.md) | Docs and release join the pipeline (`/assemble` step 7, `/ship`) | Accepted |
| [0006](0006-effort-is-pinned-per-agent.md) | Effort is pinned per agent; builders of variable scope inherit | Accepted |

New record: copy the shape of any record below, take the next number, and add it to this table. `calliope` writes them in this format.
