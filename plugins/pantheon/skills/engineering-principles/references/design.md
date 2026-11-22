# Design heuristics for functions and modules

Contents
- Deep modules, one-adapter seams (short form)
- Rule of three before abstracting
- Data over flags; no boolean parameters
- Pure core, imperative shell
- Names that carry intent and units
- Comments that say why

## Deep modules, one-adapter seams (short form)

- A module earns its interface when it hides much more than it exposes. A wrapper whose methods map one-to-one onto the thing it wraps is cost without benefit: inline it.
- An interface with exactly one implementation and no test double is a hypothetical seam. Add the interface when the second adapter (or the test that needs a fake) arrives.
- Deletion test: if deleting a module would only move its few lines back into its single caller, it should not exist.

The `codebase-design` skill, if installed, covers these at length.

## Rule of three before abstracting

Two similar blocks are a coincidence; three show the real axis of variation. Abstracting at two usually picks the wrong parameters and every later case adds another option.

```ts
// before: a "reusable" helper built for one caller
function processItems<T, R>(items: T[], opts: {
  filter?: (t: T) => boolean; map?: (t: T) => R; sort?: (a: R, b: R) => number;
  dedupe?: boolean; limit?: number;
}): R[] { /* 30 lines of branches */ }

const names = processItems(users, { filter: u => u.active, map: u => u.name, limit: 10 });

// after: say what the one caller needs
const names = users.filter(u => u.active).map(u => u.name).slice(0, 10);
```

Duplication is cheaper than the wrong abstraction. When you do extract, extract the thing the three cases share, named for the domain, not a generic `utils/process.ts`.

## Data over flags; no boolean parameters

A boolean parameter means the function does two things, and the call site `render(doc, true, false)` is unreadable.

```python
# before
def export(report, as_csv: bool, include_header: bool = True): ...
export(r, True, False)

# after: two functions, or an explicit option the call site names
def export_csv(report, *, header: bool = True): ...
def export_json(report): ...
export_csv(r, header=False)
```

When behaviour varies by kind, put the variation in a table instead of branching in five places:

```ts
// before: plan logic scattered across if/else in billing, limits and UI
if (plan === "pro") { seats = 10; price = 2900; } else if (plan === "team") { /* ... */ }

// after: one table, read everywhere
const PLANS = {
  free: { seats: 1,  priceCents: 0 },
  pro:  { seats: 10, priceCents: 2900 },
  team: { seats: 50, priceCents: 9900 },
} as const satisfies Record<Plan, { seats: number; priceCents: number }>;
```

## Pure core, imperative shell

Keep decisions in pure functions (inputs in, values out, no I/O, no clock, no randomness) and push effects to a thin outer layer. The core then needs no mocks to test, and the shell is too simple to need many tests.

```ts
// before: decision tangled with I/O and the clock
async function maybeSendReminder(userId: string) {
  const user = await db.users.get(userId);
  if (Date.now() - user.lastSeen.getTime() > 7 * 86_400_000 && !user.optedOut) {
    await mailer.send(user.email, "We miss you");
  }
}

// after
function needsReminder(user: User, now: Date): boolean {
  const WEEK_MS = 7 * 86_400_000;
  return !user.optedOut && now.getTime() - user.lastSeen.getTime() > WEEK_MS;
}

async function sendReminder(userId: string, now = new Date()) {
  const user = await db.users.get(userId);
  if (needsReminder(user, now)) await mailer.send(user.email, "We miss you");
}
```

## Names that carry intent and units

- Put the unit in the name whenever the type does not: `timeoutMs`, `sizeBytes`, `priceCents`, `ratePerSecond`. `timeout = 30` is a bug waiting for someone to assume seconds.
- Name by role, not type: `pendingInvoices`, not `list` or `data`; `retryDelayMs`, not `num`.
- Booleans read as predicates: `isExpired`, `hasAccess`, `shouldRetry`.
- A function name says what it returns or does, at the level the caller cares about: `findActiveSubscription`, not `getData` or `handleStuff`.
- Rename when the meaning changes. A name that lies is worse than a vague one.

## Comments that say why

Code says what; comments say why it is this way, what constraint is invisible, or what would break if changed.

```python
# before: narrates the code
# loop over users and check if active
for u in users:
    if u.active: ...

# after: the non-obvious reason
# Stripe sends duplicate webhooks within ~1s; dedupe on event id before charging.
if seen_event(event.id):
    return
```

- Delete comments that restate the line below.
- When you change code, update or delete the comment next to it in the same diff. A stale comment is a false instruction to the next reader.
- No commented-out code, no `// removed X` or `// changed for ticket 123` notes: that is what version control is for.
- `TODO` only with a concrete condition: `TODO(remove after v2 clients are gone)`.
