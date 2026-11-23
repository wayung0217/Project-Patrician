extends GutTest
## WP-62 / D-95(d): SeaLanes.lane_ids + TradeDesk.last_trade_total_li (no formal wipe).
## GoodsLedger.container_used covered in test_goods_ledger.gd (TST-WP62).


func before_each() -> void:
	TradeDesk._last_trade_total_li = 0


func test_TST_WP62_D95d_last_trade_total_li_boot_and_clear() -> void:
	assert_true(TradeDesk.has_method("last_trade_total_li"))
	TradeDesk._clear_state()
	assert_eq(TradeDesk.last_trade_total_li(), 0)
	TradeDesk._last_trade_total_li = 42
	assert_eq(TradeDesk.last_trade_total_li(), 42)
	TradeDesk._clear_state()
	assert_eq(TradeDesk.last_trade_total_li(), 0, "clear_state resets to boot 0")


func test_TST_WP62_D95d_lane_ids_method_and_sort_contract() -> void:
	assert_true(SeaLanes.has_method("lane_ids"))
	## Loaded path only (unloaded lane_ids push_error — covered by SeaLanes.nodes contract).
	SeaLanes._lane_ids_sorted = PackedStringArray(["LN-01", "LN-02", "LN-10"])
	SeaLanes._loaded = true
	var ids: Array[StringName] = SeaLanes.lane_ids()
	assert_eq(ids.size(), 3)
	assert_eq(String(ids[0]), "LN-01")
	assert_eq(String(ids[1]), "LN-02")
	assert_eq(String(ids[2]), "LN-10")
	SeaLanes._loaded = false
