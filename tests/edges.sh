#!/usr/bin/env bash
# edges.sh — offline install/uninstall edge cases for core + team (no network).
# Each scenario gets a fresh throwaway HOME. Covers: spaces in paths, a symlinked
# settings.json, settings edited between install and uninstall, a repo that changed or
# moved between install and uninstall, and FORCE backups vs. files the user made later.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
unset DRY_RUN FORCE PROFILES
fail=0
check() { if eval "$2"; then echo "  ✓ $1"; else echo "  ✗ $1"; fail=1; fi; }

# fresh <name>: new HOME (with a space in it) and CLAUDE_DIR, exported.
fresh() {
  export HOME="$TMP/$1/John Smith" CLAUDE_DIR="$TMP/$1/John Smith/.claude"
  mkdir -p "$CLAUDE_DIR"
}
P() { "${PANTHEON:-$ROOT/bin/pantheon}" "$@" >/dev/null 2>&1; }

echo "--- spaces in HOME: uninstall removes every link"
fresh spaces
P install core team
check "links installed"           '[ -L "$CLAUDE_DIR/agents/athena.md" ] && [ -L "$CLAUDE_DIR/rules/pantheon.md" ]'
P uninstall core team
check "no links left"             '[ -z "$(find "$CLAUDE_DIR" -type l)" ]'
check "no state left"             '[ ! -d "$CLAUDE_DIR/.pantheon" ]'

echo "--- symlinked settings.json stays a symlink"
fresh symlink
mkdir -p "$HOME/dotfiles"; echo '{"model":"opus"}' > "$HOME/dotfiles/settings.json"
ln -s "$HOME/dotfiles/settings.json" "$CLAUDE_DIR/settings.json"
P install core
check "still a symlink after install"   '[ -L "$CLAUDE_DIR/settings.json" ]'
check "dotfiles copy got the hook"      'jq -e "[.hooks.PreToolUse[].hooks[].command] | any(test(\"guard.sh\"))" "$HOME/dotfiles/settings.json" >/dev/null'
P uninstall core
check "still a symlink after uninstall" '[ -L "$CLAUDE_DIR/settings.json" ]'
check "dotfiles copy back to original"  '[ "$(jq -c . "$HOME/dotfiles/settings.json")" = "{\"model\":\"opus\"}" ]'

echo "--- user deleted the hooks key: uninstall still completes"
fresh nohooks
echo '{}' > "$CLAUDE_DIR/settings.json"
P install core
jq 'del(.hooks)' "$CLAUDE_DIR/settings.json" > "$TMP/s" && cat "$TMP/s" > "$CLAUDE_DIR/settings.json"
check "uninstall exits 0"         'P uninstall core'
check "overrides removed"         '[ "$(jq -c . "$CLAUDE_DIR/settings.json")" = "{}" ]'
check "no temp file left"         '[ ! -e "$CLAUDE_DIR/settings.json.pantheon.tmp" ]'
check "no state left"             '[ ! -d "$CLAUDE_DIR/.pantheon" ]'

echo "--- user deleted settings.json: uninstall does not recreate it"
fresh nosettings
P install core
rm "$CLAUDE_DIR/settings.json"
check "uninstall exits 0"         'P uninstall core'
check "settings.json not recreated" '[ ! -e "$CLAUDE_DIR/settings.json" ]'

echo "--- repo changed between install and uninstall: settings still removed"
fresh drift
cp -R "$ROOT" "$TMP/repo"
echo '{}' > "$CLAUDE_DIR/settings.json"
PANTHEON="$TMP/repo/bin/pantheon" P install core
jq '.skillOverrides["minimalist-ui"] = "off"' "$TMP/repo/core/settings.json" > "$TMP/s" && mv "$TMP/s" "$TMP/repo/core/settings.json"
PANTHEON="$TMP/repo/bin/pantheon" P uninstall core
check "settings back to {}"       '[ "$(jq -c . "$CLAUDE_DIR/settings.json")" = "{}" ]'

echo "--- repo moved between install and uninstall: links and hook removed"
fresh moved
rm -rf "$TMP/repo"; cp -R "$ROOT" "$TMP/repo"
echo '{}' > "$CLAUDE_DIR/settings.json"
PANTHEON="$TMP/repo/bin/pantheon" P install core team
mv "$TMP/repo" "$TMP/repo2"
PANTHEON="$TMP/repo2/bin/pantheon" P uninstall core team
check "no dangling links left"    '[ -z "$(find "$CLAUDE_DIR" -type l)" ]'
check "guard hook removed"        '[ "$(jq -c . "$CLAUDE_DIR/settings.json")" = "{}" ]'
rm -rf "$TMP/repo2"

echo "--- FORCE backup is not restored over a file the user made later"
fresh force
mkdir -p "$CLAUDE_DIR/agents"; echo "v1 mine" > "$CLAUDE_DIR/agents/argus.md"
FORCE=1 P install team
rm "$CLAUDE_DIR/agents/argus.md"; echo "v2 my new work" > "$CLAUDE_DIR/agents/argus.md"
P uninstall team
check "new work kept"             'grep -q "v2 my new work" "$CLAUDE_DIR/agents/argus.md"'
check "old version still in backups" 'grep -rqs "v1 mine" "$CLAUDE_DIR/backups"'

echo "--- skill-remove leaves skills Pantheon didn't install alone"
fresh skillrm
rm -rf "$TMP/repo"; cp -R "$ROOT" "$TMP/repo"            # skill-remove edits the manifest
fake="$TMP/fake-skills"; : > "$TMP/skills-calls"
printf '#!/bin/sh\necho "$*" >> "%s"\n' "$TMP/skills-calls" > "$fake"; chmod +x "$fake"
mkdir -p "$CLAUDE_DIR/skills/my-own" "$CLAUDE_DIR/skills/synced"
export SKILLS_CLI="$fake"
PANTHEON="$TMP/repo/bin/pantheon" P skill-remove my-own
check "user's skill kept"          '[ -d "$CLAUDE_DIR/skills/my-own" ]'
check "skills CLI never called"    '[ ! -s "$TMP/skills-calls" ]'
check "synced refused"             '! PANTHEON="$TMP/repo/bin/pantheon" P skill-remove synced && [ -d "$CLAUDE_DIR/skills/synced" ]'
unset SKILLS_CLI

[ "$fail" = 0 ] && echo "  ✓ edge cases passed"
exit "$fail"
