# Data and lifecycle patterns

Short shapes in Postgres SQL, TypeScript (Node 20+) and Python 3.11+. `db.query` / `tx.query` stand for the project's driver (`pg`-style: returns `rows` and `rowCount`).

## Contents

- Error policy
- Keyset pagination
- Optimistic locking
- Unique constraint instead of check-then-insert
- Transactional outbox
- Deduplicating consumer
- Webhook verification
- Config validated at startup
- Health endpoints
- Graceful shutdown

## Error policy

Bugs always throw. At an inbound boundary (HTTP handler, queue consumer, CLI entry), parse failures and expected domain errors may be thrown as typed errors to one translator that maps them to the response (400/404/409); inside the domain, functions whose callers branch on the outcome return a Result/union instead of throwing.

```ts
export class HttpError extends Error {
  constructor(readonly status: 400 | 404 | 409 | 412 | 422, readonly code: string, message: string) { super(message); }
}

// The one translator, registered once at the boundary. Anything that is not an HttpError is a bug: log it, answer 500.
export function toResponse(err: unknown): { status: number; body: unknown } {
  if (err instanceof HttpError) return { status: err.status, body: { error: { code: err.code, message: err.message } } };
  log.error({ err }, 'unhandled error');
  return { status: 500, body: { error: { code: 'INTERNAL', message: 'internal error' } } };
}
```

## Keyset pagination

```sql
CREATE INDEX orders_tenant_created_id_idx ON orders (tenant_id, created_at DESC, id DESC);

SELECT id, total,
       to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS created_at_cursor
FROM orders
WHERE tenant_id = $1
  AND (created_at, id) < ($2::timestamptz, $3)   -- omit on the first page
ORDER BY created_at DESC, id DESC
LIMIT $4;                                        -- page size + 1: the extra row means "there is a next page"
```

```ts
const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 100); // default 50, clamp to 100

const encodeCursor = (ts: string, id: string) => Buffer.from(JSON.stringify([ts, id])).toString('base64url');

const CURSOR_TS = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Boundary parse: validate everything the query will cast, so a forged cursor is a 400, never a 500 from the database.
function decodeCursor(c: string): [string, string] {
  try {
    const v = JSON.parse(Buffer.from(c, 'base64url').toString('utf8'));
    if (Array.isArray(v) && v.length === 2) {
      const [ts, id] = v;
      const real = typeof ts === 'string' && CURSOR_TS.test(ts)
        && new Date(ts).toISOString().slice(0, 19) === ts.slice(0, 19); // rejects 2026-02-30 and friends
      if (real && typeof id === 'string' && UUID.test(id)) return [ts, id];
    }
  } catch {}
  throw new HttpError(400, 'INVALID_CURSOR', 'invalid cursor');
}
```

- Row-value comparison `(a, b) < (x, y)` only works when every sort column has the same direction.
- Carry the timestamp as text formatted by the database: Postgres stores microseconds, a JS `Date` keeps milliseconds, and a truncated cursor skips or repeats rows.

## Optimistic locking

```sql
UPDATE accounts
SET balance = $3, version = version + 1, updated_at = now()
WHERE id = $1 AND version = $2;
```

```ts
// Domain: the caller branches on the outcome, so return it.
type UpdateResult = { ok: true } | { ok: false; reason: 'stale' };

async function updateBalance(id: string, expectedVersion: number, newBalance: string): Promise<UpdateResult> {
  const { rowCount } = await db.query(sql, [id, expectedVersion, newBalance]);
  return rowCount === 0 ? { ok: false, reason: 'stale' } : { ok: true };
}

// Boundary (handler): map the outcome to the response.
const r = await updateBalance(id, body.version, body.balance);
if (!r.ok) throw new HttpError(409, 'STALE_VERSION', 'resource changed; re-read and reapply');
```

Return `version` with the resource (or as an `ETag`; on an `If-Match` mismatch answer `412`).

## Unique constraint instead of check-then-insert

```sql
ALTER TABLE memberships ADD CONSTRAINT memberships_org_user_key UNIQUE (org_id, user_id);

INSERT INTO memberships (org_id, user_id, role) VALUES ($1, $2, $3)
ON CONFLICT (org_id, user_id) DO NOTHING
RETURNING id;            -- no row back = it already existed
```

Without `ON CONFLICT`, catch SQLSTATE `23505` (unique_violation) in the data layer and return a `conflict` result; the handler maps it to `409`. Any other database error is a bug and keeps propagating.

## Transactional outbox

```sql
CREATE TABLE outbox (
  id           uuid PRIMARY KEY,          -- becomes the message ID consumers dedupe on
  topic        text NOT NULL,
  payload      jsonb NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  claimed_until timestamptz,              -- relay lease
  published_at  timestamptz
);
CREATE INDEX outbox_unpublished_idx ON outbox (created_at, id) WHERE published_at IS NULL;

-- the business write and the event commit together or not at all
BEGIN;
UPDATE orders SET status = 'paid' WHERE id = $1;
INSERT INTO outbox (id, topic, payload) VALUES ($2, 'order.paid', $3);
COMMIT;

-- relay loop (any number of workers), step 1: lease a batch; this statement is its own short transaction
UPDATE outbox SET claimed_until = now() + interval '30 seconds'
WHERE id IN (
  SELECT id FROM outbox
  WHERE published_at IS NULL AND (claimed_until IS NULL OR claimed_until < now())
  ORDER BY created_at, id
  LIMIT 100
  FOR UPDATE SKIP LOCKED
)
RETURNING id, topic, payload;

-- step 2: publish each row with a short timeout, outside any transaction (no row locks held across the network)

-- step 3: mark what was published
UPDATE outbox SET published_at = now() WHERE id = ANY($1);
```

- A crash after publishing but before step 3 lets the lease expire and another worker republishes the rows; consumers dedupe on `outbox.id`, so that is safe.
- The lease (30s) must exceed the time to publish one batch; shrink the batch rather than lengthen the lease.
- Concurrent workers give up global ordering. If per-entity order matters, run one relay per partition key.
- Delete published rows after a retention window (7 days) so the table stays small.

## Deduplicating consumer

```sql
CREATE TABLE processed_messages (
  message_id   text PRIMARY KEY,
  processed_at timestamptz NOT NULL DEFAULT now()
);
```

```ts
async function handle(msg: { id: string; body: OrderPaid; ack(): Promise<void> }) {
  await db.transaction(async (tx) => {
    const { rowCount } = await tx.query(
      'INSERT INTO processed_messages (message_id) VALUES ($1) ON CONFLICT DO NOTHING',
      [msg.id],
    );
    if (rowCount === 0) return;       // duplicate: already applied
    await applyEffect(tx, msg.body);  // same transaction as the marker
  });
  await msg.ack();                    // only after commit
}
```

Effects outside the database (email, payment API) cannot join the transaction: send them with an idempotency key derived from `msg.id`.

## Webhook verification

Use the provider's SDK verifier when it has one. Otherwise, for an HMAC-SHA256 over `timestamp.body`:

```ts
import { createHmac, timingSafeEqual } from 'node:crypto';

export function verifyWebhook(rawBody: Buffer, timestamp: string, signature: string, secret: string) {
  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(Date.now() / 1000 - ts) > 300) return false; // 5-minute replay window
  const expected = createHmac('sha256', secret).update(`${timestamp}.`).update(rawBody).digest();
  const given = Buffer.from(signature, 'hex');
  return given.length === expected.length && timingSafeEqual(given, expected);
}
```

```python
import hashlib
import hmac
import time


def verify_webhook(raw_body: bytes, timestamp: str, signature: str, secret: bytes) -> bool:
    try:
        ts = int(timestamp)
    except ValueError:
        return False
    if abs(time.time() - ts) > 300:
        return False
    expected = hmac.new(secret, timestamp.encode() + b"." + raw_body, hashlib.sha256).hexdigest().encode()
    return hmac.compare_digest(expected, signature.encode())  # bytes: str raises TypeError on non-ASCII input
```

Then: insert the event ID with `ON CONFLICT DO NOTHING`, enqueue the work, return `200`. Verify against the raw bytes; a body-parsing middleware that runs first breaks the signature.

## Config validated at startup

```ts
import { z } from 'zod';

const Env = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: z.string().min(1),
  PAYMENTS_API_KEY: z.string().min(1),
  PAYMENTS_TIMEOUT_MS: z.coerce.number().int().positive().default(10_000),
  // not z.coerce.boolean(): it turns the string "false" into true
  FEATURE_X: z.enum(['true', 'false']).default('false').transform((v) => v === 'true'),
});

const parsed = Env.safeParse(process.env);
if (!parsed.success) {
  for (const i of parsed.error.issues) console.error(`config: ${i.path.join('.')}: ${i.message}`); // names, never values
  process.exit(1);
}
export const config = Object.freeze(parsed.data);
```

```python
import sys

from pydantic import Field, SecretStr, ValidationError
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    payments_api_key: SecretStr          # masked in repr and logs
    payments_timeout_s: float = Field(10.0, gt=0)
    port: int = Field(8000, ge=1, le=65535)


try:
    settings = Settings()
except ValidationError as e:
    for err in e.errors(include_input=False):  # never echo values
        print(f"config: {'.'.join(map(str, err['loc']))}: {err['msg']}", file=sys.stderr)
    sys.exit(1)
```

## Health endpoints

```ts
let ready = false; // true after startup completes, false again on SIGTERM
let dbOk = false;

const withTimeout = <T>(p: Promise<T>, ms: number) =>
  Promise.race([p, new Promise<never>((_, rej) => setTimeout(() => rej(new Error('timeout')), ms))]);

// Probe on a timer and serve the cached result: probe traffic stays constant however often the platform asks.
setInterval(async () => {
  try { await withTimeout(db.query('SELECT 1'), 1_000); dbOk = true; } catch { dbOk = false; }
}, 5_000).unref();

app.get('/livez', (_req, res) => res.status(200).send('ok')); // process-local only
app.get('/readyz', (_req, res) => res.status(ready && dbOk ? 200 : 503).end());
```

If the service can do useful work without a shared dependency, leave that dependency out of readiness: when it fails, every instance goes unready at once and the load balancer has nothing to route to.

## Graceful shutdown

```ts
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const server = app.listen(config.PORT, () => { ready = true; });

process.once('SIGTERM', async () => {
  ready = false;                                            // 1. fail readiness
  setTimeout(() => process.exit(1), 25_000).unref();        //    hard stop, below the 30s grace period
  await sleep(5_000);                                       // 2. let the load balancer deregister this instance
  const closed = new Promise((r) => server.close(r));       // 3. stop accepting
  server.closeIdleConnections();                            //    drop idle keep-alive sockets now
  await Promise.all([closed, consumer.stop()]);             // 4. drain requests; finish or nack in-flight messages
  await db.end();                                           // 5. close pools
  process.exit(0);
});
```

```python
import asyncio
import logging
import signal

log = logging.getLogger(__name__)


async def main() -> None:
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)

    while not stop.is_set():
        msg = await queue.receive(wait_seconds=5)  # short poll so a stop is noticed quickly
        if msg is None:
            continue
        try:
            async with asyncio.timeout(20):        # one message must fit inside the grace period
                await handle(msg)                  # dedupes, see above
            await msg.ack()
        except Exception:
            log.exception("message %s failed", msg.id)
            await msg.nack()                       # back to the queue; DLQ after max receives
    await db_pool.close()
```

For HTTP in Python, the server owns the drain (`uvicorn --timeout-graceful-shutdown 20`). Do the deregistration wait in a Kubernetes `preStop` hook that sleeps 5s.
