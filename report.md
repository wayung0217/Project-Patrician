# S9a — review/1770-t1（17-70 T1 + T4）

**Product tip:** `8f200cf93f96006234e3a865ff0c96b926d8ebad`  
**Branch:** `cursor/ci-hang-1767-866d` → `main` (PR #84)  
**CI:** https://github.com/wayung0217/Project-Patrician/actions/runs/45565620435 — **success 9/9**  
**Merge:** no（等 Owner 批准①）

## git branch -r
見 `git_branch_r.txt`。

## A 基線
head `8f200cf93f96006234e3a865ff0c96b926d8ebad`；Passing **558**；baseline 555。

## B 變更清單（vs b28012c）
見 `full.diff`。本包增量：
- T1：`test_wp56_cash_market_trade.gd`、`test_r972_cash_stock_cap_1769.gd`
- T4：`.github/workflows/ci.yml`、`tools/golden_compare.py`

## C 規格對照
| ID | 實作 | 驗證 |
| --- | --- | --- |
| D-128 甲 | 刪 `_clear_state`；R9-65 A2 `set_potential_demand_provider(zero)` | EX 期望 300/120/0 不變；CI 綠 |
| N-13／T4 | 印 COMPARED_*；0 或 ≠列×欄 fail | tip CI COMPARED_CELLS=10013=527×19 |

## D 介面
無產品簽名變更。測試側僅用既有 `DemandModel.set/clear_potential_demand_provider`。

## E 自查
無新增公開重置／僅測介面。無 `_clear_state` 於本線兩檔。

## F 基線名
REMOVED＝無；ADDED＝三 EX（見 gate）。

## G — T1 D-128 最終
刪 WP56／R972 `_boot_pricing_stack` 的 `DemandModel._clear_state()`。  
改正式注入 `_ZeroPotentialDemand`（`weekly_potential_demand`→0）→ offtake-only，避免 shard 殘態 SCRIPT ERROR。  
`after_each` clear providers。EX-05-09-01..03 常數不變。diff：`t1/tests.diff`。

## H — T4 N-13 最終
`golden_compare.py` 印 COMPARED_ROWS/COLS/CELLS；`ci.yml` 閘門。  
本 tip CI：BOOTSTRAP=0；COMPARED_ROWS=527；COLS=19；CELLS=10013；DIFF_CELLS=0。  
故意不符（本地，未留紅 tip）：`t4/compared_mismatch.out`＋`t4/mismatch_how.md`。

## I CI
- Run：45565620435 success 9/9
- Gate：`ci_evidence/gate.txt` — TOTAL_PASSING=558；REMOVED＝無；ADDED＝三 EX
- Golden：`ci_evidence/golden.txt`

## 停止
不合併。等 Owner 批准合併①（#84→main）。
