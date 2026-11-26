# Pantheon — repo guide

Installer + content repo for a Claude Code harness. See README.md for the user-facing view.

## Commands
- `make validate`: `claude plugin validate` on the marketplace and plugin, plus `tests/lint.sh`, `tests/guard.sh` (guard hook block/allow cases) and `tests/skills.sh`
- `make test`: validate + `tests/edges.sh` (offline install/uninstall edge cases) + `tests/roundtrip.sh` (install/uninstall into a throwaway HOME; needs network for skills.sh)
- `make eval` / `make eval-smoke`: `claude plugin eval` on `plugins/pantheon/evals/`. Real Claude sessions on your account: defaults are 1 run, $5 cap, report not published. Not run in CI.
- `make plan`: dry run of a full install against the real `~/.claude`
- `make capture`: regenerate `skills/manifest.tsv`, `skills/vendor/`, `plugins.tsv`, and `core/settings.json` skillOverrides from this machine

## Layout
- `bin/pantheon`: all install/uninstall logic. The Makefile only wraps it.
- `plugins/pantheon/`: the team (agents, commands, skills, hooks), also published as a plugin via `.claude-plugin/marketplace.json`.
- `core/`: rules, statusline, settings fragment.
- `skills/manifest.tsv`: `profile<TAB>source<TAB>skill`; source `vendor` means `skills/vendor/<skill>`.

## Rules for changing the installer
- Must run on macOS bash 3.2: no associative arrays, `mapfile`, `${var,,}`, or `readlink -f`.
- Every filesystem or settings change goes through `link` / `settings_write` / `runq` and is `record`ed, so uninstall can reverse it and `DRY_RUN=1` can preview it.
- Never overwrite existing user files without `FORCE=1` + backup. Never touch `~/.claude/skills/synced`.
- After changing `bin/pantheon` or `tests/`, run `make test` and confirm the "identical to before install" check passes. Run it with `/bin/bash` on macOS to exercise bash 3.2.
- Changing `plugins/pantheon/hooks/guard.sh`: add `expect` lines to `tests/guard.sh` for what the change blocks and what it must still allow. The guard is live in a session that installed it, so test strings go in that file, not on a command line.

## Adding to the team
- Agent: `plugins/pantheon/agents/<name>.md` with `name` (= filename), `description`, `tools`, `model`. Add it to the tables in README.md, `core/rules/pantheon.md`, `plugins/pantheon/ONBOARDING.md` (table and Team block), and the `pantheon-orchestration` skill. Give it a section and a portrait (`docs/assets/team/<name>.jpg`) in `docs/team.md` (style prompt under "Adding a portrait"). Include the `## Untrusted content` section. `tests/lint.sh` checks both.
- Decisions: record lasting ones as `docs/adr/NNNN-<slug>.md` and add them to `docs/adr/README.md`.
- Command: `plugins/pantheon/commands/<name>.md` with `description` (+ `argument-hint`). Add it to README.md and to "Commands to Know" in `plugins/pantheon/ONBOARDING.md`.
- Skill: `plugins/pantheon/skills/<name>/SKILL.md`, frontmatter `name` = directory name.
- Bump `version` in both `plugins/pantheon/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
