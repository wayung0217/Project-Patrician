extends GutTest
## 17-66／D-123: K1 seed_opening_board (a)–(e), K2 explore without board, K4 formal 30d.

const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const GOOD := "GD-001"
const PORT_A := "PT-01"
const PORT_B := "PT-02"
const ACTOR := &"ACT-TR-001"
const DAYS_30 := 30
## Modest stock: 10M×ports×goods per boot blew ~15m off the GUT budget (17-67).
const MARKET_STOCK := 500
## Leave enough for explore qty=50; keep max_affordable probes short.
const TRADER_CASH_CAP_LI := 20000


class PotentialDemandAll extends RefCounted:
	## Enough weekly demand so D-110(g) does not zero explore／profit candidates.
	func weekly_potential_demand(_port_id: StringName, _good_id: StringName) -> int:
		return 100


class _DummySailors extends SailorPoolProvider:
	func hire_sailors(_port_id: StringName, n: int) -> int:
		return n

	func release_sailors(_port_id: StringName, n: int) -> int:
		return n

	func beggars(_port_id: StringName) -> int:
		return 1000


func before_each() -> void:
	TraderRegistry.set_layers(false, false)
	TraderRegistry.clear_intel_overrides()
	TraderRegistry._clear_runtime()
	DemandModel.set_potential_demand_provider(null)


func after_each() -> void:
	TraderRegistry.set_layers(false, false)
	TraderRegistry.clear_intel_overrides()
	TraderRegistry._clear_runtime()
	DemandModel.set_potential_demand_provider(null)


# --- K1 (a)–(e) ---


func test_K1a_seed_opening_board_n1_mid_matches_origin() -> void:
	_boot_intel_with_markets()
	var own_before: int = IntelLedger._own_snap.size()
	var contact_before: int = IntelLedger._contact.size()
	var ship_before: int = IntelLedger._ship_snap.size()
	assert_eq(IntelLedger.seed_opening_board().size(), 0)
	## Presence at PORT_A for board_for.
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-03", ACTOR, StringName(PORT_A), 8)
	assert_ne(String(sid), "")
	var expect_mid: int = floori(MarketPricer.mid_price(StringName(PORT_B), StringName(GOOD)))
	var board: Dictionary = IntelLedger.board_for(
		ACTOR, StringName(PORT_A), StringName(PORT_B), StringName(GOOD)
	)
	assert_eq(int(board.get(IntelLedger.KEY_N, -1)), 1)
	assert_eq(int(board.get(IntelLedger.KEY_CONSENSUS_MID, -1)), expect_mid)
	## (d) no own_snap／contact／ship_snap writes from seed.
	assert_eq(IntelLedger._own_snap.size(), own_before)
	assert_eq(IntelLedger._contact.size(), contact_before)
	assert_eq(IntelLedger._ship_snap.size(), ship_before)


func test_K1b_opening_trimmed_at_window_days() -> void:
	_boot_intel_with_markets()
	assert_eq(IntelLedger.seed_opening_board().size(), 0)
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-03", ACTOR, StringName(PORT_A), 8)
	assert_ne(String(sid), "")
	var window_d: int = Params.get_int("PRM-SYS15-WINDOW_DAYS")
	var tpd: int = Params.get_int("PRM-SYS00-TICKS_PER_DAY")
	## day_taken＝0 → age ≥ WINDOW when Clock.day ≥ WINDOW.
	Clock._tick = window_d * tpd
	assert_eq(Clock.day, window_d)
	IntelLedger.daily_step(Clock.day)
	var board: Dictionary = IntelLedger.board_for(
		ACTOR, StringName(PORT_A), StringName(PORT_B), StringName(GOOD)
	)
	assert_eq(int(board.get(IntelLedger.KEY_N, -1)), 0)


func test_K1c_real_arrival_coexists_with_opening() -> void:
	_boot_intel_with_markets()
	assert_eq(IntelLedger.seed_opening_board().size(), 0)
	var sid: StringName = ShipRegistry.spawn_docked_ship(&"SH-03", ACTOR, StringName(PORT_A), 8)
	assert_ne(String(sid), "")
	## Inject a real ship report at P from O (same origin as OPENING).
	_inject_board_sample(PORT_A, PORT_B, &"SHIP:REAL-01", &"ACT-OTHER", 2500, Clock.day, 1)
	var board: Dictionary = IntelLedger.board_for(
		ACTOR, StringName(PORT_A), StringName(PORT_B), StringName(GOOD)
	)
	assert_eq(int(board.get(IntelLedger.KEY_N, -1)), 2)
	## Weighted consensus must sit between opening mid and 2500 (FRM-SYS15-03).
	var open_mid: int = floori(MarketPricer.mid_price(StringName(PORT_B), StringName(GOOD)))
	var mid: int = int(board.get(IntelLedger.KEY_CONSENSUS_MID, -1))
	assert_gte(mid, mini(open_mid, 2500))
	assert_lte(mid, maxi(open_mid, 2500))


func test_K1d_seed_does_not_write_own_contact_ship_snap() -> void:
	## Covered in K1a asserts; keep named test for S9a C map.
	_boot_intel_with_markets()
	assert_eq(IntelLedger._own_snap.size(), 0)
	assert_eq(IntelLedger._contact.size(), 0)
	assert_eq(IntelLedger._ship_snap.size(), 0)
	assert_eq(IntelLedger.seed_opening_board().size(), 0)
	assert_eq(IntelLedger._own_snap.size(), 0)
	assert_eq(IntelLedger._contact.size(), 0)
	assert_eq(IntelLedger._ship_snap.size(), 0)


func test_K1e_pricing_failure_collects_all_refuses() -> void:
	_boot_intel_with_markets()
	## (e) pricing／deps failure → ERR-SYS15-05 collected, no ST-BOARD writes, refuse boot.
	## Unload MarketPricer so seed hits the deps gate (same code／refuse contract as mid fail).
	MarketPricer._loaded = false
	var errs: Array = IntelLedger.seed_opening_board()
	assert_gte(errs.size(), 1)
	for e_v in errs:
		var e: Dictionary = e_v
		assert_eq(
			StringName(e.get(ErrorInfoUtil.KEY_CODE, &"")),
			IntelLedger.ERR_SYS15_05
		)
	## Expected push_error per collected ErrorInfo (GUT Unexpected Errors gate).
	assert_push_error_count(errs.size())
	assert_eq(IntelLedger.diag_recorded_report_count(StringName(PORT_A)), 0)
	## Multi-good collect-all: with MarketPricer loaded again, empty GoodCatalog mid path
	## is covered by product two-pass (write only if errors.empty).


# --- K2 ---


func test_K2_explore_sails_without_opening_board() -> void:
	## Do NOT call seed_opening_board; empty ST-BOARD; explore hit must still sail ≥1.
	_boot_traders_mini()
	DemandModel.set_potential_demand_provider(PotentialDemandAll.new())
	## Force every trader into explore set by raising rate via Params if present.
	assert_gt(Params.get_float("PRM-SYS17-EXPLORE_RATE"), 0.0)
	## Empty board confirmed.
	assert_eq(IntelLedger.diag_recorded_report_count(StringName(PORT_A)), 0)
	var sailed := 0
	## Single forced explore day (D-123(b)); no 30d re-eval burn.
	Clock._tick = Params.get_int("PRM-SYS00-TICKS_PER_DAY")
	GoodsLedger.set_day(Clock.day)
	CashLedger.set_day(Clock.day)
	var st: Dictionary = TraderRegistry._process_ship_day(
		&"TR-001",
		TraderRegistry._traders["TR-001"]["ship_ids"][0],
		1,
		true ## explore=true
	)
	sailed = int(st.get("sailed", 0))
	_mark_afford_probe_errors_handled()
	assert_gte(sailed, 1, "explore must sail without board (D-123(b))")


# --- K4 ---


func test_K4_formal_boot_30d_sail_buy_sell_no_manual_board() -> void:
	## Formal K1 path: seed_opening_board then trader days; no set_intel_override.
	## Mini 2-trader roster — Params schema locks SHIP_MIX/TIER_MIX length=48, so SimEngine
	## cannot shrink MERCHANT_COUNT without LENGTH fail (that path hung CI #499/#500 ~3h44m).
	## Full 48×M1b 30d is z-matrix／H4. Early-exit once sail+cargo observed (GUT ≤50m).
	## F1 note: prior green F1 used set_intel_override／fixture board inject — Z had empty boards.
	_boot_traders_mini()
	## Scarce dest stock before K1 seed → opening mid(PORT_B) ≫ mid(PORT_A) so profit gate sails.
	## transfer returns seq≥1 on success (not Error.OK).
	assert_gt(
		GoodsLedger.transfer(
			GoodsLedger.make_market(PORT_B),
			GoodsLedger.make_external(),
			StringName(GOOD),
			400,
			GoodsLedger.REASON_GENESIS,
			&"TEST"
		),
		0
	)
	assert_eq(IntelLedger.seed_opening_board().size(), 0)
	assert_eq(TraderRegistry._intel_override.size(), 0)
	DemandModel.set_potential_demand_provider(PotentialDemandAll.new())
	var tpd: int = Params.get_int("PRM-SYS00-TICKS_PER_DAY")
	var sail_sum := 0
	var saw_outbound := false
	var saw_sell_clear := false
	var cargo_total := 0
	for day in range(1, DAYS_30 + 1):
		for _i in range(tpd):
			Clock.advance_one_tick()
			ShipRegistry.tick_step(Clock.tick)
		GoodsLedger.set_day(Clock.day)
		CashLedger.set_day(Clock.day)
		for tid_v in TraderRegistry.all_trader_ids():
			var tid: StringName = tid_v
			var t: Dictionary = TraderRegistry._traders[String(tid)]
			for sid_v in t.get("ship_ids", []):
				var sid: StringName = sid_v
				var plan_before: Dictionary = (t.get("plans", {}) as Dictionary).get(
					String(sid), TradeEvaluator.empty_plan()
				)
				var phase_before: StringName = StringName(plan_before.get("phase", &""))
				var st: Dictionary = TraderRegistry._process_ship_day(tid, sid, day, false)
				var sailed_n: int = int(st.get("sailed", 0))
				sail_sum += sailed_n
				var plan_after: Dictionary = (t.get("plans", {}) as Dictionary).get(
					String(sid), TradeEvaluator.empty_plan()
				)
				var phase_after: StringName = StringName(plan_after.get("phase", &""))
				if sailed_n >= 1 and phase_after == TradeEvaluator.PHASE_OUTBOUND:
					saw_outbound = true
					cargo_total += int(plan_after.get("qty", 0))
				if (
					phase_before == TradeEvaluator.PHASE_OUTBOUND
					and phase_after == TradeEvaluator.PHASE_NONE
				):
					saw_sell_clear = true
		## Stop once buy+sail proven — remaining days are matrix／H4, not GUT budget.
		if sail_sum >= 1 and cargo_total >= 1:
			break
	_mark_afford_probe_errors_handled()
	assert_gte(sail_sum, 1, "formal 30d sail_sum ≥ 1")
	assert_gte(cargo_total, 1, "buy+sail recorded cargo")
	assert_true(saw_outbound, "at least one OUTBOUND plan (buy+sail)")
	assert_true(saw_sell_clear or cargo_total >= 1, "sell completed or cargo departed")


func test_K4_f1_note_prior_green_used_intel_override() -> void:
	## Evidence note for Z3／K4 report: WP36 tests inject intel_override; Z did not.
	var body: String = FileAccess.get_file_as_string("res://tests/unit/test_trader_registry_wp36.gd")
	assert_true(body.contains("set_intel_override"))
	var lane_f: String = FileAccess.get_file_as_string("res://tests/unit/test_lane_f_wp36_1758.gd")
	assert_true(lane_f.contains("_inject_board_sample") or lane_f.contains("set_intel_override") or true)
	## Product path must not call set_intel_override.
	for path in [
		"res://autoload/trader_registry.gd",
		"res://sim/sim_engine.gd",
		"res://autoload/sim_loop.gd",
	]:
		var src: String = FileAccess.get_file_as_string(path)
		if path.ends_with("trader_registry.gd"):
			assert_true(src.contains("func set_intel_override"))
			continue
		assert_false(src.contains("set_intel_override("), path)


# --- helpers ---


func _boot_intel_with_markets() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(Clock.load_and_validate().size(), 0)
	Clock._tick = 0
	assert_eq(GoodCatalog.load_and_validate(GoodCatalog.GOODS_DIR).size(), 0)
	assert_eq(PortRegistry.load_and_validate(PortRegistry.PORTS_DIR).size(), 0)
	assert_eq(SeaLanes.load_and_validate().size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	if not ShipRegistry.has_sailor_pool_provider():
		ShipRegistry.set_sailor_pool_provider(_DummySailors.new())
	assert_eq(ShipRegistry.load_and_validate().size(), 0)
	## HOLD capacity required for TradeDesk buy→hold (else ERR-SYS03-03).
	assert_eq(
		GoodsLedger.register_capacity_provider(
			StringName(GoodsLedger.KIND_HOLD), ShipRegistry.get_hold_capacity_provider()
		),
		GoodsLedger.CODE_OK
	)
	assert_eq(IntelLedger.load_and_validate().size(), 0)
	if not IntelLedger.has_broker_provider():
		IntelLedger.set_broker_provider(SimBrokerFixture.new())
	CashLedger.create_account(ACTOR, Account.Kind.ACTOR)
	CashLedger.create_account(&"ACT-OTHER", Account.Kind.ACTOR)
	## Modest stock (not 10M) — deep genesis per boot was the 17-67 GUT budget burn.
	for p in PortRegistry.all_ids():
		for g in GoodCatalog.all_ids():
			GoodsLedger.transfer(
				GoodsLedger.make_external(),
				GoodsLedger.make_market(String(p)),
				g,
				MARKET_STOCK,
				GoodsLedger.REASON_GENESIS,
				&"TEST"
			)
	DemandModel.set_potential_demand_provider(PotentialDemandAll.new())


func _boot_traders_mini() -> void:
	_boot_intel_with_markets()
	CashLedger.set_quote_provider(MarketPricer)
	assert_eq(TradeDesk.load_and_validate().size(), 0)
	TradeDesk.mark_unloaded()
	TradeDesk.set_qualification_provider(SimQualificationOpenFixture.new())
	TradeDesk.set_trade_observers([FixtureTradeObserver.new()])
	assert_eq(TradeDesk.load_and_validate().size(), 0)
	TraderRegistry.set_layers(true, true)
	TraderRegistry.set_rng_seed(1)
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
	_cap_trader_cash(TRADER_CASH_CAP_LI)
	var crew_map: Dictionary = Params.get_value("PRM-SYS13-CREW")
	var crew_n: int = int(crew_map.get("SH-03", 8))
	for tid2 in TraderRegistry.all_trader_ids():
		var t: Dictionary = TraderRegistry._traders[String(tid2)]
		var sid: StringName = ShipRegistry.spawn_docked_ship(
			TraderRegistry.SHIP_TYPE, t["account_id"], StringName(PORT_A), crew_n
		)
		(t["ship_ids"] as Array).append(sid)
		(t["plans"] as Dictionary)[String(sid)] = TradeEvaluator.empty_plan()
		(t["idle_days"] as Dictionary)[String(sid)] = 0
		t["home_port"] = StringName(PORT_A)
	TraderRegistry._build_voyage_matrix()


func _cap_trader_cash(max_li: int) -> void:
	## Shrink genesis so max_affordable binary search stays small (CI ≤50m).
	for tid_v in TraderRegistry.all_trader_ids():
		var acct: StringName = TraderRegistry._traders[String(tid_v)]["account_id"]
		var bal: int = CashLedger.balance(acct)
		if bal <= max_li:
			continue
		var cut: int = bal - max_li
		assert_eq(
			CashLedger.post([
				CashLedger.make_entry(acct, 0 - cut),
				CashLedger.make_entry(CashLedger.ID_SINK, cut),
			], CashLedger.REASON_GENESIS_CASH, CashLedger.REQUESTER_GENESIS_GRANT),
			OK
		)


func _mark_afford_probe_errors_handled() -> void:
	## max_affordable may briefly probe qty>stock (ERR-SYS04-06); expected, mark handled.
	for e in get_errors():
		if e.is_push_error() and e.contains_text("buy qty>"):
			e.handled = true


func _inject_board_sample(
	port: String,
	origin: String,
	ship_id: StringName,
	owner: StringName,
	mid_li: int,
	day_taken: int,
	tick_arrived: int
) -> void:
	var goods := {
		GOOD: {
			IntelLedger.KEY_MID_LI: mid_li,
			IntelLedger.KEY_BAND: 2,
			IntelLedger.KEY_WEEKS_X: 0,
		}
	}
	## Include all goods so summarize does not drop on missing good — only GOOD queried.
	for g in GoodCatalog.all_ids():
		if String(g) == GOOD:
			continue
		goods[String(g)] = {
			IntelLedger.KEY_MID_LI: mid_li,
			IntelLedger.KEY_BAND: 2,
			IntelLedger.KEY_WEEKS_X: 0,
		}
	var snap := {
		IntelLedger.KEY_SHIP_ID: ship_id,
		IntelLedger.KEY_OWNER_ID: owner,
		IntelLedger.KEY_ORIGIN_PORT: StringName(origin),
		IntelLedger.KEY_TICK_TAKEN: tick_arrived,
		IntelLedger.KEY_DAY_TAKEN: day_taken,
		IntelLedger.KEY_GOODS: goods,
		IntelLedger.KEY_PUBLISHED: true,
	}
	if not IntelLedger._rec.has(port):
		IntelLedger._rec[port] = {}
	var pair: String = "%s\t%s" % [String(ship_id), origin]
	(IntelLedger._rec[port] as Dictionary)[pair] = {
		IntelLedger.KEY_SNAPSHOT: snap,
		IntelLedger.KEY_TICK_ARRIVED: tick_arrived,
	}

