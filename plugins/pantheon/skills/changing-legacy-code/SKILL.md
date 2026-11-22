---
name: changing-legacy-code
description: Procedure for safely changing legacy or untested code without breaking what already works. Covers finding the change point and pinch points, pinning current behaviour with characterisation tests before editing, introducing the smallest seam to break a dependency (parameter with a production default, constructor injection, module-level indirection), adding behaviour by sprout or wrap instead of editing the middle, a light Mikado loop for tangled changes, branch by abstraction for in-place swaps, and when to stop. Use when changing, fixing or refactoring code that has no tests, inheriting a legacy codebase, breaking dependencies to get a class or function into a test harness, or planning a large rewrite, and when the user says "add tests to this old code", "I'm scared to touch this", "nobody knows what this does" or "can we just rewrite it". TypeScript and Python examples.
---

# Changing legacy code

Legacy code is code without tests: every edit is a guess until something pins what it does today. Diff discipline (one purpose per diff, no drive-by cleanups) lives in `engineering-principles`, if installed; strangler fig, feature-flag migrations and expand-contract live in `deprecation-and-migration`, if installed.

## Core rules

1. **Pin before you change.** Write characterisation tests around the change point first. Every expected value comes from watching a run produce it, never from reading the code.
2. **Smallest seam that gets the code into a harness.** A parameter with the production value as its default beats a class, an interface or a framework. Production call sites stay unchanged.
3. **Add beside, don't edit the middle.** New behaviour goes in a new function or class (sprout) or around the old call (wrap), with its own tests. The untested body is touched at one line.
4. **Report suspicious behaviour; don't fix it here.** Pin it as it is, mark it, tell the user. A fix is a separate change after they confirm what is intended.
5. **Never discard work with git or commit on your own.** `checkout`, `restore`, `stash`, `reset` or `apply -R` to throw away an attempt, and any commit, need the user's say-so; their tree may hold unrelated work. Undoing your own last edit by hand is fine.

## Procedure

1. **Find the change point**: the exact function and lines the requested change must alter. Write it down as `file:line`.
2. **Find a pinch point**: the narrowest place upstream where one test observes everything the change could affect (a public function, a handler, a CLI entry, a report generator). Test there first; it covers many internals with few tests.
3. **Get it into a harness.** Call the pinch point from a test. When it reaches for the network, clock, randomness, email or a slow store, add a seam (below) and nothing more.
4. **Pin current behaviour.** Use the `characterisation-tests` skill if installed. The core rule, so this stands alone: write `expect(x).toBe("PLACEHOLDER")` or `assert x == "PLACEHOLDER"`, run, paste the value the runner printed. Multi-line output goes in the project's snapshot tool (`toMatchInlineSnapshot()` in Vitest/Jest), filled by a run. Name the file `<module>.characterisation.test.ts` or `test_<module>_characterisation.py` (pytest only collects `test_*.py` / `*_test.py`, so a dotted Python name never runs) and mark odd results `SUSPICIOUS`.
5. **Prove the pins can fail.** Break each line you are about to change (flip `>` to `>=`, change a constant); a test must go red. Restore it.
6. **Make the change** by sprout or wrap, test-first for the new code. Characterisation tests stay green; if one goes red, you changed behaviour you meant to keep, or you found a dependency someone relies on. Stop and say which.
7. **Stop** (see When to stop) and report.

## Seams, in order of preference

- **Function parameter with a production default.** `function quote(order, now = () => new Date())` / `def quote(order, now=datetime.now)`. Call sites do not change; the test passes its own value.
- **Constructor parameter** for a class whose methods share the collaborator. Default to the production one inside the constructor; in Python use a `None` sentinel checked with `is None`.
- **Module-level indirection** when you cannot change the signature: call through one module attribute the test can swap and restore. In Python, patch the name where it is looked up; in TS ESM, imports are read-only, so call through an exported object. Treat module swaps as temporary pinning scaffolding; move to a parameter default once the pins are green.
- **Type the seam as narrowly as the code uses it**: a function type, or `Pick<RealThing, "find">` in TS. No new interface until a second implementation or a test fake actually exists, and even then the narrow type is usually enough.
- **What goes behind a seam**: things you do not own or that are slow or nondeterministic (HTTP APIs, email, payments, clock, randomness). For your own code, call the real thing. For your own database, use the real engine where cheap; a small in-memory version of your own store behind the seam is fine when it is not.

Read `references/seams.md` for before/after examples in TypeScript and Python, including the gotchas.

## Sprout and wrap

- **Sprout function**: the new logic is a new, fully tested function; the legacy body gains one call to it. Use when the change is a computation or a decision.
- **Sprout class**: the same, when the new logic needs state or the legacy class cannot be constructed in a test at all.
- **Wrap**: the new behaviour runs before or after an existing call. Rename the old body (a pure refactor, pins stay green), then give the old name a body that calls it plus the new step. Use for logging, auditing, notifications, caching.
- Wrap leaves the old body intact; sprout puts one line in it. Neither restructures the middle; do that later, under the pins, as its own refactor.

Read `references/sprout-and-wrap.md` for before/after examples in TypeScript and Python.

## Tangled changes: a light Mikado loop

When the change pulls on many things at once:

1. Write the goal at the top of `.mikado.md`.
2. Make the naive change straight at the goal. Run the build and tests.
3. Record each thing that broke as a prerequisite under the goal.
4. Save the attempt as a patch against the base SHA recorded in `.mikado.md` (never a shell variable: each Bash call is a fresh shell), then ask the user before reverting with `git apply -R`.
5. Pick a leaf (a prerequisite with none of its own), do it, get green, tick it off. Offer a commit; do not make one.
6. Repeat from step 2 until the goal itself is a leaf.

Read `references/mikado-and-branch-by-abstraction.md` for the `.mikado.md` template and safe revert commands.

## In-place swaps: branch by abstraction

Replacing an implementation inside one codebase (a parser, a pricing engine, an ORM call path): put an abstraction over the old one, move every caller onto it, build the new one behind it, run the same characterisation tests against both, switch the default, delete the old one. If only one implementation remains, inline the abstraction back. Anything that spans deploys, stored data or external consumers is a migration: `deprecation-and-migration`, if installed. Steps and example are in `references/mikado-and-branch-by-abstraction.md`.

## When to stop

- **Pinning**: every branch the change touches, plus one layer out (its direct callers and callees), and breaking any line you will change turns a test red.
- **Seams**: stop once the pinch point runs in a test. Do not untangle the rest of the module.
- **The change**: stop when the requested behaviour is in, new code has real tests, and characterisation tests are green. Leave the remaining mess in the report.
- **Rewrites**: do not start one unprompted. Propose a Mikado loop or branch by abstraction; if the user still wants a rewrite, pin behaviour at the pinch points first and use those tests as the acceptance check for the new code.

## Gotchas

- Expected values computed by reading the code, or by running a copy of it, certify your misreading. Only the real module's output counts.
- Fixing the "obvious bug" found while pinning. Someone may depend on it; it changes the result of the very tests you need as a safety net.
- `vi.mock` / `jest.mock` / `mock.patch` on your own modules to avoid adding a seam. It pins the test to today's import graph and breaks on the first refactor.
- Python `def f(now=datetime.now())` evaluates once at import; pass the callable. `repo or SqlRepo()` swaps in the real repo when an empty fake is falsy; use `is None`.
- Patching `mailer.send` when the code did `from mailer import send`; patch `billing.send`, where it is looked up.
- Reassigning an ESM import (`fetchRates = fake`) throws; route the call through an exported object.
- An `IFooService` plus a DI container to test one function. One default parameter does the job.
- `git checkout .`, `git restore .`, `git stash` or `git reset --hard` to undo a Mikado attempt; they take the user's unrelated changes with it.
- Characterisation tests left as the permanent suite. They pin bugs too; replace them with intent-named tests as the code becomes understood.

## Report

```
Change point:      file:line
Pinch point:       function tested, and why it covers the change
Pinned:            N characterisation tests in <file>; each value pasted from a run; break-check done
Seams added:       <seam> at file:line, production default kept
Change:            sprout | wrap at file:line, new tests in <file>
Suspicious (not fixed): behaviour, test name, why it looks wrong
Mikado state:      .mikado.md, open leaves (if used)
Left alone:        mess noticed outside the change area
```
