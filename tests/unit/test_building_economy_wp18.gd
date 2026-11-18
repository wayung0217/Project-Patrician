extends GutTest
## WP-18 / TechSpec 11-07 BuildingEconomy acceptance.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const PORT_PT01 := "PT-01"
const ACTOR := &"ACT-PLAYER"

const PRM_BASE := "PRM-SYS08-BASE_LAND_LI"
const PRM_POP_UNIT := "PRM-SYS08-POP_UNIT"
const PRM_SCARCITY_FLOOR := "PRM-SYS08-SCARCITY_FLOOR"
const PRM_RING_ALPHA := "PRM-SYS08-RING_ALPHA"

const ROOT := "user://wp18_be/"


class TestPop extends PopulationProvider:
	var _pop: Dictionary = {}

	func set_pop(port_id: String, value: int) -> void:
		_pop[port_id] = value

	func population(port_id: StringName) -> int:
		var key := String(port_id)
		if not _pop.has(key):
			return 0
		return int(_pop[key])


func before_each() -> void:
	_wipe_dir(ROOT)
	BuildingEconomy._loaded = false
	BuildingEconomy._slots = {}
	BuildingEconomy._slots_by_port = {}
	BuildingEconomy._r_by_port = {}
	BuildingEconomy._population = null


func test_TST_SYS08_01_land_price_calibration() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 3000)
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 12, 143, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 0)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	assert_eq(BuildingEconomy.ring_count_open(PORT_PT01), 12)

	# 100 empty / 143 total → scarcity ≈ 1.429
	var filled := 43
	var target: Slot = null
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = slot_variant
		if slot.kind != Slot.Kind.CIVIL:
			continue
		if slot.ring == 6 and target == null:
			target = slot
		if slot.building_id == &"" and filled > 0:
			slot.building_id = &"BLD-FILL"
			filled = filled - 1

	assert_not_null(target, "need civil slot on ring 6")
	var total := 0
	var empty := 0
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var s: Slot = slot_variant
		if s.kind == Slot.Kind.CIVIL and s.zone == target.zone:
			total = total + 1
			if s.building_id == &"":
				empty = empty + 1
	var ratio: float = float(empty) / float(total)
	var floor_v: float = Params.get_float(PRM_SCARCITY_FLOOR)
	var denom: float = ratio
	if denom < floor_v:
		denom = floor_v
	var scarcity: float = 1.0 / denom
	var price: int = BuildingEconomy.land_price(target.slot_id)
	var base: float = float(Params.get_int(PRM_BASE))
	var pop_u: float = float(Params.get_int(PRM_POP_UNIT))
	var alpha: float = Params.get_float(PRM_RING_ALPHA)
	var mid: float = base * sqrt(3000.0 / pop_u) * scarcity * pow(7.0, alpha)
	var expect: int = ceili(AmountQuantize.quantize_amount(mid))
	assert_eq(price, expect)


func test_TST_SYS08_02_closed_zone_buy_land() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 2, 4, 0)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 0)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	var slot_id: StringName = _first_civil_slot()
	var cash_before: int = CashLedger.balance(ACTOR)
	var seq: int = BuildingEconomy.buy_land(ACTOR, slot_id)
	assert_eq(seq, 0)
	var err: Dictionary = BuildingEconomy.last_error()
	assert_eq(StringName(err.get(ErrorInfoUtil.KEY_CODE, &"")), BuildingEconomy.ERR_SYS08_01)
	assert_eq(CashLedger.balance(ACTOR), cash_before)
	assert_eq(BuildingEconomy.get_slot(slot_id).land_owner, CashLedger.make_city_id(PORT_PT01))


func test_WP18_11_07_1_zone_slot_totals() -> void:
	var pop := TestPop.new()
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 4, 97, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 2)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	var civil := 0
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = slot_variant
		if slot.kind == Slot.Kind.CIVIL:
			civil = civil + 1
	assert_eq(civil, 97)


func test_WP18_11_07_2_97_slots_four_rings_25_24_24_24() -> void:
	var pop := TestPop.new()
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 4, 97, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 0)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	var by_ring: Dictionary = {}
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = slot_variant
		if slot.kind != Slot.Kind.CIVIL:
			continue
		var r: int = slot.ring
		by_ring[r] = int(by_ring.get(r, 0)) + 1
	assert_eq(int(by_ring.get(1, 0)), 25)
	assert_eq(int(by_ring.get(2, 0)), 24)
	assert_eq(int(by_ring.get(3, 0)), 24)
	assert_eq(int(by_ring.get(4, 0)), 24)


func test_WP18_11_07_3_slot_id_format_order() -> void:
	var pop := TestPop.new()
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 1, 2, 3, 1)
	_write_zone(ROOT + "zones/", PORT_PT01, 2, 1, 2, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 1)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	var ids: Array = []
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		ids.append(String((slot_variant as Slot).slot_id))
	var re := RegEx.new()
	re.compile("^SLOT:PT-01:\\d{4}$")
	for id_s in ids:
		assert_true(re.search(String(id_s)) != null, id_s)
	assert_eq(ids[0], "SLOT:PT-01:0001")
	assert_eq(ids.size(), 3 + 2 + 1 + Params.get_int("PRM-SYS08-KONTOR_PLOTS"))


func test_WP18_11_07_4_public_kontor_counts() -> void:
	var pop := TestPop.new()
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 1, 1, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 4)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	var pub := 0
	var kon := 0
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = slot_variant
		if slot.kind == Slot.Kind.PUBLIC:
			pub = pub + 1
		if slot.kind == Slot.Kind.KONTOR:
			kon = kon + 1
	assert_eq(pub, 4)
	assert_eq(kon, Params.get_int("PRM-SYS08-KONTOR_PLOTS"))


func test_WP18_11_07_5_ring_scarcity_price_direction() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 3, 9, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 0)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	var ring_prices: Dictionary = {}
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = slot_variant
		if slot.kind != Slot.Kind.CIVIL:
			continue
		if not ring_prices.has(slot.ring):
			ring_prices[slot.ring] = BuildingEconomy.land_price(slot.slot_id)
	assert_gt(int(ring_prices[1]), int(ring_prices[3]))


func test_WP18_11_07_6_buy_land_post_and_owner() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 2, 4, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 0)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	var slot_id: StringName = _first_civil_slot()
	var price: int = BuildingEconomy.land_price(slot_id)
	var city: StringName = CashLedger.make_city_id(PORT_PT01)
	var city_before: int = 0
	if CashLedger.has_method("balance"):
		CashLedger.create_account(city, Account.Kind.CITY)
		city_before = CashLedger.balance(city)
	var got_seq := 0
	BuildingEconomy.land_bought.connect(func(_a, _s, seq: int): got_seq = seq)
	var seq: int = BuildingEconomy.buy_land(ACTOR, slot_id)
	assert_gt(seq, 0)
	assert_eq(seq, got_seq)
	assert_eq(BuildingEconomy.get_slot(slot_id).land_owner, ACTOR)
	assert_eq(CashLedger.balance(ACTOR), Params.get_int(CashLedger.PRM_START_CASH) - price)
	assert_eq(CashLedger.balance(city), city_before + price)


func test_WP18_11_07_7_err08_err02_err07() -> void:
	var pop := TestPop.new()
	pop.set_pop(PORT_PT01, 1000)
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 2, 4, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 0)
	_load_be(ROOT + "zones/", ROOT + "city_center/")

	var seq0: int = BuildingEconomy.buy_land(ACTOR, &"SLOT:PT-01:9999")
	assert_eq(seq0, 0)
	assert_eq(
		StringName(BuildingEconomy.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		BuildingEconomy.ERR_SYS08_08
	)

	var slot_id: StringName = _first_civil_slot()
	assert_gt(BuildingEconomy.buy_land(ACTOR, slot_id), 0)
	var seq2: int = BuildingEconomy.buy_land(ACTOR, slot_id)
	assert_eq(seq2, 0)
	assert_eq(
		StringName(BuildingEconomy.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		BuildingEconomy.ERR_SYS08_02
	)

	var broke := &"ACT-BROKE"
	CashLedger.create_account(broke, Account.Kind.ACTOR)
	var slot2: StringName = &""
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = slot_variant
		if slot.kind == Slot.Kind.CIVIL and slot.land_owner == CashLedger.make_city_id(PORT_PT01):
			slot2 = slot.slot_id
			break
	var seq3: int = BuildingEconomy.buy_land(broke, slot2)
	assert_eq(seq3, 0)
	assert_eq(
		StringName(BuildingEconomy.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		BuildingEconomy.ERR_SYS08_07
	)


func test_WP18_11_07_8_no_population_provider_boot_error() -> void:
	var fixtures := _prepare_sim_fixtures()
	SimLoop._booted = false
	SimLoop.set_consumption_provider(_SimCons.new())
	var errors: Array = SimLoop.boot(
		PARAMS_FIXTURE, fixtures["goods"], fixtures["ports"], "res://tests/fixtures/price_curve.tres"
	)
	assert_gt(errors.size(), 0)
	assert_true(_has_code(errors, BuildingEconomy.CODE_POPULATION_PROVIDER_MISSING))
	assert_false(SimLoop.is_booted())


func test_WP18_11_07_9_warehouse_capacity_empty() -> void:
	var pop := TestPop.new()
	_setup_core(pop)
	_write_zone(ROOT + "zones/", PORT_PT01, 0, 1, 1, 1)
	_write_city_center(ROOT + "city_center/", PORT_PT01, 0)
	_load_be(ROOT + "zones/", ROOT + "city_center/")
	assert_eq(BuildingEconomy.warehouse_capacity(ACTOR, StringName(PORT_PT01)), 0)
	var wh: Dictionary = GoodsLedger.make_warehouse(String(ACTOR), PORT_PT01)
	assert_eq(BuildingEconomy.get_warehouse_capacity_provider().capacity(wh), 0)
	assert_eq(BuildingEconomy.workplaces(StringName(PORT_PT01)).size(), 0)


func _setup_core(pop: TestPop) -> void:
	var perr: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(perr.size(), 0)
	var port_count: int = Params.get_int("PRM-SYS02-PORT_COUNT_MIN")
	var ports_dir := _build_ports(port_count, ROOT + "ports/")
	var gerr: Array = GoodCatalog.load_and_validate(_build_goods(ROOT + "goods/"))
	assert_eq(gerr.size(), 0)
	var perr2: Array = PortRegistry.load_and_validate(ports_dir)
	assert_eq(perr2.size(), 0)
	var gled: Array = GoodsLedger.load_and_validate()
	assert_eq(gled.size(), 0)
	var cl: Array = CashLedger.load_and_validate()
	assert_eq(cl.size(), 0)
	assert_eq(CashLedger.genesis_grant(), OK)
	BuildingEconomy.set_population_provider(pop)


func _load_be(zones_dir: String, city_dir: String) -> void:
	var errors: Array = BuildingEconomy.load_and_validate(zones_dir, city_dir)
	assert_eq(errors.size(), 0, str(errors))


func _write_zone(
	dir: String,
	port_id: String,
	zone: int,
	rings: int,
	slots: int,
	open_at: int
) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var z := ZoneDef.new()
	z.port_id = port_id
	z.zone = zone
	z.slot_share = 0.5
	z.rings = rings
	z.slots = slots
	z.open_at_start = open_at
	var path := dir + "%s__%d.tres" % [port_id, zone]
	ResourceSaver.save(z, path)


func _write_city_center(dir: String, port_id: String, public_slots: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var c := CityCenterDef.new()
	c.port_id = port_id
	c.public_slots = public_slots
	ResourceSaver.save(c, dir + port_id + ".tres")


func _first_civil_slot() -> StringName:
	for slot_variant in BuildingEconomy.slots_for_port(PORT_PT01):
		var slot: Slot = slot_variant
		if slot.kind == Slot.Kind.CIVIL:
			return slot.slot_id
	return &""


func _build_goods(dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var g := GoodDef.new()
	g.good_id = "GD-001"
	g.name_zh = "米"
	g.tier = 1
	g.is_staple = true
	g.is_build_material = false
	g.is_strategic = false
	g.base_price_li = 1000
	g.season_mask = 0
	ResourceSaver.save(g, dir + "GD-001.tres")
	return dir


func _build_ports(count: int, dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for i in range(count):
		var id := "PT-%02d" % (i + 1)
		var p := PortDef.new()
		p.port_id = id
		p.name_zh = "港"
		p.is_free_port = false
		p.draft_limit_class = 0
		p.regime_id = "REG-01"
		ResourceSaver.save(p, dir + id + ".tres")
	return dir


func _prepare_sim_fixtures() -> Dictionary:
	Params.load_and_validate(PARAMS_FIXTURE)
	var goods := _build_goods(ROOT + "sim_goods/")
	GoodCatalog.load_and_validate(goods)
	var ports := _build_ports(1, ROOT + "sim_ports/")
	return {"goods": goods, "ports": ports}


func _has_code(errors: Array, code: String) -> bool:
	for e in errors:
		if typeof(e) == TYPE_DICTIONARY:
			var c: Variant = e.get("code", e.get(ErrorInfoUtil.KEY_CODE, ""))
			if String(c) == code or StringName(c) == StringName(code):
				return true
	return false


class _SimCons extends ConsumptionProvider:
	func weekly_consumption(_port_id: StringName, _good_id: StringName) -> int:
		return 0

	func consume_qty(_port_id: StringName, _good_id: StringName, _day: int) -> int:
		return 0


func _wipe_dir(rel: String) -> void:
	var abs := ProjectSettings.globalize_path(rel)
	if DirAccess.dir_exists_absolute(abs):
		var dir := DirAccess.open(abs)
		if dir != null:
			dir.list_dir_begin()
			while true:
				var n := dir.get_next()
				if n == "":
					break
				if n == "." or n == "..":
					continue
				var path := abs.path_join(n)
				if dir.current_is_dir():
					_wipe_dir(rel.path_join(n))
					DirAccess.remove_absolute(path)
				else:
					DirAccess.remove_absolute(path)
			dir.list_dir_end()