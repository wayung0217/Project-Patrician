extends Node
## Autoload: TradeDesk — SYS-05 unique trade entry (03_Systems 20.1 / WP-33).
## _ready() only clears fields; load_and_validate() + injection via SimLoop.boot (2.2-01).
## D-26b／D-28d／D-33b／D-39b／D-42: QualificationProvider + ordered TradeObserver list.
## CONFISCATED sell-back exception is WP-38 — not in this package.

signal trade_executed(
	actor_id: StringName,
	port_id: StringName,
	good_id: StringName,
	side: int,
	qty: int,
	total_li: int,
	seq: int
)

const SYS_ID := &"SYS-05"
const SCRIPT_PATH := "res://autoload/trade_desk.gd"

const REQUESTER_SYS04 := &"SYS-04"
const REASON_TRADE := &"TRADE"

const ERR_SYS05_01 := &"ERR-SYS05-01"
const ERR_SYS05_04 := &"ERR-SYS05-04"
const ERR_SYS05_05 := &"ERR-SYS05-05"
const ERR_SYS05_07 := &"ERR-SYS05-07"
const ERR_SYS05_10 := &"ERR-SYS05-10"
const ERR_SYS05_11 := &"ERR-SYS05-11"
const ERR_SYS05_12 := &"ERR-SYS05-12"
const ERR_SYS05_13 := &"ERR-SYS05-13"
const ERR_SYS05_14 := &"ERR-SYS05-14"

const FIELD_PROVIDER := "qualification_provider"
const FIELD_OBSERVERS := "trade_observers"
const FIELD_SIDE := "side"
const FIELD_QTY := "qty"
const FIELD_ACTOR := "actor_id"
const FIELD_CONTAINER := "container_id"
const FIELD_PORT := "port_id"

## Pending D-05 signals flushed by SimLoop at day-end step 6.
var _pending_signals: Array = [] ## {actor,port,good,side,qty,total_li,seq}
## Observer failures collected for SimLoop day_errors (do not roll back trade).
var _day_errors: Array = []

var _qualification: QualificationProvider = null
## Ordered list (D-33b／D-42 formal: ReputationLedger then TaxLedger).
var _observers: Array = [] ## Array[TradeObserver]
var _last_error: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	_clear_state()


func load_and_validate() -> Array:
	# 2.2-01／2.2-02: runtime field init; keep injected providers (mirror BuildingEconomy).
	# Provider／observer gates collected by SimLoop.boot via boot_gate_errors().
	var errors: Array = []
	_pending_signals = []
	_day_errors = []
	_last_error = {}
	_loaded = true
	return errors


func is_loaded() -> bool:
	return _loaded


func mark_unloaded() -> void:
	## D-89b 待追認: allow sim to re-inject providers after a prior boot (was _loaded=false write).
	_loaded = false


func last_error() -> Dictionary:
	return _last_error.duplicate(true)


func set_qualification_provider(provider: QualificationProvider) -> void:
	## Inject before SimLoop.boot; tests use fixtures (N-05). Ignored after load.
	if _loaded:
		push_error("TradeDesk.set_qualification_provider called after load; ignored")
		return
	_qualification = provider


func has_qualification_provider() -> bool:
	return _qualification != null


func set_trade_observers(observers: Array) -> void:
	## Ordered TradeObserver list (D-33b／D-42). Formal: [ReputationLedger, TaxLedger].
	if _loaded:
		push_error("TradeDesk.set_trade_observers called after load; ignored")
		return
	_observers = []
	for o in observers:
		_observers.append(o)


func has_trade_observers() -> bool:
	return not _observers.is_empty()


func trade_observer_count() -> int:
	return _observers.size()


func take_day_errors() -> Array:
	## SimLoop.tick_day appends these into the day error list (C-06).
	var out: Array = _day_errors
	_day_errors = []
	return out


func flush_signals() -> void:
	## D-05: emit trade_executed only after all same-day writes (SimLoop step 6).
	var batch: Array = _pending_signals
	_pending_signals = []
	for item_variant in batch:
		var item: Dictionary = item_variant
		trade_executed.emit(
			item["actor"],
			item["port"],
			item["good"],
			int(item["side"]),
			int(item["qty"]),
			int(item["total_li"]),
			int(item["seq"])
		)


func execute_trade(
	actor_id: StringName,
	container_id: StringName,
	port_id: StringName,
	good_id: StringName,
	side: int,
	qty: Variant,
	preview_total_li: int
) -> int:
	## FRM-SYS05-13: unique trade entry. Success → transfer seq ≥ 1; fail → 0 + last_error.
	assert(_loaded, "TradeDesk.execute_trade before load_and_validate")
	_clear_last_error()

	# --- (0) Pre-validation: any failure leaves all state untouched ---
	# (0)(a) side ∈ {BUY, SELL}; qty integer > 0 (ERR-SYS05-05)
	if side != MarketPricer.SIDE_BUY and side != MarketPricer.SIDE_SELL:
		return _fail(ERR_SYS05_05, FIELD_SIDE, side, "side must be BUY or SELL")
	if not _is_positive_int(qty):
		return _fail(ERR_SYS05_05, FIELD_QTY, qty, "qty must be integer > 0")
	var qty_i: int = int(qty)

	# (0)(b) actor account exists (ERR-SYS05-04)
	if not CashLedger.has_account(actor_id):
		return _fail(ERR_SYS05_04, FIELD_ACTOR, actor_id, "actor account missing")

	# (0)(c)(d) container registration／kind／owner／port／dock (FRM-SYS05-14; no id parse)
	# CONFISCATED sell-back is WP-38 — not accepted here.
	if not GoodsLedger.is_container_registered(container_id):
		return _fail(ERR_SYS05_10, FIELD_CONTAINER, container_id, "container not registered")
	var kind: StringName = GoodsLedger.get_container_kind(container_id)
	if kind != StringName(GoodsLedger.KIND_WAREHOUSE) and kind != StringName(GoodsLedger.KIND_HOLD):
		return _fail(ERR_SYS05_10, FIELD_CONTAINER, kind, "container kind must be WAREHOUSE or HOLD")
	var owner_id: StringName = GoodsLedger.get_container_owner_id(container_id)
	if owner_id != actor_id:
		return _fail(ERR_SYS05_10, FIELD_CONTAINER, container_id, "container owner_id != actor_id")
	if kind == StringName(GoodsLedger.KIND_WAREHOUSE):
		var wh_port: StringName = GoodsLedger.get_container_port_id(container_id)
		if wh_port != port_id:
			return _fail(
				ERR_SYS05_10, FIELD_PORT, wh_port, "WAREHOUSE port_id != trade port_id"
			)
	else:
		var ship_id: StringName = GoodsLedger.get_container_ship_id(container_id)
		if ship_id.is_empty() or not ShipRegistry.can_trade(ship_id, port_id):
			return _fail(ERR_SYS05_11, FIELD_PORT, port_id, "HOLD not docked at trade port")

	var container: Dictionary = GoodsLedger.container_dict(container_id)
	if container.is_empty():
		return _fail(ERR_SYS05_10, FIELD_CONTAINER, container_id, "container registry incomplete")

	# (0)(e) qualification (propagate provider ErrorInfo: ERR-SYS09-08／09)
	if _qualification == null:
		return _fail(
			ERR_SYS05_12, FIELD_PROVIDER, null, "QualificationProvider not injected"
		)
	if not _qualification.can_enter(actor_id, port_id):
		_last_error = _qualification.last_error().duplicate(true)
		if _last_error.is_empty():
			_last_error = ErrorInfoUtil.make_validation(
				QualificationProvider.ERR_SYS09_08,
				SYS_ID,
				SCRIPT_PATH,
				FIELD_PORT,
				port_id,
				"can_enter denied"
			)
		push_error("TradeDesk: %s" % str(_last_error))
		return 0
	if not _qualification.can_trade(actor_id, port_id, good_id, side):
		_last_error = _qualification.last_error().duplicate(true)
		if _last_error.is_empty():
			_last_error = ErrorInfoUtil.make_validation(
				QualificationProvider.ERR_SYS09_09,
				SYS_ID,
				SCRIPT_PATH,
				"good_id",
				good_id,
				"can_trade denied"
			)
		push_error("TradeDesk: %s" % str(_last_error))
		return 0

	# D-28d: mid_before before quote (step 2)
	var mid_before: float = MarketPricer.mid_price(port_id, good_id)

	# --- (1) Requester = SYS-04 (fixed); amounts validated after quote ---
	# --- (2) quote at submit time ---
	var quote: Dictionary = MarketPricer.quote(port_id, good_id, side, qty_i)
	if quote.has(MarketPricer.KEY_ERROR):
		var q_err: Variant = quote[MarketPricer.KEY_ERROR]
		_last_error = ErrorInfoUtil.make_validation(
			StringName(str(q_err)),
			SYS_ID,
			SCRIPT_PATH,
			FIELD_QTY,
			qty_i,
			"MarketPricer.quote failed"
		)
		# Prefer MarketPricer.last_error when present.
		var mp_err: Dictionary = MarketPricer.last_error()
		if not mp_err.is_empty():
			_last_error = mp_err.duplicate(true)
		push_error("TradeDesk: %s" % str(_last_error))
		return 0

	var total_li: int = int(quote[MarketPricer.KEY_TOTAL_LI])
	if total_li <= 0:
		return _fail(ERR_SYS05_05, "total_li", total_li, "quote total_li must be positive int")
	var mid_after: float = float(quote[MarketPricer.KEY_MID_AFTER])

	# --- (3) FRM-SYS05-11 revalidate (BUY only) ---
	if side == MarketPricer.SIDE_BUY:
		var bal: int = CashLedger.balance(actor_id)
		if total_li > bal:
			if preview_total_li > 0:
				return _fail(
					ERR_SYS05_07,
					"preview_total_li",
					preview_total_li,
					"new quote exceeds balance (stale preview)"
				)
			return _fail(ERR_SYS05_01, "balance", bal, "insufficient funds (no preview)")

	# --- (4) Build entries + FRM-SYS05-01 sum-zero ---
	var entries: Array = []
	if side == MarketPricer.SIDE_BUY:
		entries = [
			CashLedger.make_entry(actor_id, 0 - total_li),
			CashLedger.make_entry(CashLedger.ID_SINK, total_li),
		]
	else:
		entries = [
			CashLedger.make_entry(CashLedger.ID_SOURCE, 0 - total_li),
			CashLedger.make_entry(actor_id, total_li),
		]

	var market: Dictionary = GoodsLedger.make_market(String(port_id))
	var from_c: Dictionary
	var to_c: Dictionary
	if side == MarketPricer.SIDE_BUY:
		from_c = market
		to_c = container
	else:
		from_c = container
		to_c = market

	# --- (4.5) D-39b: can_transfer before cash post ---
	if not GoodsLedger.can_transfer(
		from_c, to_c, good_id, qty_i, GoodsLedger.REASON_TRADE, REQUESTER_SYS04
	):
		_last_error = GoodsLedger.last_error().duplicate(true)
		push_error("TradeDesk: can_transfer failed: %s" % str(_last_error))
		return 0

	# --- (5) CashLedger.post (reason = TRADE, requester = SYS-04) ---
	var cash_rc: Error = CashLedger.post(entries, REASON_TRADE, REQUESTER_SYS04)
	if cash_rc != OK:
		_last_error = CashLedger.last_error().duplicate(true)
		push_error("TradeDesk: CashLedger.post failed: %s" % str(_last_error))
		return 0

	# --- (6) GoodsLedger.transfer; on failure reverse step 5 (backup; ERR-SYS05-13) ---
	var seq: int = GoodsLedger.transfer(
		from_c, to_c, good_id, qty_i, GoodsLedger.REASON_TRADE, REQUESTER_SYS04
	)
	if seq <= 0:
		var goods_err: Dictionary = GoodsLedger.last_error().duplicate(true)
		var reverse_ok: bool = _reverse_cash_post(actor_id, side, total_li)
		if not reverse_ok:
			return _fail(
				ERR_SYS05_13,
				"rollback",
				goods_err,
				"transfer failed and cash rollback failed"
			)
		_last_error = goods_err
		push_error("TradeDesk: transfer failed after post; cash rolled back: %s" % str(_last_error))
		return 0

	# --- (7) Notify observers (failure does not roll back); queue signal ---
	for obs_variant in _observers:
		var obs: TradeObserver = obs_variant as TradeObserver
		if obs == null:
			_day_errors.append(
				ErrorInfoUtil.make_validation(
					ERR_SYS05_14,
					SYS_ID,
					SCRIPT_PATH,
					FIELD_OBSERVERS,
					null,
					"observer list entry is not TradeObserver"
				)
			)
			continue
		var obs_rc: int = obs.record_trade(
			actor_id, port_id, good_id, side, qty_i, mid_before, mid_after, seq
		)
		if obs_rc != TradeObserver.RECORD_OK:
			_day_errors.append(
				ErrorInfoUtil.make_validation(
					&"ERR-TRADE-OBSERVER-FAIL",
					SYS_ID,
					SCRIPT_PATH,
					FIELD_OBSERVERS,
					obs_rc,
					"TradeObserver.record_trade failed (trade kept)"
				)
			)

	_pending_signals.append({
		"actor": actor_id,
		"port": port_id,
		"good": good_id,
		"side": side,
		"qty": qty_i,
		"total_li": total_li,
		"seq": seq,
	})
	_clear_last_error()
	return seq


func boot_gate_errors() -> Array:
	## SimLoop.boot collects these (C-06); empty when fixtures／formal providers injected.
	var errors: Array = []
	if _qualification == null:
		var e12 := {
			"code": ERR_SYS05_12,
			"file": SCRIPT_PATH,
			"field": FIELD_PROVIDER,
			"value": null,
			"message": "QualificationProvider must be injected before boot (ERR-SYS05-12)",
		}
		errors.append(e12)
		push_error("TradeDesk: %s" % str(e12))
	if _observers.is_empty():
		var e14 := {
			"code": ERR_SYS05_14,
			"file": SCRIPT_PATH,
			"field": FIELD_OBSERVERS,
			"value": null,
			"message": "TradeObserver list must be injected before boot (ERR-SYS05-14)",
		}
		errors.append(e14)
		push_error("TradeDesk: %s" % str(e14))
	return errors


func _reverse_cash_post(actor_id: StringName, side: int, total_li: int) -> bool:
	## D-39b backup: reverse BUY／SELL legs after transfer failure.
	var reverse: Array = []
	if side == MarketPricer.SIDE_BUY:
		reverse = [
			CashLedger.make_entry(actor_id, total_li),
			CashLedger.make_entry(CashLedger.ID_SINK, 0 - total_li),
		]
	else:
		reverse = [
			CashLedger.make_entry(CashLedger.ID_SOURCE, total_li),
			CashLedger.make_entry(actor_id, 0 - total_li),
		]
	var rc: Error = CashLedger.post(reverse, REASON_TRADE, REQUESTER_SYS04)
	return rc == OK


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


func _clear_state() -> void:
	_qualification = null
	_observers = []
	_pending_signals = []
	_day_errors = []
	_last_error = {}
	_loaded = false


func _clear_last_error() -> void:
	_last_error = {}


func _fail(code: StringName, field: String, value: Variant, message: String) -> int:
	_last_error = ErrorInfoUtil.make_validation(
		code, SYS_ID, SCRIPT_PATH, field, value, message
	)
	push_error("TradeDesk: %s" % str(_last_error))
	return 0
