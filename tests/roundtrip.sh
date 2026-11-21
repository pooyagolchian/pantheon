#!/usr/bin/env bash
# roundtrip.sh — install into a throwaway HOME pre-seeded with "existing" user config,
# check the result, uninstall, and require ~/.claude to be byte-identical to before.
# Uses the network (skills.sh) for the small PROFILES set below.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES="${TEST_PROFILES:-career docs}"

FAKE="$(mktemp -d)"; trap 'rm -rf "$FAKE"' EXIT
export npm_config_cache="${npm_config_cache:-$HOME/.npm}"   # reuse the real npx cache
export HOME="$FAKE" CLAUDE_DIR="$FAKE/.claude" PROFILES
unset DRY_RUN FORCE

# Pre-existing user config that must survive untouched.
mkdir -p "$CLAUDE_DIR/skills/docx" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/agents"
printf -- '---\nname: docx\ndescription: my own docx skill\n---\nmine\n' > "$CLAUDE_DIR/skills/docx/SKILL.md"
echo "my rule" > "$CLAUDE_DIR/rules/mine.md"
echo "my agent" > "$CLAUDE_DIR/agents/argus.md"            # name clash with a Pantheon agent
echo '{"model":"opus","permissions":{"allow":["Bash(ls)"]},"skillOverrides":{"gpt-taste":"off"},"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo hi"}]}]}}' | jq . > "$CLAUDE_DIR/settings.json"

snapshot() { (cd "$CLAUDE_DIR" && find . \( -type f -o -type l \) ! -path './backups/*' -print0 | sort -z | xargs -0 shasum 2>/dev/null; find . -type l ! -path './backups/*' -exec sh -c 'printf "%s -> %s\n" "$1" "$(readlink "$1")"' _ {} \; | sort); }
before="$(snapshot)"

fail=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=1; fi; }

echo "--- install (PROFILES=$PROFILES)"
"$ROOT/bin/pantheon" install core team skills

echo "--- checks"
check "agents linked"                 '[ -L "$CLAUDE_DIR/agents/athena.md" ]'
check "existing argus.md kept"        '[ ! -L "$CLAUDE_DIR/agents/argus.md" ] && grep -q "my agent" "$CLAUDE_DIR/agents/argus.md"'
check "commands linked"               '[ -L "$CLAUDE_DIR/commands/assemble.md" ]'
check "pantheon skills linked"        '[ -L "$CLAUDE_DIR/skills/pantheon-orchestration" ]'
check "rules linked, mine kept"       '[ -L "$CLAUDE_DIR/rules/pantheon.md" ] && [ -f "$CLAUDE_DIR/rules/mine.md" ]'
check "existing docx skill kept"      'grep -q "^mine$" "$CLAUDE_DIR/skills/docx/SKILL.md"'
check "vendored skill linked"         '[ -L "$CLAUDE_DIR/skills/resume-bullet-writer" ]'
check "skills.sh skill installed"     '[ -f "$CLAUDE_DIR/skills/pdf/SKILL.md" ]'
check "settings: user keys kept"      'jq -e ".model==\"opus\" and .permissions.allow==[\"Bash(ls)\"] and .skillOverrides[\"gpt-taste\"]==\"off\" and (.hooks.Stop|length)==1" "$CLAUDE_DIR/settings.json" >/dev/null'
check "settings: statusLine added"    'jq -e ".statusLine.command" "$CLAUDE_DIR/settings.json" >/dev/null'
check "settings: overrides merged"    'jq -e ".skillOverrides[\"minimalist-ui\"]==\"name-only\"" "$CLAUDE_DIR/settings.json" >/dev/null'
check "settings: guard hook added"    'jq -e "[.hooks.PreToolUse[].hooks[].command] | any(test(\"guard.sh\"))" "$CLAUDE_DIR/settings.json" >/dev/null'
check "re-install is a no-op"         '"$ROOT/bin/pantheon" install core team skills >/dev/null && [ "$(jq "[.hooks.PreToolUse[]]|length" "$CLAUDE_DIR/settings.json")" = 1 ]'
check "doctor passes"                 '"$ROOT/bin/pantheon" doctor >/dev/null 2>&1'

echo "--- uninstall"
"$ROOT/bin/pantheon" uninstall

after="$(snapshot)"
if [ "$before" = "$after" ]; then echo "  ✓ ~/.claude identical to before install"
else echo "  ✗ ~/.claude differs after uninstall:"; diff <(echo "$before") <(echo "$after") | head -30; fail=1; fi
[ ! -d "$CLAUDE_DIR/.pantheon" ] && echo "  ✓ no state left behind" || { echo "  ✗ state dir left behind"; fail=1; }

echo "--- dry run changes nothing"
DRY_RUN=1 "$ROOT/bin/pantheon" install all >/dev/null
check "tree unchanged after DRY_RUN=1" '[ "$before" = "$(snapshot)" ] && [ ! -d "$CLAUDE_DIR/.pantheon" ]'

echo "--- FORCE=1 backs up and restores"
FORCE=1 "$ROOT/bin/pantheon" install team >/dev/null
check "clashing argus.md replaced by link" '[ -L "$CLAUDE_DIR/agents/argus.md" ]'
"$ROOT/bin/pantheon" uninstall team >/dev/null
check "original argus.md restored"         '[ ! -L "$CLAUDE_DIR/agents/argus.md" ] && grep -q "my agent" "$CLAUDE_DIR/agents/argus.md"'
check "tree identical again"               '[ "$before" = "$(snapshot)" ]'
left="$( { find "$HOME/.agents/skills" -mindepth 1 -maxdepth 1 2>/dev/null || true; } | wc -l | tr -d " ")"
echo "  · ~/.agents/skills entries left by skills.sh: $left"

exit "$fail"
