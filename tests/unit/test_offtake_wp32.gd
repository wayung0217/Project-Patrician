extends GutTest
## WP-32 ST-OFFTAKE acceptance: TST-SYS03-07..16, 15-08 ①③④, ERR-SYS03-07..09.
## HOLD simulated via set_container_port／container_departed (WP-30 not online).


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const GOODS_FIXTURE_ROOT := "user://offtake_wp32_goods/"
const PORTS_FIXTURE_ROOT := "user://offtake_wp32_ports/"
const PARAMS_OVERRIDE_ROOT := "user://offtake_wp32_params/"

const PORT := "PT-01"
const GOOD := "GD-001"
const OWNER_A := "ACTOR-A"
const OWNER_B := "ACTOR-B"
const ANCHOR_LI := 1000

const PRM_OFFTAKE_WINDOW := "PRM-SYS03-OFFTAKE_WINDOW_DAYS"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"

## T7 named consts (no 1+1 / 0-1 evasions)
const TWO := 2
const SNAP_MISSING := -1


class TestCapUnlimited extends CapacityProvider:
	func capacity(_container: Variant) -> int:
		return 10000


func before_each() -> void:
	var perr: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(perr.size(), 0, "params fixture must load")
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	_wipe_dir(PARAMS_OVERRIDE_ROOT)
	## D-30a side-effect: prior SimLoop boots may leave ShipRegistry loaded; HOLD
	## fixtures here are ledger-only (no ShipRegistry dock), so unload (FRM-SYS13-10).
	ShipRegistry._loaded = false
	ShipRegistry._sailor_pool = null
	_boot_catalog_ports_ledger()


func test_WP59_15_08_01_missing_offtake_window_days_refuses_boot() -> void:
	# 15-08 ①: OFFTAKE_WINDOW_DAYS 缺鍵 → boot／Params 拒絕
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARAMS_FIXTURE))
	fixture.erase(PRM_OFFTAKE_WINDOW)
	var path := _write_params(fixture, "missing_offtake.json")
	var errors: Array = Params.load_and_validate(path)
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	var found := false
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = e
		if String(d.get("code", "")) != "MISSING_KEY":
			continue
		# Params validation errors are flat C-06 shape {code,file,field,value,message}.
		if String(d.get("field", "")) == PRM_OFFTAKE_WINDOW:
			found = true
			break
	assert_true(found, "MISSING_KEY for PRM-SYS03-OFFTAKE_WINDOW_DAYS")
	assert_false(Params.is_loaded())


func test_ERR_SYS03_07_unknown_port_or_good() -> void:
	# 15-08 ③: ERR-SYS03-07
	var snap: Dictionary = GoodsLedger.offtake_snapshot(&"PT-99", StringName(GOOD))
	assert_true(snap.is_empty())
	assert_eq(StringName(GoodsLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), GoodsLedger.ERR_SYS03_07)
	var snap2: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), &"GD-999")
	assert_true(snap2.is_empty())
	assert_eq(StringName(GoodsLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), GoodsLedger.ERR_SYS03_07)
	assert_push_error_count(TWO)


func test_ERR_SYS03_08_container_departed_invalid() -> void:
	# 15-08 ③: ERR-SYS03-08 — not registered／not HOLD／not in port
	var rc: int = GoodsLedger.container_departed(&"HOLD:MISSING")
	assert_eq(rc, 0)
	assert_eq(StringName(GoodsLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), GoodsLedger.ERR_SYS03_08)
	assert_push_error_count(1)


func test_ERR_SYS03_09_hold_missing_owner() -> void:
	# 15-08 ③: ERR-SYS03-09 — HOLD without owner_id refuses registration
	var hold: Dictionary = {GoodsLedger.KEY_KIND: GoodsLedger.KIND_HOLD, GoodsLedger.KEY_SHIP: "SHIP-X"}
	var market: Dictionary = GoodsLedger.make_market(PORT)
	_seed_market(PORT, 10)
	if not GoodsLedger._capacity_providers.has(GoodsLedger.KIND_HOLD):
		assert_eq(
			GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), TestCapUnlimited.new()),
			GoodsLedger.CODE_OK
		)
	var seq: int = GoodsLedger.transfer(
		market, hold, StringName(GOOD), 1, GoodsLedger.REASON_TRADE, &"TEST"
	)
	assert_eq(seq, 0)
	assert_eq(StringName(GoodsLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), GoodsLedger.ERR_SYS03_09)
	assert_push_error_count(1)


func test_TST_SYS03_07_cross_owner_export_counts() -> void:
	# 甲賣進 100；乙買 100 上船離港 → window_qty＝100
	_seed_market(PORT, 0)
	_sell_in(OWNER_A, 100)
	var hold_b: Dictionary = _make_berthed_hold("SHIP-B", OWNER_B, PORT)
	_buy_to_hold(hold_b, 100)
	assert_eq(GoodsLedger.container_departed(StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-B"))), 100)
	GoodsLedger.set_day(1)
	GoodsLedger.roll_offtake_snapshot(1)
	var snap: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD))
	assert_eq(int(snap.get("window_qty", SNAP_MISSING)), 100)


func test_TST_SYS03_08_same_owner_offsets() -> void:
	# 甲賣進 100；同窗口甲另一船買 100 離港 → window_qty＝0
	_seed_market(PORT, 0)
	_sell_in(OWNER_A, 100)
	var hold2: Dictionary = _make_berthed_hold("SHIP-A2", OWNER_A, PORT)
	_buy_to_hold(hold2, 100)
	assert_eq(GoodsLedger.container_departed(StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-A2"))), 100)
	GoodsLedger.set_day(1)
	GoodsLedger.roll_offtake_snapshot(1)
	var snap: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD))
	assert_eq(int(snap.get("window_qty", SNAP_MISSING)), 0)


func test_TST_SYS03_09_warehouse_roundtrip_zero() -> void:
	# 甲買進倉再賣回，重複兩次 → window_qty 始終 0；pending 回 0
	_seed_market(PORT, 400)
	var wh: Dictionary = GoodsLedger.make_warehouse(OWNER_A, PORT)
	if not GoodsLedger._capacity_providers.has(GoodsLedger.KIND_WAREHOUSE):
		assert_eq(
			GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_WAREHOUSE), TestCapUnlimited.new()),
			GoodsLedger.CODE_OK
		)
	var market: Dictionary = GoodsLedger.make_market(PORT)
	for _i in range(TWO):
		assert_gt(
			GoodsLedger.transfer(market, wh, StringName(GOOD), 200, GoodsLedger.REASON_TRADE, &"TEST"),
			0
		)
		assert_gt(
			GoodsLedger.transfer(wh, market, StringName(GOOD), 200, GoodsLedger.REASON_TRADE, &"TEST"),
			0
		)
		GoodsLedger.set_day(GoodsLedger.current_day() + 1)
		GoodsLedger.roll_offtake_snapshot(GoodsLedger.current_day())
		var snap: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD))
		assert_eq(int(snap.get("window_qty", SNAP_MISSING)), 0)
	var wh_cid: String = String(GoodsLedger.container_id(StringName(GoodsLedger.KIND_WAREHOUSE), OWNER_A, PORT))
	var pend_left: int = 0
	if GoodsLedger._offtake_pending.has(wh_cid):
		pend_left = int((GoodsLedger._offtake_pending[wh_cid] as Dictionary).get(GOOD, 0))
	assert_eq(pend_left, 0)


func test_TST_SYS03_10_depart_after_berth_days() -> void:
	# 乙買 100 上船，停泊兩日後離港 → 前兩日不含；離港當日含
	_seed_market(PORT, 100)
	var hold: Dictionary = _make_berthed_hold("SHIP-BERTH", OWNER_B, PORT)
	_buy_to_hold(hold, 100)
	GoodsLedger.set_day(1)
	GoodsLedger.roll_offtake_snapshot(1)
	assert_eq(int(GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD)).get("window_qty", 0)), 0)
	GoodsLedger.set_day(2)
	GoodsLedger.roll_offtake_snapshot(2)
	assert_eq(int(GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD)).get("window_qty", 0)), 0)
	assert_eq(
		GoodsLedger.container_departed(StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-BERTH"))),
		100
	)
	GoodsLedger.set_day(3)
	GoodsLedger.roll_offtake_snapshot(3)
	assert_eq(int(GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD)).get("window_qty", 0)), 100)


func test_TST_SYS03_11_local_consume() -> void:
	_seed_market(PORT, 50)
	var market: Dictionary = GoodsLedger.make_market(PORT)
	assert_gt(
		GoodsLedger.transfer(
			market, GoodsLedger.make_external(), StringName(GOOD), 50, GoodsLedger.REASON_CONSUME, &"TEST"
		),
		0
	)
	GoodsLedger.set_day(1)
	GoodsLedger.roll_offtake_snapshot(1)
	var snap: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD))
	assert_eq(int(snap.get("local_qty", SNAP_MISSING)), 50)
	assert_eq(int(snap.get("window_qty", SNAP_MISSING)), 50)


func test_TST_SYS03_12_warehouse_consume_clears_pending() -> void:
	_seed_market(PORT, 30)
	var wh: Dictionary = GoodsLedger.make_warehouse(OWNER_A, PORT)
	if not GoodsLedger._capacity_providers.has(GoodsLedger.KIND_WAREHOUSE):
		assert_eq(
			GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_WAREHOUSE), TestCapUnlimited.new()),
			GoodsLedger.CODE_OK
		)
	var market: Dictionary = GoodsLedger.make_market(PORT)
	assert_gt(GoodsLedger.transfer(market, wh, StringName(GOOD), 30, GoodsLedger.REASON_TRADE, &"TEST"), 0)
	assert_gt(
		GoodsLedger.transfer(wh, GoodsLedger.make_external(), StringName(GOOD), 30, GoodsLedger.REASON_CONSUME, &"TEST"),
		0
	)
	GoodsLedger.set_day(1)
	GoodsLedger.roll_offtake_snapshot(1)
	var snap: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD))
	assert_eq(int(snap.get("local_qty", SNAP_MISSING)), 30)
	var cid: String = String(GoodsLedger.container_id(StringName(GoodsLedger.KIND_WAREHOUSE), OWNER_A, PORT))
	assert_false(GoodsLedger._offtake_pending.has(cid) and int(GoodsLedger._offtake_pending[cid].get(GOOD, 0)) > 0)


func test_TST_SYS03_13_window_prunes_old_days() -> void:
	# W=7: day ≤ d−W pruned
	_seed_market(PORT, 200)
	var market: Dictionary = GoodsLedger.make_market(PORT)
	GoodsLedger.set_day(1)
	assert_gt(
		GoodsLedger.transfer(
			market, GoodsLedger.make_external(), StringName(GOOD), 50, GoodsLedger.REASON_CONSUME, &"TEST"
		),
		0
	)
	GoodsLedger.roll_offtake_snapshot(1)
	assert_eq(int(GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD)).get("window_qty", 0)), 50)
	# Advance to day 8 with W=7 → day 1 record (1 ≤ 8−7) pruned
	GoodsLedger.set_day(8)
	GoodsLedger.roll_offtake_snapshot(8)
	assert_eq(int(GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD)).get("window_qty", 0)), 0)
	# Ensure daily cell for day 1 gone
	var by_port: Dictionary = GoodsLedger._offtake_daily.get(PORT, {})
	var by_good: Dictionary = by_port.get(GOOD, {})
	assert_false(by_good.has("1"))


func test_TST_SYS03_14_foreign_cargo_depart_no_export() -> void:
	# 船載外港貨抵 P，未在 P 買即離港 → P window 不變
	_seed_market(PORT, 0)
	GoodsLedger.set_day(1)
	GoodsLedger.roll_offtake_snapshot(1)
	var before: int = int(GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD)).get("window_qty", 0))
	var hold: Dictionary = _make_berthed_hold("SHIP-FOREIGN", OWNER_B, PORT)
	# Seed HOLD with GENESIS (foreign cargo — not bought at P); capacity already registered.
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(), hold, StringName(GOOD), 40, GoodsLedger.REASON_GENESIS, &"TEST"
		),
		0
	)
	assert_eq(
		GoodsLedger.container_departed(StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-FOREIGN"))),
		0
	)
	GoodsLedger.set_day(2)
	GoodsLedger.roll_offtake_snapshot(2)
	var after: int = int(GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD)).get("window_qty", 0))
	assert_eq(after, before)


func test_TST_SYS03_15_same_day_quotes_use_prior_snapshot() -> void:
	# 同日先買 10 再買 110 對照整批 120 — 皆用前一日快照；拆單同價仍成立（TST-SYS04-04）
	_boot_market_pricer(300, 105)
	var q120: Dictionary = MarketPricer.quote(StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 120)
	assert_false(q120.has(MarketPricer.KEY_ERROR))
	var batch: int = int(q120["total_li"])

	var q10: Dictionary = MarketPricer.quote(StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 10)
	assert_false(q10.has(MarketPricer.KEY_ERROR))
	var hold: Dictionary = _make_berthed_hold("SHIP-SPLIT", OWNER_A, PORT)
	_buy_to_hold(hold, 10)
	var q110: Dictionary = MarketPricer.quote(StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 110)
	assert_false(q110.has(MarketPricer.KEY_ERROR))
	var extra: int = int(q10["total_li"]) + int(q110["total_li"]) - batch
	assert_gte(extra, 0)
	assert_lte(extra, 1)


func test_TST_SYS03_16_pending_invariant_debug() -> void:
	_seed_market(PORT, 20)
	var hold: Dictionary = _make_berthed_hold("SHIP-INV", OWNER_A, PORT)
	_buy_to_hold(hold, 10)
	assert_eq(GoodsLedger.debug_check_offtake_invariants(), GoodsLedger.CODE_OK)


func test_WP59_15_08_04_cross_day_resale_red_team_60() -> void:
	# 紅隊-60／15-08 ④: 大量買走離港灌分母，隔日返港賣回。
	# Test assumptions (explicit, not formal balance): voyage cost＝0；holding cost＝0；
	# earliest return = next day; same-port berth via set_container_port.
	const BUY_Q := 100
	const STOCK0 := 300
	const WEEKLY0 := 105
	_boot_market_pricer(STOCK0, WEEKLY0)

	# Day-0 snapshot already injected (WEEKLY0). Buy at prior-day offtake.
	var buy: Dictionary = MarketPricer.quote(StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, BUY_Q)
	assert_false(buy.has(MarketPricer.KEY_ERROR))
	var buy_total: int = int(buy["total_li"])
	var hold: Dictionary = _make_berthed_hold("SHIP-RT60", OWNER_A, PORT)
	_buy_to_hold(hold, BUY_Q)
	var departed: int = GoodsLedger.container_departed(
		StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-RT60"))
	)
	assert_eq(departed, BUY_Q)

	# End of buy day → snapshot includes export.
	GoodsLedger.set_day(1)
	GoodsLedger.roll_offtake_snapshot(1)
	var snap_after_depart: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD))
	var window_after_depart: int = int(snap_after_depart.get("window_qty", 0))
	assert_gt(window_after_depart, 0)

	# Return next day: re-berth, sell back. Same-day sell still reads day-1 snapshot (not yet rolled).
	assert_eq(
		GoodsLedger.set_container_port(
			StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-RT60")),
			StringName(PORT)
		),
		GoodsLedger.CODE_OK
	)
	GoodsLedger.set_day(2)
	var sell: Dictionary = MarketPricer.quote(StringName(PORT), StringName(GOOD), MarketPricer.SIDE_SELL, BUY_Q)
	assert_false(sell.has(MarketPricer.KEY_ERROR))
	var sell_total: int = int(sell["total_li"])
	var market: Dictionary = GoodsLedger.make_market(PORT)
	assert_gt(
		GoodsLedger.transfer(hold, market, StringName(GOOD), BUY_Q, GoodsLedger.REASON_TRADE, &"TEST"),
		0
	)
	GoodsLedger.roll_offtake_snapshot(2)
	var snap_after_sellin: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD))
	# Same-owner net in window: export−sellin → 0 after sell-in offsets.
	var window_after_sellin: int = int(snap_after_sellin.get("window_qty", SNAP_MISSING))

	var trade_pnl: int = sell_total - buy_total
	var voyage_cost: int = 0 ## assumption
	var holding_cost: int = 0 ## assumption
	var net_pnl: int = trade_pnl - voyage_cost - holding_cost

	# Multi-round: repeat same pattern once more from current state.
	var buy2: Dictionary = MarketPricer.quote(StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, BUY_Q)
	var buy2_total: int = int(buy2.get("total_li", 0))
	# Need stock for second buy — seed if needed.
	var stock_now: int = GoodsLedger.get_qty(market, StringName(GOOD))
	if stock_now < BUY_Q:
		_seed_market(PORT, BUY_Q - stock_now)
	buy2 = MarketPricer.quote(StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, BUY_Q)
	buy2_total = int(buy2["total_li"])
	assert_eq(
		GoodsLedger.set_container_port(
			StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-RT60")),
			StringName(PORT)
		),
		GoodsLedger.CODE_OK
	)
	assert_gt(GoodsLedger.transfer(market, hold, StringName(GOOD), BUY_Q, GoodsLedger.REASON_TRADE, &"TEST"), 0)
	assert_eq(
		GoodsLedger.container_departed(StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-RT60"))),
		BUY_Q
	)
	GoodsLedger.set_day(3)
	GoodsLedger.roll_offtake_snapshot(3)
	assert_eq(
		GoodsLedger.set_container_port(
			StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), "SHIP-RT60")),
			StringName(PORT)
		),
		GoodsLedger.CODE_OK
	)
	GoodsLedger.set_day(4)
	var sell2: Dictionary = MarketPricer.quote(StringName(PORT), StringName(GOOD), MarketPricer.SIDE_SELL, BUY_Q)
	var sell2_total: int = int(sell2["total_li"])
	# Reload hold qty via genesis if emptied — cargo still on HOLD from second buy.
	var trade_pnl2: int = sell2_total - buy2_total
	var net_pnl2: int = trade_pnl2 - voyage_cost - holding_cost

	# Record results for PR／Owner (do not change spec).
	var single_round_profit: bool = net_pnl > 0
	var multi_round_profit: bool = net_pnl > 0 and net_pnl2 > 0
	var repeatable_profit_possible: bool = multi_round_profit

	print("WP32-15-08-04 snap_after_depart=%s window_after_sellin=%s" % [str(snap_after_depart), window_after_sellin])
	print("WP32-15-08-04 single trade_pnl=%d net_pnl=%d" % [trade_pnl, net_pnl])
	print("WP32-15-08-04 multi trade_pnl2=%d net_pnl2=%d" % [trade_pnl2, net_pnl2])
	print("WP32-15-08-04 single_round_profit=%s multi_round_profit=%s repeatable=%s" % [
		str(single_round_profit), str(multi_round_profit), str(repeatable_profit_possible)
	])

	# Persist structured notes for the PR report via gut stdout; assertions still validate mechanics.
	assert_gt(window_after_depart, 0, "depart must raise offtake window")
	assert_lte(window_after_sellin, window_after_depart, "sell-in should offset same-owner export in window")
	# File artifact for report parsing
	var notes := FileAccess.open("user://offtake_wp32_resale_notes.txt", FileAccess.WRITE)
	if notes != null:
		notes.store_string(
			"single_trade_pnl=%d\nsingle_net_pnl=%d\nmulti_trade_pnl=%d\nmulti_net_pnl=%d\nrepeatable_profit=%s\n"
			% [trade_pnl, net_pnl, trade_pnl2, net_pnl2, str(repeatable_profit_possible)]
		)
		notes.close()


# --- helpers ---

func _boot_catalog_ports_ledger() -> void:
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "base/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_valid_ports(Params.get_int(PRM_PORT_COUNT_MIN), PORTS_FIXTURE_ROOT + "base/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)


func _boot_market_pricer(stock: int, weekly_offtake: int) -> void:
	_seed_market(PORT, stock)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	GoodsLedger.seed_offtake_snapshot(
		StringName(PORT), StringName(GOOD), weekly_offtake, weekly_offtake, days_pw, 0
	)


func _seed_market(port_id: String, stock: int) -> void:
	if stock <= 0:
		return
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			GoodsLedger.make_market(port_id),
			StringName(GOOD),
			stock,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)


func _sell_in(owner_id: String, qty: int) -> void:
	# Owner sells into market: HOLD → MARKET (sellin). Seed HOLD via GENESIS first.
	var hold: Dictionary = _make_berthed_hold("SHIP-SELL-%s" % owner_id, owner_id, PORT)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(), hold, StringName(GOOD), qty, GoodsLedger.REASON_GENESIS, &"TEST"
		),
		0
	)
	assert_gt(
		GoodsLedger.transfer(
			hold, GoodsLedger.make_market(PORT), StringName(GOOD), qty, GoodsLedger.REASON_TRADE, &"TEST"
		),
		0
	)


func _make_berthed_hold(ship_id: String, owner_id: String, port_id: String) -> Dictionary:
	var hold: Dictionary = GoodsLedger.make_hold(ship_id, owner_id)
	if not GoodsLedger._capacity_providers.has(GoodsLedger.KIND_HOLD):
		assert_eq(
			GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_HOLD), TestCapUnlimited.new()),
			GoodsLedger.CODE_OK
		)
	# Register container meta via GENESIS 1 then CONSUME 1 back (GENESIS／pending-0 CONSUME: no offtake).
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(), hold, StringName(GOOD), 1, GoodsLedger.REASON_GENESIS, &"TEST"
		),
		0
	)
	assert_gt(
		GoodsLedger.transfer(
			hold, GoodsLedger.make_external(), StringName(GOOD), 1, GoodsLedger.REASON_CONSUME, &"TEST"
		),
		0
	)
	assert_eq(
		GoodsLedger.set_container_port(
			StringName(GoodsLedger.container_id(StringName(GoodsLedger.KIND_HOLD), ship_id)),
			StringName(port_id)
		),
		GoodsLedger.CODE_OK
	)
	return hold


func _buy_to_hold(hold: Dictionary, qty: int) -> void:
	var market: Dictionary = GoodsLedger.make_market(PORT)
	assert_gt(
		GoodsLedger.transfer(market, hold, StringName(GOOD), qty, GoodsLedger.REASON_TRADE, &"TEST"),
		0
	)


func _write_params(fixture: Dictionary, filename: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARAMS_OVERRIDE_ROOT))
	var path := PARAMS_OVERRIDE_ROOT + filename
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(fixture))
	f.close()
	return path


func _build_valid_goods(dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": "GD-001", "name": "米", "build": false},
		{"id": "GD-002", "name": "鹽", "build": false},
		{"id": "GD-003", "name": "木材", "build": true},
		{"id": "GD-004", "name": "魚乾", "build": false},
	]
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		ResourceSaver.save(_make_good(s["id"], s["name"], 1, true, s["build"], ANCHOR_LI), dir + "%s.tres" % s["id"])
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		ResourceSaver.save(_make_good(gid, "填料%d" % next_n, 1, false, false, next_n), dir + "%s.tres" % gid)
		written += 1
		next_n += 1
	return dir


func _build_valid_ports(port_count: int, dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var free_count: int = _valid_free_count(port_count)
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	for i in range(port_count):
		var n: int = i + 1
		var port_id := "PT-%02d" % n
		var def := PortDef.new()
		def.port_id = port_id
		def.name_zh = "港%d" % n
		def.is_free_port = i < free_count
		def.draft_limit_class = 0
		def.regime_id = "RG-TEST"
		def.role_cells = {}
		for good_variant in good_ids:
			var good_id: String = String(good_variant)
			var cell := RoleCell.new()
			if i == 0:
				cell.role = PortRegistry.ROLE_PRODUCER
				cell.base_output_per_season = 1
			else:
				cell.role = PortRegistry.ROLE_TERMINAL
				cell.base_output_per_season = 0
			cell.downstream_terminals = PackedStringArray()
			def.role_cells[good_id] = cell
		ResourceSaver.save(def, dir + "%s.tres" % port_id)
	return dir


func _valid_free_count(port_count: int) -> int:
	var ratio_min: float = Params.get_float(PRM_FREE_PORT_RATIO_MIN)
	var ratio_max: float = Params.get_float(PRM_FREE_PORT_RATIO_MAX)
	var free_count: int = 0
	while free_count <= port_count:
		var ratio: float = float(free_count) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return free_count
		free_count += 1
	return 0


func _make_good(
	good_id: String, name_zh: String, tier: int, is_staple: bool, is_build_material: bool, base_price_li: int
) -> GoodDef:
	var def := GoodDef.new()
	def.good_id = good_id
	def.name_zh = name_zh
	def.tier = tier
	def.is_staple = is_staple
	def.is_build_material = is_build_material
	def.is_strategic = false
	def.base_price_li = base_price_li
	var seasons: int = Params.get_int(PRM_SEASONS_PER_YEAR)
	def.season_mask = (1 << seasons) - 1
	return def


func _wipe_dir(dir: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var fname: String = d.get_next()
	while fname != "":
		if fname == "." or fname == "..":
			fname = d.get_next()
			continue
		if d.current_is_dir():
			_wipe_dir(dir.path_join(fname))
		else:
			d.remove(fname)
		fname = d.get_next()
	d.list_dir_end()
