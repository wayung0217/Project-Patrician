class_name SimTransferAcc
extends RefCounted
## D-47b — accumulate produced/consumed via GoodsLedger.goods_transferred (layer 1).
## WP-27: relocated_in／out via note_relocate (SIM_RELOCATE). Does not read private ledger state.


var _produced: Dictionary = {} ## "port|good" -> int
var _consumed: Dictionary = {}
var _relocated_in: Dictionary = {}
var _relocated_out: Dictionary = {}
var _connected: bool = false


func connect_ledger() -> void:
	if _connected:
		return
	if not GoodsLedger.goods_transferred.is_connected(_on_transferred):
		GoodsLedger.goods_transferred.connect(_on_transferred)
	_connected = true


func disconnect_ledger() -> void:
	if _connected and GoodsLedger.goods_transferred.is_connected(_on_transferred):
		GoodsLedger.goods_transferred.disconnect(_on_transferred)
	_connected = false


func clear() -> void:
	_produced.clear()
	_consumed.clear()
	_relocated_in.clear()
	_relocated_out.clear()


func produced(port_id: String, good_id: String) -> int:
	## 甲：map 值為本類寫入的 int；非整數拒絕（C-06）。
	var v: Variant = _produced.get(_key(port_id, good_id), 0)
	return SimJsonInt.as_int(v, "produced")


func consumed(port_id: String, good_id: String) -> int:
	## 甲：map 值為本類寫入的 int；非整數拒絕（C-06）。
	var v: Variant = _consumed.get(_key(port_id, good_id), 0)
	return SimJsonInt.as_int(v, "consumed")


func relocated_in(port_id: String, good_id: String) -> int:
	var v: Variant = _relocated_in.get(_key(port_id, good_id), 0)
	return SimJsonInt.as_int(v, "relocated_in")


func relocated_out(port_id: String, good_id: String) -> int:
	var v: Variant = _relocated_out.get(_key(port_id, good_id), 0)
	return SimJsonInt.as_int(v, "relocated_out")


func note_relocate(from_port: String, to_port: String, good_id: String, qty: int) -> void:
	## WP-27: called by SimRelocator after successful SIM_RELOCATE transfer.
	if qty <= 0:
		return
	_add(_relocated_out, from_port, good_id, qty)
	_add(_relocated_in, to_port, good_id, qty)


func take_season_produced(port_id: String, good_id: String) -> int:
	## Read current season total (caller may clear after sample).
	return produced(port_id, good_id)


func reset_counters() -> void:
	clear()


func _on_transferred(event: TransferEvent) -> void:
	var reason: StringName = event.reason
	var good_s: String = String(event.good_id)
	## 甲：TransferEvent.qty 為 int。
	var qty: int = event.qty
	if reason == GoodsLedger.REASON_PRODUCE or reason == GoodsLedger.REASON_GENESIS:
		var to_port: String = _port_of(event.to)
		if not to_port.is_empty():
			_add(_produced, to_port, good_s, qty)
	elif reason == GoodsLedger.REASON_CONSUME or reason == GoodsLedger.REASON_CONSTRUCT_USE:
		var from_port: String = _port_of(event.from)
		if not from_port.is_empty():
			_add(_consumed, from_port, good_s, qty)
	## SIM_RELOCATE counted via note_relocate (avoids double-count if signal also fires).


func _port_of(container: Variant) -> String:
	if typeof(container) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = container
	if String(d.get(GoodsLedger.KEY_KIND, "")) != GoodsLedger.KIND_MARKET:
		return ""
	return String(d.get(GoodsLedger.KEY_PORT, ""))


func _add(map: Dictionary, port_id: String, good_id: String, qty: int) -> void:
	var k: String = _key(port_id, good_id)
	var prev: Variant = map.get(k, 0)
	## C-06：map 既有值非整數 → 報錯後以 0 起算（不靜默 floori）。
	var prev_i: int = SimJsonInt.as_int(prev, "transfer_acc.prev")
	map[k] = prev_i + qty


func _key(port_id: String, good_id: String) -> String:
	return "%s|%s" % [port_id, good_id]
