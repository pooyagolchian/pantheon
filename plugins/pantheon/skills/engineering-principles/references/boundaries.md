# Boundaries: validate once at the edge, trust inside

Contents
- Where the boundaries are
- Parse, don't validate
- Make illegal states unrepresentable
- Casts are a missing parse
- Defensive checks in the wrong place

## Where the boundaries are

Data is untrusted until it has been parsed into a domain type. A boundary is anywhere data enters from outside your code:
HTTP bodies, query strings and headers; CLI args and env vars; config files; database rows (schemas drift, migrations lag);
responses from other services and LLMs; message queues; files and user uploads; `JSON.parse` / `json.loads` of anything.

Parse each one at the point of entry, into a type that downstream code can rely on without rechecking.

## Parse, don't validate

A validator returns a boolean and throws the knowledge away; every later function has to wonder again.
A parser returns a narrower type that carries the proof.

```ts
// before: validated, but the type still says string, so checks get repeated (or forgotten) downstream
function isEmail(s: string): boolean { return /^[^@\s]+@[^@\s]+$/.test(s); }
function invite(email: string) { if (!isEmail(email)) throw new Error("bad email"); /* ... */ }

// after: the type is the proof
type Email = string & { readonly __brand: "Email" };
function parseEmail(s: string): Email {
  const t = s.trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+$/.test(t)) throw new ValidationError("email", s);
  return t as Email; // the only cast, inside the parser
}
function invite(email: Email) { /* no check needed */ }
```

```python
# before: a dict travels through the system and every function does .get() with a default
def handle(payload: dict) -> None:
    qty = int(payload.get("qty", 1))
    ...

# after: parse at the edge with a schema, then pass the typed object
from pydantic import BaseModel, PositiveInt

class OrderLine(BaseModel):
    sku: str
    qty: PositiveInt

def handle(raw: dict) -> None:
    line = OrderLine.model_validate(raw)   # raises with field paths on bad input
    reserve(line)                          # reserve() takes OrderLine, never dict
```

Parsers run at the inbound boundary, so a parse failure throws a typed `ValidationError` that the boundary's one translator maps to a 400 (see `errors.md` in this skill). Domain code past the parser never sees unparsed input.

Use the schema library the project already has (zod, valibot, pydantic, attrs, serde). Do not hand-roll one next to it.

## Make illegal states unrepresentable

If two fields must change together, or one is only meaningful when another has a certain value, encode that in the type.

```ts
// before: 4 combinations, 2 of them nonsense (loading with an error, done without data)
type Fetch = { loading: boolean; error?: Error; data?: Report };

// after: exactly the 3 legal states
type Fetch =
  | { status: "loading" }
  | { status: "failed"; error: Error }
  | { status: "done"; data: Report };
```

```python
# before
@dataclass
class Shipment:
    shipped: bool
    tracking_number: str | None   # must be set iff shipped, enforced nowhere

# after
@dataclass(frozen=True)
class Pending: ...

@dataclass(frozen=True)
class Shipped:
    tracking_number: str

Shipment = Pending | Shipped
```

Other cheap wins: non-empty list types for "at least one", enums or literal unions instead of free strings, money as integer minor units plus currency, durations and timestamps as real time types rather than bare numbers.

## Casts are a missing parse

`as Foo`, `as any`, `as unknown as Foo`, `cast(Foo, x)`, `# type: ignore` and `!` non-null assertions tell the compiler to stop checking exactly where the data is least trustworthy. When you reach for one, the fix is almost always a parse at the boundary that produces the type honestly.

```ts
// before
const user = (await res.json()) as User;

// after
const user = User.parse(await res.json());
```

The one legitimate cast is inside a parser or a branded-type constructor, after the check.

## Defensive checks in the wrong place

Models tend to sprinkle `if (!x) return` and `x?.y?.z ?? ""` deep inside internal functions whose inputs are already typed and non-null, while the actual entry point does no validation at all. Invert that:

- At the boundary: strict parsing, explicit error with the field path.
- Inside: no null checks for values the type says are present; no `try` around code that cannot throw an expected error.
- For invariants that the type system cannot express: an assertion that crashes with a message, not a silent early return.
