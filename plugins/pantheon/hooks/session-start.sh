#!/usr/bin/env bash
# session-start.sh — SessionStart hook: tell the main session the team exists and when to use it.
# Plain stdout from a SessionStart hook is added to Claude's context. Keep it short: it is
# paid for in every session. The Makefile route installs core/rules/pantheon.md instead.
cat <<'EOF'
Pantheon team is available as subagents. Delegate when it fits:
- reviewing a diff or PR before merge → `argus` (add `nemesis` when it touches auth, user input, secrets, files, network or dependencies)
- planning a multi-step change → `athena`; implementing a planned task → `hephaestus`
- finding a bug's root cause → `asclepius`; proving a change works → `themis`
- researching docs or prior art → `metis`
Do small, known lookups yourself. Brief each agent with the goal, the files and what is ruled out, and treat its report as a claim: re-check the decisive point. The `pantheon-orchestration` skill has the details.
EOF
