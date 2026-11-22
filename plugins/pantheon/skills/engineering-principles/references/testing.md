# Tests that actually assert

Covers what the superpowers `test-driven-development` skill (and its `writing-good-tests.md`) does not: vacuous tests, determinism and failure focus. That skill, if installed, owns red-green-refactor, deriving expected values by hand, mock depth and the mutation check.

Contents
- Vacuous tests: they pass whatever the code does
- Behaviour, not implementation
- One reason to fail
- Determinism
- What to mock

## Vacuous tests: they pass whatever the code does

Check every new test by breaking the code it covers and watching it go red. These shapes pass regardless:

```ts
// un-awaited async assertion: the test finishes before the promise rejects
it("rejects bad input", () => {
  expect(parse("x")).rejects.toThrow();          // missing await / return
});

// assertion inside a callback or loop that never runs
it("all items are valid", () => {
  for (const item of getItems()) expect(item.valid).toBe(true);   // getItems() returned []
});

// the only assertion is that nothing threw
it("processes the order", () => {
  expect(() => process(order)).not.toThrow();
});

// asserting the mock you just configured
mockRepo.find.mockResolvedValue(user);
expect(await mockRepo.find("1")).toBe(user);
```

Fixes: `await expect(...).rejects.toThrow(ValidationError)`; assert the collection's length before iterating (`expect(items).toHaveLength(3)`); assert the outcome of `process` (state, return value, emitted event); assert on the unit under test, not the double. In Python, `pytest.raises(Exception)` is as vacuous as a bare except: name the exception type and check the message or field.

## Behaviour, not implementation

Assert on what a caller can observe: return values, persisted state, emitted messages, HTTP responses. Do not assert private method calls, call order between internal helpers, or exact log strings. A refactor that keeps behaviour must keep the tests green; if it does not, the tests are pinned to the implementation.

Snapshots of large objects or rendered output are change detectors, not specifications. Use them only when the whole output is the contract, and review every snapshot diff as if it were code.

## One reason to fail

Each test names one behaviour and fails for one reason. A test called `test_user_flow` with twelve assertions tells you nothing when it fails at assertion seven.

```python
# before
def test_discount():
    assert price(100, "SAVE10") == 90
    assert price(100, "BAD") == 100
    assert price(0, "SAVE10") == 0

# after: parametrize so each case reports separately
@pytest.mark.parametrize("cents, code, expected", [
    (100, "SAVE10", 90),
    (100, "UNKNOWN", 100),
    (0, "SAVE10", 0),
])
def test_price_applies_known_codes_only(cents, code, expected):
    assert price(cents, code) == expected
```

Multiple assertions about one outcome (status and body of one response) are fine.

## Determinism

A test that fails one run in fifty trains everyone to ignore red.

- **Time**: inject the clock or use fake timers (`vi.useFakeTimers()`, `freezegun`, `time-machine`). Never compare against `Date.now()` taken in the test.
- **Waiting**: never `sleep(500)` to let something finish. Await the promise, or poll for the condition with a timeout (`waitFor`, `eventually`).
- **Randomness**: seed it, or inject the generator. Log the seed when property tests fail.
- **Network**: no real external calls in unit or integration tests. Use a local fake server or recorded fixtures at the HTTP boundary.
- **Order and shared state**: each test creates its own data; no reliance on test order, a shared DB row, or a global mutated by another test. Unordered collections are compared as sets or after sorting.
- **Environment**: pin timezone and locale in the test setup; do not depend on the machine's `TZ`, home directory or a free port number.

## What to mock

Mock at the boundaries you do not own or that are slow or nondeterministic: external HTTP APIs, payment providers, email, the clock, randomness. Use the real thing for your own code and, where it is cheap, for your own database (a container or in-memory engine of the same kind).

Mocking your own collaborators couples the test to the current call graph, and a test where most of the lines are mock setup is testing the mocks. If a unit is hard to test without many mocks, move its decisions into a pure function (see `design.md` in this skill) and test that directly.

For generative inputs beyond a few hand-picked cases, the `property-based-testing` skill, if installed, covers it.
