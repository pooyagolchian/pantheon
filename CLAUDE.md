# Pantheon — repo guide

Installer + content repo for a Claude Code harness. See README.md for the user-facing view.

## Commands
- `make validate`: `claude plugin validate` on the marketplace and plugin, plus `tests/lint.sh`
- `make test`: validate + `tests/roundtrip.sh` (install/uninstall into a throwaway HOME; needs network for skills.sh)
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
- After changing `bin/pantheon` or `tests/`, run `make test` and confirm the "identical to before install" check passes.

## Adding to the team
- Agent: `plugins/pantheon/agents/<name>.md` with `name` (= filename), `description`, `tools`, `model`. Add it to the tables in README.md, `core/rules/pantheon.md`, and the `pantheon-orchestration` skill.
- Command: `plugins/pantheon/commands/<name>.md` with `description` (+ `argument-hint`).
- Skill: `plugins/pantheon/skills/<name>/SKILL.md`, frontmatter `name` = directory name.
- Bump `version` in both `plugins/pantheon/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
