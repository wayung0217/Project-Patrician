# 4.3 season_sail_count / season_cargo_dan vs trader_summary

## Wiring (product on tip, L4-owned)

| Layer | API / field |
|-------|-------------|
| `TraderRegistry.season_sail_count(port_id, season_index) -> int` | `_season_sails["si\|port"]` incremented in `_record_season_sail` on successful sail |
| `TraderRegistry.season_cargo_dan(port_id, season_index) -> Dictionary` | good_id → dan from same record |
| `SimSampler._sample_trader_row` | calls both → row `sail_count`, `cargo_dan_json` |
| `SimCsvOut._write_trader_summary` | `trader_summary.csv` columns: `sail_count`, `cargo_dan_json` |

So **trader_summary.sail_count ≡ season_sail_count** and **cargo_dan_json ≡ JSON(season_cargo_dan)** per (season, port).

## Totals — pre-fix baseline (z-1758-2)

From `evening-17-63/z-1758-2/groups/*/trader_summary.csv` (int before D-123):

| Group | Rows | Σ sail_count | cargo |
|-------|------|--------------|-------|
| Za_G0_A0 … Za_G2_A250 | 320 each | **0** | `{}` |
| Zb_G0_notrader | 320 | **0** | `{}` |
| Zc_G0H_A0 | 320 | **0** | `{}` |
| Zd_G0_seed2 | 320 | **0** | `{}` |

Sample head: `z1758_2_trader_summary_head.csv`. Matches 17-63 DIAG (explore_hit>0, sails=0 / empty board).

## Totals — post-fix on #83

- Unit K4: asserts `sail_sum ≥ 1` and `cargo_total ≥ 1` under formal seed (not via trader_summary CSV in the mini path; direct `_process_ship_day` + plan qty).
- **Full 9×5y z-1758-3 matrix not run** (H1: no merge/tag until Owner accepts packs).
- Post-fix trader_summary Σ sails/cargo for matrix: **deferred** — Integration / Owner Z after pack accept.

## Consistency claim

Once a sail records via `_record_season_sail`, sampler totals must match registry queries for the same (season, port). Pre-fix zeros were empty-board cold-start, not a sampler/registry mismatch.

## Raw outputs (★ 特别证据)

- Pre-fix CSVs: `trader_summary_raw/z1758_2_Za_G0_A0_trader_summary.csv`, `…_Zd_G0_seed2_…`
- Per-group totals: `trader_summary_raw/z1758_2_totals.json` (all sails=0 / cargo=0)
- Post-fix matrix CSV: deferred (H1); unit K4 proves sail+cargo ≥1 under seed
