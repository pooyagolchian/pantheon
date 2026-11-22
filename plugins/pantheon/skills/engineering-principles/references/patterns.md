# Design patterns and SOLID without the Java accent

Contents
- The default: native idiom first
- GoF pattern to native idiom
- Before/after for the most over-built ones
- When the pattern is right
- SOLID as review smells
- Composition over inheritance
- Gotchas

## The default: native idiom first

GoF patterns were written for languages without first-class functions, unions or modules. In TypeScript and Python most of them collapse into a function, a dict or a union. Reach for the class-shaped version only when the trigger in "When the pattern is right" is present today, not when it might be one day.

This file is about pattern shape. The seam, rule-of-three and data-over-flags rules it leans on are in `design.md`.

## GoF pattern to native idiom

| Pattern | TypeScript | Python |
|---|---|---|
| Strategy | pass a function: `(input) => output` | pass a callable |
| Factory / Abstract Factory | a function returning the value, or a map of constructors | a function, or `{"csv": CsvExporter, ...}` |
| Singleton | a module-level `const`, created in the shell and passed in | a module-level instance, or a `functools.cache` getter |
| Observer | `EventTarget`, Node's `EventEmitter`, a signal, or a `Set` of callbacks | a list of callbacks; `blinker` if the project has it |
| Builder | an options object with defaults in the destructuring | keyword-only args, or a `@dataclass` with defaults |
| Visitor | discriminated union + exhaustive `switch` | union of dataclasses + `match` |
| State | union of states + a transition function or table | same, with `match` or a dict of allowed moves |
| Decorator | a higher-order function, or framework middleware | an `@decorator` (a higher-order function with syntax) |
| Template Method | the varying step is a function parameter | same |
| Command | a plain data object plus one handler function | a `@dataclass` plus a handler |
| Iterator | generators (`function*`), `for...of` | generators, `yield` |

A "dict of constructors" factory is the same move as the `PLANS` table in `design.md`: put the variation in data, look it up once.

Python's `@decorator` is the native form of "wrap a function". GoF Decorator wraps an *object* behind the same interface; you need that only when callers hold the object and you cannot change them, which is the Adapter case below.

## Before/after for the most over-built ones

**Strategy: pass a function.**

```ts
// before: an interface and a class per rule, for one method
interface DiscountStrategy { apply(totalCents: number): number }
class TenPercentOff implements DiscountStrategy {
  apply(totalCents: number) { return Math.round(totalCents * 0.9); }
}

// after
type Discount = (totalCents: number) => number;
const tenPercentOff: Discount = (totalCents) => Math.round(totalCents * 0.9);
const checkout = (totalCents: number, discount: Discount) => discount(totalCents);
```

**Factory: a dict of constructors.** An unknown kind raises `KeyError` at the lookup, which is the loud failure you want.

```python
# before: class ExporterFactory with create(kind) and an if/elif per kind
# after
EXPORTERS: dict[str, type[Exporter]] = {"csv": CsvExporter, "json": JsonExporter}

def make_exporter(kind: str) -> Exporter:
    return EXPORTERS[kind]()
```

**Singleton: module scope.** A singleton class hides a global behind `getInstance()`: every caller reaches for it, so tests cannot swap it for a fake, and state leaks between tests because nothing resets it. A module-level instance is still global state, so create it in the imperative shell and pass it into the core.

```python
# before
class Settings:
    _instance = None
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance.api_url = os.environ["API_URL"]
        return cls._instance
```

```python
# after: a plain value, built once; the lazy form is a cached getter
@dataclass(frozen=True)
class Settings:
    api_url: str

@functools.cache
def settings() -> Settings:
    return Settings(api_url=os.environ["API_URL"])

# tests call settings.cache_clear(), or better, pass a Settings into the function under test
```

**Builder: an options object or keyword args.** Required fields are enforced by the type checker instead of a `build()` that throws at runtime.

```ts
// before: new RequestBuilder().url("/orders").method("POST").timeoutMs(5000).build()
type RequestOptions = { url: string; method?: "GET" | "POST"; timeoutMs?: number; retries?: number };

function request({ url, method = "GET", timeoutMs = 10_000, retries = 0 }: RequestOptions) {
  return { url, method, timeoutMs, retries };
}

request({ url: "/orders", method: "POST", timeoutMs: 5000 });
```

```python
@dataclass(frozen=True)
class ReportOptions:
    title: str
    page_size: int = 50
    columns: list[str] = field(default_factory=list)  # `= []` is a ValueError in a dataclass
```

**Visitor and State: a union plus an exhaustive switch.** The `ShapeVisitor` interface with `visitCircle` / `visitRect` and an `accept()` on every class exists to fake a sum type. Use the real one. Exhaustiveness with `assertNever` is covered by `typescript-conventions`, if installed.

```ts
type Shape = { kind: "circle"; r: number } | { kind: "rect"; w: number; h: number };

function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return Math.PI * s.r ** 2;
    case "rect": return s.w * s.h;
  }
}
```

```python
@dataclass(frozen=True)
class Circle:
    r: float

@dataclass(frozen=True)
class Rect:
    w: float
    h: float

def area(s: Circle | Rect) -> float:
    match s:
        case Circle(r=r): return math.pi * r**2
        case Rect(w=w, h=h): return w * h
        case _: assert_never(s)  # pyright/mypy flag a missing case; at runtime this raises
```

## When the pattern is right

Use the class-shaped pattern when its trigger is present now:

- **Adapter**: at a third-party or legacy boundary, to translate their types and errors into yours, so the rest of the code never imports the vendor SDK. One adapter, no interface, until a second vendor or a fake arrives.
- **Command as a class**: undo/redo (each command carries `do` and `undo`), or a durable job queue where the command is serialized, retried and audited. Otherwise it is a data object and a handler.
- **Explicit state machine**: multi-step workflows where some transitions are illegal (order, payment, onboarding). Keep it a union plus a transition table, not a State class per state:

```ts
type OrderState = "draft" | "submitted" | "paid" | "shipped" | "cancelled";

const ALLOWED: Record<OrderState, readonly OrderState[]> = {
  draft: ["submitted", "cancelled"], submitted: ["paid", "cancelled"],
  paid: ["shipped"], shipped: [], cancelled: [],
};

function transition(from: OrderState, to: OrderState): OrderState {
  if (!ALLOWED[from].includes(to)) throw new Error(`illegal order transition ${from} -> ${to}`);
  return to;
}
```

- **Repository**: by default, test data access against the real database engine when that is cheap (containerised, per-test transaction rollback). Introduce a repository port with an in-memory fake only when DB-backed service tests become too slow or there are two or more storage backends, then run one contract suite against both.
  A repository wrapping one ORM one-to-one, with neither trigger present, is a shallow module.
- **Facade**: over a sprawling SDK (cloud storage, payments) where callers need three operations out of three hundred. It should be deep: hide auth, retries, pagination and error translation.

## SOLID as review smells

Read SOLID as two failure directions. Over-application is the common model error.

| Principle | Over-applied looks like | Under-applied looks like | Fix |
|---|---|---|---|
| SRP | one-method classes chained `Validator → Mapper → Saver` for one flow | a 600-line `OrderService` doing parsing, pricing, I/O and email | group by reason to change: one module per concept, functions inside it |
| OCP | a config-driven plug-in registry for two cases | the same `if kind ==` ladder edited in five files | a `switch` or a table; extract an extension point when the third case arrives |
| LSP | (rarely over-applied) | a subclass that throws `NotImplementedError`, ignores an argument, or narrows what inputs it accepts | the subclass is not a subtype: split the type, or compose instead |
| ISP | one interface per method; `IReadable`, `IWritable`, `IClosable` on one class | callers depend on a 20-method client to use one call | depend on the function you need, or `Pick<Client, "send">` |
| DIP | an interface plus a DI container for a module with one implementation | domain logic constructing its DB client or reading `process.env` inline | pass the dependency as a parameter; no interface before a second implementation or a test fake |

On DIP: structural typing removes most reasons to declare an interface up front. In TypeScript a fake satisfies `Pick<typeof mailer, "send">` without anything declared; in Python use a `Protocol` (structural), not an ABC (nominal, forces inheritance). Often the dependency is one function, so pass the function.

## Composition over inheritance

- **Depth above one is a smell in application code.** `Base → Service → OrderService` means a change to `Base` lands in places nobody reviews. The exceptions are custom error classes (`class NotFoundError extends Error`) and framework base classes you must extend (Django `Model`, `unittest.TestCase`).
- **Share behaviour by calling it**, not by inheriting it: a function, a field holding a collaborator, or a module.
- **Abstract base classes with one subclass** are the interface-before-second-implementation smell in another form.
- **Python mixins sparingly**: one small, stateless mixin is fine; three on one class make the MRO the documentation. Prefer a function or a held collaborator.

## Gotchas

- `IUserService` + `UserServiceImpl` + `UserServiceFactory` for one class, which reads as architecture and is three files of indirection.
- A singleton class "for performance" where a module-level instance does the same and can be replaced in tests.
- A Builder whose `build()` validates required fields at runtime that the type could require at compile time.
- A Visitor hierarchy in TS or Python, when a union plus `switch` / `match` gives the same exhaustiveness with a quarter of the code.
- A Strategy registry keyed by string, for two strategies the caller already knows statically. Pass the function.
- Describing a change in GoF names ("add a StrategyFactory") before checking whether a function would do.
