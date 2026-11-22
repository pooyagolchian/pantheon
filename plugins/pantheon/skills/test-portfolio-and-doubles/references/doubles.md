# Doubles, with runnable examples

Each example ran green under Vitest 4 and pytest 9, and each was mutation-checked: deleting the email send, dropping the tax, breaking the decline translation, parsing a proxy's HTML error as JSON, or making the fake ignore overwrites or hand back its stored object turns the intended test red. The TypeScript also type-checks under `tsc --strict --erasableSyntaxOnly`. Not run: the Postgres half of each contract suite (needs a real database; shown wired) and the inline `FakeMailer` sketch in the last section.

Contents
- The ports
- Fake plus contract suite (TypeScript)
- Fake plus contract suite (Python)
- Stub, mock and state assertions in one service test
- Adapter tested against recorded responses
- Choosing between a mock and a recording fake

## The ports

Name ports in your domain's terms and mark which methods are queries and which are commands; that decides the double.

```ts
// Ports, named in our terms. Production adapters implement them; tests double them.
export interface OrderRepo {
  save(order: Order): Promise<void>;
  byId(id: string): Promise<Order | undefined>;
}
export interface TaxRates {
  rateFor(country: string): Promise<number>; // query
}
export interface Mailer {
  send(to: string, template: "order-placed", data: { orderId: string }): Promise<void>; // command
}
```

## Fake plus contract suite (TypeScript)

By default, service tests run against the real database engine (containerised, per-test rollback). Add a repository port and this fake only when those tests become too slow or there are 2+ storage backends; from then on the contract suite is what keeps the fake honest.

`test/order-repo.ts`. The builder `anOrder` (`test/builders.ts`) is shown in `outside-in.md` next to this file.

```ts
import { describe, it, expect } from "vitest";
import type { Order, OrderRepo } from "../src/orders";
import { anOrder } from "./builders";

// Fake: a working in-memory implementation of a port we own.
export class InMemoryOrderRepo implements OrderRepo {
  private rows = new Map<string, Order>();
  private failure: Error | undefined;

  failNextSave(error = new Error("connection reset")) { this.failure = error; }

  async save(order: Order) {
    const failure = this.failure;
    this.failure = undefined;
    if (failure) throw failure;
    this.rows.set(order.id, structuredClone(order));
  }
  async byId(id: string) {
    const row = this.rows.get(id);
    return row && structuredClone(row);
  }
}

// Contract suite: the same behaviour checks run against the fake and the real repo,
// so the fake cannot drift from production.
export function orderRepoContract(name: string, makeRepo: () => Promise<OrderRepo>) {
  describe(`OrderRepo contract: ${name}`, () => {
    it("returns what was saved", async () => {
      const repo = await makeRepo();
      const order = anOrder({ totalCents: 4200 });
      await repo.save(order);
      expect(await repo.byId(order.id)).toEqual(order);
    });
    it("returns undefined for an unknown id", async () => {
      const repo = await makeRepo();
      expect(await repo.byId("missing")).toBeUndefined();
    });
    it("returns a copy, not the stored object", async () => {
      const repo = await makeRepo();
      const order = anOrder({ totalCents: 4200 });
      await repo.save(order);
      order.totalCents = 1;                               // caller mutates its own object after saving
      const read = await repo.byId(order.id);
      if (!read) throw new Error("saved order not found");
      read.totalCents = 2;                                // and the object it read back
      expect((await repo.byId(order.id))?.totalCents).toBe(4200);
    });
    it("overwrites on save with the same id", async () => {
      const repo = await makeRepo();
      const order = anOrder({ status: "placed" });
      await repo.save(order);
      await repo.save({ ...order, status: "shipped" });
      expect((await repo.byId(order.id))?.status).toBe("shipped");
    });
  });
}
```

Run the contract against the fake in the unit suite and against the real adapter in the integration suite:

```ts
orderRepoContract("in-memory fake", async () => new InMemoryOrderRepo());
// In the integration suite, the same contract runs against the real adapter:
// orderRepoContract("postgres", async () => new PgOrderRepo(await freshSchema()));
```

Keep the contract to behaviour the service relies on (round-trip, copy semantics, missing id, overwrite, ordering if callers depend on it). Constraint violations, transactions and query plans are integration-only tests of the real repo; the fake does not imitate them.

## Fake plus contract suite (Python)

`tests/support.py`:

```python
from orders import Order


class InMemoryOrderRepo:
    """Fake: a working in-memory implementation of a port we own.

    Copies on save and read, like a real database: a test must not be able to change
    "stored" data by mutating an object it holds (Order is frozen today; nested lists may not be).
    """

    def __init__(self) -> None:
        self._rows: dict[str, Order] = {}
        self._failure: Exception | None = None

    def fail_next_save(self, error: Exception | None = None) -> None:
        self._failure = error or ConnectionError("connection reset")

    def save(self, order: Order) -> None:
        failure, self._failure = self._failure, None
        if failure:
            raise failure
        self._rows[order.id] = copy.deepcopy(order)

    def by_id(self, order_id: str) -> Order | None:
        row = self._rows.get(order_id)
        return copy.deepcopy(row) if row else None
```

A parametrized fixture runs one contract against both implementations; the Postgres case is skipped without `DATABASE_URL` and marked so CI can select it:

```python
def make_postgres_repo():
    from app_db import PgOrderRepo, fresh_schema  # real adapter; only importable in the integration env
    return PgOrderRepo(fresh_schema(os.environ["DATABASE_URL"]))


# One contract, two implementations: the fake cannot drift from the real repo.
@pytest.fixture(params=[
    "memory",
    pytest.param("postgres", marks=[
        pytest.mark.integration,
        pytest.mark.skipif("DATABASE_URL" not in os.environ, reason="needs a real Postgres"),
    ]),
])
def repo(request):
    return InMemoryOrderRepo() if request.param == "memory" else make_postgres_repo()


def test_returns_what_was_saved(repo):
    order = an_order(total_cents=4200)
    repo.save(order)
    assert repo.by_id(order.id) == order


def test_returns_a_copy_not_the_saved_object(repo):
    order = an_order()
    repo.save(order)
    first, second = repo.by_id(order.id), repo.by_id(order.id)
    assert first == order and first is not order and second is not first
```

## Stub, mock and state assertions in one service test

TypeScript, `test/orders.test.ts`:

```ts
function makeDeps() {
  const orders = new InMemoryOrderRepo();                                // fake: stateful port we own
  const rates = { rateFor: async (_country: string) => 0.2 };           // stub: canned answer to a query
  const mailer = { send: vi.fn<Mailer["send"]>().mockResolvedValue() }; // mock: outgoing command
  const deps: Deps = { orders, rates, mailer, now: () => new Date("2030-01-01T09:00:00Z") };
  return { deps, orders, mailer };
}

describe("placeOrder", () => {
  it("stores the order with tax applied", async () => {
    const { deps, orders } = makeDeps();
    await placeOrder(
      { id: "o-1", customerEmail: "a@example.test", country: "DE", lines: [{ priceCents: 1000, qty: 2 }] },
      deps,
    );
    // State-based: assert what was persisted, not which repo methods were called.
    expect(await orders.byId("o-1")).toMatchObject({ totalCents: 2400, status: "placed" });
  });

  it("sends the confirmation email", async () => {
    const { deps, mailer } = makeDeps();
    await placeOrder(
      { id: "o-1", customerEmail: "a@example.test", country: "DE", lines: [{ priceCents: 1000, qty: 1 }] },
      deps,
    );
    // Interaction-based, because the email is the requirement and it is a command.
    expect(mailer.send).toHaveBeenCalledExactlyOnceWith("a@example.test", "order-placed", { orderId: "o-1" });
  });

  it("rejects an empty order without side effects", async () => {
    const { deps, orders, mailer } = makeDeps();
    await expect(
      placeOrder({ id: "o-1", customerEmail: "a@example.test", country: "DE", lines: [] }, deps),
    ).rejects.toThrow(EmptyOrderError);
    expect(await orders.byId("o-1")).toBeUndefined();
    expect(mailer.send).not.toHaveBeenCalled();
  });

  it("does not email when the order could not be saved", async () => {
    const { deps, orders, mailer } = makeDeps();
    orders.failNextSave();
    await expect(
      placeOrder({ id: "o-1", customerEmail: "a@example.test", country: "DE", lines: [{ priceCents: 1000, qty: 1 }] }, deps),
    ).rejects.toThrow("connection reset");
    expect(mailer.send).not.toHaveBeenCalled();
  });
});
```

Python, `tests/test_place_order.py` (the fake lives in `tests/support.py`):

```python
class StubRates:
    """Stub: canned answer to a query."""

    def rate_for(self, country: str) -> float:
        return 0.2


@pytest.fixture
def orders():
    return InMemoryOrderRepo()


@pytest.fixture
def mailer():
    return Mock(spec_set=Mailer)  # mock: outgoing command; spec_set rejects misspelt methods


@pytest.fixture
def deps(orders, mailer):
    return Deps(orders=orders, rates=StubRates(), mailer=mailer,
                now=lambda: datetime(2030, 1, 1, 9, tzinfo=timezone.utc))


def test_stores_the_order_with_tax_applied(deps, orders):
    place_order("o-1", "a@example.test", "DE", [Line(price_cents=1000, qty=2)], deps)
    stored = orders.by_id("o-1")
    assert (stored.total_cents, stored.status) == (2400, "placed")


def test_sends_the_confirmation_email(deps, mailer):
    place_order("o-1", "a@example.test", "DE", [Line(price_cents=1000, qty=1)], deps)
    mailer.send.assert_called_once_with("a@example.test", "order-placed", {"order_id": "o-1"})


def test_rejects_an_empty_order_without_side_effects(deps, orders, mailer):
    with pytest.raises(EmptyOrderError, match="o-1"):
        place_order("o-1", "a@example.test", "DE", [], deps)
    assert orders.by_id("o-1") is None
    mailer.send.assert_not_called()


def test_does_not_email_when_the_order_could_not_be_saved(deps, orders, mailer):
    orders.fail_next_save()
    with pytest.raises(ConnectionError):
        place_order("o-1", "a@example.test", "DE", [Line(price_cents=1000, qty=1)], deps)
    mailer.send.assert_not_called()
```

Note what is *not* asserted: no `toHaveBeenCalledWith` on `rates.rateFor` or `orders.save`. The total and the stored row prove both were used correctly; asserting the calls would only pin the call graph.

## Adapter tested against recorded responses

The adapter is the only code that knows the provider's wire format, so it is the only code tested against it. Record real responses once from the provider's sandbox, commit them, and replay them through an injected transport. Re-record when the provider changes its API version; that diff is the review point.

TypeScript, `src/payments.ts`:

```ts
// Port in our terms; nothing outside this file knows the provider's API shape.
export interface PaymentGateway {
  charge(amountCents: number, cardToken: string): Promise<{ chargeId: string }>;
}
export class CardDeclinedError extends Error {}

type FetchFn = (url: string, init: RequestInit) => Promise<Response>;
type AcmeErrorBody = { error?: { code?: string; message?: string } };

export class AcmePayGateway {
  private readonly apiKey: string;
  private readonly fetchFn: FetchFn;

  constructor(apiKey: string, fetchFn: FetchFn = fetch) {
    this.apiKey = apiKey;
    this.fetchFn = fetchFn;
  }

  async charge(amountCents: number, cardToken: string): Promise<{ chargeId: string }> {
    const res = await this.fetchFn("https://api.acmepay.example/v1/charges", {
      method: "POST",
      headers: { authorization: `Bearer ${this.apiKey}`, "content-type": "application/json" },
      body: JSON.stringify({ amount: amountCents, currency: "eur", source: cardToken }),
    });
    const text = await res.text();
    if (!res.ok) {
      // Check status and content type before parsing: a proxy's 502 or 504 is an HTML page, not JSON.
      const isJson = res.headers.get("content-type")?.startsWith("application/json") ?? false;
      const error = isJson ? (JSON.parse(text) as AcmeErrorBody).error : undefined;
      if (res.status === 402 && error?.code === "card_declined") throw new CardDeclinedError(error.message);
      throw new Error(`acmepay charge failed: ${res.status} ${text.slice(0, 200)}`);
    }
    return { chargeId: (JSON.parse(text) as { id: string }).id };
  }
}
```

```ts
// Recorded once from the provider's sandbox and committed (normally under test/recordings/).
const recorded = {
  chargeOk: json(200, { id: "ch_123", object: "charge", amount: 2400, currency: "eur", status: "succeeded" }),
  declined: json(402, { error: { type: "card_error", code: "card_declined", message: "Your card was declined." } }),
  proxy502: { status: 502, contentType: "text/html", body: "<html><body>502 Bad Gateway</body></html>" },
};

function replay(rec: Recording) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fetchFn = async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(rec.body, { status: rec.status, headers: { "content-type": rec.contentType } });
  };
  return { fetchFn, calls };
}

describe("AcmePayGateway (adapter, against recorded responses)", () => {
  it("sends the amount in minor units and returns the charge id", async () => {
    const { fetchFn, calls } = replay(recorded.chargeOk);
    const gateway = new AcmePayGateway("sk_test", fetchFn);
    expect(await gateway.charge(2400, "tok_visa")).toEqual({ chargeId: "ch_123" });
    expect(JSON.parse(String(calls[0]?.init.body))).toMatchObject({ amount: 2400, source: "tok_visa" });
  });

  it("translates a decline into CardDeclinedError", async () => {
    const gateway = new AcmePayGateway("sk_test", replay(recorded.declined).fetchFn);
    await expect(gateway.charge(2400, "tok_declined")).rejects.toThrow(CardDeclinedError);
  });

  it("reports a non-JSON gateway error with its status", async () => {
    const gateway = new AcmePayGateway("sk_test", replay(recorded.proxy502).fetchFn);
    await expect(gateway.charge(2400, "tok_visa")).rejects.toThrow("acmepay charge failed: 502");
  });
});
```

Python, with `httpx.MockTransport`:

```python
class PaymentGateway(Protocol):
    """Port in our terms; nothing outside this module knows the provider's API shape."""

    def charge(self, amount_cents: int, card_token: str) -> str: ...


class CardDeclinedError(Exception):
    pass


class AcmePayError(Exception):
    pass


class AcmePayGateway:
    def __init__(self, client: httpx.Client) -> None:
        self._client = client  # base_url, auth and timeout are configured by the caller

    def charge(self, amount_cents: int, card_token: str) -> str:
        res = self._client.post("/v1/charges", json={"amount": amount_cents, "currency": "eur", "source": card_token})
        if res.is_success:
            return res.json()["id"]
        # Check status and content type before parsing: a proxy's 502 or 504 is an HTML page, not JSON.
        is_json = res.headers.get("content-type", "").startswith("application/json")
        error = res.json().get("error", {}) if is_json else {}
        if res.status_code == 402 and error.get("code") == "card_declined":
            raise CardDeclinedError(error["message"])
        raise AcmePayError(f"acmepay charge failed: {res.status_code} {res.text[:200]}")
```

```python
# Recorded once from the provider's sandbox and committed (normally as files under tests/recordings/).
CHARGE_OK = httpx.Response(200, json={"id": "ch_123", "object": "charge", "amount": 2400, "currency": "eur",
                                      "status": "succeeded"})
DECLINED = httpx.Response(402, json={"error": {"type": "card_error", "code": "card_declined",
                                               "message": "Your card was declined."}})
PROXY_502 = httpx.Response(502, text="<html><body>502 Bad Gateway</body></html>",
                           headers={"content-type": "text/html"})


def replaying(recording: httpx.Response, seen: list[httpx.Request] | None = None) -> AcmePayGateway:
    def handler(request: httpx.Request) -> httpx.Response:
        if seen is not None:
            seen.append(request)
        return httpx.Response(recording.status_code, headers=recording.headers, content=recording.content)

    return AcmePayGateway(httpx.Client(base_url="https://api.acmepay.example", transport=httpx.MockTransport(handler)))


def test_sends_minor_units_and_returns_charge_id():
    seen: list[httpx.Request] = []
    assert replaying(CHARGE_OK, seen).charge(2400, "tok_visa") == "ch_123"
    assert json.loads(seen[0].content) == {"amount": 2400, "currency": "eur", "source": "tok_visa"}


def test_translates_a_decline():
    with pytest.raises(CardDeclinedError, match="declined"):
        replaying(DECLINED).charge(2400, "tok_declined")


def test_reports_a_non_json_gateway_error_with_its_status():
    with pytest.raises(AcmePayError, match="acmepay charge failed: 502"):
        replaying(PROXY_502).charge(2400, "tok_visa")
```

Unit tests of services that charge cards double `PaymentGateway`, never the HTTP client or the provider SDK.

## Choosing between a mock and a recording fake

Both verify an outgoing command. Use a mock library (`vi.fn<Port["method"]>()`, `Mock(spec_set=Port)`) when one or two tests need it. Switch to a hand-written recording fake (`class FakeMailer { sent: Email[] = [] }`) when several test files assert on the same port, or the assertion is about the set of messages rather than one call: `expect(mailer.sent.map(e => e.to)).toEqual([...])` reads as state and survives argument reordering inside the port.
