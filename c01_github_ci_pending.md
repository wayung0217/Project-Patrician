【已被 Owner 追認取代】C-01 pending 已廢止；見 c01_github_ci_ownership_ratified.md（甲：`.github/ci/` 屬 Lane2 2.4）。

# Ownership / C-01 note — `.github/ci/` (NOT merge evidence)

**Status:** Pending Owner acceptance. Until Owner accepts, `.github/ci/*` is **NOT merge evidence**.

## What
Full diff: `github_ci_full.diff` = `git diff origin/main...c13c5bd8a64d3b3172ee578cf3ba50904be7c970 -- .github/ci/` (same content as `git diff origin/main -- .github/ci/` when checked out at tip).

Files (only these two):
- `.github/ci/gut_unit_property_baseline_names.txt` — 555 bare test names
- `.github/ci/gut_unit_property_baseline_paths.txt` — 555 `path::name` companions

## Lane / sub-item
- **Lane 2**
- Support for **17-69 item 2.4** (gut-unit-gate: ≥ baseline count + old-name set-diff; replaces hard `==555`)
- `ci.yml` reads **only** `gut_unit_property_baseline_names.txt`
- `gut_unit_property_baseline_paths.txt` is unused by workflow (report companion)

## C-01
17-69 Lane2 ownership list names: `.github/workflows/ci.yml`, `autoload/cash_ledger.gd`, new `tests/unit/` files.
**`.github/ci/` is not in that ownership list** → **C-01 pending Owner** (path out of stated ownership; added as 2.4 gate support).

## Not golden
Not a golden CSV / not main CI `golden-30d` artifact. Golden baseline remains main successful CI artifact only (S9b／S9h③; item 2.5).

## Product tip
`c13c5bd8a64d3b3172ee578cf3ba50904be7c970` on `cursor/ci-hang-1767-866d` / PR #84. No merge.
