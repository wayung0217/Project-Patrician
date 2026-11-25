# S9a — evening-17-69-lane2 (#84 / 17-69 補正三 W1+W2)

**Note:** tip 19d1a4e gut-unit(1) SCRIPT ERROR fixed in  (DemandModel unload). See .

**Final tip:** `1baa133c50c671da0d7111f8e157d5c58cf30697`  
**Branch:** `cursor/ci-hang-1767-866d` → `main` (PR #84)  
**Spec:** v6.99.222 · **Merge:** no · **tag / z-1758-3:** no

## git branch -r (H7)
見 `git_branch_r.txt`。

## A 基線
對／有改動。見 `baseline_A.txt`（歷史 555 名基線仍有效）。
- head **`1baa133c50c671da0d7111f8e157d5c58cf30697`**
- 期望 gate：`REMOVED_NAMES＝無`；`ADDED_NAMES` 仍僅三個 EX-05-09；Passing ≥558

## B 變更清單（補正三增量 vs 前 tip `6a731ff`）
| 檔 | 變更 |
| --- | --- |
| `.github/workflows/ci.yml` | W1(c)/(d) artifact-by-branch + S9b bootstrap + `DIFF_CELLS` |
| `.github/ci/golden_30d_bootstrap_1764.csv` (+`.sha256`) | 17-64 凍結基準 |
| `.github/ci/README.md` | bootstrap 說明 |
| `autoload/cash_ledger.gd` | D-125 甲：庫存上界無條件（`GoodsLedger.is_loaded()`） |
| `tests/unit/test_cash_ledger.gd` | TST-SYS05-08 Given 種庫存 |
| `tests/unit/test_wp56_cash_market_trade.gd` | WP56 demo Given 種庫存 |

`git diff --stat origin/main...HEAD`：見 `diff_stat_vs_main.txt`。

## C 規格對照表
| ID | 實作 | 測試 |
| --- | --- | --- |
| FRM-SYS05-09／D-124 | `max_affordable_qty` MIN(cash,s) | EX-05-09-01/02/03 |
| D-125 甲 | 庫存上界無條件（不限 MarketPricer） | 兩舊測 Given 種庫存；期望／測名不變 |
| W1 S9b | main artifact 或 bootstrap `8b25c951…` | golden-30d job 輸出 |

## D 介面清單
`max_affordable_qty` 簽名不變；行為：凡 `GoodsLedger.is_loaded()` 即套 MARKET 庫存上界。

## E 自查
產品 hunk：無新增業務 magic；`abs_hi=-1` 哨兵保留。無跨模組 `_`／await／Timer 新增。

## F 基線名
未改 `gut_unit_property_baseline_names.txt`。ADDED 仍僅：
- `test_R972_EX_05_09_01_stock_bottleneck_q_100`
- `test_R972_EX_05_09_02_cash_bottleneck_q_120`
- `test_R972_EX_05_09_03_zero_stock_no_quote`

## G W1 黃金基準死結（結論）
| 項 | 結論 |
| --- | --- |
| (a) | run [45358265237](https://github.com/wayung0217/Project-Patrician/actions/runs/45358265237) success 但僅 gut-ui／gut-unit-property；**無 golden-30d job／artifact**。較新 main cancelled run 45415084221 已上傳 artifact **14932606115**（14d；sha256=`8b25c951…`） |
| (b) | `gh workflow run ci.yml --ref main -f job=ci` → **HTTP 403** Resource not accessible by integration（全文見 `w1_golden/b_workflow_dispatch_403.txt`） |
| (c) | S9b bootstrap 已落地；main 有 artifact 不走 bootstrap |
| (d) | 下載改為 artifact API 依 `head_branch==main`；main 已跑／上傳 golden（cancelled 仍 upload） |

## H W2 D-125 甲
- 刪 `_quote_provider == MarketPricer and` 條件
- 兩舊測 Given 種足量庫存；期望與測名不變
- 全文／diff：`w2_d125/`

## I CI（tip 19d1a4e）
- Run：https://github.com/wayung0217/Project-Patrician/actions/runs/45523259356
- 狀態：見 `ci_evidence/`（完成後補 gate／golden 摘要）

## 停止條件
W1+W2 本線完成即停；不合併、不打 tag、不跑 z-1758-3；等整合／HANDOFF。
