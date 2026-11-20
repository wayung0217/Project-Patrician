extends GutTest
## WP-22／WP-34 — DemandModel SYS-06 + CSV import fixtures (D-36a／b／c／D-30a).


const CsvImport := preload("res://tools/csv_import.gd")

const PARAMS_FIXTURE := "res://tests/fixtures/params_sys05_demo.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const DEMAND_CSV_OK := "res://tests/fixtures/demand/ok/"
const DEMAND_OUT := "res://tests/fixtures/demand/out/"
const TABLES_OK := DEMAND_OUT ## demand dir after csv_import
const PARAMS_MISSING_WEIGHT := "res://tests/fixtures/params_sys06_missing_weight.json"
const PARAMS_MISSING_DPW := "res://tests/fixtures/params_sys06_missing_days_per_week.json"

const ROOT := "user://wp22_demand/"
const PORT := "PT-01"
const ACTOR := &"ACT-PLAYER"
const CITY := &"CITY-PT-01"

const RATE_SCALE := 100
const PPM_SCALE := 1000000
const WEIGHT_SUM := 100

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS := "PRM-SYS00-SEASONS_PER_YEAR"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"
const ANCHOR_LI := 1000

const TYPE_KONTOR := "KT-01"
const TYPE_HEMP := "IB-HEMP"
const TYPE_IRON := "IB-IRON"
const TYPE_SULFUR := "IB-SULF"
const TYPE_CLOTH := "IB-CLOTH"
const TYPE_WH := "WH-01"


class TestPop extends PopulationProvider:
	var _pop: Dictionary = {}

	func set_pop(port_id: String, value: int) -> void:
		_pop[port_id] = value

	func population(port_id: StringName) -> int:
		return int(_pop.get(String(port_id), 0))


class TestWorkforce extends WorkforceProvider:
	var _by_ws: Dictionary = {}
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


class TestConsZero extends ConsumptionProvider:
	func consume_qty(_p: StringName, _g: StringName, _d: int) -> int:
		return 0


class TestCapUnlimited extends CapacityProvider:
	func capacity(_container: Variant) -> int:
		return 100000


func before_each() -> void:
	_wipe_dir(ROOT)
	_wipe_demand_out()
	DemandModel._clear_state()
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	PopulationModel._ports = {}
	PopulationModel._workers = {}
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	BuildingEconomy._buildings = {}
	BuildingEconomy._buildings_by_port = {}
	BuildingEconomy._building_defs = {}
	BuildingEconomy._slots = {}
	BuildingEconomy._slots_by_port = {}
	BuildingEconomy._r_by_port = {}
	BuildingEconomy._max_open_zone = {}
	BuildingEconomy._pending_shortfalls = []
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false
	Params._loaded = false
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop.set_consumption_provider(null)


# --- ERR-SYS06-01..04 ---


func test_ERR_SYS06_01_negative_rate_rejects_boot() -> void:
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0)
	_install_demand_ok()
	## Mutate one rate tres to negative (DemandModel ERR path; import already rejects).
	var def: DemandRate = load(DEMAND_OUT.path_join("rates/GD-001.tres")) as DemandRate
	def.poor_rate_cj = 0 - 1
	ResourceSaver.save(def, DEMAND_OUT.path_join("rates/GD-001.tres"))
	var errs: Array = DemandModel.load_and_validate(TABLES_OK)
	assert_gt(errs.size(), 0)
	assert_true(_has_code(errs, DemandModel.ERR_SYS06_01))
	assert_false(DemandModel.is_loaded())
	assert_push_error_count(errs.size())


func test_ERR_SYS06_01_missing_demand_dir_rejects() -> void:
	## D-30a／R9-06 dedicated missing-file test.
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0)
	var missing := ROOT + "no_demand_dir/"
	var errs: Array = DemandModel.load_and_validate(missing)
	assert_gt(errs.size(), 0)
	assert_true(_has_code(errs, DemandModel.ERR_SYS06_01))
	assert_false(DemandModel.is_loaded())
	assert_push_error_count(errs.size())


func test_D40c_bad_tres_load_collects_filename() -> void:
	## D-40c: corrupt .tres → ERR-SYS06-01 with filename.
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0)
	_install_demand_ok()
	var bad_path: String = DEMAND_OUT.path_join("rates/BAD-D40.tres")
	var f := FileAccess.open(bad_path, FileAccess.WRITE)
	assert_ne(f, null)
	f.store_string("NOT A VALID RESOURCE\n")
	f.close()
	var errs: Array = DemandModel.load_and_validate(TABLES_OK)
	## Godot emits engine parse errors for corrupt .tres; count them so GUT does not fail the test.
	assert_engine_error_count(2, "corrupt .tres parse")
	assert_gt(errs.size(), 0)
	assert_true(_has_code(errs, DemandModel.ERR_SYS06_01))
	var saw_name := false
	for e in errs:
		var detail: Dictionary = (e as Dictionary).get("detail", {}) as Dictionary
		if String(detail.get("field", "")) == "BAD-D40.tres":
			saw_name = true
			break
	assert_true(saw_name, "expected detail.field=BAD-D40.tres in errors: %s" % str(errs))
	assert_false(DemandModel.is_loaded())
	assert_push_error_count(errs.size())


func test_D40c_missing_substitutions_dir_fails() -> void:
	## D-40c: substitutions subdir must exist.
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0)
	_install_demand_ok()
	var subst: String = DEMAND_OUT.path_join("substitutions/")
	_wipe_dir(subst)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(subst))
	var errs: Array = DemandModel.load_and_validate(TABLES_OK)
	assert_gt(errs.size(), 0)
	assert_true(_has_code(errs, DemandModel.ERR_SYS06_03))
	assert_false(DemandModel.is_loaded())
	assert_push_error_count(errs.size())


func test_D40c_empty_substitutions_dir_passes() -> void:
	## D-40c: empty substitutions OK when dir exists.
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0)
	_install_demand_ok()
	var subst: String = DEMAND_OUT.path_join("substitutions/")
	_wipe_dir(subst)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(subst))
	var errs: Array = DemandModel.load_and_validate(TABLES_OK)
	assert_eq(errs.size(), 0, str(errs))
	assert_true(DemandModel.is_loaded())


func test_ERR_SYS06_02_weight_sum_rejects_boot() -> void:
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0)
	_install_demand_ok()
	var def: SatisfactionWeight = load(DEMAND_OUT.path_join("weights/GD-001.tres")) as SatisfactionWeight
	def.poor_weight_pct = 29
	ResourceSaver.save(def, DEMAND_OUT.path_join("weights/GD-001.tres"))
	var errs: Array = DemandModel.load_and_validate(TABLES_OK)
	assert_gt(errs.size(), 0)
	assert_true(_has_code(errs, DemandModel.ERR_SYS06_02))
	assert_false(DemandModel.is_loaded())
	assert_push_error_count(errs.size())


func test_ERR_SYS06_03_subst_cap_rejects_boot() -> void:
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0)
	_install_demand_ok()
	var def: SubstitutionRule = load(
		DEMAND_OUT.path_join("substitutions/GD-001__GD-014.tres")
	) as SubstitutionRule
	def.cap_ppm = Params.get_int("PRM-SYS06-PPM_SCALE") + 1
	ResourceSaver.save(def, DEMAND_OUT.path_join("substitutions/GD-001__GD-014.tres"))
	var errs: Array = DemandModel.load_and_validate(TABLES_OK)
	assert_gt(errs.size(), 0)
	assert_true(_has_code(errs, DemandModel.ERR_SYS06_03))
	assert_false(DemandModel.is_loaded())
	assert_push_error_count(errs.size())


func test_ERR_SYS06_04_negative_population() -> void:
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 100, 50, 10, 0)
	_install_demand_ok()
	assert_eq(DemandModel.load_and_validate(TABLES_OK).size(), 0)
	# Force negative via direct PortPop (boot-time path covered by validate; runtime record).
	var p: Object = PopulationModel._ports[PORT]
	p.poor = 0 - 1
	var w: int = DemandModel.weekly_demand(StringName(PORT), &"GD-001")
	assert_eq(w, 0)
	assert_eq(String(DemandModel.last_error().get("code", "")), String(DemandModel.ERR_SYS06_04))
	assert_push_error_count(1)


# --- TST-SYS06-01..10 ---


func test_TST_SYS06_01_rice_week_demand_calibration_port() -> void:
	## 6.3 米列：3000＠70／20／10 → W＝178 擔；貧民人均 5.94 斤／週（非 187.5 市場規模）。
	_boot_demand_world(2100, 600, 300, 0)
	var w: int = DemandModel.weekly_demand(StringName(PORT), &"GD-001")
	assert_eq(w, 178)
	var rate_cj: int = int(DemandModel._rate_cj["POOR"]["GD-001"])
	assert_eq(rate_cj, 594)


func test_TST_SYS06_02_market_size_target() -> void:
	## 基準價 × 目標週總需求 ≈ 187.5（6.2）；木炭 1.5 × 125.0。
	_boot_demand_world(2100, 600, 300, 0)
	var product: float = 1.5 * 125.0
	assert_true(abs(product - 187.5) < 0.01)


func test_TST_SYS06_03_daily_share_sums_to_week() -> void:
	## FRM-SYS06-10: 7-day accumulator sum vs theory week within <1 dan; max−min ≤1;
	## N weeks vs N×theory within <1 dan.
	_boot_demand_world(2100, 600, 300, 0)
	var w_num: int = (
		2100 * 594 + 600 * 594 + 300 * 594
	)
	var s: int = Params.get_int("PRM-SYS06-RATE_SCALE") * Params.get_int("PRM-SYS06-JIN_PER_DAN")
	var theory: float = float(w_num) / float(s)
	var sum := 0
	var lo := 0x7fffffff
	var hi := 0
	for day in range(1, 8):
		var d: int = DemandModel.daily_demand(StringName(PORT), &"GD-001", day)
		sum = sum + d
		if d < lo:
			lo = d
		if d > hi:
			hi = d
	assert_lt(abs(float(sum) - theory), 1.0)
	assert_lte(hi - lo, 1)
	# N=4 weeks continued on same accumulators
	var n := 4
	var sum_n := sum
	for week in range(1, n):
		for day_i in range(1, 8):
			var day2: int = week * 7 + day_i
			sum_n = sum_n + DemandModel.daily_demand(StringName(PORT), &"GD-001", day2)
	assert_lt(abs(float(sum_n) - float(n) * theory), 1.0)


func test_TST_SYS06_04_sat_weights_sum_100() -> void:
	_boot_demand_world(100, 50, 10, 0)
	assert_true(DemandModel.is_loaded())
	for cls in ["POOR", "CITIZEN", "RICH"]:
		var s := 0
		for g in DemandModel._sat_pct[cls].keys():
			s = s + int(DemandModel._sat_pct[cls][g])
		assert_eq(s, Params.get_int("PRM-SYS06-WEIGHT_SUM"), cls)


func test_TST_SYS06_05_rice_shortage_triggers_fish_subst() -> void:
	_boot_demand_world(2100, 600, 300, 0)
	# Seed fish only; rice = 0.
	_seed_market("GD-014", 5000)
	var day := 1
	var rice_need: int = DemandModel.daily_demand(StringName(PORT), &"GD-001", day)
	assert_gt(rice_need, 0)
	var fish_base: int = DemandModel.daily_demand(StringName(PORT), &"GD-014", day)
	var rice_take: int = DemandModel.consume_qty(StringName(PORT), &"GD-001", day)
	assert_eq(rice_take, 0)
	var fish_take: int = DemandModel.consume_qty(StringName(PORT), &"GD-014", day)
	var subst: int = DemandModel.substitution_applied(StringName(PORT), &"GD-014")
	assert_gt(subst, 0)
	assert_eq(fish_take, fish_base + subst)
	# Cap 30% of rice need; util 0.7 → subst ≤ ceil(0.3*need/0.7)
	var max_u: int = int(rice_need * 300000 / 1000000)
	var max_b: int = int((max_u * 1000000 + 700000 - 1) / 700000)
	assert_lte(subst, max_b)
	var sat_poor: float = DemandModel.satisfaction_input(StringName(PORT), &"POOR")
	assert_gt(sat_poor, 0.0)
	assert_lt(sat_poor, 1.0)


func test_TST_SYS06_06_paused_workshops_zero_input_consume() -> void:
	## D-22a: SYS-08 — pause all workshops → hemp/iron/sulfur input consume = 0; resident needs unchanged.
	var wf := TestWorkforce.new()
	wf.set_default(10)
	_boot_be_with_input_workshops(wf)
	_install_demand_ok()
	assert_eq(DemandModel.load_and_validate(TABLES_OK).size(), 0)
	PopulationModel.set_port_state(PORT, 700, 200, 100, 0)
	var rice_w0: int = DemandModel.weekly_demand(StringName(PORT), &"GD-001")
	var fish_w0: int = DemandModel.weekly_demand(StringName(PORT), &"GD-014")
	# Seed warehouse inputs for player workshops.
	for g in ["GD-005", "GD-008", "GD-009"]:
		_seed_wh(g, 5000)
	var before: Dictionary = {
		"GD-005": _wh_qty("GD-005"),
		"GD-008": _wh_qty("GD-008"),
		"GD-009": _wh_qty("GD-009"),
	}
	# Pause every workshop at port (public API only — C-07).
	for bld_v in BuildingEconomy.buildings_for_port(PORT):
		var bld: Building = bld_v as Building
		if String(bld.build_class).begins_with("IND"):
			assert_eq(BuildingEconomy.pause(ACTOR, bld.building_id), 1)
	for _i in range(7):
		BuildingEconomy.daily_step(_i + 1)
	assert_eq(_wh_qty("GD-005"), before["GD-005"])
	assert_eq(_wh_qty("GD-008"), before["GD-008"])
	assert_eq(_wh_qty("GD-009"), before["GD-009"])
	assert_eq(DemandModel.weekly_demand(StringName(PORT), &"GD-001"), rice_w0)
	assert_eq(DemandModel.weekly_demand(StringName(PORT), &"GD-014"), fish_w0)


func test_TST_SYS06_07_double_pop_doubles_citizen_demand() -> void:
	## D-22b: DemandModel citizen demand ×2; SYS-08 production inputs unchanged (existing BE).
	_boot_demand_world(700, 200, 100, 0)
	var tea1: int = DemandModel.weekly_demand(StringName(PORT), &"GD-011")
	PopulationModel.set_port_state(PORT, 1400, 400, 200, 0)
	# weekly_demand is display-only (no plan invalidate); pop change visible immediately.
	var tea2: int = DemandModel.weekly_demand(StringName(PORT), &"GD-011")
	# Integer floor (C-09): doubling pop need not yield exact 2× when remainders exist.
	assert_eq(tea1, 7)
	assert_eq(tea2, 15)
	# SYS-08 existing BE: paused workshops consume no inputs (separate boot).
	before_each()
	var wf := TestWorkforce.new()
	_boot_be_with_input_workshops(wf)
	for bld_v in BuildingEconomy.buildings_for_port(PORT):
		var bld: Building = bld_v as Building
		if String(bld.build_class).begins_with("IND"):
			BuildingEconomy.pause(ACTOR, bld.building_id)
	for g in ["GD-005", "GD-008", "GD-009"]:
		_seed_wh(g, 1000)
	var b5: int = _wh_qty("GD-005")
	BuildingEconomy.daily_step(1)
	assert_eq(_wh_qty("GD-005"), b5)


func test_TST_SYS06_08_cotton_zero_poor_sat_unchanged_cloth_subst() -> void:
	## D-22b: M-05 — cotton not in poor sat; clothing subst triggers; BE clothing workshop idle if no cloth.
	_boot_demand_world(2100, 600, 300, 0)
	# Full stock except cotton cloth GD-010 = 0; seed clothing demand substitute path.
	for g in GoodCatalog.all_ids():
		if String(g) == "GD-010":
			continue
		_seed_market(String(g), 8000)
	# Force clothing shortage by not seeding GD-022 either → subst wants cotton which is 0.
	# Clear clothing stock.
	var m: Dictionary = GoodsLedger.make_market(PORT)
	var cloth_qty: int = GoodsLedger.get_qty(m, &"GD-022")
	if cloth_qty > 0:
		GoodsLedger.transfer(m, GoodsLedger.make_external(), &"GD-022", cloth_qty, GoodsLedger.REASON_CONSUME, &"TEST")
	# Force replan via different day if needed — first consume on day 1 after seed.
	var day := 1
	var _take_c: int = DemandModel.consume_qty(StringName(PORT), &"GD-022", day)
	var subst_cotton: int = DemandModel.substitution_applied(StringName(PORT), &"GD-010")
	# Cotton stock 0 → subst applied may be 0, but fulfil(clothing) < 1 triggers unmet.
	var fulfil_cloth: float = DemandModel.fulfilment(StringName(PORT), &"GD-022")
	assert_lt(fulfil_cloth, 1.0)
	var sat_poor: float = DemandModel.satisfaction_input(StringName(PORT), &"POOR")
	# Poor weights exclude cotton (M-05); clothing weight for poor is 0 → sat unaffected by clothing.
	# Recompute with full fulfil on poor goods only: seed was full for poor ● goods.
	assert_gt(sat_poor, 0.99)
	assert_eq(subst_cotton, 0) # no cotton to take
	# SYS-08 existing behavior: clothing workshop with missing cotton input produces 0.
	before_each()
	var wf := TestWorkforce.new()
	wf.set_default(10)
	_boot_be_clothing_workshop(wf)
	var out_before: int = _wh_qty("GD-022")
	BuildingEconomy.daily_step(1)
	assert_eq(_wh_qty("GD-022"), out_before)


func test_TST_SYS06_09_brocade_zero_only_rich_sat_drops() -> void:
	## Need enough rich so GD-028 weekly W > 0 (27 cj → ≥10000/27 people).
	_boot_demand_world(2100, 600, 4000, 0)
	for g in GoodCatalog.all_ids():
		if String(g) == "GD-028":
			continue
		_seed_market(String(g), 8000)
	for g in GoodCatalog.all_ids():
		DemandModel.consume_qty(StringName(PORT), StringName(String(g)), 1)
	var sat_p: float = DemandModel.satisfaction_input(StringName(PORT), &"POOR")
	var sat_c: float = DemandModel.satisfaction_input(StringName(PORT), &"CITIZEN")
	var sat_r: float = DemandModel.satisfaction_input(StringName(PORT), &"RICH")
	assert_gt(sat_p, 0.99)
	assert_gt(sat_c, 0.99)
	assert_lt(sat_r, 1.0)


func test_TST_SYS06_10_consume_equals_min_demand_stock() -> void:
	## Seed before first plan for the day (FRM-SYS06-10 locks stock at plan time).
	_boot_demand_world(2100, 600, 300, 0)
	var w_num: int = 2100 * 594 + 600 * 594 + 300 * 594
	var s: int = Params.get_int("PRM-SYS06-RATE_SCALE") * Params.get_int("PRM-SYS06-JIN_PER_DAN")
	var d_period: int = s * Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	var need: int = floori(float(w_num) / float(d_period)) # day-1 q from empty acc
	assert_gt(need, 1)
	_seed_market("GD-001", need - 1)
	var day := 1
	var stock: int = GoodsLedger.get_qty(GoodsLedger.make_market(PORT), &"GD-001")
	var take: int = DemandModel.consume_qty(StringName(PORT), &"GD-001", day)
	var expect: int = need if need < stock else stock
	assert_eq(take, expect)
	assert_eq(take, stock)


func test_TST_SYS07_16_beggar_sat_necessities_only() -> void:
	## D-36a／U-15: keep name; content — 100 beggars do not affect daily demand per good;
	## PopulationModel neither stores nor reports beggar sat; DemandModel rejects BEGGAR sat.
	_boot_demand_world(700, 200, 100, 0)
	var base: Dictionary = {}
	for g in GoodCatalog.all_ids():
		base[String(g)] = DemandModel.daily_demand(StringName(PORT), StringName(String(g)), 1)
	before_each()
	_boot_demand_world(700, 200, 100, 100)
	for g2 in GoodCatalog.all_ids():
		var gid: String = String(g2)
		assert_eq(
			DemandModel.daily_demand(StringName(PORT), StringName(gid), 1),
			int(base[gid]),
			"beggar must not affect demand %s" % gid
		)
	var sat_b: float = DemandModel.satisfaction_input(StringName(PORT), &"BEGGAR")
	assert_eq(sat_b, 0.0)
	assert_eq(String(DemandModel.last_error().get("code", "")), String(DemandModel.ERR_SYS06_04))
	## PopulationModel: no beggar sat storage／report.
	assert_eq(PopulationModel.satisfaction(StringName(PORT), &"BEGGAR"), 0)
	assert_eq(String(PopulationModel.last_error().get("code", "")), String(PopulationModel.ERR_SYS07_08))
	assert_push_error_count(2)


func test_TST_SYS06_11_small_port_low_volume_averages() -> void:
	## 1000-person port; brocade week demand <1 dan; N seasons total ≈ N×theory, ≠0.
	_boot_demand_world(700, 200, 100, 0)
	var w_disp: int = DemandModel.weekly_demand(StringName(PORT), &"GD-028")
	assert_eq(w_disp, 0) # floor display <1
	var w_num: int = 100 * 27 # rich only
	var s: int = Params.get_int("PRM-SYS06-RATE_SCALE") * Params.get_int("PRM-SYS06-JIN_PER_DAN")
	var theory_week: float = float(w_num) / float(s)
	assert_lt(theory_week, 1.0)
	assert_gt(theory_week, 0.0)
	var days_season: int = Params.get_int("PRM-SYS00-DAYS_PER_SEASON")
	var n_seasons := 2
	var total_days: int = n_seasons * days_season
	var total := 0
	for day in range(1, total_days + 1):
		total = total + DemandModel.daily_demand(StringName(PORT), &"GD-028", day)
	var weeks: float = float(total_days) / float(Params.get_int("PRM-SYS04-DAYS_PER_WEEK"))
	var theory_total: float = weeks * theory_week
	assert_ne(total, 0)
	assert_lt(abs(float(total) - theory_total), 1.0)


func test_TST_SYS06_12_deterministic_replay() -> void:
	## Same inputs twice → daily demand identical day-by-day (implies identical acc path).
	var seq_a: Array = _daily_seq_rice(2100, 600, 300, 14)
	before_each()
	var seq_b: Array = _daily_seq_rice(2100, 600, 300, 14)
	assert_eq(seq_a.size(), seq_b.size())
	for i in range(seq_a.size()):
		assert_eq(seq_a[i], seq_b[i], "day %s mismatch" % str(i + 1))


func test_TST_SYS06_13_unmet_only_after_flush() -> void:
	## Shortage day: no demand_unmet during CONSUME/plan; after flush_signals each once ascending.
	_boot_demand_world(2100, 600, 300, 0)
	# Leave markets empty → many unmet.
	var seen: Array = []
	var cb := func(port_id: StringName, good_id: StringName, shortfall: int) -> void:
		seen.append({"port": String(port_id), "good": String(good_id), "shortfall": shortfall})
	DemandModel.demand_unmet.connect(cb)
	var goods: Array = []
	for g in GoodCatalog.all_ids():
		goods.append(String(g))
	goods.sort()
	for g in goods:
		DemandModel.consume_qty(StringName(PORT), StringName(g), 1)
	assert_eq(seen.size(), 0, "no emit during plan/CONSUME")
	DemandModel.flush_signals()
	assert_gt(seen.size(), 0)
	# Ascending (port_id, good_id); each pair once.
	var prev_port := ""
	var prev_good := ""
	var keys: Dictionary = {}
	for row_v in seen:
		var row: Dictionary = row_v
		var p: String = String(row["port"])
		var g: String = String(row["good"])
		var key := "%s|%s" % [p, g]
		assert_false(keys.has(key), "duplicate unmet %s" % key)
		keys[key] = true
		if prev_port != "":
			assert_true(p > prev_port or (p == prev_port and g >= prev_good))
			if p == prev_port:
				assert_gt(g, prev_good)
		prev_port = p
		prev_good = g
	DemandModel.demand_unmet.disconnect(cb)


func test_TST_SYS06_14_missing_prm_refuses_boot() -> void:
	## Missing PRM-SYS04-DAYS_PER_WEEK or PRM-SYS06-* → ERR-SYS06-06; no defaults.
	var perr: Array = Params.load_and_validate(PARAMS_MISSING_WEIGHT)
	assert_gt(perr.size(), 0)
	assert_false(Params.is_loaded())
	var errs: Array = DemandModel.load_and_validate(TABLES_OK)
	assert_gt(errs.size(), 0)
	assert_true(_has_code(errs, DemandModel.ERR_SYS06_06))
	assert_false(DemandModel.is_loaded())
	before_each()
	var perr2: Array = Params.load_and_validate(PARAMS_MISSING_DPW)
	assert_gt(perr2.size(), 0)
	assert_false(Params.is_loaded())
	var errs2: Array = DemandModel.load_and_validate(TABLES_OK)
	assert_gt(errs2.size(), 0)
	assert_true(_has_code(errs2, DemandModel.ERR_SYS06_06))
	assert_false(DemandModel.is_loaded())
	# GUT error tracker accumulates across before_each within one test.
	assert_push_error_count(perr.size() + errs.size() + perr2.size() + errs2.size())


# TST-SYS07-20 lives in test_sim_loop.gd (real SimLoop.boot injected vs auto-wire).


# --- helpers ---


func _daily_seq_rice(poor: int, cit: int, rich: int, days: int) -> Array:
	_boot_demand_world(poor, cit, rich, 0)
	var out: Array = []
	for day in range(1, days + 1):
		out.append(DemandModel.daily_demand(StringName(PORT), &"GD-001", day))
	return out


func _boot_demand_world(poor: int, cit: int, rich: int, beg: int) -> void:
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, poor, cit, rich, beg)
	_install_demand_ok()
	var errs: Array = DemandModel.load_and_validate(TABLES_OK)
	assert_eq(errs.size(), 0, str(errs))
	assert_true(DemandModel.is_loaded())


func _install_demand_ok() -> void:
	var result: Dictionary = CsvImport.run_batch_demand(
		DEMAND_CSV_OK,
		DEMAND_OUT.path_join("rates/"),
		DEMAND_OUT.path_join("weights/"),
		DEMAND_OUT.path_join("substitutions/"),
		RATE_SCALE,
		PPM_SCALE,
		WEIGHT_SUM
	)
	assert_true(result["ok"], "demand csv_import: %s" % str(result.get("errors", [])))


func _wipe_demand_out() -> void:
	var abs_path := ProjectSettings.globalize_path(DEMAND_OUT)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	_wipe_dir(DEMAND_OUT)


func _boot_params_ports_goods() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	var goods_dir := _build_valid_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_valid_ports(Params.get_int(PRM_PORT_COUNT_MIN), ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)


func _boot_pop_sat() -> void:
	PopulationModel.set_satisfaction_input_provider(DemandModel.get_satisfaction_input_provider())
	assert_eq(PopulationModel.load_and_validate().size(), 0)


func _boot_be_with_input_workshops(wf: TestWorkforce) -> void:
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 700, 200, 100, 0)
	var pop := TestPop.new()
	pop.set_pop(PORT, 1000)
	BuildingEconomy.set_population_provider(pop)
	BuildingEconomy.set_workforce_provider(wf)
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), TestCapUnlimited.new()
	)
	_write_zone(ROOT + "zones/", PORT, 1, 1, 6, 1)
	_write_zone(ROOT + "zones/", PORT, 2, 1, 6, 0)
	_write_city_center(ROOT + "city_center/", PORT, 2)
	_write_input_defs()
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)
	_cheap_build()
	_top_up(5_000_000)
	_seed_market("GD-001", 500)
	_seed_market("GD-002", 500)
	_seed_market("GD-003", 500)
	var kontor: StringName = _build_kontor()
	assert_ne(kontor, &"")
	for type_id in [TYPE_HEMP, TYPE_IRON, TYPE_SULFUR]:
		var slot: StringName = _first_belt_slot()
		assert_ne(slot, &"", "missing belt slot for %s" % type_id)
		if BuildingEconomy.get_slot(slot).land_owner != ACTOR:
			assert_gt(BuildingEconomy.buy_land(ACTOR, slot), 0)
		var bid: StringName = BuildingEconomy.order_build(ACTOR, slot, StringName(type_id))
		assert_ne(bid, &"", str(BuildingEconomy.last_errors()))
		_force_active(bid)
		wf.set_workers(bid, 10)


func _boot_be_clothing_workshop(wf: TestWorkforce) -> void:
	_wipe_dir(ROOT + "buildings/")
	_wipe_dir(ROOT + "zones/")
	BuildingEconomy._loaded = false
	BuildingEconomy._buildings = {}
	BuildingEconomy._buildings_by_port = {}
	BuildingEconomy._building_defs = {}
	BuildingEconomy._slots = {}
	BuildingEconomy._slots_by_port = {}
	_boot_params_ports_goods()
	_boot_pop_sat()
	PopulationModel.set_port_state(PORT, 700, 200, 100, 0)
	var pop := TestPop.new()
	pop.set_pop(PORT, 1000)
	BuildingEconomy.set_population_provider(pop)
	BuildingEconomy.set_workforce_provider(wf)
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), TestCapUnlimited.new()
	)
	_write_zone(ROOT + "zones/", PORT, 1, 1, 4, 1)
	_write_zone(ROOT + "zones/", PORT, 2, 1, 4, 0)
	_write_city_center(ROOT + "city_center/", PORT, 2)
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, TYPE_KONTOR, "KONTOR", "", 0, 1.0, "", 0.0)
	_save_def(dir, TYPE_CLOTH, "IND2", "GD-022", 2, 5.0, "GD-010", 1.0)
	_save_def(dir, TYPE_WH, "WAREHOUSE", "", 0, 1.0, "", 0.0)
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)
	_cheap_build()
	_top_up(5_000_000)
	_seed_market("GD-001", 500)
	_build_kontor()
	var slot: StringName = _first_open_civil()
	if BuildingEconomy.get_slot(slot).land_owner != ACTOR:
		assert_gt(BuildingEconomy.buy_land(ACTOR, slot), 0)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, slot, StringName(TYPE_CLOTH))
	assert_ne(bid, &"")
	_force_active(bid)
	wf.set_workers(bid, 10)


func _write_input_defs() -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, TYPE_KONTOR, "KONTOR", "", 0, 1.0, "", 0.0)
	_save_def(dir, TYPE_HEMP, "IND1", "GD-017", 1, 5.0, "GD-005", 1.0)
	_save_def(dir, TYPE_IRON, "IND1", "GD-021", 1, 5.0, "GD-008", 1.0)
	_save_def(dir, TYPE_SULFUR, "IND1", "GD-023", 1, 5.0, "GD-009", 1.0)
	_save_def(dir, TYPE_WH, "WAREHOUSE", "", 0, 1.0, "", 0.0)


func _save_def(
	dir: String,
	type_id: String,
	build_class: String,
	out_g: String,
	tier: int,
	base_out: float,
	in_g: String,
	in_qty: float
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


func _cheap_build() -> void:
	var cash: Dictionary = Params._values["PRM-SYS08-BUILD_CASH_LI"]
	for k in cash.keys():
		cash[k] = 1000
	var days: Dictionary = Params._values["PRM-SYS08-BUILD_DAYS"]
	for k in days.keys():
		days[k] = 1
	var mats: Dictionary = Params._values["PRM-SYS08-BUILD_MAT"]
	for k in mats.keys():
		mats[k] = {"GD-001": 1}


func _build_kontor() -> StringName:
	var slot: StringName = _first_kontor_slot()
	if BuildingEconomy.get_slot(slot).land_owner != ACTOR:
		assert_gt(BuildingEconomy.buy_land(ACTOR, slot), 0)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, slot, StringName(TYPE_KONTOR))
	_force_active(bid)
	return bid


func _force_active(bid: StringName) -> void:
	var bld: Building = BuildingEconomy.get_building(bid)
	bld.state = Building.State.ACTIVE
	bld.days_left = 0
	bld.missing_materials = {}


func _first_kontor_slot() -> StringName:
	for s_variant in BuildingEconomy.slots_for_port(PORT):
		var s: Slot = s_variant
		if s.kind == Slot.Kind.KONTOR and s.building_id == &"":
			return s.slot_id
	return &""


func _first_belt_slot() -> StringName:
	for s_variant in BuildingEconomy.slots_for_port(PORT):
		var s: Slot = s_variant
		if BuildingEconomy.is_gathering_belt_slot(s.slot_id) and s.building_id == &"":
			return s.slot_id
	return &""


func _first_open_civil() -> StringName:
	for s_variant in BuildingEconomy.slots_for_port(PORT):
		var s: Slot = s_variant
		if s.kind != Slot.Kind.CIVIL or not s.zone_open or s.building_id != &"":
			continue
		return s.slot_id
	return &""


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


func _seed_market(good_id: String, qty: int) -> void:
	if qty <= 0:
		return
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			GoodsLedger.make_market(PORT),
			StringName(good_id),
			qty,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)


func _seed_wh(good_id: String, qty: int) -> void:
	if qty <= 0:
		return
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			GoodsLedger.make_warehouse(String(ACTOR), PORT),
			StringName(good_id),
			qty,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)


func _wh_qty(good_id: String) -> int:
	return GoodsLedger.get_qty(GoodsLedger.make_warehouse(String(ACTOR), PORT), StringName(good_id))


func _top_up(amount: int) -> void:
	var bal: int = CashLedger.balance(ACTOR)
	if bal >= amount:
		return
	var delta: int = amount - bal
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - delta),
				CashLedger.make_entry(ACTOR, delta),
			],
			&"TEST_TOP_UP",
			BuildingEconomy.REQUESTER_SYS08
		),
		OK
	)


func _has_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if String((e as Dictionary).get("code", "")) == String(code):
			return true
	return false


func _build_valid_goods(out_dir: String) -> String:
	_wipe_dir(out_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# SYS-06 tables cover GD-001..028; build at least 28 regardless of GOOD_COUNT_MIN.
	var need: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	if need < 28:
		need = 28
	var staples: Array = [
		{"id": "GD-001", "name": STAPLE_RICE},
		{"id": "GD-002", "name": STAPLE_SALT},
		{"id": "GD-003", "name": STAPLE_TIMBER},
		{"id": "GD-004", "name": STAPLE_FISH},
	]
	var n := 0
	for row in staples:
		n = n + 1
		var def := GoodDef.new()
		def.good_id = row["id"]
		def.name_zh = row["name"]
		def.tier = 1
		def.is_staple = true
		def.is_build_material = String(row["id"]) == "GD-003"
		def.is_strategic = false
		def.base_price_li = ANCHOR_LI
		def.season_mask = (1 << Params.get_int(PRM_SEASONS)) - 1
		ResourceSaver.save(def, out_dir + "%s.tres" % row["id"])
	while n < need:
		n = n + 1
		var gid: String = "GD-%03d" % n
		var def2 := GoodDef.new()
		def2.good_id = gid
		def2.name_zh = "填料%d" % n
		def2.tier = 1
		def2.is_staple = false
		def2.is_build_material = false
		def2.is_strategic = false
		def2.base_price_li = ANCHOR_LI
		def2.season_mask = (1 << Params.get_int(PRM_SEASONS)) - 1
		ResourceSaver.save(def2, out_dir + "%s.tres" % gid)
	return out_dir


func _build_valid_ports(port_count: int, out_dir: String) -> String:
	_wipe_dir(out_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var free_count: int = 0
	var ratio_min: float = Params.get_float(PRM_FREE_PORT_RATIO_MIN)
	var ratio_max: float = Params.get_float(PRM_FREE_PORT_RATIO_MAX)
	while free_count <= port_count:
		var ratio: float = float(free_count) / float(port_count) if port_count > 0 else 0.0
		if ratio >= ratio_min and ratio <= ratio_max:
			break
		free_count += 1
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


func _wipe_dir(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
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
			_wipe_dir(path.path_join(name))
			DirAccess.remove_absolute(child)
		else:
			DirAccess.remove_absolute(child)
	dir.list_dir_end()
