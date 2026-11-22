extends GutTest
## WP-30 / TechSpec 13-08：SYS-13／14 ship＋voyage acceptance (fixture Params only).


const CsvImport := preload("res://tools/csv_import.gd")

const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const SEA_OK_CSV := "res://tests/fixtures/wp29_sea_ok/"
const ROOT := "user://wp30_ship/"
const PARAMS_OVERRIDE := ROOT + "params/"
const GOODS_ROOT := ROOT + "goods/"
const PORTS_ROOT := ROOT + "ports/"
const SEA_ROOT := ROOT + "sea/"

const ACTOR := &"ACT-PLAYER"
const PT_FUZHOU := "PT-03"
const PT_NAHA := "PT-11"
const PT_WANG := "PT-10"
const PT_SONG := "PT-05"
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
const PRM_TPW := "PRM-SYS13-TICKS_PER_WAYPOINT"
const PRM_WAGE := "PRM-SYS13-CREW_WAGE_WK"
const PRM_PRICE := "PRM-SYS13-PRICE_CASH"
const PRM_REPAIR := "PRM-SYS13-REPAIR_RATE_SEASON"
const PRM_CAPACITY := "PRM-SYS13-CAPACITY"


class FixtureSailorPool extends SailorPoolProvider:
	var pool: Dictionary = {} ## port → beggars

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


var _sailor: FixtureSailorPool
var _arrived: Array = []
var _departed: Array = []
var _crew_signals: Array = []


func before_each() -> void:
	_wipe_dir(ROOT)
	_arrived = []
	_departed = []
	_crew_signals = []
	_reset_autoloads()


func after_each() -> void:
	if ShipRegistry.ship_arrived.is_connected(_on_arrived):
		ShipRegistry.ship_arrived.disconnect(_on_arrived)
	if ShipRegistry.ship_departed.is_connected(_on_departed):
		ShipRegistry.ship_departed.disconnect(_on_departed)
	if ShipRegistry.crew_changed.is_connected(_on_crew_changed):
		ShipRegistry.crew_changed.disconnect(_on_crew_changed)


func test_WP30_13_08_missing_sailor_pool_boot_error() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	var errors: Array = ShipRegistry.load_and_validate()
	assert_gt(errors.size(), 0)
	assert_true(_has_code(errors, ShipRegistry.ERR_SYS13_POOL_MISSING))
	assert_false(ShipRegistry.is_loaded())
	assert_push_error_count(errors.size())


func test_TST_SYS13_15_missing_prm_err12() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	_sailor = FixtureSailorPool.new()
	ShipRegistry.set_sailor_pool_provider(_sailor)
	# Clear 無值 keys from Params._values to mimic missing §10.7 keys (D-19f a / TST-SYS13-15).
	for key in ShipRegistry.NOVALUE_PRMS:
		Params._values.erase(key)
	var errors: Array = ShipRegistry.load_and_validate()
	assert_eq(errors.size(), ShipRegistry.NOVALUE_PRMS.size())
	var listed: Dictionary = {}
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) != ShipRegistry.ERR_SYS13_12:
			continue
		var detail: Dictionary = e.get(ErrorInfoUtil.KEY_DETAIL, {})
		listed[String(detail.get(ErrorInfoUtil.DETAIL_FIELD, ""))] = true
	for key in ShipRegistry.NOVALUE_PRMS:
		assert_true(listed.has(key), "ERR-SYS13-12 must list %s" % key)
	assert_push_error_count(errors.size())


func test_TST_SYS13_01_opening_sh01_wanggang() -> void:
	_boot_ship_registry()
	var before_beg: int = _sailor.beggars(StringName(PT_WANG))
	assert_eq(ShipRegistry.apply_opening_init().size(), 0)
	var ids: Array = ShipRegistry.ship_ids(ACTOR)
	assert_eq(ids.size(), 1)
	var info: Dictionary = ShipRegistry.ship_info(ids[0])
	assert_eq(String(info["type"]), "SH-01")
	assert_eq(String(info["port_id"]), PT_WANG)
	assert_eq(String(info["state"]), "DOCKED")
	var crew_map: Dictionary = Params.get_value(StringName(PRM_CREW))
	assert_eq(int(info["crew"]), int(crew_map["SH-01"]))
	# Opening does not touch sailor pool (OQ-16q).
	assert_eq(_sailor.beggars(StringName(PT_WANG)), before_beg)


func test_TST_SYS13_06_hire_crew_insufficient_beggars() -> void:
	_boot_ship_registry()
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_WANG), 0)
	_sailor.pool[PT_WANG] = 3
	var before_crew: int = int(ShipRegistry.ship_info(sid)["crew"])
	var before_beg: int = _sailor.beggars(StringName(PT_WANG))
	assert_eq(ShipRegistry.hire_crew(ACTOR, sid, 5), 0)
	assert_eq(StringName(ShipRegistry.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), ShipRegistry.ERR_SYS13_06)
	assert_eq(int(ShipRegistry.ship_info(sid)["crew"]), before_crew)
	assert_eq(_sailor.beggars(StringName(PT_WANG)), before_beg)
	assert_push_error_count(1)


func test_TST_SYS13_07_sail_crew_short_err04() -> void:
	_boot_ship_registry()
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap - 1)
	assert_eq(ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA)), 0)
	assert_eq(StringName(ShipRegistry.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), ShipRegistry.ERR_SYS13_04)
	assert_eq(String(ShipRegistry.ship_info(sid)["state"]), "DOCKED")
	assert_push_error_count(1)


func test_TST_SYS14_05_fuzhou_naha_arrival_tick() -> void:
	_boot_ship_registry()
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	var depart: int = Clock.tick
	var arrival: int = ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA))
	assert_gt(arrival, 0)
	# Fixture TPW[SH-01]=12；福州→那霸 16 waypoints → 192.
	assert_eq(arrival, depart + 192)
	assert_eq(String(ShipRegistry.ship_info(sid)["state"]), "SAILING")


func test_TST_SYS14_07_deep_ship_shallow_port_err02() -> void:
	_boot_ship_registry()
	# PT-10 draft_limit_class=0 (淺); SH-04 draft=DEEP=2.
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-04"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-04", ACTOR, StringName(PT_FUZHOU), cap)
	var before: Dictionary = ShipRegistry.ship_info(sid)
	assert_eq(ShipRegistry.sail(ACTOR, sid, StringName(PT_WANG)), 0)
	assert_eq(StringName(ShipRegistry.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), ShipRegistry.ERR_SYS14_02)
	var after: Dictionary = ShipRegistry.ship_info(sid)
	assert_eq(String(after["state"]), String(before["state"]))
	assert_eq(String(after["port_id"]), String(before["port_id"]))
	assert_push_error_count(1)


func test_TST_SYS14_06_reroute_next_waypoint() -> void:
	_boot_ship_registry()
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	var arrival1: int = ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA))
	assert_gt(arrival1, 0)
	var tpw: int = int(Params.get_value(StringName(PRM_TPW))["SH-01"])
	# Advance into first leg but before next waypoint boundary effect time.
	Clock._tick = Clock.tick + (tpw / 2)
	var arrival2: int = ShipRegistry.reroute(ACTOR, sid, StringName(PT_WANG))
	assert_gt(arrival2, 0)
	assert_ne(arrival2, arrival1)
	var info: Dictionary = ShipRegistry.ship_info(sid)
	assert_eq(String(info["dest_port"]), PT_WANG)
	# Reroute while DOCKED → ERR-SYS14-05
	# Finish by forcing dock then retry:
	ShipRegistry.tick_step(int(info["arrival_tick"]))
	assert_eq(ShipRegistry.reroute(ACTOR, sid, StringName(PT_FUZHOU)), 0)
	assert_eq(StringName(ShipRegistry.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), ShipRegistry.ERR_SYS14_05)
	assert_push_error_count(1)


func test_TST_SYS14_08_same_tick_arrival_ship_id_order() -> void:
	## Z1: same-tick arrivals via formal sail API (identical path／depart → identical arrival_tick).
	_boot_ship_registry()
	ShipRegistry.ship_arrived.connect(_on_arrived)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var a: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	var b: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	var arrival_a: int = ShipRegistry.sail(ACTOR, a, StringName(PT_NAHA))
	var arrival_b: int = ShipRegistry.sail(ACTOR, b, StringName(PT_NAHA))
	assert_gt(arrival_a, 0)
	assert_eq(arrival_a, arrival_b, "same route＋depart tick → same arrival")
	_arrived = []
	ShipRegistry.tick_step(arrival_a)
	ShipRegistry.flush_signals() ## A24／D-05: emit only via flush
	assert_eq(_arrived.size(), 2)
	assert_true(String(_arrived[0]) < String(_arrived[1]), "ship_id ascending")
	assert_true(ShipRegistry.can_trade(a, StringName(PT_NAHA)))
	assert_true(ShipRegistry.can_trade(b, StringName(PT_NAHA)))


func test_TST_SYS14_09_deterministic_twice() -> void:
	var run1: Dictionary = _run_voyage_trace()
	if ShipRegistry.ship_arrived.is_connected(_on_arrived):
		ShipRegistry.ship_arrived.disconnect(_on_arrived)
	_reset_autoloads()
	_wipe_dir(ROOT)
	_arrived = []
	var run2: Dictionary = _run_voyage_trace()
	assert_eq(run1["path"], run2["path"])
	assert_eq(run1["arrival"], run2["arrival"])
	assert_eq(str(run1["signals"]), str(run2["signals"]))


func test_TST_SYS13_13_hold_trade_while_sailing_err03() -> void:
	_boot_ship_registry()
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	assert_gt(ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA)), 0)
	var hold: Dictionary = GoodsLedger.make_hold(String(sid), String(ACTOR))
	var market: Dictionary = GoodsLedger.make_market(PT_FUZHOU)
	# Seed market
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(), market, StringName(GOOD), 10, GoodsLedger.REASON_GENESIS, &"TEST"
		),
		0
	)
	var seq: int = GoodsLedger.transfer(
		market, hold, StringName(GOOD), 1, GoodsLedger.REASON_TRADE, &"TEST"
	)
	assert_eq(seq, 0)
	assert_eq(StringName(GoodsLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), ShipRegistry.ERR_SYS13_03)
	assert_push_error_count(1)


func test_TST_SYS13_14_songjiang_dock_draft_ladder() -> void:
	_boot_ship_registry()
	# Ensure Songjiang base draft = 淺 (0).
	var port: PortDef = PortRegistry.get_port(PT_SONG)
	assert_true(port != null)
	assert_eq(int(port.draft_limit_class), 0)
	# Force BuildingEconomy loaded flag so public_level is consulted.
	BuildingEconomy._loaded = true
	BuildingEconomy._buildings_by_port[PT_SONG] = []
	assert_eq(ShipRegistry.port_draft(StringName(PT_SONG)), ShipRegistry.DRAFT_SHALLOW)
	_set_dock_level(PT_SONG, 1)
	assert_eq(ShipRegistry.port_draft(StringName(PT_SONG)), ShipRegistry.DRAFT_SHALLOW)
	_set_dock_level(PT_SONG, 2)
	assert_eq(ShipRegistry.port_draft(StringName(PT_SONG)), ShipRegistry.DRAFT_MEDIUM)
	_set_dock_level(PT_SONG, 3)
	assert_eq(ShipRegistry.port_draft(StringName(PT_SONG)), ShipRegistry.DRAFT_DEEP)
	BuildingEconomy._loaded = false
	BuildingEconomy._buildings_by_port = {}


func test_TST_SYS13_08_season_wage_arrears() -> void:
	_boot_ship_registry()
	CashLedger.create_account(ACTOR, Account.Kind.ACTOR)
	# Low balance so arrears record.
	assert_eq(
		CashLedger.post(
			[CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - 10), CashLedger.make_entry(ACTOR, 10)],
			&"TEST_GRANT",
			&"SYS-13"
		),
		OK
	)
	var n: int = 5
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_WANG), n)
	var wage: int = Params.get_int(StringName(PRM_WAGE))
	var days: int = Params.get_int(StringName(PRM_DAYS))
	for _i in range(days):
		ShipRegistry.daily_step(Clock.day)
		Clock._tick = Clock.tick + Params.get_int(StringName(PRM_TICKS))
		GoodsLedger.set_day(Clock.day)
		CashLedger.set_day(Clock.day)
	# Isolate wage from repair: no hold-days this season end.
	var s: Ship = ShipRegistry._ships[String(sid)]
	s.held_from_day = Clock.day + 1
	var days_pw: int = Params.get_int(StringName("PRM-SYS04-DAYS_PER_WEEK"))
	var expect: int = ceili(
		AmountQuantize.quantize_amount(float(n * wage * days) / float(days_pw))
	)
	var bal_before: int = CashLedger.balance(ACTOR)
	ShipRegistry.cutoff_step(0)
	var paid: int = bal_before - CashLedger.balance(ACTOR)
	assert_eq(paid, mini(bal_before, expect))
	assert_eq(CashLedger.arrears(ACTOR), expect - paid)


func test_TST_SYS13_09_repair_prorata_mid_season() -> void:
	_boot_ship_registry()
	CashLedger.create_account(ACTOR, Account.Kind.ACTOR)
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - 1000000),
				CashLedger.make_entry(ACTOR, 1000000),
			],
			&"TEST_GRANT",
			&"SYS-13"
		),
		OK
	)
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_WANG), 1)
	var s: Ship = ShipRegistry._ships[String(sid)]
	s.held_from_day = 31
	Clock._tick = 90 * Params.get_int(StringName(PRM_TICKS))
	GoodsLedger.set_day(Clock.day)
	CashLedger.set_day(Clock.day)
	assert_eq(Clock.day, 90)
	var price: int = int(Params.get_value(StringName(PRM_PRICE))["SH-01"])
	var rate: float = float(Params.get_value(StringName(PRM_REPAIR)))
	var days_d: int = Params.get_int(StringName(PRM_DAYS))
	var expect: int = ceili(
		AmountQuantize.quantize_amount(float(price) * rate * float(60) / float(days_d))
	)
	var bal_before: int = CashLedger.balance(ACTOR)
	ShipRegistry.cutoff_step(0)
	assert_eq(bal_before - CashLedger.balance(ACTOR), expect)


func test_D20a_sail_depart_arrive_container_port() -> void:
	_boot_ship_registry()
	ShipRegistry.ship_departed.connect(_on_departed)
	ShipRegistry.ship_arrived.connect(_on_arrived)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	var hold_id: StringName = StringName("HOLD:%s" % String(sid))
	# Put pending goods then sail → container_departed counts export.
	var hold: Dictionary = GoodsLedger.make_hold(String(sid), String(ACTOR))
	var market: Dictionary = GoodsLedger.make_market(PT_FUZHOU)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(), market, StringName(GOOD), 5, GoodsLedger.REASON_GENESIS, &"TEST"
		),
		0
	)
	assert_gt(
		GoodsLedger.transfer(market, hold, StringName(GOOD), 5, GoodsLedger.REASON_TRADE, &"TEST"),
		0
	)
	var arrival: int = ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA))
	assert_gt(arrival, 0)
	assert_eq(_departed.size(), 0, "A24: ship_departed not emitted until flush")
	ShipRegistry.flush_signals()
	assert_eq(_departed.size(), 1)
	assert_eq(String(GoodsLedger.get_container_port_id(hold_id)), "")
	ShipRegistry.tick_step(arrival)
	assert_eq(_arrived.size(), 0, "A24: ship_arrived not emitted until flush")
	ShipRegistry.flush_signals()
	assert_eq(_arrived.size(), 1)
	assert_eq(String(GoodsLedger.get_container_port_id(hold_id)), PT_NAHA)
	assert_true(ShipRegistry.can_trade(sid, StringName(PT_NAHA)))


func test_WP57_A24_M22_signals_only_at_flush() -> void:
	## R9-47 M22／A24／D-05: hire／fire／depart／arrive emit only via flush_signals.
	_boot_ship_registry()
	ShipRegistry.ship_departed.connect(_on_departed)
	ShipRegistry.ship_arrived.connect(_on_arrived)
	ShipRegistry.crew_changed.connect(_on_crew_changed)
	_sailor.pool[PT_FUZHOU] = 50
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), 0)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	assert_eq(ShipRegistry.hire_crew(ACTOR, sid, cap), cap)
	assert_eq(_crew_signals.size(), 0, "hire must not emit before flush")
	ShipRegistry.flush_signals()
	assert_eq(_crew_signals.size(), 1)
	assert_eq(ShipRegistry.fire_crew(ACTOR, sid, 1), 1)
	assert_eq(_crew_signals.size(), 1, "fire must not emit before flush")
	ShipRegistry.flush_signals()
	assert_eq(_crew_signals.size(), 2)
	# Re-hire to full crew for sail.
	assert_eq(ShipRegistry.hire_crew(ACTOR, sid, 1), 1)
	ShipRegistry.flush_signals()
	_departed = []
	_arrived = []
	var arrival: int = ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA))
	assert_gt(arrival, 0)
	assert_eq(_departed.size(), 0, "depart must not emit before flush")
	ShipRegistry.flush_signals()
	assert_eq(_departed.size(), 1)
	ShipRegistry.tick_step(arrival)
	assert_eq(_arrived.size(), 0, "arrive must not emit before flush")
	ShipRegistry.flush_signals()
	assert_eq(_arrived.size(), 1)


func test_WP57_A28_skipped_tick_still_arrives() -> void:
	## A28: arrival_tick < current tick still docks the ship and reports error.
	_boot_ship_registry()
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	var arrival: int = ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA))
	assert_gt(arrival, 0)
	var late_tick: int = arrival + 5
	ShipRegistry.tick_step(late_tick)
	assert_true(ShipRegistry.can_trade(sid, StringName(PT_NAHA)))
	assert_eq(
		StringName(ShipRegistry.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		ShipRegistry.ERR_SYS13_01
	)
	assert_push_error_count(1)


func test_WP57_A29_missing_tpw_type_errors() -> void:
	## A29／C-06: TPW[type] missing → ERR-SYS13-12, sail fails (no silent default 1).
	_boot_ship_registry()
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	var tpw_map: Dictionary = Params.get_value(StringName(PRM_TPW)).duplicate(true)
	tpw_map.erase("SH-01")
	Params._values[PRM_TPW] = tpw_map
	assert_eq(ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA)), 0)
	assert_eq(
		StringName(ShipRegistry.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		ShipRegistry.ERR_SYS13_12
	)
	assert_push_error_count(1)


# --- helpers ---


func _on_arrived(ship_id: StringName, _port: StringName, _from: StringName, _tick: int) -> void:
	_arrived.append(ship_id)


func _on_departed(
	ship_id: StringName, _from: StringName, _to: StringName, _dep: int, _arr: int
) -> void:
	_departed.append(ship_id)


func _on_crew_changed(ship_id: StringName, crew: int) -> void:
	_crew_signals.append({"ship_id": ship_id, "crew": crew})


func _run_voyage_trace() -> Dictionary:
	_boot_ship_registry()
	ShipRegistry.ship_arrived.connect(_on_arrived)
	var cap: int = int(Params.get_value(StringName(PRM_CREW))["SH-01"])
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-01", ACTOR, StringName(PT_FUZHOU), cap)
	var path: Array = SeaLanes.path(PT_FUZHOU, PT_NAHA)
	var lane_ids: Array = []
	for hop in path:
		lane_ids.append(String(hop["lane_id"]))
	var arrival: int = ShipRegistry.sail(ACTOR, sid, StringName(PT_NAHA))
	_arrived = []
	ShipRegistry.tick_step(arrival)
	ShipRegistry.flush_signals() ## A24
	return {"path": lane_ids, "arrival": arrival, "signals": _arrived.duplicate()}


func _boot_ship_registry() -> void:
	_boot_world(true)
	_sailor = FixtureSailorPool.new()
	_sailor.pool[PT_WANG] = 50
	_sailor.pool[PT_FUZHOU] = 50
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


func _boot_world(with_sea: bool) -> void:
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
		if port_id == PT_SONG or port_id == PT_WANG:
			def.draft_limit_class = 0
		elif port_id == PT_NAHA:
			def.draft_limit_class = 2
		else:
			def.draft_limit_class = 1
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
	def.base_price_li = 1000
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


func _set_dock_level(port_id: String, level: int) -> void:
	var b := Building.new()
	b.port_id = port_id
	b.build_class = BuildingEconomy.CLASS_PUBLIC
	b.cb_id = ShipRegistry.CB_DOCK
	b.type = ShipRegistry.CB_DOCK
	b.level = level
	b.state = Building.State.ACTIVE
	BuildingEconomy._buildings_by_port[port_id] = [b]


func _write_params(fixture: Dictionary, filename: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARAMS_OVERRIDE))
	var path := PARAMS_OVERRIDE + filename
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(fixture))
	f.close()
	return path


func _reset_autoloads() -> void:
	ShipRegistry._ready()
	SeaLanes._loaded = false
	SeaLanes._nodes = {}
	SeaLanes._regions = {}
	SeaLanes._lanes = {}
	SeaLanes._adj = {}
	SeaLanes._last_error = {}
	GoodsLedger.load_and_validate()
	# GoodsLedger.load clears; fine
	BuildingEconomy._loaded = false


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
	DirAccess.make_dir_recursive_absolute(abs)
