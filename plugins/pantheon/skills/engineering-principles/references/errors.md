# Errors: the fail-loud contract

Contents
- Where a catch is allowed
- Swallowing in its three disguises
- Wrapping with context, keeping the cause
- Silent defaults on required data
- Expected vs unexpected errors
- One error shape per boundary
- Retries

## Where a catch is allowed

A `catch` / `except` must do one of four things, or it should not exist:

1. **Recover**: take a real alternative path (cache miss, fall back to a replica, return a domain "not found").
2. **Add context and rethrow**: say which input or step failed, keep the original as the cause.
3. **Translate at a boundary**: turn an internal error into the boundary's one error shape (HTTP response, CLI exit code, queue nack).
4. **Clean up and rethrow**: release a resource. Prefer `finally` / `with` / `using` so no catch is needed.

Everything else lets the error propagate to the top-level handler, which logs it once with the stack.

## Swallowing in its three disguises

**Return null on failure.** The caller can't tell "no user" from "database down", and the real error is gone.

```ts
// before
async function getUser(id: string): Promise<User | null> {
  try {
    return await db.users.findById(id);
  } catch {
    return null;
  }
}

// after: absence is a value, failure is an error
async function getUser(id: string): Promise<User | undefined> {
  return db.users.findById(id); // returns undefined if absent, throws if the query fails
}
```

**Catch, log, continue.** The log line looks like handling, but the program runs on with half-done state.

```python
# before
for order in orders:
    try:
        charge(order)
    except Exception as e:
        logger.error(f"charge failed: {e}")
mark_batch_complete(batch_id)   # runs even if every charge failed

# after: decide what partial failure means and make it visible
failed = []
for order in orders:
    try:
        charge(order)
    except PaymentDeclined as e:        # expected, per-order, recoverable
        failed.append((order.id, e.reason))
if failed:
    mark_batch_partial(batch_id, failed)
else:
    mark_batch_complete(batch_id)
# anything other than PaymentDeclined propagates and stops the batch
```

**Log and rethrow.** Each layer logs, so one failure appears five times in the logs with no clear origin. Log at the place that handles the error, not on the way up.

```ts
// before
} catch (e) {
  logger.error("save failed", e);
  throw e;
}

// after: add context and let the top level log once
} catch (e) {
  throw new Error(`saving invoice ${invoice.id}`, { cause: e });
}
```

## Wrapping with context, keeping the cause

The wrapper message says what you were doing and with which input. The cause keeps the stack and the root message.

```python
# before: cause lost, message says nothing
try:
    cfg = json.loads(path.read_text())
except Exception:
    raise ConfigError("invalid config")

# after
try:
    cfg = json.loads(path.read_text())
except json.JSONDecodeError as e:
    raise ConfigError(f"{path}: invalid JSON at line {e.lineno}") from e
```

TypeScript: `new Error(msg, { cause: e })`. Go: `fmt.Errorf("loading %s: %w", path, err)`. Never `throw new Error(String(e))`, which drops the stack.

## Silent defaults on required data

`?? 0`, `|| ""`, `.get(key, default)` and `or []` turn missing data into plausible-looking wrong data. That is worse than a crash because it travels.

```ts
// before: a missing price becomes a free item
const total = items.reduce((sum, i) => sum + (i.priceCents ?? 0) * i.qty, 0);

// after: price is required, so its absence is a parse error at the boundary
const Item = z.object({ priceCents: z.number().int().nonnegative(), qty: z.number().int().positive() });
const items = z.array(Item).parse(body.items); // at the boundary: throws with the bad field path, translator maps it to 400
const total = items.reduce((sum, i) => sum + i.priceCents * i.qty, 0);
```

A default is fine when it is the documented meaning of "absent" (an optional page size defaulting to 50). Write it where the config or input is parsed, once, not at each read site.

## Expected vs unexpected errors

The policy:

> Bugs always throw. At an inbound boundary (HTTP handler, queue consumer, CLI entry), parse failures and expected domain errors may be thrown as typed errors to one translator that maps them to the response (400/404/409); inside the domain, functions whose callers branch on the outcome return a Result/union instead of throwing.

- **Unexpected errors** are bugs or broken infrastructure: null dereference, broken invariant, connection refused. Nobody can branch on them usefully. Let them throw, at every layer.
- **Expected errors** are part of the contract: validation failed, not found, declined, conflict. Each gets a stable code. Where they live depends on the layer:
  - *Inside the domain*, a function whose caller branches on the outcome returns a union. The caller sees every case in the signature and cannot forget one.
  - *At the inbound boundary*, the handler may throw a typed error (`ValidationError`, `NotFoundError`, `ConflictError`) for the one translator to map to 400/404/409. That keeps handlers free of response-building code.

```ts
// domain: the caller branches, so the outcome is a value
type TransferResult =
  | { ok: true; transferId: string }
  | { ok: false; reason: "insufficient_funds" | "account_frozen" };

async function transfer(from: Account, to: Account, cents: number): Promise<TransferResult> {
  if (from.frozen) return { ok: false, reason: "account_frozen" };
  if (from.balanceCents < cents) return { ok: false, reason: "insufficient_funds" };
  const id = await ledger.post(from.id, to.id, cents); // DB failure is not an outcome: it throws
  return { ok: true, transferId: id };
}

// inbound boundary: parse failures and domain errors become typed throws for the translator
app.post("/transfers", async (req, res) => {
  const body = TransferRequest.parse(req.body);          // throws ValidationError -> 400
  const [from, to] = await Promise.all([accounts.find(body.fromId), accounts.find(body.toId)]);
  if (!from || !to) throw new NotFoundError("account", !from ? body.fromId : body.toId); // -> 404
  const result = await transfer(from, to, body.cents);
  if (!result.ok) throw new ConflictError(result.reason);    // -> 409
  res.status(201).json({ id: result.transferId });
});
```

Mixing the two is the common bug: wrapping a bug in a `Result` makes callers "handle" it, while throwing a domain outcome from deep inside the domain forces every caller into try/catch for control flow.

Assertions for impossible states are welcome, but they must crash, not return a default:

```ts
default: {
  const unreachable: never = status;
  throw new Error(`unhandled status ${unreachable}`);
}
```

## One error shape per boundary

Each boundary (HTTP API, CLI, job runner, library public API) has exactly one translation point and one output shape.

- HTTP: one error middleware maps the typed errors (`ValidationError`, `NotFoundError`, `ConflictError`) to 400/404/409 and a fixed body, e.g. `{ "error": { "code": "...", "message": "..." } }`. Unexpected errors become a generic 500 with a request id; the details go to logs, not the client.
- CLI: message on stderr, non-zero exit code, no stack trace unless a debug flag is set.
- Library: a small, documented set of exported error types. Do not leak the HTTP client's or ORM's errors through your API.

Handlers do not build error responses themselves; they throw the typed errors and the translator maps them.

## Retries

Retry only errors that are transient, on operations that are idempotent. Never retry validation errors, auth failures, "not found" or bugs; they fail the same way each time and the retries hide the root cause. Cap attempts and, when giving up, surface the last error with the attempt count, not a generic "retries exhausted". The exact retryable status codes, backoff and jitter defaults are in the `backend-service-checklist` skill.
