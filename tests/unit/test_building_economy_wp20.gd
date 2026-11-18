extends GutTest
## WP-20 / TechSpec 12-12 workshop produce + wage accrual.


const PARAMS_FIXTURE := "res://tests/fixtures/params_sys05_demo.json"
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
const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"
const ANCHOR_LI := 1000

const ROOT := "user://wp20_be/"
const TYPE_KONTOR := "KT-01"
const TYPE_IND1 := "IB-RICE"
const TYPE_IND2 := "IB-BREW"
const TYPE_WH := "WH-01"


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
	var _by_ws: Dictionary = {} ## String → int
	var _default: int = 0

	func set_workers(ws_id: StringName, n: int) -> void:
		_by_ws[String(ws_id)] = n

	func set_default(n: int) -> void:
		_default = n

	func workers(ws_id: StringName) -> int:
		var key := String(ws_id)
		if _by_ws.has(key):
			return int(_by_ws[key])
		return _default


class TestCons extends ConsumptionProvider:
	func weekly_consumption(_port_id: StringName, _good_id: StringName) -> int:
		return 100

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
	BuildingEconomy._pending_started = []
	BuildingEconomy._pending_waiting = []
	BuildingEconomy._pending_completed = []
	BuildingEconomy._pending_shortfalls = []
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()


func test_TST_SYS08_06_seven_day_floor_week_output() -> void:
	## TST-SYS08-06／12-12 ①: 7-day Σ = FLOOR(workers × base × K).
	var wf := TestWorkforce.new()
	var farm: StringName = _boot_active_workshop(wf, TYPE_IND1, "GD-001", 1, 1.0, "", 0)
	wf.set_workers(farm, 25)
	var k: float = Params.get_float(BuildingEconomy.PRM_OUTPUT_K)
	var week: float = 25.0 * 1.0 * k
	var expect: int = floori(week)
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	var before: int = GoodsLedger.get_qty(wh, &"GD-001")
	var day_outs: Array = []
	for _d in range(7):
		var q0: int = GoodsLedger.get_qty(wh, &"GD-001")
		assert_eq(BuildingEconomy.daily_step(_d + 1).size(), 0)
		var q1: int = GoodsLedger.get_qty(wh, &"GD-001")
		day_outs.append(q1 - q0)
	var total: int = 0
	for v in day_outs:
		total = total + int(v)
	assert_eq(total, expect)
	assert_eq(GoodsLedger.get_qty(wh, &"GD-001"), before + expect)
	for v2 in day_outs:
		assert_lte(absi(int(v2) - int(round(week / 7.0))), 1)


func test_TST_SYS08_07_input_shortfall_and_signal() -> void:
	## TST-SYS08-07／12-12: input caps out; CONSUME CEIL(out×qty×N); shortfall signal.
	## Gap: content recipe 1.5 not int (10-06); fixture uses qty=1.
	var wf := TestWorkforce.new()
	var brew: StringName = _boot_active_workshop(wf, TYPE_IND2, "GD-002", 2, 10.0, "GD-001", 1)
	wf.set_workers(brew, 10)
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	# Seed rice for ~2/3 of potential: pot ≈ floor(10*10*1.83/7) per day via acc.
	# Pot ≈ floor(10×10×1.83 / 7)=26; seed rice so feas ≈ 2/3 pot.
	_seed_wh("GD-001", 10)
	var n: float = Params.get_float(BuildingEconomy.PRM_RECIPE_N)
	var rice_before: int = GoodsLedger.get_qty(wh, &"GD-001")
	assert_eq(rice_before, 10)
	var saw: Array = []
	var cb := func(bld_id: StringName, reason: StringName) -> void:
		saw.append({"id": bld_id, "reason": reason})
	BuildingEconomy.production_shortfall.connect(cb)
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	BuildingEconomy.flush_signals()
	BuildingEconomy.production_shortfall.disconnect(cb)
	var out: int = GoodsLedger.get_qty(wh, &"GD-002")
	var rice_left: int = GoodsLedger.get_qty(wh, &"GD-001")
	assert_gt(out, 0)
	var used: int = rice_before - rice_left
	assert_eq(used, ceili(AmountQuantize.quantize_amount(float(out) * 1.0 * n)))
	assert_eq(saw.size(), 1)
	assert_eq(saw[0]["id"], brew)
	assert_eq(saw[0]["reason"], BuildingEconomy.SHORTFALL_INPUT)


func test_TST_SYS08_08_warehouse_cap_limits_out() -> void:
	## TST-SYS08-08: out_cap binds; market unchanged; shortfall CAPACITY.
	var wf := TestWorkforce.new()
	var farm: StringName = _boot_active_workshop(wf, TYPE_IND1, "GD-001", 1, 50.0, "", 0)
	wf.set_workers(farm, 20)
	# Shrink kontor cap so remaining room is 10.
	Params._values[BuildingEconomy.PRM_KONTOR_CAP] = [10, 10, 10]
	Params._values[BuildingEconomy.PRM_WAREHOUSE_CAP] = 0
	assert_eq(BuildingEconomy.warehouse_capacity(ACTOR, StringName(PORT_PT01)), 10)
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	var mkt: Dictionary = GoodsLedger.make_market(PORT_PT01)
	var m_before: int = GoodsLedger.get_qty(mkt, &"GD-001")
	var saw: Array = []
	var cb := func(_id: StringName, reason: StringName) -> void:
		saw.append(reason)
	BuildingEconomy.production_shortfall.connect(cb)
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	BuildingEconomy.flush_signals()
	BuildingEconomy.production_shortfall.disconnect(cb)
	assert_eq(GoodsLedger.get_qty(wh, &"GD-001"), 10)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-001"), m_before)
	assert_true(saw.has(BuildingEconomy.SHORTFALL_CAPACITY))


func test_TST_SYS08_09_zero_workers_zero_out_wage() -> void:
	## TST-SYS08-09 (produce/wage part): 0 workers → out 0, wage 0.
	var wf := TestWorkforce.new()
	var farm: StringName = _boot_active_workshop(wf, TYPE_IND1, "GD-001", 1, 5.0, "", 0)
	wf.set_workers(farm, 0)
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	assert_eq(GoodsLedger.get_qty(wh, &"GD-001"), 0)
	assert_eq(BuildingEconomy.get_building(farm).acc_wage_li, 0)
	assert_eq(BuildingEconomy.get_building(farm).acc_out, 0)


func test_TST_SYS08_17_season_conservation_fixture() -> void:
	## TST-SYS08-17: fixture season produce/consume conserves (FRM-SYS03-01).
	var wf := TestWorkforce.new()
	var farm: StringName = _boot_active_workshop(wf, TYPE_IND1, "GD-001", 1, 2.0, "", 0)
	wf.set_workers(farm, 5)
	var days: int = Params.get_int(PRM_DAYS_PER_SEASON)
	for d in range(days):
		assert_eq(BuildingEconomy.daily_step(d + 1).size(), 0)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_WP20_12_12_2_upstream_same_day_feeds_downstream() -> void:
	## 12-12 ②: tier order — upstream out available to downstream same day.
	var wf := TestWorkforce.new()
	_setup_world(wf)
	_write_defs_chain()
	_load_be()
	_cheap_build_params()
	_seed_market_mats(500)
	_top_up(ACTOR, 5_000_000)
	_build_active_kontor()
	var belt: StringName = _first_belt_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, belt), 0)
	var up: StringName = BuildingEconomy.order_build(ACTOR, belt, StringName(TYPE_IND1))
	assert_ne(up, &"")
	_force_active(up)
	var civil: StringName = _first_open_civil_owned()
	var down: StringName = BuildingEconomy.order_build(ACTOR, civil, StringName(TYPE_IND2))
	assert_ne(down, &"", str(BuildingEconomy.last_errors()))
	_force_active(down)
	wf.set_workers(up, 20)
	wf.set_workers(down, 10)
	# Downstream needs GD-001; warehouse starts empty — only same-day upstream feed enables out.
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	assert_eq(GoodsLedger.get_qty(wh, &"GD-001"), 0)
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	assert_gt(GoodsLedger.get_qty(wh, &"GD-002"), 0, "downstream must produce same day")


func test_WP20_12_12_3_paused_no_out_no_wage() -> void:
	## 12-12 ③: PAUSED → no produce, no wage.
	var wf := TestWorkforce.new()
	var farm: StringName = _boot_active_workshop(wf, TYPE_IND1, "GD-001", 1, 5.0, "", 0)
	wf.set_workers(farm, 10)
	assert_eq(BuildingEconomy.pause(ACTOR, farm), 1)
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	assert_eq(GoodsLedger.get_qty(wh, &"GD-001"), 0)
	assert_eq(BuildingEconomy.get_building(farm).acc_wage_li, 0)


func test_WP20_12_12_4_missing_workforce_boot_error() -> void:
	## 12-12 ④: no WorkforceProvider → boot error.
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core_pop_only(pop)
	_write_layout()
	_write_defs_simple()
	var errs: Array = BuildingEconomy.load_and_validate(
		ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/"
	)
	assert_gt(errs.size(), 0)
	var found := false
	for e in errs:
		if String((e as Dictionary).get("code", "")) == String(
			BuildingEconomy.CODE_WORKFORCE_PROVIDER_MISSING
		):
			found = true
	assert_true(found)
	assert_false(BuildingEconomy.is_loaded())
	assert_push_error_count(errs.size())


func test_WP20_12_11_wage_accrues_when_starved() -> void:
	## 12-11: ACTIVE + input shortfall still accrues wage; city workshops skip.
	var wf := TestWorkforce.new()
	var brew: StringName = _boot_active_workshop(wf, TYPE_IND2, "GD-002", 2, 10.0, "GD-001", 1)
	wf.set_workers(brew, 4)
	# No rice seeded → out 0 but wage accrues.
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	var wage: int = BuildingEconomy.get_building(brew).acc_wage_li
	var k: float = Params.get_float(BuildingEconomy.PRM_OUTPUT_K)
	var w_share: float = Params.get_float(BuildingEconomy.PRM_WAGE_SHARE_W)
	var base: int = Params.get_int(BuildingEconomy.PRM_WAGE_BASE_LI)
	var acc: int = Params.get_int(BuildingEconomy.PRM_ACC_SCALE)
	var expect: int = floori(
		AmountQuantize.quantize_amount(4.0 * float(base) * pow(k, w_share) * float(acc))
	)
	assert_eq(wage, expect)
	assert_eq(GoodsLedger.get_qty(GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01), &"GD-002"), 0)


# --- helpers ---


func _boot_active_workshop(
	wf: TestWorkforce,
	type_id: String,
	out_g: String,
	tier: int,
	base_out: float,
	in_g: String,
	in_qty: int
) -> StringName:
	_setup_world(wf)
	_write_defs_custom(type_id, out_g, tier, base_out, in_g, in_qty)
	_load_be()
	_cheap_build_params()
	_seed_market_mats(500)
	_top_up(ACTOR, 5_000_000)
	_build_active_kontor()
	var slot: StringName
	if tier <= 1:
		slot = _first_belt_slot()
	else:
		slot = _first_open_civil_owned()
	if BuildingEconomy.get_slot(slot).land_owner != ACTOR:
		assert_gt(BuildingEconomy.buy_land(ACTOR, slot), 0)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, slot, StringName(type_id))
	assert_ne(bid, &"", str(BuildingEconomy.last_errors()))
	_force_active(bid)
	return bid


func _setup_world(wf: TestWorkforce) -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop, wf)
	_write_layout()


func _setup_core(pop: TestPop, wf: TestWorkforce) -> void:
	var perr: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(perr.size(), 0, "params: %s" % str(perr))
	var goods_dir := _build_valid_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var ports_dir := _build_valid_ports(port_count, ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	MarketPricer.set_consumption_provider(TestCons.new())
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	BuildingEconomy.set_population_provider(pop)
	BuildingEconomy.set_workforce_provider(wf)
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), BuildingEconomy.get_warehouse_capacity_provider()
	)


func _setup_core_pop_only(pop: TestPop) -> void:
	var perr: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(perr.size(), 0)
	var goods_dir := _build_valid_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_valid_ports(Params.get_int(PRM_PORT_COUNT_MIN), ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	MarketPricer.set_consumption_provider(TestCons.new())
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	BuildingEconomy.set_population_provider(pop)


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


func _write_layout() -> void:
	_write_zone(ROOT + "zones/", PORT_PT01, 1, 1, 4, 1)
	_write_zone(ROOT + "zones/", PORT_PT01, 2, 1, 4, 0)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 2)


func _write_defs_simple() -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, TYPE_KONTOR, "KONTOR", "", 0, 1.0, "", 0)
	_save_def(dir, TYPE_IND1, "IND1", "GD-001", 1, 1.0, "", 0)


func _write_defs_chain() -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, TYPE_KONTOR, "KONTOR", "", 0, 1.0, "", 0)
	_save_def(dir, TYPE_IND1, "IND1", "GD-001", 1, 5.0, "", 0)
	_save_def(dir, TYPE_IND2, "IND2", "GD-002", 2, 5.0, "GD-001", 1)
	_save_def(dir, TYPE_WH, "WAREHOUSE", "", 0, 1.0, "", 0)


func _write_defs_custom(
	type_id: String, out_g: String, tier: int, base_out: float, in_g: String, in_qty: int
) -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, TYPE_KONTOR, "KONTOR", "", 0, 1.0, "", 0)
	var bclass := "IND1" if tier <= 1 else "IND2"
	_save_def(dir, type_id, bclass, out_g, tier, base_out, in_g, in_qty)
	_save_def(dir, TYPE_WH, "WAREHOUSE", "", 0, 1.0, "", 0)


func _save_def(
	dir: String,
	type_id: String,
	build_class: String,
	out_g: String,
	tier: int,
	base_out: float,
	in_g: String,
	in_qty: int
) -> void:
	var d := BuildingDef.new()
	d.type = type_id
	d.build_class = build_class
	d.output_good_id = out_g
	d.tier = tier
	d.max_workers = 25
	d.base_output_per_worker = base_out
	d.input1_good_id = in_g
	d.input1_qty = in_qty
	ResourceSaver.save(d, dir + type_id + ".tres")


func _load_be() -> void:
	var errs: Array = BuildingEconomy.load_and_validate(
		ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/"
	)
	assert_eq(errs.size(), 0, str(errs))


func _seed_market_mats(qty: int) -> void:
	for g in ["GD-001", "GD-002", "GD-003"]:
		_seed_good_market(g, qty)


func _seed_good_market(good_id: String, qty: int) -> void:
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			GoodsLedger.make_market(PORT_PT01),
			StringName(good_id),
			qty,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)


func _seed_wh(good_id: String, qty: int) -> void:
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01),
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


func _first_kontor_slot() -> StringName:
	for s_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var s: Slot = s_variant
		if s.kind == Slot.Kind.KONTOR and s.building_id == &"":
			return s.slot_id
	return &""


func _first_belt_slot() -> StringName:
	for s_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var s: Slot = s_variant
		if BuildingEconomy.is_gathering_belt_slot(s.slot_id) and s.building_id == &"":
			return s.slot_id
	return &""


func _first_open_civil_owned() -> StringName:
	for s_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var s: Slot = s_variant
		if s.kind != Slot.Kind.CIVIL or not s.zone_open or s.building_id != &"":
			continue
		if s.land_owner != ACTOR:
			assert_gt(BuildingEconomy.buy_land(ACTOR, s.slot_id), 0)
		return s.slot_id
	return &""


func _write_zone(
	dir: String, port_id: String, zone: int, rings: int, slots: int, open_at_start: int
) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var z := ZoneDef.new()
	z.port_id = port_id
	z.zone = zone
	z.slot_share = 0.5
	z.rings = rings
	z.slots = slots
	z.open_at_start = open_at_start
	ResourceSaver.save(z, dir + "%s__%d.tres" % [port_id, zone])


func _write_city_center(dir: String, port_id: String, public_slots: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c := CityCenterDef.new()
	c.port_id = port_id
	c.public_slots = public_slots
	ResourceSaver.save(c, dir + port_id + ".tres")


func _wipe_dir(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		_wipe_abs(abs_path)


func _wipe_abs(abs_path: String) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		var child: String = abs_path.path_join(name)
		if dir.current_is_dir():
			_wipe_abs(child)
			DirAccess.remove_absolute(child)
		else:
			DirAccess.remove_absolute(child)
	dir.list_dir_end()


func _build_valid_goods(out_dir: String) -> String:
	_wipe_dir(out_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var need: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": "GD-001", "name": STAPLE_RICE, "build": false},
		{"id": "GD-002", "name": STAPLE_SALT, "build": false},
		{"id": "GD-003", "name": STAPLE_TIMBER, "build": true},
		{"id": "GD-004", "name": STAPLE_FISH, "build": false},
	]
	var n := 0
	for row in staples:
		n = n + 1
		ResourceSaver.save(
			_make_good(row["id"], row["name"], 1, true, row["build"], false, ANCHOR_LI),
			out_dir + "%s.tres" % row["id"]
		)
	while n < need:
		n = n + 1
		var gid: String = "GD-%03d" % n
		var tier: int = (n % (Params.get_int(PRM_FREE_PORT_TIER_MAX) + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(
			_make_good(gid, "填料%d" % n, tier, false, false, false, ANCHOR_LI),
			out_dir + "%s.tres" % gid
		)
	return out_dir


func _build_valid_ports(port_count: int, out_dir: String) -> String:
	_wipe_dir(out_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var free_count: int = _free_port_count(port_count)
	var good_ids: PackedStringArray = GoodCatalog.all_ids()
	for i in range(port_count):
		var pid: String = "PT-%02d" % (i + 1)
		var def := PortDef.new()
		def.port_id = pid
		def.name_zh = "港%d" % (i + 1)
		def.is_free_port = i < free_count
		def.role_cells = {}
		for g in good_ids:
			var cell := RoleCell.new()
			if i == 0:
				cell.role = PortRegistry.ROLE_PRODUCER
				cell.base_output_per_season = 1
			else:
				cell.role = PortRegistry.ROLE_TERMINAL
				cell.base_output_per_season = 0
			def.role_cells[g] = cell
		ResourceSaver.save(def, out_dir + "%s.tres" % pid)
	return out_dir


func _free_port_count(port_count: int) -> int:
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
