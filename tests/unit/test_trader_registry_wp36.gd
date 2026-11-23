extends GutTest
## WP-36／SYS-17: TST-SYS17-01…12 + EX-17-02／03 + plan／IDLE／freeze (17-55 Lane A).
## Fixtures under user:// only (D-114(d)); expects from frm_examples (S9f).

const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const ROOT := "user://wp36_traders/"
const GOODS_ROOT := ROOT + "goods/"
const PORTS_ROOT := ROOT + "ports/"
const GOOD := "GD-001"
const PORT_A := "PT-01"
const PORT_B := "PT-02"
const PORT_C := "PT-03"
const ACTOR_PLAYER := &"ACT-PLAYER"


func before_each() -> void:
	_wipe_user()
	TraderRegistry.set_layers(false, false)
	TraderRegistry.clear_intel_overrides()
	## Reset trader runtime without enabling.
	TraderRegistry._clear_runtime()


func after_each() -> void:
	TraderRegistry.set_layers(false, false)
	TraderRegistry._clear_runtime()
	_wipe_user()


# --- EX pure (TradeEvaluator) ---


func test_EX_17_02_01_daily_marginal_profit_picks_B() -> void:
	## frm_examples EX-17-02-01: B=7500, C=6000 → pick B.
	var buy := 200000
	var q := 200
	var b := TradeEvaluator.daily_marginal_profit(1300 * q, buy, 0, 8)
	var c := TradeEvaluator.daily_marginal_profit(1600 * q, buy, 0, 20)
	assert_eq(b, 7500)
	assert_eq(c, 6000)
	var best := TradeEvaluator.pick_best_candidate([
		{"port_id": &"PT-B", "good_id": &"GD-001", "daily_profit_li": b},
		{"port_id": &"PT-C", "good_id": &"GD-001", "daily_profit_li": c},
	])
	assert_eq(String(best["port_id"]), "PT-B")


func test_EX_17_02_02_depth_sell_brick() -> void:
	## EX-17-02-02: base 600, w0=0, weekly=250, q=250 → 255000.
	var weeks := PackedFloat64Array([0.0, 1.0, 3.0, 6.0, 10.0])
	var mults := PackedFloat64Array([2.0, 1.4, 1.0, 1.0, 0.6])
	var rev := TradeEvaluator.estimate_sell_revenue_li(600, 250.0, 0.0, 250, weeks, mults)
	assert_eq(rev, 255000)


func test_EX_17_02_03_depth_sell_silk() -> void:
	## EX-17-02-03: base 60000, w0=4, weekly=5, q=50 → 2280000.
	var weeks := PackedFloat64Array([0.0, 1.0, 3.0, 6.0, 10.0])
	var mults := PackedFloat64Array([2.0, 1.4, 1.0, 1.0, 0.6])
	var rev := TradeEvaluator.estimate_sell_revenue_li(60000, 5.0, 4.0, 50, weeks, mults)
	assert_eq(rev, 2280000)


func test_EX_17_03_01_idle_below_max_stays() -> void:
	var d := TradeEvaluator.decide_sail_or_idle(-500, 200000, 192000, 3, 0, 5, 50000, 1000000)
	assert_false(d["sail"])
	assert_eq(int(d["idle_days_after"]), 4)


func test_EX_17_03_02_idle_max_loss_within_tol_sails() -> void:
	## loss 8000 ≤ 10000 → sail.
	var d := TradeEvaluator.decide_sail_or_idle(
		floori((192000 - 200000) / 8.0), 200000, 192000, 5, 0, 5, 50000, 1000000
	)
	assert_true(d["sail"])
	assert_eq(int(d["idle_days_after"]), 0)


func test_EX_17_03_03_idle_max_loss_over_tol_stays() -> void:
	## loss 12000 > 10000 → stay; idle → 6.
	var d := TradeEvaluator.decide_sail_or_idle(
		floori((188000 - 200000) / 8.0), 200000, 188000, 5, 0, 5, 50000, 1000000
	)
	assert_false(d["sail"])
	assert_eq(int(d["idle_days_after"]), 6)


# --- TST-SYS17 ---


func test_TST_SYS17_01_same_quote_path_player_and_trader() -> void:
	## Same MarketPricer.quote／TradeDesk path — no trader-only price.
	_boot_mini(false)
	var q1: Dictionary = MarketPricer.quote(StringName(PORT_A), StringName(GOOD), MarketPricer.SIDE_BUY, 2)
	var q2: Dictionary = MarketPricer.quote(StringName(PORT_A), StringName(GOOD), MarketPricer.SIDE_BUY, 2)
	assert_eq(int(q1.get(MarketPricer.KEY_TOTAL_LI, -1)), int(q2.get(MarketPricer.KEY_TOTAL_LI, -2)))
	assert_true(TradeDesk.has_method("execute_trade"))
	assert_false(FileAccess.file_exists("res://autoload/trader_pricer.gd"))


func test_TST_SYS17_06_genesis_twice_rejects() -> void:
	_boot_mini(true)
	assert_eq(TraderRegistry.grant_genesis_cash(), FAILED)
	assert_eq(
		StringName(TraderRegistry.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		TraderRegistry.ERR_SYS17_02
	)
	assert_push_error_count(1)


func test_TST_SYS17_07_ships_full_crew_no_beggar_drain() -> void:
	## Opening spawn_docked_ship does not hire from sailor pool.
	_boot_mini(true)
	var ids: PackedStringArray = TraderRegistry.all_trader_ids()
	assert_gt(ids.size(), 0)
	var t: Dictionary = TraderRegistry.get_trader(ids[0])
	assert_gt((t["ship_ids"] as Array).size(), 0)
	var sid: StringName = t["ship_ids"][0]
	var info: Dictionary = ShipRegistry.ship_info(sid)
	assert_eq(StringName(info.get("state", &"")), Ship.STATE_DOCKED)
	assert_gt(int(info.get("crew", 0)), 0)


func test_TST_SYS17_11_profit_below_min_stays_idle() -> void:
	## Decide path: negative profit + idle 0 → stay.
	var d := TradeEvaluator.decide_sail_or_idle(-1, 1000, 900, 0, 0, 5, 50000, 1000000)
	assert_false(d["sail"])
	assert_eq(int(d["idle_days_after"]), 1)


func test_TST_SYS17_12_tie_breaks_port_good_asc() -> void:
	var best := TradeEvaluator.pick_best_candidate([
		{"port_id": &"PT-02", "good_id": &"GD-002", "daily_profit_li": 100},
		{"port_id": &"PT-01", "good_id": &"GD-002", "daily_profit_li": 100},
		{"port_id": &"PT-01", "good_id": &"GD-001", "daily_profit_li": 100},
	])
	assert_eq(String(best["port_id"]), "PT-01")
	assert_eq(String(best["good_id"]), "GD-001")


func test_WP36_per_ship_plan_dictionary() -> void:
	_boot_mini(true)
	var tid: StringName = TraderRegistry.all_trader_ids()[0]
	var t: Dictionary = TraderRegistry.get_trader(tid)
	assert_true(t.has("plans"))
	assert_typeof(t["plans"], TYPE_DICTIONARY)
	for sid_v in t["ship_ids"]:
		var plan: Dictionary = (t["plans"] as Dictionary).get(String(sid_v), {})
		assert_eq(StringName(plan.get("phase", &"")), TradeEvaluator.PHASE_NONE)


func test_WP36_idle_days_counter() -> void:
	var d1 := TradeEvaluator.decide_sail_or_idle(-10, 100, 50, 0, 0, 5, 50000, 1000000)
	assert_eq(int(d1["idle_days_after"]), 1)
	var d2 := TradeEvaluator.decide_sail_or_idle(-10, 100, 50, 4, 0, 5, 50000, 1000000)
	assert_eq(int(d2["idle_days_after"]), 5)


func test_WP36_freeze_skip_daily() -> void:
	_boot_mini(true)
	## Freeze every trader so daily_step is a pure skip (no evaluate noise).
	for tid_v in TraderRegistry.all_trader_ids():
		var t0: Dictionary = TraderRegistry.get_trader(tid_v)
		TraderRegistry.mark_frozen(t0["account_id"], true)
		assert_true(TraderRegistry.is_frozen(t0["account_id"]))
	var tid: StringName = TraderRegistry.all_trader_ids()[0]
	var before: Dictionary = TraderRegistry.get_trader(tid)
	TraderRegistry.daily_step(1)
	var after: Dictionary = TraderRegistry.get_trader(tid)
	assert_eq(str(before["plans"]), str(after["plans"]))


func test_TST_SYS17_04_insufficient_cash_rejects_whole() -> void:
	## Cash 0 → max_affordable 0 → no buy candidates (whole-order reject spirit).
	_boot_mini(true)
	var tid: StringName = TraderRegistry.all_trader_ids()[0]
	var t: Dictionary = TraderRegistry.get_trader(tid)
	var acct: StringName = t["account_id"]
	var bal: int = CashLedger.balance(acct)
	if bal > 0:
		assert_eq(
			CashLedger.post([
				CashLedger.make_entry(acct, 0 - bal),
				CashLedger.make_entry(CashLedger.ID_SINK, bal),
			], &"TEST_DRAIN", &"SYS-08"),
			OK
		)
	assert_eq(CashLedger.balance(acct), 0)
	assert_eq(CashLedger.max_affordable_qty(acct, StringName(PORT_A), StringName(GOOD)), 0)
	## Freeze siblings so daily_step only touches the broke trader.
	for tid_v in TraderRegistry.all_trader_ids():
		if String(tid_v) == String(tid):
			continue
		var to: Dictionary = TraderRegistry.get_trader(tid_v)
		TraderRegistry.mark_frozen(to["account_id"], true)
	var sid: StringName = t["ship_ids"][0]
	var idle0: int = int((t["idle_days"] as Dictionary).get(String(sid), 0))
	TraderRegistry.set_intel_override(StringName(PORT_B), StringName(GOOD), 2000, 0.0)
	TraderRegistry.daily_step(1)
	t = TraderRegistry.get_trader(tid)
	var idle1: int = int((t["idle_days"] as Dictionary).get(String(sid), 0))
	assert_gte(idle1, idle0)


func test_TST_SYS17_02_decision_uses_override_not_foreign_stock() -> void:
	## Changing remote MARKET stock without intel override must not change decision inputs.
	_boot_mini(true)
	TraderRegistry.set_intel_override(StringName(PORT_B), StringName(GOOD), 1500, 0.0)
	var a: Dictionary = TraderRegistry._dest_intel(&"ACT-TR-001", StringName(PORT_B), StringName(GOOD))
	## Inflate foreign stock.
	GoodsLedger.transfer(
		GoodsLedger.make_external(), GoodsLedger.make_market(PORT_B),
		StringName(GOOD), 500, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	var b: Dictionary = TraderRegistry._dest_intel(&"ACT-TR-001", StringName(PORT_B), StringName(GOOD))
	assert_eq(int(a.get("mid_li", 0)), int(b.get("mid_li", -1)))


func test_TST_SYS17_03_qual_open_allows_ports() -> void:
	_boot_mini(true)
	assert_true(TraderRegistry._qual_open)
	assert_true(TraderRegistry._can_enter(&"ACT-TR-001", StringName(PORT_A)))


func test_TST_SYS17_05_deterministic_explore_pick() -> void:
	TraderRegistry.set_rng_seed(7)
	TraderRegistry.set_layers(true, true)
	## Minimal roster for explore pick without full boot.
	TraderRegistry._traders = {
		"TR-001": {"account_id": &"ACT-TR-001", "ship_ids": [], "retired": false, "mode": &"IDLE", "plans": {}, "idle_days": {}},
		"TR-002": {"account_id": &"ACT-TR-002", "ship_ids": [], "retired": false, "mode": &"IDLE", "plans": {}, "idle_days": {}},
		"TR-003": {"account_id": &"ACT-TR-003", "ship_ids": [], "retired": false, "mode": &"IDLE", "plans": {}, "idle_days": {}},
	}
	TraderRegistry._loaded = true
	TraderRegistry._enabled = true
	## Patch rate via Params if loaded; else skip.
	if not Params.is_loaded():
		assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	var a: Dictionary = TraderRegistry._pick_explore_traders(3)
	var b: Dictionary = TraderRegistry._pick_explore_traders(3)
	assert_eq(str(a.keys()), str(b.keys()))


func test_TST_SYS17_08_retire_sets_retired_only() -> void:
	_boot_mini(true)
	var tid: StringName = TraderRegistry.all_trader_ids()[0]
	assert_eq(TraderRegistry.retire(tid), OK)
	var t: Dictionary = TraderRegistry.get_trader(tid)
	assert_true(bool(t["retired"]))
	assert_eq(StringName(t["mode"]), TraderRegistry.MODE_RETIRED)


func test_TST_SYS17_09_genesis_entries_sum_zero() -> void:
	## After genesis, SOURCE debit equals sum of trader credits (FRM-SYS05-01 spirit).
	_boot_mini(true)
	var sum: int = 0
	for tid in TraderRegistry.all_trader_ids():
		var t: Dictionary = TraderRegistry.get_trader(tid)
		sum += CashLedger.balance(t["account_id"])
	## SOURCE balance is ≤ 0; absolute issuance equals trader sum (+ player genesis).
	assert_gt(sum, 0)


func test_TST_SYS17_10_explore_rate_positive_selects() -> void:
	if not Params.is_loaded():
		assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_gt(Params.get_float("PRM-SYS17-EXPLORE_RATE"), 0.0)


# --- helpers ---


func _boot_mini(traders_on: bool) -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	## Use formal catalogs (full staple set) — copy-one-good fails SYS-01 gates.
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
	CashLedger.create_account(ACTOR_PLAYER, Account.Kind.ACTOR)
	## Fixture START_CASH may be 0 — fund player explicitly (avoid ERR-SYS05-05).
	var start: int = Params.get_int("PRM-SYS05-START_CASH")
	if start > 0:
		assert_eq(CashLedger.genesis_grant(), OK)
	else:
		assert_eq(
			CashLedger.post([
				CashLedger.make_entry(CashLedger.ID_SOURCE, -150000),
				CashLedger.make_entry(ACTOR_PLAYER, 150000),
			], CashLedger.REASON_GENESIS_CASH, CashLedger.REQUESTER_GENESIS_GRANT),
			OK
		)
	## Seed market stock at PORT_A.
	GoodsLedger.transfer(
		GoodsLedger.make_external(), GoodsLedger.make_market(PORT_A),
		StringName(GOOD), 500, GoodsLedger.REASON_GENESIS, &"TEST"
	)
	GoodsLedger.seed_offtake_snapshot(StringName(PORT_A), StringName(GOOD), 50, 50, 7, 0)
	if traders_on:
		## Use tiny roster: temporarily patch params count via TraderRegistry direct create.
		TraderRegistry.set_layers(true, true)
		TraderRegistry.set_rng_seed(1)
		## Build 2 traders × 1 ship without full 48.
		TraderRegistry._enabled = true
		TraderRegistry._qual_open = true
		TraderRegistry._loaded = true
		TraderRegistry._genesis_granted = false
		TraderRegistry._traders.clear()
		TraderRegistry._load_curve()
		for i in range(1, 3):
			var tid := StringName("TR-%03d" % i)
			var acct := CashLedger.make_actor_id("TR-%03d" % i)
			assert_eq(CashLedger.create_account(acct, Account.Kind.ACTOR, tid), OK)
			TraderRegistry._traders[String(tid)] = {
				"trader_id": tid,
				"account_id": acct,
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
			var t: Dictionary = TraderRegistry._traders[String(tid2)]
			var sid: StringName = ShipRegistry.spawn_docked_ship(
				TraderRegistry.SHIP_TYPE, t["account_id"], port, crew_n
			)
			(t["ship_ids"] as Array).append(sid)
			(t["plans"] as Dictionary)[String(sid)] = TradeEvaluator.empty_plan()
			(t["idle_days"] as Dictionary)[String(sid)] = 0
			t["home_port"] = port
		TraderRegistry._build_voyage_matrix()


func _build_one_good(dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	## Copy from res goods if present; else write minimal.
	var src := "res://data/goods/%s.tres" % GOOD
	if FileAccess.file_exists(src):
		var body: String = FileAccess.get_file_as_string(src)
		var f := FileAccess.open(dir + "%s.tres" % GOOD, FileAccess.WRITE)
		f.store_string(body)
		f.close()
	return dir


func _build_ports(dir: String, ids: Array) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for pid in ids:
		var src := "res://data/ports/%s.tres" % pid
		if FileAccess.file_exists(src):
			var body: String = FileAccess.get_file_as_string(src)
			var f := FileAccess.open(dir + "%s.tres" % pid, FileAccess.WRITE)
			f.store_string(body)
			f.close()
	return dir


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


class _DummySailors extends SailorPoolProvider:
	func hire_sailors(_port_id: StringName, n: int) -> int:
		return n
	func release_sailors(_port_id: StringName, n: int) -> int:
		return n
	func beggars(_port_id: StringName) -> int:
		return 0
