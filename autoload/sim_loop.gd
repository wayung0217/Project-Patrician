extends Node
## Autoload: SimLoop — daily tick & season cutoff scheduler (TechSpec 2.2／2.3 / WP-08).
## _ready() only clears fields; boot() loads modules in 2.2-01 order (2.2-01).
## ConsumptionProvider is injected (2.3-03); WP-22 DemandModel is formal SYS-06 Autoload (D-09a).
## D-05: Clock mutates only; day_ticked／season_cutoff emitted here at step 6.
## D-03: boot() calls CashLedger.genesis_grant() once after validation.
## D-14d／WP-28: step 1 advances tick-by-tick; empty tick-step list until WP-30.
## D-08e／D-08j: register_capacity_provider／set_consumption_provider only before boot().
## WP-18: boot loads BuildingEconomy and registers WAREHOUSE CapacityProvider when not pre-registered.
## WP-29 / D-14c: SeaLanes loads after PortRegistry (before GoodsLedger).
## WP-22: DemandModel loads after opening init; auto-wires sat／consume providers when unset.

const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_TICKS_PER_DAY := "PRM-SYS00-TICKS_PER_DAY"

const FIELD_PROVIDER := "ConsumptionProvider"
const FIELD_CAPACITY_PROVIDER := "CapacityProvider"
const REQUESTER_SYS06 := &"SYS-06"

## Error code when boot() runs without set_consumption_provider (2.3-03).
const ERR_PROVIDER_MISSING := "ERR-SIMLOOP-PROVIDER_MISSING"

## D-08j public surface (names locked): boot／tick_day／is_booted／
## set_consumption_provider／register_capacity_provider.


var _consumption: ConsumptionProvider = null
var _booted: bool = false
## D-08e: kind:String → CapacityProvider; only WAREHOUSE／HOLD are consulted (MARKET／CONFISCATED unbounded).
var _capacity_by_kind: Dictionary = {}
## D-08e: duplicate-register ErrorInfo collected for boot() (C-06).
var _capacity_reg_errors: Array = []


func _ready() -> void:
	# 2.2-01: field init only; do not read data or call other modules.
	_consumption = null
	_booted = false
	_capacity_by_kind = {}
	_capacity_reg_errors = []


func set_consumption_provider(provider: ConsumptionProvider) -> void:
	## D-08j: inject before boot only; after boot → push_error, no effect.
	## WP-32: MarketPricer no longer uses ConsumptionProvider (offtake snapshot).
	if _booted:
		push_error("SimLoop.set_consumption_provider called after boot (D-08j); ignored")
		return
	_consumption = provider


func register_capacity_provider(kind: Variant, provider: CapacityProvider) -> void:
	## D-08e／D-08j: per-kind CapacityProvider; only before boot().
	## Duplicate kind → ERR-SYS03-06 (DUPLICATE_PROVIDER); first registration kept.
	if _booted:
		push_error("SimLoop.register_capacity_provider called after boot (D-08e／D-08j); ignored")
		return
	var kind_s: String = String(kind)
	if _capacity_by_kind.has(kind_s):
		var dup: Dictionary = ErrorInfoUtil.make_validation(
			GoodsLedger.ERR_SYS03_06,
			GoodsLedger.SYS_ID,
			"res://autoload/sim_loop.gd",
			FIELD_CAPACITY_PROVIDER,
			kind_s,
			"duplicate CapacityProvider for kind (D-08e DUPLICATE_PROVIDER)"
		)
		_capacity_reg_errors.append(dup)
		push_error("SimLoop: %s" % str(dup))
		return
	_capacity_by_kind[kind_s] = provider


func is_booted() -> bool:
	return _booted


func boot(
	params_path: String = Params.PARAMS_PATH,
	goods_dir: String = GoodCatalog.GOODS_DIR,
	ports_dir: String = PortRegistry.PORTS_DIR,
	curve_path: String = MarketPricer.CURVE_PATH,
	sea_nodes_dir: String = SeaLanes.NODES_DIR,
	sea_regions_dir: String = SeaLanes.REGIONS_DIR,
	sea_lanes_dir: String = SeaLanes.LANES_DIR,
	demand_tables_path: String = DemandModel.TABLES_PATH
) -> Array:
	# 2.2-02: call load_and_validate in D-14c order; collect every error; do not stop early.
	# 任一錯誤 → 回傳完整清單且不啟動時鐘（_booted 維持 false）。
	_booted = false
	var errors: Array = []

	# D-08e: surface duplicate-register errors collected before boot (C-06).
	errors.append_array(_capacity_reg_errors)

	errors.append_array(Params.load_and_validate(params_path))
	errors.append_array(Clock.load_and_validate())
	errors.append_array(GoodCatalog.load_and_validate(goods_dir))
	errors.append_array(PortRegistry.load_and_validate(ports_dir))
	errors.append_array(SeaLanes.load_and_validate(sea_nodes_dir, sea_regions_dir, sea_lanes_dir))
	errors.append_array(GoodsLedger.load_and_validate())
	errors.append_array(MarketPricer.load_and_validate(curve_path))
	errors.append_array(CashLedger.load_and_validate())
	# D-17d／D-17c: PopulationModel after CashLedger／before BuildingEconomy.
	# WP-34／D-30a: always wire DemandModel sat when unset (no file_exists gate).
	if not PopulationModel.has_satisfaction_input_provider():
		PopulationModel.set_satisfaction_input_provider(DemandModel.get_satisfaction_input_provider())
	errors.append_array(PopulationModel.load_and_validate())
	if PopulationModel.is_loaded():
		if not BuildingEconomy.has_population_provider():
			BuildingEconomy.set_population_provider(PopulationModel.get_population_provider())
		if not BuildingEconomy.has_workforce_provider():
			BuildingEconomy.set_workforce_provider(PopulationModel.get_workforce_provider())
	errors.append_array(BuildingEconomy.load_and_validate())
	# WP-24／FRM-SYS07-14／FRM-SYS08-21: opening from CSV tres (no-op if dirs empty).
	if PopulationModel.is_loaded() and errors.is_empty():
		errors.append_array(PopulationModel.apply_opening_init())
	if BuildingEconomy.is_loaded() and errors.is_empty():
		errors.append_array(BuildingEconomy.apply_opening_init())

	# D-09a／WP-22／D-30a: DemandModel after opening init when no ConsumptionProvider pre-injected.
	# Missing demand dir → ERR-SYS06-01 collected; refuse boot (C-06／D-25b). Injected
	# fixture ConsumptionProvider still skips DemandModel load.
	if _consumption == null:
		errors.append_array(DemandModel.load_and_validate(demand_tables_path))
		if DemandModel.is_loaded():
			_consumption = DemandModel.get_consumption_provider()

	# D-14b／D-19f: ShipRegistry after PopulationModel／BuildingEconomy opening; inject SailorPool.
	if not ShipRegistry.has_sailor_pool_provider() and PopulationModel.is_loaded():
		ShipRegistry.set_sailor_pool_provider(PopulationModel.get_sailor_pool_provider())
	errors.append_array(ShipRegistry.load_and_validate())
	# FRM-SYS13-06／D-19f (d): opening SH-01 after WP-24 opening init.
	if ShipRegistry.is_loaded() and errors.is_empty():
		errors.append_array(ShipRegistry.apply_opening_init())

	# D-34d／25.1: IntelLedger after ShipRegistry; inject ShipEventObserver; ERR-SYS15-06.
	errors.append_array(IntelLedger.load_and_validate())
	if IntelLedger.is_loaded() and ShipRegistry.is_loaded():
		ShipRegistry.set_ship_observer(IntelLedger.get_ship_event_observer())
	errors.append_array(IntelLedger.boot_gate_errors())

	# 2.3-03: 未注入 provider（且 DemandModel 未載入）→ boot() 回錯誤。
	if _consumption == null:
		var missing := {
			"code": ERR_PROVIDER_MISSING,
			"file": "res://autoload/sim_loop.gd",
			"field": FIELD_PROVIDER,
			"value": null,
			"message": "ConsumptionProvider must be injected before boot (2.3-03)",
		}
		errors.append(missing)
		# Modules already push_error inside load_and_validate；此處只發 SimLoop 自有錯誤，避免重複。
		push_error("SimLoop: %s" % str(missing))

	if not errors.is_empty():
		_booted = false
		return errors

	# D-08e / WP-18: default WAREHOUSE provider from BuildingEconomy unless tests pre-register.
	if not _capacity_by_kind.has(GoodsLedger.KIND_WAREHOUSE):
		_capacity_by_kind[GoodsLedger.KIND_WAREHOUSE] = (
			BuildingEconomy.get_warehouse_capacity_provider()
		)
	# D-14c／D-10c: HOLD CapacityProvider from ShipRegistry unless tests pre-register.
	if not _capacity_by_kind.has(GoodsLedger.KIND_HOLD) and ShipRegistry.is_loaded():
		_capacity_by_kind[GoodsLedger.KIND_HOLD] = ShipRegistry.get_hold_capacity_provider()

	# D-08e: GoodsLedger.load_and_validate clears providers; apply SimLoop registrations after.
	_apply_capacity_providers()

	# Sync quote provider for CashLedger when available (WP-07 set_quote_provider bridge).
	if CashLedger.has_method("set_quote_provider"):
		CashLedger.set_quote_provider(MarketPricer)

	# D-03: after CashLedger validation passes, grant START_CASH once via genesis_grant().
	# R2-05: genesis_grant()/post() -> Error OK／FAILED（not CODE_OK int）.
	var grant_rc: Error = CashLedger.genesis_grant()
	if grant_rc != OK:
		var grant_err: Dictionary = CashLedger.last_error()
		if grant_err.is_empty():
			grant_err = {
				"code": "GENESIS_GRANT_FAILED",
				"file": "res://autoload/sim_loop.gd",
				"field": "genesis_grant",
				"value": grant_rc,
				"message": "CashLedger.genesis_grant failed after validation (D-03)",
			}
		errors.append(grant_err)
		push_error("SimLoop: genesis_grant failed: %s" % str(grant_err))
		_booted = false
		return errors

	# D-05(b)／D-07: boot day=0 (Clock._tick=0); ledgers track the same calendar day.
	GoodsLedger.set_day(Clock.day)
	CashLedger.set_day(Clock.day)

	_booted = true
	return errors


func tick_day() -> Array:
	## 每日 tick：步驟順序與 TechSpec 第 2.3 節逐字一致。
	## D-04／C-06: 回傳當日錯誤清單（CONSUME 不足等 ErrorInfo）。
	## D-08j: public name tick_day()（當日錯誤清單）.
	var day_errors: Array = []
	if not _booted:
		push_error("SimLoop.tick_day called before successful boot (2.2-02)")
		return day_errors
	if Clock.is_paused:
		push_error("SimLoop.tick_day called while Clock.is_paused=true (GP-01)")
		return day_errors

	# 2.3-01 步驟 1: 逐 tick 推進一日份（D-14d／13-02）；信號於步驟 6。
	# D-05(b)／D-07: boot day=0 → first day advance → day=1，執行 k=0 PRODUCE。
	# 每個 tick 後執行「tick 步驟清單」（本 WP 為空；WP-30 加 ShipRegistry.tick_step）。
	var tpd: int = Params.get_int(PRM_TICKS_PER_DAY)
	for _i in range(tpd):
		Clock.advance_one_tick()
		_run_tick_steps(Clock.tick)
	GoodsLedger.set_day(Clock.day)
	CashLedger.set_day(Clock.day)

	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	# 2.3-01: day_in_season = ((day−1) mod D) + 1（公式在 SimLoop；Clock 公開面無此 getter）
	var day_in_season: int = ((Clock.day - 1) % days_d) + 1

	# D-12h／D-12d／8.6 F: BuildingEconomy.daily_step = ① build + ② workshop PRODUCE + ④ wages.
	# Role-cell PRODUCE path removed (WP-20); GoodsLedger.run_daily_produce kept for SYS-03 tests only.
	day_errors.append_array(BuildingEconomy.daily_step(Clock.day))

	# 14-03: PopulationModel after workshop produce (WP-21).
	if PopulationModel.is_loaded():
		day_errors.append_array(PopulationModel.daily_step(Clock.day))

	# D-19f (b)／13-07: ShipRegistry crew wage accrual after BE + PopulationModel.
	if ShipRegistry.is_loaded():
		day_errors.append_array(ShipRegistry.daily_step(Clock.day))

	# 25.1 F／D-34d: IntelLedger.daily_step after ShipRegistry, before TraderRegistry (not yet).
	if IntelLedger.is_loaded():
		day_errors.append_array(IntelLedger.daily_step(Clock.day))

	# 2.3-03 步驟 3: 注入的 ConsumptionProvider 執行 CONSUME，依 (port_id, good_id) 升序
	day_errors.append_array(_run_daily_consume(Clock.day))

	# 2.3-04 步驟 4: 守恆檢查（是否每日執行依 PRM-SYS03-CONSERVATION_CHECK_EVERY_TICK）
	GoodsLedger.maybe_check_conservation_on_tick()

	# 2.3-05 步驟 5（僅 day_in_season = D 當日）: 商季 cutoff
	var at_cutoff: bool = day_in_season == days_d
	if at_cutoff:
		# (a) PortRegistry 套用排隊中的角色變更
		PortRegistry.apply_queued_role_changes()
		# 14-05: BuildingEconomy season six-step before close_season.
		if BuildingEconomy.is_loaded():
			day_errors.append_array(BuildingEconomy.season_step())
		# D-19f (c)／13-07: ShipRegistry (1) wage (2) repair before close_season.
		if ShipRegistry.is_loaded():
			day_errors.append_array(ShipRegistry.cutoff_step(Clock.season_index))
		# (b) CashLedger.close_season()
		CashLedger.close_season()
		# (c) 守恆檢查（release 亦必檢）
		GoodsLedger.check_conservation()

	# 15-07／15.1 F: after conservation, before signals — roll offtake snapshot (C-04 explicit call).
	GoodsLedger.roll_offtake_snapshot(Clock.day)

	# 2.3-06 步驟 6: 全部寫入完成後才發出信號（D-05(a)）
	# D-12h／14-03 ⑧: flush BuildingEconomy + PopulationModel signals before clock signals.
	# WP-22／D-05: DemandModel.flush_signals once after all same-day writes.
	BuildingEconomy.flush_signals()
	if DemandModel.is_loaded():
		DemandModel.flush_signals()
	if PopulationModel.is_loaded():
		PopulationModel.flush_signals()
	if ShipRegistry.is_loaded():
		ShipRegistry.flush_signals()
	if IntelLedger.is_loaded():
		IntelLedger.flush_signals()
	Clock.day_ticked.emit(Clock.day)
	if at_cutoff:
		# D-05(c): season_index = floori((day−1)/D)；首季 0
		Clock.season_cutoff.emit(Clock.season_index)

	return day_errors


func _run_tick_steps(current_tick: int) -> void:
	# 13-02／C-04: explicit tick-step list in SimLoop (no signal / call_deferred).
	# WP-30: ShipRegistry.tick_step(tick).
	if ShipRegistry.is_loaded():
		ShipRegistry.tick_step(current_tick)
	# 15-02／FRM-SYS03-10: debug pending invariant each tick.
	if OS.is_debug_build() and GoodsLedger.is_loaded():
		GoodsLedger.debug_check_offtake_invariants()



func _apply_capacity_providers() -> void:
	# D-08e／R3-02 relocate: after GoodsLedger.load_and_validate clears providers,
	# register each kind via GoodsLedger.register_capacity_provider (WP-05 API; set_capacity_provider removed).
	# Phase 0 with no registrations leaves GoodsLedger unset → ERR-SYS03-03.
	if _capacity_by_kind.is_empty():
		return
	var kinds: Array = _capacity_by_kind.keys()
	kinds.sort()
	for kind_variant in kinds:
		var kind_s: String = String(kind_variant)
		var provider: CapacityProvider = _capacity_by_kind[kind_s]
		var rc: int = GoodsLedger.register_capacity_provider(StringName(kind_s), provider)
		if rc != GoodsLedger.CODE_OK:
			push_error("SimLoop: GoodsLedger.register_capacity_provider failed for kind=%s" % kind_s)


func _run_daily_consume(day: int) -> Array:
	# 2.3-03: 依 (port_id, good_id) 升序；排序寫在 SimLoop 代碼內。
	# D-05(d): 不足 = transfer ERR-SYS03-02、全有或全無、進當日錯誤清單；不得 clamp。
	assert(_consumption != null, "SimLoop consume without provider")
	var day_errors: Array = []
	var jobs: Array = []
	for port_variant in PortRegistry.all_ids():
		var port_id: String = String(port_variant)
		for good_variant in GoodCatalog.all_ids():
			var good_id: String = String(good_variant)
			jobs.append({"port": port_id, "good": good_id})
	jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a["port"]) == String(b["port"]):
			return String(a["good"]) < String(b["good"])
		return String(a["port"]) < String(b["port"])
	)
	for job_variant in jobs:
		var job: Dictionary = job_variant
		var port_sn: StringName = StringName(String(job["port"]))
		var good_sn: StringName = StringName(String(job["good"]))
		var qty: int = _consumption.consume_qty(port_sn, good_sn, day)
		# qty ≤ 0: skip (0 = no demand; CONSUMPTION_FAILURE = −1 base／fixture miss)
		if qty <= 0:
			continue
		var from_c: Dictionary = GoodsLedger.make_market(String(job["port"]))
		var to_c: Dictionary = GoodsLedger.make_external()
		var result: int = GoodsLedger.transfer(
			from_c, to_c, good_sn, qty, GoodsLedger.REASON_CONSUME, REQUESTER_SYS06
		)
		# D-04: transfer fail → 0 + ErrorInfo in last_error()
		if result <= 0:
			var info: Dictionary = GoodsLedger.last_error()
			if not info.is_empty():
				day_errors.append(info)
			else:
				day_errors.append({
					"code": GoodsLedger.ERR_SYS03_02,
					"sys": GoodsLedger.SYS_ID,
					"detail": {
						"port": String(job["port"]),
						"good": String(job["good"]),
						"qty": qty,
						"message": "CONSUME transfer failed",
					},
				})
			push_error(
				"SimLoop CONSUME transfer failed port=%s good=%s qty=%s info=%s"
				% [String(job["port"]), String(job["good"]), qty, str(info)]
			)
	return day_errors
