extends GutTest
## WP-62 M0 UI: D-95(d) APIs wired; ship capacity displays 150 擔 (scenario D-94a).


const MAIN_SCENE := "res://ui/debug_main.tscn"
const ACTOR := &"ACT-PLAYER"
const BUY_PORT := &"PT-03" ## 福州
const SELL_PORT := &"PT-01" ## 月港
const GOOD := &"GD-001"
const WARMUP_DAYS := 14
const EXPECT_CAPACITY := 150


var _root_ui: Node = null


func before_each() -> void:
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop.set_consumption_provider(null)
	IntelLedger.set_broker_provider(null)
	TradeDesk._loaded = false
	TradeDesk._qualification = null
	TradeDesk._observers = []
	TradeDesk._last_trade_total_li = 0
	ShipRegistry.set_sailor_pool_provider(null)
	ShipRegistry.set_ship_observer(null)


func after_each() -> void:
	if _root_ui != null and is_instance_valid(_root_ui):
		_root_ui.queue_free()
		_root_ui = null
	await get_tree().process_frame


func _boot_ui() -> void:
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	_root_ui = packed.instantiate()
	add_child(_root_ui)
	await get_tree().process_frame


func _warmup_days(n: int) -> void:
	if Clock.is_paused:
		Clock.set_paused(false)
	for _i in range(n):
		SimLoop.tick_day()


func _absorb_tracked_errors() -> void:
	for e in get_errors():
		e.handled = true


func _sail_until(ship_id: StringName, port: StringName) -> void:
	var info: Dictionary = ShipRegistry.ship_info(ship_id)
	if StringName(info.get("port_id", "")) == port and StringName(info.get("state", "")) == Ship.STATE_DOCKED:
		return
	if StringName(info.get("state", "")) == Ship.STATE_DOCKED:
		var arrival: int = ShipRegistry.sail(ACTOR, ship_id, port)
		assert_gt(arrival, 0, "sail: %s" % str(ShipRegistry.last_error()))
	var guard: int = 0
	while guard < 400:
		var pos: Dictionary = ShipRegistry.position(ship_id)
		if StringName(pos.get("state", "")) == Ship.STATE_DOCKED:
			if StringName(pos.get("port_id", "")) == port:
				return
		SimLoop.tick_day()
		guard += 1
	assert_true(false, "did not arrive at %s" % String(port))


func test_TST_WP62_UI_capacity_shows_150_dan() -> void:
	await _boot_ui()
	assert_true(_root_ui.call("is_debug_booted"))
	var ships: Array = ShipRegistry.ship_ids(ACTOR)
	assert_gt(ships.size(), 0)
	var hold: Dictionary = GoodsLedger.make_hold(String(ships[0]), String(ACTOR))
	var cap: int = ShipRegistry.capacity_for_hold(hold)
	assert_eq(cap, EXPECT_CAPACITY, "SH-01 capacity must be 150 擔 after D-94a scenario")
	assert_eq(GoodsLedger.container_used(hold), 0)
	_root_ui.call("refresh_panels")
	await get_tree().process_frame
	assert_true(_ui_text_contains("150"), "player panel must show 150 擔 capacity")
	assert_true(_ui_text_contains("擔"), "player panel must label 擔")
	var lids: Array[StringName] = SeaLanes.lane_ids()
	assert_gt(lids.size(), 0)
	_absorb_tracked_errors()


func test_TST_WP62_UI_fuzhou_buy_yuegang_sell_last_trade() -> void:
	await _boot_ui()
	assert_true(_root_ui.call("is_debug_booted"))
	_warmup_days(WARMUP_DAYS)
	var ships: Array = ShipRegistry.ship_ids(ACTOR)
	var ship_id: StringName = ships[0]
	_sail_until(ship_id, BUY_PORT)
	_root_ui.call("force_select_port", BUY_PORT)
	_root_ui.call("force_select_good", GOOD)
	_root_ui.call("refresh_panels")
	var hold_id: StringName = StringName(GoodsLedger.CONTAINER_ID_FMT_HOLD % String(ship_id))
	var quote: Dictionary = MarketPricer.quote(BUY_PORT, GOOD, MarketPricer.SIDE_BUY, 1)
	assert_false(quote.has(MarketPricer.KEY_ERROR))
	var buy_li: int = int(quote[MarketPricer.KEY_TOTAL_LI])
	var seq: int = TradeDesk.execute_trade(
		ACTOR, hold_id, BUY_PORT, GOOD, MarketPricer.SIDE_BUY, 1, 0
	)
	assert_gt(seq, 0, "Fuzhou buy: %s" % str(TradeDesk.last_error()))
	assert_eq(TradeDesk.last_trade_total_li(), buy_li)
	assert_eq(int(_root_ui.call("last_trade_total_li")), buy_li)
	_sail_until(ship_id, SELL_PORT)
	_root_ui.call("force_select_port", SELL_PORT)
	_root_ui.call("refresh_panels")
	var sell_q: Dictionary = MarketPricer.quote(SELL_PORT, GOOD, MarketPricer.SIDE_SELL, 1)
	assert_false(sell_q.has(MarketPricer.KEY_ERROR))
	var sell_li: int = int(sell_q[MarketPricer.KEY_TOTAL_LI])
	var seq2: int = TradeDesk.execute_trade(
		ACTOR, hold_id, SELL_PORT, GOOD, MarketPricer.SIDE_SELL, 1, 0
	)
	assert_gt(seq2, 0, "Yuegang sell: %s" % str(TradeDesk.last_error()))
	assert_eq(TradeDesk.last_trade_total_li(), sell_li)
	TradeDesk.flush_signals()
	_absorb_tracked_errors()


func _ui_text_contains(needle: String) -> bool:
	if _root_ui == null:
		return false
	return _scan_labels(_root_ui, needle)


func _scan_labels(n: Node, needle: String) -> bool:
	if n is Label:
		if needle in (n as Label).text:
			return true
	if n is RichTextLabel:
		if needle in (n as RichTextLabel).get_parsed_text():
			return true
	for c in n.get_children():
		if _scan_labels(c, needle):
			return true
	return false
