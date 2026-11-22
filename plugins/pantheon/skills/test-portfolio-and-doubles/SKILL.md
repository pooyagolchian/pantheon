---
name: test-portfolio-and-doubles
description: Decides what to test at which level and with which test double. Maps the kind of change (pure logic, your own database queries, an HTTP endpoint, calls between separately deployed services, a UI journey) to unit, integration, handler, contract or end-to-end tests; sets the testing-trophy shape for web services; prefers state-based over interaction tests; picks fake, stub, mock or spy; covers acceptance-test-first outside-in development, test data builders and quarantining flaky tests. Use when planning how to test a feature, choosing unit vs integration vs e2e, deciding whether to mock, stub or fake a dependency, writing a test plan, or when asked "should I mock this", "unit or integration test?", "what tests does this need", "this test is flaky" or "how many e2e tests". Also use when a suite is slow, brittle or mostly mock setup.
---

# Test portfolio and doubles

Decides *where* each test lives and *what* it replaces. How to write one test (red-green-refactor, hand-derived expected values, the mutation check) is the superpowers `test-driven-development` skill; vacuous tests, determinism and the basic "what to mock" rule are in `engineering-principles`.

## Core rules

1. **Lowest level that runs the code that can break.** A wrong SQL join is invisible to a unit test with a fake repo; a pricing edge case does not need a browser.
2. **Assert state by default.** Interaction assertions only for outgoing commands at ports you own, never for queries.
3. **Double external systems at your own port, never their SDK.** The adapter behind the port gets its own recorded test.
4. **Every fake runs the same contract suite as the real implementation**, or it drifts and lies.
5. **Each test states only what it is about.** Builders supply the rest; nothing shared is mutable.
6. **A flaky test is quarantined with an owner and a deadline**, never retried until green.

## Choose the level

| The change is in | Test at | Real | Doubled |
|---|---|---|---|
| Pure logic: pricing, rules, parsing, state machines | unit | everything | nothing (pass `now`, ids, seeds in) |
| Use-case orchestration in a service | service test | domain code and your DB (rolled back per test) | external ports; repos only once a repository port with a contract-tested fake exists |
| Your own SQL, repo, migration, constraint, transaction | integration | the same DB engine and major version, in a container | nothing |
| HTTP contract: routing, auth, parsing, status codes, error shape | handler test, in-process through the real router | app, middleware, DB | external ports only |
| Adapter to a third-party API | adapter test against recorded responses | adapter and HTTP client | the network (replayed) |
| Calls between 2+ independently deployed services you own | consumer-driven contract test (Pact-style) | each side alone | the other side, via the contract |
| A UI journey that makes money or loses data | end-to-end in a real browser | the whole stack | third parties only |

- **Many cases, little wiring**: extract the decision into a pure function, cover the cases at unit level, and keep one handler test for the wiring.
- **No contract tests inside one deployable.** Modules released together just call each other; a contract suite there is ceremony. Before the second service exists, a handler test plus a schema check on the response is enough.
- **End-to-end is a small automated journey suite.** Driving the live app to prove one change works is `verify-app`, not this.

## Portfolio shape

For web apps and services the default is the **trophy**, not the pyramid: static types and lint underneath, most of the weight on handler and integration tests against a real DB, unit tests for pure logic, and a thin e2e top. Rough proportions for a TS or Python service: unit ~30%, handler and integration ~60-65%, e2e 3-10 journeys (under 5%). The pyramid (mostly unit) fits libraries and algorithm-heavy code where most behaviour is pure.

Read `references/portfolio.md` for what each layer must prove, the tooling per layer, real-DB isolation, and the CI layout.

## State vs interaction

- **Default**: act, then assert the return value, the persisted row, the fake's contents or the HTTP response.
- **Interaction assertion** only when the requirement *is* an outgoing command and its effect is not otherwise observable: email sent, event published, card charged. Assert it once, with the arguments that matter.
- **Never verify a query.** Stub `rates.rateFor` and assert the total; `expect(repo.findById).toHaveBeenCalledWith(id)` pins the implementation and breaks on every refactor.

## Pick the double

| Need | Double | Shape |
|---|---|---|
| Stateful collaborator you own, once it sits behind a port: repo, store, cache, queue | **fake** | in-memory working implementation, run through the real one's contract suite |
| A query whose answer drives a branch: rates, flags, current user | **stub** | canned return value, no assertions on it |
| An outgoing command that is the requirement | **mock** | `vi.fn()` / `Mock(spec_set=...)`, asserted after the act |
| Observe a real object without replacing it | **spy** | rarely; prefer a recording fake |
| Clock, ids, randomness | injected value | `now: () => fixedDate` |

- **Never double the system under test's own functions** (partial mocks, `spyOn` its methods, patching the module being tested), and never double value objects; build real ones.
- **Don't `vi.mock` or `patch` third-party SDKs in service tests.** Wrap them in an adapter you own, defined in your terms (`PaymentGateway.charge(amountCents, token)`), and double the adapter; the adapter itself gets a recorded test. Mocking `stripe` or `boto3` directly only encodes a guess about the SDK. (Legacy pinning scaffolding is the temporary exception; see `changing-legacy-code`, if installed.)
- **Repositories: real engine by default.** Test data access against the real database engine while it is cheap (containerised, per-test transaction rollback). Introduce a repository port with an in-memory fake only when DB-backed service tests become too slow or there are 2+ storage backends; then run one contract suite against both the fake and the real repo.
- **Give fakes a failure mode** (`repo.failNextSave()`) so error paths are testable without a mock library.

Read `references/doubles.md` for runnable Vitest and pytest examples: fake plus contract suite, stub, mock, adapter against recorded responses.

## Outside-in for a feature

1. **First red is an acceptance test** at the outermost cheap level: a handler test through the real router, or one e2e journey for a UI flow. Happy path, domain language, asserting observable outcome.
2. **Check it fails for the right reason** (404, missing field), not a setup error.
3. **Drive inward** with unit tests for each rule the acceptance test needs; introduce ports for external systems as the code asks for them.
4. **Acceptance goes green last, on the real DB.** If a repository fake exists it may start on it for speed, but switch it to the real-DB fixture before the slice is done; a handler test on fakes proves routing, not queries. Then add error cases at the cheapest level that exercises them: rules at unit, status-code translation at handler.
5. **Delete scaffolding.** A unit test that only drove out an intermediate step, now covered by the acceptance test and pinned to internal structure, goes. Keep a test if deleting it lets a realistic mutation survive.

## Test data

- **One builder per aggregate** with valid defaults: `anOrder({ status: "shipped" })`, `an_order(status="shipped")`. The test names only the fields it is about.
- **The asserted field is always set in the test body**, never inherited from a builder default; otherwise the expected value is hidden in the builder.
- **Fresh object per call**, unique values from a counter (deterministic, collision-free), no module-level fixture objects tests mutate, no shared seed file every test depends on.

Read `references/outside-in.md` for the acceptance-first walkthrough, builders in both languages, and the scaffolding deletion test.

## Flaky tests

- **Same day it is seen**: move the test to quarantine (`*.quarantine.test.ts` or `@pytest.mark.quarantine`). Quarantine runs in a non-blocking CI job that still reports.
- **Open an issue with a named owner and a deadline of 14 days.** At the deadline it is fixed or deleted, with the behaviour re-covered at a lower level if it matters.
- **No CI retries on the blocking job** (`retry: 2`, `--reruns`, rerun-failed workflows). A retry that turns red green ships the race to production. Rerunning locally to measure the failure rate is fine.
- **Cap the quarantine at 5 tests per suite.** Over the cap, fixing flakes outranks new features.

## Gotchas

- SQLite or an in-memory DB standing in for Postgres or MySQL: different constraints, upsert, JSON, locking and collation. Same engine in a container, or it is a unit test in disguise.
- A fake with no contract suite: green unit tests, broken production.
- A fake that can never fail: every error path goes untested.
- Asserting `toHaveBeenCalledTimes` on internal collaborators, or call order between your own helpers.
- `unittest.mock.patch` on the path where a name is defined instead of where it is looked up; needing it at all usually means a missing port.
- `Mock()` or `vi.fn()` objects without a spec accept any method name, so renaming a port method leaves the test green and production broken. Use `Mock(spec_set=Port)` and typed `vi.fn<Port["method"]>()`.
- Handler tests that bind a real port and `fetch` it: slower and flaky. Use `app.inject`, supertest or `TestClient` in-process.
- Every edge case pushed into e2e: slow, flaky and hard to diagnose. Push it down to the level of the rule.
- Coverage percentage as the goal: it rewards tests of trivial code and says nothing about which risks are covered.

## Test plan template

```
Acceptance (first red): <endpoint or journey>  ->  <observable outcome>
Unit:        <rule>: <cases>
Integration: <query / repo / migration> against real <engine>
Handler:     <endpoint>: auth 401/403, invalid 400/422, missing 404, conflict 409
Doubles:     <port>: fake | stub | mock, and why
Contract:    <consumer -> provider>, or "n/a, single deployable"
Not tested here: <what>, and where it is covered instead
```
