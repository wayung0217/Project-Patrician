extends GutTest
## WP-21 / TechSpec 14-04 PopulationModel + D-17b／D-18a extras.


const CsvImport := preload("res://tools/csv_import.gd")

const PARAMS_FIXTURE := "res://tests/fixtures/params_sys05_demo.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp21_pop/"
const PORT := "PT-01"
const ACTOR := &"ACT-PLAYER"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_TIMBER := "木材"
const STAPLE_FISH := "魚乾"


class TestSat extends SatisfactionInputProvider:
	var _v: Dictionary = {} ## "port|class" → float

	func set_input(port_id: String, clazz: String, v: float) -> void:
		_v["%s|%s" % [port_id, clazz]] = v

	func satisfaction_input(port_id: StringName, clazz: StringName) -> float:
		var key := "%s|%s" % [String(port_id), String(clazz)]
		if _v.has(key):
			return float(_v[key])
		return 0.5


class TestCons extends ConsumptionProvider:
	func weekly_consumption(_p: StringName, _g: StringName) -> int:
		return 100

	func consume_qty(_p: StringName, _g: StringName, _d: int) -> int:
		return 0


func before_each() -> void:
	_wipe(ROOT)
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	PopulationModel._ports = {}
	PopulationModel._workers = {}
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false


func test_WP21_14_04_1_missing_sat_provider_boot_error() -> void:
	Params.load_and_validate(PARAMS_FIXTURE)
	var errs: Array = PopulationModel.load_and_validate()
	assert_gt(errs.size(), 0)
	var found := false
	for e in errs:
		if String((e as Dictionary).get("code", "")) == String(
			PopulationModel.CODE_SAT_PROVIDER_MISSING
		):
			found = true
	assert_true(found)
	assert_false(PopulationModel.is_loaded())
	assert_push_error_count(errs.size())


func test_WP21_14_04_2_providers_inject_into_building_economy() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	_setup_be_layout()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0, 400, 500, 600)
	assert_eq(BuildingEconomy._population.population(StringName(PORT)), 160)
	PopulationModel.set_workers(&"BLD:X", 7)
	assert_eq(BuildingEconomy._workforce.workers(&"BLD:X"), 7)


func test_WP21_14_04_3_same_seed_same_result() -> void:
	var sat := TestSat.new()
	sat.set_input(PORT, "POOR", 0.6)
	sat.set_input(PORT, "CITIZEN", 0.8)
	sat.set_input(PORT, "RICH", 0.9)
	_boot_pop(sat)
	PopulationModel.set_master_seed(42)
	PopulationModel.set_port_state(PORT, 1010, 180, 10, 0, 300, 800, 900)
	var a1: int = PopulationModel.weighted_avg_sat(PORT)
	PopulationModel.daily_step(1)
	var snap1 := {
		"p": PopulationModel.population(StringName(PORT), &"POOR"),
		"c": PopulationModel.population(StringName(PORT), &"CITIZEN"),
		"r": PopulationModel.population(StringName(PORT), &"RICH"),
		"b": PopulationModel.beggars(StringName(PORT)),
		"sp": PopulationModel.satisfaction(StringName(PORT), &"POOR"),
	}
	before_each()
	_boot_pop(sat)
	PopulationModel.set_master_seed(42)
	PopulationModel.set_port_state(PORT, 1010, 180, 10, 0, 300, 800, 900)
	var a2: int = PopulationModel.weighted_avg_sat(PORT)
	PopulationModel.daily_step(1)
	assert_eq(a1, a2)
	assert_eq(a1, 380) # 7.8.1
	assert_eq(PopulationModel.population(StringName(PORT), &"POOR"), snap1["p"])
	assert_eq(PopulationModel.population(StringName(PORT), &"CITIZEN"), snap1["c"])
	assert_eq(PopulationModel.population(StringName(PORT), &"RICH"), snap1["r"])
	assert_eq(PopulationModel.beggars(StringName(PORT)), snap1["b"])
	assert_eq(PopulationModel.satisfaction(StringName(PORT), &"POOR"), snap1["sp"])


func test_TST_SYS07_01_weighted_avg_no_inflow() -> void:
	## 7.8.1: weighted avg 380 < SAT_IN_MIN 400 → no inflow.
	var sat := TestSat.new()
	_boot_pop(sat)
	PopulationModel.set_port_state(PORT, 1010, 180, 10, 0, 300, 800, 900)
	assert_eq(PopulationModel.weighted_avg_sat(PORT), 380)
	var b0: int = PopulationModel.beggars(StringName(PORT))
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.beggars(StringName(PORT)), b0)


func test_TST_SYS07_02_pf3_integer_flow_accum() -> void:
	## Long-run moved ≈ Σ base×rate ÷ (RATE_SCALE×DAYS) (OQ-13h); day-1 floor 0.
	var sat := TestSat.new()
	sat.set_input(PORT, "CITIZEN", 0.9)
	_boot_pop(sat)
	_setup_be_with_workshops(3)
	PopulationModel.set_port_state(PORT, 0, 180, 0, 0, 0, 900, 0)
	PopulationModel._ports[PORT].streak_up2 = 999
	# Force one active tier-3 workshop
	var ids: Array = []
	for b in BuildingEconomy.workplaces(StringName(PORT)):
		var bid: StringName = (b as Building).building_id
		ids.append(bid)
		var def: BuildingDef = BuildingEconomy._building_defs[String((b as Building).type)]
		if def.tier == 3:
			PopulationModel.set_workers(bid, 1)
		else:
			PopulationModel.set_workers(bid, 0)
	var rich0: int = PopulationModel.population(StringName(PORT), &"RICH")
	PopulationModel.daily_step(1)
	# rate 5000 ppm/wk, denom 7e6 → day1 moved = floor(180*5000/7e6)=0
	assert_eq(PopulationModel.population(StringName(PORT), &"RICH"), rich0)
	assert_gt(int(PopulationModel._ports[PORT].acc.get("acc_up2", 0)), 0)


func test_TST_SYS07_03_sat_inertia_step() -> void:
	var sat := TestSat.new()
	sat.set_input(PORT, "CITIZEN", 0.55) # T≈550
	_boot_pop(sat)
	PopulationModel.set_port_state(PORT, 0, 100, 0, 0, 0, 750, 0)
	var step: int = Params.get_int("PRM-SYS07-SAT_MAX_STEP")
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.satisfaction(StringName(PORT), &"CITIZEN"), 750 - step)


func test_TST_SYS07_04_quantize_sat_input() -> void:
	var sat := TestSat.new()
	sat.set_input(PORT, "POOR", 0.5999999999)
	_boot_pop(sat)
	PopulationModel.set_port_state(PORT, 10, 0, 0, 0)
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.satisfaction(StringName(PORT), &"POOR"), 600)


func test_TST_SYS07_05_streak_resets() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	PopulationModel.set_port_state(PORT, 100, 0, 0, 0, 600, 0, 0)
	sat.set_input(PORT, "POOR", 0.6)
	PopulationModel.daily_step(1)
	assert_gt(PopulationModel._ports[PORT].streak_up1, 0)
	sat.set_input(PORT, "POOR", 0.3)
	for _i in range(50):
		PopulationModel.daily_step(_i + 2)
	assert_eq(PopulationModel._ports[PORT].streak_up1, 0)


func test_TST_SYS07_06_tier2_needs_active_workers() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	_setup_be_with_workshops(2)
	PopulationModel.set_port_state(PORT, 100, 0, 0, 0, 700, 0, 0)
	PopulationModel._ports[PORT].streak_up1 = 999
	var ids: Array = []
	for b in BuildingEconomy.workplaces(StringName(PORT)):
		ids.append((b as Building).building_id)
	assert_gte(ids.size(), 2)
	PopulationModel.set_workers(ids[0], 0)
	PopulationModel.set_workers(ids[1], 0)
	var poor0: int = PopulationModel.population(StringName(PORT), &"POOR")
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.population(StringName(PORT), &"POOR"), poor0)


func test_TST_SYS07_07_hire_largest_remainder() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	_setup_be_with_workshops(2)
	PopulationModel.set_port_state(PORT, 0, 0, 0, 10, 500, 500, 500)
	var ids: Array = []
	for b in BuildingEconomy.workplaces(StringName(PORT)):
		var bid: StringName = (b as Building).building_id
		ids.append(bid)
		PopulationModel.set_workers(bid, 0)
		var def: BuildingDef = BuildingEconomy._building_defs[String((b as Building).type)]
		def.max_workers = 20
	PopulationModel.daily_step(1)
	var w0: int = PopulationModel.workers(ids[0])
	var w1: int = PopulationModel.workers(ids[1])
	assert_eq(w0 + w1, 2)
	assert_eq(w0, 1)
	assert_eq(w1, 1)
	assert_eq(PopulationModel.beggars(StringName(PORT)), 2) # 10-8


func test_TST_SYS07_08_demolish_releases_workers_next_tick() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	_setup_be_with_workshops(2)
	var ids: Array = []
	for b in BuildingEconomy.workplaces(StringName(PORT)):
		ids.append((b as Building).building_id)
	assert_gte(ids.size(), 2)
	var bid: StringName = ids[0]
	PopulationModel.set_workers(bid, 25)
	PopulationModel.set_workers(ids[1], 0)
	# Block re-hire so release stays visible.
	var def_b: BuildingDef = BuildingEconomy._building_defs[
		String((BuildingEconomy.get_building(ids[1]) as Building).type)
	]
	def_b.max_workers = 0
	PopulationModel.set_port_state(PORT, 100, 0, 0, 0, 500, 500, 500)
	var total0: int = PopulationModel.population(StringName(PORT))
	assert_eq(BuildingEconomy.demolish(ACTOR, bid), 1)
	assert_eq(PopulationModel.workers(bid), 0)
	# Same-day pop unchanged until daily_step applies release.
	assert_eq(PopulationModel.population(StringName(PORT), &"POOR"), 100)
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.population(StringName(PORT), &"POOR"), 0)
	assert_eq(PopulationModel.beggars(StringName(PORT)), 100)
	assert_eq(PopulationModel.population(StringName(PORT)), total0)


func test_TST_SYS07_09_outflow_beggars_first() -> void:
	var sat := TestSat.new()
	sat.set_input(PORT, "POOR", 0.1)
	_boot_pop(sat)
	# Speed PF-6 so day-1 floor moves ≥1 (FRM-11).
	Params._values["PRM-SYS07-PF6_BEGGAR_RATE_WK"] = 1000000
	Params._values["PRM-SYS07-PF6_RATE_WK"] = 100000
	PopulationModel.set_port_state(PORT, 40, 0, 0, 100, 100, 0, 0)
	var poor0: int = PopulationModel.population(StringName(PORT), &"POOR")
	PopulationModel.daily_step(1)
	assert_lt(PopulationModel.beggars(StringName(PORT)), 100)
	assert_eq(PopulationModel.population(StringName(PORT), &"POOR"), poor0)


func test_TST_SYS07_10_housing_overflow_gradual() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	Params._values["PRM-SYS07-PF6_RATE_WK"] = 1000000
	# No residences → beds=0; 200 residents overflow via PF-6, not instant wipe.
	PopulationModel.set_port_state(PORT, 200, 0, 0, 0, 500, 0, 0)
	PopulationModel.daily_step(1)
	var poor1: int = PopulationModel.population(StringName(PORT), &"POOR")
	assert_gt(poor1, 0)
	assert_lt(poor1, 200)


func test_TST_SYS07_11_port_iteration_order_independent() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	PopulationModel.set_master_seed(7)
	PopulationModel.set_port_state("PT-02", 50, 0, 0, 0, 500, 0, 0)
	PopulationModel.set_port_state("PT-01", 50, 0, 0, 0, 500, 0, 0)
	PopulationModel.daily_step(3)
	var snap := {
		"a": PopulationModel.population(StringName("PT-01"), &"POOR"),
		"b": PopulationModel.population(StringName("PT-02"), &"POOR"),
	}
	before_each()
	_boot_pop(sat)
	PopulationModel.set_master_seed(7)
	PopulationModel.set_port_state("PT-01", 50, 0, 0, 0, 500, 0, 0)
	PopulationModel.set_port_state("PT-02", 50, 0, 0, 0, 500, 0, 0)
	PopulationModel.daily_step(3)
	assert_eq(PopulationModel.population(StringName("PT-01"), &"POOR"), snap["a"])
	assert_eq(PopulationModel.population(StringName("PT-02"), &"POOR"), snap["b"])


func test_TST_SYS07_12_same_seed_placement_replay() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	_setup_be_with_workshops(2)
	PopulationModel.set_master_seed(99)
	PopulationModel.set_port_state(PORT, 30, 10, 0, 0, 500, 500, 500)
	PopulationModel.daily_step(5)
	var r1: Dictionary = PopulationModel._residents.duplicate(true)
	before_each()
	_boot_pop(sat)
	_setup_be_with_workshops(2)
	PopulationModel.set_master_seed(99)
	PopulationModel.set_port_state(PORT, 30, 10, 0, 0, 500, 500, 500)
	PopulationModel.daily_step(5)
	assert_eq(PopulationModel._residents.hash(), r1.hash())


func test_TST_SYS07_13_boot_param_errors() -> void:
	var sat := TestSat.new()
	Params.load_and_validate(PARAMS_FIXTURE)
	PopulationModel.set_satisfaction_input_provider(sat)
	Params._values.erase("PRM-SYS07-SAT_MAX_STEP")
	Params._values["PRM-SYS07-SAT_OUT_MAX"] = 900 # break OUT < DOWN
	Params._values["PRM-SYS07-LAMBDA_RING"] = 0.0
	var errs: Array = PopulationModel.load_and_validate()
	assert_gt(errs.size(), 0)
	var codes: Array = []
	for e in errs:
		codes.append(String((e as Dictionary).get("code", "")))
	assert_true(codes.has(String(PopulationModel.ERR_SYS07_06)))
	assert_true(codes.has(String(PopulationModel.ERR_SYS07_02)))
	assert_true(codes.has(String(PopulationModel.ERR_SYS07_05)))
	assert_push_error_count(errs.size())


func test_TST_SYS07_14_hire_sailors_all_or_nothing() -> void:
	var sat := TestSat.new()
	_boot_pop(sat)
	PopulationModel.set_port_state(PORT, 0, 0, 0, 3)
	assert_eq(PopulationModel.hire_sailors(StringName(PORT), 5), 0)
	assert_eq(String(PopulationModel.last_error().get("code", "")), String(PopulationModel.ERR_SYS07_07))
	assert_eq(PopulationModel.beggars(StringName(PORT)), 3)
	assert_push_error_count(1)


func test_WP21_D17b_acquire_materials_public() -> void:
	## D-17b: public acquire_materials; existing WP-19 names unchanged.
	var sat := TestSat.new()
	_boot_pop(sat)
	_setup_be_layout()
	assert_true(BuildingEconomy.has_method("acquire_materials"))
	var result: Dictionary = BuildingEconomy.acquire_materials(
		ACTOR, StringName(PORT), {"GD-001": 5}
	)
	assert_true(result.has("acquired"))
	assert_true(result.has("missing"))


func test_WP21_D18a_buildings_float_qty_import() -> void:
	## D-18a: input1_qty 1.5 loads as float.
	var result: Dictionary = CsvImport.run_batch_wp17(
		"res://tests/fixtures/wp21_d18a_recipe/",
		"res://tests/fixtures/wp21_out_d18a/zones/",
		"res://tests/fixtures/wp21_out_d18a/buildings/",
		"res://tests/fixtures/wp21_out_d18a/opening/",
		"res://tests/fixtures/wp21_out_d18a/build_queue/"
	)
	assert_true(result["ok"], str(result.get("errors", [])))
	var b: BuildingDef = load("res://tests/fixtures/wp21_out_d18a/buildings/WS-CHARCOAL.tres")
	assert_not_null(b)
	assert_eq(b.input1_qty, 1.5)


func test_WP21_D18a_negative_qty_rejected() -> void:
	var result: Dictionary = CsvImport.run_batch_wp17(
		"res://tests/fixtures/wp21_bad_qty_neg/",
		"res://tests/fixtures/wp21_out_bad/zones/",
		"res://tests/fixtures/wp21_out_bad/buildings/",
		"res://tests/fixtures/wp21_out_bad/opening/",
		"res://tests/fixtures/wp21_out_bad/build_queue/"
	)
	assert_false(result["ok"])
	var errors: PackedStringArray = result["errors"]
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())


# --- helpers ---


func _boot_pop(sat: SatisfactionInputProvider) -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	PopulationModel.set_satisfaction_input_provider(sat)
	assert_eq(PopulationModel.load_and_validate().size(), 0)
	PopulationModel.set_master_seed(1)


func _setup_be_layout() -> void:
	BuildingEconomy.set_population_provider(PopulationModel.get_population_provider())
	BuildingEconomy.set_workforce_provider(PopulationModel.get_workforce_provider())
	_setup_core_ledgers()
	_write_min_layout()
	_save_def(ROOT + "buildings/", "KT-01", "KONTOR", "", 0, 1.0)
	_save_def(ROOT + "buildings/", "RB-01", "RESIDENCE", "", 0, 1.0)
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)


func _setup_be_with_workshops(tier_max: int = 2) -> void:
	BuildingEconomy.set_population_provider(PopulationModel.get_population_provider())
	BuildingEconomy.set_workforce_provider(PopulationModel.get_workforce_provider())
	_setup_core_ledgers()
	_write_min_layout()
	var dir := ROOT + "buildings/"
	_save_def(dir, "KT-01", "KONTOR", "", 0, 1.0)
	_save_def(dir, "IB-A", "IND2", "GD-001", 2, 1.0)
	_save_def(dir, "IB-B", "IND2", "GD-001", 2, 1.0)
	if tier_max >= 3:
		_save_def(dir, "IB-C", "IND3", "GD-002", 3, 1.0)
	_save_def(dir, "RB-01", "RESIDENCE", "", 0, 1.0)
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)
	_force_workshop("IB-A", "IND2")
	_force_workshop("IB-B", "IND2")
	if tier_max >= 3:
		_force_workshop("IB-C", "IND3")
	_force_residences(20)


func _setup_core_ledgers() -> void:
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
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), BuildingEconomy.get_warehouse_capacity_provider()
	)


func _force_workshop(type_id: String, bclass: String) -> void:
	var bld := Building.new()
	bld.building_id = StringName("BLD:%s:%s" % [PORT, type_id])
	bld.type = StringName(type_id)
	bld.build_class = StringName(bclass)
	bld.owner = ACTOR
	bld.port_id = PORT
	bld.state = Building.State.ACTIVE
	BuildingEconomy._register_building(bld)


func _force_residences(n: int) -> void:
	for i in range(n):
		var bld := Building.new()
		bld.building_id = StringName("BLD:%s:RES%d" % [PORT, i])
		bld.type = &"RB-01"
		bld.build_class = &"RESIDENCE"
		bld.owner = ACTOR
		bld.port_id = PORT
		bld.state = Building.State.ACTIVE
		bld.slot_id = StringName("SLOT:%s:%04d" % [PORT, i + 10])
		BuildingEconomy._register_building(bld)


func _write_min_layout() -> void:
	_write_zone(ROOT + "zones/", PORT, 1, 1, 8, 1)
	_write_zone(ROOT + "zones/", PORT, 2, 1, 4, 0)
	_write_city(ROOT + "city_center/", PORT, 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "buildings/"))


func _save_def(dir: String, type_id: String, bclass: String, out_g: String, tier: int, base: float) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var d := BuildingDef.new()
	d.type = type_id
	d.build_class = bclass
	d.output_good_id = out_g
	d.tier = tier
	d.max_workers = 4
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
			_make_good(s["id"], s["name"], 1, true, s["build"], false),
			dir + "%s.tres" % s["id"]
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(_make_good(gid, gid, tier, false, false, false), dir + "%s.tres" % gid)
		written += 1
		next_n += 1
	return dir


func _make_good(
	id: String, name_zh: String, tier: int, is_staple: bool, is_build: bool, is_strategic: bool
) -> GoodDef:
	var g := GoodDef.new()
	g.good_id = id
	g.name_zh = name_zh
	g.tier = tier
	g.is_staple = is_staple
	g.is_build_material = is_build
	g.is_strategic = is_strategic
	g.base_price_li = 10
	g.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
	return g


func _build_valid_ports(port_count: int, dir: String) -> String:
	_wipe(dir)
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
	for c in range(port_count + 1):
		var ratio: float = float(c) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return c
	return int(ceil(float(port_count) * ratio_min))


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
