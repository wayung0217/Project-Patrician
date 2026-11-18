extends GutTest
## WP-08 SimLoop + ConsumptionProvider — TechSpec 2.2／2.3／2.1-03／3.7; Owner D-05／D-03／D-07／D-08e／D-08j.


const PARAMS_FIXTURE := "res://tests/fixtures/params_sys05_demo.json"
## R2-13 / 2.1-04 ⑤: curve from fixtures (PRM-SYS04-CURVE_W1–W5 / M1–M5). Formal path after Owner csv_import.
const CURVE_FIXTURE := "res://tests/fixtures/price_curve.tres"
const GOODS_FIXTURE_ROOT := "user://sim_loop_goods/"
const PORTS_FIXTURE_ROOT := "user://sim_loop_ports/"

const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_SEASONS_PER_YEAR := "PRM-SYS00-SEASONS_PER_YEAR"
const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"
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


class TestConsumptionProvider extends ConsumptionProvider:
	## Fixture double — weekly + consume tables only (1-A9／res://tests/).
	var _weekly: Dictionary = {} ## "port|good" -> int
	var _daily: Dictionary = {} ## "port|good" -> int
	var consume_calls: Array = [] ## ordered {port, good, day}

	func set_weekly(port_id: String, good_id: String, c: int) -> void:
		_weekly["%s|%s" % [port_id, good_id]] = c

	func set_daily(port_id: String, good_id: String, c: int) -> void:
		_daily["%s|%s" % [port_id, good_id]] = c

	func weekly_consumption(port_id: StringName, good_id: StringName) -> int:
		var key := "%s|%s" % [String(port_id), String(good_id)]
		if not _weekly.has(key):
			return 0
		return int(_weekly[key])

	func consume_qty(port_id: StringName, good_id: StringName, day: int) -> int:
		var port_s := String(port_id)
		var good_s := String(good_id)
		consume_calls.append({"port": port_s, "good": good_s, "day": day})
		var key := "%s|%s" % [port_s, good_s]
		if not _daily.has(key):
			return 0
		return int(_daily[key])


func before_each() -> void:
	_wipe_dir(GOODS_FIXTURE_ROOT)
	_wipe_dir(PORTS_FIXTURE_ROOT)
	# Reset SimLoop injection between tests (Autoload persists).
	# D-08j: providers only before boot — clear _booted so setters take effect.
	SimLoop._booted = false
	SimLoop._capacity_by_kind.clear()
	SimLoop._capacity_reg_errors.clear()
	SimLoop._capacity_router = null
	SimLoop.set_consumption_provider(null)


func test_consumption_provider_base_push_error_2_1_03() -> void:
	# 2.1-03／3.7: 基底方法一律 push_error 並回失敗值（不得回 0）
	var base := ConsumptionProvider.new()
	var w: int = base.weekly_consumption(&"PT-01", &"GD-001")
	assert_eq(w, ConsumptionProvider.CONSUMPTION_FAILURE)
	var c: int = base.consume_qty(&"PT-01", &"GD-001", 1)
	assert_eq(c, ConsumptionProvider.CONSUMPTION_FAILURE)
	assert_push_error_count(1 + 1)


func test_autoload_order_2_2_01() -> void:
	# 2.2-01: Params → Clock → GoodCatalog → PortRegistry → GoodsLedger → MarketPricer → CashLedger → SimLoop
	var expected: Array = [
		"Params",
		"Clock",
		"GoodCatalog",
		"PortRegistry",
		"GoodsLedger",
		"MarketPricer",
		"CashLedger",
		"SimLoop",
	]
	for name_variant in expected:
		var name: String = String(name_variant)
		assert_true(
			ProjectSettings.has_setting("autoload/%s" % name),
			"missing Autoload %s" % name
		)
	assert_eq(
		String(ProjectSettings.get_setting("autoload/SimLoop")),
		"*res://autoload/sim_loop.gd"
	)
	assert_eq(
		String(ProjectSettings.get_setting("autoload/CashLedger")),
		"*res://autoload/cash_ledger.gd"
	)
	assert_eq(
		String(ProjectSettings.get_setting("autoload/Clock")),
		"*res://autoload/clock.gd"
	)


func test_boot_requires_consumption_provider_2_3_03() -> void:
	# 2.3-03: 未注入 provider → boot() 回錯誤且不啟動時鐘
	var fixtures := _prepare_fixtures()
	var errors: Array = SimLoop.boot(
		PARAMS_FIXTURE, fixtures["goods"], fixtures["ports"], CURVE_FIXTURE
	)
	assert_gt(errors.size(), 0)
	assert_true(_has_code(errors, SimLoop.ERR_PROVIDER_MISSING))
	assert_false(SimLoop.is_booted())
	assert_push_error_count(errors.size())
	SimLoop.tick_day()
	assert_push_error_count(errors.size() + 1)


func test_boot_collects_all_module_errors_2_2_02() -> void:
	# 2.2-02: 不得在第一個錯誤就停止收集 — empty goods／ports still run later loads
	var cons := _full_zero_provider()
	SimLoop.set_consumption_provider(cons)
	var empty_goods := GOODS_FIXTURE_ROOT + "empty_g/"
	var empty_ports := PORTS_FIXTURE_ROOT + "empty_p/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_goods))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_ports))
	var errors: Array = SimLoop.boot(
		PARAMS_FIXTURE, empty_goods, empty_ports, CURVE_FIXTURE
	)
	assert_gt(errors.size(), 1, "must collect errors from multiple modules")
	assert_false(SimLoop.is_booted())
	assert_push_error_count(errors.size())
	assert_true(_has_code(errors, "ERR-SYS01-04") or _has_code(errors, "ERR-SYS01-05"))
	assert_true(_has_code(errors, "GOOD_CATALOG_NOT_LOADED") or _has_code(errors, "PORT_REGISTRY_NOT_LOADED") or errors.size() > 1)


func test_boot_day_zero_and_genesis_grant_D03_D05() -> void:
	# D-05(b): boot day=0；D-03: genesis_grant once after validation
	var cons := _boot_ready_provider()
	assert_true(SimLoop.is_booted())
	assert_eq(Clock.day, 0)
	assert_eq(Clock._tick, 0)
	assert_eq(Clock.season_index, 0)
	var start: int = Params.get_int(CashLedger.PRM_START_CASH)
	assert_eq(CashLedger.balance(CashLedger.ACCOUNT_PLAYER), start)
	assert_eq(CashLedger.balance(CashLedger.ID_SOURCE), 0 - start)


func test_first_tick_runs_k0_produce_D05() -> void:
	# D-05(b): first tick → day=1，k=0 PRODUCE（不得跳過）
	var cons := _boot_ready_provider()
	_set_producer_output(PORT_DEMO, GOOD_DEMO, PRODUCE_Q)
	var market: Dictionary = GoodsLedger.make_market(PORT_DEMO)
	var before: int = GoodsLedger.get_qty(market, StringName(GOOD_DEMO))
	var day_errors: Array = SimLoop.tick_day()
	assert_eq(day_errors.size(), 0)
	assert_eq(Clock.day, 1)
	var produced: int = GoodsLedger.daily_produce_qty(PRODUCE_Q, 0)
	assert_eq(GoodsLedger.get_qty(market, StringName(GOOD_DEMO)), before + produced)
	assert_eq(produced, GoodsLedger.daily_produce_qty(PRODUCE_Q, 0))


func test_boot_success_and_tick_advances_clock_2_3_01() -> void:
	# 2.3-01／D-05: boot day=0 → tick → day=1
	_boot_ready_provider()
	assert_eq(Clock.day, 0)
	SimLoop.tick_day()
	assert_eq(Clock.day, 1)


func test_tick_produce_then_consume_order_2_3_02_03() -> void:
	# 2.3-02／2.3-03: PRODUCE 後 CONSUME；consume 呼叫依 (port_id, good_id) 升序
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

	# First tick: day 0→1；k=0；produce out(0) then consume
	var k: int = 0
	var produced: int = GoodsLedger.daily_produce_qty(PRODUCE_Q, k)
	assert_eq(after, before + produced - CONSUME_PER_TICK)

	assert_gt(reasons.size(), 0)
	var first_produce_i: int = reasons.find(String(GoodsLedger.REASON_PRODUCE))
	var first_consume_i: int = reasons.find(String(GoodsLedger.REASON_CONSUME))
	assert_gte(first_produce_i, 0)
	assert_gte(first_consume_i, 0)
	assert_lt(first_produce_i, first_consume_i, "PRODUCE before CONSUME (2.3)")

	assert_gt(cons.consume_calls.size(), 1)
	for i in range(cons.consume_calls.size() - 1):
		var a: Dictionary = cons.consume_calls[i]
		var b: Dictionary = cons.consume_calls[i + 1]
		var ok: bool = String(a["port"]) < String(b["port"]) or (
			String(a["port"]) == String(b["port"]) and String(a["good"]) <= String(b["good"])
		)
		assert_true(ok, "consume order must be ascending (port, good)")


func test_step6_emits_day_ticked_after_writes_D05() -> void:
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


func test_tick_paused_push_error_no_progress() -> void:
	# GP-01 via SimLoop: paused → push_error, day unchanged
	_boot_ready_provider()
	Clock.set_paused(true)
	var day_before: int = Clock.day
	SimLoop.tick_day()
	assert_push_error_count(1)
	assert_eq(Clock.day, day_before)
	Clock.set_paused(false)


func test_season_cutoff_close_season_index_zero_D05() -> void:
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


func test_consume_shortage_err_sys03_02_into_day_errors_D05() -> void:
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


func test_conservation_runs_on_tick_when_debug_prm() -> void:
	# 2.3-04: debug fixture CONSERVATION_CHECK_EVERY_TICK=true → check does not violate after clean tick
	_boot_ready_provider()
	SimLoop.tick_day()
	assert_eq(GoodsLedger.check_conservation(), GoodsLedger.CODE_OK)


func test_no_public_subday_methods_D07() -> void:
	# D-07: SimLoop／Clock 不得公開子日推進方法
	assert_false(SimLoop.has_method("advance_one_tick"))
	assert_false(SimLoop.has_method("tick_subday"))
	assert_false(Clock.has_method("advance_one_tick"))
	assert_false(Clock.has_method("advance_ticks"))


func test_D08j_public_api_names_match_ruling() -> void:
	# D-08j／TST: five public APIs; #11 names already matched — no rename beyond ruling.
	assert_true(SimLoop.has_method("boot"))
	assert_true(SimLoop.has_method("tick_day"))
	assert_true(SimLoop.has_method("is_booted"))
	assert_true(SimLoop.has_method("set_consumption_provider"))
	assert_true(SimLoop.has_method("register_capacity_provider"))


func test_D08j_set_consumption_provider_ignored_after_boot() -> void:
	# D-08j／TST: set_consumption_provider after boot → push_error, no effect
	var first := _boot_ready_provider()
	var second := TestConsumptionProvider.new()
	SimLoop.set_consumption_provider(second)
	assert_push_error_count(1)
	assert_eq(SimLoop._consumption, first)


func test_D08e_register_capacity_provider_before_boot_applies() -> void:
	# D-08e／TST: register before boot; applied after GoodsLedger.load_and_validate
	var fixtures := _prepare_fixtures()
	var cons := _full_zero_provider()
	SimLoop.set_consumption_provider(cons)
	var cap := _TestCapProvider.new()
	cap.set_cap(GoodsLedger.KIND_WAREHOUSE, 10)
	SimLoop.register_capacity_provider(GoodsLedger.KIND_WAREHOUSE, cap)
	var errors: Array = SimLoop.boot(
		PARAMS_FIXTURE, fixtures["goods"], fixtures["ports"], CURVE_FIXTURE
	)
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


func test_D08e_register_capacity_provider_ignored_after_boot() -> void:
	# D-08e／D-08j／TST: register after boot → push_error, no effect
	_boot_ready_provider()
	var before_keys: Array = SimLoop._capacity_by_kind.keys()
	var cap := _TestCapProvider.new()
	cap.set_cap(GoodsLedger.KIND_HOLD, 99)
	SimLoop.register_capacity_provider(GoodsLedger.KIND_HOLD, cap)
	assert_push_error_count(1)
	assert_eq(SimLoop._capacity_by_kind.keys(), before_keys)
	assert_false(SimLoop._capacity_by_kind.has(GoodsLedger.KIND_HOLD))


func test_D08e_duplicate_kind_err_sys03_06_blocks_boot() -> void:
	# D-08e／TST: duplicate kind → ERR-SYS03-06；boot collects and refuses
	var fixtures := _prepare_fixtures()
	var cons := _full_zero_provider()
	SimLoop.set_consumption_provider(cons)
	var a := _TestCapProvider.new()
	a.set_cap(GoodsLedger.KIND_WAREHOUSE, 5)
	var b := _TestCapProvider.new()
	b.set_cap(GoodsLedger.KIND_WAREHOUSE, 50)
	SimLoop.register_capacity_provider(GoodsLedger.KIND_WAREHOUSE, a)
	SimLoop.register_capacity_provider(GoodsLedger.KIND_WAREHOUSE, b)
	assert_push_error_count(1)
	assert_eq(SimLoop._capacity_by_kind[GoodsLedger.KIND_WAREHOUSE], a)
	var errors: Array = SimLoop.boot(
		PARAMS_FIXTURE, fixtures["goods"], fixtures["ports"], CURVE_FIXTURE
	)
	assert_gt(errors.size(), 0)
	assert_true(_has_err_code(errors, GoodsLedger.ERR_SYS03_06))
	assert_false(SimLoop.is_booted())


# --- helpers ---


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


func _boot_ready_provider() -> TestConsumptionProvider:
	var fixtures := _prepare_fixtures()
	var cons := _full_zero_provider()
	SimLoop.set_consumption_provider(cons)
	var errors: Array = SimLoop.boot(
		PARAMS_FIXTURE, fixtures["goods"], fixtures["ports"], CURVE_FIXTURE
	)
	assert_eq(errors.size(), 0, "boot must succeed: %s" % str(errors))
	assert_true(SimLoop.is_booted())
	Clock.set_paused(false)
	return cons


func _full_zero_provider() -> TestConsumptionProvider:
	var cons := TestConsumptionProvider.new()
	return cons


func _prepare_fixtures() -> Dictionary:
	var perr: Array = Params.load_and_validate(PARAMS_FIXTURE)
	assert_eq(perr.size(), 0, "params fixture")
	var goods_dir := _build_valid_goods(GOODS_FIXTURE_ROOT + "base/", ANCHOR_LI)
	var gerr: Array = GoodCatalog.load_and_validate(goods_dir)
	assert_eq(gerr.size(), 0)
	var port_count: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var ports_dir := _build_valid_ports(port_count, PORTS_FIXTURE_ROOT + "base/")
	return {"goods": goods_dir, "ports": ports_dir}


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
