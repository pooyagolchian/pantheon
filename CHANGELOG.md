# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.5.0] - 2026-11-26

### Added
- Plugin installs now get a `SessionStart` hook (`plugins/pantheon/hooks/session-start.sh`). It adds a short block to the start of every session that lists the team and when to delegate to each agent (review to `argus`, plus `nemesis` for security-sensitive changes; planning to `athena`; building to `hephaestus`; root cause to `asclepius`; verification to `themis`; research to `metis`). It costs about 150 tokens per session, on top of the roughly 1.2k the team already uses. Makefile installs are unchanged: they get the same guidance from `core/rules/pantheon.md`.
- README section "The full lifecycle", mapping each stage (research, plan, verify, code, test, debug, fix, review, document, deploy) to its agent, command and gate.
- Two eval cases, both seeded with a sample codebase by their `setup.sh`: `review-cross-file` (a change that breaks callers in two other files) and `security-endpoint` (a download route with path traversal and no auth).
- Plugin icon (`plugins/pantheon/.claude-plugin/icon.png`, 512x512).

### Changed
- `make eval` passes `--scaffold` so the seeded eval cases can run.
- `tests/lint.sh` also syntax-checks the eval `setup.sh` scripts.
- README reports current eval results: all cases pass with and without the plugin, and the lead did not dispatch an agent in the seeded cases. Treat the suite as a regression check, not proof that the team helps.
- The `design-principles` skill now points to `nextjs-app-router-patterns` instead of `next-best-practices`.

### Removed
- Vendored skills `next-best-practices` and `product-hunt-launch`, which had no upstream license text or copyright holder. Both are gone from `skills/manifest.tsv`. If you use them, install them from their own source.

## [0.4.0]

Summarised from the release commit ([`6609bc0`](https://github.com/pooyagolchian/pantheon/commit/6609bc0)).

### Added
- `/ship` and `/onboard` commands, `ONBOARDING.md`, a team page with portraits (`docs/team.md`) and ADRs.
- `SECURITY.md`, `THIRD_PARTY_NOTICES.md` (attribution for the 17 MIT-licensed vendored skills), and CI running the offline tests on Ubuntu and macOS.
- Four eval cases and `make eval` / `make eval-smoke` with cheap, private defaults (1 run, $5 cap, report not published).
- `tests/edges.sh` installer tests and `tests/guard.sh` (60 block/allow cases).

### Changed
- Guard hook checks each command segment separately and catches more destructive forms; it no longer blocks a feature-branch force-push followed by another command.
- `/council` and `themis` do not check out or run code from fork or non-member PRs without explicit approval.

### Fixed
- Installer: uninstall handles paths with spaces, a symlinked or missing `settings.json`, and a moved or re-cloned repo; `skill-remove` refuses `synced` and skills Pantheon did not install; `capture.sh` no longer exits silently without plugins.

[0.5.0]: https://github.com/pooyagolchian/pantheon/compare/6609bc0...v0.5.0
[0.4.0]: https://github.com/pooyagolchian/pantheon/commit/6609bc0
