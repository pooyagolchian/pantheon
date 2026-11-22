---
name: backend-service-checklist
description: Production-readiness checklist for backend services and APIs, with exact defaults for what usually gets missed — timeouts and deadline propagation, retries with full jitter, idempotency keys, the outbox pattern, deduplicating consumers, keyset pagination, rate limiting, backpressure, circuit breakers, optimistic locking, startup config validation, health probes, graceful shutdown. Use when building or reviewing an API endpoint, microservice, background worker, cron job, queue consumer or webhook handler, when integrating a third-party API or wiring up an HTTP client or SDK, or when asked to "make this production ready", "harden this service", "add retries" or "add a timeout to this call".
---

# Backend service checklist

The defaults below are starting points: tune them against the dependency's measured p99, but never ship without a value. Go through every section that applies to the change and say which items you checked.

## Non-negotiables

1. **Every outbound call has a timeout**, and it never exceeds the caller's remaining deadline. Library defaults are infinite or minutes long.
2. **Retry only what is safe to repeat**, at exactly one layer, with jittered backoff and a cap on attempts and time.
3. **Non-idempotent writes take an idempotency key**; every consumer assumes at-least-once delivery and dedupes.
4. **Every queue, pool and list is bounded** — page size, in-flight work, buffered messages. Unbounded means "fails at the worst moment".
5. **Races are settled by the database** (unique constraint, version column), never by a check followed by a write.
6. **Fail fast at startup, degrade gracefully at runtime, drain on shutdown.**

## Outbound calls: timeouts and deadlines

- [ ] **Connect 2s, total 10s per attempt** for third-party APIs; for in-cluster calls, total = the dependency's p99.9 plus a margin. Set both explicitly; a read timeout alone is not a total.
- [ ] **Accept an inbound deadline and propagate the remainder.** Each hop sends `remaining - ~50ms` downstream; a call with no budget left fails immediately instead of starting. Propagate a relative duration (gRPC deadlines, or one agreed header carrying milliseconds), not an absolute timestamp — clocks skew.
- [ ] **The inbound deadline is shorter than the proxy/load balancer timeout in front of you**, so you stop work before the client has already given up.
- [ ] **Databases too:** a `statement_timeout` (5s is a sane request-path default) and a pool-acquire timeout. Size pools so `pool max × instance count` stays below the database's `max_connections`, with headroom for migrations and admin sessions (more in `performance-optimization`, if installed).
- [ ] **Cancellation flows downstream**: when the inbound request is aborted or times out, abort its outbound calls and queries.

## Retries

- [ ] **Only idempotent or safe operations** (GET, PUT, DELETE, or a POST carrying an idempotency key). A timeout on a non-idempotent call is an unknown outcome, not a failure.
- [ ] **Retry on:** connection errors, `408`, `429`, `500`, `502`, `503`, `504`, and `409` when the request carries an `Idempotency-Key` (the original is still in flight). **Never** on other 4xx — the request is wrong and will stay wrong.
- [ ] **A keyed POST whose retries run out has an unknown outcome**: record it as pending and resolve it later (re-send with the same key, or query the provider). Never report it as failed — the charge may have gone through.
- [ ] **3 attempts total, full jitter:** sleep `random(0, min(cap, base * 2^attempt))` with base 100ms, cap 2s. Without jitter, every client retries in lockstep and re-creates the spike.
- [ ] **Stop when the deadline would be exceeded**, whatever the attempt count.
- [ ] **Honour `Retry-After`** (seconds or HTTP-date). If it exceeds the remaining deadline, fail now instead of sleeping.
- [ ] **Retry budget:** retries stay under 10% of requests per client; past that, stop retrying and fail fast. This is what keeps retries from amplifying an outage.
- [ ] **One layer only** — the client closest to the dependency. Three layers of 3 attempts is 27 calls per user request. Check whether the SDK already retries before wrapping it.

## Idempotency and delivery

- [ ] **Idempotency keys** on non-idempotent POSTs: the client generates the key once per intent; the server claims it with a unique insert, stores state + request hash, replays the stored response on repeats, and answers `409` while the original is in flight and `422` for the same key with a different body. Keep keys at least 24h and longer than the longest redelivery path (DLQ replay included). More in `api-and-interface-design`, if installed.
- [ ] **At-least-once consumers dedupe**: record the message ID in a processed table in the *same transaction* as the effect; ack only after commit.
- [ ] **Visibility timeout / ack deadline > the maximum processing time**, or the message is redelivered while you are still working on it.
- [ ] **Poison messages go to a DLQ** after 5 attempts instead of blocking the partition or looping forever.
- [ ] **DB write + message publish = outbox.** Insert the event row in the same transaction as the state change; a relay leases a batch in a short transaction, publishes outside it, then marks the rows sent. Never publish inside or after the transaction directly — one side will eventually happen without the other.
- [ ] **Inbound webhooks:** verify the signature over the raw body with a constant-time compare, reject timestamps older than 5 minutes, return `2xx` fast and process asynchronously, dedupe on the provider's event ID, and tolerate out-of-order delivery (compare versions or refetch current state).

## Pagination

- [ ] **Keyset (cursor) pagination for large or changing sets**, not offset: `WHERE (created_at, id) < ($1, $2) ORDER BY created_at DESC, id DESC LIMIT $3`. Offset gets slower with depth and skips or repeats rows when data changes. If `api-and-interface-design` is installed, this overrides its offset example for those cases.
- [ ] **Stable sort with a unique tiebreaker** (the primary key), and a composite index that matches it.
- [ ] **Opaque cursor** (base64 of the last row's sort keys), so clients cannot construct or depend on it.
- [ ] **Default 50, max 100, clamped server-side** whatever the client asks for. No exact total count by default — `COUNT(*)` on a large table costs as much as the scan.

## Load: rate limits, backpressure, circuit breaking

- [ ] **Rate-limit per principal** (API key or user, not only IP) with a token bucket; reply `429` with `Retry-After`. Back the limiter with Redis or the database once more than one instance serves traffic — in-memory counters become `limit × instances`. Limit auth endpoints far tighter (about 10 attempts per 15 minutes per account). More in `security-and-hardening`, if installed.
- [ ] **Bounded work everywhere**: cap in-flight requests per dependency (bulkhead), queue lengths and buffer sizes. When full, shed load with `503` + `Retry-After` instead of queueing — a request that waits past its deadline is wasted work.
- [ ] **Circuit breaker per dependency**: open at ≥50% failures over a rolling window of ≥20 calls, stay open 30s, then half-open and let a single probe through. Count timeouts and 5xx as failures, not 4xx. While open, fail fast or serve a fallback.

## Data and concurrency

- [ ] **Transactions scoped tight**: no network calls, file I/O or user waits inside one. Locks held across an HTTP call become an outage when that call slows.
- [ ] **Optimistic locking for read-modify-write**: a `version` column, `UPDATE ... SET version = version + 1 WHERE id = $1 AND version = $2`; 0 rows updated → `409` (or re-read and retry inside the operation).
- [ ] **Unique constraints over check-then-insert**: `INSERT ... ON CONFLICT` and handle the violation. A `SELECT` then `INSERT` lets two requests both win.
- [ ] **Schema changes are expand/contract**, one deploy per step: add the new column or table → write both → backfill in batches → switch reads → stop writing the old → drop it. Run DDL with a short `lock_timeout` (5s) so a blocked `ALTER` fails instead of queueing every query behind it, and build indexes with `CREATE INDEX CONCURRENTLY`. More in `deprecation-and-migration` and `supabase-postgres-best-practices`, if installed.

## Errors

- [ ] **Bugs always throw.** At an inbound boundary (HTTP handler, queue consumer, CLI entry), parse failures and expected domain errors may be thrown as typed errors to one translator that maps them to the response (400/404/409); inside the domain, functions whose callers branch on the outcome return a Result/union instead of throwing.

## Lifecycle

- [ ] **Config from env, parsed and validated at startup** into a typed object; on any missing or invalid value, exit non-zero naming the variable (never its value). Nothing else reads `process.env` / `os.environ`.
- [ ] **Liveness = the process is not wedged** (event loop responds); it checks no dependency. **Readiness = this instance can serve**; it checks its own critical dependencies with cached, bounded probes (refresh every 5–10s, 1s timeout).
- [ ] **Health checks never fan out** to other services' health endpoints: one slow dependency then marks the whole fleet unhealthy and restarts it.
- [ ] **Graceful shutdown on SIGTERM**: fail readiness → wait ~5s for the load balancer to deregister → stop accepting → drain in-flight requests and stop consuming → close pools → exit. Hard-stop safely below the platform grace period (Kubernetes defaults to 30s; aim to finish by 25s).
- [ ] **Workers finish or release** the current message on shutdown (nack / return to queue), never drop it.

## Time and IDs

- [ ] **UTC everywhere**: `timestamptz` columns, ISO 8601 with `Z` on the wire, local time only at display.
- [ ] **Monotonic clocks for durations and timeouts** (`performance.now()`, `time.monotonic()`); wall clock jumps with NTP.
- [ ] **No sequential IDs where enumeration matters** (public URLs, invoices, users): use random IDs (UUIDv4, or UUIDv7 when leaking creation time is acceptable — it embeds a millisecond timestamp). Unguessable IDs do not replace authorization checks.

## Gotchas

- **Library defaults are not timeouts.** Python `requests` never times out unless told to, and its read timeout is the gap between bytes, not a total. `axios` defaults to `timeout: 0` (none). Node `fetch` (undici) has no total deadline and waits up to 300s each for headers and between body chunks. Go `http.Client{}` has zero timeout (none). `httpx` defaults to 5s per phase, still not a total.
- **A client timeout does not stop the server.** Without cancellation and deadline propagation, the downstream keeps working on a request nobody will read.
- **SDKs retry silently** (AWS SDKs and many vendor SDKs retry by default). Wrapping them in your own retry stacks the layers.
- **Kubernetes sends SIGTERM while endpoints are still being removed**; closing the listener immediately drops requests that are already routed to you. Hence the deregistration wait.
- **PID 1 in a container ignores SIGTERM** unless the process handles it; a shell-form `CMD` never forwards it. Use exec-form `CMD` or an init such as `tini`.
- **`Date.now()` deltas can go negative** after a clock adjustment; timeouts computed from them misfire.
- **A DB-checking liveness probe** turns a 10-second database blip into a fleet-wide restart.
- **Outbox relays are at-least-once too**; consumers still dedupe.

## References

- Read [references/resilience.md](references/resilience.md) when writing an outbound call: timeout and deadline propagation, full-jitter retry with `Retry-After`, keyed POSTs and unknown outcomes, retry budget, circuit breaker, bounded concurrency (TypeScript and Python).
- Read [references/data-and-lifecycle.md](references/data-and-lifecycle.md) when writing a list endpoint, a consumer, a webhook handler or service bootstrap: error policy and translator, keyset pagination, optimistic locking, outbox, consumer dedupe, webhook verification, config validation, health endpoints, graceful shutdown.
- Related skills, if installed: `api-and-interface-design` (contracts, idempotency keys), `observability-and-instrumentation` (logs, metrics, traces), `security-and-hardening`, `performance-optimization`, `deprecation-and-migration`, `supabase-postgres-best-practices`.
