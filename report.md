report.md
# 17-87 Lane A PERF-AFFORD report

ASOF_HKT=2026-11-28 Asia/Hong_Kong  
PR: https://github.com/wayung0217/Project-Patrician/pull/105  
Branch: `perf-afford-1787`  
Tip **FROZEN**: `107c17fea29da54363713e5896805a2ebd630a0e`  
Tree: `7b533dd0b03b885aefcc357465dea8be06892a52`  
Base main: `dcea87f338f3bea4b49197ce3cbb1c407a28a250`  
Choice: **A1** (H1+H2 成立; A2 not done)  
Merge: **no** (C-15; wait Owner)

## S9a A 基線

- Branch: `perf-afford-1787`
- Head SHA: `107c17fea29da54363713e5896805a2ebd630a0e`
- Base SHA: `dcea87f338f3bea4b49197ce3cbb1c407a28a250` (origin/main at branch start / A5 甲)
- docs/spec B9: **v6.99.293**；tree SHA `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- main 基線測試名數: BASELINE_NAMES=555（`.github/ci/gut_unit_property_baseline_names.txt`）
- CI tip: TOTAL_PASSING=615；REMOVED_NAMES=空

## S9a B 變更清單

```
git diff --stat origin/main...HEAD
 .github/workflows/m1b-afford-timing-1787.yml | 127 +++++++
 autoload/trader_registry.gd                  |  35 +-
 tests/unit/test_perf_afford_1787.gd          | 522 +++++++++++++++++++++++++++
 tests/unit/test_perf_afford_1787.gd.uid      |   1 +
 4 files changed, 681 insertions(+), 4 deletions(-)
```

- 產品碼（autoload／core／tools／project.godot）: `autoload/trader_registry.gd` only
- 測試與 fixture: `tests/unit/test_perf_afford_1787.gd` (+ `.uid`)
- 2.1 目錄以外: `.github/workflows/m1b-afford-timing-1787.yml`（A5 Actions 計時；臨時／本線）

Full diffs: `diff-trader_registry.txt`, `diff-tests.txt`, `diff-workflow-timing.txt`

## S9a C 規格對照

| 項 | 規格／裁決 | 實作 | 測試 |
|----|------------|------|------|
| FRM-SYS17-02 | q＝MIN(afford,艙位,庫存,准入) | `_evaluate_and_maybe_sail` A1 cache + lazy afford | `test_17_87_EX_*` |
| FRM-SYS05-09 | max_affordable_qty(actor,port,good)；不含 dest | 簽名未改；呼叫仍 (acct,from_port,good) | EX-05-09-01..03 fixtures |
| D-104(c)④ | 先剔除無貨／買不起 | afford 移到 market／no_intel／weekly 之後 | same |
| C-08 | 暫存僅單次評估區域 | local `afford_by_good` Dictionary | parity vs frozen-old |
| C-12 | 改動處註解 FRM／D | A1 註解 | — |
| D-60e | 測試名含 17_87 | 四測 | listed in F |
| A4 golden | sha256=cb428896… | CI golden-30d-compare | `a4-golden.txt` |

## S9a D 介面清單

- 無新增公開方法／信號／Autoload／project.godot 變更
- 未改 `CashLedger.max_affordable_qty` 簽名或本體
- 僅 `_evaluate_and_maybe_sail` 內部呼叫次數／位置（區域快取）

## S9a E 自查掃描

見 `evidence-e-scan.txt`（命令＋輸出全文）。

摘要：
- E(1) 產品碼既有字面量仍在整檔掃描中；A1 hunk 僅用 0／1；測試 fixture 常數取自 frm_examples（EX-05-09／EX-17-02）
- E(2) 測試輔助呼叫 `TraderRegistry._clear_runtime`／`_evaluate_and_maybe_sail`（D-32b 重置／斷言）
- E(3)(4) 見掃描檔
- E(5) `afford_by_good` 僅鍵查找；迴圈仍遍歷 ports／goods Array
- E(6) A1 註解含 FRM-SYS17-02／FRM-SYS05-09／D-104(c)④

## S9a F 測試

新增（4）— 名含 `17_87`：
- `test_17_87_EX_05_09_01_cash_surplus_candidates_match_frozen`
- `test_17_87_EX_05_09_02_cash_bottleneck_candidates_match_frozen`
- `test_17_87_EX_05_09_03_zero_stock_no_candidates_match_frozen`
- `test_17_87_EX_17_02_01_pick_B_matches_frozen`

刪除：無（REMOVED_NAMES 空）

改內容既有測：無（既有測試檔未改）

計數（CI tip 107c17f run 46051122126）：
```
TOTAL_PASSING=615
BASELINE_NAMES=555
REMOVED_NAMES: (empty)
SEEN_NAMES=615
```
≥611 要求：滿足。

CI: https://github.com/wayung0217/Project-Patrician/actions/runs/46051122126 — success（11 checks）  
A5: https://github.com/wayung0217/Project-Patrician/actions/runs/46051115478 — success

## S9a G 排程與信號

未動 SimLoop；無新信號；每日步驟順序不變。

## S9a H 偏離與缺口

- EX-17-02-01 coarse mid 代理可選 PT-03；測試改為 old==new 對照＋frm_examples 精確買入路徑斷言 B（非改產品語意）
- Lane V 比對表：見 V（本線不重跑 V）
- 未優化 board_for／mid_price／pop（A7）

## S9a I 格式

逐點附證據檔；CI 綠後只回報、不合併。

## 特別證據（A6）

| # | 內容 | 檔 |
|---|------|-----|
| (1) | max_affordable_qty／候選迴圈 diff 全文 | `diff-trader_registry.txt` + `evidence-special.txt` |
| (2) | H1／H2／H3 | `A-readcode.txt` |
| (3) | E(1)–(6) | `evidence-e-scan.txt` |
| (4) | golden sha256 | `a4-golden.txt` — MATCH expected cb428896… |
| (5) | 6+2 ELAPSED_MS | `a5-timing.txt` |
| (6) | V 比對表 | 見 V |

### A5 ELAPSED_MS（原文；CPU=Intel(R) Xeon(R) 6975P-C）

```
label=jia_main	days=30	round=1	elapsed_ms=668644	commit=dcea87f338f3bea4b49197ce3cbb1c407a28a250
label=yi_tip	days=30	round=1	elapsed_ms=190545	commit=107c17fea29da54363713e5896805a2ebd630a0e
label=jia_main	days=30	round=2	elapsed_ms=668430	commit=dcea87f338f3bea4b49197ce3cbb1c407a28a250
label=yi_tip	days=30	round=2	elapsed_ms=191164	commit=107c17fea29da54363713e5896805a2ebd630a0e
label=jia_main	days=30	round=3	elapsed_ms=667984	commit=dcea87f338f3bea4b49197ce3cbb1c407a28a250
label=yi_tip	days=30	round=3	elapsed_ms=191285	commit=107c17fea29da54363713e5896805a2ebd630a0e
label=jia_main	days=10	round=1	elapsed_ms=243234	commit=dcea87f338f3bea4b49197ce3cbb1c407a28a250
label=yi_tip	days=10	round=1	elapsed_ms=86610	commit=107c17fea29da54363713e5896805a2ebd630a0e
```

## 失敗執行（B-9／D-120(e)）

見 `failed-runs.txt`：tip 9f2a4d1、43b74c4 gut-unit(3) 失敗後修復；凍結 tip 107c17f 全綠。

## Orphan (S9d)

- Branch: `review/overnight-17-87-A`
- Full SHA: _(filled after push)_
- URL: https://github.com/wayung0217/Project-Patrician/tree/review/overnight-17-87-A

### git ls-tree -r -l

_(filled after push)_

## B-10 ls + FILES_TOTAL

_(filled after push)_
