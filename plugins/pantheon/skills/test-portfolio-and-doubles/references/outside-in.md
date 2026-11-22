# Outside-in, acceptance first

The acceptance tests and builders below ran green under Vitest 4 with Fastify 5 and pytest 9 with FastAPI. The before/after builder snippet near the end is illustrative and was not run.

Contents
- The double loop
- First red: the acceptance test
- Driving inward
- Deleting scaffolding
- Builders

## The double loop

The outer loop is one acceptance test per feature slice; it stays red for the whole slice. The inner loop is ordinary red-green-refactor on unit tests (the superpowers `test-driven-development` skill), one rule at a time. You are done with the slice when the outer test goes green without being edited.

Pick the outer level by what the feature exposes:

- API feature: handler test, in-process through the real router and middleware.
- UI feature: one end-to-end journey, plus handler tests for the endpoints behind it.
- Background job or consumer: invoke the real handler with a real message shape and assert the persisted result or the published event.

## First red: the acceptance test

Write it in the language of the requirement, assert only what a client can observe, and read it back through the public API rather than peeking into the database.

**Wire the real database before the slice is done.** The examples use the in-memory repo so they run anywhere without Docker. In a real project the default is the real database from the start; a repository fake is only worth having when DB-backed tests get too slow or there are 2+ storage backends. Before the slice is finished, the acceptance test takes the repo from the integration fixture (real Postgres in a container); only ports to systems you do not own stay doubled. A handler test that runs on fakes proves the routing and nothing about the queries.

TypeScript (Fastify `inject`; supertest is the equivalent for Express):

```ts
// In the real suite testDeps() wires the Postgres repo from the integration setup;
// external ports (mailer, tax provider) stay doubled.
function testDeps() {
  return {
    orders: new InMemoryOrderRepo(),
    rates: { rateFor: async () => 0.2 },
    mailer: { send: vi.fn().mockResolvedValue(undefined) },
    now: () => new Date("2030-01-01T09:00:00Z"),
  };
}

describe("POST /orders (acceptance, in-process through the real router)", () => {
  it("places an order that can then be fetched", async () => {
    const app = buildApp(testDeps());
    const created = await app.inject({
      method: "POST",
      url: "/orders",
      payload: { id: "o-1", customerEmail: "a@example.test", country: "DE", lines: [{ priceCents: 1000, qty: 2 }] },
    });
    expect(created.statusCode).toBe(201);

    const fetched = await app.inject({ method: "GET", url: "/orders/o-1" });
    expect(fetched.json()).toEqual({ id: "o-1", totalCents: 2400, status: "placed" });
  });

  it("answers 422 with a stable code for an empty order", async () => {
    const app = buildApp(testDeps());
    const res = await app.inject({
      method: "POST",
      url: "/orders",
      payload: { id: "o-2", customerEmail: "a@example.test", country: "DE", lines: [] },
    });
    expect(res.statusCode).toBe(422);
    expect(res.json()).toEqual({ code: "order.empty" });
  });
});
```

Python (FastAPI `TestClient`; Flask and Django test clients work the same way):

```python
@pytest.fixture
def client():
    # In the real suite the orders repo comes from the integration fixture (real Postgres);
    # external ports (mailer, tax provider) stay doubled.
    deps = Deps(orders=InMemoryOrderRepo(), rates=StubRates(), mailer=Mock(spec_set=Mailer),
                now=lambda: datetime(2030, 1, 1, 9, tzinfo=timezone.utc))
    return TestClient(build_app(deps))  # in-process: real routing, validation and serialization, no port


def test_placed_order_can_be_fetched(client):
    created = client.post("/orders", json={"id": "o-1", "customer_email": "a@example.test", "country": "DE",
                                           "lines": [{"price_cents": 1000, "qty": 2}]})
    assert created.status_code == 201
    assert client.get("/orders/o-1").json() == {"id": "o-1", "total_cents": 2400, "status": "placed"}


def test_empty_order_is_422_with_stable_code(client):
    res = client.post("/orders", json={"id": "o-2", "customer_email": "a@example.test", "country": "DE", "lines": []})
    assert (res.status_code, res.json()) == (422, {"code": "order.empty"})
```

Before writing any production code, run it and read the failure. The right first failure is a 404 or a missing field; an import error, a fixture crash or a timeout means the test is not yet testing the feature.

## Driving inward

- Each thing the acceptance test needs becomes a unit-level question: "what is the total with tax?" is a unit test of `placeOrder` or of a pure `totalWithTax` function, not another HTTP call.
- Introduce a port only when the code under construction needs something it should not do itself (send email, look up rates, charge a card). Double it with a stub or mock in service tests; its adapter gets a recorded test.
- Error cases go to the cheapest level that exercises them: the rule ("empty order is rejected") at unit level; its translation ("422 with code `order.empty`") once at handler level.
- Resist adding a second acceptance test for each error case. One per slice for the happy path, plus handler tests for each distinct status code.

## Deleting scaffolding

Some inner tests exist only to get you through a step. After the slice is green, review each test added during the slice:

| Keep | Delete |
|---|---|
| The acceptance test | Tests of a helper that was later inlined or made private |
| Unit tests of domain rules with several cases | A mock-heavy test of an orchestrator whose every path the acceptance and rule tests cover |
| Handler tests for each distinct status code | A test that asserts an intermediate data shape no caller sees |
| Contract suites for each fake that exists | Duplicates of the same case at two levels |

The decision test: mutate the code the test covers. If another kept test goes red for every realistic mutation, the scaffolding test adds maintenance and no protection. If deleting it lets a mutation survive, keep it.

## Builders

One builder per aggregate, valid by default, unique values from a counter.

TypeScript, `test/builders.ts`:

```ts
import type { Order } from "../src/orders";

// Builder: valid defaults, fresh object per call, deterministic unique ids.
let seq = 0;
export function anOrder(overrides: Partial<Order> = {}): Order {
  seq += 1;
  return {
    id: `order-${seq}`,
    customerEmail: `customer-${seq}@example.test`,
    totalCents: 1000,
    status: "placed",
    placedAt: new Date("2030-01-01T00:00:00Z"),
    ...overrides,
  };
}
```

Python, in `tests/support.py`:

```python
_seq = itertools.count(1)
_DEFAULT = Order(
    id="",
    customer_email="",
    total_cents=1000,
    status="placed",
    placed_at=datetime(2030, 1, 1, tzinfo=timezone.utc),
)


def an_order(**overrides) -> Order:
    """Builder: valid defaults, deterministic unique ids; the test passes only what it cares about."""
    n = next(_seq)
    unique = {"id": f"order-{n}", "customer_email": f"customer-{n}@example.test"}
    return replace(_DEFAULT, **(unique | overrides))
```

The field a test asserts on is passed explicitly, even when it equals the default; otherwise a reader cannot see where the expected value comes from, and changing the default silently changes what the test proves:

Illustrative (`invoiceLine` stands for any function under test):

```ts
// hidden: relies on the builder's totalCents default of 1000
const order = anOrder();
expect(invoiceLine(order).amountCents).toBe(1000);
```

```ts
// visible: the test owns the value it asserts
const order = anOrder({ totalCents: 4200 });
expect(invoiceLine(order).amountCents).toBe(4200);
```

Rules that keep builders from becoming shared fixtures:

- Return a new object on every call; never export a prebuilt `DEFAULT_ORDER` that tests mutate.
- Nested aggregates get their own builders (`aLine()`), composed with defaults, not one builder with forty options.
- Builders produce valid objects only. A test that needs an invalid one constructs it inline, so the invalidity is visible.
- For database rows, a builder plus a `persist(order)` helper that inserts inside the test's transaction beats a seed file loaded once for the whole run.
