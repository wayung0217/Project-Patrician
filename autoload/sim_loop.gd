extends Node
## Autoload: SimLoop — daily tick & season cutoff scheduler (TechSpec 2.2／2.3 / WP-08).
## _ready() only clears fields; boot() loads modules in 2.2-01 order (2.2-01).
## ConsumptionProvider is injected (2.3-03); formal SYS-06 is out of Phase 0 (1-A9).
## D-05: Clock mutates only; day_ticked／season_cutoff emitted here at step 6.
## D-03: boot() calls CashLedger.genesis_grant() once after validation.
## D-07: no public sub-day methods; day advance only via Clock.advance_one_day().

const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"

const FIELD_PROVIDER := "ConsumptionProvider"
const REQUESTER_SYS06 := &"SYS-06"

## Error code when boot() runs without set_consumption_provider (2.3-03).
const ERR_PROVIDER_MISSING := "ERR-SIMLOOP-PROVIDER_MISSING"

var _consumption: ConsumptionProvider = null
var _booted: bool = false


func _ready() -> void:
	# 2.2-01: field init only; do not read data or call other modules.
	_consumption = null
	_booted = false


func set_consumption_provider(provider: ConsumptionProvider) -> void:
	## 2.3-03: inject before boot. Also wires MarketPricer (SYS-04 weekly_consumption).
	## 缺口：TechSpec H 未列本登錄 API 名稱；比照 GoodsLedger.set_capacity_provider。
	_consumption = provider
	MarketPricer.set_consumption_provider(provider)


func is_booted() -> bool:
	return _booted


func boot(
	params_path: String = Params.PARAMS_PATH,
	goods_dir: String = GoodCatalog.GOODS_DIR,
	ports_dir: String = PortRegistry.PORTS_DIR,
	curve_path: String = MarketPricer.CURVE_PATH
) -> Array:
	# 2.2-02: call load_and_validate in 2.2-01 order; collect every error; do not stop early.
	# 任一錯誤 → 回傳完整清單且不啟動時鐘（_booted 維持 false）。
	_booted = false
	var errors: Array = []

	errors.append_array(Params.load_and_validate(params_path))
	errors.append_array(Clock.load_and_validate())
	errors.append_array(GoodCatalog.load_and_validate(goods_dir))
	errors.append_array(PortRegistry.load_and_validate(ports_dir))
	errors.append_array(GoodsLedger.load_and_validate())
	errors.append_array(MarketPricer.load_and_validate(curve_path))
	errors.append_array(CashLedger.load_and_validate())

	# 2.3-03: 未注入 provider → boot() 回錯誤（Phase 0 正式環境因此不會啟動時鐘，屬預期）。
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
	## 缺口：TechSpec H 未列 SimLoop 每日入口函式名；採 tick_day()。
	var day_errors: Array = []
	if not _booted:
		push_error("SimLoop.tick_day called before successful boot (2.2-02)")
		return day_errors
	if Clock.is_paused:
		push_error("SimLoop.tick_day called while Clock.is_paused=true (GP-01)")
		return day_errors

	# 2.3-01 步驟 1: Clock 推進一日（D-05(a): mutate only；信號於步驟 6）
	# D-05(b)／D-07: boot day=0 → first advance → day=1，執行 k=0 PRODUCE。
	Clock.advance_one_day()
	GoodsLedger.set_day(Clock.day)
	CashLedger.set_day(Clock.day)

	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	# 2.3-01: day_in_season = ((day−1) mod D) + 1（公式在 SimLoop；Clock 公開面無此 getter）
	var day_in_season: int = ((Clock.day - 1) % days_d) + 1

	# 2.3-02 步驟 2: GoodsLedger 當日 PRODUCE；k = day_in_season − 1（FRM-SYS03-03）
	# D-05(b): 首日 day=1 → k=0，不得跳過。
	var day_index_k: int = day_in_season - 1
	GoodsLedger.run_daily_produce(day_index_k)

	# 2.3-03 步驟 3: 注入的 ConsumptionProvider 執行 CONSUME，依 (port_id, good_id) 升序
	day_errors.append_array(_run_daily_consume(Clock.day))

	# 2.3-04 步驟 4: 守恆檢查（是否每日執行依 PRM-SYS03-CONSERVATION_CHECK_EVERY_TICK）
	GoodsLedger.maybe_check_conservation_on_tick()

	# 2.3-05 步驟 5（僅 day_in_season = D 當日）: 商季 cutoff
	var at_cutoff: bool = day_in_season == days_d
	if at_cutoff:
		# (a) PortRegistry 套用排隊中的角色變更
		PortRegistry.apply_queued_role_changes()
		# (b) CashLedger.close_season()
		CashLedger.close_season()
		# (c) 守恆檢查（release 亦必檢）
		GoodsLedger.check_conservation()

	# 2.3-06 步驟 6: 全部寫入完成後才發出信號（D-05(a)）
	Clock.day_ticked.emit(Clock.day)
	if at_cutoff:
		# D-05(c): season_index = floori((day−1)/D)；首季 0
		Clock.season_cutoff.emit(Clock.season_index)

	return day_errors


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
