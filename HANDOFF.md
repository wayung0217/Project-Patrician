# 17-71 HANDOFF

Branch tip: see `orphan_sha.txt` after push.  
Main tip at closeout: `fd5eb16c8d598b7a82f31097c9fb2207c0e4ebcd`  
Main CI: `45735400939` success (9 checks).

## Merges closed
| Step | Result |
|------|--------|
| W1 #87→main | `7be70ce` · CI `45642156227` |
| ④ #83→int | merge `196c9e6` · int tip `adb30f9` · CI `45649446070` |
| W3 #86→main | merge `3fb252a` · kick tip `989db8f` · CI `45652584571` |
| ⑥ int→main | merge `fd5eb16` · CI `45735400939` · golden DIFF_CELLS=0 |

## Golden (⑥)
```
GOLDEN_BOOTSTRAP=0
COMPARED_CELLS=10013  # 527×19
DIFF_CELLS=0
IDENTICAL=1
GOLDEN_GATE PASS
```
(Push CI skips PR compare steps; numbers from local compare vs prior main artifact `45652584571`.)

## C-14 / D-45b
- Owner: C-14 = docs/spec workbook CSV exports only; scenario JSON in AI_README §9 scope.
- D-45b PASS: ac44031 add-only TOP_N; 5fc9853 add TOP_N + structural remove ABUND from overrides→grid.
- Pack: `evening-17-69-lane3/merge6_gate/`

## #86 / run_m1b_report.gd — ⑥ conflict resolve
**Rule:** L5 (#86/main) base + transplant L4 (int) `duration_s` + per-season sails/cargo.

### #86 (L5) brought
- SEED_NO_EFFECT check (§ + helpers)
- §⑥ `season_sail_count` / `season_cargo_dan` column-presence
- §⑦ `trader_sails_total` / `trader_cargo_dan_total`
- `_cargo_dan_sum` / column helpers

### L4 transplant kept
- §⑤ keeps `duration_s`; adds `cargo_dan_sum` column
- New §⑤b: `sail_sum` / `cargo_dan_sum` / `season_sails` (from `season_index`)
- Trader parse aggregates `season_sails` + sets `cargo_dan_sum`

### Impact on m1b report columns/format (next calibration)
- Table ⑤ gains `cargo_dan_sum` beside `sail_sum` / `duration_s`
- New table ⑤b exposes per-season sail map (`season:count,…`)
- L5 SEED_NO_EFFECT and season_* column probes remain — readers must not treat N/A as FAIL
- Evidence: `merge6_gate/RUN_M1B_RESOLVE.md`, `run_m1b_POST_RESOLVE.diff`, `run_m1b_RESOLVED.txt`

## ABUND_BONUS_MAX_PPM (Owner record)
**(a)** Authorized by **R9-71 中-4 / F5** (TechSpec + `dispatch-17-58.md`): remove from G0/G1/G2/G0H overrides; keep in grid (0 & 250000). Commit `5fc9853`: 「F5 ABUND_BONUS only in M1b grid」.

**(b)** Override `0` was an **Owner-approved trial** under **D-108(c)** (pause abundance accel on M1b), not a boot-validation placeholder; grid still runs 0 and 250000.

## W5 branch cleanup
Deleted: `int-1758`, #83–#87 heads (`cursor/m1b-fix-1766-3fe3`, `cursor/ci-hang-1767-866d`, `cursor/int-ci-1767-866d`, `tools-1769`, `cursor/d130-shard-golden-aeb7`).  
`int-1755-merge-0a6e` / `int-1756-295f` / `int-1757-5ae9`: absent.  
Kept all `review/*`. Extras listed only: `merge6_gate/W5_EXTRA_BRANCHES.md`.  
ls-remote before/after: `merge6_gate/ls_remote_before_w5.txt` / `ls_remote_after_w5.txt` (28→22).

## Remotes after W5 (extras remain for Owner)
`main` + all `review/*` + Owner-held extras: `diag-z-1758`, `housing-1758`, `tools-1758`, `cursor/lane-a-wp36-traders-26f5`, `cursor/ui-1755-debug-panels-ff98`.

## TD-18 (not TD-15)
Split `tests/unit/test_sys23_wp26.gd` — pure file split; L-乙; **do not merge** until Owner. See TD-18 pack path in report when ready.

## Pack index
- `evening-17-69-lane3/merge4_83/` — merge④
- `evening-17-69-lane3/merge6_gate/` — ⑥ + golden + W5 extras + ABUND
- `evening-17-69-lane3/w5_prep/` — W5 plan / ls-remote
