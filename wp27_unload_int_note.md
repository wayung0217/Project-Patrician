# WP27 unload / ERR-SYS08-08 — #85 int gap (Lane2 note)

## Symptom (#85 gut-unit shard)
ERR-SYS08-08 "season not open" Unexpected Errors when BuildingEconomy stays `_loaded`
from co-located WP-18/19 in the same GUT process; SimMetrics._obs05 → public_upgrade_fee.

## Fix location (L2-owned)
- File: `tests/unit/test_sys23_wp27.gd` only (not `cash_ledger.gd`)
- Commit on #84: `1a3e5f144a99fbcb157c14e7766d6da42c121714`
  `fix(17-67): WP27 unload BuildingEconomy between tests`
- Mechanism: `before_each` / `after_each` set `BuildingEconomy._loaded = false` when loaded

## Presence check (blobs)
| Ref | tip | test_sys23_wp27.gd blob | unload? |
| --- | --- | --- | --- |
| #84 `cursor/ci-hang-1767-866d` | `bb1b50d…` | `2883dc5…` | **YES** |
| `main` | `191a7ee…` | `f2fbeaf…` | no |
| `int-1758` | `71b094d…` | `f2fbeaf…` | no |
| #85 `cursor/int-ci-1767-866d` | `1182da0…` | `f2fbeaf…` | no |

## Lane3 constraint
#85 is CI-only transplant — L3 must **not** add product/tests. Unload cannot ship via #85.

## Integration / Owner path (no Lane2 merge)
1. Preferred: merge/land #84 → `main` (after Owner evening OK) → bring into `int-1758` (or re-base int).
2. Or separate Owner-approved cherry-pick of `1a3e5f1` onto int (product/test commit — not L3).
3. Until then, #85 gut-unit(3) may keep failing ERR-SYS08-08 on WP27; not a Lane3 CI transplant defect.

## GOLDEN_BASE_MISSING
`golden-30d` on #84/#85 fails with GOLDEN_BASE_MISSING until **main** has a successful green golden artifact. Intentional 2.5 behavior; not fixed by L2/L3 tips. No merge from Lane2.
