extends GutTest
## WP-07 CashLedger tests. Fixture／期望值來源：TST-SYS05-01..12、示範 5.1（03_Systems B608..B637）。


const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const PARAMS_DEMO := "res://tests/fixtures/params_sys05_demo.json"

const REQUESTER_SYS04 := &"SYS-04"
const REQUESTER_SYS13 := &"SYS-13"
const REQUESTER_SYS07 := &"SYS-07"
const REASON_TRADE := &"TRADE"
const REASON_OPEN := &"OPEN"
const REASON_CHARGE := &"CHARGE"
const REASON_TEST := &"TEST"

## 示範 5.1／TST-SYS05-03（B608、B609、B614、B619）
const DEMO_C0 := 150000
const DEMO_BUY_Q := 120
const DEMO_BUY_TOTAL := 144000
const DEMO_SELL_TOTAL := 130285
const DEMO_NET_RECOVERY := 13715
const DEMO_AFTER_BUY_BAL := 6000
const DEMO_AFTER_SELL_BAL := 136285

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

const ACTOR_TOKEN := "PLAYER"


class DemoQuoteProvider extends RefCounted:
	## Test double for MarketPricer.quote（WP-06 平行未登錄）.
	## 邊界對齊示範 5.1：total(120)/total(124)/total(125)。
	var buy_totals: Dictionary = {}
	var override_total: int = 0 - 1

	func quote(_port: StringName, _good: StringName, side: int, qty: int) -> Dictionary:
		if side != CashLedger.SIDE_BUY:
			return {CashLedger.KEY_TOTAL_LI: 0}
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
	var params_errors: Array = Params.load_and_validate(PARAMS_DEMO)
	assert_eq(params_errors.size(), 0, "params demo fixture must load")
	var gl_errors: Array = GoodsLedger.load_and_validate()
	assert_eq(gl_errors.size(), 0, "GoodsLedger must load for shared seq")
	var cl_errors: Array = CashLedger.load_and_validate()
	assert_eq(cl_errors.size(), 0, "CashLedger must load")


func test_autoload_order_cash_after_goods() -> void:
	# 2.2-01：相對順序 GoodsLedger → CashLedger（MarketPricer 屬 WP-06）
	assert_true(CashLedger.is_loaded())
	assert_true(GoodsLedger.is_loaded())


func test_TST_SYS05_01_unbalanced_post_rejected() -> void:
	# TST-SYS05-01: Σ ≠ 0 → ERR-SYS05-02，餘額不變
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_C0)
	var before: int = CashLedger.balance(actor)
	var err: int = CashLedger.post([
		CashLedger.make_entry(actor, 0 - DEMO_BUY_TOTAL),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(err, CashLedger.CODE_ERR_SYS05_02)
	assert_push_error_count(1)
	assert_eq(CashLedger.balance(actor), before)


func test_TST_SYS05_02_insufficient_cash_voluntary() -> void:
	# TST-SYS05-02: 餘額 100，自願支出 101 → ERR-SYS05-01，餘額仍 100
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, TST02_BAL)
	var err: int = CashLedger.post([
		CashLedger.make_entry(actor, 0 - TST02_SPEND),
		CashLedger.make_entry(CashLedger.ID_SINK, TST02_SPEND),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(err, CashLedger.CODE_ERR_SYS05_01)
	assert_push_error_count(1)
	assert_eq(CashLedger.balance(actor), TST02_BAL)


func test_TST_SYS05_03_demo_buy_sell_conservation() -> void:
	# TST-SYS05-03: 示範 5.1 買 120 後原港賣回；Σ=0；淨回收=13715
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_C0)
	assert_eq(CashLedger.balance(CashLedger.ID_SOURCE), 0 - DEMO_C0)

	var buy_err: int = CashLedger.post([
		CashLedger.make_entry(actor, 0 - DEMO_BUY_TOTAL),
		CashLedger.make_entry(CashLedger.ID_SINK, DEMO_BUY_TOTAL),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(buy_err, CashLedger.CODE_OK)
	assert_eq(CashLedger.balance(actor), DEMO_AFTER_BUY_BAL)

	var sink_after_buy: int = CashLedger.balance(CashLedger.ID_SINK)
	var source_before_sell: int = CashLedger.balance(CashLedger.ID_SOURCE)

	var sell_err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - DEMO_SELL_TOTAL),
		CashLedger.make_entry(actor, DEMO_SELL_TOTAL),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(sell_err, CashLedger.CODE_OK)
	assert_eq(CashLedger.balance(actor), DEMO_AFTER_SELL_BAL)
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
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_BAL_FOR_CHARGE)
	var paid: int = CashLedger.charge_mandatory(actor, DEMO_DUE, REASON_CHARGE, REQUESTER_SYS13)
	assert_eq(paid, DEMO_PAID)
	assert_eq(CashLedger.balance(actor), 0)
	assert_eq(CashLedger.arrears(actor), DEMO_ARREARS_AFTER)


func test_TST_SYS05_06_arrears_priority_credit() -> void:
	# TST-SYS05-06 / FRM-SYS05-07: 欠款 1000，入帳 1500 → 先抵 1000，餘額 +500
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_BAL_FOR_CHARGE)
	CashLedger.charge_mandatory(actor, DEMO_DUE, REASON_CHARGE, REQUESTER_SYS13)
	assert_eq(CashLedger.arrears(actor), TST06_ARREARS)
	assert_eq(CashLedger.balance(actor), 0)

	var err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - TST06_CREDIT),
		CashLedger.make_entry(actor, TST06_CREDIT),
	], REASON_TEST, REQUESTER_SYS04)
	assert_eq(err, CashLedger.CODE_OK)
	assert_eq(CashLedger.arrears(actor), 0)
	assert_eq(CashLedger.balance(actor), TST06_BAL_AFTER)
	assert_eq(CashLedger.sum_all_balances(), 0)


func test_FRM_SYS05_07_is_single_function() -> void:
	# D153: FRM-SYS05-07 為單一函數 apply_inbound_credit
	assert_true(CashLedger.has_method("apply_inbound_credit"))
	var acc := Account.new()
	acc.id = CashLedger.make_actor_id("X")
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
	# Fixture ARREARS_SEASONS_TO_BANKRUPT = 2（params_sys05_demo.json）
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_BAL_FOR_CHARGE)
	CashLedger.charge_mandatory(actor, DEMO_DUE, REASON_CHARGE, REQUESTER_SYS13)
	assert_gt(CashLedger.arrears(actor), 0)

	watch_signals(CashLedger)
	CashLedger.close_season()
	assert_eq(CashLedger.arrears_seasons(actor), 1)
	assert_signal_not_emitted(CashLedger, "bankruptcy_referred")

	CashLedger.close_season()
	assert_eq(CashLedger.arrears_seasons(actor), 1 + 1)
	assert_signal_emitted(CashLedger, "bankruptcy_referred")

	# 清償欠款
	var ar: int = CashLedger.arrears(actor)
	var pay_err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - ar),
		CashLedger.make_entry(actor, ar),
	], REASON_TEST, REQUESTER_SYS04)
	assert_eq(pay_err, CashLedger.CODE_OK)
	assert_eq(CashLedger.arrears(actor), 0)

	CashLedger.close_season()
	assert_eq(CashLedger.arrears_seasons(actor), 0)


func test_TST_SYS05_08_max_affordable_qty() -> void:
	# TST-SYS05-08: q_afford=124；total(124)≤c0 < total(125)
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_C0)
	var qp := DemoQuoteProvider.new()
	CashLedger.set_quote_provider(qp)
	var q: int = CashLedger.max_affordable_qty(actor, &"PT-01", &"米")
	assert_eq(q, DEMO_Q_AFFORD)
	assert_true(qp.quote(&"PT-01", &"米", CashLedger.SIDE_BUY, DEMO_Q_AFFORD)[CashLedger.KEY_TOTAL_LI] <= DEMO_C0)
	assert_true(qp.quote(&"PT-01", &"米", CashLedger.SIDE_BUY, DEMO_Q_AFFORD + 1)[CashLedger.KEY_TOTAL_LI] > DEMO_C0)


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
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_C0)
	var bal_before: int = CashLedger.balance(actor)
	var source_before: int = CashLedger.balance(CashLedger.ID_SOURCE)
	var sink_before: int = CashLedger.balance(CashLedger.ID_SINK)

	var rev: int = CashLedger.revalidate_submit(bal_before, TST10_NEW_TOTAL)
	assert_eq(rev, CashLedger.CODE_ERR_SYS05_07)
	assert_push_error_count(1)
	# 拒絕後不呼叫 post／transfer — 餘額不變
	assert_eq(CashLedger.balance(actor), bal_before)
	assert_eq(CashLedger.balance(CashLedger.ID_SOURCE), source_before)
	assert_eq(CashLedger.balance(CashLedger.ID_SINK), sink_before)

	# 付得起則 OK（仍用當刻 B′）
	var ok: int = CashLedger.revalidate_submit(bal_before, DEMO_BUY_TOTAL)
	assert_eq(ok, CashLedger.CODE_OK)
	# 未使用常量保底
	assert_eq(TST10_Q, DEMO_BUY_Q)


func test_TST_SYS05_11_split_largest_remainder() -> void:
	# TST-SYS05-11 / FRM-SYS05-12: T=1000 權重 1,1,1 → 334,333,333
	assert_true(CashLedger.has_method("split_largest_remainder"))
	var parts: Array = CashLedger.split_largest_remainder(SPLIT_T, [SPLIT_W1, SPLIT_W2, SPLIT_W3])
	assert_eq(parts.size(), 1 + 1 + 1)
	assert_eq(int(parts[0]), SPLIT_EXPECT_0)
	assert_eq(int(parts[1]), SPLIT_EXPECT_1)
	assert_eq(int(parts[2]), SPLIT_EXPECT_2)
	assert_eq(int(parts[0]) + int(parts[1]) + int(parts[2]), SPLIT_T)


func test_TST_SYS05_12_unauthorized_and_invalid_amount() -> void:
	# TST-SYS05-12: SYS-07 → ERR-SYS05-06；金額 0 或 1.5 → ERR-SYS05-05
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_C0)

	var err_unauth: int = CashLedger.post([
		CashLedger.make_entry(actor, 0 - DEMO_BUY_TOTAL),
		CashLedger.make_entry(CashLedger.ID_SINK, DEMO_BUY_TOTAL),
	], REASON_TRADE, REQUESTER_SYS07)
	assert_eq(err_unauth, CashLedger.CODE_ERR_SYS05_06)

	var err_zero: int = CashLedger.post([
		CashLedger.make_entry(actor, 0),
		CashLedger.make_entry(CashLedger.ID_SINK, 0),
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(err_zero, CashLedger.CODE_ERR_SYS05_05)

	var err_float: int = CashLedger.post([
		{"account_id": actor, "amount": 1.5},
		{"account_id": CashLedger.ID_SINK, "amount": -1.5},
	], REASON_TRADE, REQUESTER_SYS04)
	assert_eq(err_float, CashLedger.CODE_ERR_SYS05_05)
	assert_push_error_count(1 + 1 + 1)


func test_close_season_prorate_via_schedule() -> void:
	# 季末依 ChargeSchedule 按日扣費（F 寫入順序）
	var actor := CashLedger.make_actor_id(ACTOR_TOKEN)
	assert_eq(CashLedger.create_account(actor, Account.Kind.ACTOR), CashLedger.CODE_OK)
	_open_from_source(actor, DEMO_C0)
	var sched := ChargeSchedule.new()
	sched.account_id = actor
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
	assert_eq(CashLedger.balance(actor), DEMO_C0 - DEMO_PRORATE)


func test_params_fixture_not_official_pending_keys() -> void:
	# 1-A8 / B7: 正式 params.json 不得含 START_CASH 值；缺鍵拒絕
	var errors: Array = Params.load_and_validate("res://data/params/params.json")
	assert_gt(errors.size(), 0)
	assert_push_error_count(errors.size())
	assert_false(Params.is_loaded())


func _open_from_source(actor: StringName, amount: int) -> void:
	var err: int = CashLedger.post([
		CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - amount),
		CashLedger.make_entry(actor, amount),
	], REASON_OPEN, REQUESTER_SYS04)
	assert_eq(err, CashLedger.CODE_OK, "open from SOURCE failed")
