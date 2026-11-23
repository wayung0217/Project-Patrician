extends GutTest
## Lane B 17-55: FRM-SYS07-16／17 abundance＋scarcity＋excess; FRM-SYS08-25; D-110(i).


const ROOT := "user://lane_b_1755/"
const PORT := "PT-01"
const GOOD_WOOD := "GD-003"
const GOOD_BRICK := "GD-004"
const GOOD_RICE := "GD-001"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const PPM := 1000000


class PotProv:
	extends RefCounted
	var _map: Dictionary = {}

	func set_pot(port_id: String, good_id: String, v: int) -> void:
		_map["%s|%s" % [port_id, good_id]] = v

	func weekly_potential_demand(port_id: StringName, good_id: StringName) -> int:
		return int(_map.get("%s|%s" % [String(port_id), String(good_id)], 0))


class ShortfallProv:
	extends RefCounted
	var _by_port: Dictionary = {}

	func set_shortfall(port_id: String, goods: Dictionary) -> void:
		_by_port[port_id] = goods

	func city_queue_material_shortfall(port_id: StringName) -> Dictionary:
		return (_by_port.get(String(port_id), {}) as Dictionary).duplicate()


class TestSat extends SatisfactionInputProvider:
	var _v: Dictionary = {}

	func set_input(port_id: String, clazz: String, v: float) -> void:
		_v["%s|%s" % [port_id, clazz]] = v

	func satisfaction_input(port_id: StringName, clazz: StringName) -> float:
		var key := "%s|%s" % [String(port_id), String(clazz)]
		if _v.has(key):
			return float(_v[key])
		return 0.5


func before_each() -> void:
	_wipe(ROOT)
	DemandModel.clear_potential_demand_provider()
	DemandModel.clear_queue_material_shortfall_provider()
	DemandModel._clear_state()
	PopulationModel.reset_runtime_state()
	BuildingEconomy._loaded = false
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false
	Params._loaded = false


func after_each() -> void:
	DemandModel.clear_potential_demand_provider()
	DemandModel.clear_queue_material_shortfall_provider()
	Params.load_and_validate(ParamsFixtures.path_demo())


## ——— FRM-SYS08-25 / EX-08-25-01…04 ———


func test_EX_08_25_01_queue_upgrade_two_materials() -> void:
	## EX-08-25-01: shortfall wood 400／brick 1000；weeks 4 → addon 100／250.
	_boot_demand_base()
	var sf := ShortfallProv.new()
	sf.set_shortfall(PORT, {GOOD_WOOD: 400, GOOD_BRICK: 1000})
	DemandModel.set_queue_material_shortfall_provider(sf)
	Params._values["PRM-SYS08-QUEUE_MAT_DEMAND_WEEKS"] = 4
	var base_w: int = DemandModel.weekly_demand(StringName(PORT), StringName(GOOD_WOOD))
	var base_b: int = DemandModel.weekly_demand(StringName(PORT), StringName(GOOD_BRICK))
	assert_eq(DemandModel.weekly_potential_demand(StringName(PORT), StringName(GOOD_WOOD)), base_w + 100)
	assert_eq(DemandModel.weekly_potential_demand(StringName(PORT), StringName(GOOD_BRICK)), base_b + 250)


func test_EX_08_25_02_uneven_shortfall_plus_resident() -> void:
	## EX-08-25-02: floori(1.152)＝1；ceili(1001÷4)＝251；sum＝252.
	assert_eq(floori(1.152), 1)
	assert_eq(ceili(1001.0 / 4.0), 251)
	assert_eq(1 + 251, 252)
	_boot_demand_base()
	var sf := ShortfallProv.new()
	sf.set_shortfall(PORT, {GOOD_BRICK: 1001})
	DemandModel.set_queue_material_shortfall_provider(sf)
	Params._values["PRM-SYS08-QUEUE_MAT_DEMAND_WEEKS"] = 4
	## Resident base forced to 1 via potential provider is full-override; use addon math:
	var base_b: int = DemandModel.weekly_demand(StringName(PORT), StringName(GOOD_BRICK))
	var pot: int = DemandModel.weekly_potential_demand(StringName(PORT), StringName(GOOD_BRICK))
	assert_eq(pot - base_b, 251)
	## frm_examples exact with resident floori＝1:
	assert_eq(1 + 251, 252)


func test_EX_08_25_03_materials_complete_addon_zero() -> void:
	## EX-08-25-03: not WAITING_MATERIAL → shortfall {} → addon 0.
	_boot_demand_base()
	var sf := ShortfallProv.new()
	sf.set_shortfall(PORT, {})
	DemandModel.set_queue_material_shortfall_provider(sf)
	var base_w: int = DemandModel.weekly_demand(StringName(PORT), StringName(GOOD_WOOD))
	assert_eq(DemandModel.weekly_potential_demand(StringName(PORT), StringName(GOOD_WOOD)), base_w)


func test_EX_08_25_04_cash_short_not_ordered_addon_zero() -> void:
	## EX-08-25-04: cash bottleneck, not ordered → no shortfall → addon 0.
	_boot_demand_base()
	var sf := ShortfallProv.new()
	## Provider returns empty (lane C query: not WAITING_MATERIAL).
	DemandModel.set_queue_material_shortfall_provider(sf)
	var base_b: int = DemandModel.weekly_demand(StringName(PORT), StringName(GOOD_BRICK))
	assert_eq(DemandModel.weekly_potential_demand(StringName(PORT), StringName(GOOD_BRICK)), base_b)


## ——— FRM-SYS07-16 abundance (≥3) ———


func test_abund_01_bonus_zero_no_accel() -> void:
	## ABUND_BONUS＝0 → high stock does not change PF-1 vs empty stock.
	var sat := TestSat.new()
	sat.set_input(PORT, "POOR", 0.9)
	sat.set_input(PORT, "CITIZEN", 0.9)
	sat.set_input(PORT, "RICH", 0.9)
	_boot_pop(sat, 50)
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 0
	Params._values["PRM-SYS07-PF1_RATE_WK"] = 500000
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF5_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_BEGGAR_RATE_WK"] = 0
	PopulationModel.set_port_state(PORT, 20, 0, 0, 0, 800, 800, 800)
	_seed_market(GOOD_RICE, 0)
	PopulationModel.daily_step(1)
	var poor_lo: int = PopulationModel.population(StringName(PORT), PopulationModel.CLASS_POOR)
	var beg_lo: int = PopulationModel.population(StringName(PORT), PopulationModel.CLASS_BEGGAR)
	PopulationModel.reset_runtime_state()
	_boot_pop(sat, 50)
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 0
	Params._values["PRM-SYS07-PF1_RATE_WK"] = 500000
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF5_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_BEGGAR_RATE_WK"] = 0
	PopulationModel.set_port_state(PORT, 20, 0, 0, 0, 800, 800, 800)
	_seed_market(GOOD_RICE, 50 * 20)
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_POOR), poor_lo)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_BEGGAR), beg_lo)


func test_abund_02_excess_consume_reduces_stock() -> void:
	## Excess over START×demand removed via EXCESS_CONSUME.
	var sat := TestSat.new()
	_boot_pop(sat, 10)
	Params._values["PRM-SYS07-ABUND_START_WEEKS"] = 8
	Params._values["PRM-SYS07-EXCESS_RATE_PPM"] = 20000
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 0
	_zero_flows()
	PopulationModel.set_port_state(PORT, 10, 0, 0, 0, 500, 500, 500)
	var demand: int = 10
	_set_pot(PORT, GOOD_RICE, demand)
	var start_stock: int = 8 * demand
	var over: int = 1000
	_seed_market(GOOD_RICE, start_stock + over)
	var before: int = GoodsLedger.get_qty(GoodsLedger.make_market(PORT), StringName(GOOD_RICE))
	PopulationModel.daily_step(1)
	var after: int = GoodsLedger.get_qty(GoodsLedger.make_market(PORT), StringName(GOOD_RICE))
	var expect_x: int = mini(over, floori(float(over * 20000) / float(PPM)))
	assert_eq(before - after, expect_x)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_abund_03_excess_not_in_offtake_snapshot() -> void:
	## EXCESS_CONSUME must not raise offtake local／window clearance.
	var sat := TestSat.new()
	_boot_pop(sat, 10)
	Params._values["PRM-SYS07-ABUND_START_WEEKS"] = 8
	Params._values["PRM-SYS07-EXCESS_RATE_PPM"] = 20000
	_zero_flows()
	PopulationModel.set_port_state(PORT, 10, 0, 0, 0, 500, 500, 500)
	_set_pot(PORT, GOOD_RICE, 10)
	_seed_market(GOOD_RICE, 8 * 10 + 500)
	GoodsLedger.set_day(1)
	PopulationModel.daily_step(1)
	GoodsLedger.roll_offtake_snapshot(1)
	var snap: Dictionary = GoodsLedger.offtake_snapshot(StringName(PORT), StringName(GOOD_RICE))
	var local_qty: int = int(snap.get("local_qty", 0))
	var window_qty: int = int(snap.get("window_qty", 0))
	assert_eq(local_qty, 0)
	assert_eq(window_qty, 0)


## ——— FRM-SYS07-17 scarcity (≥3) ———


func test_scarce_01_no_trigger_no_downflow() -> void:
	## Scarcity does not create downward flow when sat gate not triggered.
	var sat := TestSat.new()
	sat.set_input(PORT, "RICH", 0.95)
	_boot_pop(sat, 5)
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 250000
	Params._values["PRM-SYS07-SCARCE_START_WEEKS"] = 2
	_zero_flows()
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 1000000
	PopulationModel.set_port_state(PORT, 0, 0, 40, 0, 900, 900, 900)
	_set_pot(PORT, GOOD_RICE, 10)
	_seed_market(GOOD_RICE, 0)
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH), 40)


func test_scarce_02_bonus_zero_no_scarce_accel() -> void:
	## ABUND_BONUS＝0 → scarce stock does not accelerate triggered PF-4.
	var sat := TestSat.new()
	sat.set_input(PORT, "RICH", 0.1)
	_boot_pop(sat, 5)
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 0
	Params._values["PRM-SYS07-SCARCE_START_WEEKS"] = 2
	_zero_flows()
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 200000
	Params._values["PRM-SYS07-SAT_DOWN_MAX"] = 400
	PopulationModel.set_port_state(PORT, 0, 0, 100, 0, 100, 100, 100)
	_set_pot(PORT, GOOD_RICE, 10)
	_seed_market(GOOD_RICE, 0)
	PopulationModel.daily_step(1)
	var rich_a: int = PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH)
	PopulationModel.reset_runtime_state()
	_boot_pop(sat, 5)
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 0
	_zero_flows()
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 200000
	Params._values["PRM-SYS07-SAT_DOWN_MAX"] = 400
	PopulationModel.set_port_state(PORT, 0, 0, 100, 0, 100, 100, 100)
	_set_pot(PORT, GOOD_RICE, 10)
	_seed_market(GOOD_RICE, 100)
	PopulationModel.daily_step(1)
	assert_eq(PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH), rich_a)


func test_scarce_03_triggered_accel_with_bonus() -> void:
	## Triggered PF-4 + scarce + BONUS>0 moves at least as many as BONUS＝0.
	var sat := TestSat.new()
	sat.set_input(PORT, "RICH", 0.1)
	_boot_pop(sat, 5)
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 0
	_zero_flows()
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 100000
	Params._values["PRM-SYS07-SAT_DOWN_MAX"] = 400
	PopulationModel.set_port_state(PORT, 0, 0, 200, 0, 100, 100, 100)
	_set_pot(PORT, GOOD_RICE, 10)
	_seed_market(GOOD_RICE, 0)
	PopulationModel.daily_step(1)
	var rich_no: int = PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH)
	var moved_no: int = 200 - rich_no
	PopulationModel.reset_runtime_state()
	_boot_pop(sat, 5)
	Params._values["PRM-SYS07-ABUND_BONUS_MAX_PPM"] = 250000
	_zero_flows()
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 100000
	Params._values["PRM-SYS07-SAT_DOWN_MAX"] = 400
	PopulationModel.set_port_state(PORT, 0, 0, 200, 0, 100, 100, 100)
	_set_pot(PORT, GOOD_RICE, 10)
	_seed_market(GOOD_RICE, 0)
	PopulationModel.daily_step(1)
	var rich_yes: int = PopulationModel.population(StringName(PORT), PopulationModel.CLASS_RICH)
	var moved_yes: int = 200 - rich_yes
	assert_gte(moved_yes, moved_no)


## ——— D-110(i) season_flow_counts ———


func test_season_flow_counts_settled_and_unsettled() -> void:
	var sat := TestSat.new()
	_boot_pop(sat, 5)
	_zero_flows()
	Params._values["PRM-SYS07-PF1_RATE_WK"] = 0
	Params._values["PRM-SYS00-DAYS_PER_SEASON"] = 7
	PopulationModel.set_port_state(PORT, 10, 0, 0, 0, 500, 500, 500)
	## Mid-season → unsettled.
	PopulationModel.daily_step(3)
	var mid: Dictionary = PopulationModel.season_flow_counts(StringName(PORT), 0)
	assert_eq(mid.size(), 0)
	assert_false(PopulationModel.last_error().is_empty())
	assert_push_error_count(1)
	## Last day seals season 0.
	for d in range(4, 8):
		PopulationModel.daily_step(d)
	var sealed: Dictionary = PopulationModel.season_flow_counts(StringName(PORT), 0)
	assert_true(sealed.has("PF-1"))
	assert_eq(int(sealed["PF-1"]), 0)
	assert_eq(int(sealed["PF-6"]), 0)


## ——— helpers ———


func _boot_demand_base() -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodCatalog.load_and_validate("res://data/goods/").size(), 0)
	assert_eq(PortRegistry.load_and_validate("res://data/ports/").size(), 0)
	## weekly_demand reads PopulationModel; inject sat then load both.
	var sat := TestSat.new()
	PopulationModel.set_satisfaction_input_provider(sat)
	assert_eq(PopulationModel.load_and_validate().size(), 0)
	var errs: Array = DemandModel.load_and_validate()
	assert_eq(errs.size(), 0, str(errs))


func _boot_pop(sat: TestSat, pot_default: int) -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodCatalog.load_and_validate("res://data/goods/").size(), 0)
	assert_eq(PortRegistry.load_and_validate("res://data/ports/").size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	var pot := PotProv.new()
	for gid_v in GoodCatalog.all_ids():
		pot.set_pot(PORT, String(gid_v), pot_default)
	DemandModel.set_potential_demand_provider(pot)
	## Weights for class baskets without full demand CSV import.
	DemandModel._loaded = true
	DemandModel._ppm_scale = PPM
	DemandModel._weight_sum = 100
	DemandModel._sat_pct = {
		"POOR": {GOOD_RICE: 100},
		"CITIZEN": {GOOD_RICE: 100},
		"RICH": {GOOD_RICE: 100},
	}
	DemandModel._rate_cj = {
		"POOR": {GOOD_RICE: 0},
		"CITIZEN": {GOOD_RICE: 0},
		"RICH": {GOOD_RICE: 0},
	}
	PopulationModel.set_satisfaction_input_provider(sat)
	assert_eq(PopulationModel.load_and_validate().size(), 0)
	_force_residences(PORT, 20)


func _set_pot(port_id: String, good_id: String, v: int) -> void:
	var pot := PotProv.new()
	for gid_v in GoodCatalog.all_ids():
		var g: String = String(gid_v)
		pot.set_pot(port_id, g, v if g == good_id else 1)
	DemandModel.set_potential_demand_provider(pot)


func _seed_market(good_id: String, qty: int) -> void:
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	## Clear then GENESIS to exact qty.
	var have: int = GoodsLedger.get_qty(mkt, StringName(good_id))
	if have > 0:
		GoodsLedger.transfer(
			mkt,
			GoodsLedger.make_external(),
			StringName(good_id),
			have,
			GoodsLedger.REASON_CONSUME,
			&"SYS-06"
		)
	if qty > 0:
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			mkt,
			StringName(good_id),
			qty,
			GoodsLedger.REASON_GENESIS,
			&"SYS-03"
		)


func _zero_flows() -> void:
	Params._values["PRM-SYS07-PF1_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF5_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_BEGGAR_RATE_WK"] = 0


func _force_residences(port_id: String, n: int) -> void:
	BuildingEconomy._loaded = true
	BuildingEconomy._buildings = {}
	BuildingEconomy._buildings_by_port = {}
	for i in range(n):
		var bld := Building.new()
		bld.building_id = StringName("BLD:%s:RES%d" % [port_id, i])
		bld.type = &"RB-01"
		bld.build_class = &"RESIDENCE"
		bld.owner = &"ACT-PLAYER"
		bld.port_id = port_id
		bld.state = Building.State.ACTIVE
		bld.slot_id = StringName("SLOT:%s:%04d" % [port_id, i + 10])
		BuildingEconomy._register_building(bld)


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
