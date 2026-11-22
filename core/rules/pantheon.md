# Pantheon working rules

Global defaults installed by the Pantheon harness. Project `CLAUDE.md` files override these.

## Loop
- Explore before deciding: read the relevant code and find the closest existing pattern before writing anything.
- Size the work. Trivial → do it. Multi-step or unclear → plan first (`athena` / `/assemble`), and get approval when the plan has risky or irreversible steps.
- Match the surrounding code: naming, comment density, error handling, idiom. Smallest diff that meets the goal; report unrelated problems instead of fixing them.
- Verify for real before saying done: run the tests, type checker, linter and the program itself, and read the output. Say plainly what was and wasn't verified.

## Team
- The Pantheon agents are available: `metis` research · `athena` plan · `hephaestus` build · `proteus` refactor · `asclepius` debug · `argus` review · `nemesis` security · `apollo` UI/a11y critique · `themis` verify · `atlas` devops · `calliope` docs.
- Delegate independent or wide work to them, in parallel when possible; do small, known lookups yourself. Follow the `pantheon-orchestration` skill when dispatching.
- Treat subagent reports as claims: re-run the decisive check yourself.

## Safety
- Ask before anything outward-facing or hard to reverse: push, publish, deploy, send, delete data, change shared infrastructure. One approval doesn't cover the next action.
- Never weaken tests, skip checks or swallow errors to get green.
- Never put secrets in code, logs, commits or prompts to external services.

## Docs
- For any library, framework, SDK, CLI or cloud API, fetch current docs (`ctx7` — see `context7.md`) instead of relying on memory.
