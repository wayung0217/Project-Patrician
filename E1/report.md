# E1 — `git show` of #60 follow-up commits

## SHAs
- `423437d81526897946b0b7be78c606a70f435839` — fix(wp65): stop city queue when step cost<=0
- `d6bb0a6a9590aa6b2e2a19c403436658a995e4b3` — test(wp65): restore formal data before formal asserts

Full dumps: `423437d.show.txt`, `d6bb0a6.show.txt`.

## 423437d (product)
- File: `autoload/building_economy.gd` only (+5/−2).
- In `_season_city_build_queue`: after computing PUBLIC / upgrade cash, adds `if cost <= 0: break` before the affordability gate.
- Intent (commit msg): F2 removed fixture queue-clear bypass; `order_upgrade` → `CashLedger.post(0)` when upgrade fee is 0 (pop=0) floods SYS23/WP26 Unexpected Errors (ERR-SYS05-05 rejects amount 0). Stop without inventing ERR (D-111(c) gaps).
- Note for F1/D-113(b): this “cost≤0 → stop” is exactly what R9-69 replaces — cost=0 must still start + advance `queue_pos` + skip cash post; only cost<0 → ERR-SYS08-09 stop.

## d6bb0a6 (test-only)
- File: `tests/unit/test_sys08_wp65_d97a.gd` (+24).
- Adds `_restore_formal_data_trees_from_git()`: `git checkout HEAD --` for `data/build_queue`, `data/opening_public`, `data/opening_population`, `data/city_center` before formal asserts.
- Why: sim_loop / SYS23 / trade_desk suites wipe `res://data` build_queue tres mid-run; re-checkout keeps D-111(b) formal listing green without editing docs/spec blank rows.
