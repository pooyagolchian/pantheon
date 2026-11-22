# Patterns: before and after

Contents: boundaries · narrowing · `satisfies` · unions and exhaustiveness · branded types · enums · errors · generics · async

## Boundaries: `unknown` in, schema out

```ts
// Before: the cast is a claim nothing checks
const user = (await res.json()) as User;
```

```ts
import { z } from "zod";

const User = z.object({
  id: z.string(),
  name: z.string(),
  roles: z.array(z.enum(["admin", "member"])),
});
type User = z.infer<typeof User>;
const CreateUser = User.omit({ id: true });
type CreateUser = z.infer<typeof CreateUser>;

type HttpResponse = { status: number; body: unknown };

// Inbound boundary: `.parse` throws, and one translator turns typed errors into responses.
async function createUserHandler(
  rawBody: unknown,
  create: (input: CreateUser) => Promise<User>,
): Promise<HttpResponse> {
  try {
    const input = CreateUser.parse(rawBody);
    return { status: 201, body: await create(input) };
  } catch (e) {
    return toHttpResponse(e);
  }
}

function toHttpResponse(e: unknown): HttpResponse {
  if (e instanceof z.ZodError) return { status: 400, body: { issues: e.issues } };
  if (e instanceof NotFoundError) return { status: 404, body: { error: e.message } };
  throw e; // a bug: the top-level handler logs it and answers 500
}
```

- The schema is the source of truth; never hand-write a `User` interface next to it. Same for env vars, `JSON.parse`, `localStorage`, `postMessage`, queue payloads, and CLI args.
- `.parse` belongs only at an inbound boundary (HTTP handler, queue consumer, CLI entry) with a translator like `toHttpResponse`, usually the framework's error middleware. Anywhere a caller branches on the outcome, use `.safeParse` and return a `Result` (see Errors).

## Narrowing instead of `as` and `!`

```ts
// Before
const input = document.getElementById("email") as HTMLInputElement;
const head = items[0]!;
```

```ts
function readEmail(items: readonly string[]): string | null {
  const input = document.getElementById("email");
  if (!(input instanceof HTMLInputElement)) throw new Error("#email is not an input");

  const head = items[0];
  if (head === undefined) return null;
  return `${head}:${input.value}`;
}
```

Type guards and assertion functions move the check into a reusable function:

```ts
function isDefined<T>(x: T | null | undefined): x is T {
  return x !== null && x !== undefined;
}

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}
```

- `.filter((x) => x !== undefined)` already narrows on current compilers; reach for `isDefined` when the predicate is not that simple.
- An assertion function declared as an arrow (`const assert = (...) => ...`) fails at the call site with TS2775 unless the const itself has an explicit type. Use a `function` declaration.
- A guard's body is unchecked: `x is T` is a promise you make. Keep guards tiny, or derive them from a schema (`User.safeParse(x).success`).

## `satisfies` for checked literals

```ts
// Before: the annotation widens; keys are just `string`, every lookup is `| undefined`
const routes: Record<string, { path: string }> = { home: { path: "/" } };
```

```ts
const routes = {
  home: { path: "/" },
  user: { path: "/users/:id" },
} as const satisfies Record<string, { path: string }>;

type RouteName = keyof typeof routes; // "home" | "user"
```

## Unions and exhaustiveness

```ts
// Before: 8 combinations, 4 legal; nothing stops { loading: true, error }
type Remote = { loading?: boolean; data?: User; error?: Error };
```

```ts
type RemoteData<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

function assertNever(x: never): never {
  throw new Error(`Unhandled variant: ${JSON.stringify(x)}`);
}

function label(r: RemoteData<User>): string {
  switch (r.status) {
    case "idle": return "";
    case "loading": return "Loading";
    case "success": return r.data.name;
    case "error": return r.error.message;
    default: return assertNever(r);
  }
}
```

Adding a variant now breaks every `switch` that forgot it, at compile time, and throws if bad data slips past types at runtime.

## Branded types

```ts
declare const brand: unique symbol;
type Brand<T, B extends string> = T & { readonly [brand]: B };

type UserId = Brand<string, "UserId">;
type Cents = Brand<number, "Cents">;

function toCents(amount: number): Cents {
  if (!Number.isInteger(amount)) throw new Error(`not whole cents: ${amount}`);
  return amount as Cents; // the one sanctioned cast: inside the validating constructor
}

const OrderId = z.string().brand<"OrderId">(); // or let the schema brand it
type OrderId = z.infer<typeof OrderId>;
```

Brand what is easy to swap silently: IDs of different entities, money vs. plain numbers, units, sanitised vs. raw strings.

## Enums

```ts
// Before
enum Status { Active, Suspended }
const n: number = 99;
const s: Status = n;              // compiles: any number variable fits a numeric enum
Object.values(Status);            // ["Active", "Suspended", 0, 1]: reverse mapping
```

```ts
type Plan = "free" | "pro";               // no runtime value needed: a plain union

const Role = { Admin: "admin", Member: "member" } as const;
type Role = (typeof Role)[keyof typeof Role]; // "admin" | "member"
const allRoles = Object.values(Role);          // iterate when you need the list
```

String enums are nominal too: a caller cannot pass `"active"`, only `Status.Active`, which breaks values coming from JSON.

## Errors

`parseConfig` is called from domain code that branches on the outcome, so it returns a `Result` instead of throwing.

```ts
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

const Config = z.object({ port: z.number().int() });
type Config = z.infer<typeof Config>;
type ConfigError = { kind: "invalid-json" } | { kind: "schema"; message: string };

function parseConfig(text: string): Result<Config, ConfigError> {
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return { ok: false, error: { kind: "invalid-json" } };
  }
  const parsed = Config.safeParse(json);
  return parsed.success
    ? { ok: true, value: parsed.data }
    : { ok: false, error: { kind: "schema", message: parsed.error.message } };
}
```

```ts
class NotFoundError extends Error {
  override readonly name = "NotFoundError";
  readonly resource: string;
  constructor(resource: string, options?: ErrorOptions) {
    super(`${resource} not found`, options);
    this.resource = resource;
  }
}

async function loadOrder(
  id: string,
  query: (sql: string, params: readonly unknown[]) => Promise<unknown>,
): Promise<unknown> {
  try {
    return await query("select * from orders where id = $1", [id]);
  } catch (e) {
    throw new Error(`loading order ${id} failed`, { cause: e });
  }
}

function messageOf(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}
```

- Fields are assigned in the body, not as `constructor(readonly resource: string)`: parameter properties are rejected under `erasableSyntaxOnly`.
- `return await` inside `try` is deliberate: without `await` the rejection escapes the `catch`.

## Generics

```ts
// Before: each T appears once, so it adds nothing but noise
function logValue<T>(x: T): void { console.log(x); }
function len<T>(xs: T[]): number { return xs.length; }
```

```ts
function logValue(x: unknown): void { console.log(x); }
function len(xs: readonly unknown[]): number { return xs.length; }
function firstOf<T>(xs: readonly T[]): T | undefined { return xs[0]; }
function byId<T extends { id: string }>(xs: readonly T[]): Map<string, T> {
  return new Map(xs.map((x) => [x.id, x]));
}
```

A type parameter earns its place when it links an input to an output. Constrain it (`extends { id: string }`) instead of casting inside the body.

## Async

```ts
// Before: saves run unawaited, rejections are unhandled, the caller sees "done" too early
ids.forEach(async (id) => { await save(id); });
```

```ts
// Sequential: one at a time, stops at the first failure.
async function saveInOrder(ids: readonly string[], save: (id: string) => Promise<void>): Promise<void> {
  for (const id of ids) await save(id);
}

// Concurrent: all at once, still awaited; rejects on the first failure.
async function saveConcurrently(ids: readonly string[], save: (id: string) => Promise<void>): Promise<void> {
  await Promise.all(ids.map((id) => save(id)));
}
```

Deliberate fire-and-forget is written `void track(event).catch(report);`, which `no-floating-promises` accepts.
