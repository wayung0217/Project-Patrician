extends GutTest
## WP-07 CashLedger tests. Fixture／期望值來源：TST-SYS05-01..12、示範 5.1（03_Systems B608..B637）.
## Round 2 follow-up: R2-05 post OK/FAILED；AmountQuantize（no AmountMath）；D-03／D-04 kept.


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const SYS_ID := &"SYS-05"

const REQUESTER_SYS04 := &"SYS-04"
const REQUESTER_SYS13 := &"SYS-13"
const REQUESTER_SYS07 := &"SYS-07"
const REASON_TRADE := &"TRADE"
const REASON_OPEN := &"OPEN"
const REASON_CHARGE := &"CHARGE"
const REASON_TEST := &"TEST"

## 示範 5.1／TST-SYS05-03 xlsx（D-01：B463=144000、B470=−13715；B608／B609／B618／B620）
const DEMO_C0 := 150000
const DEMO_BUY_Q := 120
const DEMO_BUY_TOTAL := 144000
const DEMO_SELL_TOTAL := 130285
const DEMO_NET_RECOVERY := 13715
const DEMO_AFTER_BUY_BAL := 6000
const DEMO_AFTER_SELL_BAL := 136285

## D-01 float64 area factors that should quantize to 144000 before ceili（xlsx B463）
const DEMO_AREA_A := 1000.0
const DEMO_AREA_B := 105.0
const DEMO_AREA_C := 64.0
const DEMO_AREA_D := 49.0
const DEMO_AREA_E := 1.05

## TST-SYS05-04／示範 5.1 B628–B630
const DEMO_FEE := 9000
const DEMO_DAYS_HELD := 30
const DEMO_PRORATE := 3000

## TST-SYS05-05／B631–B633
const DEMO_BAL_FOR_CHARGE := 2000
const DEMO_DUE := 3000
const DEMO_PAID := 2000
const DEMO_ARREARS_AFTER := 1000

## TST-SYS05-06
const TST06_ARREARS := 1000
const TST06_CREDIT := 1500
const TST06_BAL_AFTER := 500

## TST-SYS05-08／B621–B623
const DEMO_Q_AFFORD := 124
const DEMO_TOTAL_124 := 149296
const DEMO_TOTAL_125 := 150625

## TST-SYS05-09／B625–B627
const DEMO_HOLD_FREE := 200
const DEMO_HOLD_FREE_TIGHT := 100
const DEMO_STOCK := 300
const DEMO_CARGO_AFTER_BUY := 120

## TST-SYS05-11／B635–B637
const SPLIT_T := 1000
const SPLIT_W1 := 1
const SPLIT_W2 := 1
const SPLIT_W3 := 1
const SPLIT_EXPECT_0 := 334
const SPLIT_EXPECT_1 := 333
const SPLIT_EXPECT_2 := 333

## TST-SYS05-02
const TST02_BAL := 100
const TST02_SPEND := 101

## TST-SYS05-10 stale quote
const TST10_Q := 120
const TST10_NEW_TOTAL := 160000

## T7 named consts (no 1+1 / 0-1 evasions)
const TWO := 2
const THREE := 3
const SENTINEL_UNSET := -1
const PROJECT_GODOT := "res://project.godot"


class DemoQuoteProvider extends RefCounted:
	## Test double for MarketPricer.quote（WP-06 平行未登錄）.
	## 邊界對齊示範 5.1：total(120)/total(124)/total(125) — xlsx 期望值.
	## A18：stock_cap ≥ 0 時 qty＞庫存回 error（模擬真實 MarketPricer）.
	var buy_totals: Dictionary = {}
	var override_total: int = SENTINEL_UNSET
	var stock_cap: int = SENTINEL_UNSET

	func quote(_port: StringName, _good: StringName, side: int, qty: int) -> Dictionary:
		if side != CashLedger.SIDE_BUY:
			return {CashLedger.KEY_TOTAL_LI: 0}
		if stock_cap >= 0 and qty > stock_cap:
			return {CashLedger.KEY_TOTAL_LI: 0, CashLedger.KEY_ERROR: &"ERR-SYS04-06"}
		if override_total >= 0:
			return {CashLedger.KEY_TOTAL_LI: override_total}
		if buy_totals.has(qty):
			return {CashLedger.KEY_TOTAL_LI: int(buy_totals[qty])}
		# 單調近似：釘住示範點，其餘逐步遞增（FRM-SYS05-09 二分用）
		if qty <= 0:
			return {CashLedger.KEY_TOTAL_LI: 0}
		if qty < DEMO_BUY_Q:
			return {CashLedger.KEY_TOTAL_LI: DEMO_BUY_TOTAL - (DEMO_BUY_Q - qty)}
		if qty == DEMO_BUY_Q:
			return {CashLedger.KEY_TOTAL_LI: DEMO_BUY_TOTAL}
		if qty < DEMO_Q_AFFORD:
			var span: int = DEMO_Q_AFFORD - DEMO_BUY_Q
			var step: int = floori((DEMO_TOTAL_124 - DEMO_BUY_TOTAL) / span)
			return {CashLedger.KEY_TOTAL_LI: DEMO_BUY_TOTAL + step * (qty - DEMO_BUY_Q)}
		if qty == DEMO_Q_AFFORD:
			return {CashLedger.KEY_TOTAL_LI: DEMO_TOTAL_124}
		if qty == DEMO_Q_AFFORD + 1:
			return {CashLedger.KEY_TOTAL_LI: DEMO_TOTAL_125}
		return {CashLedger.KEY_TOTAL_LI: DEMO_TOTAL_125 + (qty - (DEMO_Q_AFFORD + 1))}


func before_each() -> void:
	## G3: demo variant from baseline (START_CASH／ARREARS).
	var params_errors: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(params_errors.size(), 0, "params demo fixture must load")
	var gl_errors: Array = GoodsLedger.load_and_validate()
	assert_eq(gl_errors.size(), 0, "GoodsLedger must load for shared seq")
	var cl_errors: Array = CashLedger.load_and_validate()
	assert_eq(cl_errors.size(), 0, "CashLedger must load")


func test_WP59_autoload_order_cash_after_goods() -> void:
	# 2.2-01／AB4／W1 spirit：比較 project.godot 內實際 Autoload 相對順序
	var order: Array = _autoload_names_from_project()
	var i_goods: int = order.find("GoodsLedger")
	var i_cash: int = order.find("CashLedger")
	assert_gte(i_goods, 0, "GoodsLedger missing from project.godot [autoload]")
	assert_gte(i_cash, 0, "CashLedger missing from project.godot [autoload]")
	assert_lt(i_goods, i_cash, "GoodsLedger must precede CashLedger in Autoload order")
	assert_true(CashLedger.is_loaded())
	assert_true(GoodsLedger.is_loaded())


func test_WP59_account_player_constant() -> void:
	# D-03: ACCOUNT_PLAYER = ACT-PLAYER
	assert_eq(CashLedger.ACCOUNT_PLAYER, &"ACT-PLAYER")
	assert_eq(CashLedger.ACCOUNT_PLAYER, CashLedger.make_actor_id("PLAYER"))


func test_WP59_D01_quantize_amount_xlsx_buy_total() -> void:
	# D-01／N-04: Area×(1+HALF) → AmountQuantize then ceili = 144000（xlsx B463）；no AmountMath.
	var area: float = DEMO_AREA_A * DEMO_AREA_B * DEMO_AREA_C / DEMO_AREA_D * DEMO_AREA_E
	var total: int = ceili(AmountQuantize.quantize_amount(area))
	assert_eq(total, DEMO_BUY_TOTAL)
	assert_eq(CashLedger.quantize_money(area, CashLedger.MODE_CEIL), DEMO_BUY_TOTAL)


func test_WP59_D03_genesis_grant() -> void:
	# D-03: genesis_grant posts SOURCE/−START_CASH + ACT-PLAYER/+START_CASH, reason GENESIS_CASH
	var start: int = Params.get_int(CashLedger.PRM_START_CASH)
	assert_eq(start, DEMO_C0)
	var err: int = CashLedger.genesis_grant()
	assert_eq(err, OK)
	assert_true(CashLedger.last_error().is_empty())
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), start)
	assert_eq(CashLedger.balance(CashLedger.ID_SOURCE), 0 - start)
	assert_eq(CashLedger.sum_all_balances(), 0)


func test_WP59_D03_genesis_requester_is_sole_auth_exception() -> void:
	# D-03: REQUESTER_GENESIS_GRANT is the only ERR-SYS05-06 exception; list unchanged.
	assert_false(CashLedger.AUTHORIZED_REQUESTERS.has(CashLedger.REQUESTER_GENESIS_GRANT))
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	var ok: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - DEMO_BAL_FOR_CHARGE),
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, DEMO_BAL_FOR_CHARGE),
	], CashLedger.REASON_GENESIS_CASH, CashLedger.REQUESTER_GENESIS_GRANT)
	assert_eq(ok, OK)


func test_TST_SYS05_01_unbalanced_post_rejected() -> void:
	# TST-SYS05-01: Σ ≠ 0 → ERR-SYS05-02，餘額不變
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_C0)
	var before: int = CashLedger.balance(CashLedger.ACCOUNT_PLAYER)
	var err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, 0 - DEMO_BUY_TOTAL),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(err, FAILED)
	assert_true(_last_error_is(CashLedger.ERR_SYS05_02))
	assert_push_error_count(1)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), before)


func test_TST_SYS05_02_insufficient_cash_voluntary() -> void:
	# TST-SYS05-02: 餘額 100，自願支出 101 → ERR-SYS05-01，餘額仍 100
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, TST02_BAL)
	var err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, 0 - TST02_SPEND),
		CashLedger.make_entry(CashLedger.ID_SINK, TST02_SPEND),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(err, FAILED)
	assert_true(_last_error_is(CashLedger.ERR_SYS05_01))
	assert_push_error_count(1)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), TST02_BAL)


func test_TST_SYS05_03_demo_buy_sell_conservation() -> void:
	# TST-SYS05-03: 示範 5.1 買 120 後原港賣回；Σ=0；淨回收=13715（xlsx B618／B620）
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_C0)
	assert_eq(CashLedger.balance(CashLedger.ID_SOURCE), 0 - DEMO_C0)

	var buy_err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, 0 - DEMO_BUY_TOTAL),
		CashLedger.make_entry(CashLedger.ID_SINK, DEMO_BUY_TOTAL),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(buy_err, OK)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), DEMO_AFTER_BUY_BAL)

	var sink_after_buy: int = CashLedger.balance(CashLedger.ID_SINK)
	var source_before_sell: int = CashLedger.balance(CashLedger.ID_SOURCE)

	var sell_err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - DEMO_SELL_TOTAL),
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, DEMO_SELL_TOTAL),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(sell_err, OK)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), DEMO_AFTER_SELL_BAL)
	assert_eq(CashLedger.sum_all_balances(), 0)

	var sink_delta: int = CashLedger.balance(CashLedger.ID_SINK) - 0
	# 開局後 SINK 自 0；買入使 SINK += BUY；賣不增 SINK
	assert_eq(sink_delta, DEMO_BUY_TOTAL)
	var source_issued: int = DEMO_SELL_TOTAL
	var net: int = CashLedger.market_net_recovery_delta(
		CashLedger.balance(CashLedger.ID_SINK) - 0,
		source_issued
	)
	assert_eq(net, DEMO_NET_RECOVERY)
	# 避免未使用警告
	assert_eq(sink_after_buy, DEMO_BUY_TOTAL)
	assert_eq(source_before_sell, 0 - DEMO_C0)


func test_TST_SYS05_04_prorate() -> void:
	# TST-SYS05-04: fee 9000、30 日、D=90 → 3000
	assert_eq(CashLedger.prorate(DEMO_FEE, DEMO_DAYS_HELD), DEMO_PRORATE)


func test_TST_SYS05_05_charge_mandatory() -> void:
	# TST-SYS05-05: 餘額 2000、應付 3000 → 實付 2000、欠款 1000、餘額 0
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_BAL_FOR_CHARGE)
	var paid: int = CashLedger.charge_mandatory(CashLedger.ACCOUNT_PLAYER, DEMO_DUE, REASON_CHARGE, REQUESTER_SYS13)
	assert_eq(paid, DEMO_PAID)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), 0)
	assert_eq(CashLedger.arrears(CashLedger.ACCOUNT_PLAYER), DEMO_ARREARS_AFTER)


func test_TST_SYS05_06_arrears_priority_credit() -> void:
	# TST-SYS05-06 / FRM-SYS05-07: 欠款 1000，入帳 1500 → 先抵 1000，餘額 +500
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_BAL_FOR_CHARGE)
	CashLedger.charge_mandatory(CashLedger.ACCOUNT_PLAYER, DEMO_DUE, REASON_CHARGE, REQUESTER_SYS13)
	assert_eq(CashLedger.arrears(CashLedger.ACCOUNT_PLAYER), TST06_ARREARS)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), 0)

	var err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - TST06_CREDIT),
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, TST06_CREDIT),
	], REASON_TEST, REQUESTER_SYS04)
	assert_eq(err, OK)
	assert_eq(CashLedger.arrears(CashLedger.ACCOUNT_PLAYER), 0)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), TST06_BAL_AFTER)
	assert_eq(CashLedger.sum_all_balances(), 0)


func test_FRM_SYS05_07_is_single_function() -> void:
	# D153: FRM-SYS05-07 為單一函數 apply_inbound_credit
	assert_true(CashLedger.has_method("apply_inbound_credit"))
	var acc := Account.new()
	acc.id = CashLedger.ACCOUNT_PLAYER
	acc.kind = Account.Kind.ACTOR
	acc.arrears = TST06_ARREARS
	acc.balance = 0
	var r: Dictionary = CashLedger.apply_inbound_credit(acc, TST06_CREDIT)
	assert_eq(int(r["arrears_offset"]), TST06_ARREARS)
	assert_eq(int(r["balance_delta"]), TST06_BAL_AFTER)
	assert_eq(acc.arrears, 0)
	assert_eq(acc.balance, TST06_BAL_AFTER)


func test_TST_SYS05_07_bankruptcy_referred_and_reset() -> void:
	# TST-SYS05-07: 連續欠款達門檻 → bankruptcy_referred；清償後計數歸 0
	# A19／M21：達門檻後再過一季不重發
	# Fixture ARREARS_SEASONS_TO_BANKRUPT = ParamsFixtures.DEMO_ARREARS_SEASONS
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_BAL_FOR_CHARGE)
	CashLedger.charge_mandatory(CashLedger.ACCOUNT_PLAYER, DEMO_DUE, REASON_CHARGE, REQUESTER_SYS13)
	assert_gt(CashLedger.arrears(CashLedger.ACCOUNT_PLAYER), 0)

	watch_signals(CashLedger)
	CashLedger.close_season()
	assert_eq(CashLedger.arrears_seasons(CashLedger.ACCOUNT_PLAYER), 1)
	assert_signal_not_emitted(CashLedger, "bankruptcy_referred")

	CashLedger.close_season()
	assert_eq(CashLedger.arrears_seasons(CashLedger.ACCOUNT_PLAYER), TWO)
	assert_signal_emitted(CashLedger, "bankruptcy_referred")
	assert_signal_emit_count(CashLedger, "bankruptcy_referred", 1)

	# A19：再過一季仍欠款 → 不重發
	CashLedger.close_season()
	assert_eq(CashLedger.arrears_seasons(CashLedger.ACCOUNT_PLAYER), THREE)
	assert_signal_emit_count(CashLedger, "bankruptcy_referred", 1)

	# 清償欠款
	var ar: int = CashLedger.arrears(CashLedger.ACCOUNT_PLAYER)
	var pay_err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - ar),
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, ar),
	], REASON_TEST, REQUESTER_SYS04)
	assert_eq(pay_err, OK)
	assert_eq(CashLedger.arrears(CashLedger.ACCOUNT_PLAYER), 0)

	CashLedger.close_season()
	assert_eq(CashLedger.arrears_seasons(CashLedger.ACCOUNT_PLAYER), 0)


func test_TST_SYS05_08_max_affordable_qty() -> void:
	# TST-SYS05-08／A18／M20：買量超過庫存時 quote 失敗不得當 total＝0；q_afford ≤ stock
	# 改用帶庫存上限的報價（對齊真實 MarketPricer ERR-SYS04-06）；示範 124 點仍保留於 WP56 補強測.
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_C0)
	var qp := DemoQuoteProvider.new()
	## 庫存 100：若仍把 quote 失敗當 0，倍增會回傳遠大於 100 的荒謬值（H7）.
	qp.stock_cap = DEMO_HOLD_FREE_TIGHT
	CashLedger.set_quote_provider(qp)
	var q: int = CashLedger.max_affordable_qty(CashLedger.ACCOUNT_PLAYER, &"PT-01", &"米")
	assert_lte(q, DEMO_HOLD_FREE_TIGHT)
	assert_gt(q, 0)
	var q_over: Dictionary = qp.quote(&"PT-01", &"米", CashLedger.SIDE_BUY, DEMO_HOLD_FREE_TIGHT + 1)
	assert_true(q_over.has(CashLedger.KEY_ERROR))


func test_TST_SYS05_09_slider_caps() -> void:
	# TST-SYS05-09: hold_free < q_afford → max=hold_free；賣出 max=持貨量
	var q_afford: int = DEMO_Q_AFFORD
	var buy_max: int = CashLedger.buy_slider_max(q_afford, DEMO_HOLD_FREE_TIGHT, DEMO_STOCK)
	assert_eq(buy_max, DEMO_HOLD_FREE_TIGHT)
	var buy_max_room: int = CashLedger.buy_slider_max(q_afford, DEMO_HOLD_FREE, DEMO_STOCK)
	assert_eq(buy_max_room, DEMO_Q_AFFORD)
	assert_eq(CashLedger.sell_slider_max(DEMO_CARGO_AFTER_BUY), DEMO_CARGO_AFTER_BUY)


func test_FRM_SYS05_11_and_TST_SYS05_10_stale_quote() -> void:
	# TST-SYS05-10 / FRM-SYS05-11: 新總額 > 餘額 → ERR-SYS05-07；ST-CASH 不變
	assert_true(CashLedger.has_method("revalidate_submit"))
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_C0)
	var bal_before: int = CashLedger.balance(CashLedger.ACCOUNT_PLAYER)
	var source_before: int = CashLedger.balance(CashLedger.ID_SOURCE)
	var sink_before: int = CashLedger.balance(CashLedger.ID_SINK)

	var rev: int = CashLedger.revalidate_submit(bal_before, TST10_NEW_TOTAL)
	assert_eq(rev, FAILED)
	assert_true(_last_error_is(CashLedger.ERR_SYS05_07))
	assert_push_error_count(1)
	# 拒絕後不呼叫 post／transfer — 餘額不變
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), bal_before)
	assert_eq(CashLedger.balance(CashLedger.ID_SOURCE), source_before)
	assert_eq(CashLedger.balance(CashLedger.ID_SINK), sink_before)

	# 付得起則 OK（仍用當刻 B′）
	var ok: int = CashLedger.revalidate_submit(bal_before, DEMO_BUY_TOTAL)
	assert_eq(ok, OK)
	assert_true(CashLedger.last_error().is_empty())
	# 未使用常量保底
	assert_eq(TST10_Q, DEMO_BUY_Q)


func test_TST_SYS05_11_split_largest_remainder() -> void:
	# TST-SYS05-11 / FRM-SYS05-12: T=1000 權重 1,1,1 → 334,333,333
	assert_true(CashLedger.has_method("split_largest_remainder"))
	var parts: Array = CashLedger.split_largest_remainder(SPLIT_T, [SPLIT_W1, SPLIT_W2, SPLIT_W3])
	assert_eq(parts.size(), THREE)
	assert_eq(int(parts[0]), SPLIT_EXPECT_0)
	assert_eq(int(parts[1]), SPLIT_EXPECT_1)
	assert_eq(int(parts[2]), SPLIT_EXPECT_2)
	assert_eq(int(parts[0]) + int(parts[1]) + int(parts[2]), SPLIT_T)


func test_TST_SYS05_12_unauthorized_and_invalid_amount() -> void:
	# TST-SYS05-12: SYS-07 → ERR-SYS05-06；金額 0 或 1.5 → ERR-SYS05-05
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_C0)

	var err_unauth: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, 0 - DEMO_BUY_TOTAL),
		CashLedger.make_entry(CashLedger.ID_SINK, DEMO_BUY_TOTAL),
	], REASON_TRADE, REQUESTER_SYS07)
	assert_eq(err_unauth, FAILED)
	assert_true(_last_error_is(CashLedger.ERR_SYS05_06))

	var err_zero: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ACCOUNT_PLAYER, 0),
		CashLedger.make_entry(CashLedger.ID_SINK, 0),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(err_zero, FAILED)
	assert_true(_last_error_is(CashLedger.ERR_SYS05_05))

	var err_float: int = CashLedger.post([
		{"account_id": CashLedger.ACCOUNT_PLAYER, "amount": 1.5},
		{"account_id": CashLedger.ID_SINK, "amount": -1.5},
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(err_float, FAILED)
	assert_true(_last_error_is(CashLedger.ERR_SYS05_05))
	assert_push_error_count(THREE)


func test_WP59_close_season_prorate_via_schedule() -> void:
	# 季末依 ChargeSchedule 按日扣費（F 寫入順序）
	assert_eq(CashLedger.create_account(CashLedger.ACCOUNT_PLAYER, Account.Kind.ACTOR), OK)
	_open_from_source(CashLedger.ACCOUNT_PLAYER, DEMO_C0)
	var sched := ChargeSchedule.new()
	sched.account_id = CashLedger.ACCOUNT_PLAYER
	sched.requester = REQUESTER_SYS13
	sched.reason = REASON_CHARGE
	sched.fee_per_season = DEMO_FEE
	sched.start_day = CashLedger.DAY_PLACEHOLDER
	sched.end_day = CashLedger.DAY_PLACEHOLDER + DEMO_DAYS_HELD
	CashLedger.register_charge(sched)
	watch_signals(CashLedger)
	var report: SeasonLedgerReport = CashLedger.close_season()
	assert_not_null(report)
	assert_signal_emitted(CashLedger, "season_ledger_closed")
	# 扣 3000 後餘額
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), DEMO_C0 - DEMO_PRORATE)


func test_WP59_params_fixture_not_official_pending_keys() -> void:
	# AB5／BB3: 正式 params.json 若尚未登錄待審 PRM → 必須開機失敗；若已齊則反轉為成功。
	var schema: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/params/params_schema.json")
	)
	var official: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/params/params.json")
	)
	var missing: Array = []
	for key_v in schema.keys():
		var key: String = String(key_v)
		if not official.has(key):
			missing.append(key)
	var errors: Array = Params.load_and_validate("res://data/params/params.json")
	if missing.is_empty():
		assert_eq(errors.size(), 0, "all schema keys present → official params must load")
		assert_true(Params.is_loaded())
	else:
		assert_gt(errors.size(), 0)
		assert_push_error_count(errors.size())
		assert_false(Params.is_loaded())
		assert_true(
			_has_field_error(errors, "PRM-SYS05-START_CASH", "MISSING_KEY")
			or not schema.has("PRM-SYS05-START_CASH"),
			"START_CASH still pending → must appear in errors"
		)


func test_R2_05_post_returns_ok_or_failed() -> void:
	# 03_Systems r589／TechSpec D290（R2-05）: post() -> Error；成功 OK、失敗 FAILED.
	assert_eq(OK, 0)
	assert_eq(FAILED, 1)
	assert_eq(typeof(CashLedger.ERR_SYS05_01), TYPE_STRING_NAME)
	var actor := CashLedger.ACCOUNT_PLAYER
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), OK)
	_open_from_source(actor, DEMO_C0)
	var bad: Error = CashLedger.post([
		CashLedger.make_entry(actor, 0 - DEMO_BUY_TOTAL),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(bad, FAILED)
	assert_true(_last_error_is(CashLedger.ERR_SYS05_02))
	assert_push_error_count(1)
	var good: Error = CashLedger.post([
		CashLedger.make_entry(actor, 0 - DEMO_BUY_TOTAL),
		CashLedger.make_entry(CashLedger.ID_SINK, DEMO_BUY_TOTAL),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(good, OK)
	assert_true(CashLedger.last_error().is_empty())


# --- helpers ---

func _autoload_names_from_project() -> Array:
	## Parse [autoload] block order from project.godot (W1／AB4).
	var text: String = FileAccess.get_file_as_string(PROJECT_GODOT)
	var names: Array = []
	var in_autoload := false
	for line_v in text.split("\n"):
		var line: String = String(line_v).strip_edges()
		if line.begins_with("[") and line.ends_with("]"):
			in_autoload = line == "[autoload]"
			continue
		if not in_autoload:
			continue
		if line.is_empty() or line.begins_with(";"):
			continue
		var eq: int = line.find("=")
		if eq <= 0:
			continue
		names.append(line.substr(0, eq).strip_edges())
	return names


func _has_field_error(errors: Array, field: String, code: String) -> bool:
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if String(e.get("field", "")) == field and String(e.get("code", "")) == code:
			return true
	return false


func _open_from_source(actor: StringName, amount: int) -> void:
	var err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - amount),
		CashLedger.make_entry(actor, amount),
	], REASON_OPEN, REQUESTER_SYS04)
	assert_eq(err, OK, "open from SOURCE failed")


func _last_error_is(code: StringName) -> bool:
	var e: Dictionary = CashLedger.last_error()
	if not _is_error_info(e):
		return false
	if StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")) != code:
		return false
	assert_eq(StringName(e.get(ErrorInfoUtil.KEY_SYS, &"")), SYS_ID, "ErrorInfo.sys must be SYS-05")
	var detail: Variant = e.get(ErrorInfoUtil.KEY_DETAIL, null)
	assert_eq(typeof(detail), TYPE_DICTIONARY, "ErrorInfo.detail must be Dictionary")
	return true


func _is_error_info(e: Variant) -> bool:
	# D-04 carrier: {code: StringName, sys: StringName, detail: Dictionary}.
	if typeof(e) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = e
	if d.is_empty():
		return false
	if not d.has(ErrorInfoUtil.KEY_CODE):
		return false
	if not d.has(ErrorInfoUtil.KEY_SYS):
		return false
	if not d.has(ErrorInfoUtil.KEY_DETAIL):
		return false
	return typeof(d[ErrorInfoUtil.KEY_DETAIL]) == TYPE_DICTIONARY
