#!/usr/bin/env bash
# guard.sh — PreToolUse hook for Bash: block a small set of catastrophic commands.
# Exit 2 blocks the call and shows stderr to Claude; anything else lets it through.
# Deliberately narrow: it stops disasters, not ordinary work.

command -v jq >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -n "$cmd" ] || exit 0

block() { echo "Pantheon guard blocked this command: $1. If it is really intended, ask the user to run it themselves." >&2; exit 2; }

end='([[:space:]]|$|;|&|\|)'

# rm -r/-f of /, ~, $HOME, or their top-level glob
if printf '%s' "$cmd" | grep -Eq "(^|[;&|[:space:]])(sudo[[:space:]]+)?rm[[:space:]]+(-[[:alnum:]-]+[[:space:]]+)*(/|/\*|~|~/|~/\*|\\\$HOME|\\\$HOME/|\\\$HOME/\*|\"\\\$HOME\")$end"; then
  printf '%s' "$cmd" | grep -Eq "rm[[:space:]]+(-[[:alnum:]]*[rR]|--recursive)" && block "recursive delete of / or home"
fi

# force-push to main/master
if printf '%s' "$cmd" | grep -Eq "git[[:space:]]+push" &&
   printf '%s' "$cmd" | grep -Eq "(--force([[:space:]]|=|$)|[[:space:]]-f([[:space:]]|$)|[[:space:]]\+(main|master))" &&
   printf '%s' "$cmd" | grep -Eq "(^|[[:space:]:+/])(main|master)$end"; then
  block "force-push to main/master"
fi

# disk-level destruction and fork bombs
printf '%s' "$cmd" | grep -Eq "(^|[;&|[:space:]])mkfs(\.[[:alnum:]]+)?[[:space:]]" && block "filesystem format"
printf '%s' "$cmd" | grep -Eq "dd[[:space:]].*of=/dev/(disk|sd|nvme|rdisk)" && block "raw write to a disk device"
printf '%s' "$cmd" | grep -Eq ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:' && block "fork bomb"
printf '%s' "$cmd" | grep -Eq "chmod[[:space:]]+-R[[:space:]]+[0-7]*777[[:space:]]+/$end" && block "chmod -R 777 /"

exit 0
