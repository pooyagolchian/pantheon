#!/usr/bin/env bash
# lint.sh — static checks: scripts parse, frontmatter is present, manifest rows are sane.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
bad() { echo "  ✗ $*"; fail=1; }

for f in "$ROOT"/bin/pantheon "$ROOT"/scripts/*.sh "$ROOT"/tests/*.sh "$ROOT"/plugins/*/hooks/*.sh "$ROOT"/core/*.sh; do
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
done

for f in "$ROOT"/plugins/*/commands/*.md; do
  fm "$f" | grep -q '^description:' || bad "command missing description: ${f#"$ROOT"/}"
done

awk -F'\t' '!/^#/ && NF != 3 {print "  ✗ manifest line " NR ": expected 3 tab-separated fields"; e=1} END {exit e}' "$ROOT/skills/manifest.tsv" || fail=1
dups="$(grep -v '^#' "$ROOT/skills/manifest.tsv" | cut -f3 | sort | uniq -d)"
[ -z "$dups" ] || bad "duplicate skills in manifest: $dups"
for n in $(awk -F'\t' '$2=="vendor" {print $3}' "$ROOT/skills/manifest.tsv"); do
  [ -f "$ROOT/skills/vendor/$n/SKILL.md" ] || bad "vendored skill missing: skills/vendor/$n"
done

for f in "$ROOT"/.claude-plugin/marketplace.json "$ROOT"/plugins/*/.claude-plugin/plugin.json "$ROOT"/plugins/*/hooks/hooks.json "$ROOT"/core/settings.json; do
  jq empty "$f" 2>/dev/null || bad "invalid JSON: ${f#"$ROOT"/}"
done

[ "$fail" = 0 ] && echo "  ✓ lint passed"
exit "$fail"
