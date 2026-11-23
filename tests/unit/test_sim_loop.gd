extends GutTest
## WP-08 SimLoop + ConsumptionProvider — TechSpec 2.2／2.3／2.1-03／3.7; Owner D-05／D-03／D-07／D-08e／D-08j.


## R2-13 / 2.1-04 ⑤: curve from fixtures (PRM-SYS04-CURVE_W1–W5 / M1–M5). Formal path after Owner csv_import.
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const DEMAND_CSV_OK := "res://tests/fixtures/demand/ok/"
const DEMAND_OUT := "res://tests/fixtures/demand/out/"
const DEMAND_TABLES_OK := DEMAND_OUT
const GOODS_FIXTURE_ROOT := "user://sim_loop_goods/"
const PORTS_FIXTURE_ROOT := "user://sim_loop_ports/"
const DEMAND_RATE_SCALE := 100
const DEMAND_PPM_SCALE := 1000000
const DEMAND_WEIGHT_SUM := 100

const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_PORT_COUNT_MAX := "PRM-SYS02-PORT_COUNT_MAX"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"

const CsvImport := preload("res://tools/csv_import.gd")
const SEA_FIXTURE_CSV := "res://tests/fixtures/wp29_sea_ok/"
const SEA_FIXTURE_ROOT := "user://sim_loop_sea/"
## D-21a / D-08j: minimal opening CSV for all ports; imported via csv_import into formal dirs.
const OPENING_FIXTURE_CSV := "res://tests/fixtures/sim_loop_opening/"
const FORMAL_ZONES_DIR := "res://data/zones/"
const FORMAL_BUILDINGS_DIR := "res://data/buildings/"
const FORMAL_OPENING_DIR := "res://data/opening/"
const FORMAL_BUILD_QUEUE_DIR := "res://data/build_queue/"
const FORMAL_CITY_CENTER_DIR := "res://data/city_center/"
const FORMAL_OPENING_PUBLIC_DIR := "res://data/opening_public/"
const FORMAL_OPENING_POP_DIR := "res://data/opening_population/"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"

const STAPLE_RICE := "米"
const STAPLE_SALT := "鹽"
const STAPLE_FISH := "魚乾"
const STAPLE_TIMBER := "木材"

const PORT_DEMO := "PT-01"
const GOOD_DEMO := "GD-001"
const ANCHOR_LI := 1000
const SEED_STOCK := 50
const CONSUME_PER_TICK := 3
const PRODUCE_Q := 90


class _TestPopulationProvider extends PopulationProvider:
	func population(_port_id: StringName) -> int:
		return 0


class _TestWorkforceProvider extends WorkforceProvider:
	func workers(_ws_id: StringName) -> int:
		return 0


class _TestSatProvider extends SatisfactionInputProvider:
	func satisfaction_input(_port_id: StringName, _clazz: StringName) -> float:
		return 0.5


class TestConsumptionProvider extends ConsumptionProvider:
	## Fixture double — consume tables only (1-A9／res://tests/). WP-32: weekly_consumption removed.
	var _daily: Dictionary = {} ## "port|good" -> int
	var consume_calls: Array = [] ## ordered {port, good, day}

	func set_daily(port_id: String, good_id: String, c: int) -> void:
		_daily["%s|%s" % [port_id, good_id]] = c

	func consume_qty(port_id: StringName, good_id: StringName, day: int) -> int:
		var port_s := String(port_id)
		var good_s := String(good_id)
		consume_calls.append({"port": port_s, "good": good_s, "day": day})
		var key := "%s|%s" % [port_s, good_s]
		if not _daily.has(key):
			return 0
		return int(_daily[key])


class FixtureBrokerProvider extends BrokerProvider:
	## D-60f／N-05: deny-all fixture so SimLoop.boot gate passes without BrokerDesk.
	func has_kontor(_actor_id: StringName, _port_id: StringName) -> bool:
		return false

	func is_broker_qualified(_actor_id: StringName, _port_id: StringName) -> bool:
		return false


func before_each() -> void:
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	_wipe_dir(SEA_FIXTURE_ROOT)
	_wipe_dir(DEMAND_OUT)
	_wipe_formal_opening_layout()
	_wipe_formal_demand()
	# Reset SimLoop injection between tests (Autoload persists).
	# D-08j: providers only before boot — clear _booted so setters take effect.
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop.set_consumption_provider(null)
	IntelLedger.set_broker_provider(null)
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	DemandModel._clear_state()
	SeaLanes._loaded = false
	# WP-33: TradeDesk injection gate — reset so fixture setters take effect.
	TradeDesk._loaded = false
	TradeDesk._qualification = null
	TradeDesk._observers = []
	TradeDesk._pending_signals = []
	TradeDesk._day_errors = []
	TradeDesk._last_error = {}


func after_each() -> void:
	## 2.1-04 ⑤: leave formal data dirs without test-generated .tres.
	_wipe_formal_opening_layout()


func test_WP59_consumption_provider_base_push_error_2_1_03() -> void:
	# 2.1-03／3.7: 基底方法一律 push_error 並回失敗值（不得回 0）
	# WP-32／15-05: weekly_consumption removed; only consume_qty remains on base.
	var base := ConsumptionProvider.new()
	var c: int = base.consume_qty(&"PT-01", &"GD-001", 1)
	assert_eq(c, ConsumptionProvider.CONSUMPTION_FAILURE)
	assert_push_error_count(1)


func test_WP59_autoload_order_2_2_01() -> void:
	# W1／2.2-01／D-14c／D-26b／D-09a／D-34d／D-23g:
	# Compare actual Autoload order in project.godot (not merely has_setting).
	# … → ShipRegistry → IntelLedger → TraderRegistry → SimLoop
	var expected: Array = [
		"Params",
		"Clock",
		"GoodCatalog",
		"PortRegistry",
		"SeaLanes",
		"GoodsLedger",
		"MarketPricer",
		"CashLedger",
		"TradeDesk",
		"BuildingEconomy",
		"PopulationModel",
		"DemandModel",
		"ShipRegistry",
		"IntelLedger",
		"TraderRegistry",
		"SimLoop",
	]
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	assert_false(text.is_empty(), "project.godot readable")
	var actual: Array = []
	var paths: Dictionary = {}
	var in_autoload := false
	for line_v in text.split("\n"):
		var line: String = String(line_v).strip_edges()
		if line.begins_with("["):
			in_autoload = line == "[autoload]"
			continue
		if not in_autoload or line.is_empty() or line.begins_with(";"):
			continue
		if not line.contains("="):
			continue
		var eq: int = line.find("=")
		var name: String = line.substr(0, eq).strip_edges()
		var path: String = line.substr(eq + 1).strip_edges().trim_prefix("\"").trim_suffix("\"")
		actual.append(name)
		paths[name] = path
	assert_eq(actual, expected, "project.godot [autoload] order mismatch")
	assert_eq(String(paths.get("SimLoop", "")), "*res://autoload/sim_loop.gd")
	assert_eq(String(paths.get("CashLedger", "")), "*res://autoload/cash_ledger.gd")
	assert_eq(String(paths.get("TradeDesk", "")), "*res://autoload/trade_desk.gd")
	assert_eq(String(paths.get("Clock", "")), "*res://autoload/clock.gd")
	assert_eq(String(paths.get("DemandModel", "")), "*res://core/demand_model.gd")


func test_TST_SYS07_20_simloop_boot_sat_provider_detection() -> void:
	## SimLoop.boot detects sat provider via public has_satisfaction_input_provider();
	## injected vs auto-wire; this test never reads PopulationModel._sat_input (C-07).
	assert_true(PopulationModel.has_method("has_satisfaction_input_provider"))
	assert_false(PopulationModel.has_satisfaction_input_provider())
	# --- auto-wire: not injected + demand dir → DemandModel sat ---
	var fixtures := _prepare_fixtures()
	BuildingEconomy.set_population_provider(_TestPopulationProvider.new())
	BuildingEconomy.set_workforce_provider(_TestWorkforceProvider.new())
	_install_opening_fixtures()
	_install_demand_fixtures()
	_inject_broker_fixture()
	_inject_trade_desk_fixtures()
	assert_false(PopulationModel.has_satisfaction_input_provider())
	var errors: Array = SimLoop.boot(
		ParamsFixtures.path_demo(),
		fixtures["goods"],
		fixtures["ports"],
		CURVE_FIXTURE,
		fixtures["sea_nodes"],
		fixtures["sea_regions"],
		fixtures["sea_lanes"],
		DEMAND_TABLES_OK
	)
	assert_eq(errors.size(), 0, "auto-wire boot: %s" % str(errors))
	assert_true(PopulationModel.has_satisfaction_input_provider())
	assert_true(DemandModel.is_loaded())
	# --- injected: has_* true → boot must not require `_` and keeps provider ---
	_reset_simloop_for_reboot()
	fixtures = _prepare_fixtures()
	BuildingEconomy.set_population_provider(_TestPopulationProvider.new())
	BuildingEconomy.set_workforce_provider(_TestWorkforceProvider.new())
	PopulationModel.set_satisfaction_input_provider(_TestSatProvider.new())
	SimLoop.set_consumption_provider(_full_zero_provider())
	_install_opening_fixtures()
	_inject_broker_fixture()
	_inject_trade_desk_fixtures()
	assert_true(PopulationModel.has_satisfaction_input_provider())
	var errors2: Array = SimLoop.boot(
		ParamsFixtures.path_demo(),
		fixtures["goods"],
		fixtures["ports"],
		CURVE_FIXTURE,
		fixtures["sea_nodes"],
		fixtures["sea_regions"],
		fixtures["sea_lanes"],
		DEMAND_TABLES_OK
	)
	assert_eq(errors2.size(), 0, "injected boot: %s" % str(errors2))
	assert_true(PopulationModel.has_satisfaction_input_provider())


func test_WP59_D30a_missing_demand_refuses_boot() -> void:
	## D-30a: no demand dir + no injected consumption → ERR-SYS06-01 refuse boot.
	var fixtures := _prepare_fixtures()
	BuildingEconomy.set_population_provider(_TestPopulationProvider.new())
	BuildingEconomy.set_workforce_provider(_TestWorkforceProvider.new())
	_install_opening_fixtures()
	_inject_broker_fixture()
	var missing := GOODS_FIXTURE_ROOT + "missing_demand/"
	var errors: Array = SimLoop.boot(
		ParamsFixtures.path_demo(),
		fixtures["goods"],
		fixtures["ports"],
		CURVE_FIXTURE,
		fixtures["sea_nodes"],
		fixtures["sea_regions"],
		fixtures["sea_lanes"],
		missing
	)
	assert_gt(errors.size(), 0)
	assert_true(_has_code(errors, DemandModel.ERR_SYS06_01))
	assert_false(SimLoop.is_booted())
	assert_false(DemandModel.is_loaded())
	assert_push_error_count(errors.size())


func test_WP59_D30a_complete_demand_boots() -> void:
	## D-30a: complete demand fixtures → boot without injected ConsumptionProvider.
	var fixtures := _prepare_fixtures()
	BuildingEconomy.set_population_provider(_TestPopulationProvider.new())
	BuildingEconomy.set_workforce_provider(_TestWorkforceProvider.new())
	_install_opening_fixtures()
	_install_demand_fixtures()
	_inject_broker_fixture()
	_inject_trade_desk_fixtures()
	var errors: Array = SimLoop.boot(
		ParamsFixtures.path_demo(),
		fixtures["goods"],
		fixtures["ports"],
		CURVE_FIXTURE,
		fixtures["sea_nodes"],
		fixtures["sea_regions"],
		fixtures["sea_lanes"],
		DEMAND_TABLES_OK
	)
	assert_eq(errors.size(), 0, "complete demand boot: %s" % str(errors))
	assert_true(SimLoop.is_booted())
	assert_true(DemandModel.is_loaded())
	assert_true(PopulationModel.has_satisfaction_input_provider())


func test_WP59_boot_requires_consumption_provider_2_3_03() -> void:
	# 2.3-03: 未注入 provider → boot() 回錯誤且不啟動時鐘
	var fixtures := _prepare_fixtures()
	var errors: Array = _boot_with_fixtures(fixtures)
	assert_gt(errors.size(), 0)
	assert_true(_has_code(errors, SimLoop.ERR_PROVIDER_MISSING))
	assert_false(SimLoop.is_booted())
	assert_push_error_count(errors.size())
	SimLoop.tick_day()
	assert_push_error_count(errors.size() + 1)


func test_WP59_boot_collects_all_module_errors_2_2_02() -> void:
	# 2.2-02: 不得在第一個錯誤就停止收集 — empty goods／ports still run later loads
	var cons := _full_zero_provider()
	SimLoop.set_consumption_provider(cons)
	var empty_goods := GOODS_FIXTURE_ROOT + "empty_g/"
	var empty_ports := PORTS_FIXTURE_ROOT + "empty_p/"
	var empty_sea := SEA_FIXTURE_ROOT + "empty_sea/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_goods))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_ports))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_sea + "nodes/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_sea + "regions/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_sea + "lanes/"))
	_inject_broker_fixture()
	var errors: Array = SimLoop.boot(
		ParamsFixtures.path_demo(),
		empty_goods,
		empty_ports,
		CURVE_FIXTURE,
		empty_sea + "nodes/",
		empty_sea + "regions/",
		empty_sea + "lanes/"
	)
	assert_gt(errors.size(), 1, "must collect errors from multiple modules")
	assert_false(SimLoop.is_booted())
	assert_push_error_count(errors.size())
	## W2: per-module collection (no tautology or); empty goods → catalog, then ports／sea continue.
	assert_true(_has_code(errors, "ERR-SYS01-04"), "GoodCatalog empty count → ERR-SYS01-04")
	assert_true(
		_has_code(errors, "GOOD_CATALOG_NOT_LOADED"),
		"PortRegistry must still run and report GOOD_CATALOG_NOT_LOADED"
	)
	assert_true(
		_has_code(errors, "PORT_REGISTRY_NOT_LOADED"),
		"SeaLanes must still run and report PORT_REGISTRY_NOT_LOADED"
	)


func test_WP59_boot_day_zero_and_genesis_grant_D03_D05() -> void:
	# D-05(b): boot day=0；D-03: genesis_grant once after validation
	var cons := _boot_ready_provider()
	assert_true(SimLoop.is_booted())
	assert_eq(Clock.day, 0)
	assert_eq(Clock._tick, 0)
	assert_eq(Clock.season_index, 0)
	var start: int = Params.get_int(CashLedger.PRM_START_CASH)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), start)
	assert_eq(CashLedger.balance(CashLedger.ID_SOURCE), 0 - start)


func test_WP59_first_tick_runs_k0_produce_D05() -> void:
	# D-05(b)／D-12d／D-09g: first tick → day=1；role-cell PRODUCE removed (WP-20).
	var cons := _boot_ready_provider()
	_set_producer_output(PORT_DEMO, GOOD_DEMO, PRODUCE_Q)
	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	var before: int = GoodsLedger.get_qty(market, StringName(GOOD_DEMO))
	var day_errors: Array = SimLoop.tick_day()
	assert_eq(day_errors.size(), 0)
	assert_eq(Clock.day, 1)
	# No workshops → market unchanged despite role-cell Q (D-12d).
	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD_DEMO)), before)


func test_WP59_boot_success_and_tick_advances_clock_2_3_01() -> void:
	# 2.3-01／D-05: boot day=0 → tick → day=1
	_boot_ready_provider()
	assert_eq(Clock.day, 0)
	SimLoop.tick_day()
	assert_eq(Clock.day, 1)


func test_WP59_tick_consume_ascending_order_no_role_cell_produce_2_3_03() -> void:
	# W3／2.3-03／D-12d／D-09g: with empty workshops, tick runs CONSUME ascending (port, good);
	# role-cell Q no longer feeds MARKET (no PRODUCE events). Name matches behaviour.
	var cons := _boot_ready_provider()
	_set_producer_output(PORT_DEMO, GOOD_DEMO, PRODUCE_Q)
	_seed_market(PORT_DEMO, GOOD_DEMO, SEED_STOCK)
	cons.set_daily(PORT_DEMO, GOOD_DEMO, CONSUME_PER_TICK)

	var reasons: Array = []
	GoodsLedger.goods_transferred.connect(func(event: TransferEvent):
		reasons.append(String(event.reason))
	)

	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	var before: int = GoodsLedger.get_qty(market, StringName(GOOD_DEMO))
	SimLoop.tick_day()
	var after: int = GoodsLedger.get_qty(market, StringName(GOOD_DEMO))
	assert_eq(after, before - CONSUME_PER_TICK)

	assert_gt(reasons.size(), 0)
	assert_eq(reasons.find(String(GoodsLedger.REASON_PRODUCE)), 0 - 1, "no role-cell PRODUCE")
	var first_consume_i: int = reasons.find(String(GoodsLedger.REASON_CONSUME))
	assert_gte(first_consume_i, 0)

	assert_gt(cons.consume_calls.size(), 1)
	for i in range(cons.consume_calls.size() - 1):
		var a: Dictionary = cons.consume_calls[i]
		var b: Dictionary = cons.consume_calls[i + 1]
		var ok: bool = String(a["port"]) < String(b["port"]) or (
			String(a["port"]) == String(b["port"]) and String(a["good"]) <= String(b["good"])
		)
		assert_true(ok, "consume order must be ascending (port, good)")


func test_WP59_step6_emits_day_ticked_after_writes_D05() -> void:
	# D-05(a)／2.3-06: day_ticked only after step writes；Clock.advance does not emit
	_boot_ready_provider()
	var ticked: Array = []
	var saw_day_at_signal: Array = []
	Clock.day_ticked.connect(func(day: int):
		ticked.append(day)
		saw_day_at_signal.append(Clock.day)
	)
	SimLoop.tick_day()
	assert_eq(ticked.size(), 1)
	assert_eq(ticked[0], 1)
	assert_eq(saw_day_at_signal[0], 1)


func test_WP59_tick_paused_push_error_no_progress() -> void:
	# GP-01 via SimLoop: paused → push_error, day unchanged
	_boot_ready_provider()
	Clock.set_paused(true)
	var day_before: int = Clock.day
	SimLoop.tick_day()
	assert_push_error_count(1)
	assert_eq(Clock.day, day_before)
	Clock.set_paused(false)


func test_WP59_season_cutoff_close_season_index_zero_D05() -> void:
	# 2.3-05／D-05(c): day_in_season == D → close_season；首季 season_index=0（非 −1）
	_boot_ready_provider()
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	var closed: Array = []
	var cutoffs: Array = []
	CashLedger.season_ledger_closed.connect(func(season_index: int, _report: SeasonLedgerReport):
		closed.append(season_index)
	)
	Clock.season_cutoff.connect(func(s: int):
		cutoffs.append(s)
	)
	# boot day=0 → need D ticks to land on day D.
	for _i in range(days_d):
		SimLoop.tick_day()
	assert_eq(Clock.day, days_d)
	assert_eq(Clock.season_index, 0)
	assert_eq(closed.size(), 1, "close_season must run on day_in_season == D")
	assert_eq(closed[0], 0, "D-05(c): first season_ledger_closed index must be 0")
	assert_eq(cutoffs.size(), 1)
	assert_eq(cutoffs[0], 0, "D-05(c): first season_cutoff index must be 0")


func test_WP59_consume_shortage_err_sys03_02_into_day_errors_D05() -> void:
	# D-05(d): CONSUME 不足 → ERR-SYS03-02、全有或全無、進當日錯誤清單
	var cons := _boot_ready_provider()
	# No seed stock; demand > 0 → shortage
	cons.set_daily(PORT_DEMO, GOOD_DEMO, CONSUME_PER_TICK)
	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD_DEMO)), 0)
	var day_errors: Array = SimLoop.tick_day()
	assert_gt(day_errors.size(), 0)
	assert_true(_has_err_code(day_errors, GoodsLedger.ERR_SYS03_02))
	# GoodsLedger._fail + SimLoop consume path each push_error once
	assert_push_error_count(2)
	# all-or-nothing: still 0
	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD_DEMO)), 0)


func test_WP59_conservation_runs_on_tick_when_debug_prm() -> void:
	# T3／2.3-04: prove SimLoop.tick_day invokes maybe_check_conservation_on_tick
	# (manual post-tick check_conservation would pass even if SimLoop forgot the call).
	_boot_ready_provider()
	assert_true(
		Params.get_bool(GoodsLedger.PRM_CONSERVATION_CHECK_EVERY_TICK),
		"fixture debug PRM must enable per-tick conservation"
	)
	var good: StringName = StringName(GoodCatalog.all_ids()[0])
	var key: String = String(
		GoodsLedger.container_id(StringName(GoodsLedger.KIND_MARKET), PORT_DEMO)
	)
	if not GoodsLedger._stock.has(key):
		GoodsLedger._stock[key] = {}
	var bucket: Dictionary = GoodsLedger._stock[key]
	bucket[String(good)] = int(bucket.get(String(good), 0)) + 1
	GoodsLedger._stock[key] = bucket
	var hits: Array = [0]
	var on_hit := func(_g: StringName, _e: int, _a: int) -> void:
		hits[0] = int(hits[0]) + 1
	GoodsLedger.conservation_violated.connect(on_hit)
	SimLoop.tick_day()
	if GoodsLedger.conservation_violated.is_connected(on_hit):
		GoodsLedger.conservation_violated.disconnect(on_hit)
	assert_eq(int(hits[0]), 1, "SimLoop.tick_day must call conservation check when PRM true")
	## ERR-SYS03-05 push_error from the check invoked inside tick_day (not post-hoc).
	assert_push_error_count(1)


func test_WP59_no_public_subday_methods_D07() -> void:
	# D-07（SimLoop 仍無公開子日推進）／D-14d（Clock.advance_one_tick 已撤銷禁令）
	assert_false(SimLoop.has_method("advance_one_tick"))
	assert_false(SimLoop.has_method("tick_subday"))
	assert_true(Clock.has_method("advance_one_tick"))
	assert_false(Clock.has_method("advance_ticks"))
	# 13-02／C-04: tick 步驟清單為 SimLoop 內明確步驟（WP-28 為空）
	assert_true(SimLoop.has_method("_run_tick_steps"))


func test_TST_SYS13_16_tick_day_clock_matches_advance_one_day() -> void:
	# W3／13-03／TST-SYS13-16／D-09g／D-12d: tick_day clock (tick/day) matches advance_one_day
	# and TPD×advance_one_tick; with no workshops both paths leave market qty unchanged.
	_boot_ready_provider()
	var tpd: int = Params.get_int("PRM-SYS00-TICKS_PER_DAY")
	_set_producer_output(PORT_DEMO, GOOD_DEMO, PRODUCE_Q)
	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	var before: int = GoodsLedger.get_qty(market, StringName(GOOD_DEMO))
	SimLoop.tick_day()
	var tick_via_loop: int = Clock.tick
	var day_via_loop: int = Clock.day
	var qty_via_loop: int = GoodsLedger.get_qty(market, StringName(GOOD_DEMO))
	assert_eq(tick_via_loop, tpd)
	assert_eq(day_via_loop, 1)
	assert_eq(qty_via_loop, before, "D-12d: no role-cell PRODUCE")

	_reset_simloop_for_reboot()
	_boot_ready_provider()
	Clock.advance_one_day()
	assert_eq(Clock.tick, tick_via_loop)
	assert_eq(Clock.day, day_via_loop)

	_reset_simloop_for_reboot()
	_boot_ready_provider()
	_set_producer_output(PORT_DEMO, GOOD_DEMO, PRODUCE_Q)
	for _i in range(tpd):
		Clock.advance_one_tick()
	assert_eq(Clock.tick, tpd)
	assert_eq(Clock.day, 1)
	GoodsLedger.set_day(Clock.day)
	CashLedger.set_day(Clock.day)
	BuildingEconomy.daily_step(Clock.day)
	var qty_via_ticks: int = GoodsLedger.get_qty(
		GoodsLedger.make_market(PORT_DEMO), StringName(GOOD_DEMO)
	)
	assert_eq(qty_via_ticks, qty_via_loop)
	assert_eq(qty_via_ticks, before, "no workshops → market unchanged on both paths")


func test_WP59_D08j_public_api_names_match_ruling() -> void:
	# D-08j／TST: five public APIs; #11 names already matched — no rename beyond ruling.
	assert_true(SimLoop.has_method("boot"))
	assert_true(SimLoop.has_method("tick_day"))
	assert_true(SimLoop.has_method("is_booted"))
	assert_true(SimLoop.has_method("set_consumption_provider"))
	assert_true(SimLoop.has_method("register_capacity_provider"))


func test_WP59_D08j_set_consumption_provider_ignored_after_boot() -> void:
	# D-08j／TST: set_consumption_provider after boot → push_error, no effect
	var first := _boot_ready_provider()
	var second := TestConsumptionProvider.new()
	SimLoop.set_consumption_provider(second)
	assert_push_error_count(1)
	assert_eq(SimLoop._consumption, first)


func test_WP59_D08e_register_capacity_provider_before_boot_applies() -> void:
	# D-08e／TST: register before boot; applied after GoodsLedger.load_and_validate
	var fixtures := _prepare_fixtures()
	var cons := _full_zero_provider()
	SimLoop.set_consumption_provider(cons)
	BuildingEconomy.set_population_provider(_TestPopulationProvider.new())
	BuildingEconomy.set_workforce_provider(_TestWorkforceProvider.new())
	PopulationModel.set_satisfaction_input_provider(_TestSatProvider.new())
	var cap := _TestCapProvider.new()
	cap.set_cap(GoodsLedger.KIND_WAREHOUSE, 10)
	SimLoop.register_capacity_provider(GoodsLedger.KIND_WAREHOUSE, cap)
	var errors: Array = _boot_with_fixtures(fixtures)
	assert_eq(errors.size(), 0, "boot must succeed: %s" % str(errors))
	assert_true(SimLoop.is_booted())
	var wh: Dictionary = GoodsLedger.make_warehouse("ACT-PLAYER", PORT_DEMO)
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		wh,
		StringName(GOOD_DEMO),
		4,
		GoodsLedger.REASON_GENESIS,
		&"TEST"
	)
	assert_gt(seq, 0)
	var fail: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		wh,
		StringName(GOOD_DEMO),
		10,
		GoodsLedger.REASON_GENESIS,
		&"TEST"
	)
	assert_eq(fail, 0)
	assert_true(_last_goods_err_is(GoodsLedger.ERR_SYS03_03))
	assert_push_error_count(1)


func test_WP59_D08e_register_capacity_provider_ignored_after_boot() -> void:
	# D-08e／D-08j／TST: register after boot → push_error, no effect
	# WP-30: HOLD may already be registered from ShipRegistry at boot; use a fresh kind.
	_boot_ready_provider()
	var before_keys: Array = SimLoop._capacity_by_kind.keys()
	var before_hold: Variant = SimLoop._capacity_by_kind.get(GoodsLedger.KIND_HOLD, null)
	var cap := _TestCapProvider.new()
	cap.set_cap(GoodsLedger.KIND_HOLD, 99)
	SimLoop.register_capacity_provider(GoodsLedger.KIND_HOLD, cap)
	assert_push_error_count(1)
	assert_eq(SimLoop._capacity_by_kind.keys(), before_keys)
	assert_eq(SimLoop._capacity_by_kind.get(GoodsLedger.KIND_HOLD, null), before_hold)
	assert_ne(SimLoop._capacity_by_kind.get(GoodsLedger.KIND_HOLD, null), cap)


func test_WP59_D08e_duplicate_kind_err_sys03_06_blocks_boot() -> void:
	# D-08e／TST: duplicate kind → ERR-SYS03-06；boot collects and refuses
	var fixtures := _prepare_fixtures()
	var cons := _full_zero_provider()
	SimLoop.set_consumption_provider(cons)
	BuildingEconomy.set_population_provider(_TestPopulationProvider.new())
	BuildingEconomy.set_workforce_provider(_TestWorkforceProvider.new())
	PopulationModel.set_satisfaction_input_provider(_TestSatProvider.new())
	var a := _TestCapProvider.new()
	a.set_cap(GoodsLedger.KIND_WAREHOUSE, 5)
	var b := _TestCapProvider.new()
	b.set_cap(GoodsLedger.KIND_WAREHOUSE, 50)
	SimLoop.register_capacity_provider(GoodsLedger.KIND_WAREHOUSE, a)
	SimLoop.register_capacity_provider(GoodsLedger.KIND_WAREHOUSE, b)
	assert_push_error_count(1)
	assert_eq(SimLoop._capacity_by_kind[GoodsLedger.KIND_WAREHOUSE], a)
	var errors: Array = _boot_with_fixtures(fixtures)
	assert_gt(errors.size(), 0)
	assert_true(_has_err_code(errors, GoodsLedger.ERR_SYS03_06))
	assert_false(SimLoop.is_booted())


# --- helpers ---


func _inject_trade_desk_fixtures() -> void:
	## WP-33／N-05: test-only fixtures (not product always-allow providers).
	TradeDesk._loaded = false
	TradeDesk.set_qualification_provider(FixtureQualificationProvider.new())
	TradeDesk.set_trade_observers([
		FixtureTradeObserver.new(),
		FixtureTradeObserver.new(),
	])


func _boot_with_fixtures(fixtures: Dictionary) -> Array:
	## D-21a: every boot path runs opening validation; seed formal dirs from CSV fixtures.
	_install_opening_fixtures()
	_inject_broker_fixture()
	_inject_trade_desk_fixtures()
	return SimLoop.boot(
		ParamsFixtures.path_demo(),
		fixtures["goods"],
		fixtures["ports"],
		CURVE_FIXTURE,
		fixtures["sea_nodes"],
		fixtures["sea_regions"],
		fixtures["sea_lanes"]
	)


func _inject_broker_fixture() -> void:
	## D-60f: inject before SimLoop.boot（load_and_validate keeps provider）.
	IntelLedger.set_broker_provider(FixtureBrokerProvider.new())


func _install_opening_fixtures() -> void:
	## Per-port rows via csv_import (D-21a／2.1-04 ⑤) — not hand-written formal tres.
	var wp17: Dictionary = CsvImport.run_batch_wp17(
		OPENING_FIXTURE_CSV,
		FORMAL_ZONES_DIR,
		FORMAL_BUILDINGS_DIR,
		FORMAL_OPENING_DIR,
		FORMAL_BUILD_QUEUE_DIR
	)
	assert_true(wp17["ok"], "opening wp17 import: %s" % str(wp17.get("errors", [])))
	var wp18: Dictionary = CsvImport.run_batch_wp18(
		OPENING_FIXTURE_CSV, FORMAL_CITY_CENTER_DIR, FORMAL_OPENING_PUBLIC_DIR
	)
	assert_true(wp18["ok"], "opening wp18 import: %s" % str(wp18.get("errors", [])))
	var pop: Dictionary = CsvImport.run_batch_opening_population(
		OPENING_FIXTURE_CSV,
		FORMAL_OPENING_POP_DIR,
		OPENING_FIXTURE_CSV.path_join("ports.csv")
	)
	assert_true(pop["ok"], "opening population import: %s" % str(pop.get("errors", [])))


func _install_demand_fixtures() -> void:
	## WP-34／D-36c: fixture CSV → tres via csv_import (no handwritten demand_tables.json).
	var result: Dictionary = CsvImport.run_batch_demand(
		DEMAND_CSV_OK,
		DEMAND_OUT.path_join("rates/"),
		DEMAND_OUT.path_join("weights/"),
		DEMAND_OUT.path_join("substitutions/"),
		DEMAND_RATE_SCALE,
		DEMAND_PPM_SCALE,
		DEMAND_WEIGHT_SUM
	)
	assert_true(result["ok"], "demand import: %s" % str(result.get("errors", [])))


func _wipe_formal_demand() -> void:
	for dir_path in [
		CsvImport.DEMAND_RATES_OUT_DIR,
		CsvImport.DEMAND_WEIGHTS_OUT_DIR,
		CsvImport.DEMAND_SUBST_OUT_DIR,
	]:
		_wipe_tres_only(dir_path)


func _wipe_formal_opening_layout() -> void:
	## Remove only .tres; keep .gitkeep so 2.1-04 ⑤／repo placeholders stay intact.
	for dir_path in [
		FORMAL_ZONES_DIR,
		FORMAL_BUILDINGS_DIR,
		FORMAL_OPENING_DIR,
		FORMAL_BUILD_QUEUE_DIR,
		FORMAL_CITY_CENTER_DIR,
		FORMAL_OPENING_PUBLIC_DIR,
		FORMAL_OPENING_POP_DIR,
	]:
		_wipe_tres_only(dir_path)


func _wipe_tres_only(dir: String) -> void:
	var abs_path := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_path)
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".tres"):
			d.remove(fn)
		fn = d.get_next()
	d.list_dir_end()


class _TestCapProvider extends CapacityProvider:
	var _caps: Dictionary = {} ## kind:String -> int

	func set_cap(kind: String, cap: int) -> void:
		_caps[kind] = cap

	func capacity(container: Variant) -> int:
		if typeof(container) != TYPE_DICTIONARY:
			return CAPACITY_FAILURE
		var kind: String = String(container.get(GoodsLedger.KEY_KIND, ""))
		if not _caps.has(kind):
			return CAPACITY_FAILURE
		return int(_caps[kind])


func _last_goods_err_is(code: StringName) -> bool:
	var info: Dictionary = GoodsLedger.last_error()
	return String(info.get("code", "")) == String(code)


func _reset_simloop_for_reboot() -> void:
	# Mirror before_each so a test may boot more than once without D-08j／D-11d errors.
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	_wipe_dir(DEMAND_OUT)
	_wipe_formal_opening_layout()
	_wipe_formal_demand()
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop.set_consumption_provider(null)
	IntelLedger.set_broker_provider(null)
	BuildingEconomy._loaded = false
	BuildingEconomy._population = null
	BuildingEconomy._workforce = null
	PopulationModel._loaded = false
	PopulationModel._sat_input = null
	DemandModel._clear_state()
	TradeDesk._loaded = false
	TradeDesk._qualification = null
	TradeDesk._observers = []
	TradeDesk._pending_signals = []
	TradeDesk._day_errors = []
	TradeDesk._last_error = {}


func _boot_ready_provider() -> TestConsumptionProvider:
	var fixtures := _prepare_fixtures()
	var cons := _full_zero_provider()
	SimLoop.set_consumption_provider(cons)
	BuildingEconomy.set_population_provider(_TestPopulationProvider.new())
	BuildingEconomy.set_workforce_provider(_TestWorkforceProvider.new())
	PopulationModel.set_satisfaction_input_provider(_TestSatProvider.new())
	var errors: Array = _boot_with_fixtures(fixtures)
	assert_eq(errors.size(), 0, "boot must succeed: %s" % str(errors))
	assert_true(SimLoop.is_booted())
	Clock.set_paused(false)
	return cons


func _full_zero_provider() -> TestConsumptionProvider:
	var cons := TestConsumptionProvider.new()
	return cons


func _prepare_fixtures() -> Dictionary:
	var perr: Array = Params.load_and_validate(ParamsFixtures.path_demo())
	assert_eq(perr.size(), 0, "params fixture")
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "base/", ANCHOR_LI)
	var gerr: Array = GoodCatalog.load_and_validate(goods_dir)
	assert_eq(gerr.size(), 0)
	# SeaLanes FRM-SYS14-01 requires 16 PORT nodes; use PORT_COUNT_MAX.
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MAX)
	var ports_dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "base/")
	var sea := _install_sea_fixture(SEA_FIXTURE_ROOT + "ok/")
	return {
		"goods": goods_dir,
		"ports": ports_dir,
		"sea_nodes": sea["nodes"],
		"sea_regions": sea["regions"],
		"sea_lanes": sea["lanes"],
	}


func _install_sea_fixture(out_root: String) -> Dictionary:
	var nodes_dir: String = out_root.path_join("nodes/")
	var regions_dir: String = out_root.path_join("regions/")
	var lanes_dir: String = out_root.path_join("lanes/")
	_wipe_dir(nodes_dir)
	_wipe_dir(regions_dir)
	_wipe_dir(lanes_dir)
	var result: Dictionary = CsvImport.run_batch_wp29(
		SEA_FIXTURE_CSV, nodes_dir, regions_dir, lanes_dir
	)
	assert_true(result["ok"], "sea fixture import must succeed: %s" % str(result["errors"]))
	return {"nodes": nodes_dir, "regions": regions_dir, "lanes": lanes_dir}


func _seed_market(port_id: String, good_id: String, stock: int) -> void:
	if stock <= 0:
		return
	var seq: int = GoodsLedger.transfer(
		GoodsLedger.make_external(),
		GoodsLedger.make_market(port_id),
		StringName(good_id),
		stock,
		GoodsLedger.REASON_GENESIS,
		&"TEST"
	)
	assert_gt(seq, 0)


func _set_producer_output(port_id: String, good_id: String, q: int) -> void:
	var def: PortDef = PortRegistry.get_port(port_id)
	var cell: RoleCell = def.role_cells[good_id]
	cell.base_output_per_season = q


func _has_code(errors: Array, code: String) -> bool:
	for e in errors:
		if typeof(e) == TYPE_DICTIONARY and String(e.get("code", "")) == code:
			return true
	return false


func _has_err_code(errors: Array, code: StringName) -> bool:
	for e in errors:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var c: Variant = e.get("code", "")
		if String(c) == String(code):
			return true
	return false


func _build_valid_goods(dir: String, anchor_li: int) -> String:
	_wipe_dir(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var count: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var staples: Array = [
		{"id": GOOD_DEMO, "name": STAPLE_RICE, "build": false},
		{"id": "GD-002", "name": STAPLE_SALT, "build": false},
		{"id": "GD-003", "name": STAPLE_TIMBER, "build": true},
		{"id": "GD-004", "name": STAPLE_FISH, "build": false},
	]
	var free_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	var written: int = 0
	for s in staples:
		if written >= count:
			break
		ResourceSaver.save(
			_make_good(s["id"], s["name"], 1, true, s["build"], false, anchor_li),
			dir + "%s.tres" % s["id"]
		)
		written += 1
	var next_n: int = 5
	while written < count:
		var gid := "GD-%03d" % next_n
		var tier: int = (next_n % (free_max + 1)) + 1
		if tier > Params.get_int(PRM_TIER_MAX):
			tier = Params.get_int(PRM_TIER_MAX)
		ResourceSaver.save(
			_make_good(gid, "填料%d" % next_n, tier, false, false, false, anchor_li),
			dir + "%s.tres" % gid
		)
		written += 1
		next_n += 1
	return dir


func _build_valid_ports(port_count: int, dir: String) -> String:
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
	if port_count <= 0:
		return 0
	var free_count: int = 0
	while free_count <= port_count:
		var ratio: float = float(free_count) / float(port_count)
		if ratio >= ratio_min and ratio <= ratio_max:
			return free_count
		free_count += 1
	return 0


func _make_good(
	good_id: String,
	name_zh: String,
	tier: int,
	is_staple: bool,
	is_build_material: bool,
	is_strategic: bool,
	base_price_li: int
) -> GoodDef:
	var def := GoodDef.new()
	def.good_id = good_id
	def.name_zh = name_zh
	def.tier = tier
	def.is_staple = is_staple
	def.is_build_material = is_build_material
	def.is_strategic = is_strategic
	def.base_price_li = base_price_li
	# D-08a: year-full from PRM-SYS00-SEASONS_PER_YEAR (never literal 15).
	def.season_mask = (1 << Params.get_int(PRM_SEASONS_PER_YEAR)) - 1
	return def


func _wipe_dir(dir: String) -> void:
	var abs_path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs_path):
		var d := DirAccess.open(dir)
		if d:
			d.list_dir_begin()
			var fn := d.get_next()
			while fn != "":
				if not d.current_is_dir():
					d.remove(fn)
				fn = d.get_next()
			d.list_dir_end()
	DirAccess.make_dir_recursive_absolute(abs_path)
