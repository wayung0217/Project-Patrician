extends GutTest
## WP-23 / TechSpec 14-07 city + quarter-end (FRM-03／04／12–18).


const PARAMS_FIXTURE := "res://tests/fixtures/params_sys05_demo.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp23_city/"
const PORT := "PT-01"
const ACTOR := &"ACT-PLAYER"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"


class TestPop extends PopulationProvider:
	var _n: Dictionary = {}

	func set_pop(port_id: String, n: int) -> void:
		_n[port_id] = n

	func population(port_id: StringName) -> int:
		return int(_n.get(String(port_id), 1000))


class TestWorkforce extends WorkforceProvider:
	var _w: Dictionary = {}

	func set_workers(ws_id: StringName, n: int) -> void:
		_w[String(ws_id)] = n

	func workers(ws_id: StringName) -> int:
		return int(_w.get(String(ws_id), 0))


class TestCons extends ConsumptionProvider:
	func weekly_consumption(_p: StringName, _g: StringName) -> int:
		return 100

	func consume_qty(_p: StringName, _g: StringName, _d: int) -> int:
		return 0


class TestSat extends SatisfactionInputProvider:
	func satisfaction_input(_p: StringName, _c: StringName) -> float:
		return 0.5


func before_each() -> void:
	_wipe(ROOT)
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false


func test_TST_SYS08_10_season_wage_mandatory() -> void:
	var wf := TestWorkforce.new()
	var brew: StringName = _boot_player_workshop(wf, 20)
	wf.set_workers(brew, 20)
	# Accrue several days then season.
	for d in range(1, 31):
		BuildingEconomy.daily_step(d)
	var bld: Building = BuildingEconomy.get_building(brew)
	assert_gt(bld.acc_wage_li, 0)
	# Drain cash so arrears appear.
	var bal: int = CashLedger.balance(ACTOR)
	if bal > 10:
		CashLedger.post(
			[
				CashLedger.make_entry(ACTOR, 0 - (bal - 10)),
				CashLedger.make_entry(CashLedger.ID_SINK, bal - 10),
			],
			&"TEST_DRAIN",
			BuildingEconomy.REQUESTER_SYS08
		)
	BuildingEconomy.season_step()
	assert_eq(bld.acc_wage_li, 0)
	assert_gt(CashLedger.arrears(ACTOR), 0)


func test_TST_SYS08_11_rent_source_to_owner_and_city() -> void:
	_boot_world()
	var city := CashLedger.make_city_id(PORT)
	# Player residence
	var res_p := _force_residence(ACTOR, "RES-P")
	PopulationModel.set_satisfaction_input_provider(TestSat.new())
	assert_eq(PopulationModel.load_and_validate().size(), 0)
	PopulationModel.set_residence_occupants(res_p, 0, 100, 0)
	# City residence
	var res_c := _force_residence(city, "RES-C")
	PopulationModel.set_residence_occupants(res_c, 0, 100, 0)
	for d in range(1, 91):
		BuildingEconomy.daily_step(d)
	var bp: Building = BuildingEconomy.get_building(res_p)
	var bc: Building = BuildingEconomy.get_building(res_c)
	assert_gt(bp.acc_rent_li, 0)
	assert_gt(bc.acc_rent_li, 0)
	var owner_before: int = CashLedger.balance(ACTOR)
	var city_before: int = CashLedger.balance(city)
	BuildingEconomy.season_step()
	assert_gt(CashLedger.balance(ACTOR), owner_before)
	assert_gt(CashLedger.balance(city), city_before)
	assert_eq(bp.acc_rent_li, 0)


func test_TST_SYS08_12_vacancy_after_grace() -> void:
	_boot_world()
	var tpd: int = Params.get_int("PRM-SYS00-TICKS_PER_DAY")
	Clock._tick = 1 * tpd # day 1
	var slot: StringName = _first_open_civil()
	assert_gt(BuildingEconomy.buy_land(ACTOR, slot), 0)
	var s: Slot = BuildingEconomy.get_slot(slot)
	assert_eq(s.vacancy_start_day, 1)
	# Advance held days past grace 84 → day 100.
	BuildingEconomy._land_held_days[String(slot)] = 100
	Clock._tick = 100 * tpd
	var city := CashLedger.make_city_id(PORT)
	var city0: int = CashLedger.balance(city)
	var rent0: int = _sum_posted_to(city, BuildingEconomy.REASON_LAND_RENT)
	var vac0: int = _sum_posted_to(city, BuildingEconomy.REASON_VACANCY_TAX)
	BuildingEconomy.season_step()
	assert_gt(CashLedger.balance(city), city0)
	var rent1: int = _sum_posted_to(city, BuildingEconomy.REASON_LAND_RENT)
	var vac1: int = _sum_posted_to(city, BuildingEconomy.REASON_VACANCY_TAX)
	assert_gt(rent1 - rent0, 0)
	assert_gt(vac1 - vac0, 0)
	assert_ne(rent1 - rent0, vac1 - vac0)


func test_TST_SYS08_12b_vacancy_within_grace_no_tax() -> void:
	## D-19c: within-grace negative control — LAND_RENT may post; VACANCY_TAX must not.
	_boot_world()
	var tpd: int = Params.get_int("PRM-SYS00-TICKS_PER_DAY")
	var grace: int = Params.get_int("PRM-SYS08-VACANCY_GRACE_DAYS")
	Clock._tick = 1 * tpd
	var slot: StringName = _first_open_civil()
	assert_gt(BuildingEconomy.buy_land(ACTOR, slot), 0)
	var mid: int = mini(50, grace)
	assert_lte(mid, grace)
	BuildingEconomy._land_held_days[String(slot)] = mid
	Clock._tick = mid * tpd
	var city := CashLedger.make_city_id(PORT)
	var vac0: int = _sum_posted_to(city, BuildingEconomy.REASON_VACANCY_TAX)
	var rent0: int = _sum_posted_to(city, BuildingEconomy.REASON_LAND_RENT)
	BuildingEconomy.season_step()
	assert_eq(_sum_posted_to(city, BuildingEconomy.REASON_VACANCY_TAX), vac0)
	assert_gt(_sum_posted_to(city, BuildingEconomy.REASON_LAND_RENT), rent0)


func test_TST_SYS08_13_garrison_no_stock_no_debt() -> void:
	_boot_world()
	var city := CashLedger.make_city_id(PORT)
	_force_public(city, &"CB-09", 2)
	CashLedger.post(
		[
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - 100000),
			CashLedger.make_entry(city, 100000),
		],
		&"TEST_FUND",
		BuildingEconomy.REQUESTER_SYS08
	)
	var arrears0: int = CashLedger.arrears(city)
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	assert_eq(CashLedger.arrears(city), arrears0)
	assert_eq(int(BuildingEconomy._acc_arms.get(PORT, 0)), 0)


func test_TST_SYS08_14_city_queue_no_skip() -> void:
	_boot_world()
	var city := CashLedger.make_city_id(PORT)
	# Two queue steps; fund enough for step1 only if step0 is expensive.
	var s0 := BuildStep.new()
	s0.port_id = PORT
	s0.step = 0
	s0.cb_id = "CB-01"
	s0.target_level = 1
	var s1 := BuildStep.new()
	s1.port_id = PORT
	s1.step = 1
	s1.cb_id = "CB-02"
	s1.target_level = 1
	BuildingEconomy.set_build_queue(PORT, [s0, s1])
	# PUBLIC cash cost from params — fund less than one.
	var cost: int = int(Params.get_value("PRM-SYS08-BUILD_CASH_LI")["PUBLIC"])
	CashLedger.post(
		[
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - (cost - 1)),
			CashLedger.make_entry(city, cost - 1),
		],
		&"TEST_FUND",
		BuildingEconomy.REQUESTER_SYS08
	)
	BuildingEconomy.season_step()
	assert_eq(int(BuildingEconomy._queue_pos[PORT]), 0)


func test_TST_SYS08_14b_city_queue_asymmetric_no_skip() -> void:
	## D-19c: item1 unaffordable (L2 upgrade cash), item2 affordable (PUBLIC L1) → no skip.
	## Uses existing UPGRADE_PER_CAPITA vs BUILD_CASH_LI PUBLIC — no invented per-cb_id prices.
	_boot_world()
	var city := CashLedger.make_city_id(PORT)
	var s0 := BuildStep.new()
	s0.port_id = PORT
	s0.step = 0
	s0.cb_id = "CB-01"
	s0.target_level = 2
	var s1 := BuildStep.new()
	s1.port_id = PORT
	s1.step = 1
	s1.cb_id = "CB-02"
	s1.target_level = 1
	BuildingEconomy.set_build_queue(PORT, [s0, s1])
	var public_cost: int = int(Params.get_value("PRM-SYS08-BUILD_CASH_LI")["PUBLIC"])
	var upgrade_cost: int = BuildingEconomy._public_upgrade_cash(PORT, 2)
	assert_gt(upgrade_cost, public_cost)
	CashLedger.post(
		[
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - public_cost),
			CashLedger.make_entry(city, public_cost),
		],
		&"TEST_FUND",
		BuildingEconomy.REQUESTER_SYS08
	)
	assert_lt(CashLedger.balance(city), upgrade_cost)
	assert_gte(CashLedger.balance(city), public_cost)
	BuildingEconomy.season_step()
	assert_eq(int(BuildingEconomy._queue_pos[PORT]), 0)
	assert_eq(BuildingEconomy.public_level(StringName(PORT), &"CB-02"), 0)


func test_D21b_public_upgrade_fee_scales_with_pop() -> void:
	## D-21b: FRM-SYS08-07 — different pop → different upgrade fee; queue helper matches fee API.
	## Mutate injected TestPop (D-11d forbids set_population_provider after load).
	_boot_world()
	var pop: TestPop = BuildingEconomy._population as TestPop
	pop.set_pop(PORT, 500)
	var fee_a: Dictionary = BuildingEconomy.public_upgrade_fee(StringName(PORT), 2)
	var cash_a: int = int(fee_a["CASH_LI"])
	var helper_a: int = BuildingEconomy._public_upgrade_cash(PORT, 2)
	assert_eq(helper_a, cash_a)
	pop.set_pop(PORT, 1500)
	var fee_b: Dictionary = BuildingEconomy.public_upgrade_fee(StringName(PORT), 2)
	var cash_b: int = int(fee_b["CASH_LI"])
	var helper_b: int = BuildingEconomy._public_upgrade_cash(PORT, 2)
	assert_eq(helper_b, cash_b)
	assert_ne(cash_a, cash_b)
	assert_gt(cash_b, cash_a)
	# L2 uses arr[0], not arr[1] (三級).
	var arr: Array = Params.get_value("PRM-SYS08-UPGRADE_PER_CAPITA")
	var l2: int = int((arr[0] as Dictionary).get("CASH_LI", 0))
	var expect_b: int = ceili(AmountQuantize.quantize_amount(1500.0 * float(l2)))
	assert_eq(cash_b, expect_b)


func test_TST_SYS08_R_boot_and_zone_open_max_ring() -> void:
	## D-19c: R = max ring among open CIVIL slots at boot and after zone-open.
	_boot_world()
	assert_eq(BuildingEconomy.ring_count_open(PORT), 1)
	# Manually open zone 2 slots (same path as season zone-open recompute).
	for s_v in BuildingEconomy.slots_for_port(PORT):
		var s: Slot = s_v
		if s.kind == Slot.Kind.CIVIL and s.zone == 2:
			s.zone_open = true
	BuildingEconomy._max_open_zone[PORT] = 2
	assert_eq(BuildingEconomy._recompute_r(PORT), 2)
	assert_eq(BuildingEconomy.ring_count_open(PORT), 2)
	# Boundary: hole at ring 2 — max stays 3, not unique-count 2.
	for s2 in BuildingEconomy.slots_for_port(PORT):
		var sl: Slot = s2
		if sl.kind == Slot.Kind.CIVIL and sl.ring == 2:
			sl.zone_open = false
		if sl.kind == Slot.Kind.CIVIL and sl.ring == 1:
			sl.zone_open = true
	# Fabricate a ring-3 open civil for the hole case.
	var hole := Slot.new()
	hole.kind = Slot.Kind.CIVIL
	hole.port_id = PORT
	hole.zone = 3
	hole.ring = 3
	hole.land_owner = CashLedger.make_city_id(PORT)
	hole.building_id = &""
	hole.zone_open = true
	hole.slot_id = StringName("SLOT:%s:HOLE3" % PORT)
	BuildingEconomy._register_slot(hole, BuildingEconomy._slots_by_port[PORT])
	assert_eq(BuildingEconomy._recompute_r(PORT), 3)
	assert_eq(BuildingEconomy.ring_count_open(PORT), 3)


func test_TST_SYS08_15_missing_levy_prm_boot_error() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT, 1000)
	_setup_core_without_be(pop)
	Params._values.erase("PRM-SYS08-LEVY_RATE")
	BuildingEconomy.set_population_provider(pop)
	BuildingEconomy.set_workforce_provider(TestWorkforce.new())
	_write_layout()
	_write_defs()
	var errs: Array = BuildingEconomy.load_and_validate(
		ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/"
	)
	assert_gt(errs.size(), 0)
	var found := false
	for e in errs:
		if String((e as Dictionary).get("code", "")) == String(BuildingEconomy.ERR_SYS08_09):
			found = true
	assert_true(found)
	assert_push_error_count(errs.size())


func test_TST_SYS08_16_buy_city_residence_vs_player() -> void:
	_boot_world()
	var city := CashLedger.make_city_id(PORT)
	var res_c := _force_residence(city, "RES-CITY")
	var res_p := _force_residence(ACTOR, "RES-PL")
	_top_up(ACTOR, 50_000_000)
	var price: int = BuildingEconomy.quote_city_building(res_c)
	assert_gt(price, 0)
	var city0: int = CashLedger.balance(city)
	assert_gt(BuildingEconomy.buy_city_building(ACTOR, res_c), 0)
	assert_eq(BuildingEconomy.get_building(res_c).owner, ACTOR)
	assert_gt(CashLedger.balance(city), city0)
	assert_eq(BuildingEconomy.buy_city_building(ACTOR, res_p), 0)
	assert_eq(String(BuildingEconomy.last_error().get("code", "")), String(BuildingEconomy.ERR_SYS08_12))
	assert_push_error_count(1)


func test_WP23_14_07_1_season_order_reproducible() -> void:
	var wf := TestWorkforce.new()
	_boot_world(wf)
	var brew := _force_workshop(ACTOR, "IND1", "GD-001", 1)
	wf.set_workers(brew, 4)
	for _i in range(7):
		BuildingEconomy.daily_step(1)
	var a1: int = BuildingEconomy.get_building(brew).acc_wage_li
	assert_gt(a1, 0)
	BuildingEconomy.season_step()
	assert_eq(BuildingEconomy.get_building(brew).acc_wage_li, 0)
	# Replay
	before_each()
	wf = TestWorkforce.new()
	_boot_world(wf)
	brew = _force_workshop(ACTOR, "IND1", "GD-001", 1)
	wf.set_workers(brew, 4)
	for _i2 in range(7):
		BuildingEconomy.daily_step(1)
	assert_eq(BuildingEconomy.get_building(brew).acc_wage_li, a1)
	BuildingEconomy.season_step()
	assert_eq(BuildingEconomy.get_building(brew).acc_wage_li, 0)


func test_WP23_14_07_4_levy_only_surplus() -> void:
	_boot_world()
	var city := CashLedger.make_city_id(PORT)
	BuildingEconomy._city_spend_hist[PORT] = [1000, 1000, 1000, 1000]
	BuildingEconomy._season_city_spend[PORT] = 1000
	# thr = 4 * 1000 = 4000; fund 10000 → levy floor((10000-4000)*0.1)=600
	CashLedger.post(
		[
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - 10000),
			CashLedger.make_entry(city, 10000),
		],
		&"TEST_FUND",
		BuildingEconomy.REQUESTER_SYS08
	)
	BuildingEconomy._season_levy(PORT)
	assert_eq(CashLedger.balance(city), 9400)


# --- helpers ---


func _boot_player_workshop(wf: TestWorkforce, workers: int) -> StringName:
	_boot_world(wf)
	var brew := _force_workshop(ACTOR, "IND1", "GD-001", 1)
	wf.set_workers(brew, workers)
	_top_up(ACTOR, 1_000_000)
	return brew


func _boot_world(wf: WorkforceProvider = null) -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT, 1000)
	_setup_core_without_be(pop)
	BuildingEconomy.set_population_provider(pop)
	if wf == null:
		wf = TestWorkforce.new()
	BuildingEconomy.set_workforce_provider(wf)
	_write_layout()
	_write_defs()
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)
	_top_up(ACTOR, 5_000_000)


func _setup_core_without_be(pop: TestPop) -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	var goods_dir := _build_valid_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_valid_ports(Params.get_int(PRM_PORT_COUNT_MIN), ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	MarketPricer.set_consumption_provider(TestCons.new())
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), BuildingEconomy.get_warehouse_capacity_provider()
	)
	var _p: TestPop = pop


func _force_workshop(owner: StringName, bclass: String, out_g: String, tier: int) -> StringName:
	var type_id := "WS-%s-%d" % [bclass, tier]
	if not BuildingEconomy._building_defs.has(type_id):
		var d := BuildingDef.new()
		d.type = type_id
		d.build_class = bclass
		d.output_good_id = out_g
		d.tier = tier
		d.max_workers = 20
		d.base_output_per_worker = 1.0
		BuildingEconomy._building_defs[type_id] = d
	var bld := Building.new()
	bld.building_id = BuildingEconomy._next_bld_id(PORT)
	bld.type = StringName(type_id)
	bld.build_class = StringName(bclass)
	bld.owner = owner
	bld.port_id = PORT
	bld.state = Building.State.ACTIVE
	BuildingEconomy._register_building(bld)
	return bld.building_id


func _force_residence(owner: StringName, tag: String) -> StringName:
	var slot: StringName = _first_open_civil()
	if owner != CashLedger.make_city_id(PORT):
		if BuildingEconomy.get_slot(slot).land_owner != owner:
			assert_gt(BuildingEconomy.buy_land(owner, slot), 0)
	var bld := Building.new()
	bld.building_id = BuildingEconomy._next_bld_id(PORT)
	bld.type = &"RB-01"
	bld.build_class = &"RESIDENCE"
	bld.owner = owner
	bld.port_id = PORT
	bld.slot_id = slot
	bld.state = Building.State.ACTIVE
	BuildingEconomy.get_slot(slot).building_id = bld.building_id
	BuildingEconomy.get_slot(slot).vacancy_start_day = -1
	BuildingEconomy._register_building(bld)
	var _t: String = tag
	return bld.building_id


func _force_public(owner: StringName, cb: StringName, level: int) -> void:
	var slot_id: StringName = &""
	for s_v in BuildingEconomy.slots_for_port(PORT):
		var s: Slot = s_v
		if s.kind == Slot.Kind.PUBLIC and s.building_id == &"":
			slot_id = s.slot_id
			break
	assert_ne(slot_id, &"")
	var bld := Building.new()
	bld.building_id = BuildingEconomy._next_bld_id(PORT)
	bld.type = cb
	bld.cb_id = cb
	bld.build_class = &"PUBLIC"
	bld.owner = owner
	bld.port_id = PORT
	bld.slot_id = slot_id
	bld.level = level
	bld.state = Building.State.ACTIVE
	BuildingEconomy.get_slot(slot_id).building_id = bld.building_id
	BuildingEconomy._register_building(bld)


func _first_open_civil() -> StringName:
	for s_v in BuildingEconomy.slots_for_port(PORT):
		var s: Slot = s_v
		if s.kind == Slot.Kind.CIVIL and s.zone_open and s.building_id == &"":
			return s.slot_id
	return &""


func _sum_posted_to(account: StringName, reason: StringName) -> int:
	var total := 0
	for p_v in CashLedger._postings:
		var p: Posting = p_v
		if p.reason != reason:
			continue
		for e_v in p.entries:
			var e: PostingEntry = e_v
			if e.account_id == account and e.amount > 0:
				total = total + e.amount
	return total


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


func _write_layout() -> void:
	_write_zone(ROOT + "zones/", PORT, 1, 1, 8, 1)
	_write_zone(ROOT + "zones/", PORT, 2, 1, 4, 0)
	_write_city(ROOT + "city_center/", PORT, 4)


func _write_defs() -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, "KT-01", "KONTOR", "", 0, 1.0)
	_save_def(dir, "RB-01", "RESIDENCE", "", 0, 1.0)
	_save_def(dir, "IND1", "IND1", "GD-001", 1, 1.0)


func _save_def(dir: String, type_id: String, bclass: String, out_g: String, tier: int, base: float) -> void:
	var d := BuildingDef.new()
	d.type = type_id
	d.build_class = bclass
	d.output_good_id = out_g
	d.tier = tier
	d.max_workers = 20
	d.base_output_per_worker = base
	ResourceSaver.save(d, dir + type_id + ".tres")


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


func _write_city(dir: String, port_id: String, public_slots: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c := CityCenterDef.new()
	c.port_id = port_id
	c.public_slots = public_slots
	ResourceSaver.save(c, dir + port_id + ".tres")


func _build_valid_goods(dir: String) -> String:
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": "GD-001", "name": "米", "build": false},
		{"id": "GD-002", "name": "鹽", "build": false},
		{"id": "GD-003", "name": "木材", "build": true},
		{"id": "GD-004", "name": "魚乾", "build": false},
	]
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		var g := GoodDef.new()
		g.good_id = s["id"]
		g.name_zh = s["name"]
		g.tier = 1
		g.is_staple = true
		g.is_build_material = s["build"]
		g.base_price_li = 10
		g.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(g, dir + "%s.tres" % s["id"])
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		var g2 := GoodDef.new()
		g2.good_id = gid
		g2.name_zh = gid
		g2.tier = tier
		g2.is_staple = false
		g2.base_price_li = 10
		g2.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(g2, dir + "%s.tres" % gid)
		written += 1
		next_n += 1
	return dir


func _build_valid_ports(port_count: int, dir: String) -> String:
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var ratio_min: float = Params.get_float(PRM_FREE_PORT_RATIO_MIN)
	var ratio_max: float = Params.get_float(PRM_FREE_PORT_RATIO_MAX)
	var free_count := 0
	for c in range(port_count + 1):
		var ratio: float = float(c) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			free_count = c
			break
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	for i in range(port_count):
		var port_id := "PT-%02d" % (i + 1)
		var def := PortDef.new()
		def.port_id = port_id
		def.name_zh = "港%d" % (i + 1)
		def.is_free_port = i < free_count
		def.draft_limit_class = 0
		def.regime_id = "RG-TEST"
		def.role_cells = {}
		for gv in good_ids:
			var cell := RoleCell.new()
			cell.role = PortRegistry.ROLE_PRODUCER if i == 0 else PortRegistry.ROLE_TERMINAL
			cell.base_output_per_season = 1 if i == 0 else 0
			def.role_cells[String(gv)] = cell
		ResourceSaver.save(def, dir + "%s.tres" % port_id)
	return dir


func _wipe(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var n: String = dir.get_next()
		if n == "":
			break
		if n == "." or n == "..":
			continue
		var child: String = abs_path.path_join(n)
		if dir.current_is_dir():
			_wipe(path.path_join(n))
			DirAccess.remove_absolute(child)
		else:
			DirAccess.remove_absolute(child)
	dir.list_dir_end()
