# Integration refresh — L2 `b998cea` + L3 `e1dd426`

## Lane2 tip
- `b998cea319a880f81647288666e0b143a01f5991` — Owner 追認 gate ADDED/REMOVED; **delete** `gut_unit_property_baseline_paths.txt`
- Also: `.github/ci/README.md` added; `ci.yml` gate prints ADDED_NAMES/REMOVED_NAMES
- Orphan tip `b77e70052ebc53407f40477f0f9f0d9b40b539b8` body `1674ed1f61fb70cf762ad3f91f2409b8b51fa458`

## Lane3 tip
- `e1dd4266d46374d8225f830a483ca21f369b2ca8` — re-transplant from L2 `b998cea`
- Diff vs int-1758: `ci.yml` + `baseline_names.txt` + `README.md` (**no paths.txt**)
- BYTE_MATCH ci.yml blob `766bcceab7bb490edc83eca2362510f829e50c5b`
- Orphan tip `0faebca4f3a640239109edd77dd7f48691378eba` body `62cfab4d346f439e78dfc350901c46646d9d32ff`

## paths.txt
- **Deleted** on L2 and absent on L3 (`PATHS_ABSENT_OK`)
- Was unused by `ci.yml` (dead companion); only names baseline remains

## C-01 / ownership
- Owner 追認(甲): `.github/ci/` **is** Lane2 2.4 ownership — **not C-01 pending**
- See `c01_github_ci_ownership_ratified.md`

## I1 / I2
- I1 `b998cea`→main: clean
- I2 `e1dd426`→int: clean

## I3 note
- Post-rebase reset `ci.yml` to blob **`766bcceab7bb490edc83eca2362510f829e50c5b`** (was `2abeb9f`; tip moved)

## No merge
