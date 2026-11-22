---
name: engineering-principles
description: Code-craft rules a strong engineer applies on every change, limited to what models get wrong. Covers fail-loud error handling, parsing input once at the boundary, small single-purpose diffs, simple module and function design, names with intent and units, comments that explain why, and tests that can actually fail. Use when writing, refactoring or reviewing code, implementing a feature, adding try/catch or error handling, designing a function or module, or when asked "is this good code", "why does this swallow errors" or "tighten this diff". Also use as a self-review pass before handing back any code change, to catch catch-and-return-null, casts that silence the type checker, speculative helpers, defensive checks on impossible states, and tests that assert nothing.
---

# Engineering principles

Apply on every change. The loop (explore, plan, verify, never fake green, two strikes) lives in `agentic-workflow`; this skill is about the code itself.

## Core rules

1. **Errors fail loud.** Catch only to recover, add context, translate at a boundary, or clean up. Never return null, a default or an empty list to hide a failure.
2. **Parse at the edge, trust inside.** Untrusted data becomes a typed value at the point of entry. Internal code does not recheck it.
3. **One purpose per diff.** Refactor or change behaviour, not both. Touch only lines the goal needs.
4. **No speculative abstraction.** No extracted helper before the third use; no interface before a second implementation or a test fake.
5. **Every test must be able to fail.** Break the code, watch it go red, then trust it.

## Errors

- **Four reasons to catch, no others**: recover with a real alternative, rethrow with context, translate into the boundary's error shape, release a resource (prefer `finally` / `with`). Everything else propagates to one top-level handler that logs once.
- **Wrap, keep the cause.** `raise ConfigError(f"{path}: ...") from e`, `new Error("saving invoice " + id, { cause: e })`, `fmt.Errorf("...: %w", err)`. The message names the step and the input.
- **No catch-log-continue.** Logging is not handling; the program keeps going with half-done state. Decide what partial failure means and make it visible in the result.
- **Log where you handle, not on the way up.** Log-and-rethrow at each layer produces five log lines with no origin.
- **No silent defaults on required data.** `?? 0`, `|| ""`, `.get(k, default)` turn missing data into plausible wrong data. A default is fine only as the documented meaning of "absent", applied once where input is parsed.
- **Expected vs unexpected.** Bugs always throw. At an inbound boundary (HTTP handler, queue consumer, CLI entry), parse failures and expected domain errors may be thrown as typed errors to one translator that maps them to the response (400/404/409); inside the domain, functions whose callers branch on the outcome return a Result/union instead of throwing. Give each domain error a stable code; never wrap a bug in a `Result`.
- **One error shape per boundary.** One translation point per API, CLI or library surface. Unexpected errors leave as a generic 500 / non-zero exit with an id; details go to logs.
- **Retry only transient failures of idempotent operations**, capped with backoff. Retrying a validation error or a bug hides the cause. Exact status codes and backoff numbers are in `backend-service-checklist`.

Read `references/errors.md` for before/after examples of each rule.

## Boundaries

- A boundary is anywhere data enters: request bodies, params, env vars, config, DB rows, other services' and LLMs' responses, queues, files.
- **Parse, don't validate.** A parser returns a narrower type (`Email`, `OrderLine`) that carries the proof; a boolean validator makes every later function wonder again. Use the schema library the project already has.
- **Make illegal states unrepresentable.** `{ loading, error?, data? }` has four combinations and two are nonsense; a discriminated union has exactly the legal ones. Same for "field X set iff Y".
- **A cast is a missing parse.** `as User`, `as any`, `cast()`, `!`, `# type: ignore` silence the checker exactly where data is least trustworthy. Parse instead; the only legitimate cast lives inside a parser after the check.
- **Defend the edge, not the middle.** Strict parsing with field paths at entry; no null checks inside for values the type says exist. Invariants the type cannot express get an assertion that crashes, not an early `return`.

Read `references/boundaries.md` when designing input handling or replacing casts.

## Diff discipline

The general rule (smallest diff, match surrounding code, report unrelated problems) is in `agentic-workflow`. On top of it:

- **Refactor and behaviour change go in separate diffs or commits.** A reviewer cannot verify a behaviour change hidden in a rename.
- **Do not reformat, reorder imports or rename** in lines the goal does not need. Formatter-only churn hides the real change.
- **Remove code this change makes dead; report other dead code.** The old path, branch or option your change replaces goes in the same diff; dead code you merely noticed is reported, not deleted.
- **No compatibility shims for code with no external callers.** Change the call sites instead of keeping the old signature "just in case".
- **Copy the local idiom** even where you would choose differently: the same error type, logger, test helper, schema library. A second way of doing the same thing is a cost forever.

## Design

- **Deep over shallow.** A module should hide much more than it exposes. A wrapper that maps one-to-one onto what it wraps is cost with no benefit. (Deep modules, seams and the deletion test are covered at length by `codebase-design`, if installed.)
- **One adapter is a hypothetical seam.** Add the interface when the second implementation or the test fake actually arrives.
- **Rule of three.** Two similar blocks are coincidence; extract a helper at the third use, named for the domain, not as a generic options-bag helper.
- **Data over flags.** When behaviour varies by kind, put the variation in one table (`PLANS[plan].seats`) instead of `if plan ==` in five files.
- **No boolean parameters.** `export(r, true, false)` is two functions pretending to be one. Split them, or use a named option.
- **Pure core, imperative shell.** Decisions take inputs (including `now`) and return values; I/O, clock and randomness stay in a thin outer layer. The core needs no mocks.

Read `references/design.md` for examples, plus naming and comment examples.

## Names and comments

- **Units in the name** when the type does not carry them: `timeoutMs`, `sizeBytes`, `priceCents`.
- **Names state the role**: `pendingInvoices`, not `data`; booleans read as predicates (`isExpired`, `shouldRetry`).
- **Comments say why**: the invisible constraint, the incident, what breaks if changed. Delete comments that restate the line below.
- **Update or delete the comment in the same diff** that changes its code. No commented-out code, no `// changed for X` notes.

## Tests

Red-green-refactor, hand-derived expected values, mock depth and the mutation check belong to the superpowers `test-driven-development` skill. Add these:

- **Vacuity check.** Un-awaited `rejects`, `expect` inside a loop over an empty list, `not.toThrow()` as the only assertion, asserting a mock you just configured, `pytest.raises(Exception)`: all pass whatever the code does.
- **Behaviour, not implementation.** Assert return values, persisted state, emitted events. A behaviour-preserving refactor must stay green.
- **One reason to fail.** One behaviour per test; parametrize cases instead of stacking unrelated asserts.
- **Deterministic.** Fake or injected clock, no `sleep` (await or poll a condition), seeded randomness, no real network, no shared state or test order, pinned timezone.
- **Mock only what you do not own** or what is slow or nondeterministic: external APIs, email, payments, the clock. Use your real code, and your real DB engine where cheap.

Read `references/testing.md` when writing or reviewing tests.

## Gotchas

Patterns models produce that look careful and are not:

- `try { ... } catch { return null }` or `except Exception: pass`, which turn an outage into "no data".
- `catch (e) { console.error(e) }` and carrying on, in a loop or a request handler.
- `throw new Error("failed")` that drops the original error and the input that caused it.
- `as any`, `as unknown as T`, `!` or `# type: ignore` to make the checker quiet, instead of fixing the type or parsing.
- `x?.y?.z ?? ""` deep in internal code on values that cannot be null, while the request body is used unparsed.
- An `IFooService` interface plus `FooServiceImpl`, a factory and a config flag, for one implementation.
- A generic `processItems(items, { filter, map, sort, dedupe, limit })` helper written for a single caller.
- New `utils.ts` / `helpers.py` functions duplicating something the codebase already has; search before writing.
- A fallback that silently uses a default config, model or URL when the real one is missing; fail at startup instead.
- Tests that mock the module under test, assert `toHaveBeenCalled()` only, or use `sleep` to wait for async work.
- Comments like `// increment counter` or `// fixed bug`, and docstrings that no longer match the signature.
- Reformatting a whole file while making a one-line fix.

## Before handing back

- [ ] Every `catch` / `except` recovers, adds context, translates at a boundary, or cleans up. No null/default returns hiding failures.
- [ ] Wrapped errors keep their cause and name the failing input.
- [ ] External input is parsed into typed values at entry; no new casts or `any` outside a parser.
- [ ] No defensive checks for states the types rule out; real invariants assert loudly.
- [ ] The diff does one thing; no unrelated formatting, renames or drive-by fixes; code this change makes dead is removed, other dead code is reported.
- [ ] No extracted helper before the third use; no interface before a second implementation or a test fake.
- [ ] Names carry units and roles; every comment touched still tells the truth.
- [ ] Each new test was seen failing against broken code, is deterministic, and mocks only external boundaries.
