---
description: Write a session handoff note so a fresh session (or teammate) can continue exactly where this one stopped
argument-hint: [output path — default HANDOFF.md]
---

Output path: $ARGUMENTS

Write a handoff note to that path, or to `HANDOFF.md` in the project root if no path is given. It must let someone with zero context continue the work. Keep it under ~60 lines:

```
# Handoff — <date>
## Goal              what we are trying to achieve, and why
## State             done / in progress / not started (with file paths)
## Decisions         choices made and the reason for each
## Verified          what was tested and how (commands)
## Next steps        ordered, concrete, first one immediately actionable
## Gotchas           traps discovered, commands that fail, things not to touch
```

Base every line on what actually happened in this session — check `git status` and `git diff --stat` rather than relying on memory. Then tell the user the path.
