# D-120(e) — gut-unit (1) failure on tip 19d1a4e / run 45523259356

## Summary line
`gut-unit (1)` **failure** (job 138900171579)；GUT 147/147 passed，但 `ci-script-error-gate` 因 **42× SCRIPT ERROR** 失敗。`golden-30d` **success**（`GOLDEN_BOOTSTRAP=0`，artifact `14932606115`，`DIFF_CELLS=0`）。

## Failing test
`test_WP56_A18_max_affordable_respects_market_stock`（`tests/unit/test_wp56_cash_market_trade.gd:66`）

## Assertion / stack（全文見 `gut_unit_1_A18_SCRIPT_ERROR_excerpt.txt`）
```
SCRIPT ERROR: Assertion failed: PopulationModel.population before load
  at: population (res://autoload/population_model.gd:293)
  … → _has_neg_pop → _w_num → weekly_demand → weekly_potential_demand
  → _resolve_context (market_pricer.gd:355) → quote
  → _quote_buy_total (cash_ledger.gd:847) → max_affordable_qty (cash_ledger.gd:699)
  → test_WP56_A18… (test_wp56_cash_market_trade.gd:66)
```

## Root cause
W2 Given 種子使 `test_cash_ledger`／`test_wp56` 變大 → size-balanced 4-way shard 重排：WP56 落到 shard1（在 `lane_b_pop_demand`／`population_model` 之後）。前序留下 **DemandModel.loaded=true**，但 **PopulationModel 未載入**；MarketPricer 走 `weekly_potential_demand` 觸發 hard assert → SCRIPT ERROR（非 GUT assert 失敗）。

## Fix（tip 1baa133）
`_boot_pricing_stack`（WP56 + R972）：clear DemandModel providers + force-unload via missing tables path → offtake-only quote（對齊 `test_market_pricer`）。
