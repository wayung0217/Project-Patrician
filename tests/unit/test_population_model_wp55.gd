extends GutTest
## WP-55: A13 draw_seq、A16 PF-3／hire、A17／D-87 opening all-or-nothing.


const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp55_pop/"
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
	PopulationModel._draw_seq_by_purpose = {}
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false


func test_WP55_A13_derive_seed_draw_seq_changes_hash() -> void:
	## D-83a／D-89b（待追認）: draw_seq ≥ 0 appends lottery dim; −1 omits (legacy hash).
	var base: int = Rng.derive_seed(42, 7, "PT-01", "RB-01", "place_in")
	var same: int = Rng.derive_seed(42, 7, "PT-01", "RB-01", "place_in", -1)
	var n0: int = Rng.derive_seed(42, 7, "PT-01", "RB-01", "place_in", 0)
	var n1: int = Rng.derive_seed(42, 7, "PT-01", "RB-01", "place_in", 1)
	assert_eq(base, same)
	assert_ne(base, n0)
	assert_ne(n0, n1)


func test_WP55_A13_same_day_repeat_draw_differs() -> void:
	## Same inputs with consecutive draw_seq must yield different u streams.
	var u0: float = _u_at(0)
	var u1: float = _u_at(1)
	assert_ne(u0, u1)


func test_WP55_A13_movers_disperse_across_residences() -> void:
	## FRM-SYS07-12／A13: with draw_seq, movers do not all pile into the same best house.
	var sat := TestSat.new()
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	PopulationModel.set_master_seed(99)
	_clear_residences(PORT_A)
	_force_residences_port(PORT_A, 4)
	var sync_errs: Array = []
	PopulationModel._sync_port_residences(PORT_A, 1, sync_errs)
	var ids: Array = PopulationModel._port_res_ids[PORT_A].duplicate()
	ids.sort()
	for i in range(ids.size()):
		PopulationModel._residents[String(ids[i])]["ring"] = i + 1
	PopulationModel._draw_seq_by_purpose = {}
	for _n in range(16):
		assert_true(PopulationModel._place_one_in(PORT_A, 3, "poor"))
	var occupied := 0
	for rid_v in ids:
		var occ: Dictionary = PopulationModel.residence_occupants(StringName(String(rid_v)))
		if int(occ["poor"]) > 0:
			occupied += 1
	assert_gt(occupied, 1)


func test_WP55_A16_pf3_academy_lv0_uses_unit_mult() -> void:
	## D-84c: academy level 0 → mult = ACADEMY_MULT_UNIT even on tier-3 path.
	var sat := TestSat.new()
	sat.set_input(PORT_A, "CITIZEN", 0.95)
	_boot_two_ports(sat)
	_zero_all_flow_rates()
	_clear_residences(PORT_A)
	_force_residences_port(PORT_A, 10) # beds ≥ citizens for opening place
	_add_tier3_workshop(PORT_A)
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 1000000
	Params._values["PRM-SYS07-UP2_STREAK_DAYS"] = 1
	Params._values["PRM-SYS07-ACADEMY_MULT"] = [1500, 2000, 2500]
	Params._values["PRM-SYS07-TIER3_MIN_ACTIVE"] = 1
	## job_cap must cover residents so A15 overflow path does not steal citizens.
	var def: BuildingDef = BuildingEconomy.get_building_def(&"WS-T3")
	def.max_workers = 250
	PopulationModel.set_workers(StringName("BLD:%s:WS-T3" % PORT_A), 250)
	PopulationModel.set_port_state(PORT_A, 0, 700, 0, 0, 900, 900, 900)
	PopulationModel._ports[PORT_A].streak_up2 = 99
	assert_eq(BuildingEconomy.public_level(StringName(PORT_A), &"CB-12"), 0)
	var errs: Array = PopulationModel.daily_step(1)
	assert_eq(errs.size(), 0, str(errs))
	var rich: int = PopulationModel.population(StringName(PORT_A), &"RICH")
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	var rate_scale: int = Params.get_int("PRM-SYS07-RATE_SCALE")
	var denom: int = rate_scale * days_pw
	var expect_unit: int = mini(700, (700 * 1000000) / denom)
	assert_eq(rich, expect_unit)


func test_WP55_D87_partial_opening_writes_nothing() -> void:
	## D-87: any opening error → no class counts written (ports may exist empty from load).
	_boot_modules_ports_only()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "partial/"))
	var op := OpeningPopulation.new()
	op.port_id = PORT_A
	op.poor = 10
	ResourceSaver.save(op, ROOT + "partial/%s.tres" % PORT_A)
	assert_eq(PopulationModel.population(StringName(PORT_A), &"POOR"), 0)
	var errs: Array = PopulationModel.apply_opening_init(ROOT + "partial/")
	assert_gt(errs.size(), 0)
	assert_push_error_count(errs.size())
	assert_eq(PopulationModel.population(StringName(PORT_A), &"POOR"), 0)
	assert_false(PopulationModel._ports.has("PT-99"))


func test_WP55_A17_unknown_port_no_silent_create() -> void:
	## A17: unknown port_id in opening → ERR; D-87 no writes／no silent create.
	_boot_modules_ports_only()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "badport/"))
	for pid_v in PortRegistry.all_ids():
		var op := OpeningPopulation.new()
		op.port_id = String(pid_v)
		op.poor = 1
		ResourceSaver.save(op, ROOT + "badport/%s.tres" % String(pid_v))
	var bad := OpeningPopulation.new()
	bad.port_id = "PT-99"
	bad.poor = 5
	ResourceSaver.save(bad, ROOT + "badport/ZZ_PT-99.tres")
	var errs: Array = PopulationModel.apply_opening_init(ROOT + "badport/")
	assert_gt(errs.size(), 0)
	assert_push_error_count(errs.size())
	assert_eq(PopulationModel.population(StringName(PORT_A), &"POOR"), 0)
	assert_false(PopulationModel._ports.has("PT-99"))
	var found := false
	for e in errs:
		var detail: Dictionary = (e as Dictionary).get("detail", {})
		if str(detail.get("value", "")) == "PT-99":
			found = true
	assert_true(found)


func _u_at(draw_seq: int) -> float:
	var u_seed: int = Rng.derive_seed(7, 1, "PT-01", "R1", "place_in", draw_seq)
	var pair: Array = Rng.next(u_seed)
	return float(absi(int(pair[1]) % 1000000)) / 1000000.0


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
	_save_def(dir, "WS-T3", "IND3", "GD-001", 3, 1.0)
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", dir).size(),
		0
	)
	_force_residences_port(PORT_A, 5)
	_force_residences_port(PORT_B, 5)


func _boot_modules_ports_only() -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	_setup_core_ledgers()
	PopulationModel.set_satisfaction_input_provider(TestSat.new())
	assert_eq(PopulationModel.load_and_validate().size(), 0)


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


func _zero_all_flow_rates() -> void:
	Params._values["PRM-SYS07-PF1_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF2_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF3_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF4_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF5_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_RATE_WK"] = 0
	Params._values["PRM-SYS07-PF6_BEGGAR_RATE_WK"] = 0


func _add_tier3_workshop(port_id: String) -> void:
	var bld := Building.new()
	bld.building_id = StringName("BLD:%s:WS-T3" % port_id)
	bld.type = &"WS-T3"
	bld.build_class = &"IND3"
	bld.owner = CashLedger.make_city_id(port_id)
	bld.port_id = port_id
	bld.state = Building.State.ACTIVE
	bld.slot_id = StringName("SLOT:%s:WS" % port_id)
	BuildingEconomy._register_building(bld)
	PopulationModel.set_workers(bld.building_id, 1)


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
