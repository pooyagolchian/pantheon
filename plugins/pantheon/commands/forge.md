---
description: Execute an implementation plan task by task — hephaestus builds, argus reviews each task, themis verifies at the end
argument-hint: <path to plan file, or paste the plan>
---

Agent names below are bare; if Pantheon was installed as a plugin, use the namespaced form shown in your agents list (e.g. `pantheon:athena`).

Execute this plan with the Pantheon team: $ARGUMENTS

1. Read the plan. Build a task list (TodoWrite) with each task's files, done-check and dependencies. If a task lacks a runnable done-check, define one before starting.
2. For each ready task (independent tasks in parallel, one message, multiple Agent calls):
   - dispatch `hephaestus` (or `proteus` for tasks tagged refactor) with a self-contained brief: the task, the files, the done-check, relevant conventions, and what *not* to touch;
   - when it reports, dispatch `argus` on that task's diff;
   - send confirmed findings back to the builder; mark the task done only when its done-check passes. At most 5 fix rounds per task: rounds 1–3 resume the same builder (`SendMessage`), rounds 4–5 go to a fresh builder (optionally a stronger model via the `model` override). If `SendMessage` can't resume the agent, dispatch a fresh builder with its previous report and the findings in the brief. After round 5, stop and bring the task to the user.
3. After the last task, dispatch `themis` to verify the plan's overall goal end to end, and run the project's full test/lint/typecheck yourself.
4. Report per task: done / not done, how verified. Do not commit unless asked.

If a task turns out wrong or blocked, stop and bring it to the user rather than improvising a new design.
