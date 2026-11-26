#!/usr/bin/env bash
# lint.sh — static checks: scripts parse, frontmatter is present, manifest rows are sane.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
bad() { echo "  ✗ $*"; fail=1; }

for f in "$ROOT"/bin/pantheon "$ROOT"/scripts/*.sh "$ROOT"/tests/*.sh "$ROOT"/plugins/*/hooks/*.sh "$ROOT"/plugins/*/evals/*/setup.sh "$ROOT"/core/*.sh; do
  bash -n "$f" || bad "syntax: ${f#"$ROOT"/}"
done
command -v shellcheck >/dev/null && shellcheck -S warning "$ROOT"/bin/pantheon "$ROOT"/scripts/*.sh "$ROOT"/plugins/*/hooks/*.sh || true

fm() { awk '/^---$/ {n++; next} n==1' "$1"; }   # frontmatter of a markdown file

for f in "$ROOT"/plugins/*/skills/*/SKILL.md "$ROOT"/skills/vendor/*/SKILL.md; do
  [ -f "$f" ] || continue
  dir="$(basename "$(dirname "$f")")"
  name="$(fm "$f" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '"'"'")"
  fm "$f" | grep -q '^description:' || bad "no description: ${f#"$ROOT"/}"
  [ -n "$name" ] || bad "no name: ${f#"$ROOT"/}"
  case "$f" in "$ROOT"/plugins/*) [ "$name" = "$dir" ] || bad "name '$name' != dir '$dir': ${f#"$ROOT"/}" ;; esac
done

for f in "$ROOT"/plugins/*/agents/*.md; do
  for k in name description tools model; do fm "$f" | grep -q "^$k:" || bad "agent missing $k: ${f#"$ROOT"/}"; done
  [ "$(fm "$f" | sed -n 's/^name:[[:space:]]*//p')" = "$(basename "$f" .md)" ] || bad "agent name != filename: ${f#"$ROOT"/}"
  grep -q '^## Untrusted content' "$f" || bad "agent missing '## Untrusted content' section: ${f#"$ROOT"/}"
done

# Every agent is listed wherever the team is described (see CLAUDE.md "Adding to the team").
team_docs="README.md core/rules/pantheon.md plugins/pantheon/skills/pantheon-orchestration/SKILL.md plugins/pantheon/ONBOARDING.md docs/team.md"
for f in "$ROOT"/plugins/pantheon/agents/*.md; do
  n="$(basename "$f" .md)"
  for d in $team_docs; do
    [ -f "$ROOT/$d" ] || continue
    grep -q "\`$n\`\|#$n-" "$ROOT/$d" || bad "agent '$n' not listed in $d"
  done
done
for f in "$ROOT"/plugins/pantheon/commands/*.md; do
  n="$(basename "$f" .md)"
  grep -q "\`/$n[\` ]" "$ROOT/README.md" || bad "command '/$n' not listed in README.md"
done

for f in "$ROOT"/plugins/*/commands/*.md; do
  fm "$f" | grep -q '^description:' || bad "command missing description: ${f#"$ROOT"/}"
done

awk -F'\t' '!/^#/ && NF != 3 {print "  ✗ manifest line " NR ": expected 3 tab-separated fields"; e=1} END {exit e}' "$ROOT/skills/manifest.tsv" || fail=1
dups="$(grep -v '^#' "$ROOT/skills/manifest.tsv" | cut -f3 | sort | uniq -d)"
[ -z "$dups" ] || bad "duplicate skills in manifest: $dups"
# Manifest fields reach the skills CLI as arguments: keep them to plain names and owner/repo.
awk -F'\t' '!/^#/ && NF == 3 {
  if ($2 != "vendor" && $2 !~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/) { print "  ✗ manifest line " NR ": bad source \"" $2 "\""; e=1 }
  if ($3 !~ /^[a-z0-9][a-z0-9._-]*$/) { print "  ✗ manifest line " NR ": bad skill name \"" $3 "\""; e=1 }
} END {exit e}' "$ROOT/skills/manifest.tsv" || fail=1

# core/settings.json is merged into every user's settings: it must never grant anything.
extra="$(jq -r 'keys[] | select(. != "statusLine" and . != "skillOverrides")' "$ROOT/core/settings.json" 2>/dev/null)"
[ -z "$extra" ] || bad "core/settings.json may only set statusLine and skillOverrides, found: $extra"

for n in $(awk -F'\t' '$2=="vendor" {print $3}' "$ROOT/skills/manifest.tsv"); do
  [ -f "$ROOT/skills/vendor/$n/SKILL.md" ] || bad "vendored skill missing: skills/vendor/$n"
done

for f in "$ROOT"/.claude-plugin/marketplace.json "$ROOT"/plugins/*/.claude-plugin/plugin.json "$ROOT"/plugins/*/hooks/hooks.json "$ROOT"/core/settings.json; do
  jq empty "$f" 2>/dev/null || bad "invalid JSON: ${f#"$ROOT"/}"
done

[ "$fail" = 0 ] && echo "  ✓ lint passed"
exit "$fail"
