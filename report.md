report.md
# 17-87 Lane V VERIFY-LONG report

ASOF_HKT=2026-11-28 Asia/Hong_Kong  
Bounds: no product code change / no PR / temp verify branch deleted when done (L-甲).  
Purpose: prove Lane A tip does not change long-run outputs vs main (incl. MET seasons).

## Tip check

```
MAIN_CLAIM=dcea87f338f3bea4b49197ce3cbb1c407a28a250
MAIN_ACTUAL=dcea87f338f3bea4b49197ce3cbb1c407a28a250
MATCH=yes
A_PR=https://github.com/wayung0217/Project-Patrician/pull/105
A_FROZEN_TIP=107c17fea29da54363713e5896805a2ebd630a0e
A_FROZEN_TREE=7b533dd0b03b885aefcc357465dea8be06892a52
TIP_AT_V1_START=107c17fea29da54363713e5896805a2ebd630a0e
TIP_AT_V1_END=107c17fea29da54363713e5896805a2ebd630a0e
TIP_CHANGED_DURING_V1=no
INVALIDATIONS=none
RETRIES=0
```

## Runs

| side | run | conclusion | verify SHA | product base |
|---|---|---|---|---|
| v0 | [46032156698](https://github.com/wayung0217/Project-Patrician/actions/runs/46032156698) | success 3/3 | ceedbef | dcea87f (main) |
| v1 | [46057243679](https://github.com/wayung0217/Project-Patrician/actions/runs/46057243679) | success 3/3 | 8a5391b | 107c17f (PR #105) |

Matrix each side: 450×s1, 720×s1, 720×s2. Method: push `perf-verify-1787` (workflow_dispatch 403).

## V2 compare (facts)

ALL required files IDENTICAL across 3 lines × 5 files when `summary.csv` compared **sans elapsed_ms**.  
Content diffs = 0. Raw summary sha differs only in `elapsed_ms` (expected). See `v2-compare.txt`.

## V3 MET / seasons (raw; no judgement)

| line | seasons | MET-01 | MET-02 | MET-03 | MET-04 | MET-05a | MET-05b | MET-06 |
|---|---|---|---|---|---|---|---|---|
| v0 450×s1 | 5 | 0.06741573033708 | 0 | 0 | 0 | 0 | 1 | 0 |
| v1 450×s1 | 5 | 0.06741573033708 | 0 | 0 | 0 | 0 | 1 | 0 |
| v0 720×s1 | 8 | 0.06369785794814 | 0 | 0.07042253521127 | 218 | 0 | 2.05151648022107 | 0 |
| v1 720×s1 | 8 | 0.06369785794814 | 0 | 0.07042253521127 | 218 | 0 | 2.05151648022107 | 0 |
| v0 720×s2 | 8 | 0.06937394247039 | 0 | 0.07042253521127 | 321 | 0 | 1.92736172213601 | 0 |
| v1 720×s2 | 8 | 0.06937394247039 | 0 | 0.07042253521127 | 321 | 0 | 1.92736172213601 | 0 |

Full pass flags + summary.csv: `v3-met.txt`.

## V4 ELAPSED_MS + CPU (raw; ★ do not cross-CPU compare)

| side | line | ELAPSED_MS | CPU |
|---|---|---|---|
| v0 | 450×s1 | 8929486 | AMD EPYC 7763 64-Core Processor |
| v0 | 720×s1 | 9240194 | Intel(R) Xeon(R) 6973P-C |
| v0 | 720×s2 | 9292568 | AMD EPYC 9V74 80-Core Processor |
| v1 | 450×s1 | 1668792 | INTEL(R) XEON(R) PLATINUM 8573C |
| v1 | 720×s1 | 1919185 | Intel(R) Xeon(R) 6975P-C |
| v1 | 720×s2 | 1862438 | AMD EPYC 9V74 80-Core Processor |

## S9a A 基線

- Lane: V VERIFY-LONG (orphan only; no product PR)
- main tip: `dcea87f338f3bea4b49197ce3cbb1c407a28a250`
- A tip frozen: `107c17fea29da54363713e5896805a2ebd630a0e` tree `7b533dd0b03b885aefcc357465dea8be06892a52`
- Temp branch: `perf-verify-1787` (workflow-only; deleted after pack)

## S9a B 變更清單

無產品碼變更（Lane V）。僅臨時 workflow on `perf-verify-1787`（用畢刪）。

## S9a C 規格對照

| 項 | 要求 | 本線產出 |
|----|------|----------|
| V0 | main 450/720×s1,s2 | `v0-baseline.txt` + artifacts/v0 |
| V1 | A tip 同三線；tip 凍結 | `v1-a-side.txt` + artifacts/v1 |
| V2 | 逐位元組比對五檔 | `v2-compare.txt` IDENTICAL |
| V3 | 季結算數＋MET-01..06 | `v3-met.txt` |
| V4 | ELAPSED_MS＋CPU | 上表＋ v0/v1 檔 |

## S9a D 介面清單

無（不改碼）。

## S9a E 自查掃描

N/A（無 .gd 變更）。

## S9a F 測試

未改測。長跑為 Actions M1b-Verify-1787（非 gut）。

## S9a G 排程與信號

V0∥Q/P/A0；V1 於 A tip 凍結＋CI 綠後啟動。

## S9a H 偏離與缺口

- workflow_dispatch 403 → 沿用 push `perf-verify-1787`（同 17-83 met-lengths-* 作法）。
- 標準 runner CPU 不一；耗時僅作紀錄、不跨 CPU 比較（B-11）。
- 缺口：無。

## S9a I 格式／失敗執行

失敗執行：無。INVALIDATIONS：無。RETRIES：0。

---

## Delivered (required)

- `v0-baseline.txt`
- `v1-a-side.txt`
- `v2-compare.txt`
- `v3-met.txt`
- `report.md`
- `lane.txt`
- `orphan_push.log` / `orphan_sha.txt` (S9d)
- store also: `dispatch-v0.txt`, `dispatch-v1.txt`, `artifacts/v0/`, `artifacts/v1/`

## FILES_TOTAL

- `artifacts/v0/Za_G0_A0_d450_s1/combos.csv`
- `artifacts/v0/Za_G0_A0_d450_s1/commit_sha.txt`
- `artifacts/v0/Za_G0_A0_d450_s1/obs_ext.csv`
- `artifacts/v0/Za_G0_A0_d450_s1/product_base_sha.txt`
- `artifacts/v0/Za_G0_A0_d450_s1/progress_snip.log`
- `artifacts/v0/Za_G0_A0_d450_s1/runner_specs.txt`
- `artifacts/v0/Za_G0_A0_d450_s1/scenario.json`
- `artifacts/v0/Za_G0_A0_d450_s1/season_cells.csv`
- `artifacts/v0/Za_G0_A0_d450_s1/season_ports.csv`
- `artifacts/v0/Za_G0_A0_d450_s1/sim_runner.log`
- `artifacts/v0/Za_G0_A0_d450_s1/summary.csv`
- `artifacts/v0/Za_G0_A0_d450_s1/timing.txt`
- `artifacts/v0/Za_G0_A0_d450_s1/trader_summary.csv`
- `artifacts/v0/Za_G0_A0_d450_s1/verify_side.txt`
- `artifacts/v0/Za_G0_A0_d720_s1/combos.csv`
- `artifacts/v0/Za_G0_A0_d720_s1/commit_sha.txt`
- `artifacts/v0/Za_G0_A0_d720_s1/obs_ext.csv`
- `artifacts/v0/Za_G0_A0_d720_s1/product_base_sha.txt`
- `artifacts/v0/Za_G0_A0_d720_s1/progress_snip.log`
- `artifacts/v0/Za_G0_A0_d720_s1/runner_specs.txt`
- `artifacts/v0/Za_G0_A0_d720_s1/scenario.json`
- `artifacts/v0/Za_G0_A0_d720_s1/season_cells.csv`
- `artifacts/v0/Za_G0_A0_d720_s1/season_ports.csv`
- `artifacts/v0/Za_G0_A0_d720_s1/sim_runner.log`
- `artifacts/v0/Za_G0_A0_d720_s1/summary.csv`
- `artifacts/v0/Za_G0_A0_d720_s1/timing.txt`
- `artifacts/v0/Za_G0_A0_d720_s1/trader_summary.csv`
- `artifacts/v0/Za_G0_A0_d720_s1/verify_side.txt`
- `artifacts/v0/Za_G0_A0_d720_s2/combos.csv`
- `artifacts/v0/Za_G0_A0_d720_s2/commit_sha.txt`
- `artifacts/v0/Za_G0_A0_d720_s2/obs_ext.csv`
- `artifacts/v0/Za_G0_A0_d720_s2/product_base_sha.txt`
- `artifacts/v0/Za_G0_A0_d720_s2/progress_snip.log`
- `artifacts/v0/Za_G0_A0_d720_s2/runner_specs.txt`
- `artifacts/v0/Za_G0_A0_d720_s2/scenario.json`
- `artifacts/v0/Za_G0_A0_d720_s2/season_cells.csv`
- `artifacts/v0/Za_G0_A0_d720_s2/season_ports.csv`
- `artifacts/v0/Za_G0_A0_d720_s2/sim_runner.log`
- `artifacts/v0/Za_G0_A0_d720_s2/summary.csv`
- `artifacts/v0/Za_G0_A0_d720_s2/timing.txt`
- `artifacts/v0/Za_G0_A0_d720_s2/trader_summary.csv`
- `artifacts/v0/Za_G0_A0_d720_s2/verify_side.txt`
- `artifacts/v0/_scenarios/Za_G0_A0_d450_s1.json`
- `artifacts/v0/_scenarios/Za_G0_A0_d720_s1.json`
- `artifacts/v0/_scenarios/Za_G0_A0_d720_s2.json`
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
- `artifacts/v1/_scenarios/Za_G0_A0_d450_s1.json`
- `artifacts/v1/_scenarios/Za_G0_A0_d720_s1.json`
- `artifacts/v1/_scenarios/Za_G0_A0_d720_s2.json`
- `dispatch-v0.txt`
- `dispatch-v1.txt`
- `lane.txt`
- `orphan_push.log`
- `orphan_sha.txt`
- `report.md`
- `v0-baseline.txt`
- `v1-a-side.txt`
- `v2-compare.txt`
- `v3-met.txt`

FILES_TOTAL=103
