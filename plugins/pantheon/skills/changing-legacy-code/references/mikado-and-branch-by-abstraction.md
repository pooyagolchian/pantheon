# Mikado loop and branch by abstraction

Contents
- Mikado loop
- The `.mikado.md` file
- Saving and reverting an attempt safely
- Branch by abstraction
- Where branch by abstraction ends

## Mikado loop

For a change that breaks many things at once. The naive attempt is a probe: it tells you what has to change first, then it is thrown away.

1. Write the goal in `.mikado.md`.
2. Record a fresh base for this attempt in `.mikado.md` (below), then make the naive change straight at the goal.
3. Run the build, type checker and tests. Each distinct failure becomes a prerequisite under the node you were attempting.
4. Save the attempt as a patch. Ask the user before reverting it; revert only what the attempt changed.
5. Pick a leaf (a node with no open prerequisites). Do just that, test-first where it adds behaviour. Get green. Tick it. Offer a commit; never make one yourself.
6. Go back to step 2 with the goal (or the lowest open parent). When the goal is a leaf, do it and stop.

Keep each leaf small enough to finish green in one sitting. If a leaf grows its own failures, it is not a leaf: record them as children and revert.

## The `.mikado.md` file

```markdown
# Mikado: invoice totals use Decimal instead of float

- [ ] GOAL: Invoice.total returns Decimal
  - [ ] TaxCalculator.rate returns Decimal
    - [x] parse tax table rows as Decimal
  - [ ] PdfRenderer formats Decimal amounts
  - [ ] CSV export stops calling round() on totals

Current leaf: PdfRenderer formats Decimal amounts
Attempts:
- attempt 1: base 3f9c2e1a7b8d4c6e9f0a1b2c3d4e5f6a7b8c9d0e; naive change to Invoice.total, 7 type errors, 2 failing tests, saved as .mikado-attempt-1.patch
```

It is a working file. Do not commit it; ask the user at the end whether to keep or delete it and the patch files.

## Saving and reverting an attempt safely

The user's tree may already hold uncommitted work. `git checkout .`, `git restore .`, `git stash` and `git reset --hard` would destroy it, and `git restore -- <file>` reverts a pre-existing edit in that file too. Diff against a snapshot of the tree as it was just before the attempt instead.

Each Bash tool call is a fresh shell, so a `$base` variable set in one call is gone in the next; a fallback like `${base:-HEAD}` then diffs against `HEAD` and the reverse patch wipes every uncommitted edit in the tree. Keep the base as a literal SHA written in `.mikado.md`, never in a shell variable:

```sh
# 1. before EACH attempt (finished leaves are not committed, so an old base is stale)
git status --porcelain --untracked-files=no   # note whether this printed anything
git stash create                              # prints a SHA; touches nothing, adds no stash entry
# write that literal SHA next to the attempt in .mikado.md.
# Use HEAD only if both commands printed nothing (clean tracked tree).

# 2. ...naive attempt...

# 3. save exactly the attempt, using the literal SHA from .mikado.md
git diff --binary --no-color --no-ext-diff 3f9c2e1a7b8d4c6e9f0a1b2c3d4e5f6a7b8c9d0e > .mikado-attempt-1.patch

# 4. only after the user agrees: undo the attempt, keep everything else
git apply -R .mikado-attempt-1.patch
```

If `git stash create` printed nothing but `git status` did print changes, stop and ask; do not fall back to `HEAD`.

`git stash create` and `git diff` see tracked files only. Run `git status --short` before the attempt and do not edit files that were already untracked; list any new files the attempt creates in `.mikado.md` and delete them only with the same permission.

## Branch by abstraction

For replacing an implementation inside one codebase and one deploy: a hand-rolled parser, a pricing engine, a query path. Each step is its own green diff.

1. **Pin** the behaviour at the pinch point that uses the old implementation.
2. **Abstract**: put the old implementation behind the narrowest seam its callers need. Pure refactor.
3. **Move callers** onto the seam. Pure refactor.
4. **Build the new implementation** behind the same seam, test-first.
5. **Run the pins against both.** Expected values come from the old implementation's runs; every difference is either a bug in the new one or a behaviour the user must decide on. Report the second kind; do not pick silently.
6. **Switch the default** to the new implementation.
7. **Delete the old one.** If only one implementation is left and no test needs the seam, inline it back.

```ts
// step 2: the old parser moves behind a parameter; callers are unchanged
type ParseCsv = (text: string) => string[][];
export function importCustomers(text: string, parse: ParseCsv = legacyParseCsv): Customer[] { /* ... */ }

// step 5: one suite, both implementations
describe.each([
  ["legacy", legacyParseCsv],
  ["library", libraryParseCsv],
])("importCustomers characterisation (%s)", (_name, parse) => {
  it("characterises quoted commas", () => {
    // expected value pasted from a run against legacyParseCsv
    expect(importCustomers(QUOTED_SAMPLE, parse)).toEqual([{ name: "Smith, J", city: "Leeds" }]);
  });
});
```

Do not use named snapshots (`toMatchSnapshot()`) here: the test names differ per implementation, so the new one would silently record its own baseline instead of being compared with the old.

```python
@pytest.mark.parametrize("parse", [legacy_parse_csv, library_parse_csv])
def test_characterises_quoted_commas(parse):
    # expected value pasted from a run against legacy_parse_csv
    assert import_customers(QUOTED_SAMPLE, parse=parse) == [Customer(name="Smith, J", city="Leeds")]
```

## Where branch by abstraction ends

It stays in one process and one release. If the swap needs both versions live across deploys, a runtime flag, a change to stored data, or coordination with external consumers, it is a migration: use `deprecation-and-migration`, if installed (strangler fig, feature flags, expand-contract).
