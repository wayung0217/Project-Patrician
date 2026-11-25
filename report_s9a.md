# S9a — evening-17-69-lane2 (#84 / 17-69 補正三 W1+W2) FINAL

**Final tip:** `b28012ca49407433e229e8cfc698e083e7680e8f`  
**Branch:** `cursor/ci-hang-1767-866d` → `main` (PR #84)  
**Spec:** v6.99.222 · **Merge:** no（等 Owner 批准）· **tag / z-1758-3:** no  
**CI:** https://github.com/wayung0217/Project-Patrician/actions/runs/45528301812 — **success 9/9**

## git branch -r (H7)
見 `git_branch_r.txt`。

## A 基線
對。head `b28012ca49407433e229e8cfc698e083e7680e8f`；baseline 555 名；Passing **558**；REMOVED＝無；ADDED＝三 EX。

## B 變更清單（vs `origin/main`）
見 `diff_stat_vs_main.txt`。本線擁有：`ci.yml`、`cash_ledger.gd`、`tests/unit/`（本線檔）、`.github/ci/`。

## C 規格對照
| ID | 實作 | 驗證 |
| --- | --- | --- |
| FRM-SYS05-09／D-124 | `max_affordable_qty` MIN(cash,s) | EX-05-09-01/02/03 |
| D-125 甲 | 庫存上界無條件（`GoodsLedger.is_loaded()`） | 兩舊測 Given 種庫存；期望／測名不變 |
| W1 S9b | main artifact 或 bootstrap `8b25c951…` | tip CI：BOOTSTRAP=0、DIFF_CELLS=0 |

## D 介面
`max_affordable_qty` 簽名不變；行為：GoodsLedger 已載入即套 MARKET 庫存上界。

## E 自查
產品 hunk 無新增業務 magic；`abs_hi=-1` 哨兵保留。WP56／R972 boot 靜默 `DemandModel._clear_state()`（測試側）。

## F 基線名
未改 baseline 檔。ADDED 僅三 EX（見 gate）。

## G W1 黃金基準死結 — 最終結論
| 項 | 結論 |
| --- | --- |
| (a) | main run 45358265237 success 但無 `golden-30d` job。較新 cancelled main 45415084221 已上傳 artifact **14932606115**（sha256 `8b25c951…`，retention 14d） |
| (b) | `gh workflow run ci.yml --ref main -f job=ci` → **HTTP 403** Resource not accessible by integration |
| (c) | S9b bootstrap CSV 已提交；本 tip CI **未走 bootstrap**（`GOLDEN_BOOTSTRAP=0`） |
| (d) | 下載改 artifact API（`head_branch==main`）；main 已跑／上傳 golden |

本 tip golden：`DIFF_CELLS=0`、`IDENTICAL=1`、PR artifact **14983617491**。

## H W2 D-125 甲 — 最終結論
- 刪 `_quote_provider == MarketPricer` 條件；庫存上界無條件。
- 只改 `test_TST_SYS05_08`／`test_WP56_demo_q_afford_124` Given（種足量庫存）；期望／測名不變。
- Gate：REMOVED＝無；ADDED＝三 EX only。全文／diff：`w2_d125/`。

## I CI（tip b28012c）
- Run：https://github.com/wayung0217/Project-Patrician/actions/runs/45528301812
- Gate：`ci_evidence/gate_tip_b28012c.txt`
- Golden：`ci_evidence/golden_tip_b28012c.txt`
- 中途失敗已解：19d1a4e SCRIPT ERROR；1baa133 A21 push_error count（見 `ci_fail/`）

## 停止
本線完成。不合併、不打 tag、不跑 z-1758-3；等 Owner 批准／整合／HANDOFF。
