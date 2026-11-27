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
- Base SHA: `dcea87f338f3bea4b49197ce3cbb1c407a28a250`
- docs/spec B9: **v6.99.293**；tree SHA `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- main 基線測試名數: BASELINE_NAMES=555
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

- 產品碼: `autoload/trader_registry.gd` only
- 測試: `tests/unit/test_perf_afford_1787.gd` (+ `.uid`)
- 2.1 以外: `.github/workflows/m1b-afford-timing-1787.yml`（A5）

Full diffs: `diff-trader_registry.txt`, `diff-tests.txt`, `diff-workflow-timing.txt`

## S9a C 規格對照

| 項 | 規格／裁決 | 實作 | 測試 |
|----|------------|------|------|
| FRM-SYS17-02 | q＝MIN(afford,艙位,庫存,准入) | A1 cache + lazy afford | `test_17_87_EX_*` |
| FRM-SYS05-09 | max_affordable_qty(actor,port,good) | 簽名未改 | EX-05-09-01..03 |
| D-104(c)④ | 先剔除無貨／買不起 | afford after cheap skips | same |
| C-08 | 暫存僅單次評估區域 | local `afford_by_good` | parity vs frozen-old |
| C-12 | 改動處註解 FRM／D | A1 註解 | — |
| D-60e | 測試名含 17_87 | 四測 | F |
| A4 golden | sha256=cb428896… | CI golden-30d-compare | `a4-golden.txt` |

## S9a D 介面清單

- 無新增公開方法／信號／Autoload／project.godot
- 未改 `CashLedger.max_affordable_qty` 簽名或本體

## S9a E 自查掃描

見 `evidence-e-scan.txt`（命令＋輸出全文）。

## S9a F 測試

新增（4）:
- `test_17_87_EX_05_09_01_cash_surplus_candidates_match_frozen`
- `test_17_87_EX_05_09_02_cash_bottleneck_candidates_match_frozen`
- `test_17_87_EX_05_09_03_zero_stock_no_candidates_match_frozen`
- `test_17_87_EX_17_02_01_pick_B_matches_frozen`

刪除: 無。改內容既有測: 無。

```
TOTAL_PASSING=615
BASELINE_NAMES=555
REMOVED_NAMES: (empty)
```

CI: https://github.com/wayung0217/Project-Patrician/actions/runs/46051122126 — success  
A5: https://github.com/wayung0217/Project-Patrician/actions/runs/46051115478 — success

## S9a G 排程與信號

未動 SimLoop；無新信號。

## S9a H 偏離與缺口

- EX-17-02-01 coarse mid 可選 PT-03；測試改 old==new＋frm_examples 精確路徑
- Lane V 比對表: 見 V
- 未優化 board_for／mid_price／pop（A7）

## S9a I 格式

CI 綠後只回報、不合併。

## 特別證據（A6）

| # | 內容 | 檔 |
|---|------|-----|
| (1) | max_affordable_qty／候選迴圈 diff 全文 | `diff-trader_registry.txt` + `evidence-special.txt` |
| (2) | H1／H2／H3 | `A-readcode.txt` |
| (3) | E(1)–(6) | `evidence-e-scan.txt` |
| (4) | golden sha256 | `a4-golden.txt` — MATCH cb428896… |
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

見 `failed-runs.txt`。

## Orphan (S9d)

- Branch: `review/overnight-17-87-A`
- Full SHA: `c382d0af4971585b480637a3159d2e0c91f4e478`
- URL: https://github.com/wayung0217/Project-Patrician/tree/review/overnight-17-87-A

### git ls-tree -r -l

```
100644 blob 5a55d02c28a48b2ba46563b906476b800c8a0bcd    8665	A-readcode.txt
100644 blob 8100cc8010500c2f9707c8ac500788b4898d027b     748	a4-golden.txt
100644 blob 938a79ff5ef7d836878608c5a9c22b4a8a1447e4    9744	a5-timing.txt
100644 blob f2b403fbcb2adabfdc553612c38887d9b679bc8e   19055	diff-tests.txt
100644 blob fa8e3e308c515c4e2e04af85d967f826c0c252de    3304	diff-trader_registry.txt
100644 blob 45331ff420c2a1f476df3c9f0aa76bc6bb3163f9    5532	diff-workflow-timing.txt
100644 blob 35cc871485037d73f4c48d745fdf257c7236262f   20669	evidence-e-scan.txt
100644 blob 7e1bf4e73f77c2a0bf7fd88f124af8731e29b996    8587	evidence-special.txt
100644 blob e128046157ad9d6a8844f3144ea3faa75773fa9c    1183	failed-runs.txt
100644 blob 284a7efe5e38577e6d23f38307e785640d4a982f     376	lane.txt
100644 blob c01a3539343d983ffb932f3f3bd5a81c15dc4c3b    1469	manifest.txt
100644 blob 70cce2cc2be95f5ef7f255d57880bc3b63993f9e    1301	orphan_push.log
100644 blob 538a2522eafe1e10a3376796d0f0b1d6234fdd8e      41	orphan_sha.txt
100644 blob a82c3e79243e85efbcbdbcebfb603107a695a109    5849	report.md
```

## B-10 ls + FILES_TOTAL

```
total 88
drwxrwxrwx 2 ubuntu ubuntu     0 Nov 27 16:14 .
drwxrwxrwx 2 ubuntu ubuntu     0 Nov 27 16:14 ..
-rw-rw-rw- 1 ubuntu ubuntu   748 Nov 27 19:36 a4-golden.txt
-rw-rw-rw- 1 ubuntu ubuntu  9744 Nov 27 19:36 a5-timing.txt
-rw-rw-rw- 1 ubuntu ubuntu  8665 Nov 27 19:36 A-readcode.txt
-rw-rw-rw- 1 ubuntu ubuntu 19055 Nov 27 19:36 diff-tests.txt
-rw-rw-rw- 1 ubuntu ubuntu  3304 Nov 27 19:36 diff-trader_registry.txt
-rw-rw-rw- 1 ubuntu ubuntu  5532 Nov 27 19:37 diff-workflow-timing.txt
-rw-rw-rw- 1 ubuntu ubuntu 20669 Nov 27 19:37 evidence-e-scan.txt
-rw-rw-rw- 1 ubuntu ubuntu  8587 Nov 27 19:37 evidence-special.txt
-rw-rw-rw- 1 ubuntu ubuntu  1183 Nov 27 19:37 failed-runs.txt
-rw-rw-rw- 1 ubuntu ubuntu   376 Nov 27 19:37 lane.txt
-rw-rw-rw- 1 ubuntu ubuntu  1469 Nov 27 19:37 manifest.txt
-rw-rw-rw- 1 ubuntu ubuntu  1301 Nov 27 19:37 orphan_push.log
-rw-rw-rw- 1 ubuntu ubuntu    41 Nov 27 19:37 orphan_sha.txt
-rw-rw-rw- 1 ubuntu ubuntu  5849 Nov 27 19:37 report.md
```

FILES_TOTAL=14
