# E2 — `git show --cc 7d7ee47` (I3 merge #64 into int-1756)

## Merge
- SHA: `7d7ee479e4ce885ad1fd32231131eb50c3ae5620`
- Parents: `40b13ad` (I2 = #60 tip on int) + `6228d20` (#64 wp67 tip)
- Message: keep F1/F3 city-queue + market-first garrison; add WP-67 spend categories, OBS-05 columns, queue_position together.

Conflicted files (merge-tree “changed in both”):  
`autoload/building_economy.gd`, `sim/csv_out.gd`, `sim/metrics.gd`, `sim/sampler.gd`, `tests/unit/test_sys23_wp26.gd` (auto?), `tests/unit/test_wp67_garrison_obs05.gd`, `tools/golden_harness.gd`.

Full `--cc` dumps under `cc_*.txt`.

## Per-file: which side + why

### `autoload/building_economy.gd`
1. **`_try_garrison_buy`**: keep **ours (I2/#60 F3 / D-111(d))** market-first `q=MIN(FLOOR(acc/thresh), MARKET)` walk-down (no `max_affordable_qty` overstock probes → ERR-SYS04-06), **plus theirs (WP-67 D-97d)** offsetting cash post on goods failure + `_note_city_spend(..., SPEND_CAT_GARRISON)`. Combined comment cites both. Threshold arg name stays `thresh` (ours), not `acc_scale` (theirs).
2. **`_try_start_city_public`**: keep **ours (WP-65 F1)** — no invent BuildingDef; L1 via `order_build`; missing def/slot → error+stop; upgrades via `order_upgrade`. Drop theirs invent-def + direct ACTIVE create. Add theirs `_note_city_spend(..., SPEND_CAT_BUILD)` on upgrade path.

### `sim/sampler.gd` / `sim/csv_out.gd`
- **Both**: HDR/rows keep **ours** `queue_position` **and theirs** `land_rent_li` / `vacancy_tax_li` / `city_spend_json`.
- Sampler reloc/potential: keep **ours** direct WP-27/64 API calls (`relocated_in/out`, `weekly_potential_demand`) — not theirs defensive `has_method` stubs (those were for wp67-alone tip before WP-27/64 on main).

### `sim/metrics.gd`
- Drop **ours** OBS-05 gap stub rows (`gap_spend_breakdown` / `no_public_BuildingEconomy_city_spend_by_category`); keep **theirs** real OBS-05 spend breakdown once queries exist.

### `tools/golden_harness.gd`
- Trivial/`--cc` empty of conflict markers in dump (12 lines) — settled to include OBS-05 settle gate from #64 with int columns.

### `tests/unit/test_wp67_garrison_obs05.gd`
- Keep **theirs** WP-67 tests; adjusted to coexist with F3 garrison path (full `--cc` in `cc_tests_unit_test_wp67_garrison_obs05.gd.txt`).

## Why this resolution
I2 already had market-first garrison + formal city-queue; #64 adds OBS-05 spend taxonomy. Union preserves golden ERROR=0 from F3 while enabling OBS-05 columns — neither side alone is sufficient on int.
