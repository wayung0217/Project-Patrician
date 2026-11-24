# ⑥ conflict resolve — tools/run_m1b_report.gd

## Rule
L5 (#86/main) base + transplant L4 (int) `duration_s` + per-season sails/cargo.

## Keep (L5)
- SEED_NO_EFFECT / `_SEED_PAIRS` / `_SEED_METRIC_KEYS` / `_append_seed_no_effect`
- §⑥ `season_sail_count` / `season_cargo_dan` column-presence checks
- §⑦ `trader_sails_total` / `trader_cargo_dan_total`
- `_cargo_dan_sum`, `_column_*` helpers
- All ①–④ report tables

## Transplant (L4)
- `duration_s` already on L5 — kept in §⑤; §⑤ gains `cargo_dan_sum` column (L4)
- New §⑤b table: `sail_sum` / `cargo_dan_sum` / `season_sails`
- Trader parse: aggregate `season_sails` from `season_index` + set `cargo_dan_sum`

## Drop (L4-only shape not kept as replacement)
- Replacing L5 §⑥/⑦ with L4-only §⑥ — **not done**; L5 sections retained
- L4 `_cargo_dan_total` — not needed; L5 `_cargo_dan_sum` used

## Artifacts
- `run_m1b_L5_main.txt` / `run_m1b_L4_int.txt` / `run_m1b_CONFLICTED.txt`
- `run_m1b_RESOLVED.txt` (full final file)
- `run_m1b_POST_RESOLVE.diff` (vs main L5)
