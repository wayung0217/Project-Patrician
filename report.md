report.md
# 17-88 Lane V VERIFY-LONG-2 report

ASOF_HKT=2026-11-28 10:50 Asia/Hong_Kong  
Bounds: no product code change / no PR / temp verify branch NOT deleted yet (L still in_progress) (L-甲).  
Purpose: prove Lane A tip (#106) does not change long-run outputs vs brief known-fact #4 baseline.

## Tip check

```
A_PR=https://github.com/wayung0217/Project-Patrician/pull/106
A_FROZEN_TIP=59ae4cb8485805f4a717785f2a36bf7217a5c780
A_FROZEN_TREE=adc21ebce033a02bd00f5225dca1d5a717fe0dc9
TIP_AT_V1_START=59ae4cb8485805f4a717785f2a36bf7217a5c780
TIP_AT_V1_END=59ae4cb8485805f4a717785f2a36bf7217a5c780
TIP_CHANGED_DURING_V1=no
INVALIDATIONS=none
RETRIES=1 (workflow YAML parse only; product tip unchanged)
BASELINE=brief known-fact #4 (17-87 V; main≡#105; no main re-run)
```

## Runs

| side | run | conclusion | verify SHA | product base |
|---|---|---|---|---|
| v1 | [46097057464](https://github.com/wayung0217/Project-Patrician/actions/runs/46097057464) | success 3/3 | d9e0065 | 59ae4cb (PR #106) |
| fail | [46096973460](https://github.com/wayung0217/Project-Patrician/actions/runs/46096973460) | failure 0s (YAML) | e154ae8 | — (D-120e; see failed-runs.txt) |

Matrix: 450×s1, 720×s1, 720×s2. Method: push `perf-verify-1788` (paths filter on verify yml).

## V2 compare (facts)

ALL required files IDENTICAL across 3 lines × 5 files when `summary.csv` compared **sans elapsed_ms**.  
Content diffs = 0. Raw summary sha differs only in `elapsed_ms` (expected). See `v2-compare.txt`.

## V3 MET / seasons (raw; no judgement)

| line | seasons | MET-01 | MET-02 | MET-03 | MET-04 | MET-05a | MET-05b | MET-06 |
|---|---|---|---|---|---|---|---|---|
| 17-87 450×s1 | 5 | 0.06741573033708 | 0 | 0 | 0 | 0 | 1 | 0 |
| v1 450×s1 | 5 | 0.06741573033708 | 0 | 0 | 0 | 0 | 1 | 0 |
| 17-87 720×s1 | 8 | 0.06369785794814 | 0 | 0.07042253521127 | 218 | 0 | 2.05151648022107 | 0 |
| v1 720×s1 | 8 | 0.06369785794814 | 0 | 0.07042253521127 | 218 | 0 | 2.05151648022107 | 0 |
| 17-87 720×s2 | 8 | 0.06937394247039 | 0 | 0.07042253521127 | 321 | 0 | 1.92736172213601 | 0 |
| v1 720×s2 | 8 | 0.06937394247039 | 0 | 0.07042253521127 | 321 | 0 | 1.92736172213601 | 0 |

Full pass flags + summary.csv: `v3-met.txt`.

## V4 ELAPSED_MS + CPU (raw; ★ do not cross-CPU compare)

| side | line | ELAPSED_MS | CPU |
|---|---|---|---|
| v1 | 450×s1 | 765725 | AMD EPYC 9V45 96-Core Processor |
| v1 | 720×s1 | 1464718 | AMD EPYC 9V74 80-Core Processor |
| v1 | 720×s2 | 1923660 | AMD EPYC 7763 64-Core Processor |

## S9a A 基線

- Lane: V VERIFY-LONG-2 (orphan only; no product PR)
- A tip frozen: `59ae4cb8485805f4a717785f2a36bf7217a5c780` tree `adc21ebce033a02bd00f5225dca1d5a717fe0dc9`
- Temp branch: `perf-verify-1788` (shared with L; delete when both done)

## S9a B 變更清單

無產品碼變更（Lane V）。僅臨時 workflow on `perf-verify-1788`（用畢刪，等 L）。

## S9a C 規格對照

| 項 | 要求 | 本線產出 |
|----|------|----------|
| V1 | A tip 450/720×s1,s2；tip 凍結 | `v1-a-side.txt` + artifacts/v1 |
| V2 | 逐位元組比對五檔 vs known-fact #4 | `v2-compare.txt` IDENTICAL |
| V3 | 季結算數＋MET-01..06 | `v3-met.txt` |
| V4 | ELAPSED_MS＋CPU | 上表＋ v1 檔 |

## S9a D 介面清單

無（不改碼）。

## S9a E 自查掃描

N/A（無 .gd 變更）。

## S9a F 測試

未改測。長跑為 Actions M1b-Verify-1788（非 gut）。

## S9a G 排程與信號

V1 於 A tip 凍結＋CI 綠後啟動（coordinator SendToAgent）。

## S9a H 偏離與缺口

- workflow_dispatch 403 → push `perf-verify-1788` with paths filter（同 17-87）。
- 首次 push YAML 壞掉（multiline python）；retry 1 修復後成功（D-120e）。
- 首次 commit 同時加入 longrun/timing yml → 誤觸發 L/A5 重複 run；cancel 403（無 actions:write）；已請 Owner 取消。
- 標準 runner CPU 不一；耗時僅作紀錄、不跨 CPU 比較（B-11）。
- 缺口：無（比對 15/15 IDENTICAL）。
- `perf-verify-1788` 尚未刪：L run 46091383793 仍 in_progress。

## S9a I 格式／失敗執行

失敗執行：46096973460（YAML）。INVALIDATIONS：無。RETRIES：1（workflow only）。

---

## Delivered (required)

- `v1-a-side.txt`
- `v2-compare.txt`
- `v3-met.txt`
- `report.md`
- `lane.txt`
- `failed-runs.txt`
- `dispatch-v1.txt`
- `orphan_push.log` / `orphan_sha.txt` (S9d)
- store also: `artifacts/v1/`

ORPHAN=`review/overnight-17-88-V` @ 見 orphan_sha.txt
VERIFY_BRANCH=`perf-verify-1788` @ `d9e0065c5eebe474c83fd1794625ed0f8f07613d` (retained until L done)

## FILES_TOTAL
- `artifacts/v1/_scenarios/Za_G0_A0_d450_s1.json`
- `artifacts/v1/_scenarios/Za_G0_A0_d720_s1.json`
- `artifacts/v1/_scenarios/Za_G0_A0_d720_s2.json`
- `artifacts/v1/Za_G0_A0_d450_s1/combos.csv`
- `artifacts/v1/Za_G0_A0_d450_s1/commit_sha.txt`
- `artifacts/v1/Za_G0_A0_d450_s1/obs_ext.csv`
- `artifacts/v1/Za_G0_A0_d450_s1/product_base_sha.txt`
- `artifacts/v1/Za_G0_A0_d450_s1/product_tree_sha.txt`
- `artifacts/v1/Za_G0_A0_d450_s1/progress_snip.log`
- `artifacts/v1/Za_G0_A0_d450_s1/runner_specs.txt`
- `artifacts/v1/Za_G0_A0_d450_s1/scenario.json`
- `artifacts/v1/Za_G0_A0_d450_s1/season_cells.csv`
- `artifacts/v1/Za_G0_A0_d450_s1/season_ports.csv`
- `artifacts/v1/Za_G0_A0_d450_s1/sim_runner.log`
- `artifacts/v1/Za_G0_A0_d450_s1/summary.csv`
- `artifacts/v1/Za_G0_A0_d450_s1/timing.txt`
- `artifacts/v1/Za_G0_A0_d450_s1/trader_summary.csv`
- `artifacts/v1/Za_G0_A0_d450_s1/verify_side.txt`
- `artifacts/v1/Za_G0_A0_d720_s1/combos.csv`
- `artifacts/v1/Za_G0_A0_d720_s1/commit_sha.txt`
- `artifacts/v1/Za_G0_A0_d720_s1/obs_ext.csv`
- `artifacts/v1/Za_G0_A0_d720_s1/product_base_sha.txt`
- `artifacts/v1/Za_G0_A0_d720_s1/product_tree_sha.txt`
- `artifacts/v1/Za_G0_A0_d720_s1/progress_snip.log`
- `artifacts/v1/Za_G0_A0_d720_s1/runner_specs.txt`
- `artifacts/v1/Za_G0_A0_d720_s1/scenario.json`
- `artifacts/v1/Za_G0_A0_d720_s1/season_cells.csv`
- `artifacts/v1/Za_G0_A0_d720_s1/season_ports.csv`
- `artifacts/v1/Za_G0_A0_d720_s1/sim_runner.log`
- `artifacts/v1/Za_G0_A0_d720_s1/summary.csv`
- `artifacts/v1/Za_G0_A0_d720_s1/timing.txt`
- `artifacts/v1/Za_G0_A0_d720_s1/trader_summary.csv`
- `artifacts/v1/Za_G0_A0_d720_s1/verify_side.txt`
- `artifacts/v1/Za_G0_A0_d720_s2/combos.csv`
- `artifacts/v1/Za_G0_A0_d720_s2/commit_sha.txt`
- `artifacts/v1/Za_G0_A0_d720_s2/obs_ext.csv`
- `artifacts/v1/Za_G0_A0_d720_s2/product_base_sha.txt`
- `artifacts/v1/Za_G0_A0_d720_s2/product_tree_sha.txt`
- `artifacts/v1/Za_G0_A0_d720_s2/progress_snip.log`
- `artifacts/v1/Za_G0_A0_d720_s2/runner_specs.txt`
- `artifacts/v1/Za_G0_A0_d720_s2/scenario.json`
- `artifacts/v1/Za_G0_A0_d720_s2/season_cells.csv`
- `artifacts/v1/Za_G0_A0_d720_s2/season_ports.csv`
- `artifacts/v1/Za_G0_A0_d720_s2/sim_runner.log`
- `artifacts/v1/Za_G0_A0_d720_s2/summary.csv`
- `artifacts/v1/Za_G0_A0_d720_s2/timing.txt`
- `artifacts/v1/Za_G0_A0_d720_s2/trader_summary.csv`
- `artifacts/v1/Za_G0_A0_d720_s2/verify_side.txt`
- `dispatch-v1.txt`
- `failed-runs.txt`
- `lane.txt`
- `report.md`
- `v1-a-side.txt`
- `v2-compare.txt`
- `v3-met.txt`

FILES_TOTAL=55
