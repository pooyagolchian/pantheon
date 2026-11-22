# The portfolio for a TS or Python web service

Contents
- Proportions
- What each layer must prove
- Tooling per layer
- Real database isolation
- CI layout and quarantine
- Signs the portfolio is wrong

## Proportions

For a typical service with 10-30 endpoints and one Postgres database. Counts are a sanity check, not a target.

| Layer | Share of tests | Typical count | Runtime budget |
|---|---|---|---|
| Static: types, lint, schema checks | n/a | n/a | under 1 min |
| Unit: pure logic; services with doubled external ports | ~30% | 50-150 | under 10 s |
| Integration: repos, migrations and DB-backed service tests against the real engine | ~20% | 20-60 | under 2 min |
| Handler: endpoints in-process, real router and DB | ~40-45% | 4-8 per endpoint | under 3 min |
| Adapter: third-party wrappers against recordings | ~5% | 3-6 per adapter | under 10 s |
| End-to-end journeys in a browser | under 5% | 3-10 | under 10 min |
| Consumer-driven contracts | only with 2+ deployables | one suite per consumer-provider pair | under 1 min |

A CLI, library or algorithm-heavy codebase flips this: most tests are unit, with a thin integration layer.

## What each layer must prove

- **Unit**: every branch of each domain rule, plus the edge values that rule cares about (zero, empty, one, maximum, just over a limit, a past or future `now`). Nothing about HTTP, SQL or serialization.
- **Repo integration**: every query you wrote, against the same engine and major version as production: filters, ordering, pagination cursors, unique and foreign-key violations surfacing as your typed error, transactions that must roll back together, and migrations applying cleanly to an empty database.
- **Handler**: for every endpoint, the happy path once, then each distinct outcome once: 401 and 403, 400 or 422 with the field path, 404, 409, and the stable error body shape. Also request parsing (unknown fields, wrong types) and response serialization (dates, money, omitted nulls).
- **Adapter**: the request you send (method, path, units, idempotency key), parsing of each recorded response, translation of each provider error into your error, and behaviour on timeout.
- **Contract**: the fields and status codes the consumer actually reads, verified against the provider in the provider's own CI.
- **End-to-end**: the journeys that make money or lose data if broken (sign up, log in, the core purchase or create flow, one permission boundary). Also run as a smoke test after each deploy.

A rule tested at unit level is not re-tested at handler level; the handler test proves the wiring and the translation, once.

## Tooling per layer

| Layer | TypeScript | Python |
|---|---|---|
| Unit | Vitest | pytest |
| Integration DB | `@testcontainers/postgresql` | `testcontainers[postgres]` |
| Handler | Fastify `app.inject`, supertest for Express, `app.request` for Hono | FastAPI or Starlette `TestClient`, Flask `test_client`, Django `Client` |
| Adapter | injected `fetch` or MSW with committed recordings | `httpx.MockTransport`, `respx`, or `vcrpy` cassettes |
| Contract | Pact JS | pact-python |
| End-to-end | Playwright | Playwright for Python |

## Real database isolation

- **One container per test run**, started in a global setup, migrated once. Starting one per test file multiplies runtime for no isolation gain.
- **Per-test isolation by transaction rollback**: open a transaction in a fixture, hand that connection to the code under test, roll back after. Fast and order-independent.
- **Use truncation instead** for tests where the code under test commits or opens its own transaction, uses deferred constraints, or runs work on another connection (outbox relays, `LISTEN/NOTIFY`, background workers). Rollback would hide exactly what they need to prove.
- **Parallel workers** each get their own database (`test_1`, `test_2`, created from a migrated template) rather than sharing tables.

Global setup sketches, from the Testcontainers docs (not run here; they need Docker):

```ts
// vitest.globalSetup.ts, registered as test.globalSetup in vitest.config.ts
import { PostgreSqlContainer, type StartedPostgreSqlContainer } from "@testcontainers/postgresql";

let pg: StartedPostgreSqlContainer;

export async function setup() {
  pg = await new PostgreSqlContainer("postgres:16-alpine").start();
  process.env.DATABASE_URL = pg.getConnectionUri();
  // run migrations here, once
}

export async function teardown() {
  await pg.stop();
}
```

```python
# tests/conftest.py
import pytest
from testcontainers.postgres import PostgresContainer


@pytest.fixture(scope="session")
def database_url():
    with PostgresContainer("postgres:16-alpine", driver=None) as pg:
        url = pg.get_connection_url()
        # run migrations here, once
        yield url
```

Pin the image to the major version production runs; a test against `postgres:latest` passes on features production does not have.

## CI layout and quarantine

| Job | Runs | Blocks merge |
|---|---|---|
| check | types, lint, unit, adapter | yes |
| integration | repo and handler tests against a container DB | yes |
| e2e | journeys against a preview deployment | yes |
| quarantine | only quarantined tests, same environment as their home job | no, but reports |

Selecting quarantined tests (these commands were run against Vitest 4 and pytest 9):

```bash
# Vitest: quarantined files are named *.quarantine.test.ts
npx vitest run --exclude '**/*.quarantine.test.ts'   # blocking jobs
npx vitest run quarantine                            # non-blocking job (filename filter)

# pytest: register the marker; --strict-markers rejects typos
pytest -m "not quarantine"     # blocking jobs
pytest -m quarantine           # non-blocking job
```

```ini
# pytest.ini
[pytest]
markers =
    integration: needs real infrastructure (database container)
    quarantine: known-flaky; runs in the non-blocking job only
addopts = --strict-markers
```

In GitHub Actions, the quarantine job sets `continue-on-error: true`; blocking jobs never set it and never use a rerun or retry option.

## Signs the portfolio is wrong

- **A bug escaped**: write the missing test at the level where the bug lived (a wrong query gets a repo integration test, not a handler test), then fix.
- **A behaviour-preserving refactor broke many tests**: they are interaction tests on internals or scaffolding that should have been deleted.
- **More lines of mock setup than of act and assert**: the unit is doing I/O it should delegate to a port, or the test belongs at handler level.
- **The blocking suite takes over 10 minutes**: look for e2e tests covering rules, per-file containers, and `sleep`-based waits, in that order.
- **Handler tests all pass while production returns 500s**: they run against fakes instead of the real DB, or bypass the middleware stack.
