# 17-89 Lane M MERGE-106 report

ASOF_HKT=2026-11-28 Asia/Hong_Kong  
PR: https://github.com/wayung0217/Project-Patrician/pull/106  
Branch: `perf-afford-1788` (deleted after merge)  
Merge: **YES** (S9b merge commit; Owner APPROVED 2026-11-28)

## git branch -r（S9i ③）

見 `m-branches.txt` 全文（A=fetch --prune 合併前；B=合併刪分支後）。

## M1 tip record

```
PR106_HEAD=59ae4cb8485805f4a717785f2a36bf7217a5c780
PR106_TREE=adc21ebce033a02bd00f5225dca1d5a717fe0dc9
EXPECTED_HEAD=59ae4cb8485805f4a717785f2a36bf7217a5c780
EXPECTED_TREE=adc21ebce033a02bd00f5225dca1d5a717fe0dc9
HEAD_MATCH=YES TREE_MATCH=YES
```

## M2 origin/main

```
ORIGIN_MAIN=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6
EXPECTED=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6
MAIN_MATCH=YES
mergeable=MERGEABLE
```

## M3 pre-merge CI（tip 59ae4cb）

```
run=46095438765
url=https://github.com/wayung0217/Project-Patrician/actions/runs/46095438765
success=7 skipped=3 failed=0
TOTAL_PASSING=619
BASELINE_COUNT=555
REMOVED_NAMES:
無
golden sha256=cb4288967c1ef79844c672a906b1ddfd02843d841b1710517c39e2e733167bf7
DIFF_CELLS=0
```

原文見 `m-ci.txt`。

## M4 merge

```
MERGE_SHA=25a398492fa568a223fb4802adbb4f15bc40bcbb
MAIN_TIP=25a398492fa568a223fb4802adbb4f15bc40bcbb
parents=aa098a8425a4c9d3e10a860a77a40c3f9b3878a6 59ae4cb8485805f4a717785f2a36bf7217a5c780
method=merge commit only (gh pr merge 106 --merge)
mergedAt=2026-11-28T05:04:26Z
```

`perf-afford-1788` deleted（remote＋local empty）。見 `m-merge.txt`。

## M5 post-merge

```
main CI run=46110421786
url=https://github.com/wayung0217/Project-Patrician/actions/runs/46110421786
conclusion=success
success=7 skipped=3 failed=0
TOTAL_PASSING=619 BASELINE_COUNT=555 REMOVED_NAMES=無
golden-30d-baseline csv sha256=cb4288967c1ef79844c672a906b1ddfd02843d841b1710517c39e2e733167bf7
artifact_id=15249112638
```

```
git diff --stat aa098a8..25a3984
 autoload/cash_ledger.gd                 |   6 +
 autoload/trader_registry.gd             |  19 +-
 tests/unit/test_perf_afford_1788.gd     | 391 ++++++++++++++++++++++++++++++++
 tests/unit/test_perf_afford_1788.gd.uid |   1 +
 4 files changed, 416 insertions(+), 1 deletion(-)
```

docs/spec tree unchanged=`cb4e2c04da3db42696644474f6c0d27c6b862c22`  
B9=`v6.99.293`

Last 30 lines / full gate：`m-main-post.txt`。

## M6 / M7

只刪 `perf-afford-1788`；其餘分支不動；不改任何檔案內容；不開新 PR；不 rebase。

## S9a A 基線

- Branch: `perf-afford-1788` → merged＋deleted
- Head（合併前 tip）: `59ae4cb8485805f4a717785f2a36bf7217a5c780`
- Base / pre-main: `aa098a8425a4c9d3e10a860a77a40c3f9b3878a6`
- docs/spec B9: **v6.99.293**；tree `cb4e2c04da3db42696644474f6c0d27c6b862c22`
- tip CI: TOTAL_PASSING=619；BASELINE_COUNT=555；REMOVED_NAMES=無
- Merge SHA / main tip: `25a398492fa568a223fb4802adbb4f15bc40bcbb`

## S9a B 變更清單

產品碼: `autoload/cash_ledger.gd`, `autoload/trader_registry.gd`  
測試: `tests/unit/test_perf_afford_1788.gd` (+`.uid`)  
2.1 以外: 無  
（本線不改檔；diff 即 #106 原交付）

## S9a C–H

本線＝合併動作（審查已於 17-88 R9-99／L-丙）。規格對照與掃描證據沿用 #106 tip 交付；本包證據＝M1–M6 原文輸出。

## S9a I

含合併動作（Owner 已批准）。orphan SHA 以 `orphan_sha.txt` 為準（B-8）。

## Orphan 交付（S9d）

- branch: `review/overnight-17-89-M`
- orphan_sha.txt: `1c52fe8a081d30b351011e3d9b6c2b5d07720d2b`（B-8）
- branch tip (ls-remote): `55c112dca8b306294a3e04adaf4058359a96847b`
- pack path: `/cursor/stores/bc-384468d1-b190-4297-a5ea-281d48ea7ac0/overnight-17-89-M/`

## FILES_TOTAL
lane.txt
m-branches.txt
m-ci.txt
m-main-post.txt
m-merge.txt
orphan_push.log
orphan_sha.txt
report.md
FILES_TOTAL=8
