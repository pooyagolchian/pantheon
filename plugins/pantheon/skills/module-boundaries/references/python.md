# Python boundary configs

Contents: layout · install and CI · import-linter contracts · baseline · deptry · vulture

Each config was run against a src-layout fixture with planted violations, then against a clean tree: import-linter 2.17, deptry 0.25, vulture 2.16.

## Layout

```
src/shop/
  app/                 composition root (ASGI app, wiring); nothing imports it
  features/
    billing/
      __init__.py      the public API: explicit imports plus __all__
      _domain.py       private: only billing.* may import it
      _infra.py
    orders/
  shared/              leaf kernel: imports no feature and no app code
```

The leading underscore is what import-linter's `private_modules` contract enforces. A feature's internals are `_modules` (or `_packages`), and other features go through `shop.features.billing`.

## Install and CI

```sh
pip install -e . import-linter deptry       # or: uv pip install -e . import-linter deptry
lint-imports                                # reads [tool.importlinter] from pyproject.toml (or .importlinter)
deptry .
```

- `lint-imports` parses source without running it, but it must find the package on `sys.path`. Without the editable install or `PYTHONPATH=src`, it fails with `Could not find package 'shop' in your Python path.`
- It prints `Analyzed N files, M dependencies`. Compare N with the real file count before trusting a pass.

## import-linter: `pyproject.toml`

```toml
[tool.importlinter]
root_package = "shop"
include_external_packages = true   # needed only to forbid third-party packages (last contract)

[[tool.importlinter.contracts]]
name = "app -> features -> shared"
type = "layers"
layers = ["shop.app", "shop.features", "shop.shared"]   # higher layers may import lower, never the reverse

[[tool.importlinter.contracts]]
name = "Feature internals (_modules) are private to their feature"
type = "private_modules"
packages_with_private_modules = ["shop.features"]

[[tool.importlinter.contracts]]
name = "No cycles between features"
type = "acyclic_siblings"
ancestors = ["shop.features"]

[[tool.importlinter.contracts]]
name = "Domain is pure"
type = "forbidden"
source_modules = ["shop.features.*._domain"]
forbidden_modules = ["shop.features.*._infra", "shop.app", "sqlalchemy"]
```

- **Layers line syntax:** `"a | b"` puts independent siblings in one layer, so neither may import the other. `"a : b"` puts siblings in one layer that may import each other. `"(a)"` marks a layer optional, so it may be missing. A layers contract with `containers = ["shop.features.*"]` applies the same layer list inside every feature.
- **Indirect imports count.** `_domain -> shop.shared.util -> _infra` breaks "Domain is pure" and the report prints the chain. Use `allow_indirect_imports = true` on a forbidden contract only when you mean direct imports alone.
- **`independence`** (`modules = ["shop.features.*"]`) is the stricter alternative to `private_modules`: features may not import each other at all, even through `__init__`. Use it when features must talk only through `shared/` or events.
- **`private_modules` and `acyclic_siblings` are recent contract types.** If `lint-imports` rejects them as an unknown type, upgrade import-linter. Failing that, use `independence` for features and one `forbidden` contract per feature for internals.
- **`if TYPE_CHECKING:` imports count by default**, which is what you want for layering: an annotation on an infrastructure type is still coupling. `exclude_type_checking_imports = true` (top level) drops them everywhere, including from the layering contracts. Set it only if the codebase uses `TYPE_CHECKING` to break cycles and you accept that trade.
- `broken_contract_guidance = "..."` on a contract prints a fix hint under its violations. Use it to point at the feature's public API.

Output on a violation (exit 1):

```
Feature internals (_modules) are private to their feature BROKEN
...
- shop.features.orders.service -> shop.features.billing._infra (l.1)
```

## Baseline (brownfield ratchet)

Each contract's `ignore_imports` list is the baseline. List one exact import per entry, copied from the `BROKEN` report:

```toml
[[tool.importlinter.contracts]]
name = "app -> features -> shared"
type = "layers"
layers = ["shop.app", "shop.features", "shop.shared"]
ignore_imports = [
    "shop.shared.bad -> shop.features.orders",   # known violation; delete this line when fixed
]
```

- The run reports `KEPT (1 ignored import)`, and a new violation still breaks the contract.
- An entry that no longer matches any import fails the run with `No matches for ignored import ...`, because `unmatched_ignore_imports_alerting` defaults to `error`. The list can only shrink; do not lower that setting.
- Wildcards (`*`, `**`) are allowed in `ignore_imports`. Keep them out of a baseline, since one wildcard entry silently admits new violations.

## deptry: unused and missing dependencies

```toml
[tool.deptry]
known_first_party = ["shop"]          # else an editable install reports `shop` as DEP003 transitive

[tool.deptry.per_rule_ignores]
DEP002 = ["uvicorn"]                  # used only as a CLI in the Dockerfile, never imported
```

- Codes: DEP001 missing (imported, not declared), DEP002 unused (declared, not imported), DEP003 transitive (imported, only installed via another package), DEP004 dev dependency imported by shipped code, DEP005 standard-library module declared as a dependency.
- Default excludes cover `venv`, `.venv`, `.direnv`, `tests`, `.git` and `setup.py`. `--exclude` / `exclude` replaces that list; use `extend_exclude` to add to it.
- A package whose import name differs from its distribution name and is not installed (an optional extra) shows up as both DEP002 and DEP001. Map it in `[tool.deptry.package_module_name_map]` (`foo-python = "foo"`).
- `per_rule_ignores` is the baseline. Comment each entry with where the dependency is really used.
- deptry 0.12 replaced the older `ignore_missing` / `ignore_unused` options with `per_rule_ignores`.

## vulture: dead functions and classes (advisory)

```sh
vulture src --min-confidence 80                 # imports and unreachable code; few false positives
vulture src --make-whitelist > vulture_allow.py # once: record what is used dynamically
vulture src vulture_allow.py                    # gate: exit 0 on the recorded state, 3 on new findings
```

- At the default threshold, every function a framework calls by name (routes, fixtures, signal handlers) is reported at 60% confidence. Review the whitelist before committing it: anything really dead goes, not into the file.
- It flags a `TYPE_CHECKING` import used only in a string annotation, and `import pytest` in tests. Pass `tests/` only if you whitelist those.
