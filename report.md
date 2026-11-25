# review/1770-t1 — T1 D-128 + T4 COMPARED_CELLS

## Product tip (final)
`9f228f04abfff6ac1a1a03586a7b5250378ff97e`
CI: https://github.com/wayung0217/Project-Patrician/actions/runs/45569511994 — **9/9 success**

## Gate
```
REMOVED_NAMES: 無
ADDED_NAMES:
test_R972_EX_05_09_01_stock_bottleneck_q_300
test_R972_EX_05_09_02_cash_bottleneck_q_120
test_R972_EX_05_09_03_zero_stock_no_quote
TOTAL_PASSING=558
```

## COMPARED_* (T4／N-13；CSV 權威)
`GOLDEN_BOOTSTRAP=0` · `COMPARED_ROWS=527` · `COMPARED_COLS=19` · `COMPARED_CELLS=10013` · `DIFF_CELLS=0` · CSV 527×19 both · `GOLDEN_CELLS_IDENTICAL=1`

## T4 cells=0 fix
#85 移植僅 ci.yml → 舊 golden_compare 在 IDENTICAL=1 不印 COMPARED_* → 閘門 cells=0。
tip `9f228f04abfff6ac1a1a03586a7b5250378ff97e`：COMPARED_* 改由兩 CSV 網格計算。證據見 `t4/cells0_root_cause.md`、`t4/ci_yml_csv_grid_gate.diff`。

## Orphan history
- `b99d61d` tip 8f200cf pack
- `a45dc73` GOLDEN_BASE_RUN_ID
- this commit: tip 9f228f0 CI green + CSV-grid gate

## Stop
不合併。等 Owner 批准合併①（#84→main）。
