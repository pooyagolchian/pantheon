---
name: characterisation-tests
description: Records what existing code actually does right now, before anyone changes it, by writing characterisation tests (golden master / approval tests) whose expected values come from running the real code, never from reading it. Use when you need to pin current behaviour of code that has no tests or inadequate tests, when specs are missing or contradict the running system, or when code is too tangled to reason about by reading alone. Specifically for documenting what code currently does, not what it should do. Not for test-driving new behaviour.
---

# Characterisation Tests

**Deep-dive resources** are in the `resources/` directory. Load them on demand:

| Resource | Load when... |
|----------|-------------|
| `resources/writing-process.md` | Need a worked example of the full characterisation process with targeted testing, async code, and when-to-stop guidance |
| `resources/modern-tooling.md` | The code under test returns multi-line text, a rendered document or a large object (snapshot and approval testing), you want to sweep many input combinations, or the behaviour is non-deterministic |

## Core Concept

> A **characterisation test** is a test that characterizes the actual behavior of a piece of code. There's no "it should do this" -- the tests document what the system really does.

Characterisation tests have no moral authority. They don't assert correctness -- they detect *change*. When a characterisation test breaks, a human decides whether the change was intended. Also known as **golden master testing** or **approval testing** -- same concept, different names.

*-- Michael Feathers, Working Effectively with Legacy Code (2004)*

## When to Use

- Modifying existing code that has no tests (or inadequate tests)
- Specifications are missing, incomplete, or contradict the running system
- Code is too complex to reason about by reading alone
- Facing the **legacy code dilemma**: need tests to refactor safely, but code resists testing
- Need to understand what a function actually returns before changing it

## When NOT to Use

- **Greenfield code** -- new code should be test-driven from the start
- **You already have specs** -- if requirements are clear and code is new, write behavior-driven tests that assert intended behavior, not characterisation tests that document whatever the code does
- **Code already has adequate tests** -- characterise only the untested parts; don't duplicate existing coverage
- **As a permanent testing strategy** -- characterisation tests are scaffolding; replace them with proper tests as you refactor

## Naming and Identification

Characterisation tests must be **immediately recognisable** as characterisation tests -- to other LLMs, to humans, and to your future self. Someone reading the test file should understand at a glance: these tests document actual behavior, they are not assertions of correctness, and they are intended to be temporary.

### Test Naming

Use `characterises` in the test name to distinguish from behavior-driven tests:

```typescript
// ✅ Clearly identified as characterisation tests
describe('calculateBonus characterisation', () => {
  it('characterises premium-member bonus for < 5 years', () => { ... });
  it('characterises business-member loyalty threshold', () => { ... });
});

// ❌ Indistinguishable from behavior-driven tests
describe('calculateBonus', () => {
  it('should apply a premium-member bonus', () => { ... });
});
```

### File Naming

Use a distinct file suffix so characterisation tests are visually separable in the file tree:

```
scoring.characterisation.test.ts    ← characterisation tests (temporary)
member-bonus.test.ts                ← behavior-driven tests (permanent)
```

The temporary characterisation file may mirror the implementation file 1:1 — it is pinning that file's current behaviour and will be deleted. The permanent tests follow behaviour, not file boundaries.

### Documentation Within Tests

Add a block comment at the top of each characterisation test file explaining the purpose and the planned lifecycle. This is one of the few places where comments are essential -- the tests themselves document *what* the code does, but the comment documents *why these tests exist and when to remove them*:

```typescript
/**
 * CHARACTERISATION TESTS -- documenting actual behavior, NOT asserting correctness.
 *
 * These tests pin down the current behavior of calculateBonus so we can
 * safely refactor it. They should be replaced with behavior-driven tests
 * as the code is understood and restructured.
 *
 * See: characterisation-tests skill for the methodology.
 */
describe('calculateBonus characterisation', () => { ... });
```

### Suspicious Behavior

When a characterisation test captures behavior that looks like a bug, mark it explicitly:

```typescript
it('characterises negative activity handling -- SUSPICIOUS: returns negative bonus', () => {
  // This may be a bug -- negative activity produces a negative bonus.
  // Documented as-is; escalate before changing.
  expect(calculateBonus(-5, 'premium', 3)).toBe(-0.75);
});
```

## The Algorithm

1. **Use** a piece of code in a test harness
2. **Write an assertion you know will fail** (use a dummy value like `"PLACEHOLDER"`)
3. **Run the tests and let the failure tell you the behavior** -- the test runner shows the actual value
4. **Change the test** so it expects the behavior the code actually produces
5. **Repeat** -- let curiosity guide you; the code itself suggests what to test next

**Never type an expected value you have not watched a run produce.** Every expected value comes from executing the real module: the failing placeholder assertion, a recorded snapshot, or a scratch test that imports it. Working the answer out by reading the code, or copying the function into a throwaway script and running the copy, is not characterisation -- it pins your reading of the code, and a misreading becomes a test that certifies the mistake. Write the placeholders, run, then paste in what the runner printed: the test file is written at least twice, with a run in between.

Keep oracle discovery focused: run only the characterisation file or test name while discovering values, then run the project's full suite once the values are stable.

```typescript
// Step 2: write assertion you know will fail
it('characterises formatPrice', () => {
  expect(formatPrice(1999)).toBe('PLACEHOLDER');
});
// Test output: expected 'PLACEHOLDER' but received '$19.99'

// Step 4: change test to expect actual behavior
it('characterises formatPrice', () => {
  expect(formatPrice(1999)).toBe('$19.99');
});
```

**Output longer than a line -- rendered text, a formatted document, a large object -- is pinned with an inline snapshot, not a hand-typed string.** Call `toMatchInlineSnapshot()` with no argument, run once, and the runner writes the observed output into the test file: the algorithm above, automated, and it fails on a single wrong character. Type an expectation by hand only when it is short enough to read at a glance. Load `resources/modern-tooling.md` before pinning multi-line output, for the inline/file snapshot choice, combination sweeps and non-determinism.

## Heuristics

1. **Use focused coverage as your guide** -- run coverage on the change area to confirm your tests actually execute the branches you are about to modify
2. **Production behavior is compatibility evidence, not correctness authority** -- treat deployed observations as something a consumer may depend on until it is known whether they must be preserved
3. **Focus on the change area** -- you don't need to characterise the entire codebase, only the code you're about to modify
4. **Mark suspicious behavior** -- when you find something that looks like a bug, document it in the test but mark it as suspicious; don't silently "fix" it
5. **Look at the code** -- these aren't black-box tests; read the code to guide which paths to characterise
6. **Prove the tests can fail** -- coverage tells you which paths are *exercised*, not which are *protected*. Break each line you are about to change (flip a comparison, change a constant) and watch a characterisation test go red, then restore it

## When to Stop

You don't need 100% coverage of the entire codebase. Stop when:

- **Every branch your upcoming change touches** has a characterisation test exercising it
- **One layer out** from the change point is also covered (the branches that call into or are called by the code you're changing)
- **Breaking any line you will change** turns at least one characterisation test red

If you can't feel confident that your tests would detect a mistake in the specific code you're about to change, add more tests. If you can, stop.

## When You Find Bugs

All legacy code has bugs. When you find one during characterisation:

- **Pin it as it is.** Document the actual behavior, mark the test as suspicious, and keep it passing.
- **Report it; don't fix it in the same change.** If the system is deployed, someone may depend on the "buggy" behavior. Even if it is not deployed, non-deployment does not establish correctness. Fix it only as a separate change, after the user or an authoritative requirement confirms the intended behavior; then replace the old-behavior characterisation with an intended-behavior regression test.
- **Preserve evidence, not a permanently red assertion**: a test for old behavior remains only while that behavior is intentionally conserved.

## Characterisation Tests Are Temporary

They enable refactoring, then get replaced by proper behavior-driven tests:

1. **Characterise** -- pin down current behavior as a safety net
2. **Refactor** -- restructure code while characterisation tests detect any behavioral change
3. **Replace** -- as you understand the code, write proper tests that assert *intended* behavior
4. **Remove** -- retire characterisation tests once proper tests cover the same behavior

> Like walking into a forest and drawing a line: "I own all of this area." After you know that, you can develop it by refactoring and writing more tests. Over time, the characterisation tests can go away.

## Characterising Async Code

Async legacy code requires the same algorithm -- the key difference is awaiting results and controlling timing.

```typescript
// Step 1: dummy assertion, same algorithm
it('characterises fetchUserOrders', async () => {
  const result = await fetchUserOrders('user-123');
  expect(result).toBe('PLACEHOLDER');
});
// Output: expected 'PLACEHOLDER' but received [{ id: 'order-1', ... }]

// Step 2: record actual behavior
it('characterises fetchUserOrders for known user', async () => {
  const result = await fetchUserOrders('user-123');
  expect(result).toEqual([
    expect.objectContaining({ id: 'order-1', status: 'shipped' }),
  ]);
});
```

**Key concerns for async characterisation:**
- **Use real seams for I/O** -- pass async dependencies as parameters (with the production implementation as the default) rather than hitting real services
- **Error paths** -- characterise both resolved and rejected states: `await expect(fn()).rejects.toThrow()`
- **Timing-dependent behavior** -- use `vi.useFakeTimers()` and `vi.advanceTimersByTime()` to control time (see `resources/modern-tooling.md`)
- **Streams and events** -- collect emitted values into an array, then assert on the collected result

```typescript
// Characterising an event emitter
it('characterises order processor events', async () => {
  const events: string[] = [];
  processor.on('status', (s: string) => events.push(s));
  await processor.process(testOrder);
  expect(events).toEqual(['validating', 'processing', 'complete']);
});
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Treating characterisation tests as permanent | They are scaffolding -- replace with behavior-driven tests as you refactor |
| "Fixing" bugs in characterisation tests | Document the actual behavior, mark as suspicious, escalate |
| Trying to characterise the entire codebase | Focus on the area you're about to change + one layer out |
| Writing characterisation tests based on what code *should* do | Let the code tell you what it does -- use the algorithm above |
| Calculating the expected values by reading the code, or from a copy of the function in a scratch script | Run the real module and take every expected value from the runner's output or a recorded snapshot |
| Treating coverage as proof of test strength | Break each line you will change and confirm a test goes red |
| Using characterisation tests for new code | New code should be test-driven |
| Using `vi.mock()` for sensing instead of parameter injection | Pass a sensing function as a parameter with the production function as its default |
| Not awaiting async results | Use `async`/`await` in characterisation tests -- a synchronous assertion on a promise always passes |

## Provenance and license

- **Source**: https://github.com/citypaul/.dotfiles/tree/67d1b74409be1023016e2e6bc8731a33ce0ed4a9/claude/.claude/skills/characterisation-tests
- **Author**: Paul Hammond. MIT License, Copyright (c) 2024 Paul Hammond; full text in `LICENSE` in this directory.
- **Trimmed for Pantheon**: removed references to sibling skills not shipped here (`tdd`, `testing`, `finding-seams`, `mutation-testing`), the watcher and repository mutation-policy paragraphs, and PR-gate instructions; mutation-testing steps replaced by a manual break-it-and-watch-it-fail check; the "not yet deployed: fix it" bug rule changed to report-and-fix-separately.
