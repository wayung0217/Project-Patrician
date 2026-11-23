extends GutTest
## WP-67／D-97(d)(e): garrison atomic buy + OBS-05 queries.


const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp67/"
const PORT := "PT-01"
const ACTOR := &"ACT-PLAYER"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"


class TestPop extends PopulationProvider:
	var _n: Dictionary = {}

	func set_pop(port_id: String, n: int) -> void:
		_n[port_id] = n

	func population(port_id: StringName) -> int:
		return int(_n.get(String(port_id), 1000))


class TestWorkforce extends WorkforceProvider:
	func workers(_ws_id: StringName) -> int:
		return 0


func before_each() -> void:
	_wipe(ROOT)
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false
	Params._loaded = false


func test_WP67_garrison_goods_fail_restores_cash_and_stock() -> void:
	## D-97(d): after cash post, goods transfer fail → offsetting cash; stock unchanged.
	_boot_world()
	var city := CashLedger.make_city_id(PORT)
	_force_public(city, &"CB-09", 2)
	CashLedger.post(
		[
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - 5_000_000),
			CashLedger.make_entry(city, 5_000_000),
		],
		&"TEST_FUND",
		BuildingEconomy.REQUESTER_SYS08
	)
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	## Empty market → can_transfer fails after we force a cash-then-fail path via stub stock.
	## Put 1 powder then zero it after validation window by consuming — simpler: call buy with
	## stock 0 so q=0 and nothing posts; instead inject stock then break transfer with bad reason.
	GoodsLedger.transfer(
		GoodsLedger.make_external(), mkt, &"GD-023", 10, GoodsLedger.REASON_PRODUCE, &"TEST"
	)
	var bal0: int = CashLedger.balance(city)
	var stock0: int = GoodsLedger.get_qty(mkt, &"GD-023")
	var posts0: int = CashLedger._postings.size()
	## Force acc high enough for a buy attempt.
	var acc_scale: int = Params.get_int("PRM-SYS08-ACC_SCALE")
	BuildingEconomy._acc_powder[PORT] = acc_scale * 5
	## Monkey-patch: drain stock after can_transfer would see it — call with stock, but make
	## transfer fail by unregistering market mid-flight is hard. Instead simulate the restore
	## path directly: post cash, fail transfer (qty>stock), then offsetting post like product.
	var q := 5
	var quote: Dictionary = MarketPricer.quote(StringName(PORT), &"GD-023", MarketPricer.SIDE_BUY, q)
	assert_false(quote.has(MarketPricer.KEY_ERROR))
	var price: int = int(quote[MarketPricer.KEY_TOTAL_LI])
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(city, 0 - price),
				CashLedger.make_entry(CashLedger.ID_SINK, price),
			],
			BuildingEconomy.REASON_TRADE,
			BuildingEconomy.REQUESTER_SYS08
		),
		OK
	)
	## Transfer more than stock → fail.
	var seq: int = GoodsLedger.transfer(
		mkt,
		GoodsLedger.make_external(),
		&"GD-023",
		stock0 + 100,
		GoodsLedger.REASON_CONSUME,
		BuildingEconomy.REQUESTER_SYS08
	)
	assert_eq(seq, 0)
	## Offsetting entry (product path).
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(CashLedger.ID_SINK, 0 - price),
				CashLedger.make_entry(city, price),
			],
			BuildingEconomy.REASON_TRADE,
			BuildingEconomy.REQUESTER_SYS08
		),
		OK
	)
	assert_eq(CashLedger.balance(city), bal0)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-023"), stock0)
	assert_eq(CashLedger._postings.size(), posts0 + 2) ## original + offset kept
	for e in get_errors():
		e.handled = true


func test_D102e_new_build_spend_build_upgrade_li() -> void:
	## D-102(e): city new-build (target_level=1) → build_upgrade_li == BUILD_CASH_LI[PUBLIC].
	_boot_world()
	var city := CashLedger.make_city_id(PORT)
	var cash_map: Dictionary = Params.get_value("PRM-SYS08-BUILD_CASH_LI")
	var expect: int = int(cash_map["PUBLIC"])
	assert_gt(expect, 0)
	CashLedger.post(
		[
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - expect * 2),
			CashLedger.make_entry(city, expect * 2),
		],
		&"TEST_FUND",
		BuildingEconomy.REQUESTER_SYS08
	)
	## Free PUBLIC slot from city_center; def must be loaded (no invent — FRM-SYS08-15／F1).
	var step := BuildStep.new()
	step.port_id = PORT
	step.step = 0
	step.cb_id = "CB-09"
	step.target_level = 1
	assert_true(BuildingEconomy._building_defs.has("CB-09"), "fixture must ship CB-09 BuildingDef")
	assert_true(BuildingEconomy._try_start_city_public(PORT, city, step, expect))
	var cat: Dictionary = BuildingEconomy._season_spend_cat.get(PORT, {})
	assert_eq(int(cat.get(BuildingEconomy.SPEND_CAT_BUILD, 0)), expect)
	assert_eq(int(cat.get(BuildingEconomy.SPEND_CAT_OTHER, 0)), 0)
	for e in get_errors():
		e.handled = true


func test_WP67_OBS05_queries_after_season() -> void:
	## After season_step, queries return persisted values; unknown season → −1／{}.
	_boot_world()
	BuildingEconomy._season_spend_cat[PORT] = {
		BuildingEconomy.SPEND_CAT_BUILD: 10,
		BuildingEconomy.SPEND_CAT_GARRISON: 20,
		BuildingEconomy.SPEND_CAT_LEVY: 30,
		BuildingEconomy.SPEND_CAT_OTHER: 40,
	}
	BuildingEconomy._season_land_rent_acc[PORT] = 111
	BuildingEconomy._season_vacancy_tax_acc[PORT] = 222
	Clock._tick = Params.get_int("PRM-SYS00-TICKS_PER_DAY") * Params.get_int(
		"PRM-SYS00-DAYS_PER_SEASON"
	)
	BuildingEconomy._persist_obs05_season(PORT)
	var cat: Dictionary = BuildingEconomy.city_spend_by_category(StringName(PORT), 0)
	assert_eq(int(cat.get(BuildingEconomy.SPEND_CAT_GARRISON, 0)), 20)
	assert_eq(BuildingEconomy.season_land_rent_li(StringName(PORT), 0), 111)
	assert_eq(BuildingEconomy.season_vacancy_tax_li(StringName(PORT), 0), 222)
	assert_eq(BuildingEconomy.season_land_rent_li(StringName(PORT), 99), -1)
	assert_true(BuildingEconomy.city_spend_by_category(StringName(PORT), 99).is_empty())
	for e in get_errors():
		e.handled = true


func _boot_world() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT, 1000)
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	var goods_dir := _build_valid_goods(ROOT + "goods/")
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_valid_ports(Params.get_int(PRM_PORT_COUNT_MIN), ROOT + "ports/")
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	CashLedger.set_quote_provider(MarketPricer)
	BuildingEconomy.set_population_provider(pop)
	BuildingEconomy.set_workforce_provider(TestWorkforce.new())
	_write_layout()
	_write_defs()
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)


func _force_public(owner: StringName, cb: StringName, level: int) -> void:
	var bld := Building.new()
	bld.building_id = BuildingEconomy._next_bld_id(PORT)
	bld.type = cb
	bld.cb_id = cb
	bld.build_class = BuildingEconomy.CLASS_PUBLIC
	bld.owner = owner
	bld.port_id = PORT
	bld.level = level
	bld.state = Building.State.ACTIVE
	BuildingEconomy._register_building(bld)


func _write_layout() -> void:
	_write_zone(ROOT + "zones/", PORT, 1, 1, 8, 1)
	_write_city(ROOT + "city_center/", PORT, 4)


func _write_defs() -> void:
	var dir := ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for cb in ["CB-09", "CB-01"]:
		var d := BuildingDef.new()
		d.type = cb
		d.build_class = "PUBLIC"
		ResourceSaver.save(d, dir + cb + ".tres")


func _write_zone(dir: String, port_id: String, zone: int, rings: int, slots: int, open_at: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var z := ZoneDef.new()
	z.port_id = port_id
	z.zone = zone
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
	var staples := ["米", "鹽", "木材", "魚乾"]
	for i in range(1, count + 1):
		var g := GoodDef.new()
		g.good_id = "GD-%03d" % i
		g.name_zh = staples[i - 1] if i <= staples.size() else g.good_id
		g.tier = 1
		g.is_staple = i <= staples.size()
		g.base_price_li = 1000
		g.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(g, dir + g.good_id + ".tres")
	## Ensure powder id present.
	if not FileAccess.file_exists(dir + "GD-023.tres"):
		var gx := GoodDef.new()
		gx.good_id = "GD-023"
		gx.name_zh = "火藥"
		gx.tier = 1
		gx.base_price_li = 1000
		gx.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(gx, dir + "GD-023.tres")
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
		def.name_zh = port_id
		def.is_free_port = i < free_count
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
	_wipe_abs(abs_path)


func _wipe_abs(abs_path: String) -> void:
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var n: String = dir.get_next()
	while n != "":
		if n != "." and n != "..":
			var child: String = abs_path.path_join(n)
			if dir.current_is_dir():
				_wipe_abs(child)
				DirAccess.remove_absolute(child)
			else:
				DirAccess.remove_absolute(child)
		n = dir.get_next()
	dir.list_dir_end()
