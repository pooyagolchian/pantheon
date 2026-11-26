# Security

Pantheon changes your Claude Code configuration (`~/.claude`). It installs third-party skills and plugins, and it ships a hook that runs before every Bash command. Please treat security reports seriously, and report them privately.

## Reporting a vulnerability

Use GitHub's **Report a vulnerability** button on this repository's Security tab (private vulnerability reporting). Please don't open a public issue for anything exploitable.

Include what you ran, what happened, and what you expected. Say which part is affected: the installer (`bin/pantheon`), the guard hook, an agent or command prompt, or a skill. You should get a reply within a week.

## What is in scope

- `bin/pantheon` and `scripts/capture.sh` doing something to `~/.claude` that uninstall can't reverse, or touching files they didn't create
- `core/settings.json` or the installer granting permissions, hooks or environment variables
- Agent, command or skill prompts in `plugins/pantheon/` that can be steered into running untrusted code or leaking data
- Ways past `plugins/pantheon/hooks/guard.sh` for the commands it claims to block

## What to know before you install

- **The guard hook is a seatbelt, not a sandbox.** It blocks the common forms of a few catastrophic commands, such as recursive deletes of `/` or `~` and force-pushes to `main`. A model that has been steered by a prompt injection can still get past a text match. Use `permissions.deny` and Claude Code's sandbox for real limits.
- **Skills from `skills/manifest.tsv` are third-party and unpinned.** They come from their authors' repositories at install time. Some declare `allowed-tools`, which lets Claude use those tools without asking while the skill is active. Review the profiles you install (`make list`), and start with a narrow one: `PROFILES=core make install`.
- **`make install-all` also installs every plugin in `plugins.tsv`.** Several of them connect to external services through MCP. Read the list first.
- **The installed files are live symlinks into this clone.** A `git pull` changes the hook, statusline, rules and agent prompts immediately. Pin to a release tag if you want changes to arrive only when you choose.
