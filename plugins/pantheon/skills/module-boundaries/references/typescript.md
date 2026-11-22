# TypeScript boundary configs

Contents: install and CI · dependency-cruiser · baseline · workspaces · eslint-plugin-boundaries · `no-restricted-imports` · knip

All configs assume the layout from SKILL.md (`src/app`, `src/features/<f>`, `src/shared`) and a `@/*` paths alias. Each one was run against a fixture with planted violations: dependency-cruiser 18.8, eslint-plugin-boundaries 7.4, ESLint 10, knip 6, TypeScript 6.

## Install and CI

```sh
npm i -D dependency-cruiser knip   # dependency-cruiser 18 needs Node 22+; on Node 20 npm quietly installs 17
```

On dependency-cruiser 17, delete the `baseline` key from the options below: 17 rejects the whole config with `data/options must NOT have additional properties`. Also use `npx depcruise-baseline src` in place of `--baseline`. Version 17 has no stale-entry check, so review the baseline file for shrinkage by hand.

```sh
npx depcruise src --validate --ignore-known   # structure; drop --ignore-known on a clean codebase
npx knip                                      # unused files, exports, dependencies
```

- dependency-cruiser uses the project's own `typescript` package to parse `.ts`. If `npx depcruise --info` shows `x typescript`, it skips every `.ts` file and exits 0.
- `npx depcruise --init` generates a larger starter config. The file below is the minimum worth keeping. Add `--init` rules such as `no-orphans` or `not-to-dev-dep` only when you will act on them.

## dependency-cruiser: `.dependency-cruiser.cjs`

```js
/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: "no-runtime-cycles",
      comment: "Cycles made only of `import type` edges vanish at runtime, so they pass.",
      severity: "error",
      from: {},
      to: { circular: true, viaOnly: { dependencyTypesNot: ["type-only"] } },
    },
    {
      name: "feature-public-entry-only",
      comment: "Another feature is reachable only through its index.ts. $1 = the importing feature.",
      severity: "error",
      from: { path: "^src/features/([^/]+)/" },
      to: {
        path: "^src/features/[^/]+/",
        pathNot: ["^src/features/$1/", "^src/features/[^/]+/index\\.ts$"],
      },
    },
    {
      name: "domain-is-pure",
      comment: "domain/ code imports no infra/, ui/ or app/ code, in its own feature or any other.",
      severity: "error",
      from: { path: "^src/features/[^/]+/domain/" },
      to: { path: ["^src/features/[^/]+/(infra|ui)/", "^src/app/"] },
    },
    {
      name: "shared-is-a-leaf",
      comment: "shared/ is the kernel every feature may use, so it imports no feature or app code.",
      severity: "error",
      from: { path: "^src/shared/" },
      to: { path: "^src/(features|app)/" },
    },
    {
      name: "nothing-imports-app",
      comment: "app/ is the composition root: it wires features together and nobody imports it.",
      severity: "error",
      from: { pathNot: "^src/app/" },
      to: { path: "^src/app/" },
    },
    {
      name: "not-to-unresolvable",
      comment: "An import that does not resolve is invisible to every rule above.",
      severity: "error",
      from: {},
      to: { couldNotResolve: true },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    tsConfig: { fileName: "tsconfig.json" }, // resolves the `@/` paths alias
    tsPreCompilationDeps: true, // keep `import type` edges; without it they are dropped
    baseline: { staleEntriesSeverity: "error" }, // a fixed violation must leave the baseline
  },
};
```

- `$1` in `to.pathNot` back-references the capture group in `from.path`. That is how one rule says "your own feature is fine, other features only through `index.ts`".
- `from` and `to` paths are regexes matched against paths relative to where you run the command. Always run it from the repo root.
- Without `tsConfig`, every `@/` import becomes unresolvable. Without `not-to-unresolvable`, those imports would silently escape every rule.
- To keep framework packages out of the domain, add a rule with `from: { path: "^src/features/[^/]+/domain/" }` and `to: { dependencyTypes: ["npm"], pathNot: ["node_modules/(zod)/"] }`, listing the packages the domain may use.

Expected output on a violation, exit code = number of errors:

```
  error feature-public-entry-only: src/features/orders/index.ts → src/features/billing/domain/invoice.ts
x 1 dependency violations (1 errors, 0 warnings). 13 modules, 18 dependencies cruised.
```

## Baseline (brownfield ratchet)

```sh
npx depcruise src --baseline                              # once: writes .dependency-cruiser-known-violations.json; commit it
npx depcruise src --validate --ignore-known               # CI: fails on new violations only
npx depcruise src --baseline --baseline-mode shrink-only  # after fixing some: drops fixed entries, never adds
```

- `--baseline` is the recommended form since dependency-cruiser 18.3. On older versions use `depcruise-baseline`.
- With `staleEntriesSeverity: "error"`, a fixed-but-still-listed violation makes `--ignore-known` exit 1 with `x 1 stale known violations in the baseline`. That forces the shrink-only step into the same PR as the fix.
- Severity is ignored when comparing against the baseline, so changing a rule from `warn` to `error` does not clear it.

## Workspaces (monorepo)

Run one cruise from the root over all packages: `npx depcruise apps packages --validate`. Workspace imports resolve through their `node_modules` symlink to the real path (`packages/a/src/index.ts`), so path rules see them. Make `package.json` `exports` the public entry and let the resolver enforce it:

```js
// in options
enhancedResolveOptions: {
  exportsFields: ["exports"],
  conditionNames: ["import", "require", "node", "default", "types"],
},
```

Then a deep import like `@org/a/src/internal` is reported by `not-to-unresolvable`. A relative path into another package is not, so pair it with a rule shaped like `feature-public-entry-only` with `from: { path: "^(packages|apps)/([^/]+)/" }` and `pathNot: ["^packages/$2/", "^packages/[^/]+/src/index\\.ts$"]`.

## eslint-plugin-boundaries (editor feedback, optional)

Gives squiggles while typing. It does not find cycles, so keep dependency-cruiser as the CI gate. Needs `eslint-plugin-boundaries`, `eslint-import-resolver-typescript` and a TypeScript parser (`typescript-eslint`).

```js
// eslint.config.js
import tseslint from "typescript-eslint";
import boundaries from "eslint-plugin-boundaries";

export default [
  {
    files: ["src/**/*.{ts,tsx}"],
    languageOptions: { parser: tseslint.parser },
    plugins: { boundaries },
    settings: {
      // Without a resolver that understands TS, nothing resolves and nothing is reported.
      "import/resolver": { typescript: { project: "./tsconfig.json" } },
      "boundaries/elements": [
        { type: "app", pattern: "src/app" },
        { type: "shared", pattern: "src/shared" },
        { type: "feature", pattern: "src/features/*", capture: ["name"] },
      ],
    },
    rules: {
      "boundaries/dependencies": ["error", {
        default: "allow",
        policies: [
          // Another feature only through its index.ts; a feature's own files are unrestricted.
          { from: { element: { type: "feature" } },
            disallow: { to: { element: {
              type: "feature",
              captured: { name: "!{{ from.element.captured.name }}" },
              fileInternalPath: "!index.{ts,tsx}",
            } } } },
          { from: { element: { type: "shared" } },
            disallow: { to: { element: { type: ["feature", "app"] } } } },
          { from: { element: { type: ["feature", "shared"] } },
            disallow: { to: { element: { type: "app" } } } },
        ],
      }],
    },
  },
];
```

- `boundaries/dependencies` replaces `boundaries/element-types`, `boundaries/entry-point`, `boundaries/external` and `boundaries/no-private`, which v7 marks deprecated. Configs and blog posts using those rule names, `rules:` instead of `policies:`, or `${from.name}` templates are for older majors.
- Verify by planting a relative-path import of `../billing/domain/x`. If ESLint stays silent, the resolver is not being used.

## `no-restricted-imports` (package bans only)

ESLint's core rule matches the import string as written. It cannot tell that `../billing/internal` and `@/features/billing/internal` are the same file, so do not use it for folder boundaries. It is the right tool for banning a package or a deep path inside one:

```js
"no-restricted-imports": ["error", { patterns: [
  { group: ["lodash", "lodash/*"], message: "Use lodash-es." },
  { group: ["@org/ui/*", "!@org/ui/icons"], allowTypeImports: true,
    message: "Import @org/ui from its root; icons are the one public subpath." },
] }],
```

`allowTypeImports` works in core ESLint when a TypeScript parser is configured. Negated `!` entries must come last in a `group`.

## knip: `knip.json`

```json
{
  "$schema": "https://unpkg.com/knip@6/schema.json",
  "entry": ["src/app/main.ts"],
  "project": ["src/**/*.{ts,tsx}"]
}
```

- **`entry` is the main fix for false positives.** Without it, knip treats only default names (`src/index.ts`, `src/main.ts`, …) as entries. It then flags the real entry and everything it reaches as unused files.
- **Plugins find config and test files** (`eslint.config.js`, `vitest.config.ts`, `*.test.ts`) only when the tool is listed in `package.json`. An unlisted runner means test files show up as unused.
- **Exports of entry files are not reported** unless `--include-entry-exports` is passed. A package's public API is not flagged just because nothing in-repo uses it.
- **Production mode:** `knip --production` checks only shipped code. Suffix production globs with `!` (`"src/app/main.ts!"`, `"src/**/*.ts!"`), or it scans nothing for unused files.
- **Workspaces:** with `workspaces` configured, root-level `entry`/`project` are ignored. Put the root's under the `"."` key:

```json
{
  "workspaces": {
    ".": { "entry": ["scripts/*.ts"] },
    "packages/*": { "entry": ["src/index.ts"], "project": ["src/**/*.ts"] }
  }
}
```

- **Staging on a brownfield repo:** `knip --include files,dependencies` first, then add `--include exports,types`. `knip --fix` removes unused exports and dependencies, and deletes files only with `--allow-remove-files`. Review the diff.
- A dependency used only by string (a CLI in a script, a plugin named in config) goes in `ignoreDependencies` with a comment saying where it is used.
