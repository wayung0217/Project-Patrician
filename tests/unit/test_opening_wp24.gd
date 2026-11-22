extends GutTest
## WP-24 / TechSpec 14-09 opening init + season conservation (D-19d／e).


const CsvImport := preload("res://tools/csv_import.gd")

const PARAMS_FIXTURE := "res://tests/fixtures/params_sys05_demo.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp24_open/"
const PORT_A := "PT-01"
const PORT_HOME := "PT-10"
const ACTOR := &"ACT-PLAYER"
const FIX_POP_OK := "res://tests/fixtures/wp24_pop_ok/"
const FIX_POP_DUP := "res://tests/fixtures/wp24_pop_dup/"
const FIX_POP_BAD_PORT := "res://tests/fixtures/wp24_pop_bad_port/"
const OUT_POP := "res://tests/fixtures/wp24_out_pop/"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_DAYS := "PRM-SYS00-DAYS_PER_SEASON"


class TestCons extends ConsumptionProvider:
	var _qty: Dictionary = {} ## "port|good" → int

	func set_qty(port_id: String, good_id: String, qty: int) -> void:
		_qty["%s|%s" % [port_id, good_id]] = qty


	func consume_qty(port_id: StringName, good_id: StringName, _d: int) -> int:
		return int(_qty.get("%s|%s" % [String(port_id), String(good_id)], 0))


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
	assert_eq(PopulationModel.population(StringName(PORT_HOME), &"POOR"), 80)
	assert_eq(PopulationModel.population(StringName(PORT_HOME), &"CITIZEN"), 30)
	assert_eq(PopulationModel.population(StringName(PORT_HOME), &"RICH"), 5)
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
	var need_a: int = int(ceil(150.0 / float(house_cap)))
	var need_home: int = int(ceil(115.0 / float(house_cap)))
	assert_eq(BuildingEconomy.residences(StringName(PORT_A)).size(), need_a)
	assert_eq(BuildingEconomy.residences(StringName(PORT_HOME)).size(), need_home)


func test_TST_SYS08_17_season_conservation_clean() -> void:
	## D-19d: full SimLoop schedule with CONSUME, recipe workshop, CONSTRUCT_USE, TRADE.
	var cons := TestCons.new()
	cons.set_qty(PORT_A, "GD-001", 1)
	SimLoop.set_consumption_provider(cons)
	_boot_with_opening()
	# Stock market for CONSUME + recipe input.
	var mkt: Dictionary = GoodsLedger.make_market(PORT_A)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			mkt,
			&"GD-001",
			500,
			GoodsLedger.REASON_PRODUCE,
			&"SYS-08"
		),
		0
	)
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			mkt,
			&"GD-002",
			200,
			GoodsLedger.REASON_PRODUCE,
			&"SYS-08"
		),
		0
	)
	# Recipe-input workshop already ACTIVE from opening (WS-RICE needs GD-002).
	# CONSTRUCT_USE + TRADE: player order_build residence (buys mats from market).
	_top_up_actor(5_000_000)
	var slot: StringName = &""
	for s_v in BuildingEconomy.slots_for_port(PORT_HOME):
		var s: Slot = s_v
		if s.kind == Slot.Kind.CIVIL and s.zone_open and s.building_id == &"":
			slot = s.slot_id
			break
	assert_ne(slot, &"")
	if BuildingEconomy.get_slot(slot).land_owner != ACTOR:
		assert_gt(BuildingEconomy.buy_land(ACTOR, slot), 0)
	var bid: StringName = BuildingEconomy.order_build(ACTOR, slot, &"RB-01")
	assert_ne(bid, &"")
	SimLoop._booted = true
	var days: int = Params.get_int(PRM_DAYS)
	for _d in range(days):
		var day_errs: Array = SimLoop.tick_day()
		for e in day_errs:
			# CONSUME shortage is allowed as ErrorInfo but conservation must stay clean.
			pass
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_WP24_csv_import_opening_population_ok() -> void:
	_wipe(OUT_POP)
	var result: Dictionary = CsvImport.run_batch_opening_population(
		FIX_POP_OK, OUT_POP, FIX_POP_OK.path_join("ports.csv")
	)
	assert_true(result["ok"], str(result.get("errors", [])))
	assert_true(FileAccess.file_exists(OUT_POP.path_join("PT-01.tres")))
	assert_true(FileAccess.file_exists(OUT_POP.path_join("PT-10.tres")))
	var op: OpeningPopulation = load(OUT_POP.path_join("PT-10.tres"))
	assert_eq(op.poor, 80)
	assert_eq(op.citizen, 30)
	assert_eq(op.rich, 5)


func test_WP24_opening_pop_missing_file_refuses() -> void:
	var result: Dictionary = CsvImport.run_batch_opening_population(
		"res://tests/fixtures/wp24_pop_missing/", OUT_POP + "miss/", FIX_POP_OK.path_join("ports.csv")
	)
	assert_false(result["ok"])
	assert_gt((result["errors"] as PackedStringArray).size(), 0)
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP24_opening_pop_duplicate_port_refuses() -> void:
	var result: Dictionary = CsvImport.run_batch_opening_population(
		FIX_POP_DUP, OUT_POP + "dup/", FIX_POP_OK.path_join("ports.csv")
	)
	assert_false(result["ok"])
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP24_opening_pop_unknown_port_refuses() -> void:
	var result: Dictionary = CsvImport.run_batch_opening_population(
		FIX_POP_BAD_PORT, OUT_POP + "bad/", FIX_POP_OK.path_join("ports.csv")
	)
	assert_false(result["ok"])
	assert_push_error_count((result["errors"] as PackedStringArray).size())


func test_WP24_ERR_SYS07_09_empty_opening_pop_dir() -> void:
	_boot_modules_only()
	var errs: Array = PopulationModel.apply_opening_init(ROOT + "empty_pop/")
	assert_gt(errs.size(), 0)
	assert_true(_has_code(errs, PopulationModel.ERR_SYS07_09))
	assert_push_error_count(errs.size())


func test_WP24_ERR_SYS07_09_missing_port() -> void:
	_boot_modules_only()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "partial_pop/"))
	var op := OpeningPopulation.new()
	op.port_id = PORT_A
	op.poor = 10
	op.citizen = 0
	op.rich = 0
	ResourceSaver.save(op, ROOT + "partial_pop/%s.tres" % PORT_A)
	var errs: Array = PopulationModel.apply_opening_init(ROOT + "partial_pop/")
	assert_true(_has_code(errs, PopulationModel.ERR_SYS07_09))
	assert_push_error_count(errs.size())


func test_WP24_ERR_SYS07_09_duplicate_port() -> void:
	_boot_modules_only()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "dup_pop/"))
	for name in ["a", "b"]:
		var op := OpeningPopulation.new()
		op.port_id = PORT_A
		op.poor = 1
		ResourceSaver.save(op, ROOT + "dup_pop/%s.tres" % name)
	var errs: Array = PopulationModel.apply_opening_init(ROOT + "dup_pop/")
	assert_true(_has_code(errs, PopulationModel.ERR_SYS07_09))
	assert_push_error_count(errs.size())


func test_WP24_ERR_SYS08_10_empty_workshops_no_writes() -> void:
	## D-87: ERR-SYS08-10 → no residences／kontor／workshops written.
	_boot_with_opening_population_only()
	var empty_ws := ROOT + "empty_ws/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_ws))
	# Public present for all ports so only workshops-empty is the trigger under test.
	_write_opening_public_all()
	var errs: Array = BuildingEconomy.apply_opening_init(
		empty_ws, ROOT + "opening_public/", PORT_HOME, ACTOR
	)
	assert_true(_has_code(errs, BuildingEconomy.ERR_SYS08_10))
	assert_eq(BuildingEconomy.residences(StringName(PORT_A)).size(), 0)
	assert_eq(BuildingEconomy.workplaces(StringName(PORT_A)).size(), 0)
	var kontor_ok := false
	for b_v in BuildingEconomy.buildings_for_port(PORT_HOME):
		if (b_v as Building).build_class == &"KONTOR" and (b_v as Building).owner == ACTOR:
			kontor_ok = true
	assert_false(kontor_ok)
	assert_eq(BuildingEconomy.buildings_for_port(PORT_A).size(), 0)
	assert_push_error_count(errs.size())


func test_WP24_ERR_SYS08_10_empty_public_no_writes() -> void:
	## D-87: ERR-SYS08-10 → no residences／kontor／workshops written.
	_boot_with_opening_population_only()
	_write_opening_workshops_all()
	var empty_pub := ROOT + "empty_pub/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_pub))
	var errs: Array = BuildingEconomy.apply_opening_init(
		ROOT + "opening/", empty_pub, PORT_HOME, ACTOR
	)
	assert_true(_has_code(errs, BuildingEconomy.ERR_SYS08_10))
	assert_eq(BuildingEconomy.residences(StringName(PORT_HOME)).size(), 0)
	assert_eq(BuildingEconomy.workplaces(StringName(PORT_HOME)).size(), 0)
	var kontor_ok := false
	for b_v in BuildingEconomy.buildings_for_port(PORT_HOME):
		if (b_v as Building).build_class == &"KONTOR" and (b_v as Building).owner == ACTOR:
			kontor_ok = true
	assert_false(kontor_ok)
	assert_eq(BuildingEconomy.buildings_for_port(PORT_HOME).size(), 0)
	assert_push_error_count(errs.size())


func test_WP24_ERR_SYS08_10_missing_port_in_workshops_no_writes() -> void:
	## D-87: missing port → error and no buildings written.
	_boot_with_opening_population_only()
	_write_opening_public_all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening/"))
	# Only PT-01 workshop — missing other PortRegistry ports.
	var ow := OpeningWorkshop.new()
	ow.port_id = PORT_A
	ow.good_id = "GD-001"
	ow.count = 1
	ResourceSaver.save(ow, ROOT + "opening/%s__GD-001.tres" % PORT_A)
	var errs: Array = BuildingEconomy.apply_opening_init(
		ROOT + "opening/", ROOT + "opening_public/", PORT_HOME, ACTOR
	)
	assert_true(_has_code(errs, BuildingEconomy.ERR_SYS08_10))
	assert_eq(BuildingEconomy.residences(StringName(PORT_A)).size(), 0)
	assert_eq(BuildingEconomy.workplaces(StringName(PORT_A)).size(), 0)
	var kontor_ok := false
	for b_v in BuildingEconomy.buildings_for_port(PORT_HOME):
		if (b_v as Building).build_class == &"KONTOR" and (b_v as Building).owner == ACTOR:
			kontor_ok = true
	assert_false(kontor_ok)
	assert_push_error_count(errs.size())


func test_WP54_V1_opening_residence_before_workshop_rings() -> void:
	## V1／FRM-SYS08-21／A9: residences on innermost open civil; IND1 on gathering belt.
	_boot_with_opening()
	var res_rings: Array = []
	for b_v in BuildingEconomy.residences(StringName(PORT_A)):
		var b: Building = b_v
		var slot: Slot = BuildingEconomy.get_slot(b.slot_id)
		assert_not_null(slot)
		assert_true(slot.zone_open)
		res_rings.append(slot.ring)
	assert_gt(res_rings.size(), 0)
	res_rings.sort()
	var ws_rings: Array = []
	for b_v2 in BuildingEconomy.workplaces(StringName(PORT_A)):
		var w: Building = b_v2
		var wslot: Slot = BuildingEconomy.get_slot(w.slot_id)
		assert_not_null(wslot)
		# IND1 gathering belt = max open zone + 1 → not zone_open.
		assert_false(wslot.zone_open)
		ws_rings.append(wslot.ring)
	assert_gt(ws_rings.size(), 0)
	ws_rings.sort()
	# Residences occupy lower rings than gathering-belt workshops.
	assert_lt(int(res_rings[res_rings.size() - 1]), int(ws_rings[0]))


func test_WP54_V1_opening_processing_outermost_ring() -> void:
	## V1／A9: IND2／3 place on outermost open civil (not innermost).
	# Custom boot so IND2 def is present at load_and_validate.
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	var goods_dir := _build_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_ports(Params.get_int(PRM_PORT_COUNT_MIN), ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	PopulationModel.set_satisfaction_input_provider(TestSat.new())
	assert_eq(PopulationModel.load_and_validate().size(), 0)
	BuildingEconomy.set_population_provider(PopulationModel.get_population_provider())
	BuildingEconomy.set_workforce_provider(PopulationModel.get_workforce_provider())
	_write_layout_multi()
	_write_defs()
	_save_def(ROOT + "buildings/", "WS-SALT", "IND2", "GD-002", 1, 1.0)
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)
	_write_opening_tres()
	var ow := OpeningWorkshop.new()
	ow.port_id = PORT_A
	ow.good_id = "GD-002"
	ow.count = 1
	ResourceSaver.save(ow, ROOT + "opening/%s__GD-002.tres" % PORT_A)
	assert_eq(PopulationModel.apply_opening_init(ROOT + "opening_population/").size(), 0)
	assert_eq(
		BuildingEconomy.apply_opening_init(
			ROOT + "opening/", ROOT + "opening_public/", PORT_HOME, ACTOR
		).size(),
		0
	)
	var open_rings: Array = []
	for s_v in BuildingEconomy.slots_for_port(PORT_A):
		var s: Slot = s_v
		if s.kind == Slot.Kind.CIVIL and s.zone_open:
			open_rings.append(s.ring)
	open_rings.sort()
	var max_open_ring: int = int(open_rings[open_rings.size() - 1])
	var found := false
	for b_v in BuildingEconomy.workplaces(StringName(PORT_A)):
		var b: Building = b_v
		if String(b.type) != "WS-SALT":
			continue
		var slot: Slot = BuildingEconomy.get_slot(b.slot_id)
		assert_eq(slot.ring, max_open_ring)
		found = true
	assert_true(found)


func test_WP54_A11_bad_opening_workshop_tres_reported() -> void:
	## A11: non-OpeningWorkshop tres in opening dir is collected, not skipped.
	_boot_with_opening_population_only()
	_write_opening_workshops_all()
	_write_opening_public_all()
	# Drop a ZoneDef into workshops dir (wrong type).
	var bad := ZoneDef.new()
	bad.port_id = PORT_A
	bad.zone = 1
	bad.rings = 1
	bad.slots = 1
	bad.open_at_start = 1
	ResourceSaver.save(bad, ROOT + "opening/ZZ_BAD.tres")
	var errs: Array = BuildingEconomy.apply_opening_init(
		ROOT + "opening/", ROOT + "opening_public/", PORT_HOME, ACTOR
	)
	assert_true(_has_code(errs, BuildingEconomy.ERR_SYS08_10))
	assert_eq(BuildingEconomy.buildings_for_port(PORT_A).size(), 0)
	assert_push_error_count(errs.size())


func test_WP24_csv_only_opening_resources() -> void:
	## AC4: CSV fixtures import to OpeningPopulation tres with row values (not mere file-exists).
	var fix := "res://tests/fixtures/wp24_opening/"
	var out := ROOT + "csv_open_res/"
	_wipe(out)
	var result: Dictionary = CsvImport.run_batch_opening_population(
		fix, out, FIX_POP_OK.path_join("ports.csv")
	)
	assert_true(result["ok"], str(result.get("errors", [])))
	var op1: OpeningPopulation = load(out.path_join("PT-01.tres")) as OpeningPopulation
	assert_ne(op1, null)
	assert_eq(op1.poor, 100)
	assert_eq(op1.citizen, 40)
	assert_eq(op1.rich, 10)
	var op10: OpeningPopulation = load(out.path_join("PT-10.tres")) as OpeningPopulation
	assert_ne(op10, null)
	assert_eq(op10.poor, 80)
	assert_eq(op10.citizen, 30)
	assert_eq(op10.rich, 5)
	## Workshop／public CSVs parse with expected row counts (behavior, not existence-only).
	var ws: Dictionary = CsvImport.import_csv(
		fix.path_join("opening_workshops.csv"), CsvImport.KIND_OPENING_WORKSHOP, false
	)
	assert_true(ws["ok"], str(ws.get("errors", [])))
	assert_eq((ws["rows"] as Array).size(), 2)
	var pub: Dictionary = CsvImport.import_csv(
		fix.path_join("opening_public.csv"), CsvImport.KIND_OPENING_PUBLIC, false
	)
	assert_true(pub["ok"], str(pub.get("errors", [])))
	assert_eq((pub["rows"] as Array).size(), 2)


# --- helpers ---


func _boot_with_opening() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	var goods_dir := _build_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_ports(Params.get_int(PRM_PORT_COUNT_MIN), ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
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
	## Cover every PortRegistry port (D-19e); PT-01／PT-10 keep fixture class counts.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening_population/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening_public/"))
	for pid_v in PortRegistry.all_ids():
		var pid: String = String(pid_v)
		var poor := 10
		var cit := 0
		var rich := 0
		var ws_n := 1
		var cb := "CB-01"
		if pid == PORT_A:
			poor = 100
			cit = 40
			rich = 10
			ws_n = 2
			cb = "CB-01"
		elif pid == PORT_HOME:
			poor = 80
			cit = 30
			rich = 5
			ws_n = 1
			cb = "CB-09"
		var op := OpeningPopulation.new()
		op.port_id = pid
		op.poor = poor
		op.citizen = cit
		op.rich = rich
		ResourceSaver.save(op, ROOT + "opening_population/%s.tres" % pid)
		var ow := OpeningWorkshop.new()
		ow.port_id = pid
		ow.good_id = "GD-001"
		ow.count = ws_n
		ResourceSaver.save(ow, ROOT + "opening/%s__GD-001.tres" % pid)
		var opub := OpeningPublic.new()
		opub.port_id = pid
		opub.cb_id = cb
		opub.level = 1
		ResourceSaver.save(opub, ROOT + "opening_public/%s__%s.tres" % [pid, cb])


func _write_opening_workshops_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening/"))
	for pid_v in PortRegistry.all_ids():
		var pid: String = String(pid_v)
		var ow := OpeningWorkshop.new()
		ow.port_id = pid
		ow.good_id = "GD-001"
		ow.count = 1 if pid != PORT_A else 2
		ResourceSaver.save(ow, ROOT + "opening/%s__GD-001.tres" % pid)


func _write_opening_public_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening_public/"))
	for pid_v in PortRegistry.all_ids():
		var pid: String = String(pid_v)
		var opub := OpeningPublic.new()
		opub.port_id = pid
		opub.cb_id = "CB-09" if pid == PORT_HOME else "CB-01"
		opub.level = 1
		ResourceSaver.save(opub, ROOT + "opening_public/%s__%s.tres" % [pid, opub.cb_id])


func _boot_modules_only() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	var goods_dir := _build_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_ports(Params.get_int(PRM_PORT_COUNT_MIN), ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
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


func _boot_with_opening_population_only() -> void:
	_boot_modules_only()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "opening_population/"))
	for pid_v in PortRegistry.all_ids():
		var pid: String = String(pid_v)
		var op := OpeningPopulation.new()
		op.port_id = pid
		op.poor = 80 if pid == PORT_HOME else (100 if pid == PORT_A else 10)
		op.citizen = 30 if pid == PORT_HOME else (40 if pid == PORT_A else 0)
		op.rich = 5 if pid == PORT_HOME else (10 if pid == PORT_A else 0)
		ResourceSaver.save(op, ROOT + "opening_population/%s.tres" % pid)
	assert_eq(PopulationModel.apply_opening_init(ROOT + "opening_population/").size(), 0)


func _has_code(errs: Array, code: StringName) -> bool:
	for e in errs:
		if String((e as Dictionary).get("code", "")) == String(code):
			return true
	return false


func _top_up_actor(need: int) -> void:
	var bal: int = CashLedger.balance(ACTOR)
	if bal >= need:
		return
	var delta: int = need - bal
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


func _write_layout_multi() -> void:
	# Every PortRegistry port needs slots so residences／workshops／public can place.
	for pid_v in PortRegistry.all_ids():
		var port: String = String(pid_v)
		_write_zone(ROOT + "zones/", port, 1, 2, 12, 1)
		_write_zone(ROOT + "zones/", port, 2, 1, 4, 0)
		_write_city(ROOT + "city_center/", port, 4)


func _write_defs() -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save_def(dir, "CB-17", "KONTOR", "", 0, 1.0)
	_save_def(dir, "RB-01", "RESIDENCE", "", 0, 1.0)
	## A12: no silent PUBLIC shells — opening_public rows need real defs.
	_save_def(dir, "CB-01", "PUBLIC", "", 0, 1.0)
	_save_def(dir, "CB-09", "PUBLIC", "", 0, 1.0)
	# Recipe-input workshop for D-19d conservation (consumes GD-002).
	var d := BuildingDef.new()
	d.type = "WS-RICE"
	d.build_class = "IND1"
	d.output_good_id = "GD-001"
	d.input1_good_id = "GD-002"
	d.input1_qty = 1.0
	d.tier = 1
	d.max_workers = 4
	d.base_output_per_worker = 1.5
	ResourceSaver.save(d, dir + "WS-RICE.tres")


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
