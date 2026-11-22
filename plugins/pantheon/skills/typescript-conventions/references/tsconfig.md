# tsconfig baseline

Contents: Node baseline · what each flag buys · bundled frontend · published library · existing codebases · removed options

## Node service or CLI (the default)

```json
{
  "compilerOptions": {
    "target": "es2023",
    "module": "nodenext",
    "lib": ["es2023"],
    "types": ["node"],
    "rootDir": "src",
    "outDir": "dist",
    "sourceMap": true,

    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noPropertyAccessFromIndexSignature": true,

    "verbatimModuleSyntax": true,
    "isolatedModules": true,
    "erasableSyntaxOnly": true,
    "noUncheckedSideEffectImports": true,
    "moduleDetection": "force",
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

Pair it with `"type": "module"` in `package.json`. Under `nodenext` a `.ts` file is CommonJS unless the package says otherwise, and `verbatimModuleSyntax` then rejects every `import`/`export` (TS1295, TS1287). Relative imports need the runtime extension: `import { x } from "./x.js"`.

## What each flag buys

- **`target` / `lib`** — match both to the oldest Node you run; the baseline's `es2023` fits Node 20. `esnext` emits syntax an older runtime cannot parse (`using` is a SyntaxError on Node 20) and types APIs it lacks (`Promise.withResolvers` type-checks, then is `undefined`). Raise them when the runtime floor rises.
- **`strict`** — the family (`strictNullChecks`, `noImplicitAny`, `useUnknownInCatchVariables`, ...). TypeScript 6.0 made it the default, but set it explicitly: editors, older compilers and tools that read the config do not all share that default.
- **`noUncheckedIndexedAccess`** — `arr[i]` and `record[key]` include `undefined`. Catches the most common runtime `undefined` crash that `strict` misses.
- **`exactOptionalPropertyTypes`** — `{ a?: string }` no longer accepts `{ a: undefined }`. Makes "absent" and "present but undefined" distinct, which matters for `in` checks, spreads, and PATCH semantics.
- **`noImplicitOverride`** — overriding a base method needs `override`; renaming the base method then breaks the build instead of silently orphaning the subclass method.
- **`noImplicitReturns`, `noFallthroughCasesInSwitch`** — cheap, almost never false positives.
- **`noPropertyAccessFromIndexSignature`** — `obj.foo` only for declared keys, `obj["foo"]` for index-signature keys, so the code shows which lookups can miss.
- **`verbatimModuleSyntax`** — imports are emitted exactly as written; type-only imports must say `import type`. Single-file transpilers (esbuild, swc, Babel, type stripping) then produce the same imports `tsc` would.
- **`erasableSyntaxOnly`** — rejects syntax that needs code generation: `enum`, `namespace` with runtime code, constructor parameter properties, `import x = require()`, `export =`, `<T>x` assertions. Keeps the source runnable by type-stripping runtimes and keeps TS a pure type layer.
- **`noUncheckedSideEffectImports`** — `import "./polyfil"` with a typo becomes an error. Default since 6.0; stated for older toolchains.
- **`moduleDetection: force`** — every file is a module, so top-level names never collide as globals.
- **`skipLibCheck`** — do not type-check `.d.ts` in `node_modules`; their errors are not yours to fix and cost build time.
- **`types: ["node"]`** — since 6.0 `types` defaults to `[]`, so globals like `process`, `Buffer`, `describe` vanish until listed. "Cannot find name 'process'" means add the package here (`"node"`, `"vitest/globals"`, ...), not a `declare`.
- **`rootDir`** — since 6.0 it defaults to the tsconfig directory instead of being inferred; set it or `dist/` gains an extra `src/` level.
- **Left out on purpose** — `noUnusedLocals` / `noUnusedParameters` fail the build mid-edit; let the linter report unused code as warnings.

## Bundled frontend (Vite, Next, etc.)

The bundler resolves and emits; `tsc` only type-checks. Change these keys from the Node baseline:

```diff
-    "module": "nodenext",
-    "lib": ["es2023"],
-    "types": ["node"],
-    "rootDir": "src",
-    "outDir": "dist",
-    "sourceMap": true,
+    "module": "preserve",
+    "moduleResolution": "bundler",
+    "lib": ["es2023", "dom"],
+    "types": [],
+    "jsx": "react-jsx",
+    "noEmit": true,
```

Put the framework's ambient types in `types` (for example `"vite/client"`). Frameworks that generate their own tsconfig: keep theirs and add only the strictness flags.

## Published library

Add to the Node baseline:

```json
{
  "compilerOptions": {
    "declaration": true,
    "declarationMap": true,
    "isolatedDeclarations": true
  }
}
```

`isolatedDeclarations` forces explicit types on every export so `.d.ts` files can be generated per file by fast tools, and stops inferred types from leaking into your public API. In app code it is noise.

## Existing codebases: do not flip blindly

Turn each on in its own change, fix the errors properly, and never "fix" them with `!`, `as`, or `any` — that is worse than leaving the flag off.

| Flag | Typical cost | How to adopt |
|---|---|---|
| `strict` (from off) | hundreds to thousands of errors | enable sub-flags one at a time, `strictNullChecks` last |
| `noUncheckedIndexedAccess` | every `arr[0]` and map lookup | fix with guards or `.at()` + check; a wave of `!` means stop |
| `exactOptionalPropertyTypes` | errors in code that passes `undefined` explicitly, and in some third-party types | change to `a?: T \| undefined` where undefined is truly allowed |
| `erasableSyntaxOnly` | every `enum`, parameter property, namespace | only when moving to type stripping; replace enums with `as const` objects |
| `verbatimModuleSyntax` | CommonJS output becomes awkward; `import` of types must become `import type` | mechanical with `eslint --fix` (`consistent-type-imports`) |
| `isolatedDeclarations` | annotations on every export | libraries only |

## Removed options

All four are deprecated in TypeScript 6.0 (errors TS5101/TS5107, silenced only by `"ignoreDeprecations": "6.0"`) and removed in 7. Remove on sight; do not add `ignoreDeprecations`.

- `baseUrl` — put the prefix in each `paths` entry instead (`"@app/*": ["./src/app/*"]`).
- `moduleResolution: "node"` / `"node10"` — use `nodenext` for Node, `bundler` behind a bundler.
- `esModuleInterop: false`.
- `target: "es5"`.
