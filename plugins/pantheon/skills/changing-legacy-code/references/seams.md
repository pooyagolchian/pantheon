# Seams: getting legacy code into a test harness

A seam is a place where a test can substitute what the code does without editing the code at that place. Add the smallest one that lets the pinch point run in a test, keep the production behaviour as the default, and stop.

Contents
- Parameter with a production default
- Constructor parameter
- Module-level indirection
- Typing the seam
- Gotchas

## Parameter with a production default

The default seam. Call sites do not change, so the production path is byte-for-byte what it was.

```ts
// before: reads the clock directly, so the result depends on when the test runs
export function isTrialExpired(account: Account): boolean {
  return Date.now() - account.createdAt.getTime() > TRIAL_MS;
}

// after: the clock is a parameter; production callers still pass one argument
export function isTrialExpired(account: Account, now: () => number = Date.now): boolean {
  return now() - account.createdAt.getTime() > TRIAL_MS;
}

// characterisation test
it("characterises trial expiry one day after the trial window", () => {
  const fixedNow = () => Date.parse("2025-01-16T00:00:00Z");
  expect(isTrialExpired(account, fixedNow)).toBe("PLACEHOLDER"); // run, then paste the printed value
});
```

```python
# before
def is_trial_expired(account):
    return datetime.now(timezone.utc) - account.created_at > TRIAL

# after: pass the callable, not its result (see Gotchas)
def is_trial_expired(account, now=lambda: datetime.now(timezone.utc)):
    return now() - account.created_at > TRIAL

# characterisation test
def test_characterises_trial_expiry_one_day_after_window():
    fixed = lambda: datetime(2025, 1, 16, tzinfo=timezone.utc)
    assert is_trial_expired(ACCOUNT, now=fixed) == "PLACEHOLDER"  # pytest prints the real value
```

## Constructor parameter

Use when several methods share the collaborator, or the class builds it in its constructor.

```ts
// before: the gateway is created inside, so constructing the class calls the provider
export class InvoiceService {
  private readonly gateway = new PaymentsGateway(config.paymentsUrl);
  async settle(invoice: Invoice): Promise<Receipt> { /* 80 untested lines using this.gateway.charge */ }
}

// after: `new InvoiceService()` still works everywhere; tests pass a stand-in for the provider
export class InvoiceService {
  private readonly gateway: Pick<PaymentsGateway, "charge">;
  constructor(gateway: Pick<PaymentsGateway, "charge"> = new PaymentsGateway(config.paymentsUrl)) {
    this.gateway = gateway;   // assigned in the body: parameter properties are not erasable syntax
  }
  async settle(invoice: Invoice): Promise<Receipt> { /* unchanged */ }
}

const service = new InvoiceService({ charge: async () => ({ id: "ch_1", status: "succeeded" }) });
```

```python
# before
class InvoiceService:
    def __init__(self):
        self._gateway = PaymentsGateway(settings.PAYMENTS_URL)

# after: None sentinel, checked with `is None`
class InvoiceService:
    def __init__(self, gateway=None):
        self._gateway = gateway if gateway is not None else PaymentsGateway(settings.PAYMENTS_URL)
```

## Module-level indirection

Use when the signature is fixed by something else (a framework calls the handler with set arguments) or there are too many layers between the test and the dependency to thread a parameter through.

```ts
// before: ESM import bindings are read-only, so a test cannot replace sendEmail
import { sendEmail } from "./mailer.js";
export async function closeAccount(id: string): Promise<void> {
  // ...
  await sendEmail(user.email, "account-closed");
}

// after: one exported object is the seam; production code calls through it
import { sendEmail } from "./mailer.js";
export const deps = { sendEmail };
export async function closeAccount(id: string): Promise<void> {
  // ...
  await deps.sendEmail(user.email, "account-closed");
}

// test: swap and always restore
const original = deps.sendEmail;
const sent: string[] = [];
beforeEach(() => { deps.sendEmail = async (to) => { sent.push(to); }; });
afterEach(() => { deps.sendEmail = original; });
```

In Python, module globals already are this seam: no code change is needed, only the right target. This is temporary pinning scaffolding for code that has no seam yet; once the characterisation tests are green, add a parameter default and switch the test to it.

```python
# billing.py
from mailer import send_email          # billing now holds its own reference
def close_account(account_id): ...; send_email(user.email, "account-closed")

# test: patch the name where it is looked up (billing), not where it is defined (mailer)
def test_characterises_close_account_email(monkeypatch):
    sent = []
    monkeypatch.setattr(billing, "send_email", lambda to, template: sent.append((to, template)))
    billing.close_account("acc_1")
    assert sent == "PLACEHOLDER"
```

## Typing the seam

- Type it as the narrowest thing the code uses: `() => number`, `Pick<PaymentsGateway, "charge">`, a `Callable`. TS structural typing and Python duck typing mean no named interface is needed for the fake.
- Add a named interface or `Protocol` only when a second real implementation arrives (branch by abstraction is the usual reason).
- Your own pure code is never behind a seam; call it. Your own database: the real engine where cheap, otherwise a small in-memory store with the same methods.

## Gotchas

- **Python defaults are evaluated once, at definition.** `def f(now=datetime.now())` freezes the time of import; `def f(items=[])` shares one list across calls. Pass a callable, or use `None`.
- **Falsy fakes.** `gateway or PaymentsGateway()` silently uses the real gateway when the fake defines `__len__` or `__bool__` and is empty. Use `is None`.
- **Patch target.** `mock.patch("mailer.send_email")` does nothing to a module that did `from mailer import send_email`; patch `billing.send_email`.
- **ESM imports cannot be reassigned.** `sendEmail = fake` is a compile error in TS and a `TypeError` at runtime. Route through an exported object, or add a parameter.
- **`vi.mock` / `jest.mock` replace the whole module for the whole file** and are hoisted above imports. Acceptable only as temporary pinning scaffolding for a third-party client called from legacy code with no seam yet; for your own modules, add a seam instead.
- **Module swaps and `vi.mock` are legacy scaffolding, not test style.** Replace them with a real seam (a parameter default) as soon as one exists. In normal tests, never double the code under test's own functions, and do not `vi.mock` a third-party SDK: wrap it in an adapter and fake the adapter.
- **Always restore module-level swaps** (`afterEach`, or pytest's `monkeypatch`, which undoes itself). A leaked fake makes later tests pass or fail by order.
- **No test-mode branches.** `if (process.env.NODE_ENV === "test")` in production code is not a seam; it is a second program that only tests run.
- **One seam per dependency.** Do not grow it into an options bag of every collaborator "while you are there".
