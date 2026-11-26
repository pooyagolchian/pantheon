#!/usr/bin/env bash
# guard.sh — unit tests for plugins/pantheon/hooks/guard.sh.
# Each case feeds a PreToolUse payload on stdin and checks the exit code: 2 = blocked, 0 = allowed.
# Cases live in this file (not on a command line) because the guard would block the test command itself.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/plugins/pantheon/hooks/guard.sh"
command -v jq >/dev/null || { echo "  ✗ guard tests need jq"; exit 1; }
fail=0; n=0

expect() {  # expect <block|allow> <command>
  local want="$1" cmd="$2" got code
  printf '%s' "$cmd" | jq -Rs '{tool_name:"Bash", tool_input:{command:.}}' | "$GUARD" >/dev/null 2>&1
  code=$?
  case "$code" in 2) got=block ;; 0) got=allow ;; *) got="exit $code" ;; esac
  n=$((n+1))
  [ "$got" = "$want" ] || { echo "  ✗ guard: expected $want, got $got: $cmd"; fail=1; }
}

# --- must block
expect block 'rm -rf /'
expect block 'rm -rf /*'
expect block 'sudo rm -rf /'
expect block 'rm -rf ~'
expect block 'rm -rf ~/'
expect block 'rm -rf ~/*'
expect block 'rm -rf $HOME'
expect block 'rm -rf "$HOME"'
expect block 'rm -fr ~'
expect block 'rm -r -f /'
expect block 'rm --recursive --force /'
expect block 'cd /tmp && rm -rf ~'
expect block 'git push --force origin main'
expect block 'git push -f origin master'
expect block 'git push origin +main'
expect block 'git push --force origin HEAD:main'
expect block 'mkfs.ext4 /dev/sda1'
expect block 'dd if=/dev/zero of=/dev/disk2 bs=1m'
expect block ':(){ :|:& };:'
expect block 'chmod -R 777 /'
expect block 'rm -f -r /'
expect block 'rm -rf ${HOME}'
expect block 'rm -rf "$HOME/"'
expect block '/bin/rm -rf /'
expect block 'bash -c "rm -rf ~"'
expect block 'git -C . push --force origin main'
expect block 'git push -fu origin main'
expect block 'git push origin +refs/heads/main'
expect block 'dd if=/dev/zero of=/dev/vda'
expect block 'dd if=/dev/zero of=/dev/mmcblk0'
expect block 'rm -v -rf ~'
expect block 'rm --force --recursive /'
expect block 'rm -rf "/"'
expect block '\rm -rf ~'
expect block 'command rm -rf /'
expect block 'git push --mirror origin'
expect block 'git push origin +HEAD:main'
expect block 'git push --force-with-lease origin main'
# Known false positive, accepted: matching inside quotes is what catches `bash -c "rm -rf ~"`,
# so searching for the literal text is blocked too. Run such a search yourself.
expect block 'grep -n "rm -rf /" README.md'

# --- must allow (ordinary work)
expect allow 'rm -rf ./build'
expect allow 'rm -rf node_modules dist'
expect allow 'rm -rf ~/projects/scratch'
expect allow 'rm -rf /tmp/pantheon-test'
expect allow 'rm -f ~/.cache/foo.log'
expect allow 'git push origin main'
expect allow 'git push --force origin feature/x'
expect allow 'git push --force-with-lease origin feature/x'
expect allow 'dd if=disk.img of=./copy.img'
expect allow 'chmod -R 755 ./bin'
expect allow 'ls -la /'
expect allow 'git push -f origin feature && git checkout main'
expect allow 'git push --force origin x; git log main'
expect allow 'git push --follow-tags origin main'
expect allow 'git push -u origin main'
expect allow 'git push origin +feature/x'
expect allow 'npm run format -- --check src/main.ts'
expect allow 'rm -f ~/notes.txt && ls /'
expect allow 'rm ~/old.log'
expect allow ''

# --- without jq the guard still checks (falls back to the raw payload)
nojq="$(mktemp -d)"; trap 'rm -rf "$nojq"' EXIT
for t in bash cat grep tr printf; do p="$(command -v "$t")" && ln -s "$p" "$nojq/$t"; done
code="$(printf '%s' '{"tool_input":{"command":"rm -rf ~"}}' | PATH="$nojq" "$(command -v bash)" "$GUARD" >/dev/null 2>&1; echo $?)"
n=$((n+1)); [ "$code" = 2 ] || { echo "  ✗ guard without jq: expected block, got exit $code"; fail=1; }

[ "$fail" = 0 ] && echo "  ✓ guard: $n cases passed"
exit "$fail"
