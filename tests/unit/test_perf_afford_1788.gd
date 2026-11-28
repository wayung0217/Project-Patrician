extends GutTest
## 17-88 A3／PERF-PRICE-AFFORD：A2 quote(s) 快路徑＋獨立暴力對照。
## Basis D-60e：測名含 17_88；依據 FRM-SYS05-09、D-124、D-128 甲。
## 期望值只取 frm_examples EX-05-09-01 至 03（S9f；非產品公式鏡像）。
## D-128：只用公開介面與正式注入（CashLedger.set_quote_provider）；不碰他模組 _ 成員。
## ★ 缺口（H4 mid_price 區域快取）：無法在不碰 TraderRegistry _ 成員下計數 mid_price
##   呼叫次數；等價性改由 golden-30d 與 lane V 長跑涵蓋（brief A3）。

const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const GOODS_ROOT := "user://perf_afford_1788_goods/"
const PORTS_ROOT := "user://perf_afford_1788_ports/"

const REQUESTER_SYS04 := &"SYS-04"
const REASON_OPEN := &"OPEN"

const PORT := "PT-01"
const GOOD := "GD-001"
const ACTOR := &"ACT-1788"

## frm_examples EX-05-09-01：現金足以買 500；s＝300 → q_afford＝300。
const EX_05_09_01_CASH_Q := 500
const EX_05_09_01_STOCK_S := 300
const EX_05_09_01_EXPECT_Q := 300
const EX_05_09_01_QUOTE_CALLS := 1

## frm_examples EX-05-09-02：現金僅足以買 120；s＝300 → q_afford＝120。
const EX_05_09_02_CASH_Q := 120
const EX_05_09_02_STOCK_S := 300
const EX_05_09_02_EXPECT_Q := 120

## frm_examples EX-05-09-03：s＝0 → q_afford＝0；報價呼叫＝0。
const EX_05_09_03_EXPECT_Q := 0
const EX_05_09_03_SEED_CASH := 500000
const EX_05_09_03_QUOTE_CALLS := 0

## 獨立對照：庫存上界與最少現金水位個數（≥20）。
const BRUTE_STOCK_S := 40
const BRUTE_MIN_LEVELS := 20

const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"


## D-128 甲：正式注入 weekly_potential_demand；禁止他模組 _ 成員。
class _ZeroPotentialDemand extends RefCounted:
	func weekly_potential_demand(_port_id: StringName, _good_id: StringName) -> int:
		return 0


## 公開注入：計數並轉發至內層 quote（通常為 MarketPricer）。
class _CountingQuoteProvider extends RefCounted:
	var _inner: Object = null
	var call_count: int = 0

	func _init(inner: Object) -> void:
		_inner = inner

	func quote(port: StringName, good: StringName, side: int, qty: int) -> Dictionary:
		call_count = call_count + 1
		return _inner.call("quote", port, good, side, qty)


func before_each() -> void:
	_wipe_dir(GOODS_ROOT)
	_wipe_dir(PORTS_ROOT)


func after_each() -> void:
	DemandModel.clear_potential_demand_provider()
	DemandModel.clear_queue_material_shortfall_provider()
	_wipe_dir(GOODS_ROOT)
	_wipe_dir(PORTS_ROOT)


func test_17_88_EX_05_09_01_stock_bottleneck_quote_once() -> void:
	## EX-05-09-01／D-124／A2：庫存瓶頸 → q＝300 且 quote 呼叫＝1（快路徑）。
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
	var counter := _CountingQuoteProvider.new(MarketPricer)
	CashLedger.set_quote_provider(counter)
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	assert_eq(q, EX_05_09_01_EXPECT_Q)
	assert_eq(counter.call_count, EX_05_09_01_QUOTE_CALLS)
	_mark_errors_handled()


func test_17_88_EX_05_09_02_cash_bottleneck_q_120() -> void:
	## EX-05-09-02／D-124：現金瓶頸 → q＝120（frm_examples）。
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
	_mark_errors_handled()
	_fund_actor(cash_for_120)
	var counter := _CountingQuoteProvider.new(MarketPricer)
	CashLedger.set_quote_provider(counter)
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	assert_eq(q, EX_05_09_02_EXPECT_Q)
	_mark_errors_handled()


func test_17_88_EX_05_09_03_zero_stock_no_quote() -> void:
	## EX-05-09-03／D-124：s＝0 → q＝0 且 quote 呼叫＝0。
	_boot_pricing_stack()
	assert_true(PortRegistry.is_loaded())
	assert_true(GoodsLedger.is_loaded())
	assert_eq(_market_stock(), 0)
	_fund_actor(EX_05_09_03_SEED_CASH)
	var counter := _CountingQuoteProvider.new(MarketPricer)
	CashLedger.set_quote_provider(counter)
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	assert_eq(q, EX_05_09_03_EXPECT_Q)
	assert_eq(counter.call_count, EX_05_09_03_QUOTE_CALLS)
	_mark_errors_handled()


func test_17_88_brute_cash_levels_match_max_affordable() -> void:
	## 獨立對照（非鏡像）：公開 MarketPricer.quote 逐擔暴力 vs max_affordable_qty。
	## 至少 20 個現金水位，含剛好買得起 s、買不起 s 差 1 厘、買不起 1 擔。
	_boot_pricing_stack()
	_seed_market(BRUTE_STOCK_S)
	CashLedger.set_quote_provider(MarketPricer)
	var s: int = BRUTE_STOCK_S
	var q1: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, 1
	)
	assert_false(q1.has(MarketPricer.KEY_ERROR))
	var cost_1: int = int(q1[MarketPricer.KEY_TOTAL_LI])
	assert_gt(cost_1, 0)
	var qs: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, s
	)
	assert_false(qs.has(MarketPricer.KEY_ERROR))
	var cost_s: int = int(qs[MarketPricer.KEY_TOTAL_LI])
	assert_gt(cost_s, cost_1)
	_mark_errors_handled()

	var levels: Array = []
	## 買不起 1 擔（含 0 與差 1 厘）。
	levels.append(0)
	if cost_1 > 1:
		levels.append(cost_1 - 1)
	## 剛好買得起 s、買不起 s 差 1 厘、略有餘。
	if cost_s > 1:
		levels.append(cost_s - 1)
	levels.append(cost_s)
	levels.append(cost_s + 1)
	## 填滿至 ≥20：取 quote(k).total 作為水位（k＝1..s）。
	var k: int = 1
	while k <= s and levels.size() < BRUTE_MIN_LEVELS:
		var qk: Dictionary = MarketPricer.quote(
			StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, k
		)
		assert_false(qk.has(MarketPricer.KEY_ERROR))
		levels.append(int(qk[MarketPricer.KEY_TOTAL_LI]))
		k = k + 1
	## 若仍不足，加步長現金。
	var pad: int = cost_1
	while levels.size() < BRUTE_MIN_LEVELS:
		levels.append(pad)
		pad = pad + cost_1
	assert_gte(levels.size(), BRUTE_MIN_LEVELS)
	_mark_errors_handled()

	for cash_v in levels:
		var cash: int = int(cash_v)
		## 每水位獨立帳戶：load 清帳後重建。
		assert_eq(CashLedger.load_and_validate().size(), 0)
		_fund_actor(cash)
		CashLedger.set_quote_provider(MarketPricer)
		var got: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
		var expect: int = _brute_max_q(cash, s)
		assert_eq(got, expect, "cash=%s got=%s expect=%s" % [cash, got, expect])
		_mark_errors_handled()


func _brute_max_q(cash: int, s: int) -> int:
	## 公開 MarketPricer.quote 逐擔：最大 q≤s 使 total≤cash（非產品搜尋路徑）。
	if cash <= 0 or s < 1:
		return 0
	var best: int = 0
	var q: int = 1
	while q <= s:
		var d: Dictionary = MarketPricer.quote(
			StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, q
		)
		if d.has(MarketPricer.KEY_ERROR):
			break
		var total: int = int(d[MarketPricer.KEY_TOTAL_LI])
		if total > cash:
			break
		best = q
		q = q + 1
	return best


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
	if cash <= 0:
		return
	assert_eq(
		CashLedger.post([
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - cash),
			CashLedger.make_entry(ACTOR, cash),
		], REASON_OPEN, REQUESTER_SYS04),
		OK
	)


func _boot_pricing_stack() -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	## D-128 甲：正式 set_potential_demand_provider；不呼叫 DemandModel._clear_state。
	DemandModel.clear_queue_material_shortfall_provider()
	DemandModel.set_potential_demand_provider(_ZeroPotentialDemand.new())
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
