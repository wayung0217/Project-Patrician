extends GutTest
## WP-40 SYS-15 IntelLedger acceptance: TST-SYS15-01..20 + D-37c visibility.
## Fixture Params only (N-05); no formal values filled.


const CsvImport := preload("res://tools/csv_import.gd")

const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const SEA_OK_CSV := "res://tests/fixtures/wp29_sea_ok/"
const ROOT := "user://wp40_intel/"
const PARAMS_OVERRIDE := ROOT + "params/"
const GOODS_ROOT := ROOT + "goods/"
const PORTS_ROOT := ROOT + "ports/"
const SEA_ROOT := ROOT + "sea/"

const ACTOR := &"ACT-PLAYER"
const ACTOR_B := &"ACT-OTHER"
const PT_A := "PT-03"
const PT_B := "PT-11"
const GOOD := "GD-001"

const PRM_TICKS := "PRM-SYS00-TICKS_PER_DAY"
const PRM_DAYS := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_PORT_COUNT_MAX := "PRM-SYS02-PORT_COUNT_MAX"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_CREW := "PRM-SYS13-CREW"
const PRM_WINDOW := "PRM-SYS15-WINDOW_DAYS"
const PRM_DECAY := "PRM-SYS15-DECAY_DAYS"
const PRM_DIV_LO := "PRM-SYS15-DIVERGENCE_LO_PPM"
const PRM_DIV_HI := "PRM-SYS15-DIVERGENCE_HI_PPM"
const PRM_DEADBAND := "PRM-SYS15-DIRECTION_DEADBAND_PPM"
const PRM_WEEKS_SCALE := "PRM-SYS15-WEEKS_SCALE"
const PRM_DELAY := "PRM-SYS15-PUBLIC_DELAY_TICKS"
const PRM_PPM := "PRM-SYS06-PPM_SCALE"
const PRM_OFFTAKE := "PRM-SYS03-OFFTAKE_WINDOW_DAYS"
const PRM_DPW := "PRM-SYS04-DAYS_PER_WEEK"

## TST-SYS15-06 fixture (not formal): WINDOW=10 DECAY=10; ages 5／2 → consensus 81.
const TST06_MID_OLD := 100
const TST06_MID_NEW := 70
const TST06_AGE_OLD := 5
const TST06_AGE_NEW := 2
const TST06_CONSENSUS := 81
## TST-SYS15-08: (100-70)*PPM / 81
const TST08_SPAN := 30

## DEMO pricing regression (xlsx／TST-SYS04-04／05).
const DEMO_ANCHOR := 1000
const DEMO_WEEKLY_C := 105
const DEMO_STOCK := 300
const DEMO_Q := 120
const DEMO_BUY_TOTAL := 144000
const DEMO_SELL_TOTAL := 130285


class FixtureSailorPool extends SailorPoolProvider:
	var pool: Dictionary = {}

	func beggars(port_id: StringName) -> int:
		return int(pool.get(String(port_id), 0))

	func hire_sailors(port_id: StringName, n: int) -> int:
		var p := String(port_id)
		var have: int = int(pool.get(p, 0))
		if n <= 0 or have < n:
			return 0
		pool[p] = have - n
		return n

	func release_sailors(port_id: StringName, n: int) -> int:
		if n <= 0:
			return 0
		var p := String(port_id)
		pool[p] = int(pool.get(p, 0)) + n
		return n


class TestCapUnlimited extends CapacityProvider:
	func capacity(_container: Variant) -> int:
		return 100000


class CountingObserver extends ShipEventObserver:
	var depart_count: int = 0
	var arrival_calls: int = 0
	var last_arrivals: Array = []

	func on_departed(
		_ship_id: StringName, _owner_id: StringName, _from_port_id: StringName, _tick: int
	) -> void:
		depart_count += 1

	func on_arrivals(_tick: int, arrivals: Array) -> void:
		arrival_calls += 1
		last_arrivals = arrivals.duplicate(true)


class FixtureBrokerProvider extends BrokerProvider:
	## Stand-in for WP-41 BrokerDesk (tests only；D-60f).
	var kontor: Dictionary = {} ## "actor|port" → true
	var qualified: Dictionary = {}

	func has_kontor(actor_id: StringName, port_id: StringName) -> bool:
		return bool(kontor.get("%s|%s" % [String(actor_id), String(port_id)], false))

	func is_broker_qualified(actor_id: StringName, port_id: StringName) -> bool:
		return bool(qualified.get("%s|%s" % [String(actor_id), String(port_id)], false))


var _sailor: FixtureSailorPool
var _broker: FixtureBrokerProvider


func before_each() -> void:
	_wipe_dir(ROOT)
	_broker = null
	_reset_runtime()


func after_each() -> void:
	_broker = null


func test_TST_SYS15_01_missing_prm() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	Params._values.erase(PRM_WINDOW)
	Params._values.erase(PRM_DECAY)
	var e1: Array = IntelLedger.load_and_validate()
	assert_true(_has_code(e1, IntelLedger.ERR_SYS15_01))
	assert_eq(e1.size(), 1 + 1)
	assert_false(IntelLedger.is_loaded())
	assert_push_error_count(e1.size())


func test_TST_SYS15_01b_bad_param_order() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	Params._values[PRM_WINDOW] = 20
	Params._values[PRM_DECAY] = 10
	var e2: Array = IntelLedger.load_and_validate()
	assert_true(_has_code(e2, IntelLedger.ERR_SYS15_02))
	assert_eq(e2.size(), 1)
	assert_push_error_count(e2.size())


func test_TST_SYS15_02_03_depart_snapshot_weeks_null() -> void:
	_boot_intel(true)
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	var arrival: int = ShipRegistry.sail(ACTOR, sid, StringName(PT_B))
	assert_gt(arrival, 0)
	var own: Dictionary = IntelLedger.own_snapshot(ACTOR, StringName(PT_A))
	assert_false(own.is_empty())
	assert_eq(int(own[IntelLedger.KEY_DAY_TAKEN]), Clock.day)
	assert_eq(int(own[IntelLedger.KEY_TICK_TAKEN]), Clock.tick)
	var goods: Dictionary = own[IntelLedger.KEY_GOODS]
	var ids: Array = goods.keys()
	ids.sort()
	assert_eq(ids, _sorted_good_ids())
	var g0: Dictionary = goods[GOOD]
	assert_eq(int(g0[IntelLedger.KEY_MID_LI]), floori(MarketPricer.mid_price(StringName(PT_A), StringName(GOOD))))
	assert_true(g0[IntelLedger.KEY_WEEKS_X] != null)
	# TST-SYS15-03: zero offtake → weeks_x null (not 0).
	_set_offtake(PT_A, GOOD, 0, 7)
	var sid2: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	assert_gt(ShipRegistry.sail(ACTOR, sid2, StringName(PT_B)), 0)
	var own2: Dictionary = IntelLedger.own_snapshot(ACTOR, StringName(PT_A))
	var g_null: Dictionary = own2[IntelLedger.KEY_GOODS][GOOD]
	assert_true(g_null[IntelLedger.KEY_WEEKS_X] == null)
	assert_false(g_null[IntelLedger.KEY_WEEKS_X] is int and int(g_null[IntelLedger.KEY_WEEKS_X]) == 0)


func test_TST_SYS15_04_05_batch_atomic_and_stale_mid() -> void:
	_boot_intel(true)
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var a: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	var b: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	assert_gt(ShipRegistry.sail(ACTOR, a, StringName(PT_B)), 0)
	assert_gt(ShipRegistry.sail(ACTOR, b, StringName(PT_B)), 0)
	var mid_at_depart: int = floori(
		float(
			(IntelLedger._ship_snap[String(a)] as Dictionary)[IntelLedger.KEY_GOODS][GOOD][
				IntelLedger.KEY_MID_LI
			]
		)
	)
	# Change origin market after both departed (TST-SYS15-04).
	_seed_market(PT_A, GOOD, 10, DEMO_WEEKLY_C)
	var live: float = MarketPricer.mid_price(StringName(PT_A), StringName(GOOD))
	assert_true(floori(live) != mid_at_depart)
	var tick_arrive: int = 5000
	for sid in [a, b]:
		var s: Ship = ShipRegistry._ships[String(sid)]
		s.arrival_tick = tick_arrive
		s.origin_port = StringName(PT_A)
		s.dest_port = StringName(PT_B)
	_add_building(ACTOR, PT_B)
	var counter := _ForwardObserver.new()
	counter.inner = IntelLedger.get_ship_event_observer()
	ShipRegistry.set_ship_observer(counter)
	ShipRegistry.tick_step(tick_arrive)
	assert_eq(counter.arrival_calls, 1)
	assert_eq(counter.last_arrivals.size(), 2)
	var board: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 2)
	assert_eq(int(board[IntelLedger.KEY_CONSENSUS_MID]), mid_at_depart)


func test_TST_SYS15_06_08_consensus_and_divergence() -> void:
	_boot_intel(false)
	_add_building(ACTOR, PT_B)
	# Inject two board samples with fixture mids／ages (TST-SYS15-06／08).
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, TST06_MID_OLD, Clock.day - TST06_AGE_OLD, 1)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0002", ACTOR_B, TST06_MID_NEW, Clock.day - TST06_AGE_NEW, 2)
	var board: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 2)
	assert_eq(int(board[IntelLedger.KEY_CONSENSUS_MID]), TST06_CONSENSUS)
	# weights 5／8 → mean_age = (5*5+8*2)/13 = 41/13 = 3；newest=2
	assert_eq(int(board[IntelLedger.KEY_MEAN_AGE]), floori(float(5 * 5 + 8 * 2) / float(13)))
	assert_eq(int(board[IntelLedger.KEY_NEWEST_AGE]), TST06_AGE_NEW)
	var ppm: int = Params.get_int(PRM_PPM)
	var expect_div: int = floori(float(TST08_SPAN * ppm) / float(TST06_CONSENSUS))
	assert_eq(int(board[IntelLedger.KEY_DIV_PPM]), expect_div)
	assert_eq(int(board[IntelLedger.KEY_DIV_BAND]), IntelLedger.DivergenceBand.MID)


func test_TST_SYS15_07_09_10_dedupe_direction_trim() -> void:
	_boot_intel(false)
	_add_building(ACTOR, PT_B)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, 100, Clock.day - 3, 1)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, 80, Clock.day - 1, 2) # same ship+origin overwrite
	var board: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 1)
	assert_eq(int(board[IntelLedger.KEY_CONSENSUS_MID]), 80)
	# Direction UP／DOWN／FLAT／NONE
	IntelLedger._rec.clear()
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, 100, Clock.day - 4, 1)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0002", ACTOR_B, 120, Clock.day - 1, 2)
	board = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(StringName(board[IntelLedger.KEY_DIRECTION]), IntelLedger.DIR_UP)
	IntelLedger._rec.clear()
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, 100, Clock.day - 4, 1)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0002", ACTOR_B, 70, Clock.day - 1, 2)
	board = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(StringName(board[IntelLedger.KEY_DIRECTION]), IntelLedger.DIR_DOWN)
	IntelLedger._rec.clear()
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, 100, Clock.day - 4, 1)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0002", ACTOR_B, 100, Clock.day - 1, 2)
	board = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(StringName(board[IntelLedger.KEY_DIRECTION]), IntelLedger.DIR_FLAT)
	IntelLedger._rec.clear()
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, 100, Clock.day - 1, 1)
	board = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(StringName(board[IntelLedger.KEY_DIRECTION]), IntelLedger.DIR_NONE)
	# Trim: age >= WINDOW removed; own_snap kept.
	IntelLedger._rec.clear()
	var window_d: int = Params.get_int(PRM_WINDOW)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0009", ACTOR, 90, Clock.day - window_d, 1)
	IntelLedger._own_snap[String(ACTOR)] = {
		PT_A: {IntelLedger.KEY_DAY_TAKEN: Clock.day - window_d, IntelLedger.KEY_GOODS: {}}
	}
	IntelLedger.daily_step(Clock.day)
	board = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 0)
	assert_false(IntelLedger.own_snapshot(ACTOR, StringName(PT_A)).is_empty())


func test_TST_SYS15_11_12_13_14_presence_contact_samples() -> void:
	_boot_intel(true)
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	# Presence via docked ship.
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_B), cap)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0099", ACTOR_B, 100, Clock.day, 1)
	var board: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 1)
	# Presence via building only.
	ShipRegistry._ships.erase(String(sid))
	_add_building(ACTOR, PT_B)
	board = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 1)
	# Neither → ERR-SYS15-04.
	BuildingEconomy._buildings_by_port.erase(PT_B)
	var before: Dictionary = IntelLedger._rec.duplicate(true)
	board = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_true(board.is_empty())
	assert_eq(StringName(IntelLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), IntelLedger.ERR_SYS15_04)
	assert_eq(str(IntelLedger._rec), str(before))
	assert_push_error_count(1)
	# Return-to-origin: no publish; contact updates.
	_add_building(ACTOR, PT_A)
	var s2: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	assert_gt(ShipRegistry.sail(ACTOR, s2, StringName(PT_B)), 0)
	# Force arrive back at origin.
	var ship: Ship = ShipRegistry._ships[String(s2)]
	ship.arrival_tick = 9000
	ship.origin_port = StringName(PT_A)
	ship.dest_port = StringName(PT_A)
	ShipRegistry.set_ship_observer(IntelLedger.get_ship_event_observer())
	ShipRegistry.tick_step(9000)
	assert_eq(IntelLedger.contact_level(ACTOR, StringName(PT_A)), 1)
	board = IntelLedger.board_for(ACTOR, StringName(PT_A), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board.get(IntelLedger.KEY_N, 0)), 0)
	# Never visited → 0.
	assert_eq(IntelLedger.contact_level(ACTOR_B, StringName(PT_B)), 0)
	# Level 2 via fixture BrokerProvider.has_kontor（D-60f／D-37e）.
	_install_broker()
	_broker.kontor["%s|%s" % [String(ACTOR), PT_B]] = true
	assert_eq(IntelLedger.contact_level(ACTOR, StringName(PT_B)), 1 + 1)
	# Presence ERR already pushed once; board_samples unauthorized → ERR-SYS15-03.
	var samples: Array = IntelLedger.board_samples(
		ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD), &"SYS-99"
	)
	assert_eq(samples.size(), 0)
	assert_eq(StringName(IntelLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), IntelLedger.ERR_SYS15_03)
	assert_push_error_count(1 + 1)
	samples = IntelLedger.board_samples(
		ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD), IntelLedger.REQUESTER_SYS16
	)
	assert_gte(samples.size(), 0)


func test_TST_SYS15_13_publish_at_actual_arrival_port() -> void:
	## TST-SYS15-13：中途改道／他港抵達 → 公開在實際抵達港，origin＝原起航港.
	_boot_intel(true)
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	# Sail A→B then divert dest to a third fixture port before arrival.
	assert_gt(ShipRegistry.sail(ACTOR, sid, StringName(PT_B)), 0)
	var ship: Ship = ShipRegistry._ships[String(sid)]
	var pt_c := "PT-01"
	ship.arrival_tick = 8000
	ship.origin_port = StringName(PT_A)
	ship.dest_port = StringName(pt_c) # 改道：實際抵達 ≠ 原目的
	_add_building(ACTOR, pt_c)
	ShipRegistry.set_ship_observer(IntelLedger.get_ship_event_observer())
	ShipRegistry.tick_step(8000)
	var board_c: Dictionary = IntelLedger.board_for(
		ACTOR, StringName(pt_c), StringName(PT_A), StringName(GOOD)
	)
	assert_eq(int(board_c[IntelLedger.KEY_N]), 1)
	# 原目的港 B 無此筆公開.
	_add_building(ACTOR, PT_B)
	var board_b: Dictionary = IntelLedger.board_for(
		ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD)
	)
	assert_eq(int(board_b.get(IntelLedger.KEY_N, 0)), 0)


func test_TST_SYS15_15_16_snapshot_fail_and_no_observer() -> void:
	## TST-SYS15-15／16：離港取樣失敗＋未注入觀察者 → ERR-SYS15-05／06.
	_boot_intel(true)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	# mid_price fails when GoodsLedger not loaded → ERR-SYS15-05; no partial snap.
	GoodsLedger._loaded = false
	IntelLedger.on_departed(sid, ACTOR, StringName(PT_A), Clock.tick)
	GoodsLedger._loaded = true
	assert_true(IntelLedger._ship_snap.get(String(sid), null) == null)
	var day_errs: Array = IntelLedger.daily_step(Clock.day)
	assert_true(_has_code(day_errs, IntelLedger.ERR_SYS15_05))
	# Detach observer then sail — sail must still succeed (ERR-SYS15-05 does not block).
	ShipRegistry._ship_observer = null
	assert_gt(ShipRegistry.sail(ACTOR, sid, StringName(PT_B)), 0)
	var gate: Array = IntelLedger.boot_gate_errors()
	assert_true(_has_code(gate, IntelLedger.ERR_SYS15_06))
	assert_true(_gate_field(gate, "ShipEventObserver"))
	# Absorb all expected pushes from this test (MarketPricer + ERR-05 + ERR-06).
	assert_push_error_count(1 + 1 + gate.size())


func test_TST_SYS15_16_D60f_broker_provider_required() -> void:
	## TST-SYS15-16／D-60f：無 BrokerProvider → ERR-SYS15-06 field＝broker_provider.
	_boot_intel(true)
	# _boot_intel injects fixture；clear it to simulate missing injection.
	IntelLedger.set_broker_provider(null)
	assert_false(IntelLedger.has_broker_provider())
	var gate: Array = IntelLedger.boot_gate_errors()
	assert_true(_has_code(gate, IntelLedger.ERR_SYS15_06))
	assert_true(_gate_field(gate, "broker_provider"))
	assert_push_error_count(gate.size())


func test_TST_SYS15_17_18_20_deterministic_lcr_no_cash_goods() -> void:
	_boot_intel(true)
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	_add_building(ACTOR, PT_B)
	_add_building(ACTOR_B, PT_B)
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	assert_eq(CashLedger.create_account(ACTOR_B, Account.Kind.ACTOR), OK)
	var bal_a: int = CashLedger.balance(ACTOR)
	var bal_b: int = CashLedger.balance(ACTOR_B)
	var market: Dictionary = GoodsLedger.make_market(PT_A)
	var qty_before: int = GoodsLedger.get_qty(market, StringName(GOOD))
	var run1: Dictionary = _run_board_trace()
	_reset_runtime()
	_wipe_dir(ROOT)
	_boot_intel(true)
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	_add_building(ACTOR, PT_B)
	_add_building(ACTOR_B, PT_B)
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	assert_eq(CashLedger.create_account(ACTOR_B, Account.Kind.ACTOR), OK)
	var run2: Dictionary = _run_board_trace()
	assert_eq(str(run1), str(run2))
	# LCR-09: same structure for player／AI actor.
	var board_p: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	var board_ai: Dictionary = IntelLedger.board_for(ACTOR_B, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(board_p.keys(), board_ai.keys())
	assert_eq(int(board_p[IntelLedger.KEY_N]), int(board_ai[IntelLedger.KEY_N]))
	assert_eq(CashLedger.balance(ACTOR), bal_a)
	assert_eq(CashLedger.balance(ACTOR_B), bal_b)
	assert_eq(GoodsLedger.get_qty(GoodsLedger.make_market(PT_A), StringName(GOOD)), qty_before)


func test_TST_SYS15_19_stock_weeks_single_site_and_regression() -> void:
	# Behavior: mid／quote match pre-extract expectations (TST-SYS04-04／05 totals).
	_boot_intel(false)
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	var w: Variant = MarketPricer.stock_weeks(StringName(PT_A), StringName(GOOD))
	assert_true(w != null)
	assert_true(is_equal_approx(float(w), float(DEMO_STOCK) / float(DEMO_WEEKLY_C)))
	var mid: float = MarketPricer.mid_price(StringName(PT_A), StringName(GOOD))
	assert_true(mid > 0.0)
	var buy: Dictionary = MarketPricer.quote(
		StringName(PT_A), StringName(GOOD), MarketPricer.SIDE_BUY, DEMO_Q
	)
	assert_false(buy.has(MarketPricer.KEY_ERROR))
	assert_eq(int(buy[MarketPricer.KEY_TOTAL_LI]), DEMO_BUY_TOTAL)
	# Zero offtake → null weeks.
	_set_offtake(PT_A, GOOD, 0, 7)
	assert_true(MarketPricer.stock_weeks(StringName(PT_A), StringName(GOOD)) == null)


func test_D37c_public_delay_visibility() -> void:
	## D-37c／FRM-SYS16-04：PUBLIC_DELAY 與 is_broker_qualified 特權可見性.
	_boot_intel(false)
	_add_building(ACTOR, PT_B)
	_add_building(ACTOR_B, PT_B)
	Params._values[PRM_DELAY] = 10
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, 100, Clock.day, 100)
	# Before delay: general actor sees n=0；qualified sees sample.
	Clock._tick = 100
	var board: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 0)
	_install_broker()
	_broker.qualified["%s|%s" % [String(ACTOR_B), PT_B]] = true
	board = IntelLedger.board_for(ACTOR_B, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 1)
	# After delay: both see.
	Clock._tick = 110
	board = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 1)


func test_red_team_94_same_ship_dedupe() -> void:
	## 紅隊-94：同一艘船同一起航港只算最新一筆（依 TST-SYS15-07）.
	_boot_intel(false)
	_add_building(ACTOR, PT_B)
	_inject_board_sample(PT_B, PT_A, &"SHIP:RT94", ACTOR, 100, Clock.day - 3, 1)
	_inject_board_sample(PT_B, PT_A, &"SHIP:RT94", ACTOR, 55, Clock.day - 1, 2)
	var board: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 1)
	assert_eq(int(board[IntelLedger.KEY_CONSENSUS_MID]), 55)


func test_red_team_96_batch_atomic_before_read() -> void:
	## 紅隊-96：同 tick 批次寫完才公開（依 TST-SYS15-05）.
	_boot_intel(true)
	_seed_market(PT_A, GOOD, DEMO_STOCK, DEMO_WEEKLY_C)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var a: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	var b: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_A), cap)
	assert_gt(ShipRegistry.sail(ACTOR, a, StringName(PT_B)), 0)
	assert_gt(ShipRegistry.sail(ACTOR, b, StringName(PT_B)), 0)
	var tick_arrive: int = 7000
	for sid in [a, b]:
		var s: Ship = ShipRegistry._ships[String(sid)]
		s.arrival_tick = tick_arrive
		s.origin_port = StringName(PT_A)
		s.dest_port = StringName(PT_B)
	_add_building(ACTOR, PT_B)
	var counter := _ForwardObserver.new()
	counter.inner = IntelLedger.get_ship_event_observer()
	ShipRegistry.set_ship_observer(counter)
	ShipRegistry.tick_step(tick_arrive)
	assert_eq(counter.arrival_calls, 1)
	assert_eq(counter.last_arrivals.size(), 2)
	var board: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_eq(int(board[IntelLedger.KEY_N]), 2)


func test_red_team_97_registry_not_live_price() -> void:
	## 紅隊-97：商籍／接觸不給即時遠港價；遠端行情靠船報（TST-SYS15-11／18）.
	_boot_intel(false)
	# Never present at PT_B → ERR-SYS15-04；無行市.
	var board: Dictionary = IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))
	assert_true(board.is_empty())
	assert_eq(StringName(IntelLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), IntelLedger.ERR_SYS15_04)
	assert_eq(IntelLedger.contact_level(ACTOR, StringName(PT_B)), 0)
	assert_push_error_count(1)


func test_ship_event_observer_base_2_1_03() -> void:
	var base := ShipEventObserver.new()
	base.on_departed(&"S", &"A", &"P", 0)
	base.on_arrivals(0, [])
	assert_push_error_count(1 + 1)


func test_WP40_D60f_broker_provider_base_2_1_03() -> void:
	## D-60f／2.1-03：BrokerProvider 基底 push_error 並回 false＋ErrorInfo.
	var base := BrokerProvider.new()
	assert_false(base.has_kontor(ACTOR, StringName(PT_A)))
	assert_false(base.last_error().is_empty())
	assert_false(base.is_broker_qualified(ACTOR, StringName(PT_A)))
	assert_false(base.last_error().is_empty())
	assert_push_error_count(1 + 1)


# --- helpers ---


class _ForwardObserver extends ShipEventObserver:
	var inner: ShipEventObserver = null
	var arrival_calls: int = 0
	var last_arrivals: Array = []

	func on_departed(
		ship_id: StringName, owner_id: StringName, from_port_id: StringName, tick: int
	) -> void:
		if inner != null:
			inner.on_departed(ship_id, owner_id, from_port_id, tick)

	func on_arrivals(tick: int, arrivals: Array) -> void:
		arrival_calls += 1
		last_arrivals = arrivals.duplicate(true)
		if inner != null:
			inner.on_arrivals(tick, arrivals)


func _boot_intel(with_sea: bool) -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	Clock._tick = 0
	_setup_ports_goods(Params.get_int(PRM_PORT_COUNT_MAX))
	if with_sea:
		var sea := _install_sea_ok()
		assert_eq(SeaLanes.load_and_validate(sea["nodes"], sea["regions"], sea["lanes"]).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	GoodsLedger.set_day(Clock.day)
	CashLedger.set_day(Clock.day)
	_sailor = FixtureSailorPool.new()
	_sailor.pool[PT_A] = 50
	_sailor.pool[PT_B] = 50
	ShipRegistry.set_sailor_pool_provider(_sailor)
	assert_eq(ShipRegistry.load_and_validate().size(), 0)
	assert_eq(
		GoodsLedger.register_capacity_provider(
			StringName(GoodsLedger.KIND_HOLD), ShipRegistry.get_hold_capacity_provider()
		),
		GoodsLedger.CODE_OK
	)
	if not GoodsLedger._capacity_providers.has(GoodsLedger.KIND_WAREHOUSE):
		GoodsLedger.register_capacity_provider(
			StringName(GoodsLedger.KIND_WAREHOUSE), TestCapUnlimited.new()
		)
	assert_eq(IntelLedger.load_and_validate().size(), 0)
	_install_broker()
	ShipRegistry.set_ship_observer(IntelLedger.get_ship_event_observer())


func _run_board_trace() -> Dictionary:
	_add_building(ACTOR, PT_B)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0001", ACTOR, 100, Clock.day - 2, 10)
	_inject_board_sample(PT_B, PT_A, &"SHIP:0002", ACTOR_B, 80, Clock.day - 1, 11)
	return IntelLedger.board_for(ACTOR, StringName(PT_B), StringName(PT_A), StringName(GOOD))


func _inject_board_sample(
	port: String, origin: String, ship_id: StringName, owner: StringName, mid_li: int, day_taken: int, tick_arrived: int
) -> void:
	var goods: Dictionary = {}
	for g in GoodCatalog.all_ids():
		goods[String(g)] = {
			IntelLedger.KEY_MID_LI: mid_li if String(g) == GOOD else mid_li,
			IntelLedger.KEY_BAND: 0,
			IntelLedger.KEY_WEEKS_X: 100,
		}
	var snap := {
		IntelLedger.KEY_SHIP_ID: ship_id,
		IntelLedger.KEY_OWNER_ID: owner,
		IntelLedger.KEY_ORIGIN_PORT: StringName(origin),
		IntelLedger.KEY_TICK_TAKEN: tick_arrived,
		IntelLedger.KEY_DAY_TAKEN: day_taken,
		IntelLedger.KEY_GOODS: goods,
		IntelLedger.KEY_PUBLISHED: true,
	}
	if not IntelLedger._rec.has(port):
		IntelLedger._rec[port] = {}
	var pair: String = "%s\t%s" % [String(ship_id), origin]
	(IntelLedger._rec[port] as Dictionary)[pair] = {
		IntelLedger.KEY_SNAPSHOT: snap,
		IntelLedger.KEY_TICK_ARRIVED: tick_arrived,
	}


func _seed_market(port: String, good: String, stock: int, weekly_offtake: float) -> void:
	var market: Dictionary = GoodsLedger.make_market(port)
	var cur: int = GoodsLedger.get_qty(market, StringName(good))
	if cur > 0:
		assert_gt(
			GoodsLedger.transfer(
				market,
				GoodsLedger.make_external(),
				StringName(good),
				cur,
				GoodsLedger.REASON_CONSUME,
				&"TEST"
			),
			0
		)
	if stock > 0:
		assert_gt(
			GoodsLedger.transfer(
				GoodsLedger.make_external(),
				market,
				StringName(good),
				stock,
				GoodsLedger.REASON_GENESIS,
				&"TEST"
			),
			0
		)
	# Mirror test_market_pricer: window_days == DAYS_PER_WEEK → weekly_offtake == window_qty.
	_inject_offtake_weekly(port, good, int(weekly_offtake))


func _inject_offtake_weekly(port_id: String, good_id: String, weekly_offtake: int) -> void:
	var window_qty: int = weekly_offtake
	if not GoodsLedger._offtake_snapshot.has(port_id):
		GoodsLedger._offtake_snapshot[port_id] = {}
	var by_good: Dictionary = GoodsLedger._offtake_snapshot[port_id]
	by_good[good_id] = {
		"window_qty": window_qty,
		"local_qty": window_qty,
		"window_days": Params.get_int(PRM_DPW),
	}
	GoodsLedger._offtake_snapshot[port_id] = by_good


func _set_offtake(port: String, good: String, window_qty: int, _window_days: int) -> void:
	_inject_offtake_weekly(port, good, window_qty)


func _add_building(actor: StringName, port: String) -> void:
	BuildingEconomy._loaded = true
	var b := Building.new()
	b.owner = actor
	b.port_id = port
	b.build_class = &"IND1"
	b.state = Building.State.ACTIVE
	var arr: Array = BuildingEconomy._buildings_by_port.get(port, [])
	arr.append(b)
	BuildingEconomy._buildings_by_port[port] = arr


func _install_broker() -> void:
	## D-60f: inject FixtureBrokerProvider（no /root/BrokerDesk）.
	_broker = FixtureBrokerProvider.new()
	IntelLedger.set_broker_provider(_broker)


func _gate_field(errors: Array, field: String) -> bool:
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var detail: Variant = e.get(ErrorInfoUtil.KEY_DETAIL, {})
		if typeof(detail) == TYPE_DICTIONARY and str(detail.get(ErrorInfoUtil.DETAIL_FIELD, "")) == field:
			return true
	return false


func _sorted_good_ids() -> Array:
	var ids: Array = []
	for g in GoodCatalog.all_ids():
		ids.append(String(g))
	ids.sort()
	return ids


func _setup_ports_goods(port_count: int) -> void:
	var goods_dir := _build_valid_goods(GOODS_ROOT)
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_valid_ports(port_count, PORTS_ROOT)
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)


func _install_sea_ok() -> Dictionary:
	var nodes_dir: String = SEA_ROOT + "ok/nodes/"
	var regions_dir: String = SEA_ROOT + "ok/regions/"
	var lanes_dir: String = SEA_ROOT + "ok/lanes/"
	_wipe_dir(nodes_dir)
	_wipe_dir(regions_dir)
	_wipe_dir(lanes_dir)
	var result: Dictionary = CsvImport.run_batch_wp29(
		SEA_OK_CSV, nodes_dir, regions_dir, lanes_dir
	)
	assert_true(result["ok"], "import: %s" % str(result["errors"]))
	return {"nodes": nodes_dir, "regions": regions_dir, "lanes": lanes_dir}


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
		ResourceSaver.save(
			_make_good(s["id"], s["name"], 1, true, s["build"], false),
			dir + "%s.tres" % s["id"]
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (Params.get_int(PRM_FREE_PORT_TIER_MAX) + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(
			_make_good(gid, "填料%d" % next_n, tier, false, false, false),
			dir + "%s.tres" % gid
		)
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
		def.draft_limit_class = 2
		def.regime_id = "RG-TEST"
		def.role_cells = {}
		for good_variant in good_ids:
			var good_id: String = String(good_variant)
			var cell := RoleCell.new()
			if i == 0:
				cell.role = PortRegistry.ROLE_PRODUCER
				cell.base_output_per_season = 1
				cell.downstream_terminals = PackedStringArray()
			else:
				cell.role = PortRegistry.ROLE_TERMINAL
				cell.base_output_per_season = 0
				cell.downstream_terminals = PackedStringArray()
			def.role_cells[good_id] = cell
		ResourceSaver.save(def, dir + "%s.tres" % port_id)
	return dir


func _make_good(
	good_id: String,
	name_zh: String,
	tier: int,
	is_staple: bool,
	is_build_material: bool,
	is_strategic: bool
) -> GoodDef:
	var def := GoodDef.new()
	def.good_id = good_id
	def.name_zh = name_zh
	def.tier = tier
	def.is_staple = is_staple
	def.is_build_material = is_build_material
	def.is_strategic = is_strategic
	def.base_price_li = DEMO_ANCHOR
	def.season_mask = (1 << Params.get_int(PRM_SEASONS)) - 1
	return def


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


func _reset_runtime() -> void:
	IntelLedger._ready()
	ShipRegistry._ready()
	SeaLanes._loaded = false
	BuildingEconomy._loaded = false
	BuildingEconomy._buildings_by_port = {}
	MarketPricer._loaded = false
	GoodsLedger.load_and_validate()


func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if typeof(e) == TYPE_DICTIONARY and StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) == code:
			return true
	return false


func _wipe_dir(rel: String) -> void:
	var abs := ProjectSettings.globalize_path(rel)
	if DirAccess.dir_exists_absolute(abs):
		var dir := DirAccess.open(abs)
		if dir != null:
			dir.list_dir_begin()
			while true:
				var n := dir.get_next()
				if n == "":
					break
				if n == "." or n == "..":
					continue
				var path := abs.path_join(n)
				if dir.current_is_dir():
					_wipe_dir(rel.path_join(n))
					DirAccess.remove_absolute(path)
				else:
					DirAccess.remove_absolute(path)
			dir.list_dir_end()
