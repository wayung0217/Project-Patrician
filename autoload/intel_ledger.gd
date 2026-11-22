extends Node
## Autoload: IntelLedger — SYS-15 ship intel & board (03_Systems 25.1／D-34／D-37c／D-38a).
## _ready() only clears fields; load_and_validate via SimLoop.boot (2.2-01).
## Implements ShipEventObserver via adapter (Node cannot extend RefCounted interface).
## D-37e／D-38a: no grant_base；contact level 2 via BrokerProvider.has_kontor (D-60f).
## D-37c: PUBLIC_DELAY visibility；board_samples requester SYS-16 only.
## D-60f: BrokerProvider injected；absent → ERR-SYS15-06（field＝broker_provider）.

signal board_updated(port_id: StringName, tick: int)

const SYS_ID := &"SYS-15"
const SCRIPT_PATH := "res://autoload/intel_ledger.gd"
const REQUESTER_SYS16 := &"SYS-16"

const ERR_SYS15_01 := &"ERR-SYS15-01"
const ERR_SYS15_02 := &"ERR-SYS15-02"
const ERR_SYS15_03 := &"ERR-SYS15-03"
const ERR_SYS15_04 := &"ERR-SYS15-04"
const ERR_SYS15_05 := &"ERR-SYS15-05"
const ERR_SYS15_06 := &"ERR-SYS15-06"
const ERR_SYS15_07 := &"ERR-SYS15-07"

const PRM_WINDOW_DAYS := "PRM-SYS15-WINDOW_DAYS"
## EX-03: contact level when actor has kontor at port (was 1+1).
const CONTACT_LEVEL_KONTOR := 2
## D-84f: minimum sample count for direction／trend (was 1+1).
const MIN_SAMPLES_FOR_TREND := 2
const PRM_DECAY_DAYS := "PRM-SYS15-DECAY_DAYS"
const PRM_DIV_LO := "PRM-SYS15-DIVERGENCE_LO_PPM"
const PRM_DIV_HI := "PRM-SYS15-DIVERGENCE_HI_PPM"
const PRM_DEADBAND := "PRM-SYS15-DIRECTION_DEADBAND_PPM"
const PRM_WEEKS_SCALE := "PRM-SYS15-WEEKS_SCALE"
const PRM_PUBLIC_DELAY := "PRM-SYS15-PUBLIC_DELAY_TICKS"
const PRM_PPM_SCALE := "PRM-SYS06-PPM_SCALE"

## 25.1 附錄 A 六項 + D-37c PUBLIC_DELAY（可見性）；皆無值，缺鍵 → ERR-SYS15-01.
const NOVALUE_PRMS: Array[String] = [
	PRM_WINDOW_DAYS,
	PRM_DECAY_DAYS,
	PRM_DIV_LO,
	PRM_DIV_HI,
	PRM_DEADBAND,
	PRM_WEEKS_SCALE,
	PRM_PUBLIC_DELAY,
]

const DIR_NONE := &"NONE"
const DIR_UP := &"UP"
const DIR_DOWN := &"DOWN"
const DIR_FLAT := &"FLAT"

enum DivergenceBand { LOW, MID, HIGH }

const KEY_SHIP_ID := "ship_id"
const KEY_OWNER_ID := "owner_id"
const KEY_PORT_ID := "port_id"
const KEY_FROM_PORT_ID := "from_port_id"
const KEY_ORIGIN_PORT := "origin_port"
const KEY_TICK_TAKEN := "tick_taken"
const KEY_DAY_TAKEN := "day_taken"
const KEY_GOODS := "goods"
const KEY_PUBLISHED := "published"
const KEY_MID_LI := "mid_li"
const KEY_BAND := "band"
const KEY_WEEKS_X := "weeks_x"
const KEY_TICK_ARRIVED := "tick_arrived"
const KEY_SNAPSHOT := "snapshot"
const KEY_N := "n"
const KEY_CONSENSUS_MID := "consensus_mid_li"
const KEY_CONSENSUS_WEEKS := "consensus_weeks_x"
const KEY_MEAN_AGE := "mean_age_days"
const KEY_NEWEST_AGE := "newest_age_days"
const KEY_DIV_PPM := "divergence_ppm"
const KEY_DIV_BAND := "divergence_band"
const KEY_DIRECTION := "direction"
const KEY_AGE_DAYS := "age_days"

var _loaded: bool = false
var _last_error: Dictionary = {}
var _ship_snap: Dictionary = {} ## ship_id:String → Dictionary
var _own_snap: Dictionary = {} ## owner:String → {origin:String → snap}
var _rec: Dictionary = {} ## port:String → {pair_key:String → {snapshot, tick_arrived}}
var _contact: Dictionary = {} ## actor:String → {port:String → 1}
var _pending_errors: Array = []
var _pending_board_signals: Array = [] ## {port_id, tick}
var _observer_adapter: _ObserverAdapter = null
var _broker: BrokerProvider = null


func _ready() -> void:
	_clear_runtime()


func get_ship_event_observer() -> ShipEventObserver:
	if _observer_adapter == null:
		_observer_adapter = _ObserverAdapter.new()
		_observer_adapter.host = self
	return _observer_adapter


func set_broker_provider(provider: BrokerProvider) -> void:
	## D-60f: inject before SimLoop.boot；formal provider＝BrokerDesk（WP-41）.
	## Tests may pass null to clear（fixture teardown／gate probes）.
	_broker = provider


func has_broker_provider() -> bool:
	return _broker != null


func is_loaded() -> bool:
	return _loaded


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func load_and_validate() -> Array:
	# Keep injected BrokerProvider across reload（D-60f；mirror TradeDesk／BuildingEconomy）.
	_clear_runtime(true)
	var errors: Array = []
	if not Params.is_loaded():
		errors.append(_err(ERR_SYS15_01, "Params", null, "Params must load before IntelLedger"))
		_emit_errors(errors)
		return errors
	for key in NOVALUE_PRMS:
		if not Params.has_prm(StringName(key)):
			errors.append(_err(ERR_SYS15_01, key, null, "required PRM-SYS15 key missing"))
	if not Params.has_prm(StringName(PRM_PPM_SCALE)):
		errors.append(_err(ERR_SYS15_01, PRM_PPM_SCALE, null, "PRM-SYS06-PPM_SCALE missing"))
	if errors.is_empty():
		var window_d: int = Params.get_int(StringName(PRM_WINDOW_DAYS))
		var decay_d: int = Params.get_int(StringName(PRM_DECAY_DAYS))
		var lo: int = Params.get_int(StringName(PRM_DIV_LO))
		var hi: int = Params.get_int(StringName(PRM_DIV_HI))
		var deadband: int = Params.get_int(StringName(PRM_DEADBAND))
		var weeks_scale: int = Params.get_int(StringName(PRM_WEEKS_SCALE))
		var delay: int = Params.get_int(StringName(PRM_PUBLIC_DELAY))
		if window_d < 1:
			errors.append(_err(ERR_SYS15_01, PRM_WINDOW_DAYS, window_d, "WINDOW_DAYS < 1"))
		if decay_d < 1:
			errors.append(_err(ERR_SYS15_01, PRM_DECAY_DAYS, decay_d, "DECAY_DAYS < 1"))
		if lo < 0:
			errors.append(_err(ERR_SYS15_01, PRM_DIV_LO, lo, "DIVERGENCE_LO_PPM < 0"))
		if hi < 0:
			errors.append(_err(ERR_SYS15_01, PRM_DIV_HI, hi, "DIVERGENCE_HI_PPM < 0"))
		if deadband < 0:
			errors.append(_err(ERR_SYS15_01, PRM_DEADBAND, deadband, "DEADBAND < 0"))
		if weeks_scale < 1:
			errors.append(_err(ERR_SYS15_01, PRM_WEEKS_SCALE, weeks_scale, "WEEKS_SCALE < 1"))
		if delay < 0:
			errors.append(_err(ERR_SYS15_01, PRM_PUBLIC_DELAY, delay, "PUBLIC_DELAY_TICKS < 0"))
		if window_d > decay_d:
			errors.append(
				_err(ERR_SYS15_02, PRM_WINDOW_DAYS, window_d, "WINDOW_DAYS > DECAY_DAYS")
			)
		if lo > hi:
			errors.append(_err(ERR_SYS15_02, PRM_DIV_LO, lo, "DIVERGENCE_LO > HI"))
	if errors.is_empty():
		_loaded = true
	else:
		_loaded = false
		_emit_errors(errors)
	return errors


func boot_gate_errors() -> Array:
	## ERR-SYS15-06: observer＋BrokerProvider＋stock_weeks (C-06／D-60f).
	var errors: Array = []
	if not ShipRegistry.has_ship_observer():
		errors.append(
			_err(ERR_SYS15_06, "ShipEventObserver", null, "ShipRegistry has no ship observer")
		)
	if not has_broker_provider():
		errors.append(
			_err(ERR_SYS15_06, "broker_provider", null, "BrokerProvider not injected (D-60f)")
		)
	if not MarketPricer.has_method("stock_weeks"):
		errors.append(
			_err(ERR_SYS15_06, "stock_weeks", null, "MarketPricer.stock_weeks missing")
		)
	_emit_errors(errors)
	return errors


func on_departed(
	ship_id: StringName, owner_id: StringName, from_port_id: StringName, tick: int
) -> void:
	## FRM-SYS15-01.
	assert(_loaded, "IntelLedger.on_departed before load")
	_clear_last()
	var goods: Dictionary = {}
	var ids: PackedStringArray = GoodCatalog.all_ids()
	var weeks_scale: int = Params.get_int(StringName(PRM_WEEKS_SCALE))
	for g_variant in ids:
		var good_id: StringName = StringName(g_variant)
		var mid: float = MarketPricer.mid_price(from_port_id, good_id)
		var mp_err: Dictionary = MarketPricer.last_error()
		if not mp_err.is_empty() or mid <= 0.0:
			_fail_snapshot(ship_id, from_port_id, good_id, "mid_price failed")
			return
		var mid_li: int = floori(mid)
		if mid_li < 1:
			_fail_snapshot(ship_id, from_port_id, good_id, "mid_li < 1")
			return
		var good: GoodDef = GoodCatalog.get_good(String(good_id))
		var base_li: int = good.base_price_li
		var ratio: float = mid / float(base_li) if base_li > 0 else 0.0
		var band: int = MarketPricer.indicator_band(ratio)
		var w: Variant = MarketPricer.stock_weeks(from_port_id, good_id)
		var weeks_x: Variant = null
		if w != null:
			weeks_x = floori(float(w) * float(weeks_scale))
		goods[String(good_id)] = {
			KEY_MID_LI: mid_li,
			KEY_BAND: band,
			KEY_WEEKS_X: weeks_x,
		}
	var snap: Dictionary = {
		KEY_SHIP_ID: ship_id,
		KEY_OWNER_ID: owner_id,
		KEY_ORIGIN_PORT: from_port_id,
		KEY_TICK_TAKEN: tick,
		KEY_DAY_TAKEN: Clock.day,
		KEY_GOODS: goods,
		KEY_PUBLISHED: false,
	}
	_ship_snap[String(ship_id)] = snap
	var owner_s: String = String(owner_id)
	if not _own_snap.has(owner_s):
		_own_snap[owner_s] = {}
	(_own_snap[owner_s] as Dictionary)[String(from_port_id)] = snap.duplicate(true)


func on_arrivals(tick: int, arrivals: Array) -> void:
	## FRM-SYS15-02: batch write; query must not see partial batch.
	assert(_loaded, "IntelLedger.on_arrivals before load")
	var ports_touched: Dictionary = {}
	for item_variant in arrivals:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_variant
		var sid: StringName = item.get(KEY_SHIP_ID, &"")
		var owner_id: StringName = item.get(KEY_OWNER_ID, &"")
		var port_id: StringName = item.get(KEY_PORT_ID, &"")
		var from_port: StringName = item.get(KEY_FROM_PORT_ID, &"")
		_bump_contact(owner_id, port_id)
		var snap: Variant = _ship_snap.get(String(sid), null)
		if typeof(snap) != TYPE_DICTIONARY:
			continue
		var snap_d: Dictionary = snap
		if bool(snap_d.get(KEY_PUBLISHED, false)):
			continue
		var origin: StringName = snap_d.get(KEY_ORIGIN_PORT, &"")
		if String(origin) == String(port_id):
			continue
		var port_s: String = String(port_id)
		if not _rec.has(port_s):
			_rec[port_s] = {}
		var pair: String = _pair_key(sid, origin)
		(_rec[port_s] as Dictionary)[pair] = {
			KEY_SNAPSHOT: snap_d.duplicate(true),
			KEY_TICK_ARRIVED: tick,
		}
		snap_d[KEY_PUBLISHED] = true
		_ship_snap[String(sid)] = snap_d
		ports_touched[port_s] = true
	var port_keys: Array = ports_touched.keys()
	port_keys.sort()
	for p in port_keys:
		_pending_board_signals.append({"port_id": StringName(p), "tick": tick})


func daily_step(_day: int) -> Array:
	## FRM-SYS15-08: trim ST-BOARD by age；return pending snapshot errors.
	assert(_loaded, "IntelLedger.daily_step before load")
	var window_d: int = Params.get_int(StringName(PRM_WINDOW_DAYS))
	var today: int = Clock.day
	var port_keys: Array = _rec.keys()
	port_keys.sort()
	for port_s_variant in port_keys:
		var port_s: String = String(port_s_variant)
		var board: Dictionary = _rec[port_s]
		var pair_keys: Array = board.keys()
		pair_keys.sort()
		for pair_variant in pair_keys:
			var pair: String = String(pair_variant)
			var entry: Dictionary = board[pair]
			var snap: Dictionary = entry.get(KEY_SNAPSHOT, {})
			var day_taken: int = _dict_int(snap, KEY_DAY_TAKEN, 0)
			var age: int = today - day_taken
			if age >= window_d:
				board.erase(pair)
		if board.is_empty():
			_rec.erase(port_s)
		else:
			_rec[port_s] = board
	var out: Array = _pending_errors.duplicate()
	_pending_errors.clear()
	return out


func flush_signals() -> void:
	## D-05: emit board_updated after all same-day writes.
	var queued: Array = _pending_board_signals.duplicate()
	_pending_board_signals.clear()
	for item_variant in queued:
		var item: Dictionary = item_variant
		board_updated.emit(item["port_id"], _expect_int(item["tick"], "tick"))


func own_snapshot(actor_id: StringName, origin_port: StringName) -> Dictionary:
	## FRM-SYS15-07.
	assert(_loaded, "IntelLedger.own_snapshot before load")
	_clear_last()
	var by_origin: Variant = _own_snap.get(String(actor_id), null)
	if typeof(by_origin) != TYPE_DICTIONARY:
		return {}
	var snap_v: Variant = (by_origin as Dictionary).get(String(origin_port), null)
	if typeof(snap_v) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = (snap_v as Dictionary).duplicate(true)
	out[KEY_AGE_DAYS] = Clock.day - _dict_int(out, KEY_DAY_TAKEN, 0)
	return out


func board_for(
	actor_id: StringName, port_id: StringName, origin_port: StringName, good_id: StringName
) -> Dictionary:
	## FRM-SYS15-06 + D-37c visibility.
	assert(_loaded, "IntelLedger.board_for before load")
	_clear_last()
	if not _ids_ok(port_id, origin_port, good_id):
		_record(ERR_SYS15_04, KEY_PORT_ID, port_id, "unknown port/origin/good")
		return {}
	if not _actor_present(actor_id, port_id):
		_record(ERR_SYS15_04, KEY_OWNER_ID, actor_id, "actor not present at port")
		return {}
	var samples: Array = _visible_samples(actor_id, port_id, origin_port, good_id)
	return _summarize_board(samples, good_id)


func board_samples(
	actor_id: StringName,
	port_id: StringName,
	origin_port: StringName,
	good_id: StringName,
	requester: StringName
) -> Array:
	## D-37e: requester only SYS-16 → else ERR-SYS15-03.
	assert(_loaded, "IntelLedger.board_samples before load")
	_clear_last()
	if requester != REQUESTER_SYS16:
		_record(ERR_SYS15_03, "requester", requester, "board_samples requester not SYS-16")
		return []
	if not _ids_ok(port_id, origin_port, good_id):
		_record(ERR_SYS15_04, KEY_PORT_ID, port_id, "unknown port/origin/good")
		return []
	return _visible_samples(actor_id, port_id, origin_port, good_id)


func contact_level(actor_id: StringName, port_id: StringName) -> int:
	## FRM-SYS15-09（D-37e／D-38a）: 2 via has_kontor；1 via contact／presence；else 0.
	assert(_loaded, "IntelLedger.contact_level before load")
	_clear_last()
	if _has_kontor(actor_id, port_id):
		return CONTACT_LEVEL_KONTOR
	var actor_s: String = String(actor_id)
	var port_s: String = String(port_id)
	if _contact.has(actor_s) and (_contact[actor_s] as Dictionary).has(port_s):
		return 1
	if _actor_present(actor_id, port_id):
		return 1
	return 0


# --- internals ---


func _clear_runtime(keep_broker: bool = false) -> void:
	_loaded = false
	_last_error = {}
	_ship_snap = {}
	_own_snap = {}
	_rec = {}
	_contact = {}
	_pending_errors = []
	_pending_board_signals = []
	if not keep_broker:
		_broker = null


func _clear_last() -> void:
	_last_error = {}


func _record(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)
	push_error("IntelLedger: %s" % str(_last_error))


func _err(code: StringName, field: String, value: Variant, message: String) -> Dictionary:
	return ErrorInfoUtil.make_validation(code, SYS_ID, SCRIPT_PATH, field, value, message)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("IntelLedger: %s" % str(e))


func _fail_snapshot(
	ship_id: StringName, from_port: StringName, good_id: StringName, message: String
) -> void:
	_ship_snap.erase(String(ship_id))
	var info: Dictionary = _err(
		ERR_SYS15_05, String(good_id), from_port, "snapshot failed: %s" % message
	)
	_pending_errors.append(info)
	_last_error = info
	push_error("IntelLedger: %s" % str(info))


func _pair_key(ship_id: StringName, origin: StringName) -> String:
	return "%s\t%s" % [String(ship_id), String(origin)]


func _bump_contact(owner_id: StringName, port_id: StringName) -> void:
	var actor_s: String = String(owner_id)
	var port_s: String = String(port_id)
	if not _contact.has(actor_s):
		_contact[actor_s] = {}
	var cur: int = _dict_int(_contact[actor_s] as Dictionary, port_s, 0)
	if cur < 1:
		(_contact[actor_s] as Dictionary)[port_s] = 1


func _ids_ok(port_id: StringName, origin_port: StringName, good_id: StringName) -> bool:
	if not PortRegistry.is_loaded() or not GoodCatalog.is_loaded():
		return false
	var port_ok := false
	var origin_ok := false
	for p in PortRegistry.all_ids():
		var ps: String = String(p)
		if ps == String(port_id):
			port_ok = true
		if ps == String(origin_port):
			origin_ok = true
	if not port_ok or not origin_ok:
		return false
	for g in GoodCatalog.all_ids():
		if String(g) == String(good_id):
			return true
	return false


func _actor_present(actor_id: StringName, port_id: StringName) -> bool:
	## FRM-SYS15-06: docked ship at P, or any-state building at P.
	if ShipRegistry.is_loaded():
		for sid_variant in ShipRegistry.ship_ids(actor_id):
			var info: Dictionary = ShipRegistry.ship_info(sid_variant)
			if info.is_empty():
				continue
			if StringName(info.get("state", &"")) != Ship.STATE_DOCKED:
				continue
			if String(info.get("port_id", "")) == String(port_id):
				return true
	if BuildingEconomy.is_loaded():
		for b_variant in BuildingEconomy.buildings_for_port(String(port_id)):
			var bld: Building = b_variant as Building
			if bld != null and bld.owner == actor_id:
				return true
	return false


func _has_kontor(actor_id: StringName, port_id: StringName) -> bool:
	## D-60f／FRM-SYS15-09: only via injected BrokerProvider（no /root lookup）.
	if _broker == null:
		return false
	return _broker.has_kontor(actor_id, port_id)


func _is_broker_qualified(actor_id: StringName, port_id: StringName) -> bool:
	## FRM-SYS16-04／02／D-60f: single rule via injected BrokerProvider（N-04）.
	if _broker == null:
		return false
	return _broker.is_broker_qualified(actor_id, port_id)


func _sample_visible(actor_id: StringName, port_id: StringName, tick_arrived: int) -> bool:
	## FRM-SYS16-04: visible if tick ≥ arrived+delay, or broker-qualified.
	var delay: int = Params.get_int(StringName(PRM_PUBLIC_DELAY))
	if Clock.tick >= tick_arrived + delay:
		return true
	if delay == 0:
		return true
	return _is_broker_qualified(actor_id, port_id)


func _visible_samples(
	actor_id: StringName, port_id: StringName, origin_port: StringName, good_id: StringName
) -> Array:
	var window_d: int = Params.get_int(StringName(PRM_WINDOW_DAYS))
	var today: int = Clock.day
	var board: Dictionary = _rec.get(String(port_id), {})
	var out: Array = []
	var pair_keys: Array = board.keys()
	pair_keys.sort()
	for pair_variant in pair_keys:
		var entry: Dictionary = board[pair_variant]
		var snap: Dictionary = entry.get(KEY_SNAPSHOT, {})
		if String(snap.get(KEY_ORIGIN_PORT, "")) != String(origin_port):
			continue
		var tick_arrived: int = _dict_int(entry, KEY_TICK_ARRIVED, 0)
		if not _sample_visible(actor_id, port_id, tick_arrived):
			continue
		var day_taken: int = _dict_int(snap, KEY_DAY_TAKEN, 0)
		var age: int = today - day_taken
		if age < 0 or age >= window_d:
			continue
		var goods: Dictionary = snap.get(KEY_GOODS, {})
		if not goods.has(String(good_id)):
			continue
		var g: Dictionary = goods[String(good_id)]
		out.append({
			KEY_SHIP_ID: snap.get(KEY_SHIP_ID, &""),
			KEY_OWNER_ID: snap.get(KEY_OWNER_ID, &""),
			KEY_ORIGIN_PORT: origin_port,
			KEY_TICK_TAKEN: _dict_int(snap, KEY_TICK_TAKEN, 0),
			KEY_DAY_TAKEN: day_taken,
			KEY_MID_LI: _dict_int(g, KEY_MID_LI, 0),
			KEY_BAND: _dict_int(g, KEY_BAND, 0),
			KEY_WEEKS_X: g.get(KEY_WEEKS_X, null),
			KEY_TICK_ARRIVED: tick_arrived,
			KEY_AGE_DAYS: age,
		})
	return out


func _summarize_board(samples: Array, good_id: StringName) -> Dictionary:
	var n: int = samples.size()
	if n == 0:
		return {
			KEY_N: 0,
			KEY_CONSENSUS_MID: null,
			KEY_BAND: null,
			KEY_CONSENSUS_WEEKS: null,
			KEY_MEAN_AGE: null,
			KEY_NEWEST_AGE: null,
			KEY_DIV_PPM: null,
			KEY_DIV_BAND: null,
			KEY_DIRECTION: null,
		}
	var decay_d: int = Params.get_int(StringName(PRM_DECAY_DAYS))
	var ppm: int = Params.get_int(StringName(PRM_PPM_SCALE))
	var sum_w: int = 0
	var sum_wm: int = 0
	var sum_wa: int = 0
	var sum_ww: int = 0
	var sum_w_weeks: int = 0
	var min_mid: int = 0
	var max_mid: int = 0
	var newest_age: int = 0
	var first := true
	for s_variant in samples:
		var s: Dictionary = s_variant
		var age: int = _dict_int(s, KEY_AGE_DAYS, 0)
		var w: int = decay_d - age
		var mid: int = _dict_int(s, KEY_MID_LI, 0)
		var prod_wm: Variant = _mul_checked(w, mid)
		var prod_wa: Variant = _mul_checked(w, age)
		if prod_wm == null or prod_wa == null:
			_record(ERR_SYS15_07, KEY_CONSENSUS_MID, mid, "weighted sum overflow")
			return {}
		var prod_wm_i: int = _expect_int(prod_wm, KEY_CONSENSUS_MID)
		var prod_wa_i: int = _expect_int(prod_wa, KEY_MEAN_AGE)
		if not _add_checked(sum_w, w) or not _add_checked(sum_wm, prod_wm_i):
			_record(ERR_SYS15_07, KEY_CONSENSUS_MID, mid, "weighted sum overflow")
			return {}
		if not _add_checked(sum_wa, prod_wa_i):
			_record(ERR_SYS15_07, KEY_MEAN_AGE, age, "weighted age overflow")
			return {}
		sum_w = sum_w + w
		sum_wm = sum_wm + prod_wm_i
		sum_wa = sum_wa + prod_wa_i
		var weeks_x: Variant = s.get(KEY_WEEKS_X, null)
		if weeks_x != null:
			var weeks_i: int = _expect_int(weeks_x, KEY_CONSENSUS_WEEKS)
			var prod_ww: Variant = _mul_checked(w, weeks_i)
			if prod_ww == null:
				_record(ERR_SYS15_07, KEY_CONSENSUS_WEEKS, weeks_x, "weeks weighted overflow")
				return {}
			var prod_ww_i: int = _expect_int(prod_ww, KEY_CONSENSUS_WEEKS)
			if not _add_checked(sum_ww, prod_ww_i):
				_record(ERR_SYS15_07, KEY_CONSENSUS_WEEKS, weeks_x, "weeks weighted overflow")
				return {}
			if not _add_checked(sum_w_weeks, w):
				_record(ERR_SYS15_07, KEY_CONSENSUS_WEEKS, weeks_x, "weeks weight overflow")
				return {}
			sum_ww = sum_ww + prod_ww_i
			sum_w_weeks = sum_w_weeks + w
		if first:
			min_mid = mid
			max_mid = mid
			newest_age = age
			first = false
		else:
			if mid < min_mid:
				min_mid = mid
			if mid > max_mid:
				max_mid = mid
			if age < newest_age:
				newest_age = age
	if sum_w <= 0:
		return {
			KEY_N: 0,
			KEY_CONSENSUS_MID: null,
			KEY_BAND: null,
			KEY_CONSENSUS_WEEKS: null,
			KEY_MEAN_AGE: null,
			KEY_NEWEST_AGE: null,
			KEY_DIV_PPM: null,
			KEY_DIV_BAND: null,
			KEY_DIRECTION: null,
		}
	var consensus: int = floori(float(sum_wm) / float(sum_w))
	var mean_age: int = floori(float(sum_wa) / float(sum_w))
	var consensus_weeks: Variant = null
	if sum_w_weeks > 0:
		consensus_weeks = floori(float(sum_ww) / float(sum_w_weeks))
	var good: GoodDef = GoodCatalog.get_good(String(good_id))
	var base_li: int = good.base_price_li
	var band: int = MarketPricer.indicator_band(
		float(consensus) / float(base_li) if base_li > 0 else 0.0
	)
	var div_ppm: int = 0
	var div_band: int = DivergenceBand.LOW
	if n >= MIN_SAMPLES_FOR_TREND:
		var span: int = max_mid - min_mid
		var prod_div: Variant = _mul_checked(span, ppm)
		if prod_div == null:
			_record(ERR_SYS15_07, KEY_DIV_PPM, span, "divergence overflow")
			return {}
		var prod_div_i: int = _expect_int(prod_div, KEY_DIV_PPM)
		div_ppm = floori(float(prod_div_i) / float(consensus))
		var lo: int = Params.get_int(StringName(PRM_DIV_LO))
		var hi: int = Params.get_int(StringName(PRM_DIV_HI))
		if div_ppm <= lo:
			div_band = DivergenceBand.LOW
		elif div_ppm <= hi:
			div_band = DivergenceBand.MID
		else:
			div_band = DivergenceBand.HIGH
	var direction: StringName = _direction_of(samples, ppm)
	return {
		KEY_N: n,
		KEY_CONSENSUS_MID: consensus,
		KEY_BAND: band,
		KEY_CONSENSUS_WEEKS: consensus_weeks,
		KEY_MEAN_AGE: mean_age,
		KEY_NEWEST_AGE: newest_age,
		KEY_DIV_PPM: div_ppm,
		KEY_DIV_BAND: div_band,
		KEY_DIRECTION: direction,
	}


func _direction_of(samples: Array, ppm: int) -> StringName:
	## FRM-SYS15-05.
	if samples.size() < MIN_SAMPLES_FOR_TREND:
		return DIR_NONE
	var ordered: Array = samples.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = _dict_int(a, KEY_DAY_TAKEN, 0)
		var db: int = _dict_int(b, KEY_DAY_TAKEN, 0)
		if da != db:
			return da > db
		var ta: int = _dict_int(a, KEY_TICK_TAKEN, 0)
		var tb: int = _dict_int(b, KEY_TICK_TAKEN, 0)
		if ta != tb:
			return ta > tb
		return String(a[KEY_SHIP_ID]) < String(b[KEY_SHIP_ID])
	)
	var newest: Dictionary = ordered[0]
	var rest: Array = ordered.slice(1)
	var decay_d: int = Params.get_int(StringName(PRM_DECAY_DAYS))
	var sum_w: int = 0
	var sum_wm: int = 0
	for s_variant in rest:
		var s: Dictionary = s_variant
		var age: int = _dict_int(s, KEY_AGE_DAYS, 0)
		var w: int = decay_d - age
		var mid: int = _dict_int(s, KEY_MID_LI, 0)
		var prod: Variant = _mul_checked(w, mid)
		if prod == null:
			_record(ERR_SYS15_07, KEY_DIRECTION, mid, "direction rest overflow")
			return DIR_NONE
		var prod_i: int = _expect_int(prod, KEY_DIRECTION)
		if not _add_checked(sum_w, w) or not _add_checked(sum_wm, prod_i):
			_record(ERR_SYS15_07, KEY_DIRECTION, mid, "direction rest overflow")
			return DIR_NONE
		sum_w = sum_w + w
		sum_wm = sum_wm + prod_i
	if sum_w <= 0:
		return DIR_NONE
	var rest_mid: int = floori(float(sum_wm) / float(sum_w))
	var mid_n: int = _dict_int(newest, KEY_MID_LI, 0)
	var d: int = mid_n - rest_mid
	var abs_d: int = d if d >= 0 else 0 - d
	var deadband: int = Params.get_int(StringName(PRM_DEADBAND))
	var left: Variant = _mul_checked(abs_d, ppm)
	var right: Variant = _mul_checked(deadband, rest_mid)
	if left == null or right == null:
		_record(ERR_SYS15_07, KEY_DIRECTION, d, "direction deadband overflow")
		return DIR_NONE
	var left_i: int = _expect_int(left, KEY_DIRECTION)
	var right_i: int = _expect_int(right, KEY_DIRECTION)
	if left_i <= right_i:
		return DIR_FLAT
	if d > 0:
		return DIR_UP
	if d < 0:
		return DIR_DOWN
	return DIR_FLAT


func _mul_checked(a: int, b: int) -> Variant:
	## C-10: detect int64 wrap without magic INT64_MAX literal.
	## Returns int（TYPE_INT）or null — never float（C-09）.
	if a == 0 or b == 0:
		return 0
	var p: int = a * b
	if p / a != b:
		return null
	return p


func _add_checked(a: int, b: int) -> bool:
	if b == 0:
		return true
	if b > 0:
		return a <= a + b
	return a >= a + b


func _expect_int(v: Variant, field: String) -> int:
	## C-09: reject float→int coercion；only accept already-integer Variants.
	if typeof(v) != TYPE_INT:
		_record(ERR_SYS15_07, field, v, "non-int where int required (C-09)")
		return 0
	return v


func _dict_int(d: Dictionary, key: String, default_v: int) -> int:
	## C-09: Dictionary values written as int／null only；prove TYPE_INT before use.
	if not d.has(key):
		return default_v
	var v: Variant = d[key]
	if typeof(v) != TYPE_INT:
		_record(ERR_SYS15_07, key, v, "non-int dict value (C-09)")
		return default_v
	return v


class _ObserverAdapter extends ShipEventObserver:
	var host: Node = null

	func on_departed(
		ship_id: StringName, owner_id: StringName, from_port_id: StringName, tick: int
	) -> void:
		if host != null:
			host.call("on_departed", ship_id, owner_id, from_port_id, tick)

	func on_arrivals(tick: int, arrivals: Array) -> void:
		if host != null:
			host.call("on_arrivals", tick, arrivals)
