# D-120(e) — gut-unit (3) failure on tip 1baa133 / run 45525619106

## Summary line
`gut-unit (3)` **failure** (job 138908172799)；Failing Tests＝1；**無 SCRIPT ERROR**（count＝0）。`golden-30d`／gut-unit(0,1,2)／gut-ui success；gate skipped。

## Failing test
`test_WP56_A21_quote_unknown_port`（`tests/unit/test_wp56_cash_market_trade.gd:161`）

## Assertion
```
[Failed]: Expected 1 push_error errors. Got 2.
[Failed]: Unexpected Errors:
  [1] <push_error>MarketPricer: UNKNOWN_PORT …
```

## Stack / ERROR lines
1. `DemandModel.load_and_validate("user://wp56_demand_force_unload/")` → ERR-SYS06-01 push_error（`_boot_pricing_stack`）
2. `MarketPricer.quote(PT-99)` → UNKNOWN_PORT push_error（測本身預期）

全文見 `gut_unit_3_A21_fail_excerpt.txt`。

## Root cause
前一修（SCRIPT ERROR）用「缺表目錄 load」卸 DemandModel，會多一筆 push_error；A21 的 `assert_push_error_count(1)` 因而失敗。shard1 已綠；本失敗為同修副作用，非產品碼。

## Fix（tip b28012c）
改 `DemandModel._clear_state()` 靜默卸載（同 `trade_desk_wp33` before_each）；無 push_error、仍 offtake-only。
