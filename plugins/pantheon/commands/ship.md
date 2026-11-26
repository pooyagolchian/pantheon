---
description: Prepare a release — atlas readies version, checks and exact release commands, calliope writes the changelog and PR text; stops before anything outward-facing
argument-hint: [version or bump: patch | minor | major — default: infer from changes]
---

Agent names below are bare; if Pantheon was installed as a plugin, use the namespaced form shown in your agents list (e.g. `pantheon:atlas`).

Prepare a release with the Pantheon team: $ARGUMENTS

1. **Scope**: find the last release (latest tag, or the last version bump in `git log`) and list what changed since: `git log --oneline <last>..HEAD` and `git diff --stat <last>..HEAD`. If there is nothing to release, stop and say so.
2. **Gate**: run the project's full test, lint and typecheck yourself. If anything fails, stop and report — don't release red.
3. In **one message**, dispatch in parallel:
   - `atlas` — bump the version everywhere the project keeps it (or to the version given above), validate what can be validated locally (build, package, dry-run publish), and return the exact outward-facing commands (tag, push, publish, deploy) plus rollback. It must not run them.
   - `calliope` — write the CHANGELOG entry (Keep a Changelog style, user-facing impact first) and the PR or release description, from the commit range and diff, verifying each claim against the code.
4. Review both reports. Re-run any check atlas claims passed. Read the changelog against the diff: every user-visible change listed, nothing invented.
5. **Stop for approval.** Show the user: version, changelog, files changed, and the exact commands from atlas's **To run** with the rollback. Run nothing outward-facing until the user approves those specific commands.

Do not commit, tag, push or publish unless the user explicitly approves it in this conversation.
