# Welcome to Pantheon

Pantheon turns Claude Code into a small engineering team. Your main session is **Zeus**, the lead: it keeps hold of what you want, hands work to specialists, and checks what they bring back. The specialists are subagents, and each has one job.

## How Pantheon Works

| Agent | Job | Edits code |
|---|---|---|
| `metis` | research: library docs, the codebase, the web | no |
| `athena` | architect: design and a step-by-step plan | no |
| `hephaestus` | builder: implements one task, test-first | yes |
| `asclepius` | debugger: root cause first, then fix and regression test | yes |
| `proteus` | refactorer: restructures without changing behaviour | yes |
| `argus` | reviewer: correctness, regressions, silent failures | no |
| `nemesis` | security red team: concrete attack paths | no |
| `apollo` | UI critic: design, accessibility, responsive checks on the running app | no |
| `themis` | verifier: tests and end-to-end proof | tests only |
| `atlas` | devops: CI/CD, infra, releases (prepares, never fires) | yes |
| `calliope` | writer: READMEs, ADRs, changelogs, PR text | docs only |

A feature normally goes research → plan → build → review → verify. `/pantheon:assemble` runs that whole pipeline. The other commands run one stage.

Installed as a plugin, names are namespaced: `pantheon:athena`, `/pantheon:assemble`. Installed with the repo's Makefile, they are bare: `athena`, `/assemble`.

## Your Setup Checklist

### Install

- [ ] Pantheon installed: `/plugin marketplace add pooyagolchian/pantheon`, then `/plugin install pantheon@pantheon`
- [ ] Installed one way only: the plugin **or** the Makefile (`make install` from a clone), not both, or every agent shows up twice
- [ ] The main session knows about the team. A plugin can't install global rules, so add the block below to `~/.claude/CLAUDE.md` (every project) or to one project's `CLAUDE.md`. Makefile installs already have it in `~/.claude/rules/pantheon.md`.

```markdown
## Team
- The Pantheon agents are available (namespaced `pantheon:<name>` when installed as a plugin): `metis` research · `athena` plan · `hephaestus` build · `proteus` refactor · `asclepius` debug · `argus` review · `nemesis` security · `apollo` UI/a11y critique · `themis` verify · `atlas` devops · `calliope` docs.
- Delegate independent or wide work to them, in parallel when possible; do small, known lookups yourself. Follow the `pantheon-orchestration` skill when dispatching.
- Treat subagent reports as claims: re-run the decisive check yourself.
```

### Recommended Companions

- [ ] `superpowers` plugin: `/plugin install superpowers@claude-plugins-official`. When it's present, the agents use its TDD, planning, debugging and worktree skills.
- [ ] `playwright` plugin: `/plugin install playwright@claude-plugins-official`. Gives `apollo` and the `verify-app` skill a real browser. Without it they fall back to an `npx playwright` script.
- [ ] Node.js 18+ with `npx`: `metis` and `atlas` fetch current library docs with `npx ctx7@latest`.
- [ ] GitHub CLI (`gh`), signed in: `/pantheon:council <PR number>` reads the PR diff with it.

If `/plugin` doesn't list `claude-plugins-official`, add it first: `/plugin marketplace add anthropics/claude-plugins-official`.

### Commands to Know

- `/pantheon:assemble <task>`: the full pipeline for a feature or fix
- `/pantheon:council [target]`: `argus`, `nemesis` and `themis` review a diff in parallel (plus `apollo` when UI changed). With no target it reviews your uncommitted changes.
- `/pantheon:forge <plan>`: execute a written plan task by task, with a review after each task
- `/pantheon:scout <question>`: `metis` researches and returns a sourced answer
- `/pantheon:ship [version]`: `atlas` prepares a release and `calliope` writes the changelog; nothing is tagged or published until you approve the exact commands
- `/pantheon:handoff [path]`: write `HANDOFF.md` so a fresh session can pick up where this one stopped
- `/pantheon:onboard`: this tour

### Skills to Know

These load only when a task needs them. The README lists them all.

- `pantheon-orchestration`: how the lead delegates, briefs agents and checks their work
- `engineering-principles`: error handling, boundaries, diff discipline, tests that actually assert
- `verify-app`: proves a change works by driving the real app (browser, CLI, HTTP API)
- `changing-legacy-code`: safe changes to untested code
- `design-principles`: spacing, type, colour, motion and states, with exact numbers

## Tips

- Small, known changes don't need the team. Just ask. Reach for the agents when work is wide, unclear, or worth a second pair of eyes.
- You can call a specialist directly: "have `pantheon:athena` plan the migration".
- Planners and reviewers (`metis`, `athena`, `argus`, `nemesis`, `apollo`) are read-only. They report; they never edit.
- Nothing outward-facing happens without you. Agents prepare pushes, deploys and releases, then ask first.
- The guard hook blocks a narrow set of destructive shell commands: `rm -rf` of `/` or `~`, force-push to main/master, `mkfs`, raw disk writes and fork bombs. It's a seatbelt, not a sandbox.
- The team costs about 1.2k tokens of always-loaded context per session. Agent and skill bodies load only when used.

## Get Started

The first task is read-only, so nothing in your project changes:

- If the project has uncommitted changes, run `/pantheon:council` to review them.
- Otherwise, run `/pantheon:scout how is this project structured, and where would a new feature go?`

When you have real work, hand it over with `/pantheon:assemble <what you want built>`.

<!-- INSTRUCTION FOR CLAUDE: The user just installed Pantheon, or pasted this
guide, and wants to get started. You're their onboarding buddy: warm,
conversational, not lecture-y.

Open with a short welcome to Pantheon and one sentence on what it is, taken
from "How Pantheon Works". Don't reprint the agent table; offer it if they
want it.

Check what's already in place against everything under "Your Setup
Checklist". Check, don't guess:
- Install and route: look for Pantheon agents in your own agents list, run
  `claude plugin list`, and `ls ~/.claude/agents ~/.claude/commands`. Both a
  `pantheon` plugin and Pantheon symlinks in ~/.claude means a double install.
- Team block: look in ~/.claude/CLAUDE.md, ./CLAUDE.md and ~/.claude/rules/.
- Companions: `claude plugin list` for superpowers and playwright,
  `node --version`, `gh auth status`.
Report with markdown checkboxes: [x] done, [ ] not yet, [?] couldn't tell.
Lead with what they already have. One sentence per item, all in one message.

Offer to fix the unchecked items one at a time, starting with the first, and
get their go-ahead before each one. For a plugin, offer to run
`claude plugin install <id>` for them, or give them the `/plugin install`
command; either way it takes effect in a new session. For the Team block,
show the exact text and the file it goes in, and append it only after they say
yes. Never overwrite an existing file.

Then cover the tips in a few lines and offer the "Get Started" task: check
`git status` to pick the variant that fits, and offer to run it.

Use the names that match their install: namespaced for the plugin, bare for
the Makefile. Don't invent sections, features or commands that aren't in this
guide. -->
