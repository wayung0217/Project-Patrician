# `.github/ci/` — Lane2 ownership (17-69 2.4; Owner 追認 甲)

## Files
- `gut_unit_property_baseline_names.txt` — recorded unit+property bare test-name baseline (555 at intro). Used by `gut-unit-gate`.

## Baseline control (Owner 追認 乙)
1. Any edit to `gut_unit_property_baseline_names.txt` → S9a §F must list every added/removed name with a reason.
2. Removing any name requires **Owner pre-approval**; never in the same commit as product-code changes.
3. `gut-unit-gate` prints `ADDED_NAMES` and `REMOVED_NAMES` (or `無`); not totals alone.
4. Rationale: prevent self-certifying by deleting tests and shrinking the baseline together.

## Golden bootstrap (17-69 W1(c) S9b)
- `golden_30d_bootstrap_1764.csv` + `.sha256` — evening-17-64 frozen 30d CSV
  (`sha256` prefix `8b25c951…`). Used **only** when a PR cannot download a
  non-expired `golden-30d` artifact from `main`. Compare then prints
  `GOLDEN_BOOTSTRAP=1` and `DIFF_CELLS`. When main has the artifact, bootstrap
  is not used (`GOLDEN_BOOTSTRAP=0`).

## Not the primary golden baseline
Primary compare uses main CI artifact `golden-30d` (S9b／S9h③). Bootstrap is
the S9b exception path only.
