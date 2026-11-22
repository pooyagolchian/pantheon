---
name: module-boundaries
description: Enforces module and dependency boundaries mechanically in TypeScript and Python, as CI fitness functions instead of conventions that erode. Picks feature folders, layers or ports-and-adapters; encodes dependency direction (pure domain, one public entry per feature, no import cycles) in tested dependency-cruiser, eslint-plugin-boundaries, knip, import-linter, deptry and vulture configs; ratchets a brownfield repo with a shrink-only violation baseline. Use when enforcing architecture or layering, preventing circular dependencies, setting up any of those tools, structuring folders for a new app, finding dead code, unused exports or unused dependencies, or when asked to "stop features importing each other", "add architecture tests", "find unused exports" or "why is there an import cycle".
---

# Module boundaries

A boundary nobody checks is a suggestion. This skill turns folder rules into checks that fail the build. Whether a module is worth having (deep modules, seams, the rule of three) is covered in `engineering-principles` and `codebase-design`; this skill is about making the agreed shape stick.

## Core rules

1. **Encode the rule or drop it.** Each boundary becomes a named rule in a tool that exits non-zero in CI. A rule that lives only in a README or a review comment erodes one shortcut at a time.
2. **Prove every check can fail.** Add one violation through a relative path and one through a path alias, watch both go red, then remove them. These tools pass silently when imports do not resolve or files are not parsed. A green run on a broken config looks the same as a green run on clean code.
3. **Four rules carry most of the value.** Domain code imports no infrastructure, UI or app code. A feature is imported only through its public entry. There are no runtime import cycles. Every import resolves.
4. **One gate per language.** TypeScript: dependency-cruiser for structure, knip for dead code. Python: import-linter for structure, deptry for dependencies. Linters in the editor are a convenience on top, not the gate.
5. **Brownfield: baseline, then ratchet.** Record today's violations, fail only on new ones, and make the baseline shrink-only so a fixed violation cannot come back.

## Pick the structure

- **Default for a typical web app: feature folders (vertical slices).** `features/<name>/` holds everything one capability needs. A thin `shared/` kernel holds domain-agnostic code, and `app/` is the composition root (routing, wiring, startup). Most changes then stay inside one folder, and deleting a feature is deleting a folder.
- **Layers across the whole app** (`controllers/ services/ repositories/`) only for a small CRUD app with a handful of entities and one team. Past that, every change touches every layer and the layers turn into dumping grounds.
- **Ports and adapters** for a feature with real business rules and a long life, where the domain must be tested without a database or will outlive its framework. It pays off when a port has a second adapter (often the test fake); before that it is ceremony. Apply it inside the features that need it, not app-wide.
- **Layers inside a feature** (`domain/ infra/ ui/`) appear only when the feature grows past a few files. The direction rule still applies: `domain/` imports neither `infra/` nor `ui/`.

## Dependency rules to encode

```
app/            imports anything; nothing imports app/
features/<f>/   imports shared/, and other features only through features/<g>/index.ts
  domain/       imports nothing from infra/, ui/ or app/; ideally no framework packages
  infra/, ui/   may import domain/
shared/         a leaf: imports no feature and no app code
```

- **Public entry = one explicit file.** TypeScript: `features/<f>/index.ts` with named re-exports, never `export *`. This is the "single public entry" exception that `typescript-conventions` allows to its no-barrels rule. Python: the feature package's `__init__.py`; everything else in the feature is an `_underscore` module.
- **Inside a feature, import siblings directly, never your own `index.ts`.** An internal file that imports its own entry creates a cycle through the barrel.
- **Cycles:** forbid runtime cycles. Type-only cycles vanish at runtime, so exempt them from the cycle rule. They still count for layering, because a domain annotated with an infrastructure type is still coupled to it.
- **Tests follow the same rules.** A test that reaches into another feature's internals breaks when those internals move. Its own feature's internals are fine.
- **Workspaces:** the package's `package.json` `exports` field is the public entry. Resolve with it, and a deep import like `@org/pkg/src/x` fails as unresolvable.

## Set up or tighten boundaries

1. Write the target layout (the sketch above, adapted) and map each folder to a rule.
2. Copy the config for the language: read `references/typescript.md` for dependency-cruiser, eslint-plugin-boundaries and knip, or `references/python.md` for import-linter, deptry and vulture.
3. Run it and read the summary line. dependency-cruiser prints `N modules, M dependencies cruised`, and import-linter prints `Analyzed N files`. If N is far below the file count, the config is wrong. Fix it before trusting any result.
4. Plant the two violations from core rule 2 (relative and alias), confirm both are reported, then delete them.
5. On an existing codebase, record the baseline (below) and commit it with the config.
6. Add the CI command next to the type checker, so the PR that crosses a boundary is the one that fails.

## Brownfield ratchet

- **Baseline once, commit it.** dependency-cruiser: `npx depcruise src --baseline` writes `.dependency-cruiser-known-violations.json`. import-linter: each contract's `ignore_imports` list is the baseline.
- **CI fails only on new violations.** `npx depcruise src --validate --ignore-known` and `lint-imports`.
- **Shrink-only.** Set `baseline: { staleEntriesSeverity: "error" }` in dependency-cruiser options (version 18.3+, Node 22+; for 17, see `references/typescript.md`). A fixed violation then fails CI until `npx depcruise src --baseline --baseline-mode shrink-only` removes it, and shrink-only mode never adds entries. import-linter already errors on an `ignore_imports` entry that matches nothing (`unmatched_ignore_imports_alerting` defaults to `error`).
- **Never refresh the baseline to get green.** A full `--baseline` run absorbs the new violation it should have blocked. Treat a growing baseline file in a diff as a review flag.
- **One entry per import, no wildcards** in the baseline, so a new violation in the same area cannot hide behind an old one.
- **Dead-code tools have no baseline file.** Turn knip and deptry on one issue type at a time (`knip --include files,dependencies` first, exports later). Pin the rare true exception by name (`ignoreDependencies`, deptry `per_rule_ignores`) with a comment. Prefer this to a `--max-issues` count, which lets a new issue in whenever an old one is fixed.

## Dead code and unused dependencies

- **knip** (TypeScript) reports unused files, exports and dependencies. Declare the real entry points (`entry`) and source globs (`project`). Without them it flags your app's own entry file and everything only that file reaches. Its framework plugins find config files and test files, but only when the runner (vitest, jest, playwright) is listed in `package.json`.
- **deptry** (Python) reports unused (DEP002), missing (DEP001), transitive (DEP003) and misplaced dev (DEP004) dependencies. Set `known_first_party` to your package name, or an editable install makes it report your own package as a transitive dependency.
- **vulture** (Python) finds unused functions and classes but guesses at 60% confidence for anything a framework calls by name. Use it as a report to triage, or gate it with a committed whitelist from `--make-whitelist`. Do not run it as a bare CI gate.
- When these tools run as a side effect of another change, report their findings and leave the code alone; delete only when cleanup is the task (`engineering-principles` diff discipline). Before deleting, search the repo for string-based use: dynamic imports, routes registered by filename, plugin names in config, CLI entry points in `pyproject.toml`.

## Gotchas

- **Unresolved means invisible.** An alias that the tool cannot resolve drops out of every rule. That is why `not-to-unresolvable` is in the TypeScript config: it turns a misconfigured alias into a failure instead of a silent pass.
- **eslint-plugin-boundaries without a TypeScript resolver reports nothing,** not even relative-path violations, and exits 0.
- **`no-restricted-imports` matches the import string, not the resolved file.** A `@/features/*/*` pattern does not catch `../billing/internal`. Use it to ban packages, not to enforce folder boundaries.
- **dependency-cruiser skips `.ts` files when the installed `typescript` version is one it cannot load,** then reports `0 modules cruised` and exits 0. Check `npx depcruise --info` for a tick next to typescript.
- **dependency-cruiser drops `import type` edges unless `tsPreCompilationDeps: true`.** Layering rules then miss type-level coupling.
- **`lint-imports` needs the package importable:** `pip install -e .` or `PYTHONPATH=src` in CI. Otherwise it fails with "Could not find package".
- **knip `--production` only scans entry and project globs suffixed with `!`.** Without the suffix it quietly reports fewer unused files.

## Before handing back

- [ ] Each boundary in the layout has a named rule, and the CI command for it is wired in.
- [ ] A planted relative-path violation and a planted alias violation both failed, and were removed.
- [ ] The summary's module or file count matches the size of the codebase.
- [ ] On brownfield code the baseline is committed, CI ignores only known violations, and stale entries fail.
- [ ] Dead-code findings were checked for string-based use before anything was deleted.
