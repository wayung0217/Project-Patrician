extends Node
## Autoload: GoodsLedger — SYS-03 ST-GOOD (TechSpec 3.4 / WP-05) + ST-OFFTAKE (WP-32 / 15.1).
## _ready() only clears fields; load_and_validate() inits seq／stock (2.2-01).
## WAREHOUSE／HOLD capacity only via CapacityProvider (1-A6); no SYS-08／SYS-13 providers here.
## D-04: transfer success→seq≥1, fail→0; ErrorInfo via last_error()／validate Arrays. No ERR→int.
## D-08d: container addresses only via container_id(kind,…); kind from Dictionary kind field.
## D-08e: per-kind CapacityProvider; duplicate → ERR-SYS03-06; unregistered → ERR-SYS03-03.
## D-08f: goods_transferred(event); conservation_violated(good_id, expected, actual).
## D-20c／15.1: container registry stores owner_id／port_id; ST-OFFTAKE daily／pending／snapshot.

signal goods_transferred(event: TransferEvent)
signal conservation_violated(good_id: StringName, expected: int, actual: int)

const SYS_ID := &"SYS-03"
const SCRIPT_PATH := "res://autoload/goods_ledger.gd"

const PRM_DAYS_PER_SEASON := "PRM-SYS00-DAYS_PER_SEASON"
const PRM_CONSERVATION_CHECK_EVERY_TICK := "PRM-SYS03-CONSERVATION_CHECK_EVERY_TICK"
const PRM_OFFTAKE_WINDOW_DAYS := "PRM-SYS03-OFFTAKE_WINDOW_DAYS"

## ->int success／fail literals only 0／1 (D-04); transfer success returns seq≥1 separately.
const CODE_OK := 0
const CODE_FAIL := 1

const ERR_SYS03_01 := &"ERR-SYS03-01"
const ERR_SYS03_02 := &"ERR-SYS03-02"
const ERR_SYS03_03 := &"ERR-SYS03-03"
const ERR_SYS03_04 := &"ERR-SYS03-04"
const ERR_SYS03_05 := &"ERR-SYS03-05"
## D-08e: duplicate CapacityProvider registration for the same container kind.
const ERR_SYS03_06 := &"ERR-SYS03-06"
## 15.1 附錄 C: offtake_snapshot unknown port／good.
const ERR_SYS03_07 := &"ERR-SYS03-07"
## 15.1 附錄 C: container_departed invalid target.
const ERR_SYS03_08 := &"ERR-SYS03-08"
## 15.1 附錄 C: WAREHOUSE／HOLD registration missing owner_id (or WAREHOUSE port_id).
const ERR_SYS03_09 := &"ERR-SYS03-09"

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_PORT_REGISTRY_NOT_LOADED := &"PORT_REGISTRY_NOT_LOADED"

const FIELD_OWNER_ID := "owner_id"
const FIELD_PORT_ID := "port_id"
const FIELD_WINDOW_QTY := "window_qty"
const FIELD_LOCAL_QTY := "local_qty"
const FIELD_WINDOW_DAYS := "window_days"
const FIELD_DAY := "day"
const FIELD_LOCAL := "local"
const FIELD_EXPORT := "export"
const FIELD_SELLIN := "sellin"

const REASON_GENESIS := &"GENESIS"
const REASON_PRODUCE := &"PRODUCE"
const REASON_CONSUME := &"CONSUME"
const REASON_TRADE := &"TRADE"
const REASON_LOAD := &"LOAD"
const REASON_UNLOAD := &"UNLOAD"
const REASON_CONSTRUCT_USE := &"CONSTRUCT_USE"
const REASON_CONFISCATE := &"CONFISCATE"
const REASON_SEA_LOSS := &"SEA_LOSS"

## Container Dictionary schema (TechSpec MARKET(port)／WAREHOUSE(owner,port)／HOLD(ship)／CONFISCATED／外部).
## Exact key names not in D 欄 — see PR 缺口 (C-05).
const KEY_KIND := "kind"
const KEY_PORT := "port"
const KEY_OWNER := "owner"
const KEY_SHIP := "ship"

const KIND_MARKET := "MARKET"
const KIND_WAREHOUSE := "WAREHOUSE"
const KIND_HOLD := "HOLD"
const KIND_CONFISCATED := "CONFISCATED"
const KIND_EXTERNAL := "EXTERNAL"

## D-08d: named format patterns only (no hand-typed address literals at call sites).
const CONTAINER_ID_FMT_MARKET := "MARKET:%s"
const CONTAINER_ID_FMT_WAREHOUSE := "WAREHOUSE:%s:%s"
const CONTAINER_ID_FMT_HOLD := "HOLD:%s"
const CONTAINER_ID_CONFISCATED := "CONFISCATED"
## EXTERNAL is not a D-08d address; internal sentinel for genesis／produce／consume only.
const EXTERNAL_KEY := "EXTERNAL"

const FIELD_PARAMS := "Params"
const FIELD_QTY := "qty"
const FIELD_REASON := "reason"
const FIELD_PORT_REGISTRY := "PortRegistry"
const FIELD_KIND := "kind"
const REQUESTER_SYS03 := &"SYS-03"

## Day when Clock Autoload absent (WP-02 not on WP-04 stack) — see PR 缺口.
## D-05(b): Clock boot day = 0; keep injectable default aligned until Clock is on stack.
const DAY_PLACEHOLDER := 0

var _stock: Dictionary = {} ## container_id:String -> Dictionary[good_id:String -> int qty]
var _expected_net: Dictionary = {} ## good_id:String -> int (Σ GENESIS+PRODUCE − CONSUME − CONSTRUCT_USE − SEA_LOSS)
var _kind_by_id: Dictionary = {} ## container_id:String -> kind:String (D-08d: never parse id string)
## D-20c／15.1 D: container_id -> {owner_id:String, port_id:String}
var _container_meta: Dictionary = {}
var _next_seq: int = 1
var _loaded: bool = false
## D-08e: one CapacityProvider per kind (WAREHOUSE／HOLD); MARKET／CONFISCATED never registered.
var _capacity_providers: Dictionary = {} ## kind:String -> CapacityProvider
## 缺口：TransferEvent.day 應讀 Clock.day；本堆疊無 Clock。暫存 _day，預設 DAY_PLACEHOLDER；測試可 set_day。
var _day: int = DAY_PLACEHOLDER
## D-04: last single-call ErrorInfo {code,sys,detail}; empty Dictionary when none.
var _last_error: Dictionary = {}
## ST-OFFTAKE (15.1 D): daily[port][good][day] = {local, export{owner}, sellin{owner}}
var _offtake_daily: Dictionary = {}
## pending[container][good] = int
var _offtake_pending: Dictionary = {}
## snapshot[port][good] = {window_qty, local_qty, window_days, day}
var _offtake_snapshot: Dictionary = {}
## First roll_offtake_snapshot day (window_days epoch); -1 = none yet.
var _offtake_epoch_day: int = 0 - 1


func _ready() -> void:
	_clear_state()


func load_and_validate() -> Array:
	# 2.2-01／2.2-02: field init + Params gate; no PortRegistry produce at boot.
	var errors: Array = []
	_clear_state()
	if not Params.is_loaded():
		errors.append(_err(CODE_PARAMS_NOT_LOADED, FIELD_PARAMS, null, "Params must load_and_validate before GoodsLedger"))
		_emit_errors(errors)
		return errors
	_next_seq = 1
	_day = DAY_PLACEHOLDER
	_loaded = true
	return errors


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	# D-04: single-call failures (transfer／check_conservation) expose ErrorInfo here.
	return _last_error.duplicate(true)


func register_capacity_provider(kind: StringName, provider: CapacityProvider) -> int:
	# D-08e: one provider per kind (WAREHOUSE→SYS-08、HOLD→SYS-13).
	# Duplicate kind → ERR-SYS03-06 in last_error(); return CODE_FAIL (1).
	# SimLoop.before-boot gate is WP-08 (D-08e／D-08j).
	_clear_last_error()
	var kind_s: String = String(kind)
	if _capacity_providers.has(kind_s):
		_record_error(ERR_SYS03_06, FIELD_KIND, kind, "duplicate capacity provider")
		return CODE_FAIL
	_capacity_providers[kind_s] = provider
	return CODE_OK


func set_day(day: int) -> void:
	## 缺口：應由 Clock.day 驅動；無 Clock 時測試／呼叫端可 set_day。不新增子日公開 API（D-07）。
	_day = day


func next_seq() -> int:
	# D101: 全域唯一發號，從 1 起，每次 +1
	assert(_loaded, "GoodsLedger.next_seq before load_and_validate")
	var seq: int = _next_seq
	_next_seq = _next_seq + 1
	return seq


func transfer(from: Variant, to: Variant, good: StringName, qty: Variant, reason: StringName, requester: StringName) -> int:
	# FRM-SYS03-02: qty 整數且 > 0；from 餘額 ≥ qty；to 容量足夠；全有或全無
	# D-04: success → seq≥1；fail → 0 + ErrorInfo in last_error()
	assert(_loaded, "GoodsLedger.transfer before load_and_validate")
	_clear_last_error()

	# ERR-SYS03-04 — SEA_LOSS 停用（OQ-08 7c）
	if reason == REASON_SEA_LOSS:
		return _fail(ERR_SYS03_04, FIELD_REASON, reason, "SEA_LOSS disabled")

	# ERR-SYS03-01 — qty ≤ 0 或非整數
	if not _is_positive_int(qty):
		return _fail(ERR_SYS03_01, FIELD_QTY, qty, "qty must be integer > 0")
	var qty_i: int = int(qty)

	var from_key: String = _container_key(from)
	if from_key.is_empty():
		# ERR-SYS03-09 may already be recorded during registration.
		if not _last_error.is_empty() and StringName(_last_error.get(ErrorInfoUtil.KEY_CODE, &"")) == ERR_SYS03_09:
			return 0
		return _fail(ERR_SYS03_01, KEY_KIND, from, "invalid container")
	var to_key: String = _container_key(to)
	var good_s: String = String(good)

	if to_key.is_empty():
		if not _last_error.is_empty() and StringName(_last_error.get(ErrorInfoUtil.KEY_CODE, &"")) == ERR_SYS03_09:
			return 0
		return _fail(ERR_SYS03_01, KEY_KIND, to, "invalid container")

	# Snapshot for all-or-nothing rollback
	var from_before: int = _get_qty_by_key(from_key, good_s)
	var to_before: int = _get_qty_by_key(to_key, good_s)

	# ERR-SYS03-02 — from 餘額不足（EXTERNAL 不檢查餘額）
	# D-05(d): CONSUME 同一般 transfer — 不足即 ERR-SYS03-02、全有或全無、收進錯誤清單
	if not _is_external_key(from_key):
		if from_before < qty_i:
			return _fail(ERR_SYS03_02, FIELD_QTY, qty_i, "insufficient balance")

	# FRM-SYS13-10／TST-SYS13-13: TRADE／LOAD／UNLOAD involving HOLD while SAILING → ERR-SYS13-03.
	if (
		reason == REASON_TRADE or reason == REASON_LOAD or reason == REASON_UNLOAD
	) and _hold_sailing_blocked(from, from_key, to, to_key):
		return 0

	# ERR-SYS03-03 — to 容量不足
	if not _has_capacity_for(to, to_key, qty_i):
		return _fail(ERR_SYS03_03, FIELD_QTY, qty_i, "insufficient capacity")

	# Apply (both sides); EXTERNAL 不記帳
	if not _is_external_key(from_key):
		_set_qty_by_key(from_key, good_s, from_before - qty_i)
	if not _is_external_key(to_key):
		_set_qty_by_key(to_key, good_s, to_before + qty_i)

	# Update expected net for FRM-SYS03-01 (creation／destruction reasons only)
	_apply_expected_delta(good_s, reason, from_key, to_key, qty_i)

	# FRM-SYS03-05: offtake pending／daily in same atomic op as successful transfer.
	_apply_offtake_on_transfer(from_key, to_key, good_s, qty_i, reason)

	var seq: int = next_seq()
	var event := TransferEvent.new()
	event.seq = seq
	event.day = _day
	event.timestamp = seq
	event.from = from
	event.to = to
	event.good_id = good
	event.qty = qty_i
	event.reason = reason
	event.requester = requester
	goods_transferred.emit(event)
	return seq


func get_qty(container: Variant, good: StringName) -> int:
	assert(_loaded, "GoodsLedger.get_qty before load_and_validate")
	var key: String = _container_key(container)
	if key.is_empty() or _is_external_key(key):
		return 0
	return _get_qty_by_key(key, String(good))


func total(good: StringName) -> int:
	# 3.4: 容器鍵 Dictionary 彙總先排序鍵再加總
	assert(_loaded, "GoodsLedger.total before load_and_validate")
	var good_s: String = String(good)
	var keys: Array = _stock.keys()
	keys.sort()
	var sum: int = 0
	for key_variant in keys:
		var key: String = String(key_variant)
		sum = sum + _get_qty_by_key(key, good_s)
	return sum


func in_transit(good: StringName) -> int:
	## 推導：航行中船艙＝在途（r282）。缺口：無 SYS-13 航行旗標；Phase 0 加總全部 HOLD。
	## D-08d: kind from _kind_by_id registry (set when container_id／Dictionary kind seen); never parse id.
	assert(_loaded, "GoodsLedger.in_transit before load_and_validate")
	var good_s: String = String(good)
	var keys: Array = _stock.keys()
	keys.sort()
	var sum: int = 0
	for key_variant in keys:
		var key: String = String(key_variant)
		if String(_kind_by_id.get(key, "")) == KIND_HOLD:
			sum = sum + _get_qty_by_key(key, good_s)
	return sum


func check_conservation() -> int:
	# FRM-SYS03-01: Σ 容器(good) = expected_net(good)；違反 → conservation_violated + ERR-SYS03-05
	# D-04: return 0 OK／1 fail；ErrorInfo in last_error()
	# D-08f: conservation_violated(good_id, expected, actual)
	assert(_loaded, "GoodsLedger.check_conservation before load_and_validate")
	_clear_last_error()
	var goods: Dictionary = {}
	for good_variant in _expected_net.keys():
		goods[String(good_variant)] = true
	var stock_keys: Array = _stock.keys()
	stock_keys.sort()
	for key_variant in stock_keys:
		var bucket: Dictionary = _stock[key_variant]
		var gkeys: Array = bucket.keys()
		gkeys.sort()
		for g_variant in gkeys:
			goods[String(g_variant)] = true
	var good_list: Array = goods.keys()
	good_list.sort()
	var violated := false
	var first_good: String = ""
	var first_actual: int = 0
	var first_expected: int = 0
	for g_variant in good_list:
		var good_s: String = String(g_variant)
		var actual: int = total(StringName(good_s))
		var expected: int = int(_expected_net.get(good_s, 0))
		if actual != expected:
			violated = true
			conservation_violated.emit(StringName(good_s), expected, actual)
			if first_good.is_empty():
				first_good = good_s
				first_actual = actual
				first_expected = expected
	if violated:
		_record_error(ERR_SYS03_05, "good_id", {
			"good": first_good,
			"actual": first_actual,
			"expected": first_expected,
		}, "conservation violated")
		return CODE_FAIL
	return CODE_OK


func maybe_check_conservation_on_tick() -> int:
	# 2.3-04: 是否每日執行依 PRM-SYS03-CONSERVATION_CHECK_EVERY_TICK；以 OS.is_debug_build() 選值
	assert(_loaded, "GoodsLedger.maybe_check_conservation_on_tick before load")
	# PRM-SYS03-CONSERVATION_CHECK_EVERY_TICK
	if Params.get_bool(PRM_CONSERVATION_CHECK_EVERY_TICK):
		return check_conservation()
	return CODE_OK


func daily_produce_qty(season_output_q: int, day_index_k: int) -> int:
	# FRM-SYS03-03: out(k) = FLOOR(Q·(k+1)/D) − FLOOR(Q·k/D)，k = 0..D−1
	assert(_loaded, "GoodsLedger.daily_produce_qty before load")
	# PRM-SYS00-DAYS_PER_SEASON
	var days_d: int = Params.get_int(PRM_DAYS_PER_SEASON)
	assert(days_d > 0, "DAYS_PER_SEASON must be > 0")
	assert(day_index_k >= 0 and day_index_k < days_d, "k out of 0..D-1")
	var q: int = season_output_q
	var k: int = day_index_k
	# floori on int operands (TechSpec 3.4 E)；不走 float 累加產量
	var term_hi: int = floori(q * (k + 1) / days_d)
	var term_lo: int = floori(q * k / days_d)
	return term_hi - term_lo


func run_daily_produce(day_index_k: int) -> Array:
	## 2.3-02: PRODUCE 依 (port_id, good_id) 升序。缺口：H 未列本方法名；k 應為 Clock.day_in_season−1。
	assert(_loaded, "GoodsLedger.run_daily_produce before load")
	var results: Array = []
	if not PortRegistry.is_loaded():
		results.append(_err(CODE_PORT_REGISTRY_NOT_LOADED, FIELD_PORT_REGISTRY, null, "PortRegistry required for PRODUCE"))
		_emit_errors(results)
		return results
	var jobs: Array = []
	for port_variant in PortRegistry.all_ids():
		var port_id: String = String(port_variant)
		var def: PortDef = PortRegistry.get_port(port_id)
		var good_keys: Array = def.role_cells.keys()
		good_keys.sort()
		for good_variant in good_keys:
			var good_id: String = String(good_variant)
			var cell: RoleCell = def.role_cells[good_id]
			if cell.role != PortRegistry.ROLE_PRODUCER:
				continue
			jobs.append({
				"port": port_id,
				"good": good_id,
				"q": cell.base_output_per_season,
			})
	jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a["port"]) == String(b["port"]):
			return String(a["good"]) < String(b["good"])
		return String(a["port"]) < String(b["port"])
	)
	for job_variant in jobs:
		var job: Dictionary = job_variant
		var qty: int = daily_produce_qty(int(job["q"]), day_index_k)
		if qty <= 0:
			continue
		var from_c: Dictionary = {KEY_KIND: KIND_EXTERNAL}
		var to_c: Dictionary = {KEY_KIND: KIND_MARKET, KEY_PORT: String(job["port"])}
		var seq_or_zero: int = transfer(from_c, to_c, StringName(String(job["good"])), qty, REASON_PRODUCE, REQUESTER_SYS03)
		results.append({"port": job["port"], "good": job["good"], "qty": qty, "result": seq_or_zero})
	return results


func container_id(kind: StringName, arg1: String = "", arg2: String = "") -> StringName:
	# D-08d: sole producer of container addresses. Formats are named constants only.
	var kind_s: String = String(kind)
	match kind_s:
		KIND_MARKET:
			return StringName(CONTAINER_ID_FMT_MARKET % arg1)
		KIND_WAREHOUSE:
			return StringName(CONTAINER_ID_FMT_WAREHOUSE % [arg1, arg2])
		KIND_HOLD:
			return StringName(CONTAINER_ID_FMT_HOLD % arg1)
		KIND_CONFISCATED:
			return StringName(CONTAINER_ID_CONFISCATED)
		_:
			return StringName()


func make_market(port_id: String) -> Dictionary:
	return {KEY_KIND: KIND_MARKET, KEY_PORT: port_id}


func make_warehouse(owner_id: String, port_id: String) -> Dictionary:
	return {KEY_KIND: KIND_WAREHOUSE, KEY_OWNER: owner_id, KEY_PORT: port_id}


func make_hold(ship_id: String, owner_id: String = "") -> Dictionary:
	# D-20c: HOLD owner_id = 船主帳戶; port set later via set_container_port.
	var d: Dictionary = {KEY_KIND: KIND_HOLD, KEY_SHIP: ship_id}
	if not owner_id.is_empty():
		d[KEY_OWNER] = owner_id
	return d


func ensure_hold_registered(container: Dictionary, port_id: StringName = &"") -> int:
	## WP-30: register empty HOLD meta so set_container_port／capacity work before first transfer.
	assert(_loaded, "GoodsLedger.ensure_hold_registered before load_and_validate")
	_clear_last_error()
	var d: Dictionary = container.duplicate()
	if not port_id.is_empty():
		d[KEY_PORT] = String(port_id)
	var key: String = _container_key(d)
	if key.is_empty():
		return CODE_FAIL
	if not port_id.is_empty():
		return set_container_port(StringName(key), port_id)
	return CODE_OK


func offtake_snapshot(port_id: StringName, good_id: StringName) -> Dictionary:
	# 15.1 H／ERR-SYS03-07: unknown port／good → empty Dictionary + last_error (D-08c).
	assert(_loaded, "GoodsLedger.offtake_snapshot before load_and_validate")
	_clear_last_error()
	var port_s: String = String(port_id)
	var good_s: String = String(good_id)
	if not _is_known_port(port_s) or not _is_known_good(good_s):
		_record_error(ERR_SYS03_07, FIELD_PORT_ID if not _is_known_port(port_s) else "good_id", port_s if not _is_known_port(port_s) else good_s, "offtake_snapshot unknown port_id or good_id")
		return {}
	if not _offtake_snapshot.has(port_s):
		return {}
	var by_good: Dictionary = _offtake_snapshot[port_s]
	if not by_good.has(good_s):
		return {}
	return (by_good[good_s] as Dictionary).duplicate(true)


func set_container_port(container_id: StringName, port_id: StringName) -> int:
	# 15.1 H: OK／FAILED; HOLD port while berthed; empty port_id clears (sailing).
	assert(_loaded, "GoodsLedger.set_container_port before load_and_validate")
	_clear_last_error()
	var cid: String = String(container_id)
	if not _container_meta.has(cid):
		_record_error(ERR_SYS03_08, FIELD_PORT_ID, cid, "set_container_port: container not registered")
		return CODE_FAIL
	var kind: String = String(_kind_by_id.get(cid, ""))
	if kind != KIND_HOLD and kind != KIND_WAREHOUSE:
		_record_error(ERR_SYS03_08, FIELD_KIND, kind, "set_container_port only for HOLD／WAREHOUSE")
		return CODE_FAIL
	var meta: Dictionary = _container_meta[cid]
	meta[FIELD_PORT_ID] = String(port_id)
	_container_meta[cid] = meta
	return CODE_OK


func container_departed(container_id: StringName) -> int:
	# FRM-SYS03-06／ERR-SYS03-08: berthed HOLD only; returns Σ pending counted as export.
	assert(_loaded, "GoodsLedger.container_departed before load_and_validate")
	_clear_last_error()
	var cid: String = String(container_id)
	if not _container_meta.has(cid):
		_record_error(ERR_SYS03_08, "container_id", cid, "container_departed: not registered")
		return 0
	var kind: String = String(_kind_by_id.get(cid, ""))
	if kind != KIND_HOLD:
		_record_error(ERR_SYS03_08, FIELD_KIND, kind, "container_departed: not HOLD")
		return 0
	var meta: Dictionary = _container_meta[cid]
	var port_s: String = String(meta.get(FIELD_PORT_ID, ""))
	if port_s.is_empty():
		_record_error(ERR_SYS03_08, FIELD_PORT_ID, cid, "container_departed: HOLD not in port")
		return 0
	var owner_s: String = String(meta.get(FIELD_OWNER_ID, ""))
	var total_c: int = 0
	var pending_bucket: Dictionary = _offtake_pending.get(cid, {})
	var good_keys: Array = pending_bucket.keys()
	good_keys.sort()
	for g_variant in good_keys:
		var good_s: String = String(g_variant)
		var c: int = int(pending_bucket[good_s])
		if c <= 0:
			continue
		_add_daily_owner_qty(port_s, good_s, FIELD_EXPORT, owner_s, c)
		total_c = total_c + c
		pending_bucket[good_s] = 0
	_offtake_pending.erase(cid)
	meta[FIELD_PORT_ID] = ""
	_container_meta[cid] = meta
	return total_c


func roll_offtake_snapshot(day: int) -> void:
	# FRM-SYS03-07／08／09: SimLoop only; after conservation, before signals (15-07).
	assert(_loaded, "GoodsLedger.roll_offtake_snapshot before load_and_validate")
	var w: int = Params.get_int(PRM_OFFTAKE_WINDOW_DAYS)
	if _offtake_epoch_day < 0:
		_offtake_epoch_day = day
	var record_days: int = day - _offtake_epoch_day + 1
	if record_days < 1:
		record_days = 1
	var window_days: int = w if w < record_days else record_days
	if window_days < 1:
		window_days = 1

	var ports: Array = []
	if PortRegistry.is_loaded():
		for p in PortRegistry.all_ids():
			ports.append(String(p))
	for p_existing in _offtake_daily.keys():
		var ps: String = String(p_existing)
		if not ports.has(ps):
			ports.append(ps)
	ports.sort()

	var goods: Array = []
	if GoodCatalog.is_loaded():
		for g in GoodCatalog.all_ids():
			goods.append(String(g))
	for p_variant in _offtake_daily.keys():
		var by_good: Dictionary = _offtake_daily[p_variant]
		for g_variant in by_good.keys():
			var gs: String = String(g_variant)
			if not goods.has(gs):
				goods.append(gs)
	goods.sort()

	for port_s in ports:
		if not _offtake_snapshot.has(port_s):
			_offtake_snapshot[port_s] = {}
		var snap_port: Dictionary = _offtake_snapshot[port_s]
		for good_s in goods:
			var agg: Dictionary = _aggregate_window(port_s, good_s, day, w)
			snap_port[good_s] = {
				FIELD_WINDOW_QTY: int(agg[FIELD_WINDOW_QTY]),
				FIELD_LOCAL_QTY: int(agg[FIELD_LOCAL_QTY]),
				FIELD_WINDOW_DAYS: window_days,
				FIELD_DAY: day,
			}
		_offtake_snapshot[port_s] = snap_port

	_prune_daily(day, w)


func debug_check_offtake_invariants() -> int:
	# FRM-SYS03-10: 0 ≤ pending ≤ get_qty for every pending entry (debug).
	assert(_loaded, "GoodsLedger.debug_check_offtake_invariants before load")
	_clear_last_error()
	var cids: Array = _offtake_pending.keys()
	cids.sort()
	for cid_variant in cids:
		var cid: String = String(cid_variant)
		var bucket: Dictionary = _offtake_pending[cid]
		var gkeys: Array = bucket.keys()
		gkeys.sort()
		for g_variant in gkeys:
			var good_s: String = String(g_variant)
			var pending_q: int = int(bucket[good_s])
			var qty: int = _get_qty_by_key(cid, good_s)
			if pending_q < 0 or pending_q > qty:
				_record_error(ERR_SYS03_05, "pending", {
					"container": cid,
					"good": good_s,
					"pending": pending_q,
					"qty": qty,
				}, "offtake pending invariant violated")
				return CODE_FAIL
	return CODE_OK


func make_confiscated() -> Dictionary:
	return {KEY_KIND: KIND_CONFISCATED}


func make_external() -> Dictionary:
	return {KEY_KIND: KIND_EXTERNAL}


func _hold_sailing_blocked(from: Variant, from_key: String, to: Variant, to_key: String) -> bool:
	## WP-30: consult ShipRegistry when HOLD is a TRADE／LOAD／UNLOAD endpoint.
	if not _is_hold_key(from_key) and not _is_hold_key(to_key):
		return false
	if ShipRegistry == null or not ShipRegistry.is_loaded():
		return false
	var targets: Array = []
	if _is_hold_key(from_key):
		targets.append(from)
	if _is_hold_key(to_key):
		targets.append(to)
	for c in targets:
		if not ShipRegistry.hold_transfer_allowed(c):
			var err: Dictionary = ShipRegistry.last_error()
			if err.is_empty():
				_record_error(
					StringName("ERR-SYS13-03"),
					FIELD_KIND,
					c,
					"HOLD transfer while not DOCKED (FRM-SYS13-10)"
				)
			else:
				# ShipRegistry already push_error'd; copy ErrorInfo only (TST-SYS13-13).
				_last_error = err
			return true
	return false


func _is_hold_key(container_key: String) -> bool:
	return String(_kind_by_id.get(container_key, "")) == KIND_HOLD


func _has_capacity_for(container: Variant, container_key: String, qty_i: int) -> bool:
	if _is_external_key(container_key):
		return true
	# D-08d: kind only from Dictionary kind field (or remembered registry), never parse id.
	var kind: String = _kind_of_container(container, container_key)
	# MARKET／CONFISCATED：不設上限（OQ-09 9b／預留池）；D-08e：不登錄提供者
	if kind == KIND_MARKET or kind == KIND_CONFISCATED:
		return true
	# WAREHOUSE／HOLD：只問該 kind 的 CapacityProvider；未登錄 → ERR-SYS03-03（D-08e）
	if kind == KIND_WAREHOUSE or kind == KIND_HOLD:
		if not _capacity_providers.has(kind):
			return false
		var provider: CapacityProvider = _capacity_providers[kind]
		var cap: int = provider.capacity(container)
		if cap <= CapacityProvider.CAPACITY_FAILURE:
			return false
		var used: int = _container_used(container_key)
		var remaining: int = cap - used
		return remaining >= qty_i
	return false


func _container_used(container_key: String) -> int:
	if not _stock.has(container_key):
		return 0
	var bucket: Dictionary = _stock[container_key]
	var keys: Array = bucket.keys()
	keys.sort()
	var sum: int = 0
	for g_variant in keys:
		sum = sum + int(bucket[g_variant])
	return sum


func _apply_expected_delta(good_s: String, reason: StringName, from_key: String, to_key: String, qty_i: int) -> void:
	# FRM-SYS03-01 右側：GENESIS／PRODUCE 增加；CONSUME／CONSTRUCT_USE／SEA_LOSS 減少
	var delta: int = 0
	if reason == REASON_GENESIS or reason == REASON_PRODUCE:
		if _is_external_key(from_key) and not _is_external_key(to_key):
			delta = qty_i
	elif reason == REASON_CONSUME or reason == REASON_CONSTRUCT_USE or reason == REASON_SEA_LOSS:
		if not _is_external_key(from_key) and _is_external_key(to_key):
			delta = 0 - qty_i
	if delta != 0:
		_expected_net[good_s] = int(_expected_net.get(good_s, 0)) + delta


func _is_positive_int(qty: Variant) -> bool:
	var t: int = typeof(qty)
	if t == TYPE_INT:
		return int(qty) > 0
	if t == TYPE_FLOAT:
		var f: float = float(qty)
		if f != floorf(f):
			return false
		return int(f) > 0
	return false


func _container_key(container: Variant) -> String:
	# D-08d: address only via container_id(kind,…); kind read from Dictionary kind field.
	# D-20c／ERR-SYS03-09: register owner_id／port_id; refuse incomplete WAREHOUSE／HOLD.
	if typeof(container) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = container
	if not d.has(KEY_KIND):
		return ""
	var kind: String = String(d[KEY_KIND])
	match kind:
		KIND_EXTERNAL:
			return EXTERNAL_KEY
		KIND_CONFISCATED:
			var cid_c: String = String(container_id(StringName(KIND_CONFISCATED)))
			_kind_by_id[cid_c] = kind
			_container_meta[cid_c] = {FIELD_OWNER_ID: "", FIELD_PORT_ID: ""}
			return cid_c
		KIND_MARKET:
			if not d.has(KEY_PORT):
				return ""
			var port_m: String = String(d[KEY_PORT])
			var cid_m: String = String(container_id(StringName(KIND_MARKET), port_m))
			_kind_by_id[cid_m] = kind
			_container_meta[cid_m] = {FIELD_OWNER_ID: "", FIELD_PORT_ID: port_m}
			return cid_m
		KIND_WAREHOUSE:
			if not d.has(KEY_OWNER) or not d.has(KEY_PORT):
				_record_error(ERR_SYS03_09, FIELD_OWNER_ID, d, "WAREHOUSE registration requires owner_id and port_id")
				return ""
			var owner_w: String = String(d[KEY_OWNER])
			var port_w: String = String(d[KEY_PORT])
			if owner_w.is_empty() or port_w.is_empty():
				_record_error(ERR_SYS03_09, FIELD_OWNER_ID, d, "WAREHOUSE registration requires owner_id and port_id")
				return ""
			var cid_w: String = String(container_id(
				StringName(KIND_WAREHOUSE), owner_w, port_w
			))
			_kind_by_id[cid_w] = kind
			_container_meta[cid_w] = {FIELD_OWNER_ID: owner_w, FIELD_PORT_ID: port_w}
			return cid_w
		KIND_HOLD:
			if not d.has(KEY_SHIP):
				return ""
			if not d.has(KEY_OWNER) or String(d[KEY_OWNER]).is_empty():
				_record_error(ERR_SYS03_09, FIELD_OWNER_ID, d, "HOLD registration requires owner_id")
				return ""
			var owner_h: String = String(d[KEY_OWNER])
			var cid_h: String = String(container_id(StringName(KIND_HOLD), String(d[KEY_SHIP])))
			_kind_by_id[cid_h] = kind
			# Preserve port if already set via set_container_port; else optional KEY_PORT on dict.
			var port_h: String = ""
			if _container_meta.has(cid_h):
				port_h = String((_container_meta[cid_h] as Dictionary).get(FIELD_PORT_ID, ""))
			if d.has(KEY_PORT) and not String(d[KEY_PORT]).is_empty():
				port_h = String(d[KEY_PORT])
			_container_meta[cid_h] = {FIELD_OWNER_ID: owner_h, FIELD_PORT_ID: port_h}
			return cid_h
		_:
			return ""


func _kind_of_container(container: Variant, container_key: String) -> String:
	# D-08d: kind from Dictionary kind field; fall back to registry written at container_id time.
	if typeof(container) == TYPE_DICTIONARY:
		var d: Dictionary = container
		if d.has(KEY_KIND):
			return String(d[KEY_KIND])
	return String(_kind_by_id.get(container_key, ""))


func _is_external_key(key: String) -> bool:
	return key == EXTERNAL_KEY


func _get_qty_by_key(container_key: String, good_s: String) -> int:
	if not _stock.has(container_key):
		return 0
	var bucket: Dictionary = _stock[container_key]
	return int(bucket.get(good_s, 0))


func _set_qty_by_key(container_key: String, good_s: String, qty_i: int) -> void:
	if not _stock.has(container_key):
		_stock[container_key] = {}
	var bucket: Dictionary = _stock[container_key]
	if qty_i == 0:
		bucket.erase(good_s)
		if bucket.is_empty():
			_stock.erase(container_key)
		else:
			_stock[container_key] = bucket
	else:
		bucket[good_s] = qty_i
		_stock[container_key] = bucket


func _clear_state() -> void:
	_stock = {}
	_expected_net = {}
	_kind_by_id = {}
	_container_meta = {}
	_next_seq = 1
	_loaded = false
	_capacity_providers = {}
	_day = DAY_PLACEHOLDER
	_offtake_daily = {}
	_offtake_pending = {}
	_offtake_snapshot = {}
	_offtake_epoch_day = 0 - 1
	_clear_last_error()


func _apply_offtake_on_transfer(
	from_key: String, to_key: String, good_s: String, qty_i: int, reason: StringName
) -> void:
	# FRM-SYS03-05 (a)–(f). GENESIS／PRODUCE do not record.
	if reason == REASON_GENESIS or reason == REASON_PRODUCE:
		return
	var from_kind: String = String(_kind_by_id.get(from_key, ""))
	var to_kind: String = String(_kind_by_id.get(to_key, ""))

	# (a) TRADE MARKET:P → X：pending[X][g] ＋＝ q
	if reason == REASON_TRADE and from_kind == KIND_MARKET and _is_owner_container_kind(to_kind):
		_add_pending(to_key, good_s, qty_i)
		return

	# (b) TRADE X → MARKET:P：sellin＋＝q；pending −＝ MIN(pending, q)
	if reason == REASON_TRADE and to_kind == KIND_MARKET and _is_owner_container_kind(from_kind):
		var port_b: String = String((_container_meta.get(to_key, {}) as Dictionary).get(FIELD_PORT_ID, ""))
		var owner_b: String = String((_container_meta.get(from_key, {}) as Dictionary).get(FIELD_OWNER_ID, ""))
		if not port_b.is_empty() and not owner_b.is_empty():
			_add_daily_owner_qty(port_b, good_s, FIELD_SELLIN, owner_b, qty_i)
		_reduce_pending(from_key, good_s, qty_i)
		return

	# (c) CONSUME／CONSTRUCT_USE 自 MARKET:P：local ＋＝ q
	if (reason == REASON_CONSUME or reason == REASON_CONSTRUCT_USE) and from_kind == KIND_MARKET:
		var port_c: String = String((_container_meta.get(from_key, {}) as Dictionary).get(FIELD_PORT_ID, ""))
		if not port_c.is_empty():
			_add_daily_local(port_c, good_s, qty_i)
		return

	# (d) CONSUME／CONSTRUCT_USE 自 X：c＝MIN(pending,q)；local＋＝c；pending−＝c
	if (reason == REASON_CONSUME or reason == REASON_CONSTRUCT_USE) and _is_owner_container_kind(from_kind):
		var c: int = _peek_pending(from_key, good_s)
		if c > qty_i:
			c = qty_i
		var port_d: String = String((_container_meta.get(from_key, {}) as Dictionary).get(FIELD_PORT_ID, ""))
		if c > 0 and not port_d.is_empty():
			_add_daily_local(port_d, good_s, c)
		_reduce_pending(from_key, good_s, qty_i)
		return

	# (e) LOAD／UNLOAD X → Y（同港）：transfer pending first
	if (reason == REASON_LOAD or reason == REASON_UNLOAD) and _is_owner_container_kind(from_kind) and _is_owner_container_kind(to_kind):
		var m: int = _peek_pending(from_key, good_s)
		if m > qty_i:
			m = qty_i
		if m > 0:
			_reduce_pending(from_key, good_s, m)
			_add_pending(to_key, good_s, m)
		return

	# (f) 其他使 X 減量：pending ＝ MIN(pending, 轉移後現量)
	if not _is_external_key(from_key) and _is_owner_container_kind(from_kind):
		var after: int = _get_qty_by_key(from_key, good_s)
		var pend: int = _peek_pending(from_key, good_s)
		if pend > after:
			_set_pending(from_key, good_s, after)


func _is_owner_container_kind(kind: String) -> bool:
	return kind == KIND_WAREHOUSE or kind == KIND_HOLD


func _peek_pending(container_key: String, good_s: String) -> int:
	if not _offtake_pending.has(container_key):
		return 0
	return int((_offtake_pending[container_key] as Dictionary).get(good_s, 0))


func _add_pending(container_key: String, good_s: String, qty_i: int) -> void:
	if not _offtake_pending.has(container_key):
		_offtake_pending[container_key] = {}
	var bucket: Dictionary = _offtake_pending[container_key]
	bucket[good_s] = int(bucket.get(good_s, 0)) + qty_i
	_offtake_pending[container_key] = bucket


func _reduce_pending(container_key: String, good_s: String, qty_i: int) -> void:
	var pend: int = _peek_pending(container_key, good_s)
	var dec: int = qty_i if qty_i < pend else pend
	_set_pending(container_key, good_s, pend - dec)


func _set_pending(container_key: String, good_s: String, qty_i: int) -> void:
	if qty_i <= 0:
		if _offtake_pending.has(container_key):
			var bucket: Dictionary = _offtake_pending[container_key]
			bucket.erase(good_s)
			if bucket.is_empty():
				_offtake_pending.erase(container_key)
			else:
				_offtake_pending[container_key] = bucket
		return
	if not _offtake_pending.has(container_key):
		_offtake_pending[container_key] = {}
	var b: Dictionary = _offtake_pending[container_key]
	b[good_s] = qty_i
	_offtake_pending[container_key] = b


func _ensure_daily_cell(port_s: String, good_s: String) -> Dictionary:
	if not _offtake_daily.has(port_s):
		_offtake_daily[port_s] = {}
	var by_good: Dictionary = _offtake_daily[port_s]
	if not by_good.has(good_s):
		by_good[good_s] = {}
	var by_day: Dictionary = by_good[good_s]
	var day_key: String = str(_day)
	if not by_day.has(day_key):
		by_day[day_key] = {
			FIELD_LOCAL: 0,
			FIELD_EXPORT: {},
			FIELD_SELLIN: {},
		}
	by_good[good_s] = by_day
	_offtake_daily[port_s] = by_good
	return by_day[day_key]


func _add_daily_local(port_s: String, good_s: String, qty_i: int) -> void:
	var cell: Dictionary = _ensure_daily_cell(port_s, good_s)
	cell[FIELD_LOCAL] = int(cell.get(FIELD_LOCAL, 0)) + qty_i


func _add_daily_owner_qty(
	port_s: String, good_s: String, field: String, owner_s: String, qty_i: int
) -> void:
	var cell: Dictionary = _ensure_daily_cell(port_s, good_s)
	var owners: Dictionary = cell.get(field, {})
	owners[owner_s] = int(owners.get(owner_s, 0)) + qty_i
	cell[field] = owners


func _aggregate_window(port_s: String, good_s: String, day: int, w: int) -> Dictionary:
	# FRM-SYS03-07: local_W + Σ MAX(0, export_a − sellin_a) with owner_id ascending.
	var local_w: int = 0
	var export_by_owner: Dictionary = {}
	var sellin_by_owner: Dictionary = {}
	if _offtake_daily.has(port_s):
		var by_good: Dictionary = _offtake_daily[port_s]
		if by_good.has(good_s):
			var by_day: Dictionary = by_good[good_s]
			var day_keys: Array = by_day.keys()
			day_keys.sort()
			for day_key_variant in day_keys:
				var day_s: String = String(day_key_variant)
				var d_i: int = int(day_s)
				if d_i <= day - w:
					continue
				var cell: Dictionary = by_day[day_key_variant]
				local_w = local_w + int(cell.get(FIELD_LOCAL, 0))
				var ex: Dictionary = cell.get(FIELD_EXPORT, {})
				for a_variant in ex.keys():
					var a: String = String(a_variant)
					export_by_owner[a] = int(export_by_owner.get(a, 0)) + int(ex[a_variant])
				var si: Dictionary = cell.get(FIELD_SELLIN, {})
				for a_variant2 in si.keys():
					var a2: String = String(a_variant2)
					sellin_by_owner[a2] = int(sellin_by_owner.get(a2, 0)) + int(si[a_variant2])
	var owners: Dictionary = {}
	for a in export_by_owner.keys():
		owners[String(a)] = true
	for a in sellin_by_owner.keys():
		owners[String(a)] = true
	var owner_list: Array = owners.keys()
	owner_list.sort()
	var net_sum: int = 0
	for a_variant in owner_list:
		var a: String = String(a_variant)
		var net_a: int = int(export_by_owner.get(a, 0)) - int(sellin_by_owner.get(a, 0))
		if net_a < 0:
			net_a = 0
		net_sum = net_sum + net_a
	return {
		FIELD_WINDOW_QTY: local_w + net_sum,
		FIELD_LOCAL_QTY: local_w,
	}


func _prune_daily(day: int, w: int) -> void:
	# FRM-SYS03-09: drop day ≤ d − W.
	var ports: Array = _offtake_daily.keys()
	ports.sort()
	for port_variant in ports:
		var port_s: String = String(port_variant)
		var by_good: Dictionary = _offtake_daily[port_s]
		var goods: Array = by_good.keys()
		goods.sort()
		for good_variant in goods:
			var good_s: String = String(good_variant)
			var by_day: Dictionary = by_good[good_s]
			var day_keys: Array = by_day.keys()
			for day_key_variant in day_keys:
				var d_i: int = int(String(day_key_variant))
				if d_i <= day - w:
					by_day.erase(day_key_variant)
			if by_day.is_empty():
				by_good.erase(good_s)
			else:
				by_good[good_s] = by_day
		if by_good.is_empty():
			_offtake_daily.erase(port_s)
		else:
			_offtake_daily[port_s] = by_good


func _is_known_port(port_s: String) -> bool:
	if not PortRegistry.is_loaded():
		return false
	for p in PortRegistry.all_ids():
		if String(p) == port_s:
			return true
	return false


func _is_known_good(good_s: String) -> bool:
	if not GoodCatalog.is_loaded():
		return false
	for g in GoodCatalog.all_ids():
		if String(g) == good_s:
			return true
	return false


func _clear_last_error() -> void:
	_last_error = {}


func _fail(code: StringName, field: String, value: Variant, message: String) -> int:
	# D-04: transfer fail → 0 (literal); ErrorInfo via last_error().
	_record_error(code, field, value, message)
	return 0


func _record_error(code: StringName, field: String, value: Variant, message: String) -> void:
	var info: Dictionary = _err(code, field, value, message)
	_last_error = info
	push_error("GoodsLedger: %s" % str(info))


func _err(code: StringName, field: String, value: Variant, message: String) -> Dictionary:
	# D-04 ErrorInfo = {code, sys, detail}; C-06 file/field/value live in detail.
	return ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("GoodsLedger: %s" % str(e))
