extends GutTest
## R9-72 丁(1)／17-69 2.1：max_affordable_qty on real MarketPricer path.
## Basis D-60e：規格無 TST ID → 名稱含 R972 紅隊編號；註解寫明依據。
## 必須載入 PortRegistry＋GoodsLedger；不得走 DemoQuoteProvider。
## 期望值：庫存／現金邊界為測試設定常數；現金情境以 MarketPricer.quote 單點
## 觀測 total_li 作外部 oracle（非重寫 FRM-SYS05-09 二分／倍增，S9f）。


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const GOODS_ROOT := "user://r972_stock_cap_goods/"
const PORTS_ROOT := "user://r972_stock_cap_ports/"

const REQUESTER_SYS04 := &"SYS-04"
const REASON_OPEN := &"OPEN"

const PORT := "PT-01"
const GOOD := "GD-001"
const ACTOR := &"ACT-R972"

## 2.1(a)(b)：庫存上界；現金遠大於單擔價 → 結果受庫存限制。
const STOCK_CAP_A := 8
const CASH_HUGE := 500000

## 2.1(d)：庫存遠大於現金可買量；期望 q＝1（見測試內 oracle 註解）。
const STOCK_HIGH_D := 40
const EXPECT_Q_CASH_LIMIT := 1

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


func test_R972_D1a_max_affordable_le_market_stock() -> void:
	## 2.1(a)：max_affordable_qty ≤ 該港該貨市場庫存（STOCK_CAP_A 為設定常數）。
	_boot_pricing_stack()
	assert_true(PortRegistry.is_loaded())
	assert_true(GoodsLedger.is_loaded())
	_seed_market(STOCK_CAP_A)
	_fund_actor(CASH_HUGE)
	CashLedger.set_quote_provider(MarketPricer)
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	assert_lte(q, STOCK_CAP_A)
	assert_gte(q, 0)
	_mark_errors_handled()


func test_R972_D1b_err_sys04_06_count_zero_during_search() -> void:
	## 2.1(b)：搜尋過程 ERR-SYS04-06 計數＝0（庫存上界避免 qty>stock 探測）。
	_boot_pricing_stack()
	assert_true(PortRegistry.is_loaded())
	assert_true(GoodsLedger.is_loaded())
	_seed_market(STOCK_CAP_A)
	_fund_actor(CASH_HUGE)
	CashLedger.set_quote_provider(MarketPricer)
	var before: int = _count_err_sys04_06()
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	var after: int = _count_err_sys04_06()
	assert_eq(after - before, 0, "ERR-SYS04-06 must not fire during stock-capped search")
	assert_lte(q, STOCK_CAP_A)
	_mark_errors_handled()


func test_R972_D1c_zero_stock_returns_zero() -> void:
	## 2.1(c)：庫存＝0 → max_affordable_qty 回 0。
	_boot_pricing_stack()
	assert_true(PortRegistry.is_loaded())
	assert_true(GoodsLedger.is_loaded())
	## 不 seed 市場 → MARKET 庫存 0。
	_fund_actor(CASH_HUGE)
	CashLedger.set_quote_provider(MarketPricer)
	var before: int = _count_err_sys04_06()
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	var after: int = _count_err_sys04_06()
	assert_eq(q, 0)
	assert_eq(after - before, 0)
	_mark_errors_handled()


func test_R972_D1d_cash_limit_not_overridden_by_stock_cap() -> void:
	## 2.1(d)：庫存上界不得蓋過現金限制。
	## Oracle（S9f）：以 MarketPricer.quote 單點觀測 total_li，非產品二分公式。
	## 設現金＝quote(q=1).total_li，且 quote(q=2).total_li > 現金 → 期望 q＝1。
	_boot_pricing_stack()
	assert_true(PortRegistry.is_loaded())
	assert_true(GoodsLedger.is_loaded())
	_seed_market(STOCK_HIGH_D)
	CashLedger.set_quote_provider(MarketPricer)
	var q1: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, EXPECT_Q_CASH_LIMIT
	)
	assert_false(q1.has(MarketPricer.KEY_ERROR), "oracle quote q=1 must succeed")
	var total_1: int = int(q1[MarketPricer.KEY_TOTAL_LI])
	assert_gt(total_1, 0)
	var q2: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, EXPECT_Q_CASH_LIMIT + 1
	)
	assert_false(q2.has(MarketPricer.KEY_ERROR), "oracle quote q=2 must succeed under high stock")
	var total_2: int = int(q2[MarketPricer.KEY_TOTAL_LI])
	assert_gt(total_2, total_1)
	## 清掉 oracle 探測的 push_error（若有）；再量測搜尋本身。
	_mark_errors_handled()
	_fund_actor(total_1)
	var before: int = _count_err_sys04_06()
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	var after: int = _count_err_sys04_06()
	assert_eq(q, EXPECT_Q_CASH_LIMIT, "cash=total(1) → afford exactly 1; stock cap must not raise it")
	assert_eq(after - before, 0)
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
	## D-08d：容器地址最終仍由 GoodsLedger.container_id 產生（_container_key）。
	## 測試用 make_market 與既有 WP56 相同；產品碼 2.8 改走 Dictionary＋KIND（見 cash_ledger）。
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			GoodsLedger.make_market(PORT),
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
