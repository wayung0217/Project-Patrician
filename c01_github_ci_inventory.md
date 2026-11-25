# .github/ci/ inventory — Owner Q (17-69 Lane2)

Tip: `c13c5bd8a64d3b3172ee578cf3ba50904be7c970` (#84)
Added in commit `2e845b9` (Lane2 item **2.4**).

| Path | Bytes | Lines | Purpose |
| --- | ---: | ---: | --- |
| `.github/ci/gut_unit_property_baseline_names.txt` | 24242 | 555 | **GUT unit+property test-name baseline** for `gut-unit-gate` (17-69 **2.4**). Bare `test_*` names. Gate: Passing ≥ 555 AND baseline ⊆ seen names (set diff). **Not** a golden CSV / not main CI artifact. |
| `.github/ci/gut_unit_property_baseline_paths.txt` | 44206 | 555 | Companion list `path::test_name` from evening-17-64 `test_names_unit_after.txt`, for S9a/report trace. **Not read by `ci.yml`.** |

Source of name list: store pack `evening-17-64/test_names_unit_after.txt` (pre-change main unit+property = 555), sorted bare names.

## Not golden
These files do **not** produce/consume `out/golden/30d.csv`. Golden baseline remains **main successful CI artifact `golden-30d`** (S9b／S9h③; Lane2 item 2.5). `.github/ci/*` is gate input for GUT name retention only.

## Producer / update / audit
- **Produced by:** Lane2 agent, commit `2e845b9`, copying evening-17-64 unit+property name list.
- **Updated by:** no auto-updater; would be a manual commit if Owner accepts a new recorded baseline.
- **Audit trail:** git history on `#84` / `cursor/ci-hang-1767-866d`; full diff `github_ci_full.diff` on orphan.

## Owner hold
Until Owner accepts: `.github/ci/*` is **NOT merge evidence** (per Owner ask).
