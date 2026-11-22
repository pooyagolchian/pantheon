#!/usr/bin/env bash
# skills.sh — quality gate for Pantheon's own skills, agents and commands.
#   structure:  name format, description length, SKILL.md size, references linked and none orphaned
#   triggers:   no two descriptions in the same kind overlap enough to compete for the same request,
#               and no quoted trigger phrase is claimed twice
# Execution evals (does the skill improve output?) belong to skill-creator / `claude plugin eval`.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/pantheon"
MAX_LINES=500 MAX_DESC=1024 MAX_OVERLAP="${MAX_OVERLAP:-0.30}"
fail=0
bad() { echo "  ✗ $*"; fail=1; }

fm() { awk '/^---$/ {n++; next} n==1' "$1"; }
field() { fm "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

for f in "$PLUGIN"/skills/*/SKILL.md; do
  dir="$(dirname "$f")"; rel="${dir#"$ROOT"/}"; name="$(field "$f" name)"; desc="$(field "$f" description)"
  printf '%s' "$name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' && [ ${#name} -le 64 ] || bad "$rel: name '$name' must be lowercase-hyphenated, ≤64 chars"
  [ ${#desc} -le $MAX_DESC ] || bad "$rel: description is ${#desc} chars (max $MAX_DESC)"
  [ ${#desc} -ge 80 ] || bad "$rel: description is too short to trigger reliably (${#desc} chars)"
  lines="$(wc -l < "$f" | tr -d ' ')"; [ "$lines" -le $MAX_LINES ] || bad "$rel: SKILL.md is $lines lines (max $MAX_LINES; move detail to references/)"
  for ref in $(grep -oE 'references/[A-Za-z0-9._-]+' "$f" | sort -u); do
    [ -f "$dir/$ref" ] || bad "$rel: links missing $ref"
  done
  for ref in "$dir"/references/*; do
    [ -f "$ref" ] || continue
    grep -q "references/$(basename "$ref")" "$f" || bad "$rel: references/$(basename "$ref") is not linked from SKILL.md"
  done
done

# Trigger overlap: compare descriptions within each kind with a crude stemmed-word Jaccard score.
node - "$PLUGIN" "$MAX_OVERLAP" <<'EOF' || fail=1
const fs = require('fs'), path = require('path');
const [plugin, max] = [process.argv[2], Number(process.argv[3])];
const stop = new Set('a an and are as at be by for from how in into is it its of on or that the then this to use used uses using when with without what which who you your before after any every one do does not via'.split(' '));
const stem = w => w.replace(/(ing|ed|es|s)$/, '');
const desc = file => (fs.readFileSync(file, 'utf8').split(/^---$/m)[1] || '').match(/^description:\s*(.*)$/m)?.[1] || '';
const words = d => new Set(d.toLowerCase().match(/[a-z][a-z-]{2,}/g)?.filter(w => !stop.has(w)).map(stem) || []);
const phrases = d => (d.match(/"([^"]{4,})"/g) || []).map(p => p.toLowerCase());
const kinds = {
  skills: fs.readdirSync(path.join(plugin, 'skills')).map(d => [d, path.join(plugin, 'skills', d, 'SKILL.md')]),
  agents: fs.readdirSync(path.join(plugin, 'agents')).map(f => [f.replace(/\.md$/, ''), path.join(plugin, 'agents', f)]),
  commands: fs.readdirSync(path.join(plugin, 'commands')).map(f => [f.replace(/\.md$/, ''), path.join(plugin, 'commands', f)]),
};
let bad = 0, worst = [0, ''];
const claimed = new Map();
for (const [kind, items] of Object.entries(kinds)) {
  const d = items.filter(([, f]) => fs.existsSync(f)).map(([n, f]) => [n, desc(f)]);
  for (let i = 0; i < d.length; i++) {
    for (const p of phrases(d[i][1])) {
      if (claimed.has(p)) { console.log(`  ✗ trigger ${p} claimed by both ${claimed.get(p)} and ${d[i][0]}`); bad = 1; }
      claimed.set(p, d[i][0]);
    }
    for (let j = i + 1; j < d.length; j++) {
      const a = words(d[i][1]), b = words(d[j][1]);
      const score = [...a].filter(w => b.has(w)).length / new Set([...a, ...b]).size;
      if (score > worst[0]) worst = [score, `${kind}: ${d[i][0]} ~ ${d[j][0]}`];
      if (score > max) { console.log(`  ✗ ${kind} ${d[i][0]} and ${d[j][0]} descriptions overlap ${score.toFixed(2)} (max ${max})`); bad = 1; }
    }
  }
}
console.log(`  · closest pair ${worst[1]} (${worst[0].toFixed(2)})`);
process.exit(bad);
EOF

[ "$fail" = 0 ] && echo "  ✓ skill quality passed"
exit "$fail"
