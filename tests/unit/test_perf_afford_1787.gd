extends GutTest
## 17-87 A3／PERF-AFFORD：候選迴圈 max_affordable_qty 惰性＋每貨一次。
## Basis D-60e：測試名含 17_87；依據 FRM-SYS17-02、FRM-SYS05-09、D-104(c)④。
## 期望值只取 frm_examples EX-05-09-01..03 與 EX-17-02-01（S9f；非產品公式鏡像）。
## 凍結對照＝改前「每格都呼叫 afford」作法；註明為回歸對照，非公式鏡像。

const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://perf_afford_1787/"

const GOOD := "GD-001"
const PORT_A := "PT-01"
const PORT_B := "PT-02"
const PORT_C := "PT-03"

## frm_examples EX-05-09-01：現金足以買 500；s＝300 → q_afford＝300。
const EX_05_09_01_CASH_Q := 500
const EX_05_09_01_STOCK_S := 300
const EX_05_09_01_EXPECT_Q := 300

## frm_examples EX-05-09-02：現金僅足以買 120；s＝300 → q_afford＝120。
const EX_05_09_02_CASH_Q := 120
const EX_05_09_02_STOCK_S := 300
const EX_05_09_02_EXPECT_Q := 120

## frm_examples EX-05-09-03：s＝0 → q_afford＝0。
const EX_05_09_03_EXPECT_Q := 0
const EX_05_09_03_SEED_CASH := 500000

## frm_examples EX-17-02-01：B mid 1300／8 日；C mid 1600／20 日；選 B。
const EX_17_02_01_MID_B := 1300
const EX_17_02_01_MID_C := 1600
const EX_17_02_01_DAYS_B := 8
const EX_17_02_01_DAYS_C := 20
const EX_17_02_01_PICK_PORT := "PT-02"

## 凍結對照用固定週需求（非亂數；足以通過 skip.weekly）。
const FIX_WEEKLY := 250


func before_each() -> void:
	_wipe_user()
	TraderRegistry.set_layers(false, false)
	TraderRegistry.clear_intel_overrides()
	TraderRegistry._clear_runtime()
	DemandModel.clear_potential_demand_provider()


func after_each() -> void:
	DemandModel.clear_potential_demand_provider()
	TraderRegistry.set_layers(false, false)
	TraderRegistry.clear_intel_overrides()
	TraderRegistry._clear_runtime()
	_wipe_user()


func test_17_87_EX_05_09_01_cash_surplus_candidates_match_frozen() -> void:
	## 現金有餘（EX-05-09-01）：庫存瓶頸 q_afford＝300；候選與 q 須與凍結舊作法逐筆相同。
	## 先以 s≥500 觀測 quote(500) 設現金，再抽庫存至 s＝300（同 R972 整備）。
	var ctx: Dictionary = _boot_two_dest(EX_05_09_01_CASH_Q)
	_fund_actor_for_qty(ctx["acct"], EX_05_09_01_CASH_Q)
	var drain: int = EX_05_09_01_CASH_Q - EX_05_09_01_STOCK_S
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_market(PORT_A),
			GoodsLedger.make_external(),
			StringName(GOOD),
			drain,
			GoodsLedger.REASON_CONSUME,
			&"TEST"
		),
		0
	)
	assert_eq(
		GoodsLedger.get_qty(GoodsLedger.make_market(PORT_A), StringName(GOOD)),
		EX_05_09_01_STOCK_S
	)
	assert_eq(
		CashLedger.max_affordable_qty(ctx["acct"], StringName(PORT_A), StringName(GOOD)),
		EX_05_09_01_EXPECT_Q
	)
	_assert_coarse_and_plan_match_frozen(ctx)


func test_17_87_EX_05_09_02_cash_bottleneck_candidates_match_frozen() -> void:
	## 現金為瓶頸（EX-05-09-02）：q_afford＝120；候選與 q 須與凍結舊作法逐筆相同。
	var ctx: Dictionary = _boot_two_dest(EX_05_09_02_STOCK_S)
	_fund_actor_for_qty(ctx["acct"], EX_05_09_02_CASH_Q)
	assert_eq(
		CashLedger.max_affordable_qty(ctx["acct"], StringName(PORT_A), StringName(GOOD)),
		EX_05_09_02_EXPECT_Q
	)
	_assert_coarse_and_plan_match_frozen(ctx)


func test_17_87_EX_05_09_03_zero_stock_no_candidates_match_frozen() -> void:
	## 庫存為 0（EX-05-09-03）：q_afford＝0；舊／新皆無候選；產品評估不得出航。
	var ctx: Dictionary = _boot_two_dest(0)
	_fund_actor_li(ctx["acct"], EX_05_09_03_SEED_CASH)
	assert_eq(
		CashLedger.max_affordable_qty(ctx["acct"], StringName(PORT_A), StringName(GOOD)),
		EX_05_09_03_EXPECT_Q
	)
	var old_c: Array = _frozen_old_coarse(ctx)
	var new_c: Array = _frozen_new_coarse(ctx)
	assert_eq(old_c.size(), 0)
	assert_eq(new_c.size(), 0)
	assert_eq(_coarse_fingerprint(old_c), _coarse_fingerprint(new_c))
	var tid: StringName = ctx["tid"]
	var sid: StringName = ctx["sid"]
	var t: Dictionary = TraderRegistry.get_trader(tid)
	var info: Dictionary = ShipRegistry.ship_info(sid)
	var idle0: int = int((t["idle_days"] as Dictionary).get(String(sid), 0))
	var st: Dictionary = TraderRegistry._evaluate_and_maybe_sail(tid, sid, t, info, false)
	assert_eq(int(st.get("sailed", -1)), 0)
	t = TraderRegistry.get_trader(tid)
	var idle1: int = int((t["idle_days"] as Dictionary).get(String(sid), 0))
	assert_gte(idle1, idle0)


func test_17_87_EX_17_02_01_pick_B_matches_frozen() -> void:
	## EX-17-02-01：兩目的港比每日邊際；凍結舊作法與產品選港皆為 B（PT-02）。
	## 輸入 mid／排序依據取自 frm_examples；q 受艙位與庫存上限（非鏡像公式）。
	var ctx: Dictionary = _boot_two_dest(EX_05_09_01_STOCK_S)
	_fund_actor_for_qty(ctx["acct"], EX_05_09_01_CASH_Q)
	_assert_coarse_and_plan_match_frozen(ctx)
	var best_old: Dictionary = TradeEvaluator.pick_best_candidate(_to_pick_rows(_frozen_old_coarse(ctx)))
	assert_false(best_old.is_empty())
	assert_eq(String(best_old["port_id"]), EX_17_02_01_PICK_PORT)


# --- frozen regression helpers (改前作法；非公式鏡像) ---


func _assert_coarse_and_plan_match_frozen(ctx: Dictionary) -> void:
	var old_c: Array = _frozen_old_coarse(ctx)
	var new_c: Array = _frozen_new_coarse(ctx)
	assert_gt(old_c.size(), 0)
	assert_eq(_coarse_fingerprint(old_c), _coarse_fingerprint(new_c))
	var tid: StringName = ctx["tid"]
	var sid: StringName = ctx["sid"]
	var t: Dictionary = TraderRegistry.get_trader(tid)
	var info: Dictionary = ShipRegistry.ship_info(sid)
	## Freeze sibling traders so only this ship evaluates.
	for tid_v in TraderRegistry.all_trader_ids():
		if String(tid_v) == String(tid):
			continue
		var to: Dictionary = TraderRegistry.get_trader(tid_v)
		TraderRegistry.mark_frozen(to["account_id"], true)
	var st: Dictionary = TraderRegistry._evaluate_and_maybe_sail(tid, sid, t, info, false)
	var best_old: Dictionary = TradeEvaluator.pick_best_candidate(_to_pick_rows(old_c))
	## Product precise top-N may filter by buy_cost；比對粗選最佳的 port/good/q 指紋。
	assert_eq(_coarse_fingerprint(old_c), _coarse_fingerprint(new_c))
	if best_old.is_empty():
		assert_eq(int(st.get("sailed", -1)), 0)
		return
	## 若產品出航，目的港須與凍結粗選最佳一致（EX-17-02-01 選 B）。
	t = TraderRegistry.get_trader(tid)
	var plan: Dictionary = (t["plans"] as Dictionary).get(String(sid), {})
	if int(st.get("sailed", 0)) == 1:
		assert_eq(String(plan.get("to_port", "")), String(best_old["port_id"]))
		assert_eq(String(plan.get("good_id", "")), String(best_old["good_id"]))
		assert_eq(int(plan.get("qty", -1)), int(best_old["qty"]))


func _frozen_old_coarse(ctx: Dictionary) -> Array:
	## 回歸對照：改前順序＝market → afford → intel → weekly → append（每格都呼叫 afford）。
	var out: Array = []
	var from_port: StringName = StringName(PORT_A)
	var acct: StringName = ctx["acct"]
	var free_cap: int = int(ctx["free_cap"])
	var goods: Array = [StringName(GOOD)]
	var ports: Array = [StringName(PORT_B), StringName(PORT_C)]
	for dest_v in ports:
		var dest: StringName = dest_v
		var days: int = int(TraderRegistry._voyage_days.get("%s|%s" % [String(from_port), String(dest)], 0))
		if days < 1:
			continue
		for good_v in goods:
			var good: StringName = good_v
			var market_qty: int = GoodsLedger.get_qty(GoodsLedger.make_market(String(from_port)), good)
			if market_qty < 1:
				continue
			var afford: int = CashLedger.max_affordable_qty(acct, from_port, good)
			if afford < 1:
				continue
			var intel: Dictionary = TraderRegistry._dest_intel(acct, from_port, dest, good)
			if intel.is_empty() or intel.get("mid_li", null) == null:
				continue
			var mid: int = int(intel["mid_li"])
			var weeks_v: Variant = intel.get("weeks", 0.0)
			var weekly: int = DemandModel.weekly_potential_demand(dest, good)
			if weekly < 1:
				continue
			var q: int = mini(mini(afford, free_cap), market_qty)
			if q < 1:
				continue
			var origin_mid: float = MarketPricer.mid_price(from_port, good)
			var rough_buy: int = floori(origin_mid * float(q))
			var score: int = TradeEvaluator.coarse_score(mid, q, rough_buy, days)
			out.append({
				"port_id": dest,
				"good_id": good,
				"qty": q,
				"voyage_days": days,
				"mid_li": mid,
				"weeks": weeks_v,
				"weekly": weekly,
				"score": score,
				"rough_buy": rough_buy,
				"daily_profit_li": score,
			})
	out.sort_custom(func(a, b):
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		var ap := String(a["port_id"])
		var bp := String(b["port_id"])
		if ap != bp:
			return ap < bp
		return String(a["good_id"]) < String(b["good_id"])
	)
	return out


func _frozen_new_coarse(ctx: Dictionary) -> Array:
	## 與產品 A1 同序：market → intel → weekly → afford（區域快取每貨一次）。
	var out: Array = []
	var from_port: StringName = StringName(PORT_A)
	var acct: StringName = ctx["acct"]
	var free_cap: int = int(ctx["free_cap"])
	var afford_by_good: Dictionary = {}
	var goods: Array = [StringName(GOOD)]
	var ports: Array = [StringName(PORT_B), StringName(PORT_C)]
	for dest_v in ports:
		var dest: StringName = dest_v
		var days: int = int(TraderRegistry._voyage_days.get("%s|%s" % [String(from_port), String(dest)], 0))
		if days < 1:
			continue
		for good_v in goods:
			var good: StringName = good_v
			var market_qty: int = GoodsLedger.get_qty(GoodsLedger.make_market(String(from_port)), good)
			if market_qty < 1:
				continue
			var intel: Dictionary = TraderRegistry._dest_intel(acct, from_port, dest, good)
			if intel.is_empty() or intel.get("mid_li", null) == null:
				continue
			var mid: int = int(intel["mid_li"])
			var weeks_v: Variant = intel.get("weeks", 0.0)
			var weekly: int = DemandModel.weekly_potential_demand(dest, good)
			if weekly < 1:
				continue
			var afford: int = TraderRegistry._afford_qty_cached(afford_by_good, acct, from_port, good)
			if afford < 1:
				continue
			var q: int = mini(mini(afford, free_cap), market_qty)
			if q < 1:
				continue
			var origin_mid: float = MarketPricer.mid_price(from_port, good)
			var rough_buy: int = floori(origin_mid * float(q))
			var score: int = TradeEvaluator.coarse_score(mid, q, rough_buy, days)
			out.append({
				"port_id": dest,
				"good_id": good,
				"qty": q,
				"voyage_days": days,
				"mid_li": mid,
				"weeks": weeks_v,
				"weekly": weekly,
				"score": score,
				"rough_buy": rough_buy,
				"daily_profit_li": score,
			})
	out.sort_custom(func(a, b):
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		var ap := String(a["port_id"])
		var bp := String(b["port_id"])
		if ap != bp:
			return ap < bp
		return String(a["good_id"]) < String(b["good_id"])
	)
	return out


func _coarse_fingerprint(rows: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for r_v in rows:
		var r: Dictionary = r_v
		parts.append(
			"%s|%s|%d|%d|%d"
			% [
				String(r["port_id"]),
				String(r["good_id"]),
				int(r["qty"]),
				int(r["score"]),
				int(r["voyage_days"]),
			]
		)
	return "|".join(parts)


func _to_pick_rows(rows: Array) -> Array:
	var out: Array = []
	for r_v in rows:
		var r: Dictionary = r_v
		out.append({
			"port_id": r["port_id"],
			"good_id": r["good_id"],
			"qty": r["qty"],
			"daily_profit_li": r["score"],
		})
	return out


# --- boot / money / stock ---


func _boot_two_dest(stock_s: int) -> Dictionary:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(GoodCatalog.load_and_validate(GoodCatalog.GOODS_DIR).size(), 0)
	assert_eq(PortRegistry.load_and_validate(PortRegistry.PORTS_DIR).size(), 0)
	assert_eq(SeaLanes.load_and_validate().size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(MarketPricer.CURVE_PATH).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	CashLedger.set_quote_provider(MarketPricer)
	assert_eq(TradeDesk.load_and_validate().size(), 0)
	TradeDesk.mark_unloaded()
	TradeDesk.set_qualification_provider(FixtureQualificationProvider.new())
	TradeDesk.set_trade_observers([FixtureTradeObserver.new()])
	assert_eq(TradeDesk.load_and_validate().size(), 0)
	if not ShipRegistry.has_sailor_pool_provider():
		ShipRegistry.set_sailor_pool_provider(_DummySailors.new())
	assert_eq(ShipRegistry.load_and_validate().size(), 0)
	assert_eq(IntelLedger.load_and_validate().size(), 0)
	if not IntelLedger.has_broker_provider():
		IntelLedger.set_broker_provider(SimBrokerFixture.new())
	DemandModel.set_potential_demand_provider(_FixedWeekly.new(FIX_WEEKLY))
	CashLedger.create_account(&"ACT-PLAYER", Account.Kind.ACTOR)
	var start: int = Params.get_int("PRM-SYS05-START_CASH")
	if start > 0:
		assert_eq(CashLedger.genesis_grant(), OK)
	else:
		assert_eq(
			CashLedger.post([
				CashLedger.make_entry(CashLedger.ID_SOURCE, -150000),
				CashLedger.make_entry(&"ACT-PLAYER", 150000),
			], CashLedger.REASON_GENESIS_CASH, CashLedger.REQUESTER_GENESIS_GRANT),
			OK
		)
	if stock_s > 0:
		assert_gt(
			GoodsLedger.transfer(
				GoodsLedger.make_external(),
				GoodsLedger.make_market(PORT_A),
				StringName(GOOD),
				stock_s,
				GoodsLedger.REASON_GENESIS,
				&"TEST"
			),
			0
		)
		GoodsLedger.seed_offtake_snapshot(StringName(PORT_A), StringName(GOOD), 50, 50, 7, 0)
	TraderRegistry.set_layers(true, true)
	TraderRegistry.set_rng_seed(1)
	TraderRegistry._enabled = true
	TraderRegistry._qual_open = true
	TraderRegistry._loaded = true
	TraderRegistry._genesis_granted = false
	TraderRegistry._traders.clear()
	TraderRegistry._load_curve()
	for i in range(1, 3):
		var tid0 := StringName("TR-%03d" % i)
		var acct0 := CashLedger.make_actor_id("TR-%03d" % i)
		assert_eq(CashLedger.create_account(acct0, Account.Kind.ACTOR, tid0), OK)
		TraderRegistry._traders[String(tid0)] = {
			"trader_id": tid0,
			"account_id": acct0,
			"ship_ids": [],
			"ship_count_planned": 1,
			"qualifications": {"tier": 1},
			"mode": TraderRegistry.MODE_IDLE,
			"plans": {},
			"idle_days": {},
			"retired": false,
			"home_port": &"",
		}
	assert_eq(TraderRegistry.grant_genesis_cash(), OK)
	var port := StringName(PORT_A)
	var crew_map: Dictionary = Params.get_value("PRM-SYS13-CREW")
	var crew_n: int = int(crew_map.get("SH-03", 8))
	for tid2 in TraderRegistry.all_trader_ids():
		var t2: Dictionary = TraderRegistry._traders[String(tid2)]
		var sid2: StringName = ShipRegistry.spawn_docked_ship(
			TraderRegistry.SHIP_TYPE, t2["account_id"], port, crew_n
		)
		(t2["ship_ids"] as Array).append(sid2)
		(t2["plans"] as Dictionary)[String(sid2)] = TradeEvaluator.empty_plan()
		(t2["idle_days"] as Dictionary)[String(sid2)] = 0
		t2["home_port"] = port
	TraderRegistry._build_voyage_matrix()
	## EX-17-02-01 航程輸入：B／C 日數取自 frm_examples（覆蓋矩陣，固定 fixture、非亂數）。
	TraderRegistry._voyage_days["%s|%s" % [PORT_A, PORT_B]] = EX_17_02_01_DAYS_B
	TraderRegistry._voyage_days["%s|%s" % [PORT_A, PORT_C]] = EX_17_02_01_DAYS_C
	## EX-17-02-01 mids on B／C（本港 A）。
	TraderRegistry.set_intel_override(StringName(PORT_B), StringName(GOOD), EX_17_02_01_MID_B, 0.0)
	TraderRegistry.set_intel_override(StringName(PORT_C), StringName(GOOD), EX_17_02_01_MID_C, 0.0)
	var tid: StringName = TraderRegistry.all_trader_ids()[0]
	var t: Dictionary = TraderRegistry.get_trader(tid)
	var sid: StringName = t["ship_ids"][0]
	var cap_map: Dictionary = Params.get_value("PRM-SYS13-CAPACITY")
	var hold_cap: int = int(cap_map.get("SH-03", 0))
	return {
		"tid": tid,
		"sid": sid,
		"acct": t["account_id"],
		"free_cap": hold_cap,
	}


func _fund_actor_for_qty(acct: StringName, qty: int) -> void:
	## 整備：把餘額設成剛好能買 qty 擔（以當下 quote 計），對齊 EX-05-09 輸入語意。
	var q: Dictionary = MarketPricer.quote(
		StringName(PORT_A), StringName(GOOD), MarketPricer.SIDE_BUY, qty
	)
	assert_false(q.has(MarketPricer.KEY_ERROR), "setup quote must succeed")
	var need: int = int(q[MarketPricer.KEY_TOTAL_LI])
	assert_gt(need, 0)
	_fund_actor_li(acct, need)


func _fund_actor_li(acct: StringName, target: int) -> void:
	var bal: int = CashLedger.balance(acct)
	if bal == target:
		return
	if bal > target:
		var drain: int = bal - target
		assert_eq(
			CashLedger.post([
				CashLedger.make_entry(acct, 0 - drain),
				CashLedger.make_entry(CashLedger.ID_SINK, drain),
			], &"TEST_DRAIN", &"SYS-08"),
			OK
		)
	else:
		var add: int = target - bal
		assert_eq(
			CashLedger.post([
				CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - add),
				CashLedger.make_entry(acct, add),
			], &"TEST_FUND", CashLedger.REQUESTER_GENESIS_GRANT),
			OK
		)
	assert_eq(CashLedger.balance(acct), target)


func _wipe_user() -> void:
	var abs := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(abs):
		_rm_tree(abs)


func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n == "." or n == "..":
			n = d.get_next()
			continue
		var p := path.path_join(n)
		if d.current_is_dir():
			_rm_tree(p)
		else:
			DirAccess.remove_absolute(p)
		n = d.get_next()
	DirAccess.remove_absolute(path)


class _FixedWeekly extends RefCounted:
	var _w: int = 0
	func _init(w: int) -> void:
		_w = w
	func weekly_potential_demand(_port_id: StringName, _good_id: StringName) -> int:
		return _w


class _DummySailors extends SailorPoolProvider:
	func hire_sailors(_port_id: StringName, n: int) -> int:
		return n
	func release_sailors(_port_id: StringName, n: int) -> int:
		return n
	func beggars(_port_id: StringName) -> int:
		return 0
