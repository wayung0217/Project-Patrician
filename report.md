report.md
# 17-88 Lane B FIX-AND-MERGE-105 report

ASOF_HKT=2026-11-28 Asia/Hong_Kong  
PR: https://github.com/wayung0217/Project-Patrician/pull/105  
Branch: `perf-afford-1787` (deleted after merge)  
Merge: **YES** (S9b merge commit; Owner authorized 2026-11-28)

## git branch -r（S9i ③；合併前快照見 b-branches.txt；合併後見同檔 B6 段）

見 `b-branches.txt` 全文。

## B1 tip record

```
MAIN_ACTUAL=dcea87f338f3bea4b49197ce3cbb1c407a28a250
PR105_HEAD_AT_START=107c17fea29da54363713e5896805a2ebd630a0e
PR105_TREE_AT_START=7b533dd0b03b885aefcc357465dea8be06892a52
trader_registry.gd blob=3df59445ae15ff5eee2f97a0e6d48d977c931352
```

## B2 tip after fix

```
PR105_NEW_TIP=112a47fd4310a6de9db87d403de0aae502ae9434
PR105_NEW_TREE=079aad6732ea1125a862d1bb9bb970921f2acfd9
trader_registry.gd blob AFTER B2=3df59445ae15ff5eee2f97a0e6d48d977c931352
EQUAL_TO_107c17f=YES
```

B2 changes (same PR branch, no new PR):
- deleted `.github/workflows/m1b-afford-timing-1787.yml`
- rewrote `tests/unit/test_perf_afford_1787.gd` for D-128（公開 CashLedger／TradeEvaluator＋正式 DemandModel inject；frm_examples 期望）
- `autoload/trader_registry.gd` 一字不動

Failed run then fix (D-120(e)):
- run 46091376165 head 4a7b8cb → SCRIPT ERROR Parse Error `fn :=` reassignment in `_wipe_dir`
- fixed → 112a47f (`fn = d.get_next()`)

## B3 CI（tip 112a47f）

```
run=46093285770
url=https://github.com/wayung0217/Project-Patrician/actions/runs/46093285770
success=7 skipped=3 failed=0
TOTAL_PASSING=615
BASELINE_COUNT=555
SEEN_NAMES=615 BASELINE_NAMES=555
REMOVED_NAMES:
無
GUT_UNIT_PROPERTY_BASELINE_NAMES_OK=1
GUT_UNIT_PROPERTY_COUNT_OK>=555 actual=615
golden sha256=cb4288967c1ef79844c672a906b1ddfd02843d841b1710517c39e2e733167bf7
DIFF_CELLS=0
```

## B5 merge

```
MERGE_SHA=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6
MAIN_TIP=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6
parents=dcea87f338f3bea4b49197ce3cbb1c407a28a250 112a47fd4310a6de9db87d403de0aae502ae9434
method=merge commit only (gh pr merge 105 --merge)
trader_registry.gd on main=3df59445ae15ff5eee2f97a0e6d48d977c931352 (=107c17f)
docs/spec tree unchanged=cb4e2c04da3db42696644474f6c0d27c6b862c22
B9=v6.99.293
```

```
git diff --stat dcea87f..aa098a8
 autoload/trader_registry.gd             |  35 +++-
 tests/unit/test_perf_afford_1787.gd     | 332 ++++++++++++++++++++++++++++++++
 tests/unit/test_perf_afford_1787.gd.uid |   1 +
 3 files changed, 364 insertions(+), 4 deletions(-)
```

perf-afford-1787 deleted (remote＋local empty). See `b-merge.txt`.

Main post-merge CI: run 46095216894 **success**（success=7 skipped=3 failed=0；TOTAL_PASSING=615 BASELINE_NAMES=555 REMOVED_NAMES=無）。最後 30 行見 `b-merge.txt`.

## B6 branch cleanup（Owner-authorized only）

| branch | full SHA | is-ancestor of main | deleted |
|--------|----------|---------------------|---------|
| cursor/d136-m1b-abund-overrides-5981 | 01adee0d01514e94f1c3fd7b296dcccf23f78e10 | 是 | yes |
| met-lengths-1783 | 33bd59d198e52529629997133c9bb17522bbf50b | 是 | yes |

Others untouched（含 tools-1758）. Post-delete `git ls-remote --heads origin` in `b-branches.txt`.

## S9a A 基線

- Branch: `perf-afford-1787` → merged＋deleted
- Head（合併前 tip）: `112a47fd4310a6de9db87d403de0aae502ae9434`
- Base: `dcea87f338f3bea4b49197ce3cbb1c407a28a250`
- docs/spec B9: **v6.99.293**；tree `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- main 基線測試名數: BASELINE_NAMES=555
- CI tip: TOTAL_PASSING=615；REMOVED_NAMES=無

## S9a B 變更清單

產品碼: `autoload/trader_registry.gd`（相對 main；來自 #105 A1；B2 未再改）  
測試: `tests/unit/test_perf_afford_1787.gd` (+`.uid`)  
2.1 以外: timing workflow **未**進 main（B2 已刪）

Full diffs: `b-diff-trader_registry.txt`, `b-diff-tests.txt`, `b-diff-workflow-removed.txt`

## S9a C 規格對照

| 項 | 規格／裁決 | 實作 | 測試／證據 |
|----|------------|------|-----------|
| FRM-SYS17-02 / D-104(c) | once-per-good afford | trader_registry A1（107c17f blob） | golden DIFF=0；lane V/L |
| FRM-SYS05-09 / D-124 | max_affordable_qty | 未改簽名 | test_17_87_EX_05_09_* |
| D-128 甲 | 測試不碰他模組 _ | B2 rewrite | E(2)=無 |
| D-60e | 測名含 17_87 | 四測 | F |
| S9b | merge commit＋刪分支 | aa098a8 | b-merge.txt |

## S9a D 介面清單

B2 無新增公開方法／信號／Autoload／project.godot。未新增公開重置函式。

## S9a E 自查掃描

見 `b-e-scan.txt`。**E(2) 跨模組 _ 存取＝無**。

## S9a F 測試

本 tip 新增（相對 baseline；ADDED 含本 PR 四名）:
- `test_17_87_EX_05_09_01_cash_surplus_q_afford_300`
- `test_17_87_EX_05_09_02_cash_bottleneck_q_afford_120`
- `test_17_87_EX_05_09_03_zero_stock_q_afford_0`
- `test_17_87_EX_17_02_01_precise_pick_B`

既有測試零改動。REMOVED_NAMES=無。

缺口（D-128 無法保留；新測不在 gut 基準）:
- coarse frozen old/new 比對（需 `_voyage_days`／`_dest_intel`／`_afford_qty_cached`）
- `_evaluate_and_maybe_sail` 直呼之零庫存不出航斷言

## S9a G 排程與信號

未動 SimLoop；無新信號。

## S9a H 偏離與缺口

見上 F 缺口；等價性改由 golden／長跑涵蓋。

## S9a I 格式

本線含合併動作（Owner 已授權）。orphan SHA 以 `orphan_sha.txt` 為準（B-13）。

## FILES

見報告末 FILES_TOTAL。

## FILES_TOTAL
b-blob-trader_registry.txt
b-branches.txt
b-ci.txt
b-diff-tests.txt
b-diff-trader_registry.txt
b-diff-workflow-removed.txt
b-e-scan.txt
b-main-ci-last30.txt
b-merge.txt
lane.txt
orphan_push.log
orphan_sha.txt
report.md
FILES_TOTAL=13
