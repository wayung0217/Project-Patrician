extends GutTest
## WP-63／EX-08-14／EX-08-18：工坊基準價毛利、D-92a 城防、D-96d reverse、ERR-SYS08-09.


const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp63_frm/"
const PORT := "PT-01"
const ACTOR := &"ACT-PLAYER"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"


class TestPop extends PopulationProvider:
	var _n: Dictionary = {}

	func set_pop(port_id: String, n: int) -> void:
		_n[port_id] = n

	func population(port_id: StringName) -> int:
		return int(_n.get(String(port_id), 1000))


class TestWorkforce extends WorkforceProvider:
	var _w: Dictionary = {}

	func set_workers(ws_id: StringName, n: int) -> void:
		_w[String(ws_id)] = n

	func workers(ws_id: StringName) -> int:
		return int(_w.get(String(ws_id), 0))


func before_each() -> void:
	_wipe(ROOT)
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	PortRegistry._loaded = false
	GoodCatalog._loaded = false
	GoodsLedger._loaded = false
	CashLedger._loaded = false
	MarketPricer._loaded = false


func test_EX_08_14_01_garrison_fraction_carry_three_days() -> void:
	## EX-08-14-01：駐軍 150、ARMS=0.07 → 日加 1.5 擔；買量 [1,2,1]、餘 [0.5,0,0.5].
	_boot_world()
	Params._values["PRM-SYS08-ARMS_PER_SOLDIER_WK"] = 0.07
	Params._values["PRM-SYS08-POWDER_PER_SOLDIER_WK"] = 0.07
	var city := CashLedger.make_city_id(PORT)
	_force_public(city, &"CB-09", 2)
	_fund_city(city, 50_000_000)
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	GoodsLedger.transfer(
		GoodsLedger.make_external(), mkt, &"GD-026", 100, GoodsLedger.REASON_PRODUCE, &"TEST"
	)
	var acc_scale: int = Params.get_int("PRM-SYS08-ACC_SCALE")
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	var thresh: int = days_pw * acc_scale
	var buys: Array = []
	var rems: Array = []
	var stock0: int = GoodsLedger.get_qty(mkt, &"GD-026")
	for d in range(1, 4):
		var before: int = GoodsLedger.get_qty(mkt, &"GD-026")
		assert_eq(BuildingEconomy.daily_step(d).size(), 0)
		var after: int = GoodsLedger.get_qty(mkt, &"GD-026")
		buys.append(before - after)
		rems.append(float(int(BuildingEconomy._acc_arms.get(PORT, 0))) / float(thresh))
	assert_eq(buys, [1, 2, 1])
	assert_eq(rems[0], 0.5)
	assert_eq(rems[1], 0.0)
	assert_eq(rems[2], 0.5)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-026"), stock0 - 4)
	_consume_max_affordable_quote_errors()


func test_EX_08_14_02_garrison_no_stock_keeps_fraction() -> void:
	## EX-08-14-02：第 1 日庫存 0 → 買 0、餘 0.5；第 2 日補貨買 2、餘 0.
	_boot_world()
	Params._values["PRM-SYS08-ARMS_PER_SOLDIER_WK"] = 0.07
	Params._values["PRM-SYS08-POWDER_PER_SOLDIER_WK"] = 0.07
	var city := CashLedger.make_city_id(PORT)
	_force_public(city, &"CB-09", 2)
	_fund_city(city, 50_000_000)
	var acc_scale: int = Params.get_int("PRM-SYS08-ACC_SCALE")
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	var thresh: int = days_pw * acc_scale
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-026"), 0)
	assert_eq(float(int(BuildingEconomy._acc_arms.get(PORT, 0))) / float(thresh), 0.5)
	GoodsLedger.transfer(
		GoodsLedger.make_external(), mkt, &"GD-026", 100, GoodsLedger.REASON_PRODUCE, &"TEST"
	)
	var before: int = GoodsLedger.get_qty(mkt, &"GD-026")
	assert_eq(BuildingEconomy.daily_step(2).size(), 0)
	assert_eq(before - GoodsLedger.get_qty(mkt, &"GD-026"), 2)
	assert_eq(int(BuildingEconomy._acc_arms.get(PORT, 0)), 0)
	_consume_max_affordable_quote_errors()


func test_EX_08_14_03_garrison_zero_afford_same_as_no_stock() -> void:
	## EX-08-14-03：CITY 可負擔 0 → 同庫存不足（買 0、餘 0.5）.
	_boot_world()
	Params._values["PRM-SYS08-ARMS_PER_SOLDIER_WK"] = 0.07
	Params._values["PRM-SYS08-POWDER_PER_SOLDIER_WK"] = 0.07
	var city := CashLedger.make_city_id(PORT)
	_force_public(city, &"CB-09", 2)
	## Leave city at 0 cash (no fund).
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	GoodsLedger.transfer(
		GoodsLedger.make_external(), mkt, &"GD-026", 100, GoodsLedger.REASON_PRODUCE, &"TEST"
	)
	var acc_scale: int = Params.get_int("PRM-SYS08-ACC_SCALE")
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	var thresh: int = days_pw * acc_scale
	var stock0: int = GoodsLedger.get_qty(mkt, &"GD-026")
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	assert_eq(GoodsLedger.get_qty(mkt, &"GD-026"), stock0)
	assert_eq(float(int(BuildingEconomy._acc_arms.get(PORT, 0))) / float(thresh), 0.5)


func test_EX_08_14_04_garrison_season_reset() -> void:
	## EX-08-14-04：季末歸零；新季第 1 日 acc＝1.5、買 1、餘 0.5.
	_boot_world()
	Params._values["PRM-SYS08-ARMS_PER_SOLDIER_WK"] = 0.07
	Params._values["PRM-SYS08-POWDER_PER_SOLDIER_WK"] = 0.07
	var city := CashLedger.make_city_id(PORT)
	_force_public(city, &"CB-09", 2)
	_fund_city(city, 50_000_000)
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	GoodsLedger.transfer(
		GoodsLedger.make_external(), mkt, &"GD-026", 100, GoodsLedger.REASON_PRODUCE, &"TEST"
	)
	var acc_scale: int = Params.get_int("PRM-SYS08-ACC_SCALE")
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	var thresh: int = days_pw * acc_scale
	assert_eq(BuildingEconomy.daily_step(1).size(), 0)
	assert_eq(float(int(BuildingEconomy._acc_arms.get(PORT, 0))) / float(thresh), 0.5)
	BuildingEconomy.set_build_queue(PORT, [])
	BuildingEconomy.season_step()
	assert_eq(int(BuildingEconomy._acc_arms.get(PORT, 0)), 0)
	var before: int = GoodsLedger.get_qty(mkt, &"GD-026")
	assert_eq(BuildingEconomy.daily_step(2).size(), 0)
	assert_eq(before - GoodsLedger.get_qty(mkt, &"GD-026"), 1)
	assert_eq(float(int(BuildingEconomy._acc_arms.get(PORT, 0))) / float(thresh), 0.5)
	_consume_max_affordable_quote_errors()


func test_EX_08_14_05_garrison_trial_params_buy_on_day_14() -> void:
	## EX-08-14-05：駐軍 50、RATE=0.01 → 第 14 日累滿 1 擔並買入.
	_boot_world()
	## Fixture already ARMS=0.01；L1 barracks → soldiers 50.
	var city := CashLedger.make_city_id(PORT)
	_force_public(city, &"CB-09", 1)
	_fund_city(city, 50_000_000)
	var mkt: Dictionary = GoodsLedger.make_market(PORT)
	GoodsLedger.transfer(
		GoodsLedger.make_external(), mkt, &"GD-026", 100, GoodsLedger.REASON_PRODUCE, &"TEST"
	)
	var bought := false
	var buy_day := 0
	for d in range(1, 31):
		var before: int = GoodsLedger.get_qty(mkt, &"GD-026")
		assert_eq(BuildingEconomy.daily_step(d).size(), 0)
		var after: int = GoodsLedger.get_qty(mkt, &"GD-026")
		if after < before:
			bought = true
			buy_day = d
			assert_eq(before - after, 1)
			break
	assert_true(bought)
	assert_eq(buy_day, 14)
	_consume_max_affordable_quote_errors()


func test_EX_08_18_01_rice_workshop_gross() -> void:
	## EX-08-18-01：IB-01 滿編；週毛利 34404.
	var wf := TestWorkforce.new()
	_boot_world(wf)
	_set_good_price("GD-001", 1000)
	var bid: StringName = _spawn_typed_workshop("IB-01", "IND1", "GD-001", 3.252, "", 0.0)
	wf.set_workers(bid, 25)
	var bld: Building = BuildingEconomy.get_building(bid)
	assert_eq(BuildingEconomy._weekly_income_estimate(bld), 34404)


func test_EX_08_18_02_wine_workshop_gross() -> void:
	## EX-08-18-02：IB-16 米酒；週毛利 113460.
	var wf := TestWorkforce.new()
	_boot_world(wf)
	_set_good_price("GD-001", 1000)
	_ensure_good("GD-016", 2500)
	var bid: StringName = _spawn_typed_workshop("IB-16", "IND2", "GD-016", 3.5, "GD-001", 1.5)
	wf.set_workers(bid, 20)
	var bld: Building = BuildingEconomy.get_building(bid)
	assert_eq(BuildingEconomy._weekly_income_estimate(bld), 113460)


func test_EX_08_18_03_zero_workers() -> void:
	## EX-08-18-03：workers＝0 → 全 0.
	var wf := TestWorkforce.new()
	_boot_world(wf)
	_ensure_good("GD-016", 2500)
	var bid: StringName = _spawn_typed_workshop("IB-16", "IND2", "GD-016", 3.5, "GD-001", 1.5)
	wf.set_workers(bid, 0)
	assert_eq(BuildingEconomy._weekly_income_estimate(BuildingEconomy.get_building(bid)), 0)


func test_EX_08_18_04_salt_floor_revenue() -> void:
	## EX-08-18-04：鹽收入 floori(119023.2)＝119023；毛利 27523.
	var wf := TestWorkforce.new()
	_boot_world(wf)
	_set_good_price("GD-002", 1200)
	var bid: StringName = _spawn_typed_workshop("IB-02", "IND1", "GD-002", 2.71, "", 0.0)
	wf.set_workers(bid, 20)
	assert_eq(BuildingEconomy._weekly_income_estimate(BuildingEconomy.get_building(bid)), 27523)


func test_EX_08_18_05_negative_gross_not_clamped() -> void:
	## EX-08-18-05／D-102(b)：WAGE_BASE=10000 → 毛利 −308721；quote/buy → ERR-SYS08-14.
	var wf := TestWorkforce.new()
	_boot_world(wf)
	Params._values["PRM-SYS08-WAGE_BASE_LI"] = 10000
	_set_good_price("GD-001", 1000)
	var bid: StringName = _spawn_typed_workshop("IB-01", "IND1", "GD-001", 3.252, "", 0.0)
	wf.set_workers(bid, 25)
	var bld: Building = BuildingEconomy.get_building(bid)
	var inc: int = BuildingEconomy._weekly_income_estimate(bld)
	assert_eq(inc, -308721)
	## City-owned so quote／buy path runs; negative gross → fail + ERR-SYS08-14（not free）.
	bld.owner = CashLedger.make_city_id(PORT)
	assert_eq(BuildingEconomy.quote_city_building(bid), 0)
	var qerr: Variant = BuildingEconomy.last_error()
	assert_typeof(qerr, TYPE_DICTIONARY)
	assert_eq(String((qerr as Dictionary).get("code", "")), "ERR-SYS08-14")
	assert_eq(BuildingEconomy.buy_city_building(ACTOR, bid), 0)
	var berr: Variant = BuildingEconomy.last_error()
	assert_typeof(berr, TYPE_DICTIONARY)
	assert_eq(String((berr as Dictionary).get("code", "")), "ERR-SYS08-14")
	assert_eq(bld.owner, CashLedger.make_city_id(PORT))


func test_R9_65_C1_negative_margin_buy_fails() -> void:
	## R9-65／D-102(b)：週毛利 < 0 → ERR-SYS08-14；不得 0 元成交.
	var wf := TestWorkforce.new()
	_boot_world(wf)
	Params._values["PRM-SYS08-WAGE_BASE_LI"] = 10000
	_set_good_price("GD-001", 1000)
	var bid: StringName = _spawn_typed_workshop("IB-01", "IND1", "GD-001", 3.252, "", 0.0)
	wf.set_workers(bid, 25)
	var bld: Building = BuildingEconomy.get_building(bid)
	bld.owner = CashLedger.make_city_id(PORT)
	assert_lt(BuildingEconomy._weekly_income_estimate(bld), 0)
	assert_eq(BuildingEconomy.quote_city_building(bid), 0)
	assert_eq(String((BuildingEconomy.last_error() as Dictionary).get("code", "")), "ERR-SYS08-14")
	assert_eq(BuildingEconomy.buy_city_building(ACTOR, bid), 0)
	assert_eq(String((BuildingEconomy.last_error() as Dictionary).get("code", "")), "ERR-SYS08-14")
	assert_eq(bld.owner, CashLedger.make_city_id(PORT))


func test_WP63_TST_reverse_last_post_keeps_original() -> void:
	## D-96d：reverse 保留原分錄、只追加沖銷；Σ＝0.
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	var n0: int = CashLedger._postings.size()
	assert_eq(
		CashLedger.post(
			[
				CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - 5000),
				CashLedger.make_entry(ACTOR, 5000),
			],
			&"TEST_TRADE",
			&"SYS-04"
		),
		OK
	)
	var n1: int = CashLedger._postings.size()
	assert_eq(n1, n0 + 1)
	var orig_id: int = (CashLedger._postings[n1 - 1] as Posting).posting_id
	assert_eq(CashLedger.reverse_last_post(&"SYS-04"), OK)
	var n2: int = CashLedger._postings.size()
	assert_eq(n2, n1 + 1)
	assert_eq((CashLedger._postings[n1 - 1] as Posting).posting_id, orig_id)
	assert_eq(CashLedger.balance(ACTOR), 0)
	assert_eq(CashLedger.sum_all_balances(), 0)


func test_WP63_TST_public_upgrade_cash_oob_err_sys08_09() -> void:
	## WP-63 (g)：等級越界 → ERR-SYS08-09，不得回 0.
	_boot_world()
	var rc: int = BuildingEconomy._public_upgrade_cash(PORT, 99)
	assert_eq(rc, BuildingEconomy.PUBLIC_UPGRADE_CASH_FAIL)
	assert_eq(String(BuildingEconomy.last_error().get("code", "")), String(BuildingEconomy.ERR_SYS08_09))
	assert_push_error_count(1)


# --- helpers ---


func _consume_max_affordable_quote_errors() -> void:
	## max_affordable_qty binary-search may probe qty>stock → ERR-SYS04-06 (WP-56 A18).
	for e in get_errors():
		e.handled = true


func _boot_world(wf: WorkforceProvider = null) -> void:
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
	GoodsLedger.register_capacity_provider(
		StringName(GoodsLedger.KIND_WAREHOUSE), BuildingEconomy.get_warehouse_capacity_provider()
	)
	BuildingEconomy.set_population_provider(pop)
	if wf == null:
		wf = TestWorkforce.new()
	BuildingEconomy.set_workforce_provider(wf)
	_write_layout()
	_write_defs()
	assert_eq(
		BuildingEconomy.load_and_validate(ROOT + "zones/", ROOT + "city_center/", ROOT + "buildings/").size(),
		0
	)


func _fund_city(city: StringName, amt: int) -> void:
	CashLedger.post(
		[
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - amt),
			CashLedger.make_entry(city, amt),
		],
		&"TEST_FUND",
		BuildingEconomy.REQUESTER_SYS08
	)


func _force_public(owner: StringName, cb: StringName, level: int) -> void:
	var slot_id: StringName = &""
	for s_v in BuildingEconomy.slots_for_port(PORT):
		var s: Slot = s_v
		if s.kind == Slot.Kind.PUBLIC and s.building_id == &"":
			slot_id = s.slot_id
			break
	assert_ne(slot_id, &"")
	var bld := Building.new()
	bld.building_id = BuildingEconomy._next_bld_id(PORT)
	bld.type = cb
	bld.build_class = &"PUBLIC"
	bld.cb_id = cb
	bld.owner = owner
	bld.port_id = PORT
	bld.slot_id = slot_id
	bld.level = level
	bld.state = Building.State.ACTIVE
	BuildingEconomy.get_slot(slot_id).building_id = bld.building_id
	BuildingEconomy._register_building(bld)


func _spawn_typed_workshop(
	type_id: String,
	bclass: String,
	out_g: String,
	base: float,
	in_g: String,
	in_qty: float
) -> StringName:
	var d := BuildingDef.new()
	d.type = type_id
	d.build_class = bclass
	d.output_good_id = out_g
	d.tier = 1
	d.max_workers = 25
	d.base_output_per_worker = base
	if not in_g.is_empty():
		d.input1_good_id = in_g
		d.input1_qty = in_qty
	BuildingEconomy._building_defs[type_id] = d
	var bld := Building.new()
	bld.building_id = BuildingEconomy._next_bld_id(PORT)
	bld.type = StringName(type_id)
	bld.build_class = StringName(bclass)
	bld.owner = ACTOR
	bld.port_id = PORT
	bld.state = Building.State.ACTIVE
	BuildingEconomy._register_building(bld)
	return bld.building_id


func _set_good_price(gid: String, price: int) -> void:
	var g: GoodDef = GoodCatalog.get_good(gid)
	assert_ne(g, null)
	g.base_price_li = price


func _ensure_good(gid: String, price: int) -> void:
	var g: GoodDef = GoodCatalog.get_good(gid)
	if g != null:
		g.base_price_li = price
		return
	var gx := GoodDef.new()
	gx.good_id = gid
	gx.name_zh = gid
	gx.tier = 1
	gx.is_staple = false
	gx.base_price_li = price
	gx.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
	GoodCatalog._by_id[gid] = gx
	var ids: Array = GoodCatalog._by_id.keys()
	ids.sort()
	GoodCatalog._ids_sorted = PackedStringArray(ids)


func _write_layout() -> void:
	_write_zone(ROOT + "zones/", PORT, 1, 1, 8, 1)
	_write_zone(ROOT + "zones/", PORT, 2, 1, 8, 0)
	_write_city(ROOT + "city_center/", PORT, 6)


func _write_defs() -> void:
	var dir: String = ROOT + "buildings/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_write_bdef(dir, "RB-01", "RESIDENCE", 0, 0.0)
	_write_bdef(dir, "CB-01", "PUBLIC", 0, 0.0)
	_write_bdef(dir, "CB-09", "PUBLIC", 0, 0.0)
	_write_bdef(dir, "CB-17", "KONTOR", 0, 0.0)


func _write_bdef(dir: String, type_id: String, bclass: String, tier: int, base: float) -> void:
	var d := BuildingDef.new()
	d.type = type_id
	d.build_class = bclass
	d.tier = tier
	d.max_workers = 20
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
		{"id": "GD-001", "name": "米", "build": false},
		{"id": "GD-002", "name": "鹽", "build": false},
		{"id": "GD-003", "name": "木材", "build": true},
		{"id": "GD-004", "name": "魚乾", "build": false},
	]
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		var g := GoodDef.new()
		g.good_id = s["id"]
		g.name_zh = s["name"]
		g.tier = 1
		g.is_staple = true
		g.is_build_material = s["build"]
		g.base_price_li = 10
		g.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(g, dir + "%s.tres" % s["id"])
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		var g2 := GoodDef.new()
		g2.good_id = gid
		g2.name_zh = gid
		g2.tier = tier
		g2.is_staple = false
		g2.base_price_li = 10
		g2.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(g2, dir + "%s.tres" % gid)
		written += 1
		next_n += 1
	for extra_id in ["GD-023", "GD-026"]:
		var extra_path: String = dir + "%s.tres" % extra_id
		if FileAccess.file_exists(extra_path):
			continue
		var gx := GoodDef.new()
		gx.good_id = extra_id
		gx.name_zh = extra_id
		gx.tier = 1
		gx.is_staple = false
		gx.base_price_li = 10
		gx.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(gx, extra_path)
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
		def.name_zh = "港%d" % (i + 1)
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
