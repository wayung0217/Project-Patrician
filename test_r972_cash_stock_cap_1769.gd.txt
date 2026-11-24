extends GutTest
## R9-72 丁(1)／17-69 2.1／D-124：max_affordable_qty on real MarketPricer path.
## Basis D-60e：規格無 TST ID → 名稱含 R972＋EX-05-09-*；註解寫明依據。
## 必須載入 PortRegistry＋GoodsLedger；不得走 DemoQuoteProvider。
## 期望值只取 frm_examples EX-05-09-01 至 03（D-124(f)；S9f 禁止鏡像產品公式）。
## docs/spec B9 gate：v6.99.220。


const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const GOODS_ROOT := "user://r972_stock_cap_goods/"
const PORTS_ROOT := "user://r972_stock_cap_ports/"

const REQUESTER_SYS04 := &"SYS-04"
const REASON_OPEN := &"OPEN"

const PORT := "PT-01"
const GOOD := "GD-001"
const ACTOR := &"ACT-R972"

## frm_examples EX-05-09-01：現金足以買 500；s＝300 → q_afford＝300；ERR-SYS04-06＝0。
const EX_05_09_01_CASH_Q := 500
const EX_05_09_01_STOCK_S := 300
const EX_05_09_01_EXPECT_Q := 300

## frm_examples EX-05-09-02：現金僅足以買 120；s＝300 → q_afford＝120；ERR-SYS04-06＝0。
const EX_05_09_02_CASH_Q := 120
const EX_05_09_02_STOCK_S := 300
const EX_05_09_02_EXPECT_Q := 120

## frm_examples EX-05-09-03：s＝0 → q＝0；完全不呼叫 quote()。
const EX_05_09_03_EXPECT_Q := 0
const EX_05_09_03_SEED_CASH := 500000

const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"


func before_each() -> void:
	_wipe_dir(GOODS_ROOT)
	_wipe_dir(PORTS_ROOT)


func test_R972_EX_05_09_01_stock_bottleneck_q_300() -> void:
	## EX-05-09-01／D-124(f)：庫存瓶頸。期望 q＝300（frm_examples），非產品公式。
	## 預先以 s≥500 觀測 quote(500) 設現金（輸入整備），再抽庫存至 s＝300。
	_boot_pricing_stack()
	assert_true(PortRegistry.is_loaded())
	assert_true(GoodsLedger.is_loaded())
	_seed_market(EX_05_09_01_CASH_Q)
	CashLedger.set_quote_provider(MarketPricer)
	var q_setup: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, EX_05_09_01_CASH_Q
	)
	assert_false(q_setup.has(MarketPricer.KEY_ERROR), "setup quote q=500 must succeed at s>=500")
	var cash_for_500: int = int(q_setup[MarketPricer.KEY_TOTAL_LI])
	assert_gt(cash_for_500, 0)
	_mark_errors_handled()
	_fund_actor(cash_for_500)
	var drain: int = EX_05_09_01_CASH_Q - EX_05_09_01_STOCK_S
	assert_gt(
		GoodsLedger.transfer(
			_market_dict(),
			GoodsLedger.make_external(),
			StringName(GOOD),
			drain,
			GoodsLedger.REASON_CONSUME,
			&"TEST"
		),
		0
	)
	assert_eq(_market_stock(), EX_05_09_01_STOCK_S)
	var before: int = _count_err_sys04_06()
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	var after: int = _count_err_sys04_06()
	assert_eq(q, EX_05_09_01_EXPECT_Q)
	assert_eq(after - before, 0)
	_mark_errors_handled()


func test_R972_EX_05_09_02_cash_bottleneck_q_120() -> void:
	## EX-05-09-02／D-124(f)：現金瓶頸。期望 q＝120（frm_examples）。
	## 設現金＝quote(120).total（整備「僅足以買 120」）；s＝300。
	_boot_pricing_stack()
	assert_true(PortRegistry.is_loaded())
	assert_true(GoodsLedger.is_loaded())
	_seed_market(EX_05_09_02_STOCK_S)
	CashLedger.set_quote_provider(MarketPricer)
	var q120: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, EX_05_09_02_CASH_Q
	)
	assert_false(q120.has(MarketPricer.KEY_ERROR), "setup quote q=120 must succeed")
	var cash_for_120: int = int(q120[MarketPricer.KEY_TOTAL_LI])
	assert_gt(cash_for_120, 0)
	var q121: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, EX_05_09_02_CASH_Q + 1
	)
	assert_false(q121.has(MarketPricer.KEY_ERROR), "setup quote q=121 must succeed under s=300")
	assert_gt(int(q121[MarketPricer.KEY_TOTAL_LI]), cash_for_120)
	_mark_errors_handled()
	_fund_actor(cash_for_120)
	var before: int = _count_err_sys04_06()
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	var after: int = _count_err_sys04_06()
	assert_eq(q, EX_05_09_02_EXPECT_Q)
	assert_eq(after - before, 0)
	_mark_errors_handled()


func test_R972_EX_05_09_03_zero_stock_no_quote() -> void:
	## EX-05-09-03／D-124(f)：s＝0 → q＝0；完全不呼叫 quote()。
	## 證明：任一 quote(q≥1) 在 s＝0 必產生 ERR-SYS04-06；計數增量＝0 ⇒ 未呼叫。
	_boot_pricing_stack()
	assert_true(PortRegistry.is_loaded())
	assert_true(GoodsLedger.is_loaded())
	assert_eq(_market_stock(), 0)
	_fund_actor(EX_05_09_03_SEED_CASH)
	CashLedger.set_quote_provider(MarketPricer)
	var before: int = _count_err_sys04_06()
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	var after: int = _count_err_sys04_06()
	assert_eq(q, EX_05_09_03_EXPECT_Q)
	assert_eq(after - before, 0, "ERR-SYS04-06 delta 0 ⇒ quote() never called (EX-05-09-03)")
	_mark_errors_handled()


func _count_err_sys04_06() -> int:
	var n: int = 0
	for e in get_errors():
		if e.contains_text("ERR-SYS04-06"):
			n += 1
	return n


func _mark_errors_handled() -> void:
	for e in get_errors():
		e.handled = true


func _market_dict() -> Dictionary:
	return {
		GoodsLedger.KEY_KIND: GoodsLedger.KIND_MARKET,
		GoodsLedger.KEY_PORT: PORT,
	}


func _market_stock() -> int:
	return GoodsLedger.get_qty(_market_dict(), StringName(GOOD))


func _fund_actor(cash: int) -> void:
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	assert_eq(
		CashLedger.post([
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - cash),
			CashLedger.make_entry(ACTOR, cash),
		], REASON_OPEN, REQUESTER_SYS04),
		OK
	)


func _boot_pricing_stack() -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	var goods_dir := _build_goods(GOODS_ROOT)
	assert_eq(GoodCatalog.load_and_validate(goods_dir).size(), 0)
	var ports_dir := _build_ports(Params.get_int(PRM_PORT_COUNT_MIN), PORTS_ROOT)
	assert_eq(PortRegistry.load_and_validate(ports_dir).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	var days_pw: int = Params.get_int("PRM-SYS04-DAYS_PER_WEEK")
	GoodsLedger.seed_offtake_snapshot(
		StringName(PORT), StringName(GOOD), 105, 105, days_pw, 0
	)


func _seed_market(stock: int) -> void:
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			_market_dict(),
			StringName(GOOD),
			stock,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)


func _build_goods(dir: String) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": GOOD, "name": "米", "build": false},
		{"id": "GD-002", "name": "鹽", "build": false},
		{"id": "GD-003", "name": "木材", "build": true},
		{"id": "GD-004", "name": "魚乾", "build": false},
	]
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		var def := GoodDef.new()
		def.good_id = String(s["id"])
		def.name_zh = String(s["name"])
		def.tier = 1
		def.is_staple = true
		def.is_build_material = bool(s["build"])
		def.is_strategic = false
		def.base_price_li = 1000
		def.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(def, dir + "%s.tres" % def.good_id)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var def2 := GoodDef.new()
		def2.good_id = gid
		def2.name_zh = "填料%d" % next_n
		def2.tier = mini((next_n % (free_max + 1)) + 1, Params.get_int(PRM_TIER_MAX))
		def2.is_staple = false
		def2.is_build_material = false
		def2.is_strategic = false
		def2.base_price_li = 1000
		def2.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
		ResourceSaver.save(def2, dir + "%s.tres" % gid)
		written += 1
		next_n += 1
	return dir


func _build_ports(port_count: int, dir: String) -> String:
	_wipe_dir(dir)
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
	var free_count: int = 0
	while free_count <= port_count:
		var ratio: float = float(free_count) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return free_count
		free_count += 1
	return 0


func _wipe_dir(dir: String) -> void:
	var abs_path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs_path):
		var d := DirAccess.open(dir)
		if d:
			d.list_dir_begin()
			var fn := d.get_next()
			while fn != "":
				if fn != "." and fn != "..":
					d.remove(fn)
				fn = d.get_next()
