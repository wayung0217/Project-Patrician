# 17-90 Lane P DIAG-PORTS report

ASOF_HKT=2026-11-28 Asia/Hong_Kong  
Bounds: no merge / no PR / no force-push / facts only (B-7).  
Product pin `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6`. Probe branch `diag-ports-1790` (deleted after pack).

## Delivered

- `p0-baseline.txt`
- `p1-probe-diff.txt`
- `p2-determinism.txt`
- `p3-skip-reasons.txt`
- `p4-route-matrix.txt`
- `p5-explore.txt`
- `failed-runs.txt`
- `lane.txt`
- `report.md` — this file
- `artifacts/` — Actions extract + probe raw
- `orphan_sha.txt` / `orphan_push.log` (S9d)

## Actions

| what | id | status |
|------|-----|--------|
| M1b-Diag-Ports-1790 | [46111718300](https://github.com/wayung0217/Project-Patrician/actions/runs/46111718300) | completed success (1/1) |

## Probe branch

- Created `diag-ports-1790` from `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6`
- SHA Actions `c59170d30a2102788f23f2116c8006ca33f8a288`
- Workflow `.github/workflows/diag-ports-1790.yml` (paths filter)
- No PR opened
- Deleted after pack assembly (authorized B-5)

## CPU (B-8)

| job | cpu_model | duration_s |
|-----|-----------|------------|
| za-g0-a0-diag-ports | AMD EPYC 9V74 80-Core Processor | 1063 |

## P0 baseline

```
PRODUCT_BASE=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6
PRODUCT_TREE=079aad6732ea1125a862d1bb9bb970921f2acfd9
TRADER_REGISTRY_BLOB_AT_BASE=3df59445ae15ff5eee2f97a0e6d48d977c931352
EXPECTED_BLOB=3df59445ae15ff5eee2f97a0e6d48d977c931352
BLOB_MATCH=yes
```

## P1 probe (count-only)

Files touched (diff in `p1-probe-diff.txt`):

- `sim/m1b_diag_ports.gd` (new; gated `M1B_DIAG_PORTS=1`)
- `autoload/trader_registry.gd` (note_* calls only; control flow unchanged)
- `sim/sim_engine.gd` (begin/finish)
- `.github/workflows/diag-ports-1790.yml`

Skip reason names are probe-added (aa098a8 had no product `skip.*` counters).

## P2 determinism vs review/overnight-17-88-L d1800 seasons 0–3

```
PROGRESS: 34451/1024, 34429/1960, 34092/3109, 33717/4054 — all equal
season_ports.csv season_index 0..3 — byte_identical=True
trader_summary.csv season_index 0..3 — byte_identical=True
P2_DETERMINISM=PASS
PROBE_CHANGED_OUTPUT=no
```

Raw: `p2-determinism.txt`.

## P3 skip reasons (job totals; raw)

```
skip.market_qty=5868735
skip.no_intel=3369603
skip.weekly_demand=168924
skip.decide_idle=22183
skip.afford=3299
skip.other=47
```

`skip.entry` / `skip.draft` / `skip.good_admit` / `skip.hold_full` / `skip.q_lt1` / `skip.quote_err` / `skip.buy_cost` / `skip.buy_fail` / `skip.sail_fail` / `skip.no_voyage` absent from job totals (=0). Season×port×dest counts: `p3-skip-reasons.txt`. Full day rows: `artifacts/d360/probe/diag_ports_skip_reasons.txt`.

## P4 route matrix

Season P→D `cand_enter` / `sailed` + MATRIX blocks: `p4-route-matrix.txt`.

## P5 explore

Daily `EXPLORE_N` + event lines: `p5-explore.txt` (from `diag_ports_explore.txt`).

## S9a A 基線

```
BRANCH=diag-ports-1790 (temp; deleted)
HEAD_SHA=c59170d30a2102788f23f2116c8006ca33f8a288
BASE_SHA=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6
DOCS_SPEC_AT_BASE=v6.99.293
AI_README_CSV_BLOB=31c1eee809f8abf46469c03addf82a6454379cee
MAIN_BASELINE_TESTS=not re-run (probe lane; no merge; L-甲-adjacent diag)
```

## S9a B 變更清單

```
 .github/workflows/diag-ports-1790.yml | 163 +
 autoload/trader_registry.gd           |  45 +-
 sim/m1b_diag_ports.gd                 | 344 +
 sim/sim_engine.gd                     |   5 +
 4 files changed, 554 insertions(+), 3 deletions(-)
```

產品碼：`autoload/trader_registry.gd`、`sim/m1b_diag_ports.gd`、`sim/sim_engine.gd`。測試與 fixture：無。目錄外：無（workflow 在 `.github/`）。

## S9a C 規格對照

| ID | 實作 | 測試 |
|----|------|------|
| FRM-SYS17-02 候選剔除路徑 | probe counts at existing continues in `_evaluate_and_maybe_sail` | 無（探測） |
| FRM-SYS17-04 探索 | `note_explore_picks` / explore event lines | 無 |
| D-120(e) 失敗列原因 | `failed-runs.txt` | n/a |
| P2 決定性 | vs 17-88 L d1800 s0–3 | PASS |

未實作修法／參數變更（本包禁止）。

## S9a D 介面清單

新增 `class_name M1bDiagPorts`（`sim/m1b_diag_ports.gd`）靜態 API：`begin_from_env` / `set_day` / `note_*` / `finish`。環境變數 `M1B_DIAG_PORTS`、`M1B_DIAG_PORTS_OUT`。無 Autoload／`project.godot` 變更。依據：本包探測派工（未經產品裁決編號；臨時分支刪除）。

## S9a E 自查掃描

Probe lane — 完整掃描未在 Actions 跑 GUT。Diff 僅加計數呼叫與新檔；未改排序／亂數／既有 CSV 寫入路徑。P2 位元組對照通過。

## S9a F 測試

新增／刪除／改內容測試：無。CI：僅 `M1b-Diag-Ports-1790` run `46111718300` success @ `c59170d`.

## S9a G 排程與信號

未改 SimLoop 步驟順序；未改信號。`sim_engine` 僅在 boot/finish 呼叫 `M1bDiagPorts.begin_from_env`／`finish`。

## S9a H 偏離與缺口

- aa098a8 無既有 `skip.*` 計數器 → 探測新增名稱（brief 允許）。
- 日級 skip 原始檔 4.6MB；交付 `p3` 放季彙總＋job totals，全日原始在 `artifacts/`。
- 不下「為什麼／該怎麼改」判斷（B-7）。

## S9a I 格式／失敗執行

Authoritative failures: none. Retries: 0. See `failed-runs.txt`.

---

## Orphan delivery (S9d)

- branch: `review/overnight-17-90-P`
- full SHA: `52c316ee3db99d0718f28b0947568ec55bb49946`
- see `orphan_sha.txt` / `orphan_push.log` / `ls-tree.txt`

## FILES_TOTAL

FILES_TOTAL=37

- `artifacts/_scenarios/Za_G0_A0_d360_s1.json`
- `artifacts/d360/baseline_trader_blob.txt`
- `artifacts/d360/combos.csv`
- `artifacts/d360/commit_sha.txt`
- `artifacts/d360/day_progress_tail.log`
- `artifacts/d360/diag_ports_lines.txt`
- `artifacts/d360/obs_ext.csv`
- `artifacts/d360/probe/diag_ports_explore.txt`
- `artifacts/d360/probe/diag_ports_idle_eval.txt`
- `artifacts/d360/probe/diag_ports_job_totals.txt`
- `artifacts/d360/probe/diag_ports_route_matrix.txt`
- `artifacts/d360/probe/diag_ports_skip_reasons.txt`
- `artifacts/d360/product_base_sha.txt`
- `artifacts/d360/product_tree_sha.txt`
- `artifacts/d360/progress_snip.log`
- `artifacts/d360/progress_timed.txt`
- `artifacts/d360/runner_specs.txt`
- `artifacts/d360/scenario.json`
- `artifacts/d360/season_cells.csv`
- `artifacts/d360/season_ports.csv`
- `artifacts/d360/sim_runner.log`
- `artifacts/d360/summary.csv`
- `artifacts/d360/timing.txt`
- `artifacts/d360/trader_registry_blob.txt`
- `artifacts/d360/trader_summary.csv`
- `failed-runs.txt`
- `lane.txt`
- `ls-tree.txt`
- `orphan_push.log`
- `orphan_sha.txt`
- `p0-baseline.txt`
- `p1-probe-diff.txt`
- `p2-determinism.txt`
- `p3-skip-reasons.txt`
- `p4-route-matrix.txt`
- `p5-explore.txt`
- `report.md`
