# 0001. Every installer change is recorded and reversible

- Status: Accepted
- Date: 2026-11-21

## Context

`bin/pantheon` installs into a user's real `~/.claude`, which already holds their own settings, skills, rules and synced content. An installer that can't be cleanly undone turns "try Pantheon" into a risk, and one that overwrites files silently destroys user work.

## Decision

Every filesystem or settings change goes through `link`, `settings_write` or `runq` and is `record`ed. Uninstall replays the record in reverse, and `DRY_RUN=1` prints the same steps without running them. Existing user files are never overwritten without `FORCE=1`, and even then they are backed up first. `~/.claude/skills/synced` is never touched. The installer runs on macOS bash 3.2.

## Consequences

- `make plan` shows exactly what an install will do, and `make uninstall` restores the previous state.
- `tests/roundtrip.sh` can assert that install followed by uninstall leaves `~/.claude` byte-identical. `make test` enforces it.
- Every new installer feature costs more to write: it has to go through the helpers, not raw `ln` or `jq`.

## Alternatives considered

- **Plugin-only distribution.** It reverses cleanly, but a plugin can't install global rules (see the README), so the main session wouldn't be told to delegate to the team. The curated skills collection doesn't fit in a single plugin either.
- **Snapshot and restore all of `~/.claude`.** Simpler to write, but restoring would also undo any change the user made after installing.
