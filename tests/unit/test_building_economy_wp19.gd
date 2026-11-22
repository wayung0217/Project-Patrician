extends GutTest
## WP-19 / TechSpec 12-08 BuildingEconomy construction acceptance.


const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const PORT_PT01 := "PT-01"
const ACTOR := &"ACT-PLAYER"

const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"
const ANCHOR_LI := 1000

const ROOT := "user://wp19_be/"
const TYPE_KONTOR := "CB-17"
const TYPE_RES := "RB-01"
const TYPE_IND1 := "IB-01"
const TYPE_WH := "WH-01"
const TYPE_PUB := "CB-01"


class TestPop extends PopulationProvider:
	var _pop: Dictionary = {}

	func set_pop(port_id: String, value: int) -> void:
		_pop[port_id] = value

	func population(port_id: StringName) -> int:
		var key := String(port_id)
		if not _pop.has(key):
			return 0
		return int(_pop[key])


class TestWorkforce extends WorkforceProvider:
	func workers(_ws_id: StringName) -> int:
		return 0


class TestCons extends ConsumptionProvider:

	func consume_qty(_port_id: StringName, _good_id: StringName, _day: int) -> int:
		return 0


func before_each() -> void:
	_wipe_dir(ROOT)
	BuildingEconomy._loaded = false
	BuildingEconomy._slots = {}
	BuildingEconomy._slots_by_port = {}
	BuildingEconomy._r_by_port = {}
	BuildingEconomy._max_open_zone = {}
	BuildingEconomy._buildings = {}
	BuildingEconomy._buildings_by_port = {}
	BuildingEconomy._building_defs = {}
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	BuildingEconomy._pending_started = []
	BuildingEconomy._pending_waiting = []
	BuildingEconomy._pending_completed = []
	BuildingEconomy._pending_shortfalls = []
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()


func test_TST_SYS08_03_kontor_duplicate_err04() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(200)
	_top_up(ACTOR, 5_000_000)

	var k1: StringName = _first_kontor_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, k1), 0)
	var b1: StringName = BuildingEconomy.order_build(ACTOR, k1, StringName(TYPE_KONTOR))
	assert_ne(b1, &"")
	_force_active(b1)

	var k2: StringName = _second_kontor_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, k2), 0)
	var b2: StringName = BuildingEconomy.order_build(ACTOR, k2, StringName(TYPE_KONTOR))
	assert_eq(b2, &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_04))
	assert_push_error_count(BuildingEconomy.last_errors().size())


func test_TST_SYS08_04_warehouse_then_market_mats() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	# Residence needs 40 of GD-001 for this test.
	(Params._values["PRM-SYS08-BUILD_MAT"] as Dictionary)["RESIDENCE"] = {"GD-001": 40}
	(Params._values["PRM-SYS08-BUILD_CASH_LI"] as Dictionary)["RESIDENCE"] = 1000
	(Params._values["PRM-SYS08-BUILD_DAYS"] as Dictionary)["RESIDENCE"] = 1
	_seed_market_mats(200)
	_top_up(ACTOR, 5_000_000)

	var kid: StringName = _build_active_kontor()
	assert_ne(kid, &"")

	# Stock warehouse 20 of GD-001 (capacity now > 0).
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	assert_gt(BuildingEconomy.warehouse_capacity(ACTOR, StringName(PORT_PT01)), 0)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			wh,
			&"GD-001",
			20,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)
	var mkt: Dictionary = GoodsLedger.make_market(PORT_PT01)
	var m_before: int = GoodsLedger.get_qty(mkt, &"GD-001")
	var cash_before: int = CashLedger.balance(ACTOR)

	var civil: StringName = _first_open_civil_owned()
	var bid: StringName = BuildingEconomy.order_build(ACTOR, civil, StringName(TYPE_RES))
	assert_ne(bid, &"")
	assert_eq(GoodsLedger.get_qty(wh, &"GD-001"), 0)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-001"), m_before - 20)
	assert_lt(CashLedger.balance(ACTOR), cash_before)
	assert_eq(BuildingEconomy.get_building(bid).state, Building.State.BUILDING)


func test_TST_SYS08_05_waiting_material_no_countdown() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	(Params._values["PRM-SYS08-BUILD_MAT"] as Dictionary)["KONTOR"] = {"GD-001": 50}
	(Params._values["PRM-SYS08-BUILD_DAYS"] as Dictionary)["KONTOR"] = 3
	# Market only has 10 → WAITING
	_seed_good_market("GD-001", 10)
	_top_up(ACTOR, 5_000_000)
	var k1: StringName = _first_kontor_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, k1), 0)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, k1, StringName(TYPE_KONTOR))
	assert_ne(bid, &"")
	var bld: Building = BuildingEconomy.get_building(bid)
	assert_eq(bld.state, Building.State.WAITING_MATERIAL)
	var days: int = bld.days_left
	BuildingEconomy.daily_step(1)
	BuildingEconomy.flush_signals()
	assert_eq(BuildingEconomy.get_building(bid).state, Building.State.WAITING_MATERIAL)
	assert_eq(BuildingEconomy.get_building(bid).days_left, days)
	# Top up market and advance → BUILDING then countdown
	_seed_good_market("GD-001", 100)
	BuildingEconomy.daily_step(2)
	BuildingEconomy.flush_signals()
	assert_eq(BuildingEconomy.get_building(bid).state, Building.State.BUILDING)


func test_WP19_12_08_1_err08_unknown_slot_type() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	assert_eq(BuildingEconomy.order_build(ACTOR, &"SLOT:NOPE", StringName(TYPE_KONTOR)), &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_08))
	assert_push_error_count(BuildingEconomy.last_errors().size())


func test_WP19_12_08_1_err05_not_land_owner() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	_top_up(ACTOR, 5_000_000)
	var k1: StringName = _first_kontor_slot()
	assert_eq(BuildingEconomy.order_build(ACTOR, k1, StringName(TYPE_KONTOR)), &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_05))
	assert_push_error_count(BuildingEconomy.last_errors().size())


func test_WP19_12_08_1_err02_slot_occupied() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(50)
	_top_up(ACTOR, 5_000_000)
	var kid: StringName = _build_active_kontor()
	var slot_id: StringName = BuildingEconomy.get_building(kid).slot_id
	assert_eq(BuildingEconomy.order_build(ACTOR, slot_id, StringName(TYPE_KONTOR)), &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_02))
	assert_push_error_count(BuildingEconomy.last_errors().size())


func test_WP19_12_08_1_err01_zone_closed_not_belt() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	# zone1 open, zone2 belt, zone3 closed beyond belt
	_write_zone(ROOT + "zones/", PORT_PT01, 1, 1, 2, 1)
	_write_zone(ROOT + "zones/", PORT_PT01, 2, 1, 2, 0)
	_write_zone(ROOT + "zones/", PORT_PT01, 3, 1, 2, 0)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 0)
	_write_defs()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(50)
	_top_up(ACTOR, 5_000_000)
	_build_active_kontor()
	var closed: StringName = &""
	for s in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = s
		if slot.kind == Slot.Kind.CIVIL and slot.zone == 3 and slot.building_id == &"":
			closed = slot.slot_id
			break
	assert_ne(closed, &"")
	# buy_land on non-belt closed → ERR-01
	assert_eq(BuildingEconomy.buy_land(ACTOR, closed), 0)
	assert_eq(
		StringName(BuildingEconomy.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		BuildingEconomy.ERR_SYS08_01
	)
	assert_push_error_count(1)
	# Force owner for order_build path of ERR-01
	BuildingEconomy.get_slot(closed).land_owner = ACTOR
	assert_eq(BuildingEconomy.order_build(ACTOR, closed, StringName(TYPE_RES)), &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_01))
	assert_push_error_count(1 + BuildingEconomy.last_errors().size())


func test_WP19_12_08_1_err03_wrong_placement() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(50)
	_top_up(ACTOR, 5_000_000)
	_build_active_kontor()
	var open_civil: StringName = _first_open_civil_owned()
	# IND1 only on belt → ERR-03 on open city zone
	assert_eq(BuildingEconomy.order_build(ACTOR, open_civil, StringName(TYPE_IND1)), &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_03))
	assert_push_error_count(BuildingEconomy.last_errors().size())


func test_WP19_12_08_1_err07_insufficient_build_cash() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	(Params._values["PRM-SYS08-BUILD_CASH_LI"] as Dictionary)["KONTOR"] = 50_000
	_seed_market_mats(50)
	var k1: StringName = _first_kontor_slot()
	# Enough for land, not for BUILD_CASH
	_top_up(ACTOR, 300_000)
	assert_gt(BuildingEconomy.buy_land(ACTOR, k1), 0)
	var bal: int = CashLedger.balance(ACTOR)
	if bal > 1000:
		assert_eq(
			CashLedger.post(
				[
					CashLedger.make_entry(ACTOR, 0 - (bal - 1000)),
					CashLedger.make_entry(CashLedger.ID_SINK, bal - 1000),
				],
				&"TEST_DRAIN",
				BuildingEconomy.REQUESTER_SYS08
			),
			OK
		)
	assert_eq(BuildingEconomy.order_build(ACTOR, k1, StringName(TYPE_KONTOR)), &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_07))
	assert_push_error_count(BuildingEconomy.last_errors().size())


func test_WP19_12_08_4_warehouse_full_market_buy() -> void:
	## 12-08 ④ / D-12e: warehouse full; market mats still acquired; build starts.
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	(Params._values["PRM-SYS08-BUILD_MAT"] as Dictionary)["RESIDENCE"] = {"GD-001": 5}
	(Params._values["PRM-SYS08-BUILD_CASH_LI"] as Dictionary)["RESIDENCE"] = 1000
	(Params._values["PRM-SYS08-BUILD_DAYS"] as Dictionary)["RESIDENCE"] = 1
	_seed_market_mats(200)
	_top_up(ACTOR, 5_000_000)
	_build_active_kontor()
	var cap: int = BuildingEconomy.warehouse_capacity(ACTOR, StringName(PORT_PT01))
	assert_gt(cap, 0)
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			wh,
			&"GD-002",
			cap,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0,
		"fill warehouse to capacity"
	)
	assert_eq(BuildingEconomy.warehouse_capacity_for_container(wh), cap)
	# Any further GENESIS into WH must fail capacity — proves full
	assert_eq(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			wh,
			&"GD-001",
			1,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)
	assert_push_error_count(1)
	var mkt: Dictionary = GoodsLedger.make_market(PORT_PT01)
	var m_before: int = GoodsLedger.get_qty(mkt, &"GD-001")
	var civil: StringName = _first_open_civil_owned()
	var bid: StringName = BuildingEconomy.order_build(ACTOR, civil, StringName(TYPE_RES))
	assert_ne(bid, &"", str(BuildingEconomy.last_errors()))
	assert_eq(BuildingEconomy.get_building(bid).state, Building.State.BUILDING)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-001"), m_before - 5)
	assert_eq(GoodsLedger.get_qty(wh, &"GD-001"), 0, "mats must not enter full warehouse")


func test_WP19_D15b_kontor_upgrade_missing_boot_err09() -> void:
	## D-15b ①: missing PRM-SYS08-KONTOR_UPGRADE → BuildingEconomy boot ERR-SYS08-09.
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	assert_true(Params.has_prm("PRM-SYS08-KONTOR_UPGRADE"))
	Params._values.erase("PRM-SYS08-KONTOR_UPGRADE")
	assert_false(Params.has_prm("PRM-SYS08-KONTOR_UPGRADE"))
	var errs: Array = BuildingEconomy.load_and_validate(
		ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/"
	)
	assert_gt(errs.size(), 0)
	var has09 := false
	for e in errs:
		if StringName((e as Dictionary).get(ErrorInfoUtil.KEY_CODE, &"")) == BuildingEconomy.ERR_SYS08_09:
			has09 = true
	assert_true(has09)
	assert_false(BuildingEconomy.is_loaded())
	assert_push_error_count(errs.size())


func test_WP19_12_08_2_gathering_belt_ind1_only() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(200)
	_top_up(ACTOR, 5_000_000)
	_build_active_kontor()

	var belt: StringName = _first_belt_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, belt), 0)
	# RESIDENCE on belt → ERR-03
	assert_eq(BuildingEconomy.order_build(ACTOR, belt, StringName(TYPE_RES)), &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_03))
	assert_push_error_count(BuildingEconomy.last_errors().size())
	# IND1 on belt OK
	var bid: StringName = BuildingEconomy.order_build(ACTOR, belt, StringName(TYPE_IND1))
	assert_ne(bid, &"")


func test_WP19_12_08_3_err13_no_kontor_residence() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(200)
	_top_up(ACTOR, 5_000_000)
	var civil: StringName = _first_open_civil()
	assert_gt(BuildingEconomy.buy_land(ACTOR, civil), 0)
	assert_eq(BuildingEconomy.order_build(ACTOR, civil, StringName(TYPE_RES)), &"")
	assert_true(_errors_have(BuildingEconomy.ERR_SYS08_13))
	assert_push_error_count(BuildingEconomy.last_errors().size())


func test_WP19_12_08_5_buy_mats_cash_short_waiting() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	(Params._values["PRM-SYS08-BUILD_MAT"] as Dictionary)["KONTOR"] = {"GD-001": 5}
	(Params._values["PRM-SYS08-BUILD_CASH_LI"] as Dictionary)["KONTOR"] = 100
	_seed_good_market("GD-001", 100)
	_top_up(ACTOR, 5_000_000)
	var k1: StringName = _first_kontor_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, k1), 0)
	# Leave only BUILD_CASH; market buy will starve → WAITING, no order error
	var bal: int = CashLedger.balance(ACTOR)
	if bal > 100:
		assert_eq(
			CashLedger.post(
				[
					CashLedger.make_entry(ACTOR, 0 - (bal - 100)),
					CashLedger.make_entry(CashLedger.ID_SINK, bal - 100),
				],
				&"TEST_DRAIN",
				BuildingEconomy.REQUESTER_SYS08
			),
			OK
		)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, k1, StringName(TYPE_KONTOR))
	assert_ne(bid, &"", "cash short on mats must WAITING not fail order")
	assert_eq(BuildingEconomy.get_building(bid).state, Building.State.WAITING_MATERIAL)


func test_WP19_12_08_6_signals_flush_only() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	(Params._values["PRM-SYS08-BUILD_DAYS"] as Dictionary)["KONTOR"] = 1
	(Params._values["PRM-SYS08-BUILD_MAT"] as Dictionary)["KONTOR"] = {"GD-001": 1}
	_seed_good_market("GD-001", 50)
	_top_up(ACTOR, 5_000_000)
	var completed := {"n": 0}
	var cb := func(_id: StringName) -> void:
		completed["n"] = int(completed["n"]) + 1
	BuildingEconomy.construction_completed.connect(cb)
	var bid: StringName = _build_active_kontor_without_force()
	assert_eq(BuildingEconomy.get_building(bid).state, Building.State.BUILDING)
	BuildingEconomy.daily_step(1)
	assert_eq(int(completed["n"]), 0, "must not emit before flush")
	BuildingEconomy.flush_signals()
	assert_eq(int(completed["n"]), 1)
	BuildingEconomy.construction_completed.disconnect(cb)


func test_WP19_12_08_7_public_upgrade_fee() -> void:
	## V2／FRM-SYS08-07: pop=1000 × UPGRADE_PER_CAPITA[L2].CASH_LI=10000 → 10_000_000.
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	var fee: Dictionary = BuildingEconomy.public_upgrade_fee(StringName(PORT_PT01), 2)
	assert_eq(int(fee["CASH_LI"]), 10_000_000)


func test_WP19_12_08_8_pause_resume_demolish() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(200)
	_top_up(ACTOR, 5_000_000)
	var kid: StringName = _build_active_kontor()
	assert_eq(BuildingEconomy.pause(ACTOR, kid), 1)
	assert_eq(BuildingEconomy.get_building(kid).state, Building.State.PAUSED)
	assert_eq(BuildingEconomy.resume(ACTOR, kid), 1)
	assert_eq(BuildingEconomy.get_building(kid).state, Building.State.ACTIVE)

	var civil: StringName = _first_open_civil_owned()
	(Params._values["PRM-SYS08-BUILD_MAT"] as Dictionary)["RESIDENCE"] = {"GD-001": 1}
	(Params._values["PRM-SYS08-BUILD_DAYS"] as Dictionary)["RESIDENCE"] = 1
	var rid: StringName = BuildingEconomy.order_build(ACTOR, civil, StringName(TYPE_RES))
	assert_ne(rid, &"")
	_force_active(rid)
	assert_eq(Clock.load_and_validate().size(), 0)
	while Clock.day < 7:
		Clock.advance_one_day()
	var day_now: int = Clock.day
	assert_eq(BuildingEconomy.demolish(ACTOR, rid), 1)
	var slot: Slot = BuildingEconomy.get_slot(civil)
	assert_eq(slot.building_id, &"")
	assert_eq(slot.vacancy_start_day, day_now)


func test_WP19_12_08_9_demolish_kontor_err03() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(200)
	_top_up(ACTOR, 5_000_000)
	var kid: StringName = _build_active_kontor()
	assert_eq(BuildingEconomy.demolish(ACTOR, kid), 0)
	assert_eq(
		StringName(BuildingEconomy.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		BuildingEconomy.ERR_SYS08_03
	)
	assert_push_error_count(1)


func test_WP19_12_08_simloop_hooks() -> void:
	## D-12h: tick_day calls daily_step + flush_signals; quarter-end untouched.
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_layout_open_and_belt()
	_write_defs()
	_load_be()
	_cheap_build_params()
	(Params._values["PRM-SYS08-BUILD_MAT"] as Dictionary)["KONTOR"] = {"GD-001": 1}
	(Params._values["PRM-SYS08-BUILD_DAYS"] as Dictionary)["KONTOR"] = 1
	_seed_good_market("GD-001", 20)
	_top_up(ACTOR, 5_000_000)
	var k1: StringName = _first_kontor_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, k1), 0)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, k1, StringName(TYPE_KONTOR))
	assert_ne(bid, &"")

	assert_eq(Clock.load_and_validate().size(), 0)
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop.register_capacity_provider(
		GoodsLedger.KIND_WAREHOUSE, BuildingEconomy.get_warehouse_capacity_provider()
	)
	SimLoop.set_consumption_provider(TestCons.new())
	SimLoop._booted = true
	Clock.set_paused(false)
	var got := {"n": 0}
	var cb := func(_id: StringName) -> void:
		got["n"] = int(got["n"]) + 1
	BuildingEconomy.construction_completed.connect(cb)
	var day_errs: Array = SimLoop.tick_day()
	assert_eq(day_errs.size(), 0, str(day_errs))
	assert_eq(BuildingEconomy.get_building(bid).state, Building.State.ACTIVE)
	assert_eq(int(got["n"]), 1)
	BuildingEconomy.construction_completed.disconnect(cb)


# --- helpers ---

func _setup_core(pop: TestPop) -> void:
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0, "params: %s" % str(perr))
	var goods_dir := _build_valid_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var ports_dir := _build_valid_ports(port_count, ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	BuildingEconomy.set_population_provider(pop)
	BuildingEconomy.set_workforce_provider(TestWorkforce.new())
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), BuildingEconomy.get_warehouse_capacity_provider()
	)


func _cheap_build_params() -> void:
	var cash: Dictionary = Params._values["PRM-SYS08-BUILD_CASH_LI"]
	for k in cash.keys():
		cash[k] = 1000
	var days: Dictionary = Params._values["PRM-SYS08-BUILD_DAYS"]
	for k in days.keys():
		days[k] = 1
	var mats: Dictionary = Params._values["PRM-SYS08-BUILD_MAT"]
	for k in mats.keys():
		mats[k] = {"GD-001": 1}


func _write_layout_open_and_belt() -> void:
	# zone 1 open, zone 2 closed (= gathering belt)
	_write_zone(ROOT + "zones/", PORT_PT01, 1, 1, 4, 1)
	_write_zone(ROOT + "zones/", PORT_PT01, 2, 1, 4, 0)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 2)


func _write_defs() -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, TYPE_KONTOR, "KONTOR", "", 0)
	_save_def(dir, TYPE_RES, "RESIDENCE", "", 0)
	_save_def(dir, TYPE_IND1, "IND1", "GD-001", 1)
	_save_def(dir, TYPE_WH, "WAREHOUSE", "", 0)
	_save_def(dir, TYPE_PUB, "PUBLIC", "", 0)


func _save_def(dir: String, type_id: String, build_class: String, out_g: String, tier: int) -> void:
	var d := BuildingDef.new()
	d.type = type_id
	d.build_class = build_class
	d.output_good_id = out_g
	d.tier = tier
	d.max_workers = 1
	d.base_output_per_worker = 1.0
	ResourceSaver.save(d, dir + type_id + ".tres")


func _load_be() -> void:
	var errs: Array = BuildingEconomy.load_and_validate(
		ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/"
	)
	assert_eq(errs.size(), 0, str(errs))


func _seed_market_mats(qty: int) -> void:
	## G3: BUILD_MAT uses GD-003／GD-004; keep GD-001 for tests that override mats.
	for g in ["GD-001", "GD-002", "GD-003", "GD-004"]:
		_seed_good_market(g, qty)


func _seed_good_market(good_id: String, qty: int) -> void:
	var mkt: Dictionary = GoodsLedger.make_market(PORT_PT01)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			mkt,
			StringName(good_id),
			qty,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)


func _top_up(actor: StringName, need: int) -> void:
	var bal: int = CashLedger.balance(actor)
	if bal >= need:
		return
	var delta: int = need - bal
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - delta),
				CashLedger.make_entry(actor, delta),
			],
			&"TEST_TOP_UP",
			BuildingEconomy.REQUESTER_SYS08
		),
		OK
	)


func _force_active(bld_id: StringName) -> void:
	var bld: Building = BuildingEconomy.get_building(bld_id)
	bld.state = Building.State.ACTIVE
	bld.days_left = 0
	bld.missing_materials = {}


func _build_active_kontor() -> StringName:
	var k1: StringName = _first_kontor_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, k1), 0)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, k1, StringName(TYPE_KONTOR))
	assert_ne(bid, &"", str(BuildingEconomy.last_errors()))
	_force_active(bid)
	return bid


func _build_active_kontor_without_force() -> StringName:
	var k1: StringName = _first_kontor_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, k1), 0)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, k1, StringName(TYPE_KONTOR))
	assert_ne(bid, &"")
	return bid


func _first_kontor_slot() -> StringName:
	for s in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = s
		if slot.kind == Slot.Kind.KONTOR and slot.building_id == &"":
			return slot.slot_id
	return &""


func _second_kontor_slot() -> StringName:
	var seen := 0
	for s in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = s
		if slot.kind == Slot.Kind.KONTOR and slot.building_id == &"":
			seen = seen + 1
			if seen == 1:
				continue
			return slot.slot_id
	return &""


func _first_open_civil() -> StringName:
	for s in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = s
		if slot.kind == Slot.Kind.CIVIL and slot.zone_open and slot.building_id == &"":
			return slot.slot_id
	return &""


func _first_open_civil_owned() -> StringName:
	var id: StringName = _first_open_civil()
	if BuildingEconomy.get_slot(id).land_owner != ACTOR:
		assert_gt(BuildingEconomy.buy_land(ACTOR, id), 0)
	return id


func _first_belt_slot() -> StringName:
	for s in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = s
		if BuildingEconomy.is_gathering_belt_slot(slot.slot_id) and slot.building_id == &"":
			return slot.slot_id
	return &""


func _errors_have(code: StringName) -> bool:
	for e in BuildingEconomy.last_errors():
		if StringName((e as Dictionary).get(ErrorInfoUtil.KEY_CODE, &"")) == code:
			return true
	if StringName(BuildingEconomy.last_error().get(ErrorInfoUtil.KEY_CODE, &"")) == code:
		return true
	return false


func _write_zone(dir: String, port_id: String, zone: int, rings: int, slots: int, open_at: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var z := ZoneDef.new()
	z.port_id = port_id
	z.zone = zone
	z.slot_share = 0.5
	z.rings = rings
	z.slots = slots
	z.open_at_start = open_at
	ResourceSaver.save(z, dir + "%s__%d.tres" % [port_id, zone])


func _write_city_center(dir: String, port_id: String, public_slots: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c := CityCenterDef.new()
	c.port_id = port_id
	c.public_slots = public_slots
	ResourceSaver.save(c, dir + port_id + ".tres")


func _build_valid_goods(dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": "GD-001", "name": STAPLE_RICE, "build": false},
		{"id": "GD-002", "name": STAPLE_SALT, "build": false},
		{"id": "GD-003", "name": STAPLE_TIMBER, "build": true},
		{"id": "GD-004", "name": STAPLE_FISH, "build": false},
	]
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		ResourceSaver.save(
			_make_good(s["id"], s["name"], 1, true, s["build"], false, ANCHOR_LI),
			dir + "%s.tres" % s["id"]
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(
			_make_good(gid, "填料%d" % next_n, tier, false, false, false, ANCHOR_LI),
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
		def.draft_limit_class = 0
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


func _valid_free_count(port_count: int) -> int:
	var ratio_min: float = Params.get_float(PRM_FREE_PORT_RATIO_MIN)
	var ratio_max: float = Params.get_float(PRM_FREE_PORT_RATIO_MAX)
	if port_count <= 0:
		return 0
	var free_count: int = 0
	while free_count <= port_count:
		var ratio: float = float(free_count) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return free_count
		free_count += 1
	return 0


func _make_good(
	good_id: String,
	name_zh: String,
	tier: int,
	is_staple: bool,
	is_build_material: bool,
	is_strategic: bool,
	base_price_li: int
) -> GoodDef:
	var def := GoodDef.new()
	def.good_id = good_id
	def.name_zh = name_zh
	def.tier = tier
	def.is_staple = is_staple
	def.is_build_material = is_build_material
	def.is_strategic = is_strategic
	def.base_price_li = base_price_li
	def.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
	return def


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
