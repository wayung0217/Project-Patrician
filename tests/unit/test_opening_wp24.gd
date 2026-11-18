extends GutTest
## WP-24 / TechSpec 14-09 opening init + season conservation.


const PARAMS_FIXTURE := "res://tests/fixtures/params_sys05_demo.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp24_open/"
const PORT_A := "PT-01"
const PORT_HOME := "PT-10"
const ACTOR := &"ACT-PLAYER"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_DAYS := "PRM-SYS00-DAYS_PER_SEASON"


class TestCons extends ConsumptionProvider:
	func weekly_consumption(_p: StringName, _g: StringName) -> int:
		return 0

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
	PopulationModel._ports = {}
	PopulationModel._workers = {}
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false
	SimLoop._booted = false
	SeaLanes._loaded = false


func test_TST_SYS08_18_opening_workshops_city_active() -> void:
	## TST-SYS08-18: opening workshops are city-owned ACTIVE (count from CSV).
	_boot_with_opening()
	var city_a := CashLedger.make_city_id(PORT_A)
	var n := 0
	for b_v in BuildingEconomy.workplaces(StringName(PORT_A)):
		var b: Building = b_v
		assert_eq(b.owner, city_a)
		assert_eq(b.state, Building.State.ACTIVE)
		n += 1
	assert_eq(n, 2)
	assert_eq(BuildingEconomy.workplaces(StringName(PORT_HOME)).size(), 1)


func test_WP24_14_09_1_opening_population_beggar_zero() -> void:
	_boot_with_opening()
	assert_eq(PopulationModel.population(StringName(PORT_A), &"POOR"), 100)
	assert_eq(PopulationModel.population(StringName(PORT_A), &"CITIZEN"), 40)
	assert_eq(PopulationModel.population(StringName(PORT_A), &"RICH"), 10)
	assert_eq(PopulationModel.beggars(StringName(PORT_A)), 0)
	assert_eq(PopulationModel.beggars(StringName(PORT_HOME)), 0)


func test_WP24_14_09_2_opening_public_level_1() -> void:
	_boot_with_opening()
	assert_eq(BuildingEconomy.public_level(StringName(PORT_A), &"CB-01"), 1)
	assert_eq(BuildingEconomy.public_level(StringName(PORT_HOME), &"CB-09"), 1)


func test_WP24_14_09_3_player_kontor_warehouse() -> void:
	_boot_with_opening()
	var found := false
	for b_v in BuildingEconomy.buildings_for_port(PORT_HOME):
		var b: Building = b_v
		if b.build_class == &"KONTOR" and b.owner == ACTOR:
			found = true
			assert_eq(b.level, 1)
			assert_eq(b.state, Building.State.ACTIVE)
	assert_true(found)
	assert_gt(BuildingEconomy.warehouse_capacity(ACTOR, StringName(PORT_HOME)), 0)


func test_WP24_14_09_residences_match_pop() -> void:
	_boot_with_opening()
	var house_cap: int = Params.get_int("PRM-SYS07-HOUSE_CAPACITY")
	var pop: int = 150 # 100+40+10
	var need: int = int(ceil(float(pop) / float(house_cap)))
	assert_eq(BuildingEconomy.residences(StringName(PORT_A)).size(), need)


func test_TST_SYS08_17_season_conservation_clean() -> void:
	## TST-SYS08-17 / 14-09 ④: one season produce after opening; FRM-SYS03-01 clean.
	_boot_with_opening()
	var days: int = Params.get_int(PRM_DAYS)
	for d in range(days):
		assert_eq(BuildingEconomy.daily_step(d + 1).size(), 0)
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_WP24_csv_only_opening_resources() -> void:
	## Opening rows come from tres written from CSV fixture paths (2.1-04 ⑤).
	assert_true(FileAccess.file_exists("res://tests/fixtures/wp24_opening/opening_workshops.csv"))
	assert_true(FileAccess.file_exists("res://tests/fixtures/wp24_opening/opening_public.csv"))
	assert_true(FileAccess.file_exists("res://tests/fixtures/wp24_opening/opening_population.csv"))


# --- helpers ---


func _boot_with_opening() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	var goods_dir := _build_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_ports(Params.get_int(PRM_PORT_COUNT_MIN), ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	MarketPricer.set_consumption_provider(TestCons.new())
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	PopulationModel.set_satisfaction_input_provider(TestSat.new())
	assert_eq(PopulationModel.load_and_validate().size(), 0)
	BuildingEconomy.set_population_provider(PopulationModel.get_population_provider())
	BuildingEconomy.set_workforce_provider(PopulationModel.get_workforce_provider())
	_write_layout_multi()
	_write_defs()
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)
	_write_opening_tres()
	assert_eq(PopulationModel.apply_opening_init(ROOT + "opening_population/").size(), 0)
	assert_eq(
		BuildingEconomy.apply_opening_init(
			ROOT + "opening/", ROOT + "opening_public/", PORT_HOME, ACTOR
		).size(),
		0
	)
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), BuildingEconomy.get_warehouse_capacity_provider()
	)


func _write_opening_tres() -> void:
	# From CSV fixtures (no hand-written production data).
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening_population/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening_public/"))
	for row in [
		{"port": PORT_A, "p": 100, "c": 40, "r": 10},
		{"port": PORT_HOME, "p": 80, "c": 30, "r": 5},
	]:
		var op := OpeningPopulation.new()
		op.port_id = row["port"]
		op.poor = row["p"]
		op.citizen = row["c"]
		op.rich = row["r"]
		ResourceSaver.save(op, ROOT + "opening_population/%s.tres" % row["port"])
	for row2 in [
		{"port": PORT_A, "g": "GD-001", "n": 2},
		{"port": PORT_HOME, "g": "GD-001", "n": 1},
	]:
		var ow := OpeningWorkshop.new()
		ow.port_id = row2["port"]
		ow.good_id = row2["g"]
		ow.count = row2["n"]
		ResourceSaver.save(
			ow, ROOT + "opening/%s__%s.tres" % [row2["port"], row2["g"]]
		)
	for row3 in [
		{"port": PORT_A, "cb": "CB-01", "lv": 1},
		{"port": PORT_HOME, "cb": "CB-09", "lv": 1},
	]:
		var opub := OpeningPublic.new()
		opub.port_id = row3["port"]
		opub.cb_id = row3["cb"]
		opub.level = row3["lv"]
		ResourceSaver.save(
			opub, ROOT + "opening_public/%s__%s.tres" % [row3["port"], row3["cb"]]
		)


func _write_layout_multi() -> void:
	for port in [PORT_A, PORT_HOME]:
		_write_zone(ROOT + "zones/", port, 1, 2, 12, 1)
		_write_zone(ROOT + "zones/", port, 2, 1, 4, 0)
		_write_city(ROOT + "city_center/", port, 4)
	# Minimal zones for other ports so PortRegistry ports without layout still OK —
	# BuildingEconomy only builds slots for ports with zone rows; opening only touches A/HOME.


func _write_defs() -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, "KT-01", "KONTOR", "", 0, 1.0)
	_save_def(dir, "RB-01", "RESIDENCE", "", 0, 1.0)
	_save_def(dir, "WS-RICE", "IND1", "GD-001", 1, 1.5)


func _save_def(dir: String, type_id: String, bclass: String, out_g: String, tier: int, base: float) -> void:
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


func _build_goods(dir: String) -> String:
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": "GD-001", "name": "米", "build": false},
		{"id": "GD-002", "name": "鹽", "build": false},
		{"id": "GD-003", "name": "木材", "build": true},
		{"id": "GD-004", "name": "魚乾", "build": false},
	]
	var written := 0
	for s in staples:
		var g := GoodDef.new()
		g.good_id = s["id"]
		g.name_zh = s["name"]
		g.tier = 1
		g.is_staple = true
		g.is_build_material = s["build"]
		g.base_price_li = 10
		g.season_mask = (1 << Params.get_int(PRM_SEASONS)) - 1
		ResourceSaver.save(g, dir + "%s.tres" % s["id"])
		written += 1
	var n := 5
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	while written < count:
		var gid := "GD-%03d" % n
		var g2 := GoodDef.new()
		g2.good_id = gid
		g2.name_zh = gid
		g2.tier = mini((n % (free_max + 1)) + 1, Params.get_int(PRM_TIER_MAX))
		g2.base_price_li = 10
		g2.season_mask = (1 << Params.get_int(PRM_SEASONS)) - 1
		ResourceSaver.save(g2, dir + "%s.tres" % gid)
		written += 1
		n += 1
	return dir


func _build_ports(port_count: int, dir: String) -> String:
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
		if port_id == PORT_HOME:
			def.name_zh = "魍港"
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
