extends GutTest
## WP-51 incremental placement — FRM-SYS07-12、OQ-13j、TST-SYS07-11／12、C-13／D-63e.


const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp51_pop/"
const PORT_A := "PT-01"
const PORT_B := "PT-02"
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
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	PopulationModel._ports = {}
	PopulationModel._workers = {}
	PopulationModel._residents = {}
	PopulationModel._port_res_ids = {}
	PopulationModel._opening_placed = {}
	PopulationModel._wp51_rng_calls = 0
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false


func test_WP51_occupants_stable_when_no_movers() -> void:
	## FRM-SYS07-12／OQ-13j: no movers → occupants unchanged day-to-day.
	var sat := TestSat.new()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(11)
	PopulationModel.set_port_state(PORT_A, 40, 20, 10, 0, 500, 500, 500)
	PopulationModel.daily_step(1) # opening place
	var snap1: Dictionary = _snap_occ(PORT_A)
	PopulationModel._wp51_rng_calls = 0
	PopulationModel.daily_step(2)
	var snap2: Dictionary = _snap_occ(PORT_A)
	assert_eq(snap1, snap2)
	assert_eq(PopulationModel._wp51_rng_calls, 0)


func test_WP51_only_movers_draw_rng() -> void:
	## OQ-13j: only movers draw; zero movers → zero Rng.derive_seed in placement.
	var sat := TestSat.new()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(22)
	PopulationModel.set_port_state(PORT_A, 30, 10, 5, 0, 500, 500, 500)
	PopulationModel.daily_step(1)
	PopulationModel._wp51_rng_calls = 0
	PopulationModel.daily_step(2)
	assert_eq(PopulationModel._wp51_rng_calls, 0)
	# Force one hire-like in by directly calling place movers path: raise beggars＋beds.
	Params._values["PRM-SYS07-PF1_RATE_WK"] = 0
	PopulationModel.set_port_state(PORT_A, 30, 10, 5, 20, 900, 900, 900)
	# Ensure free beds: capacity 5*100=500, residents 45.
	PopulationModel._wp51_rng_calls = 0
	# Inject one immigration via _place_movers directly after sync.
	var sync_errs: Array = []
	PopulationModel._sync_port_residences(PORT_A, 3, sync_errs)
	PopulationModel._draw_seq_by_purpose = {}
	PopulationModel._place_movers(PORT_A, 3, 0, 0, 0, 0, 0, 0, 1)
	assert_gt(PopulationModel._wp51_rng_calls, 0)


func test_WP51_no_cross_port_placement() -> void:
	## FRM-SYS07-12: B overcrowded vs own beds must not place into A's free beds.
	var sat := TestSat.new()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(33)
	# A: 2 residences (200 beds), only 10 people → free beds.
	# B: 1 residence (100 beds), 150 people → over capacity locally.
	_clear_residences(PORT_A)
	_clear_residences(PORT_B)
	_force_residences_port(PORT_A, 2)
	_force_residences_port(PORT_B, 1)
	PopulationModel.set_port_state(PORT_A, 10, 0, 0, 0, 500, 500, 500)
	PopulationModel.set_port_state(PORT_B, 150, 0, 0, 0, 500, 500, 500)
	PopulationModel.daily_step(1)
	var a_ids: Array = PopulationModel._port_res_ids.get(PORT_A, [])
	for rid_v in a_ids:
		var occ: Dictionary = PopulationModel.residence_occupants(StringName(String(rid_v)))
		var total: int = int(occ["poor"]) + int(occ["citizen"]) + int(occ["rich"])
		# A's houses only hold A's 10 (or less); never B's overflow.
		assert_lte(total, 10)
	var sum_b := 0
	for rid2_v in PopulationModel._port_res_ids.get(PORT_B, []):
		var occ2: Dictionary = PopulationModel.residence_occupants(StringName(String(rid2_v)))
		sum_b += int(occ2["poor"]) + int(occ2["citizen"]) + int(occ2["rich"])
	assert_lte(sum_b, 100)
	# No B occupants stored under A's res_ids beyond A's own pop.
	var sum_a := 0
	for rid3_v in a_ids:
		var occ3: Dictionary = PopulationModel.residence_occupants(StringName(String(rid3_v)))
		sum_a += int(occ3["poor"]) + int(occ3["citizen"]) + int(occ3["rich"])
	assert_eq(sum_a, 10)


func test_WP51_sum_occupants_equals_st_pop() -> void:
	## Σ occupants (housed) = ST-POP poor+citizen+rich when beds suffice.
	var sat := TestSat.new()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(44)
	_clear_residences(PORT_A)
	_force_residences_port(PORT_A, 5)
	PopulationModel.set_port_state(PORT_A, 120, 80, 40, 0, 500, 500, 500)
	PopulationModel.daily_step(1)
	var sum_occ := 0
	for rid_v in PopulationModel._port_res_ids.get(PORT_A, []):
		var occ: Dictionary = PopulationModel.residence_occupants(StringName(String(rid_v)))
		sum_occ += int(occ["poor"]) + int(occ["citizen"]) + int(occ["rich"])
	var st: int = (
		PopulationModel.population(StringName(PORT_A), &"POOR")
		+ PopulationModel.population(StringName(PORT_A), &"CITIZEN")
		+ PopulationModel.population(StringName(PORT_A), &"RICH")
	)
	assert_eq(sum_occ, st)
	assert_eq(st, 240)


func test_WP51_port_iteration_order_independent() -> void:
	## TST-SYS07-11: different port insert order → same occupants／ST-POP.
	var sat := TestSat.new()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(55)
	PopulationModel.set_port_state(PORT_A, 40, 20, 10, 0, 500, 500, 500)
	PopulationModel.set_port_state(PORT_B, 30, 15, 5, 0, 500, 500, 500)
	# Natural order A then B (keys sorted in daily_step).
	PopulationModel.daily_step(1)
	var snap_ab: Dictionary = {"A": _snap_occ(PORT_A), "B": _snap_occ(PORT_B)}
	var pop_ab := {
		"Ap": PopulationModel.population(StringName(PORT_A), &"POOR"),
		"Bp": PopulationModel.population(StringName(PORT_B), &"POOR"),
	}
	before_each()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(55)
	# Insert B before A into _ports.
	PopulationModel.set_port_state(PORT_B, 30, 15, 5, 0, 500, 500, 500)
	PopulationModel.set_port_state(PORT_A, 40, 20, 10, 0, 500, 500, 500)
	PopulationModel.daily_step(1)
	assert_eq(_snap_occ(PORT_A), snap_ab["A"])
	assert_eq(_snap_occ(PORT_B), snap_ab["B"])
	assert_eq(PopulationModel.population(StringName(PORT_A), &"POOR"), pop_ab["Ap"])
	assert_eq(PopulationModel.population(StringName(PORT_B), &"POOR"), pop_ab["Bp"])


func test_WP51_same_seed_same_result() -> void:
	## TST-SYS07-12／GP-03: same seed → identical placement.
	var sat := TestSat.new()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(66)
	PopulationModel.set_port_state(PORT_A, 50, 25, 12, 0, 500, 500, 500)
	PopulationModel.daily_step(1)
	var s1: Dictionary = _snap_occ(PORT_A)
	before_each()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(66)
	PopulationModel.set_port_state(PORT_A, 50, 25, 12, 0, 500, 500, 500)
	PopulationModel.daily_step(1)
	assert_eq(_snap_occ(PORT_A), s1)


func test_WP51_opening_full_placement() -> void:
	## FRM-SYS07-14: first daily_step performs full local placement.
	var sat := TestSat.new()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(77)
	_clear_residences(PORT_A)
	_force_residences_port(PORT_A, 3)
	PopulationModel.set_port_state(PORT_A, 100, 50, 20, 0, 500, 500, 500)
	assert_false(bool(PopulationModel._opening_placed.get(PORT_A, false)))
	PopulationModel.daily_step(1)
	assert_true(bool(PopulationModel._opening_placed.get(PORT_A, false)))
	var sum_occ := 0
	for rid_v in PopulationModel._port_res_ids.get(PORT_A, []):
		var occ: Dictionary = PopulationModel.residence_occupants(StringName(String(rid_v)))
		sum_occ += int(occ["poor"]) + int(occ["citizen"]) + int(occ["rich"])
		assert_lte(
			int(occ["poor"]) + int(occ["citizen"]) + int(occ["rich"]),
			Params.get_int("PRM-SYS07-HOUSE_CAPACITY")
		)
	assert_eq(sum_occ, 170)


# --- helpers ---


func _boot_two_ports(sat: SatisfactionInputProvider) -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	PopulationModel.set_satisfaction_input_provider(sat)
	assert_eq(PopulationModel.load_and_validate().size(), 0)
	PopulationModel.set_master_seed(1)
	BuildingEconomy.set_population_provider(PopulationModel.get_population_provider())
	BuildingEconomy.set_workforce_provider(PopulationModel.get_workforce_provider())
	_setup_core_ledgers()
	_write_min_layout_two()
	var dir := ROOT + "buildings/"
	_save_def(dir, "KT-01", "KONTOR", "", 0, 1.0)
	_save_def(dir, "RB-01", "RESIDENCE", "", 0, 1.0)
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", dir).size(),
		0
	)
	_force_residences_port(PORT_A, 5)
	_force_residences_port(PORT_B, 5)


func _zero_all_flow_rates() -> void:
	Params._values["PRM-SYS07-PF1_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF5_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_BEGGAR_RATE_WK"] = 0


func _snap_occ(port_id: String) -> Dictionary:
	var out := {}
	var ids: Array = PopulationModel._port_res_ids.get(port_id, [])
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	for rid_v in sorted_ids:
		var rid: String = String(rid_v)
		var occ: Dictionary = PopulationModel.residence_occupants(StringName(rid))
		out[rid] = "%s,%s,%s" % [str(occ["poor"]), str(occ["citizen"]), str(occ["rich"])]
	return out


func _clear_residences(port_id: String) -> void:
	var arr: Array = BuildingEconomy._buildings_by_port.get(port_id, [])
	var keep: Array = []
	for bld_v in arr:
		var bld: Building = bld_v
		if bld.build_class == &"RESIDENCE":
			BuildingEconomy._buildings.erase(String(bld.building_id))
			PopulationModel._residents.erase(String(bld.building_id))
		else:
			keep.append(bld)
	BuildingEconomy._buildings_by_port[port_id] = keep
	PopulationModel._port_res_ids[port_id] = []
	PopulationModel._opening_placed.erase(port_id)


func _force_residences_port(port_id: String, n: int) -> void:
	for i in range(n):
		var bld := Building.new()
		bld.building_id = StringName("BLD:%s:RES%d" % [port_id, i])
		bld.type = &"RB-01"
		bld.build_class = &"RESIDENCE"
		bld.owner = ACTOR
		bld.port_id = port_id
		bld.state = Building.State.ACTIVE
		bld.slot_id = StringName("SLOT:%s:%04d" % [port_id, i + 10])
		BuildingEconomy._register_building(bld)


func _setup_core_ledgers() -> void:
	var goods_dir := _build_valid_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var port_count: int = maxi(2, Params.get_int(PRM_PORT_COUNT_MIN))
	var ports_dir := _build_valid_ports(port_count, ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), BuildingEconomy.get_warehouse_capacity_provider()
	)


func _write_min_layout_two() -> void:
	for pid in [PORT_A, PORT_B]:
		_write_zone(ROOT + "zones/", pid, 1, 1, 8, 1)
		_write_zone(ROOT + "zones/", pid, 2, 1, 4, 0)
		_write_city(ROOT + "city_center/", pid, 2)
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
