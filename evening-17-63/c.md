# Z2 (c) Per-day eval (30 days)

**Source:** `diag_z.json` → `c_days` / `DIAG_Z_C`  
`sails_total` from diag instrument = **0** (not the blank H3 sail_sum path).

## Pattern (identical all 30 days)

| Day | evaluable_candidates | dest_excluded_no_market | explore_hit_traders | sail_count |
|-----|---------------------:|------------------------:|--------------------:|-----------:|
| 1 | 0 | 16 | 2 | 0 |
| 7 | 0 | 16 | 2 | 0 |
| 15 | 0 | 16 | 2 | 0 |
| 30 | 0 | 16 | 2 | 0 |
| … (all 1–30) | 0 | 16 | 2 | 0 |

## Reading
- Explore lottery fires (**2 traders/day** hit) but never sails — explore only skips the profit gate; it still needs ≥1 candidate.
- **evaluable_candidates = 0** every day: F2 `_dest_intel` / `board_for` returns empty → dests dropped.
- **dest_excluded_no_market = 16**: unique dest ports that had tradeable goods path but empty dest intel (union across ships = all ports appear as someone’s dest with no market intel).
- **actual sails = 0** confirmed by instrument (independent of missing `season_sail_count`).
