#!/usr/bin/env bash
# Claude Code statusline: model · dir · git-branch · output-style
# Reads the harness JSON payload on stdin and prints one line.
set -euo pipefail

input="$(cat)"

model="$(printf '%s' "$input" | jq -r '.model.display_name // "claude"')"
cwd="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "."')"
style="$(printf '%s' "$input" | jq -r '.output_style.name // empty')"

dir="$(basename "$cwd")"

branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch="$(git -C "$cwd" branch --show-current 2>/dev/null)"
  [ -z "$branch" ] && branch="$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)"
fi

# ANSI colors (dim separators, subtle accents)
RESET=$'\033[0m'; DIM=$'\033[2m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'

line="${CYAN}${model}${RESET}"
line="${line} ${DIM}·${RESET} ${dir}"
[ -n "$branch" ] && line="${line} ${DIM}·${RESET} ${GREEN}⎇ ${branch}${RESET}"
[ -n "$style" ] && [ "$style" != "default" ] && line="${line} ${DIM}·${RESET} ${YELLOW}${style}${RESET}"

printf '%s' "$line"
