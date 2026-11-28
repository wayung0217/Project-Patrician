report.md
# 17-88 Lane L LONG-RUN report

ASOF_HKT=2026-11-28 Asia/Hong_Kong  
Bounds: no product code change / no PR / L-甲. Facts only (B-12).  
Purpose: long metrics + daily elapsed curve on sped-up sim (#105 tip trader_registry).

## Tip / product

```
PRODUCT_COMMIT=107c17fea29da54363713e5896805a2ebd630a0e
PRODUCT_TREE=7b533dd0b03b885aefcc357465dea8be06892a52
TRADER_REGISTRY_BLOB=3df59445ae15ff5eee2f97a0e6d48d977c931352
WORKFLOW_BRANCH=perf-verify-1788
WORKFLOW_COMMIT_AT_L1=6d1ad7331166f3a5eb366d7631f3f24bbccaa630
AUTHORITATIVE_RUN=46091383793
URL=https://github.com/wayung0217/Project-Patrician/actions/runs/46091383793
```

## L0 limits

```
years=5
warmup_years=1
DAYS_PER_YEAR=360
DAYS_LIMIT_YEARS_X_360=1800
BRIEF_EXPECTED_LIMIT=3600
ACTUAL_VS_EXPECTED=actual 1800; expected 3600 not matched
FRM-SYS23-07: 1800d → 20 seasons, eval_seasons=16; 3600d → 40 seasons, eval_seasons=36 (warmup_years=1, SEASONS_PER_YEAR=4)
NOTE: L1 still ran --days 3600 via days_override (sim_engine absolute total_days); scenario years/params/seeds unchanged
```

See `l0-limits.txt`.

## Runs

| line | run | job | conclusion | workflow SHA | product base |
|---|---|---|---|---|---|
| d1800×s1 | [46091383793](https://github.com/wayung0217/Project-Patrician/actions/runs/46091383793) | za-g0-a0-longrun (1800, 1) | success | 6d1ad73 | 107c17f (#105) |
| d3600×s1 | same | za-g0-a0-longrun (3600, 1) | success | 6d1ad73 | 107c17f (#105) |

Method: push `perf-verify-1788` (workflow_dispatch 403). Shared with Lane V.

### Duplicate (ignored)

V force-push `e154ae8` re-triggered M1b-Longrun-1788 as run `46096974533` (wrong checkout = A tip). Cancel attempted → HTTP 403 (no actions:write). Authoritative = `46091383793` only. No shortened-day restart.

## L3 sizes + sha256 (facts)

### d1800×s1

| file | bytes | sha256 |
|---|---:|---|
| summary.csv | 496 | fc2d91a2824661e727467361676b019b21c15c86ae1360d683a79f0e0539de8d |
| season_ports.csv | 88683 | c03e64960a73565317d51dcf9518b8b230212c413c2058ba6f5e7624d568e132 |
| season_cells.csv | 436991 | 6105f5855f9cd906c3048e678a77d3698259f307be13a7d3a487d29c123ab655 |
| trader_summary.csv | 48758 | 5f006e8248b16c000e55132586a5828d89da15c02eef5d9c97cce67992d20fa1 |
| obs_ext.csv | 70439 | 8bd0b3c19327e58057edd812390c4bad2b80ac8e4dce84db5be84142596beabf |

season_ports season_index count = 20 (0..19)

### d3600×s1

| file | bytes | sha256 |
|---|---:|---|
| summary.csv | 483 | 92b716b27d5b072befae3a93856237b22c00bfaed85b6baa8244e7050c7d9827 |
| season_ports.csv | 176757 | d35b44bf606fd95275b028082760dd935da45e86e1706556f5770d3724cd4477 |
| season_cells.csv | 875081 | 11fecc60f1e1ef430139f01baad6caedab0ab516a1cfaaaa9eff7ccf02232dd4 |
| trader_summary.csv | 91450 | 02a5e653f8650d73424b30692f45733745289dfeff3676df860a5ed9bb5218c0 |
| obs_ext.csv | 156714 | 2ac2023441ae24c2feb0ac7ccf0616147126e17d3f25e328b47650318972105c |

season_ports season_index count = 40 (0..39)

Full sha256 lines: `l1-d1800.txt`, `l1-d3600.txt`.

## MET-01..06 (final summary.csv only; raw)

| line | seasons | MET-01 | MET-02 | MET-03 | MET-04 | MET-05a | MET-05b | MET-06 |
|---|---:|---|---|---|---|---|---|---|
| d1800×s1 | 20 | 0.06144306651635 | 10 | 0.53333333333333 | 235 | 0 | 3.63346827174155 | 0 |
| d3600×s1 | 40 | 0.05948653725736 | 15 | 0 | 202 | 0 | 6.62841302773958 | 0 |

GAP: per-evaluation-season MET-01..06 series — runner emits final values only in summary.csv one row. No code change (L3).

## ELAPSED_MS + CPU (raw; ★ do not cross-CPU compare)

| line | ELAPSED_MS | WALL duration_s | CPU |
|---|---:|---:|---|
| d1800×s1 | 4163596 | 4165 | AMD EPYC 9V74 80-Core Processor |
| d3600×s1 | 6794658 | 6797 | AMD EPYC 9V45 96-Core Processor |

## Daily elapsed curve (from progress_timed DAY_PROGRESS UTC)

See `l3-curve.txt` (full). Milestones cum_elapsed_s:

d1800: 1=59, 30=193, 90=347, 180=576, 360=1007, 720=1878, 1080=2736, 1440=3509, 1800=4164  
d3600: 1=44, 30=172, 90=313, 180=518, 360=940, 720=1728, 1080=2521, 1440=3218, 1800=3905, 2160=4542, 2520=5152, 2880=5730, 3240=6286, 3600=6796

## S9a A 基線

- Lane: L LONG-RUN (orphan only; no product PR)
- Product: `#105` tip `107c17f` tree `7b533dd` trader_registry blob `3df59445…`
- Temp branch: `perf-verify-1788` @ L1 start `6d1ad73` (workflow-only; shared with V — not deleted by L)

## S9a B 變更清單

無產品碼變更。僅臨時 workflow `.github/workflows/m1b-longrun-1788.yml` on `perf-verify-1788`。

## S9a C 規格對照

| 項 | 要求 | 本線產出 |
|----|------|----------|
| L0 | years×360 limit + FRM-SYS23-07 | `l0-limits.txt` |
| L1 | 1800×s1 + 3600×s1 parallel | run 46091383793 success 2/2 |
| L2 | --season-progress + --day-progress; UTC stamp → progress_timed | `progress_timed_d1800.txt`, `progress_timed_d3600.txt` |
| L3 | sizes/sha256, MET, curve | `l1-d*.txt`, `l3-curve.txt` |
| L4 | fail handling | authoritative success; duplicate noted |
| L5 | no metric judgement | this report |

## S9a D 介面清單

無（不改碼）。

## S9a E 自查掃描

N/A（無 .gd 變更）。

## S9a F 測試

未改測。長跑為 Actions M1b-Longrun-1788（非 gut）。

## S9a G 排程與信號

L∥B/Q at T0 on #105 tip. V later force-pushed same branch; L kept original run.

## S9a H 偏離與缺口

- years×360 actual=1800 (brief expected 3600); still ran --days 3600 via days_override.
- per-season MET series: GAP (final only).
- duplicate run 46096974533: cancel 403; ignored.
- CPUs differ across the two jobs; no cross-CPU compare (B-11).
- `perf-verify-1788` left for V (not deleted by L).

## S9a I 格式／失敗執行

Authoritative failures: none. Retries: 0. Duplicate uncancellable by agent token: see `failed-runs.txt`.

---

## Delivered (required)

- `l0-limits.txt`
- `l1-d1800.txt`
- `l1-d3600.txt`
- `l3-curve.txt`
- `progress_timed_d1800.txt` / `progress_timed_d3600.txt`
- `report.md`
- `lane.txt`
- `orphan_push.log` / `orphan_sha.txt` (S9d)
- store also: `dispatch-l1.txt`, `failed-runs.txt`, `artifacts/d1800/`, `artifacts/d3600/`, `artifacts/_scenarios/`

ORPHAN=`review/overnight-17-88-L` @ `dad6dfb7b44bd725342f21fe9d18c833d7a4091f`  
VERIFY_BRANCH: `perf-verify-1788` retained for Lane V (L did not delete).

## FILES_TOTAL

FILES_TOTAL=49

- `artifacts/_scenarios/Za_G0_A0_d1800_s1.json`
- `artifacts/_scenarios/Za_G0_A0_d3600_s1.json`
- `artifacts/d1800/combos.csv`
- `artifacts/d1800/commit_sha.txt`
- `artifacts/d1800/day_progress_tail.log`
- `artifacts/d1800/obs_ext.csv`
- `artifacts/d1800/product_base_sha.txt`
- `artifacts/d1800/product_tree_sha.txt`
- `artifacts/d1800/progress_snip.log`
- `artifacts/d1800/progress_timed.txt`
- `artifacts/d1800/runner_specs.txt`
- `artifacts/d1800/scenario.json`
- `artifacts/d1800/season_cells.csv`
- `artifacts/d1800/season_ports.csv`
- `artifacts/d1800/sim_runner.log`
- `artifacts/d1800/summary.csv`
- `artifacts/d1800/timing.txt`
- `artifacts/d1800/trader_registry_blob.txt`
- `artifacts/d1800/trader_summary.csv`
- `artifacts/d3600/combos.csv`
- `artifacts/d3600/commit_sha.txt`
- `artifacts/d3600/day_progress_tail.log`
- `artifacts/d3600/obs_ext.csv`
- `artifacts/d3600/product_base_sha.txt`
- `artifacts/d3600/product_tree_sha.txt`
- `artifacts/d3600/progress_snip.log`
- `artifacts/d3600/progress_timed.txt`
- `artifacts/d3600/runner_specs.txt`
- `artifacts/d3600/scenario.json`
- `artifacts/d3600/season_cells.csv`
- `artifacts/d3600/season_ports.csv`
- `artifacts/d3600/sim_runner.log`
- `artifacts/d3600/summary.csv`
- `artifacts/d3600/timing.txt`
- `artifacts/d3600/trader_registry_blob.txt`
- `artifacts/d3600/trader_summary.csv`
- `dispatch-l1.txt`
- `failed-runs.txt`
- `l0-limits.txt`
- `l1-d1800.txt`
- `l1-d3600.txt`
- `l3-curve.txt`
- `lane.txt`
- `ls-tree.txt`
- `orphan_push.log`
- `orphan_sha.txt`
- `progress_timed_d1800.txt`
- `progress_timed_d3600.txt`
- `report.md`
