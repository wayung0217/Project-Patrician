report.md
# 17-88 Lane A PERF-PRICE-AFFORD report

ASOF_HKT=2026-11-28 Asia/Hong_Kong  
PR: https://github.com/wayung0217/Project-Patrician/pull/106  
Branch: `perf-afford-1788`  
Tip **FROZEN**: `59ae4cb8485805f4a717785f2a36bf7217a5c780`  
Tree: `adc21ebce033a02bd00f5225dca1d5a717fe0dc9`  
Base (B merge): `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6`  
A1: `e2f1053ed00c73f9216c8c45fe92b79e5055b253`  
A2: `dd4b96f28ad179285d2e30f6009f09da8c242935`  
Choice: **A1+A2** (H4 成立, H5 成立)  
Merge: **no** (C-15; wait Owner)

## S9a A 基線

- Branch: `perf-afford-1788`
- Head SHA: `59ae4cb8485805f4a717785f2a36bf7217a5c780`
- Tree: `adc21ebce033a02bd00f5225dca1d5a717fe0dc9`
- Base SHA: `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6`
- docs/spec B9: **v6.99.293**
- BASELINE_COUNT=555
- CI tip: TOTAL_PASSING=619；REMOVED_NAMES=無
- CI run: https://github.com/wayung0217/Project-Patrician/actions/runs/46095438765 — success (7 success / 3 skipped / 0 failed)

## S9a B 變更清單

```
git diff --stat aa098a8..59ae4cb
 autoload/cash_ledger.gd                 |   6 +
 autoload/trader_registry.gd             |  19 +-
 tests/unit/test_perf_afford_1788.gd     | 391 ++++++++++++++++++++++++++++++++
 tests/unit/test_perf_afford_1788.gd.uid |   1 +
 4 files changed, 416 insertions(+), 1 deletion(-)
```

- 產品碼: `autoload/trader_registry.gd` (A1 mid_price local cache) + `autoload/cash_ledger.gd` (A2 quote(s) fast-path)
- 測試: `tests/unit/test_perf_afford_1788.gd` (+ `.uid`)
- Timing workflow NOT in PR: `.github/workflows/m1b-afford-timing-1788.yml` on `perf-verify-1788`

Full diffs: `diff-trader_registry.txt`, `diff-cash_ledger.txt`, `diff-tests.txt`, `diff-workflow-timing.txt`

## S9a C 規格對照

| 項 | 規格／裁決 | 實作 | 測試 |
|----|------------|------|------|
| FRM-SYS17-02 | q＝MIN(afford,艙位,庫存,准入) | A1 mid cache; afford cache from #105 | golden + V |
| FRM-SYS05-09／D-124 | max_affordable_qty；不以 q>s quote | A2 fast-path quote(s) | EX-05-09-01..03 + brute |
| SYS-04 純函數 | MarketPricer 無狀態 | 不改 MarketPricer | — |
| D-104(c)／C-08 | 區域快取；不依 Dictionary 插入序 | `mid_by_good` local; key=String(good) | — |
| C-12 | 改動處註解 FRM／D | A1／A2 註解 | — |
| D-128 | 測試不碰他模組 `_` | counting provider + public APIs | E(2)=無 |
| D-60e | 測名含 17_88 | 四測 | F |
| A4 golden | sha256=cb428896… | CI golden-30d-compare | `a4-golden.txt` |

## S9a D 介面清單

- 無新增公開方法／信號／Autoload／project.godot
- `CashLedger.max_affordable_qty` 簽名未改
- `MarketPricer` 未改

## S9a E 自查掃描

見 `evidence-e-scan.txt`。E(2)=無。

## S9a F 測試

新增（4）:
- `test_17_88_EX_05_09_01_stock_bottleneck_quote_once`（q=300；quote calls=1）
- `test_17_88_EX_05_09_02_cash_bottleneck_q_120`
- `test_17_88_EX_05_09_03_zero_stock_no_quote`（q=0；quote calls=0）
- `test_17_88_brute_cash_levels_match_max_affordable`（≥20 cash levels）

刪除: 無。改內容既有測: 無。REMOVED_NAMES=無。

缺口（H4 mid_price 呼叫次數）: 無法在不碰 TraderRegistry `_` 下計數；等價性靠 golden + lane V。

```
TOTAL_PASSING=619
BASELINE_COUNT=555
SEEN_NAMES=619 BASELINE_NAMES=555
REMOVED_NAMES:
無
GUT_UNIT_PROPERTY_BASELINE_NAMES_OK=1
GUT_UNIT_PROPERTY_COUNT_OK>=555 actual=619
```

## S9a G 排程與信號

- 無排程／信號變更

## S9a H 風險與缺口

- H4 單元測試缺口（上）
- A5 timing complete (primary 46095496498)；dup 46096974557 ignored；cancel was 403
- 不合併（C-15）

## S9a I 證據索引

| 檔 | 內容 |
|----|------|
| A-readcode.txt | A0 H4/H5 |
| diff-*.txt | 全文 diff |
| a4-golden.txt | sha256 對照 |
| a5-timing.txt | ELAPSED_MS |
| evidence-e-scan.txt | S9a E |
| evidence-special.txt | A6 特別證據 |
| ci-gate.txt | gate 原文 |
| failed-runs.txt | D-120(e) |
| orphan_sha.txt | orphan tip（見該檔） |
| manifest.txt | 清單＋sha256 |

## A4 golden

expected = actual = `cb4288967c1ef79844c672a906b1ddfd02843d841b1710517c39e2e733167bf7`  
DIFF_CELLS=0

## A5 timing

見 `a5-timing.txt`。run 46095496498 success。CPU=INTEL(R) XEON(R) PLATINUM 8573C。
甲=aa098a8 乙=e2f1053 丙=59ae4cb。
d30: 256700/226067/202008 ; 255521/224302/200380 ; 253792/223289/200041
d10: 114998/106012/99502

Orphan SHA: 见 orphan_sha.txt（B-13）

## 分支衛生（S9i）

- 本包新增非 review: `perf-afford-1788`、`perf-verify-1788`（shared）
- orphan: `review/overnight-17-88-A`
- 不刪他線分支；不合併 #106

## FILES_TOTAL

見報告末 `ls` 與 `manifest.txt`（pack 完成後更新）。

## ls pack
A-readcode.txt
a4-golden.txt
a5-timing.txt
ci-gate.txt
diff-cash_ledger.txt
diff-tests.txt
diff-trader_registry.txt
diff-workflow-timing.txt
evidence-e-scan.txt
evidence-special.txt
failed-runs.txt
lane.txt
manifest.txt
orphan_push.log
orphan_sha.txt
report.md
FILES_TOTAL=16
