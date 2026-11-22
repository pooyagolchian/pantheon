# Sprout and wrap: adding behaviour without editing the middle

Both put new behaviour in new, fully tested code and touch the untested body at one line or not at all. Pin the legacy code first; the pins must stay green throughout.

Contents
- Sprout function
- Sprout class
- Wrap
- Choosing

## Sprout function

Use when the new behaviour is a computation or a decision.

```ts
// before: request is "skip entries that are already posted"
export function postEntries(entries: Entry[], ledger: Ledger): void {
  for (const entry of entries) {
    // ...60 untested lines of posting logic...
    ledger.add(entry);
  }
}

// after: the decision is a new pure function with its own tests (test-first)
export function unpostedEntries(entries: Entry[], postedIds: ReadonlySet<string>): Entry[] {
  return entries.filter((entry) => !postedIds.has(entry.id));
}

export function postEntries(entries: Entry[], ledger: Ledger): void {
  for (const entry of unpostedEntries(entries, ledger.postedIds())) {   // the only changed line
    // ...60 lines unchanged...
    ledger.add(entry);
  }
}
```

```python
# after, same shape in Python
def unposted_entries(entries, posted_ids):
    return [e for e in entries if e.id not in posted_ids]

def post_entries(entries, ledger):
    for entry in unposted_entries(entries, ledger.posted_ids()):   # the only changed line
        ...  # 60 lines unchanged
```

## Sprout class

Use when the new logic needs state, or the legacy class cannot be constructed in a test at all (it connects to a database or reads files in its constructor). The new class takes plain values, so it is testable even though its caller is not.

```python
# before: ReportJob opens a DB connection in __init__; request is "add a CSV of quarterly totals"
class ReportJob:
    def __init__(self):
        self.db = connect(settings.DATABASE_URL)
    def run(self):
        rows = self.db.query("select ...")
        ...  # 120 untested lines

# after: the new behaviour lives in a class that never sees the DB
class QuarterlyTotals:
    def __init__(self, rows):
        self._rows = rows
    def to_csv(self) -> str:
        ...  # new, test-driven

class ReportJob:
    def run(self):
        rows = self.db.query("select ...")
        write_file("quarterly.csv", QuarterlyTotals(rows).to_csv())   # the only added line
        ...  # 120 lines unchanged
```

## Wrap

Use when the new behaviour runs before or after an existing operation: auditing, notifications, metrics, caching. Two steps, two diffs:

1. **Refactor**: move the old body to a new name and make the old name call it. No behaviour change; pins stay green.
2. **Behaviour**: give the old name the extra step.

```ts
// step 1: rename the body; pay() now only delegates
class Payroll {
  pay(employee: Employee): void {
    this.dispatchPay(employee);
  }
  private dispatchPay(employee: Employee): void { /* the old 50 lines, untouched */ }
}

// step 2: the new behaviour wraps the old call; the audit log arrives with it, behind a defaulted seam
  private readonly audit: Pick<AuditLog, "record">;
  constructor(audit: Pick<AuditLog, "record"> = defaultAuditLog) {
    this.audit = audit;
  }
  pay(employee: Employee): void {
    this.dispatchPay(employee);
    this.audit.record({ kind: "payment", employeeId: employee.id });
  }
```

```python
# step 1: rename
def pay(employee):
    _dispatch_pay(employee)

def _dispatch_pay(employee):
    ...  # the old body, untouched

# step 2: wrap
def pay(employee, audit=default_audit_log):
    _dispatch_pay(employee)
    audit.record("payment", employee.id)
```

When callers should choose (some want the audit, some do not), keep the old name as-is and add a new function (`pay_and_audit`) that wraps it, instead of a boolean flag.

## Choosing

- New decision or computation: sprout function.
- New logic with state, or an unconstructable host: sprout class.
- New step before or after existing behaviour: wrap.
- The change must alter a branch deep inside the body: neither fits yet. Pin it, extract that branch into a function as a pure refactor (separate diff, pins green), then change the extracted function test-first.
