---
name: typescript-conventions
description: Strict, modern TypeScript conventions limited to what models get wrong, with an annotated tsconfig baseline and before/after patterns. Covers strict compiler flags (noUncheckedIndexedAccess, exactOptionalPropertyTypes, verbatimModuleSyntax, erasableSyntaxOnly), narrowing instead of as-casts and non-null assertions, satisfies, unknown plus zod schemas at boundaries, discriminated unions with exhaustive never checks, branded IDs, as-const objects instead of enum, typed Result errors, import type, barrel files, default exports and generics. Use when writing or reviewing TypeScript or TSX in Node, React or other frontend projects, setting up or upgrading tsconfig.json, fixing type errors, modelling data, API or domain types, or when asked to "fix the types", "make this type-safe", "type this API response", "get rid of any" or "why is this possibly undefined". Also catches JSON.parse and fetch any leaks, Object.keys typing, async forEach and floating promises.
---

# TypeScript conventions

## Rules that matter most

1. **Never silence the checker.** No `as` to make an error go away, no `!` without an invariant you can name, no `any`, no `@ts-ignore`. A type error is a question about the code; answer it with a check.
2. **`unknown` at every boundary, then a schema.** `JSON.parse`, `fetch`, env, storage, messages, CLI args come in as `unknown` and leave a runtime schema (the project's existing validator; zod if there is none) as typed data. Infer the type from the schema; never maintain both.
3. **Make illegal states unrepresentable.** Discriminated unions over bags of optional fields, with an exhaustive `assertNever` in every `switch`.
4. **Types document intent at module edges.** Explicit return types on exported functions, `readonly` inputs, branded IDs. Inside a function, let inference work.
5. **Bugs always throw; expected failures follow the error policy below.**

## tsconfig

New projects start from `strict` plus `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`, `verbatimModuleSyntax`, `erasableSyntaxOnly` and `isolatedModules`; Node packages use `module: nodenext` with `"type": "module"`, bundled frontends use `module: preserve` + `moduleResolution: bundler` + `noEmit`.

- In an existing codebase, enable one flag per change and fix the errors for real. If a flag produces a wave of `!` or `as`, back it out; that is worse than the flag being off.
- Since TypeScript 6.0, `types` defaults to `[]` instead of every installed `@types` package. "Cannot find name 'process'" means add `"node"` to `types`, not a `declare`.
- Match `target` and `lib` to the oldest Node you run (`es2023` for Node 20). `esnext` emits syntax and types APIs that older runtimes lack.
- `baseUrl`, `moduleResolution: node`/`node10`, `esModuleInterop: false` and `target: es5` are deprecated in TypeScript 6.0 and removed in 7. Delete them; do not reach for `ignoreDeprecations`.

Read [references/tsconfig.md](references/tsconfig.md) when creating or changing a tsconfig: full baseline JSON, what each flag buys, frontend and library variants, the adoption table for existing code.

## Narrowing over casting

- **Narrow with real checks:** `typeof`, `instanceof`, `in`, `Array.isArray`, discriminant comparison, `=== undefined`.
- **`satisfies` for literals** you want checked but not widened: `const routes = {...} as const satisfies Record<string, Route>`.
- **Type guards** (`x is T`) and **assertion functions** (`asserts x`) for checks you repeat. The guard body is unchecked, so keep it tiny or derive it from the schema. Declare assertion functions with `function`, not as arrow consts (TS2775).
- **`as` is acceptable** in exactly three places: `as const`, inside a validating constructor for a branded type, and test fixtures built from partial data. Anything else needs a comment saying why the compiler cannot see it.
- **`!` needs a named invariant** in a comment ("set in `init()`, which the constructor calls"). Prefer restructuring so the value is never optional.

## Modelling

- **Discriminated unions** with a literal `status`/`kind`/`type` field. Ending every `switch` with `default: return assertNever(x)` turns a new variant into a compile error everywhere it is unhandled.
- **No optional-property soup.** Three optional fields is eight shapes. If only some combinations are legal, write them as union members.
- **Branded types** for values that are easy to swap: `UserId` vs `OrderId`, `Cents` vs `number`, `SafeHtml` vs `string`. Mint them only in one validating function or schema (`z.string().brand<"UserId">()`).
- **`readonly` by default for inputs:** `readonly T[]`, `ReadonlyMap`, `Readonly<T>` on parameters. It is shallow; do not build deep-readonly types in app code.
- **No `enum`.** Use a union of string literals; when a runtime list is needed, an `as const` object plus `type X = (typeof X)[keyof typeof X]`. Enums emit runtime code (rejected by `erasableSyntaxOnly`), numeric enums accept any `number` variable, and string enums reject the plain strings that arrive from JSON.
- **`interface` vs `type`:** `type` by default (unions, mapped types, consistency); `interface` when declaration merging or `extends` hierarchies are the point.

## Error policy

Bugs always throw. At an inbound boundary (HTTP handler, queue consumer, CLI entry), parse failures and expected domain errors may be thrown as typed errors to one translator that maps them to the response (400/404/409); inside the domain, functions whose callers branch on the outcome return a Result/union instead of throwing.

- **In TypeScript terms:** at the boundary, `Schema.parse(raw)` plus a translator that maps `ZodError` and your error classes to status codes, rethrowing anything else so the top-level handler answers 500. In the domain, `Schema.safeParse` and `type Result<T, E> = { ok: true; value: T } | { ok: false; error: E }` with `E` itself a discriminated union. Do not add a Result library to a codebase that has none.
- **`catch` variables are `unknown`** under `strict`. Narrow with `instanceof Error` before reading `.message`. Promise `.catch((e) => ...)` callbacks are still `any`; annotate `(e: unknown)`.
- **Wrap with `cause`** when rethrowing across layers: `throw new Error("loading order 42 failed", { cause: e })`. Never rethrow a new error without it.
- **`return await` inside `try`**, or the rejection skips the `catch`.
- **Custom error classes** set `override readonly name` and assign fields in the body; parameter properties are not erasable syntax.

## Modules

- **`import type` / `export type`** for type-only symbols. `verbatimModuleSyntax` enforces it; it keeps type stripping and bundlers from emitting or dropping the wrong imports.
- **No barrel files (`index.ts` re-exporting a folder) in app code.** They pull whole folders into every import, slow type-checking and test startup, and are the usual source of import cycles. Import from the defining file. A package's single public entry point is the exception, and so is a feature folder's single public entry when module boundaries are enforced (named re-exports only, never `export *`).
- **Explicit return types on exported functions.** They stop internal types leaking into the API, keep a changed body from silently changing callers, and speed up checking. Required anyway under `isolatedDeclarations`.
- **Named exports only.** Default exports get renamed at every import site, auto-import and rename refactors handle them worse, and they interoperate badly with CommonJS consumers. Use a default export only where a framework demands it (route files, config files, stories).

## Generics

- A type parameter must link at least two positions (input to output, or two inputs). If it appears once, use the concrete type or `unknown`.
- Constrain instead of casting inside the body: `<T extends { id: string }>`.
- No conditional, recursive or template-literal type machinery in app code. If the type takes longer to read than the function, write the simpler type and add a test.

## Gotchas

- **`any` leaks.** `JSON.parse` returns `any`, and `Response.json()` is `any` under the DOM lib. Assign to `unknown` and parse. One `any` silently disables checking for everything it touches.
- **`Object.keys(obj)` is `string[]`,** because objects can carry extra keys at runtime. Use `Object.entries`, a `Map`, or an `as const` key array, not a cast.
- **Index access** returns `T | undefined` with `noUncheckedIndexedAccess`. Check it, or use `for...of` / `.entries()` instead of index loops.
- **`{}` means any non-nullish value** and `Function` is an untyped call. Use `object`, `Record<string, unknown>`, `unknown`, or an explicit signature.
- **Async callbacks in `forEach`** run unawaited and their rejections go unhandled. Use `for...of` with `await`, or `await Promise.all(xs.map(...))`.
- **Floating promises.** Enable typescript-eslint `no-floating-promises` and `no-misused-promises` (they need type-aware linting). Deliberate fire-and-forget is `void task().catch(report)`.
- **`process.env.X` is TS4111** under `noPropertyAccessFromIndexSignature`. Do not scatter `process.env["X"]` reads; parse `process.env` once at startup with a schema and import the typed config.
- **`exactOptionalPropertyTypes`** rejects `{ a: undefined }` for `a?: T`. Omit the key, or declare `a?: T | undefined` when undefined is a meaningful value.
- **`.filter(Boolean)`** narrows nothing and drops `0` and `""`. Use `.filter((x) => x !== undefined)`.

Read [references/patterns.md](references/patterns.md) when you need a worked before/after for any rule above: schema plus translator at an inbound handler, narrowing, `satisfies`, `assertNever`, brands, enum replacement, `Result`, `cause`, generics, async loops.

## Before handing back TypeScript

- [ ] `tsc --noEmit` (or the project's typecheck script) passes with no new `as`, `!`, `any` or `@ts-` comments.
- [ ] Every external input is parsed by a schema; no hand-written duplicate of an inferred type.
- [ ] Every `switch` on a union ends in `assertNever`.
- [ ] Exported functions have return types; type-only imports use `import type`.
- [ ] The linter's floating-promise rules pass.
