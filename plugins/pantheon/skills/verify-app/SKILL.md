---
name: verify-app
description: Prove a change works by driving the real running app (browser UI, CLI or TUI, HTTP API) against explicit acceptance checks, asserting state rather than eyeballing it, and saving evidence. Use after building a feature or fix, before saying "done", when asked to "verify this end to end", "test it in the browser", or when themis verifies a change.
---

# Verify the app

Tests prove the code does what the tests say. Verification proves the product does what the user asked. This skill gives the second kind of proof. To launch the app, use Claude Code's built-in `run` skill if it is available. This skill decides **what** to check, **how** to assert it, and **what evidence** to keep.

## 1. Turn the claim into checks

Write 2 to 6 acceptance checks before you touch the app. Each check is an action, then an observable result, then where you observe it.

```
C1  Submit signup form with a new email  →  redirected to /welcome, user row exists   (URL + DB)
C2  Submit with an existing email        →  inline error "already registered", no row  (DOM + DB)
C3  CLI `acme export --since 7d`         →  exit 0, CSV with header + ≥1 row           (exit code + file)
```

Include at least one **negative** check (bad input, unauthorised, empty state) and the specific **regression** the change could cause. If the request had no acceptance criteria, derive them from it and state them.

## 2. Choose the driver for the surface

| Surface | Driver | Assert on |
|---|---|---|
| Web UI | Playwright / Chrome DevTools MCP, or `npx playwright` script | URL, DOM text and roles, network responses, console errors, storage |
| HTTP API | `curl -sS -w '%{http_code}'`, or a script | status code, JSON fields (`jq -e`), headers, side effects |
| CLI | run the binary directly | exit code, stdout/stderr content, files written |
| TUI / interactive CLI | `tmux new -d -s v`, `send-keys`, `capture-pane -p` | screen text after each step |
| Background job / queue | trigger it, then poll the result store | final state, logs, timing |
| Library | a minimal script that imports the public API | return values, raised errors |

Prefer the driver the project already uses (an existing e2e suite, `make` targets, documented scripts) over a new one.

## 3. Run it

- Start from a **clean, known state**: fresh test data or a seeded database, a logged-out browser, an empty output folder.
- Wait for **readiness**, not for time. Poll the health endpoint or the port, or wait for a selector. Never use `sleep 5` and hope.
- Assert **state**, not appearance. Screenshots are evidence for the user, not proof for you. Check text, status codes, records and files.
- Watch for **silent failures**: console errors, 4xx and 5xx responses in the network log, warnings on stderr, and a non-zero exit hidden behind a pipe (`set -o pipefail`).
- Exercise the **real** path. If the app only works with a mock or a feature flag you set by hand, report that as a gap, not a pass.

## 4. Keep evidence

Save it to `.verify/<YYYYMMDD-HHMM>/` (add `.verify/` to `.gitignore`) or the project's equivalent:

- the commands you ran, and the key output lines
- screenshots of the key screens and the final state
- response bodies and any relevant log excerpts

## 5. Report

```
Claim:    <one sentence>
Verdict:  PASS | FAIL | PARTIAL
Checks:   C1 PASS  (URL=/welcome, users.count +1)
          C2 FAIL  (no inline error; 500 in network log: POST /api/signup)
Evidence: .verify/20260115-1432/
Gaps:     what was not exercised and why (no staging credentials, payments mocked)
```

FAIL and PARTIAL include the failing step, what you expected, what you saw, and the first log line that explains it. Hand failures to a debugger (`asclepius`). Don't patch production code inside verification.

## Gotchas

- The dev server port is already taken by an old process. Check with `lsof -i :<port>` before you start, and stop what you started when you finish.
- Hot reload serves stale code after a build. Restart the server when verification follows a code change.
- Auth walls. Use the project's test user or seed script. Never use real credentials, and never type secrets into a page.
- Flaky selectors. Prefer roles and visible text (`getByRole('button', {name: 'Save'})`) over CSS paths.
- Time zones, locales and caches can make a PASS on your machine meaningless. Note the environment in the report.
- Never point verification at production, or anything outward-facing (real emails, payments, webhooks), without explicit approval.
