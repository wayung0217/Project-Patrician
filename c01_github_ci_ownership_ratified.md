# Ownership note — `.github/ci/` (Owner 追認 甲／乙／丙)

**NOT merge evidence for golden.** GUT name baseline only.

## (甲) Ownership — 追認
`.github/ci/` **is** Lane2 ownership for **17-69 item 2.4**. Lane3 transplant OK.
Not C-01.

## (乙) Baseline control — implemented
1. Edits to `gut_unit_property_baseline_names.txt` → S9a §F must list each add/remove + reason.
2. Removing a name → Owner pre-approval; never same commit as product.
3. `gut-unit-gate` prints `ADDED_NAMES` / `REMOVED_NAMES` (or `無`); fails if REMOVED non-empty.
4. Rationale: no self-certify by deleting tests+baseline together.

## (丙) paths.txt — **deleted**
Chose **delete** (not wire). File was unused by `ci.yml` (dead companion). Only `gut_unit_property_baseline_names.txt` + `README.md` remain under `.github/ci/`.

## Tip / L3
- Product tip: `b998cea319a880f81647288666e0b143a01f5991`
- READY_FOR_LANE3.txt = that SHA
- L3 transplant: `ci.yml` + `.github/ci/gut_unit_property_baseline_names.txt` + `.github/ci/README.md`
- No merge
