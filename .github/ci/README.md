# `.github/ci/` — Lane2 ownership (17-69 2.4; Owner 追認 甲)

## Files
- `gut_unit_property_baseline_names.txt` — recorded unit+property bare test-name baseline (555 at intro). Used by `gut-unit-gate`.

## Baseline control (Owner 追認 乙)
1. Any edit to `gut_unit_property_baseline_names.txt` → S9a §F must list every added/removed name with a reason.
2. Removing any name requires **Owner pre-approval**; never in the same commit as product-code changes.
3. `gut-unit-gate` prints `ADDED_NAMES` and `REMOVED_NAMES` (or `無`); not totals alone.
4. Rationale: prevent self-certifying by deleting tests and shrinking the baseline together.

## Not golden
This is **not** the 30d golden CSV baseline. Golden compare uses main CI artifact `golden-30d` only (S9b／S9h③).
