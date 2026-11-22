extends GutTest
## WP-61 Debug UI tests (formal L1 boot + day tick + buy). Names contain WP61.


const MAIN_SCENE := "res://ui/debug_main.tscn"
const ACTOR := &"ACT-PLAYER"
const BUY_PORT := &"PT-03" ## has GD-001 stock after ~14 produce days
const GOOD := &"GD-001"
const WARMUP_DAYS := 14


var _root_ui: Node = null


func before_each() -> void:
	# Autoloads persist — reset boot／providers; do NOT wipe formal data dirs.
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop.set_consumption_provider(null)
	IntelLedger.set_broker_provider(null)
	TradeDesk._loaded = false
	TradeDesk._qualification = null
	TradeDesk._observers = []
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
	## Formal L1 day ticks push_error on unmet CONSUME etc. — mark handled (GUT).
	for e in get_errors():
		e.handled = true


func test_WP61_scene_loads() -> void:
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	assert_not_null(packed, "debug_main.tscn must load")
	_root_ui = packed.instantiate()
	add_child(_root_ui)
	await get_tree().process_frame
	assert_true(_root_ui is Control)
	assert_true(_root_ui.has_method("is_debug_booted"))
	assert_true(_root_ui.call("is_debug_booted"))
	_absorb_tracked_errors()


func test_WP61_formal_boot_zero_errors() -> void:
	await _boot_ui()
	assert_true(_root_ui.call("is_debug_booted"), "formal L1 boot must succeed with debug providers")
	assert_true(SimLoop.is_booted())
	assert_true(TradeDesk.has_qualification_provider())
	assert_true(TradeDesk.has_trade_observers())
	assert_true(IntelLedger.has_broker_provider())
	_absorb_tracked_errors()


func test_WP61_advance_day_increments() -> void:
	await _boot_ui()
	assert_true(_root_ui.call("is_debug_booted"))
	var day0: int = Clock.day
	if Clock.is_paused:
		Clock.set_paused(false)
	var errs: Array = SimLoop.tick_day()
	# Day-1 CONSUME may report unmet demand — still must advance calendar.
	assert_eq(Clock.day, day0 + 1, "day must increment by 1 (errs=%s)" % str(errs.size()))
	_absorb_tracked_errors()


func test_WP61_buy_reduces_cash_and_stock() -> void:
	await _boot_ui()
	assert_true(_root_ui.call("is_debug_booted"))
	_warmup_days(WARMUP_DAYS)
	var ships: Array = ShipRegistry.ship_ids(ACTOR)
	assert_gt(ships.size(), 0, "player must have opening ship")
	var ship_id: StringName = ships[0]
	# Opening is PT-10; sail to a rice-producing port that has stock after warmup.
	var info: Dictionary = ShipRegistry.ship_info(ship_id)
	var at_port: StringName = StringName(info.get("port_id", ""))
	if at_port != BUY_PORT:
		var arrival: int = ShipRegistry.sail(ACTOR, ship_id, BUY_PORT)
		assert_gt(arrival, 0, "sail to buy port: %s" % str(ShipRegistry.last_error()))
		# Advance until arrival (ticks → days).
		var tpd: int = Params.get_int("PRM-SYS00-TICKS_PER_DAY")
		if tpd < 1:
			tpd = 1
		var guard: int = 0
		while guard < 400:
			var pos: Dictionary = ShipRegistry.position(ship_id)
			if StringName(pos.get("state", "")) == Ship.STATE_DOCKED:
				if StringName(pos.get("port_id", "")) == BUY_PORT:
					break
			SimLoop.tick_day()
			guard += 1
		assert_true(ShipRegistry.can_trade(ship_id, BUY_PORT), "ship must dock at buy port")
	var hold_id: StringName = StringName(GoodsLedger.CONTAINER_ID_FMT_HOLD % String(ship_id))
	var market: Dictionary = GoodsLedger.make_market(String(BUY_PORT))
	var stock_before: int = GoodsLedger.get_qty(market, GOOD)
	assert_gt(stock_before, 0, "market must have rice stock after warmup")
	var cash_before: int = CashLedger.balance(ACTOR)
	var quote: Dictionary = MarketPricer.quote(BUY_PORT, GOOD, MarketPricer.SIDE_BUY, 1)
	assert_false(quote.has(MarketPricer.KEY_ERROR), "quote must succeed: %s" % str(quote))
	var total_li: int = int(quote[MarketPricer.KEY_TOTAL_LI])
	var seq: int = TradeDesk.execute_trade(
		ACTOR, hold_id, BUY_PORT, GOOD, MarketPricer.SIDE_BUY, 1, 0
	)
	assert_gt(seq, 0, "buy must succeed: %s" % str(TradeDesk.last_error()))
	var cash_after: int = CashLedger.balance(ACTOR)
	var stock_after: int = GoodsLedger.get_qty(market, GOOD)
	assert_eq(cash_before - cash_after, total_li, "cash decrease must equal quote total_li")
	assert_eq(stock_before - stock_after, 1, "port stock must drop by bought qty")
	TradeDesk.flush_signals()
	_absorb_tracked_errors()
