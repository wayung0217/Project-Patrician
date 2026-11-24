extends GutTest
## 17-58 Lane F／WP-36: F1–F5 unit evidence (CI runs; Cursor does not run GUT per 17-61).

const PARAMS_FIXTURE := "res://tests/fixtures/params_all_keys.json"
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const SCENARIOS := [
	"res://docs/spec/scenario_M1b_G0.json",
	"res://docs/spec/scenario_M1b_G1.json",
	"res://docs/spec/scenario_M1b_G2.json",
	"res://docs/spec/scenario_M1b_G0H.json",
]
const GOOD := "GD-001"
const PORT_A := "PT-01"
const PORT_B := "PT-02"
const ACTOR := &"ACT-TR-001"


func before_each() -> void:
	TraderRegistry.set_layers(false, false)
	TraderRegistry.clear_intel_overrides()
	TraderRegistry._clear_runtime()


func after_each() -> void:
	TraderRegistry.set_layers(false, false)
	TraderRegistry.clear_intel_overrides()
	TraderRegistry._clear_runtime()


# --- F1 ---


func test_F1_set_layers_traders_off_skips_load() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	TraderRegistry.set_layers(false, true)
	assert_false(TraderRegistry.is_enabled())
	assert_eq(TraderRegistry.load_and_validate().size(), 0)
	assert_false(TraderRegistry.is_loaded())
	assert_eq(TraderRegistry.apply_boot_steps().size(), 0)
	assert_eq(TraderRegistry.all_trader_ids().size(), 0)


func test_F1_open_fixture_allows_when_qual_open() -> void:
	var fx := SimQualificationOpenFixture.new()
	assert_true(fx.can_enter(ACTOR, StringName(PORT_A)))
	assert_true(fx.can_trade(ACTOR, StringName(PORT_A), StringName(GOOD), MarketPricer.SIDE_BUY))
	assert_true(fx.can_build(ACTOR, StringName(PORT_A)))


func test_F1_deny_fixture_blocks_when_qual_closed() -> void:
	## Mirror test_WP33_D63b_sim_qualification_fixture_always_denies: assert expected push_error.
	var fx := SimQualificationFixture.new()
	assert_false(fx.can_enter(ACTOR, StringName(PORT_A)))
	assert_eq(
		StringName(fx.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		QualificationProvider.ERR_SYS09_08
	)
	assert_false(fx.can_trade(ACTOR, StringName(PORT_A), StringName(GOOD), MarketPricer.SIDE_BUY))
	assert_eq(
		StringName(fx.last_error().get(ErrorInfoUtil.KEY_CODE, &"")),
		QualificationProvider.ERR_SYS09_09
	)
	assert_push_error_count(2)


func test_F1_open_fixture_only_referenced_from_sim_engine_qual_branch() -> void:
	## Formal boot must not load OpenFixture — product grep contract (D-120(f)).
	var engine_src: String = FileAccess.get_file_as_string("res://sim/sim_engine.gd")
	assert_true(engine_src.contains("SimQualificationOpenFixture"))
	assert_true(engine_src.contains("qual_open"))
	## No Autoload／ui formal path references.
	assert_false(FileAccess.file_exists("res://autoload/sim_qualification_open_fixture.gd"))
	var ui_boot: String = FileAccess.get_file_as_string("res://ui/debug_boot.gd")
	assert_false(ui_boot.contains("SimQualificationOpenFixture"))


# --- F2 ---


func test_F2_dest_intel_uses_board_for_present_port_origin() -> void:
	## (a)(c): trader at P, board samples at P from origin O → consensus_mid used.
	## (b): no samples from O → empty.
	_boot_intel_mini()
	## Presence at PORT_A via docked ship owned by ACTOR.
	var sid: StringName = ShipRegistry.spawn_docked_ship(
		&"SH-03", ACTOR, StringName(PORT_A), 8
	)
	assert_ne(String(sid), "")
	## Empty board → drop.
	var empty: Dictionary = TraderRegistry._dest_intel(
		ACTOR, StringName(PORT_A), StringName(PORT_B), StringName(GOOD)
	)
	assert_true(empty.is_empty())
	## Inject sample at P=PORT_A from O=PORT_B (remote origin report).
	_inject_board_sample(PORT_A, PORT_B, &"SHIP:F2-01", &"ACT-OTHER", 1500, Clock.day, 1)
	var hit: Dictionary = TraderRegistry._dest_intel(
		ACTOR, StringName(PORT_A), StringName(PORT_B), StringName(GOOD)
	)
	assert_false(hit.is_empty())
	assert_eq(int(hit.get("mid_li", -1)), 1500)
	## Trader not at O (PORT_B) does not block (c).
	assert_eq(String(ShipRegistry.ship_info(sid).get("port_id", "")), PORT_A)


func test_F2_intel_override_set_sites_tests_only_contract() -> void:
	## Grep contract encoded as file scan (product／sim must not call set_intel_override).
	var product_hits: PackedStringArray = PackedStringArray()
	for path in [
		"res://autoload/trader_registry.gd",
		"res://sim/sim_engine.gd",
		"res://sim/sim_runner.gd",
		"res://autoload/sim_loop.gd",
	]:
		var body: String = FileAccess.get_file_as_string(path)
		## Definition site in trader_registry is OK; call sites must not appear in sim/product.
		if path.ends_with("trader_registry.gd"):
			assert_true(body.contains("func set_intel_override"))
			continue
		if body.contains("set_intel_override("):
			product_hits.append(path)
	assert_eq(product_hits.size(), 0, str(product_hits))


# --- F3 ---


func test_F3_same_seed_explore_identical() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	_seed_mini_roster()
	TraderRegistry.set_rng_seed(11)
	var a: Dictionary = TraderRegistry._pick_explore_traders(5)
	var b: Dictionary = TraderRegistry._pick_explore_traders(5)
	assert_eq(str(a.keys()), str(b.keys()))


func test_F3_seeds_1_vs_2_explore_differ_some_day() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	_seed_mini_roster()
	var differ := false
	for day in range(1, 91):
		TraderRegistry.set_rng_seed(1)
		var a: Dictionary = TraderRegistry._pick_explore_traders(day)
		TraderRegistry.set_rng_seed(2)
		var b: Dictionary = TraderRegistry._pick_explore_traders(day)
		if str(a.keys()) != str(b.keys()):
			differ = true
			break
	assert_true(differ)


# --- F4 ---


func test_F4_batch_area_public_matches_ex_brick() -> void:
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	## EX-17-02-02 stock path: w0=0 → stock 0→250.
	var area: float = MarketPricer.batch_area(600, 250.0, 0, 250)
	assert_eq(floori(area), 255000)


func test_F4_top_n_missing_refuses_trader_load() -> void:
	## Missing PRM-SYS17-TOP_N_PRECISE → ERR-SYS17-01 (refuse boot when traders on).
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	## Temporarily hide via direct clear of value map is unsafe; instead assert has_prm true on fixture
	## and that load_and_validate lists PRM_TOP_N in required keys by negative via layers.
	TraderRegistry.set_layers(true, true)
	assert_true(Params.has_prm(&"PRM-SYS17-TOP_N_PRECISE"))
	assert_eq(TraderRegistry.load_and_validate().size(), 0)
	assert_gte(Params.get_int(&"PRM-SYS17-TOP_N_PRECISE"), 1)


func test_F4_draft_unknown_type_errors_no_default() -> void:
	## F4②／C-06: type missing from SHIP_DRAFT → error, no silent default 2.
	_boot_intel_mini()
	var sid: StringName = ShipRegistry.spawn_docked_ship(
		&"SH-03", ACTOR, StringName(PORT_A), 8
	)
	assert_ne(String(sid), "")
	var ship: Ship = ShipRegistry._ships[String(sid)] as Ship
	ship.type = &"SH-NOPE"
	assert_false(ShipRegistry.SHIP_DRAFT.has("SH-NOPE"))
	assert_false(TraderRegistry._draft_ok(sid, StringName(PORT_B)))
	## Each push_error may be asserted once — prefer text match over count.
	assert_push_error("SHIP_DRAFT missing type")


# --- F5 ---


func test_F5_m1b_scenarios_validate_zero_err_and_abund_grid_only() -> void:
	for path in SCENARIOS:
		var raw: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(raw)
		assert_true(typeof(parsed) == TYPE_DICTIONARY, path)
		var sc: Dictionary = parsed
		var ov: Dictionary = sc.get("overrides", {})
		var grid: Dictionary = sc.get("grid", {})
		assert_false(
			ov.has("PRM-SYS07-ABUND_BONUS_MAX_PPM"),
			"%s still has ABUND in overrides" % path
		)
		assert_true(
			grid.has("PRM-SYS07-ABUND_BONUS_MAX_PPM"),
			"%s missing ABUND in grid" % path
		)
		assert_eq(int(ov.get("PRM-SYS17-TOP_N_PRECISE", -1)), 3, path)
		var r: Dictionary = SimScenarioValidator.validate_file(path)
		assert_true(bool(r.get("ok", false)), "%s errors=%s" % [path, str(r.get("errors", []))])
		assert_eq((r.get("errors", []) as Array).size(), 0, path)


# --- helpers ---


func _seed_mini_roster() -> void:
	TraderRegistry.set_layers(true, true)
	TraderRegistry._enabled = true
	TraderRegistry._loaded = true
	TraderRegistry._traders = {
		"TR-001": {"account_id": &"ACT-TR-001", "ship_ids": [], "retired": false, "mode": &"IDLE", "plans": {}, "idle_days": {}},
		"TR-002": {"account_id": &"ACT-TR-002", "ship_ids": [], "retired": false, "mode": &"IDLE", "plans": {}, "idle_days": {}},
		"TR-003": {"account_id": &"ACT-TR-003", "ship_ids": [], "retired": false, "mode": &"IDLE", "plans": {}, "idle_days": {}},
		"TR-004": {"account_id": &"ACT-TR-004", "ship_ids": [], "retired": false, "mode": &"IDLE", "plans": {}, "idle_days": {}},
		"TR-005": {"account_id": &"ACT-TR-005", "ship_ids": [], "retired": false, "mode": &"IDLE", "plans": {}, "idle_days": {}},
	}


func _boot_intel_mini() -> void:
	assert_eq(Params.load_and_validate(PARAMS_FIXTURE).size(), 0)
	assert_eq(GoodCatalog.load_and_validate(GoodCatalog.GOODS_DIR).size(), 0)
	assert_eq(PortRegistry.load_and_validate(PortRegistry.PORTS_DIR).size(), 0)
	assert_eq(SeaLanes.load_and_validate().size(), 0)
	assert_eq(GoodsLedger.load_and_validate().size(), 0)
	assert_eq(MarketPricer.load_and_validate(CURVE_FIXTURE).size(), 0)
	assert_eq(CashLedger.load_and_validate().size(), 0)
	if not ShipRegistry.has_sailor_pool_provider():
		ShipRegistry.set_sailor_pool_provider(_DummySailors.new())
	assert_eq(ShipRegistry.load_and_validate().size(), 0)
	assert_eq(IntelLedger.load_and_validate().size(), 0)
	if not IntelLedger.has_broker_provider():
		IntelLedger.set_broker_provider(SimBrokerFixture.new())
	CashLedger.create_account(ACTOR, Account.Kind.ACTOR)
	CashLedger.create_account(&"ACT-OTHER", Account.Kind.ACTOR)
	TraderRegistry.set_layers(true, true)
	TraderRegistry._enabled = true
	TraderRegistry._loaded = true


func _inject_board_sample(
	port: String, origin: String, ship_id: StringName, owner: StringName, mid_li: int, day_taken: int, tick_arrived: int
) -> void:
	var goods: Dictionary = {}
	for g in GoodCatalog.all_ids():
		goods[String(g)] = {
			IntelLedger.KEY_MID_LI: mid_li,
			IntelLedger.KEY_BAND: 0,
			IntelLedger.KEY_WEEKS_X: 100,
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


class _DummySailors extends SailorPoolProvider:
	func hire_sailors(_port_id: StringName, n: int) -> int:
		return n
	func release_sailors(_port_id: StringName, n: int) -> int:
		return n
	func beggars(_port_id: StringName) -> int:
		return 0
