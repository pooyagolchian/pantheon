# Resilience patterns for outbound calls

Minimal, dependency-free shapes (TypeScript on Node 20+, Python 3.11+ with `httpx`). Prefer the project's existing client wrapper, breaker or mesh if it has one; these show what it must do.

## Contents

- Deadline and per-call timeout
- Retry with full jitter and Retry-After
- Retrying a POST
- Retry budget
- Circuit breaker
- Bounded concurrency (bulkhead)
- Putting it together

## Deadline and per-call timeout

One deadline per inbound request, measured on the monotonic clock. Each outbound call gets `min(per-call cap, remaining - margin)` and forwards that budget as a relative duration.

```ts
export class Deadline {
  private readonly expiresAt: number;
  private constructor(expiresAt: number) { this.expiresAt = expiresAt; }
  static after(ms: number) { return new Deadline(performance.now() + ms); }
  remainingMs() { return Math.max(0, this.expiresAt - performance.now()); }
}

const DEADLINE_HEADER = 'x-request-timeout-ms'; // pick one name for all your services

// Honour the caller's budget, capped below the load balancer timeout.
export function inboundDeadline(headerValue: string | undefined, maxMs = 25_000) {
  const asked = Number(headerValue);
  return Deadline.after(Number.isFinite(asked) && asked > 0 ? Math.min(asked, maxMs) : maxMs);
}

// AbortSignal bounds the whole call (connect, headers and body); `upstream` cancels it when the inbound request dies.
export async function callWithDeadline(url: string, init: RequestInit, deadline: Deadline, upstream?: AbortSignal) {
  const budget = deadline.remainingMs() - 50;
  if (budget <= 0) throw new Error('deadline exceeded before call');
  const timeout = Math.floor(Math.min(10_000, budget)); // AbortSignal.timeout throws on non-integers
  const headers = new Headers(init.headers);
  headers.set(DEADLINE_HEADER, String(timeout));
  const signals = [AbortSignal.timeout(timeout), ...(upstream ? [upstream] : [])];
  return fetch(url, { ...init, headers, signal: AbortSignal.any(signals) });
}
```

```python
import asyncio
import time

import httpx


class Deadline:
    def __init__(self, seconds: float):
        self._expires = time.monotonic() + seconds

    def remaining(self) -> float:
        return max(0.0, self._expires - time.monotonic())


# httpx timeouts are per phase (connect, each read), so a slow-dripping body never trips them.
client = httpx.AsyncClient(timeout=httpx.Timeout(10.0, connect=2.0))


async def call_with_deadline(method: str, url: str, deadline: Deadline, **kw) -> httpx.Response:
    budget = deadline.remaining() - 0.05
    if budget <= 0:
        raise TimeoutError("deadline exceeded before call")
    timeout = min(10.0, budget)
    headers = {**kw.pop("headers", {}), "x-request-timeout-ms": str(int(timeout * 1000))}
    async with asyncio.timeout(timeout):  # the total: connect + headers + body
        return await client.request(method, url, headers=headers, **kw)
```

## Retry with full jitter and Retry-After

Use only for idempotent requests or POSTs carrying an `Idempotency-Key`. `attempt` makes exactly one call. Pass the key as an option for keyed POSTs: `409` then means "the original is still in flight" and is retried, and running out of retries raises an unknown-outcome error instead of returning a failure.

```ts
const RETRYABLE = new Set([408, 429, 500, 502, 503, 504]);
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// A keyed call ran out of retries: it may or may not have been applied. Resolve it later; never report it as failed.
export class OutcomeUnknownError extends Error {
  readonly idempotencyKey: string;
  readonly last: unknown;
  constructor(idempotencyKey: string, last: unknown) {
    super(`outcome unknown for ${idempotencyKey}`);
    this.idempotencyKey = idempotencyKey;
    this.last = last;
  }
}

function retryAfterMs(res: Response): number | undefined {
  const h = res.headers.get('retry-after');
  if (!h) return undefined;
  const secs = Number(h);
  if (Number.isFinite(secs)) return Math.max(0, secs * 1000);
  const at = Date.parse(h); // HTTP-date
  return Number.isNaN(at) ? undefined : Math.max(0, at - Date.now());
}

export async function withRetry(
  attempt: () => Promise<Response>,
  deadline: Deadline,
  budget: RetryBudget,
  { maxAttempts = 3, baseMs = 100, capMs = 2_000, idempotencyKey }:
    { maxAttempts?: number; baseMs?: number; capMs?: number; idempotencyKey?: string } = {},
): Promise<Response> {
  budget.onRequest();
  for (let i = 0; ; i++) {
    let res: Response | undefined;
    let err: unknown;
    try {
      res = await attempt();
      const inFlight = idempotencyKey !== undefined && res.status === 409; // original attempt still running
      if (!RETRYABLE.has(res.status) && !inFlight) return res;
    } catch (e) {
      if (e instanceof Error && e.name === 'AbortError') throw e; // caller cancelled: never retry
      err = e; // network error or per-attempt timeout
    }
    let wait = Math.random() * Math.min(capMs, baseMs * 2 ** i); // full jitter
    const hinted = res && retryAfterMs(res);
    if (hinted !== undefined) wait = hinted;
    if (i + 1 >= maxAttempts || wait >= deadline.remainingMs() || !budget.tryRetry()) {
      if (idempotencyKey !== undefined) throw new OutcomeUnknownError(idempotencyKey, res ?? err);
      if (res) return res;
      throw err;
    }
    await res?.body?.cancel(); // release the connection before sleeping
    await sleep(wait);
  }
}
```

```python
import random
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

RETRYABLE = {408, 429, 500, 502, 503, 504}


class OutcomeUnknown(Exception):
    """A keyed call ran out of retries: it may or may not have been applied. Resolve later; never report failure."""

    def __init__(self, idempotency_key: str, last: object):
        super().__init__(f"outcome unknown for {idempotency_key}")
        self.idempotency_key, self.last = idempotency_key, last


def retry_after_s(resp: httpx.Response) -> float | None:
    h = resp.headers.get("retry-after")
    if h is None:
        return None
    try:
        return max(0.0, float(h))
    except ValueError:
        pass
    try:
        return max(0.0, (parsedate_to_datetime(h) - datetime.now(timezone.utc)).total_seconds())
    except (TypeError, ValueError):
        return None


async def with_retry(send, deadline: Deadline, budget: "RetryBudget", max_attempts: int = 3,
                     base: float = 0.1, cap: float = 2.0, idempotency_key: str | None = None) -> httpx.Response:
    budget.on_request()
    for i in range(max_attempts):
        resp, err = None, None
        try:
            resp = await send()
            in_flight = idempotency_key is not None and resp.status_code == 409  # original still running
            if resp.status_code not in RETRYABLE and not in_flight:
                return resp
        except (httpx.TransportError, TimeoutError) as e:  # CancelledError is not caught: never retried
            err = e
        wait = random.uniform(0, min(cap, base * 2 ** i))
        if resp is not None and (hinted := retry_after_s(resp)) is not None:
            wait = hinted
        if i + 1 >= max_attempts or wait >= deadline.remaining() or not budget.try_retry():
            if idempotency_key is not None:
                raise OutcomeUnknown(idempotency_key, resp if resp is not None else err)
            if resp is not None:
                return resp
            raise err
        await asyncio.sleep(wait)
    raise AssertionError("unreachable")
```

## Retrying a POST

The key belongs to the intent, so create it once, outside the attempt: generated inside, every retry is a new charge. Derive it from an immutable ID when one exists, and persist it with the pending record so a later reconciliation re-sends the same key.

When retries run out the charge may have gone through. Record it as pending and let a reconciler re-send with the same key (the server replays the stored response) or query the provider; tell the user it is processing, never that it failed.

```ts
const key = `charge:v1:${order.id}`; // or crypto.randomUUID(), generated once per intent
try {
  const res = await withRetry(
    () => callWithDeadline(url, { method: 'POST', body, headers: { 'Idempotency-Key': key } }, deadline),
    deadline,
    budget,
    { idempotencyKey: key },
  );
  // ...handle res (2xx, or a non-retryable 4xx such as 422)
} catch (e) {
  if (!(e instanceof OutcomeUnknownError)) throw e;
  await markChargePending(order.id, key); // reconciler resolves it; respond 202 "processing"
}
```

```python
key = f"charge:v1:{order.id}"  # or str(uuid.uuid4()), generated once per intent
try:
    resp = await with_retry(
        lambda: call_with_deadline("POST", url, deadline, json=body, headers={"Idempotency-Key": key}),
        deadline,
        budget,
        idempotency_key=key,
    )
except OutcomeUnknown:
    await mark_charge_pending(order.id, key)  # reconciler resolves it; respond 202 "processing"
```

## Retry budget

One per dependency per process. Each request earns 0.1 tokens, each retry spends 1, so retries settle at about 10% of traffic and stop entirely during a sustained outage.

```ts
export class RetryBudget {
  private readonly ratio: number;
  private readonly max: number;
  private tokens: number;
  constructor(ratio = 0.1, max = 10) {
    this.ratio = ratio;
    this.max = max;
    this.tokens = max;
  }
  onRequest() { this.tokens = Math.min(this.max, this.tokens + this.ratio); }
  tryRetry() { if (this.tokens < 1) return false; this.tokens -= 1; return true; }
}
```

```python
class RetryBudget:
    def __init__(self, ratio: float = 0.1, max_tokens: float = 10.0):
        self.ratio, self.max, self.tokens = ratio, max_tokens, max_tokens

    def on_request(self) -> None:
        self.tokens = min(self.max, self.tokens + self.ratio)

    def try_retry(self) -> bool:
        if self.tokens < 1:
            return False
        self.tokens -= 1
        return True
```

## Circuit breaker

One per dependency. Opens at ≥50% failures over the last 20 calls, stays open 30s, then lets one probe through. Failures are thrown errors, so throw on 5xx and let 4xx pass; caller cancellation is not counted.

```ts
export class CircuitOpenError extends Error {}

export class CircuitBreaker {
  private window: boolean[] = []; // true = failed, last `size` calls
  private openedAt: number | null = null;
  private probing = false;
  private readonly size: number;
  private readonly threshold: number;
  private readonly openMs: number;
  constructor(size = 20, threshold = 0.5, openMs = 30_000) {
    this.size = size;
    this.threshold = threshold;
    this.openMs = openMs;
  }

  async run<T>(fn: () => Promise<T>): Promise<T> {
    if (this.openedAt !== null) {
      if (this.probing || performance.now() - this.openedAt < this.openMs) throw new CircuitOpenError('circuit open');
      this.probing = true; // half-open
    }
    try {
      const out = await fn();
      this.record(false);
      return out;
    } catch (e) {
      if (e instanceof Error && e.name === 'AbortError') {
        this.probing = false; // caller cancelled: says nothing about the dependency
        throw e;
      }
      this.record(true);
      throw e;
    }
  }

  private record(failed: boolean) {
    if (this.probing) {
      this.probing = false;
      this.openedAt = failed ? performance.now() : null;
      if (!failed) this.window = [];
      return;
    }
    this.window.push(failed);
    if (this.window.length > this.size) this.window.shift();
    const failures = this.window.filter(Boolean).length;
    if (this.window.length >= this.size && failures / this.size >= this.threshold) this.openedAt = performance.now();
  }
}
```

```python
import collections


class CircuitOpen(Exception):
    pass


class CircuitBreaker:
    def __init__(self, size: int = 20, threshold: float = 0.5, open_s: float = 30.0):
        self.size, self.threshold, self.open_s = size, threshold, open_s
        self.window: collections.deque[bool] = collections.deque(maxlen=size)  # True = failed
        self.opened_at: float | None = None
        self.probing = False

    async def run(self, fn):
        if self.opened_at is not None:
            if self.probing or time.monotonic() - self.opened_at < self.open_s:
                raise CircuitOpen()
            self.probing = True  # half-open
        try:
            out = await fn()
        except asyncio.CancelledError:
            self.probing = False  # caller cancelled: says nothing about the dependency
            raise
        except Exception:
            self._record(True)
            raise
        self._record(False)
        return out

    def _record(self, failed: bool) -> None:
        if self.probing:
            self.probing = False
            self.opened_at = time.monotonic() if failed else None
            if not failed:
                self.window.clear()
            return
        self.window.append(failed)
        if len(self.window) == self.size and sum(self.window) / self.size >= self.threshold:
            self.opened_at = time.monotonic()
```

## Bounded concurrency (bulkhead)

Cap in-flight calls per dependency and reject immediately when full; map the rejection to `503` with `Retry-After`.

```ts
export class OverloadedError extends Error {}
let inFlight = 0;
const MAX_IN_FLIGHT = 32;

export async function bulkhead<T>(fn: () => Promise<T>): Promise<T> {
  if (inFlight >= MAX_IN_FLIGHT) throw new OverloadedError('overloaded');
  inFlight++;
  try { return await fn(); } finally { inFlight--; }
}
```

```python
class Overloaded(Exception):
    pass


sem = asyncio.Semaphore(32)  # max in-flight calls to this dependency


async def bulkhead(fn):
    if sem.locked():
        raise Overloaded()  # shed instead of queueing past the deadline
    async with sem:
        return await fn()
```

## Putting it together

Bulkhead outside, breaker around the whole retried call, timeout on each attempt. Circuit-open and overloaded errors are not retried, because they never reach `withRetry`.

```ts
const res = await bulkhead(() =>
  breaker.run(async () => {
    const r = await withRetry(() => callWithDeadline(url, init, deadline, req.signal), deadline, budget);
    if (r.status >= 500) throw new Error(`upstream ${r.status}`);
    return r;
  }),
);
```
