#!/usr/bin/env bash
# guard.sh — PreToolUse hook for Bash: block a small set of catastrophic commands.
# Exit 2 blocks the call and shows stderr to Claude; anything else lets it through.
# Deliberately narrow: it stops disasters, not ordinary work, and it is a seatbelt, not a
# sandbox — a determined command (eval, base64, a script file) gets past any text match.
# tests/guard.sh pins what it blocks and what it lets through.

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  cmd="$input"   # no jq: match against the raw JSON payload rather than not checking at all
fi
[ -n "$cmd" ] || exit 0

block() { echo "Pantheon guard blocked this command: $1. If it is really intended, ask the user to run it themselves." >&2; exit 2; }

# Whole-command checks (these patterns contain separators themselves).
printf '%s' "$cmd" | grep -Eq ':\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:' && block "fork bomb"

# Per-segment checks: split on ; & | and newlines so `git push -f origin x && git checkout main`
# is judged as two commands, not one.
q="[\"']"                                                       # a quote character
home='(~|\$HOME|\$\{HOME\})'
targets="(/|/\*|${home}|${home}/|${home}/\*)"
rm_cmd="(^|[[:space:]]|${q})(sudo[[:space:]]+)?([^[:space:]\"']*[/\\\\])?rm[[:space:]]+"   # rm, /bin/rm, \rm
rm_target="${rm_cmd}(-[[:alnum:]-]+[[:space:]]+)*\"?${targets}\"?([[:space:]]|${q}|\$)"
rm_recursive="${rm_cmd}(-[[:alnum:]-]+[[:space:]]+)*(-[[:alnum:]]*[rR][[:alnum:]]*|--recursive)([[:space:]]|\$)"

segments="$(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n')"
while IFS= read -r seg; do
  [ -n "$seg" ] || continue

  # rm -r of /, ~, $HOME, or their top-level glob
  if printf '%s' "$seg" | grep -Eq "$rm_target" && printf '%s' "$seg" | grep -Eq "$rm_recursive"; then
    block "recursive delete of / or home"
  fi

  # force-push to main/master (git [-C dir ...] push ... --force*|-f|--mirror|+refspec ... main)
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]/])git[[:space:]](.*[[:space:]])?push([[:space:]]|$)' &&
     printf '%s' "$seg" | grep -Eq '(--force|--mirror|[[:space:]]-[[:alnum:]]*f[[:alnum:]]*([[:space:]]|$)|[[:space:]]\+[^[:space:]]+)' &&
     printf '%s' "$seg" | grep -Eq '((^|[[:space:]:+/])(main|master)([[:space:]]|$)|--mirror)'; then
    block "force-push to main/master"
  fi

  # disk-level destruction
  printf '%s' "$seg" | grep -Eq '(^|[[:space:]])(sudo[[:space:]]+)?mkfs(\.[[:alnum:]]+)?[[:space:]]' && block "filesystem format"
  printf '%s' "$seg" | grep -Eq 'dd[[:space:]].*of=/dev/(r?disk|sd|hd|vd|xvd|nvme|mmcblk)' && block "raw write to a disk device"
  printf '%s' "$seg" | grep -Eq 'chmod[[:space:]]+-R[[:space:]]+[0-7]*777[[:space:]]+/([[:space:]]|$)' && block "chmod -R 777 /"
done <<< "$segments"

exit 0
