extends GutTest
## WP-56：A18–A23 帳本／報價／成交修復（R9-46／R9-47；D-84）.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const GOODS_ROOT := "user://wp56_goods/"
const PORTS_ROOT := "user://wp56_ports/"

const REQUESTER_SYS04 := &"SYS-04"
const REQUESTER_SYS13 := &"SYS-13"
const REASON_CHARGE := &"CHARGE"
const REASON_TRADE := &"TRADE"
const REASON_OPEN := &"OPEN"
const REASON_TEST := &"TEST"

const PORT := "PT-01"
const GOOD := "GD-001"
const ACTOR := &"ACT-PLAYER"
const UNKNOWN_PORT := "PT-99"

const STOCK_SMALL := 8
const CASH_HUGE := 500000
const ARREARS_SEED := 5000
const DEMO_C0 := 150000
const DEMO_Q_AFFORD := 124
const DEMO_BUY_Q := 120
const DEMO_BUY_TOTAL := 144000
const DEMO_TOTAL_124 := 149296
const DEMO_TOTAL_125 := 150625

const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"

## A20 overflow probes（非規格值；僅觸發 ERR-SYS05-08）
const HUGE_FEE := 9223372036854775807
const HUGE_DAYS := 90
## T7 named consts
const TWO := 2
const NEG_ONE := -1


## R9-65 A2／D-128 甲：正式注入 weekly_potential_demand（offtake-only → 回 0）；禁止 _clear_state。
class _ZeroPotentialDemand extends RefCounted:
	func weekly_potential_demand(_port_id: StringName, _good_id: StringName) -> int:
		return 0


func before_each() -> void:
	_wipe_dir(GOODS_ROOT)
	_wipe_dir(PORTS_ROOT)


func after_each() -> void:
	DemandModel.clear_potential_demand_provider()
	DemandModel.clear_queue_material_shortfall_provider()


func test_WP56_A18_max_affordable_respects_market_stock() -> void:
	## A18／TST-SYS05-08 真實 MarketPricer：現金充足時 q_afford ≤ 庫存，不得爆到 2^k.
	_boot_pricing_stack()
	_seed_market(STOCK_SMALL)
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	assert_eq(
		CashLedger.post([
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - CASH_HUGE),
			CashLedger.make_entry(ACTOR, CASH_HUGE),
		], REASON_OPEN, REQUESTER_SYS04),
		OK
	)
	CashLedger.set_quote_provider(MarketPricer)
	var q: int = CashLedger.max_affordable_qty(ACTOR, StringName(PORT), StringName(GOOD))
	assert_lte(q, STOCK_SMALL)
	assert_gte(q, 0)
	var over: Dictionary = MarketPricer.quote(
		StringName(PORT), StringName(GOOD), MarketPricer.SIDE_BUY, STOCK_SMALL + 1
	)
	assert_true(over.has(MarketPricer.KEY_ERROR))
	## Binary search + explicit overstock quote 皆會 push ERR-SYS04-06；視為預期.
	for e in get_errors():
		e.handled = true


func test_WP56_A19_bankruptcy_referred_once_only() -> void:
	## A19：達門檻後連續季不重發；清償後可再發.
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	assert_eq(
		CashLedger.post([
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - 2000),
			CashLedger.make_entry(ACTOR, 2000),
		], REASON_OPEN, REQUESTER_SYS04),
		OK
	)
	CashLedger.charge_mandatory(ACTOR, 3000, REASON_CHARGE, REQUESTER_SYS13)
	watch_signals(CashLedger)
	CashLedger.close_season()
	CashLedger.close_season()
	assert_signal_emit_count(CashLedger, "bankruptcy_referred", 1)
	CashLedger.close_season()
	CashLedger.close_season()
	assert_signal_emit_count(CashLedger, "bankruptcy_referred", 1)


func test_WP56_A20_reverse_after_arrears_keeps_sum_zero() -> void:
	## A20／A23：入帳抵欠後 reverse_last_post → Σ 全帳戶＝0、欠款還原.
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	CashLedger.charge_mandatory(ACTOR, ARREARS_SEED, REASON_CHARGE, REQUESTER_SYS13)
	assert_eq(CashLedger.arrears(ACTOR), ARREARS_SEED)
	assert_eq(CashLedger.sum_all_balances(), 0)
	var sink_before: int = CashLedger.balance(CashLedger.ID_SINK)
	var sell_total: int = ARREARS_SEED + 1000
	assert_eq(
		CashLedger.post([
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - sell_total),
			CashLedger.make_entry(ACTOR, sell_total),
		], REASON_TRADE, REQUESTER_SYS04),
		OK
	)
	assert_eq(CashLedger.arrears(ACTOR), 0)
	assert_eq(CashLedger.balance(ACTOR), 1000)
	assert_eq(CashLedger.balance(CashLedger.ID_SINK), sink_before + ARREARS_SEED)
	assert_eq(CashLedger.sum_all_balances(), 0)
	assert_eq(CashLedger.reverse_last_post(REQUESTER_SYS04), OK)
	assert_eq(CashLedger.arrears(ACTOR), ARREARS_SEED)
	assert_eq(CashLedger.balance(ACTOR), 0)
	assert_eq(CashLedger.balance(CashLedger.ID_SINK), sink_before)
	assert_eq(CashLedger.sum_all_balances(), 0)


func test_WP56_A20_prorate_and_split_overflow() -> void:
	## A20／C-10：prorate／split 乘法溢位 → ERR-SYS05-08
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	var p: int = CashLedger.prorate(HUGE_FEE, HUGE_DAYS)
	assert_eq(p, CashLedger.INT_API_FAILURE)
	assert_eq(StringName(CashLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), CashLedger.ERR_SYS05_08)
	var parts: Array = CashLedger.split_largest_remainder(HUGE_FEE, [HUGE_DAYS, 1])
	assert_eq(parts.size(), 0)
	assert_eq(StringName(CashLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), CashLedger.ERR_SYS05_08)
	assert_push_error_count(TWO)


func test_WP56_A21_quote_unknown_port() -> void:
	## A21：未知港報價失敗；不得登記 MARKET 容器.
	_boot_pricing_stack()
	var before_reg: bool = GoodsLedger.is_container_registered(
		GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), UNKNOWN_PORT)
	)
	assert_false(before_reg)
	var q: Dictionary = MarketPricer.quote(
		StringName(UNKNOWN_PORT), StringName(GOOD), MarketPricer.SIDE_SELL, 1
	)
	assert_true(q.has(MarketPricer.KEY_ERROR))
	assert_eq(q[MarketPricer.KEY_ERROR], MarketPricer.CODE_UNKNOWN_PORT)
	assert_false(
		GoodsLedger.is_container_registered(
			GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), UNKNOWN_PORT)
		)
	)
	assert_push_error_count(1) ## MarketPricer；PortRegistry.get_port 只寫 last_error


func test_WP56_A22_buy_slider_max_rejects_negative() -> void:
	## A22：buy_slider_max 負數不得靜默夾 0
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	var m: int = CashLedger.buy_slider_max(NEG_ONE, 10, 10)
	assert_eq(m, CashLedger.INT_API_FAILURE)
	assert_eq(StringName(CashLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), CashLedger.ERR_SYS05_05)
	assert_push_error_count(1)


func test_WP56_A22_post_requires_goods_ledger_seq() -> void:
	## A22：GoodsLedger 未載入時 post 不得靜默用 posting_id 當 seq
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	GoodsLedger._loaded = false
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	var err: Error = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, -10),
		CashLedger.make_entry(ACTOR, 10),
	], REASON_OPEN, REQUESTER_SYS04)
	assert_eq(err, FAILED)
	assert_eq(StringName(CashLedger.last_error().get(ErrorInfoUtil.KEY_CODE, &"")), CashLedger.ERR_SYS05_04)
	assert_eq(CashLedger.sum_all_balances(), 0)
	assert_push_error_count(1)


func test_WP56_A23_trade_desk_reverse_with_arrears() -> void:
	## A23：賣出抵欠後 reverse_last_post（TradeDesk 備用路徑）守恆.
	_boot_pricing_stack()
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	CashLedger.charge_mandatory(ACTOR, ARREARS_SEED, REASON_CHARGE, REQUESTER_SYS13)
	## 倉庫備貨後直接 post SELL 分錄（模擬步驟 5），再 reverse（模擬步驟 6 失敗）.
	var sell_total: int = 2000
	assert_eq(
		CashLedger.post([
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - sell_total),
			CashLedger.make_entry(ACTOR, sell_total),
		], REASON_TRADE, REQUESTER_SYS04),
		OK
	)
	assert_lt(CashLedger.arrears(ACTOR), ARREARS_SEED)
	assert_eq(CashLedger.sum_all_balances(), 0)
	assert_eq(CashLedger.reverse_last_post(REQUESTER_SYS04), OK)
	assert_eq(CashLedger.arrears(ACTOR), ARREARS_SEED)
	assert_eq(CashLedger.sum_all_balances(), 0)


func test_WP56_demo_q_afford_124_still_holds() -> void:
	## 示範 5.1 q_afford＝124（原 TST-SYS05-08 數值釘）保留為補強.
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	assert_eq(CashLedger.create_account(ACTOR, Account.Kind.ACTOR), OK)
	assert_eq(
		CashLedger.post([
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - DEMO_C0),
			CashLedger.make_entry(ACTOR, DEMO_C0),
		], REASON_OPEN, REQUESTER_SYS04),
		OK
	)
	## D-125 甲：庫存上界無條件；Given 先種足量 MARKET 庫存（期望／測名不變）.
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_external(),
			GoodsLedger.make_market("PT-01"),
			&"米",
			DEMO_Q_AFFORD + DEMO_BUY_Q,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)
	var provider := _Demo124.new()
	CashLedger.set_quote_provider(provider)
	var q: int = CashLedger.max_affordable_qty(ACTOR, &"PT-01", &"米")
	assert_eq(q, DEMO_Q_AFFORD)


class _Demo124 extends RefCounted:
	## Nested class cannot see outer consts — local copies of TST-SYS05-08 demo points.
	const Q_AFFORD := 124
	const BUY_Q := 120
	const BUY_TOTAL := 144000
	const TOTAL_124 := 149296
	const TOTAL_125 := 150625

	func quote(_port: StringName, _good: StringName, side: int, qty: int) -> Dictionary:
		if side != CashLedger.SIDE_BUY:
			return {CashLedger.KEY_TOTAL_LI: 0}
		if qty <= 0:
			return {CashLedger.KEY_TOTAL_LI: 0}
		if qty < BUY_Q:
			return {CashLedger.KEY_TOTAL_LI: BUY_TOTAL - (BUY_Q - qty)}
		if qty == BUY_Q:
			return {CashLedger.KEY_TOTAL_LI: BUY_TOTAL}
		if qty < Q_AFFORD:
			var span: int = Q_AFFORD - BUY_Q
			var step: int = floori((TOTAL_124 - BUY_TOTAL) / span)
			return {CashLedger.KEY_TOTAL_LI: BUY_TOTAL + step * (qty - BUY_Q)}
		if qty == Q_AFFORD:
			return {CashLedger.KEY_TOTAL_LI: TOTAL_124}
		if qty == Q_AFFORD + 1:
			return {CashLedger.KEY_TOTAL_LI: TOTAL_125}
		return {CashLedger.KEY_TOTAL_LI: TOTAL_125 + (qty - (Q_AFFORD + 1))}


# --- boot helpers（精簡自 test_market_pricer） ---


func _boot_pricing_stack() -> void:
	assert_eq(Params.load_and_validate(ParamsFixtures.path_demo()).size(), 0)
	## D-128 甲／R9-65 A2：正式 set_potential_demand_provider（回 0）→ offtake-only；
	## 不呼叫 DemandModel._clear_state（禁止私有重置）；不新增公開重置介面。
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
