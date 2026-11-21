extends GutTest
## WP-33 TradeDesk：TST-SYS05-13..24、D-28d／D-33b／D-39b／D-42.
## Fixtures only for QualificationProvider／TradeObserver (N-05).


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp33_trade_desk/"
const GOODS_ROOT := ROOT + "goods/"
const PORTS_ROOT := ROOT + "ports/"
const SEA_ROOT := ROOT + "sea/"
const DEMAND_OUT := ROOT + "demand_out/"

const PORT := "PT-01"
const PORT_OTHER := "PT-02"
const GOOD := "GD-001"
const ACTOR := &"ACT-PLAYER"
const ACTOR_B := &"ACT-TRADER-B"
const ANCHOR_LI := 1000

const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_PORT_COUNT_MAX := "PRM-SYS02-PORT_COUNT_MAX"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_START_CASH := "PRM-SYS05-START_CASH"

const CsvImport := preload("res://tools/csv_import.gd")
const SEA_OK_CSV := "res://tests/fixtures/wp29_sea_ok/"
const OPENING_FIXTURE_CSV := "res://tests/fixtures/sim_loop_opening/"
const DEMAND_CSV_OK := "res://tests/fixtures/demand/ok/"
const DEMAND_RATE_SCALE := 100
const DEMAND_PPM_SCALE := 1000000
const DEMAND_WEIGHT_SUM := 100

const FORMAL_ZONES_DIR := "res://data/zones/"
const FORMAL_BUILDINGS_DIR := "res://data/buildings/"
const FORMAL_OPENING_DIR := "res://data/opening/"
const FORMAL_BUILD_QUEUE_DIR := "res://data/build_queue/"
const FORMAL_CITY_CENTER_DIR := "res://data/city_center/"
const FORMAL_OPENING_PUBLIC_DIR := "res://data/opening_public/"
const FORMAL_OPENING_POP_DIR := "res://data/opening_population/"


class TestCapFixed extends CapacityProvider:
	var cap_value: int = 10000

	func capacity(_container: Variant) -> int:
		return cap_value


class _Pop0 extends PopulationProvider:
	func population(_port_id: StringName) -> int:
		return 0


class _Work0 extends WorkforceProvider:
	func workers(_ws_id: StringName) -> int:
		return 0


class _Sat0 extends SatisfactionInputProvider:
	func satisfaction_input(_port_id: StringName, _clazz: StringName) -> float:
		return 0.5


class _Consume0 extends ConsumptionProvider:
	func consume_qty(_port_id: StringName, _good_id: StringName, _day: int) -> int:
		return 0


func before_each() -> void:
	_wipe_dir(ROOT)
	_wipe_formal_opening_tres()
	_reset_trade_desk()
	ShipRegistry._loaded = false
	ShipRegistry._sailor_pool = null
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop.set_consumption_provider(null)
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	DemandModel._clear_state()
	SeaLanes._loaded = false


func after_each() -> void:
	_wipe_formal_opening_tres()


func test_qualification_provider_base_push_error_2_1_03() -> void:
	var base := QualificationProvider.new()
	assert_false(base.can_enter(ACTOR, StringName(PORT)))
	assert_false(base.can_trade(ACTOR, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY))
	assert_false(base.can_build(ACTOR, StringName(PORT)))
	assert_push_error_count(3)


func test_trade_observer_base_push_error_2_1_03() -> void:
	var base := TradeObserver.new()
	assert_eq(
		base.record_trade(ACTOR, StringName(PORT), StringName(GOOD), 0, 1, 1.0, 1.0, 1),
		TradeObserver.RECORD_FAIL
	)
	assert_push_error_count(1)


func test_WP33_D63b_sim_qualification_fixture_always_denies() -> void:
	## D-63b: SimQualificationFixture is deny-all with ErrorInfo；never always-allow.
	var fx := SimQualificationFixture.new()
	assert_false(fx.can_enter(ACTOR, StringName(PORT)))
	assert_eq(
		StringName(fx.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		QualificationProvider.ERR_SYS09_08
	)
	assert_false(
		fx.can_trade(ACTOR, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY)
	)
	assert_eq(
		StringName(fx.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		QualificationProvider.ERR_SYS09_09
	)
	assert_false(fx.can_build(ACTOR, StringName(PORT)))
	assert_eq(
		StringName(fx.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		QualificationProvider.ERR_SYS09_08
	)
	assert_push_error_count(3)


func test_WP33_D63b_sim_trade_observer_fixture_no_record() -> void:
	## D-63b: SimTradeObserverFixture records nothing and never returns RECORD_OK.
	var fx := SimTradeObserverFixture.new()
	var cash_before: int = 0
	if CashLedger.is_loaded() and CashLedger.has_account(ACTOR):
		cash_before = CashLedger.balance(ACTOR)
	assert_eq(
		fx.record_trade(ACTOR, StringName(PORT), StringName(GOOD), 0, 1, 1.0, 1.0, 1),
		TradeObserver.RECORD_FAIL
	)
	if CashLedger.is_loaded() and CashLedger.has_account(ACTOR):
		assert_eq(CashLedger.balance(ACTOR), cash_before)


func test_WP33_D63b_sim_fixtures_satisfy_boot_gate() -> void:
	## D-63b: deny-all Sim fixtures unblock TradeDesk boot_gate（sim／probe inject path）.
	TradeDesk._loaded = false
	TradeDesk._qualification = null
	TradeDesk._observers = []
	TradeDesk.set_qualification_provider(SimQualificationFixture.new())
	TradeDesk.set_trade_observers([SimTradeObserverFixture.new()])
	assert_true(TradeDesk.has_qualification_provider())
	assert_true(TradeDesk.has_trade_observers())
	assert_eq(TradeDesk.boot_gate_errors().size(), 0)


func test_TST_SYS05_13_boot_missing_qualification_provider() -> void:
	var fixtures := _prepare_sim_fixtures()
	_install_opening_fixtures()
	TradeDesk._loaded = false
	TradeDesk.set_trade_observers([FixtureTradeObserver.new()])
	SimLoop.set_consumption_provider(_Consume0.new())
	BuildingEconomy.set_population_provider(_Pop0.new())
	BuildingEconomy.set_workforce_provider(_Work0.new())
	PopulationModel.set_satisfaction_input_provider(_Sat0.new())
	var errors: Array = SimLoop.boot(
		PARAMS_FIXTURE,
		fixtures["goods"],
		fixtures["ports"],
		CURVE_FIXTURE,
		fixtures["sea_nodes"],
		fixtures["sea_regions"],
		fixtures["sea_lanes"]
	)
	assert_gt(errors.size(), 0)
	assert_true(_has_code(errors, TradeDesk.ERR_SYS05_12))
	assert_false(SimLoop.is_booted())
	assert_push_error_count(errors.size())


func test_TST_SYS05_13b_boot_missing_trade_observers() -> void:
	var fixtures := _prepare_sim_fixtures()
	_install_opening_fixtures()
	TradeDesk._loaded = false
	TradeDesk.set_qualification_provider(FixtureQualificationProvider.new())
	SimLoop.set_consumption_provider(_Consume0.new())
	BuildingEconomy.set_population_provider(_Pop0.new())
	BuildingEconomy.set_workforce_provider(_Work0.new())
	PopulationModel.set_satisfaction_input_provider(_Sat0.new())
	var errors: Array = SimLoop.boot(
		PARAMS_FIXTURE,
		fixtures["goods"],
		fixtures["ports"],
		CURVE_FIXTURE,
		fixtures["sea_nodes"],
		fixtures["sea_regions"],
		fixtures["sea_lanes"]
	)
	assert_gt(errors.size(), 0)
	assert_true(_has_code(errors, TradeDesk.ERR_SYS05_14))
	assert_false(SimLoop.is_booted())
	assert_push_error_count(errors.size())


func test_TST_SYS05_14_buy_success() -> void:
	_boot_ledgers()
	var qty: int = 10
	_seed_market(qty + 50)
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var market: Dictionary = GoodsLedger.make_market(PORT)
	var wh: Dictionary = GoodsLedger.container_dict(wh_id)
	var cash_before: int = CashLedger.balance(ACTOR)
	var sink_before: int = CashLedger.balance(CashLedger.ID_SINK)
	var market_before: int = GoodsLedger.get_qty(market, StringName(GOOD))
	var quote: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, qty
	)
	var expect_b: int = int(quote[MarketPricer.KEY_TOTAL_LI])
	var seq: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, qty, 0
	)
	assert_gte(seq, 1)
	assert_eq(CashLedger.balance(ACTOR), cash_before - expect_b)
	assert_eq(CashLedger.balance(CashLedger.ID_SINK), sink_before + expect_b)
	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD)), market_before - qty)
	assert_eq(GoodsLedger.get_qty(wh, StringName(GOOD)), qty)
	assert_eq(CashLedger.sum_all_balances(), 0)


func test_TST_SYS05_15_sell_success() -> void:
	_boot_ledgers()
	var qty: int = 8
	_seed_market(100)
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var wh: Dictionary = GoodsLedger.container_dict(wh_id)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(), wh, StringName(GOOD), qty,
			GoodsLedger.REASON_GENESIS, &"TEST"
		),
		0
	)
	var cash_before: int = CashLedger.balance(ACTOR)
	var source_before: int = CashLedger.balance(CashLedger.ID_SOURCE)
	var quote: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_SELL, qty
	)
	var expect_s: int = int(quote[MarketPricer.KEY_TOTAL_LI])
	var seq: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_SELL, qty, 0
	)
	assert_gte(seq, 1)
	assert_eq(CashLedger.balance(ACTOR), cash_before + expect_s)
	assert_eq(CashLedger.balance(CashLedger.ID_SOURCE), source_before - expect_s)
	assert_eq(GoodsLedger.get_qty(wh, StringName(GOOD)), 0)
	assert_eq(CashLedger.sum_all_balances(), 0)


func test_TST_SYS05_16_can_trade_denied() -> void:
	_boot_ledgers()
	(TradeDesk._qualification as FixtureQualificationProvider).deny_trade = true
	_seed_market(50)
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var cash_before: int = CashLedger.balance(ACTOR)
	var mkt_before: int = GoodsLedger.get_qty(GoodsLedger.make_market(PORT), StringName(GOOD))
	var seq: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 5, 0
	)
	assert_eq(seq, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		QualificationProvider.ERR_SYS09_09
	)
	assert_eq(CashLedger.balance(ACTOR), cash_before)
	assert_eq(GoodsLedger.get_qty(GoodsLedger.make_market(PORT), StringName(GOOD)), mkt_before)
	assert_push_error_count(2)


func test_TST_SYS05_17_can_enter_denied() -> void:
	_boot_ledgers()
	(TradeDesk._qualification as FixtureQualificationProvider).deny_enter = true
	_seed_market(50)
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var cash_before: int = CashLedger.balance(ACTOR)
	var seq: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 5, 0
	)
	assert_eq(seq, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		QualificationProvider.ERR_SYS09_08
	)
	assert_eq(CashLedger.balance(ACTOR), cash_before)
	assert_push_error_count(2)


func test_TST_SYS05_18_container_owner_port_hold() -> void:
	_boot_ledgers()
	_seed_market(50)
	CashLedger.create_account(ACTOR_B, Account.Kind.ACTOR)
	var wh_other: StringName = _ensure_warehouse(ACTOR_B, PORT)
	var seq1: int = TradeDesk.execute_trade(
		ACTOR, wh_other, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 1, 0
	)
	assert_eq(seq1, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		TradeDesk.ERR_SYS05_10
	)
	var wh_far: StringName = _ensure_warehouse(ACTOR, PORT_OTHER)
	var seq2: int = TradeDesk.execute_trade(
		ACTOR, wh_far, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 1, 0
	)
	assert_eq(seq2, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		TradeDesk.ERR_SYS05_10
	)
	var hold: Dictionary = GoodsLedger.make_hold("SHIP-SAILING", String(ACTOR))
	GoodsLedger.ensure_hold_registered(hold, StringName(PORT))
	var hold_id: StringName = GoodsLedger.container_id(
		StringName(GoodsLedger.KIND_HOLD), "SHIP-SAILING"
	)
	var seq3: int = TradeDesk.execute_trade(
		ACTOR, hold_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 1, 0
	)
	assert_eq(seq3, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		TradeDesk.ERR_SYS05_11
	)
	assert_push_error_count(3)


func test_TST_SYS05_19_insufficient_and_stale_preview() -> void:
	_boot_ledgers()
	_seed_market(200)
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var bal: int = CashLedger.balance(ACTOR)
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(ACTOR, 0 - (bal - 1)),
				CashLedger.make_entry(CashLedger.ID_SINK, bal - 1),
			],
			&"TEST",
			&"SYS-04"
		),
		OK
	)
	var seq1: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 5, 0
	)
	assert_eq(seq1, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		TradeDesk.ERR_SYS05_01
	)
	var seq2: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 5, 1
	)
	assert_eq(seq2, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		TradeDesk.ERR_SYS05_07
	)
	assert_push_error_count(2)


func test_TST_SYS05_20_and_24_capacity_precheck_no_cash() -> void:
	## TST-SYS05-20／24 + D-39b: can_transfer fail → no CashLedger.post.
	_boot_ledgers()
	_seed_market(50)
	var tiny := TestCapFixed.new()
	tiny.cap_value = 2
	GoodsLedger._capacity_providers[GoodsLedger.KIND_WAREHOUSE] = tiny
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var market: Dictionary = GoodsLedger.make_market(PORT)
	var wh: Dictionary = GoodsLedger.container_dict(wh_id)
	var bal_actor: int = CashLedger.balance(ACTOR)
	var bal_sink: int = CashLedger.balance(CashLedger.ID_SINK)
	var mkt_qty: int = GoodsLedger.get_qty(market, StringName(GOOD))
	var wh_qty: int = GoodsLedger.get_qty(wh, StringName(GOOD))
	var seq: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 10, 0
	)
	assert_eq(seq, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		GoodsLedger.ERR_SYS03_03
	)
	assert_eq(CashLedger.balance(ACTOR), bal_actor)
	assert_eq(CashLedger.balance(CashLedger.ID_SINK), bal_sink)
	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD)), mkt_qty)
	assert_eq(GoodsLedger.get_qty(wh, StringName(GOOD)), wh_qty)
	assert_eq(CashLedger.sum_all_balances(), 0)
	assert_push_error_count(2)


func test_TST_SYS05_21_qty_and_stock_errors() -> void:
	_boot_ledgers()
	_seed_market(3)
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var seq1: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 10, 0
	)
	assert_eq(seq1, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		&"ERR-SYS04-06"
	)
	var seq2: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 0, 0
	)
	assert_eq(seq2, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		TradeDesk.ERR_SYS05_05
	)
	var seq3: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 1.5, 0
	)
	assert_eq(seq3, 0)
	assert_eq(
		StringName(TradeDesk.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		TradeDesk.ERR_SYS05_05
	)
	assert_push_error_count(4)


func test_TST_SYS05_22_same_rules_and_trade_transfer_scan() -> void:
	_boot_ledgers()
	_seed_market(80)
	CashLedger.create_account(ACTOR_B, Account.Kind.ACTOR)
	var fund: int = 500000
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - fund),
				CashLedger.make_entry(ACTOR_B, fund),
			],
			CashLedger.REASON_GENESIS_CASH,
			CashLedger.REQUESTER_GENESIS_GRANT
		),
		OK
	)
	var wh_a: StringName = _ensure_warehouse(ACTOR, PORT)
	var wh_b: StringName = _ensure_warehouse(ACTOR_B, PORT)
	var qty: int = 5
	var seq_a: int = TradeDesk.execute_trade(
		ACTOR, wh_a, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, qty, 0
	)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(), GoodsLedger.make_market(PORT),
			StringName(GOOD), qty, GoodsLedger.REASON_GENESIS, &"TEST"
		),
		0
	)
	var seq_b: int = TradeDesk.execute_trade(
		ACTOR_B, wh_b, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, qty, 0
	)
	assert_gte(seq_a, 1)
	assert_gte(seq_b, 1)
	assert_eq(
		GoodsLedger.get_qty(GoodsLedger.container_dict(wh_a), StringName(GOOD)), qty
	)
	assert_eq(
		GoodsLedger.get_qty(GoodsLedger.container_dict(wh_b), StringName(GOOD)), qty
	)
	var hits: Array = _scan_product_trade_transfers()
	assert_eq(hits.size(), 1, "unexpected TRADE transfer sites: %s" % str(hits))
	assert_true(String(hits[0]).ends_with("autoload/trade_desk.gd"))


func test_TST_SYS05_23_can_transfer_matches_transfer() -> void:
	_boot_ledgers()
	_seed_market(20)
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var market: Dictionary = GoodsLedger.make_market(PORT)
	var wh: Dictionary = GoodsLedger.container_dict(wh_id)
	var mkt_qty: int = GoodsLedger.get_qty(market, StringName(GOOD))
	var wh_qty: int = GoodsLedger.get_qty(wh, StringName(GOOD))
	assert_true(
		GoodsLedger.can_transfer(
			market, wh, StringName(GOOD), 5, GoodsLedger.REASON_TRADE, &"SYS-04"
		)
	)
	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD)), mkt_qty)
	assert_eq(GoodsLedger.get_qty(wh, StringName(GOOD)), wh_qty)
	var seq_ok: int = GoodsLedger.transfer(
		market, wh, StringName(GOOD), 5, GoodsLedger.REASON_TRADE, &"SYS-04"
	)
	assert_gte(seq_ok, 1)
	var tiny := TestCapFixed.new()
	tiny.cap_value = 0
	GoodsLedger._capacity_providers[GoodsLedger.KIND_WAREHOUSE] = tiny
	mkt_qty = GoodsLedger.get_qty(market, StringName(GOOD))
	wh_qty = GoodsLedger.get_qty(wh, StringName(GOOD))
	assert_false(
		GoodsLedger.can_transfer(
			market, wh, StringName(GOOD), 1, GoodsLedger.REASON_TRADE, &"SYS-04"
		)
	)
	var code_can: StringName = StringName(
		GoodsLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")
	)
	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD)), mkt_qty)
	assert_eq(GoodsLedger.get_qty(wh, StringName(GOOD)), wh_qty)
	var seq_fail: int = GoodsLedger.transfer(
		market, wh, StringName(GOOD), 1, GoodsLedger.REASON_TRADE, &"SYS-04"
	)
	assert_eq(seq_fail, 0)
	assert_eq(
		StringName(GoodsLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		code_can
	)
	assert_eq(code_can, GoodsLedger.ERR_SYS03_03)
	assert_push_error_count(2)


func test_D28d_observer_failure_keeps_trade() -> void:
	_boot_ledgers()
	_seed_market(40)
	var obs: FixtureTradeObserver = TradeDesk._observers[0] as FixtureTradeObserver
	obs.fail_next = true
	var wh_id: StringName = _ensure_warehouse(ACTOR, PORT)
	var cash_before: int = CashLedger.balance(ACTOR)
	var seq: int = TradeDesk.execute_trade(
		ACTOR, wh_id, StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 4, 0
	)
	assert_gte(seq, 1)
	assert_lt(CashLedger.balance(ACTOR), cash_before)
	assert_eq(obs.records.size(), 1)
	assert_gt(TradeDesk.take_day_errors().size(), 0)
	var obs2: FixtureTradeObserver = TradeDesk._observers[1] as FixtureTradeObserver
	assert_eq(obs2.records.size(), 1)
	assert_push_error_count(1)


# --- helpers ---


func _reset_trade_desk() -> void:
	TradeDesk._loaded = false
	TradeDesk._qualification = null
	TradeDesk._observers = []
	TradeDesk._pending_signals = []
	TradeDesk._day_errors = []
	TradeDesk._last_error = {}


func _boot_ledgers() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	var goods_dir := _build_goods(GOODS_ROOT)
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_ports(Params.get_int(PRM_PORT_COUNT_MIN), PORTS_ROOT)
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(TradeDesk.load_and_validate().size(), 0)
	TradeDesk._loaded = false
	TradeDesk.set_qualification_provider(FixtureQualificationProvider.new())
	TradeDesk.set_trade_observers([FixtureTradeObserver.new(), FixtureTradeObserver.new()])
	TradeDesk._loaded = true
	var cap := TestCapFixed.new()
	GoodsLedger.register_capacity_provider(StringName(GoodsLedger.KIND_WAREHOUSE), cap)
	CashLedger.create_account(ACTOR, Account.Kind.ACTOR)
	# params_all_keys has START_CASH=0; fund explicitly for trade tests.
	var start: int = 500000
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - start),
				CashLedger.make_entry(ACTOR, start),
			],
			CashLedger.REASON_GENESIS_CASH,
			CashLedger.REQUESTER_GENESIS_GRANT
		),
		OK
	)
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	if not GoodsLedger._offtake_snapshot.has(PORT):
		GoodsLedger._offtake_snapshot[PORT] = {}
	GoodsLedger._offtake_snapshot[PORT][GOOD] = {
		"window_qty": 105,
		"local_qty": 105,
		"window_days": days_pw,
		"day": 0,
	}


func _seed_market(stock: int) -> void:
	if stock <= 0:
		return
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(), GoodsLedger.make_market(PORT),
			StringName(GOOD), stock, GoodsLedger.REASON_GENESIS, &"TEST"
		),
		0
	)


func _ensure_warehouse(owner: StringName, port_id: String) -> StringName:
	var wh: Dictionary = GoodsLedger.make_warehouse(String(owner), port_id)
	var cid: StringName = GoodsLedger.container_id(
		StringName(GoodsLedger.KIND_WAREHOUSE), String(owner), port_id
	)
	if not GoodsLedger.is_container_registered(cid):
		assert_gt(
			GoodsLedger.transfer(
				GoodsLedger.make_external(), wh, StringName(GOOD), 1,
				GoodsLedger.REASON_GENESIS, &"TEST"
			),
			0
		)
		assert_gt(
			GoodsLedger.transfer(
				wh, GoodsLedger.make_external(), StringName(GOOD), 1,
				GoodsLedger.REASON_CONSUME, &"TEST"
			),
			0
		)
	return cid


func _has_code(errors: Array, code: Variant) -> bool:
	var want := String(code)
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if String(e.get("code", "")) == want:
			return true
	return false


func _scan_product_trade_transfers() -> Array:
	var hits: Array = []
	for root in ["res://autoload/", "res://core/"]:
		_scan_dir_trade(root, hits)
	return hits


func _scan_dir_trade(dir_path: String, hits: Array) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name.begins_with("."):
			name = da.get_next()
			continue
		var full: String = dir_path.path_join(name)
		if da.current_is_dir():
			_scan_dir_trade(full + "/", hits)
		elif name.ends_with(".gd"):
			var text: String = FileAccess.get_file_as_string(full)
			if "transfer(" in text and "REASON_TRADE" in text:
				var lines: PackedStringArray = text.split("\n")
				var found := false
				for i in range(lines.size()):
					if "transfer(" not in lines[i]:
						continue
					var window: String = lines[i]
					for j in range(i + 1, mini(i + 9, lines.size())):
						window += "\n" + lines[j]
					if "REASON_TRADE" in window:
						hits.append(full)
						found = true
						break
				if found:
					pass
		name = da.get_next()
	da.list_dir_end()


func _prepare_sim_fixtures() -> Dictionary:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	var goods := _build_goods(GOODS_ROOT + "sim/")
	assert_eq(GoodCatalog.load_and_validate(goods).size(), 0)
	# SeaLanes FRM-SYS14-01 requires 16 PORT nodes; use PORT_COUNT_MAX.
	var ports := _build_ports(Params.get_int(PRM_PORT_COUNT_MAX), PORTS_ROOT + "sim/")
	var nodes_dir: String = SEA_ROOT + "nodes/"
	var regions_dir: String = SEA_ROOT + "regions/"
	var lanes_dir: String = SEA_ROOT + "lanes/"
	_wipe_dir(nodes_dir)
	_wipe_dir(regions_dir)
	_wipe_dir(lanes_dir)
	var sea_batch: Dictionary = CsvImport.run_batch_wp29(
		SEA_OK_CSV, nodes_dir, regions_dir, lanes_dir
	)
	assert_true(bool(sea_batch.get("ok", false)), str(sea_batch))
	return {
		"goods": goods,
		"ports": ports,
		"sea_nodes": nodes_dir,
		"sea_regions": regions_dir,
		"sea_lanes": lanes_dir,
	}


func _install_opening_fixtures() -> void:
	var wp17: Dictionary = CsvImport.run_batch_wp17(
		OPENING_FIXTURE_CSV,
		FORMAL_ZONES_DIR,
		FORMAL_BUILDINGS_DIR,
		FORMAL_OPENING_DIR,
		FORMAL_BUILD_QUEUE_DIR
	)
	assert_true(wp17["ok"], "opening wp17: %s" % str(wp17.get("errors", [])))
	var wp18: Dictionary = CsvImport.run_batch_wp18(
		OPENING_FIXTURE_CSV, FORMAL_CITY_CENTER_DIR, FORMAL_OPENING_PUBLIC_DIR
	)
	assert_true(wp18["ok"], "opening wp18: %s" % str(wp18.get("errors", [])))
	var pop: Dictionary = CsvImport.run_batch_opening_population(
		OPENING_FIXTURE_CSV,
		FORMAL_OPENING_POP_DIR,
		OPENING_FIXTURE_CSV.path_join("ports.csv")
	)
	assert_true(pop["ok"], "opening pop: %s" % str(pop.get("errors", [])))


func _wipe_formal_opening_tres() -> void:
	for dir_path in [
		FORMAL_ZONES_DIR, FORMAL_BUILDINGS_DIR, FORMAL_OPENING_DIR,
		FORMAL_BUILD_QUEUE_DIR, FORMAL_CITY_CENTER_DIR, FORMAL_OPENING_PUBLIC_DIR,
		FORMAL_OPENING_POP_DIR,
	]:
		_wipe_tres_only(dir_path)


func _wipe_tres_only(dir: String) -> void:
	var abs_path := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_path)
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".tres"):
			d.remove(fn)
		fn = d.get_next()
	d.list_dir_end()


func _build_goods(dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if not Params.is_loaded():
		Params.load_and_validate(PARAMS_FIXTURE)
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
		ResourceSaver.save(
			_make_good(s["id"], s["name"], 1, true, s["build"], ANCHOR_LI),
			dir.path_join("%s.tres" % s["id"])
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		ResourceSaver.save(
			_make_good(gid, "填料%d" % next_n, 1, false, false, next_n),
			dir.path_join("%s.tres" % gid)
		)
		written += 1
		next_n += 1
	return dir


func _build_ports(port_count: int, dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var free_count: int = _valid_free_count(port_count)
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	if good_ids.is_empty():
		# Catalog may not be loaded yet when building ports for sim fixtures after goods dir write.
		pass
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
		if GoodCatalog.is_loaded():
			for good_variant in GoodCatalog.all_ids():
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
		ResourceSaver.save(def, dir.path_join("%s.tres" % port_id))
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
	good_id: String, name_zh: String, tier: int, is_staple: bool,
	is_build_material: bool, base_price_li: int
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


func _wipe_dir(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	da.list_dir_begin()
	var n := da.get_next()
	while n != "":
		if n == "." or n == "..":
			n = da.get_next()
			continue
		var child := path.path_join(n)
		if da.current_is_dir():
			_wipe_dir(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		n = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(abs_path)
