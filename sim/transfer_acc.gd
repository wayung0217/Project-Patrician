class_name SimTransferAcc
extends RefCounted
## D-47b — accumulate produced/consumed via GoodsLedger.goods_transferred (layer 1).
## relocated_in／out stay 0 (WP-27). Does not read private ledger state.


var _produced: Dictionary = {} ## "port|good" -> int
var _consumed: Dictionary = {}
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


func produced(port_id: String, good_id: String) -> int:
	return int(_produced.get(_key(port_id, good_id), 0))


func consumed(port_id: String, good_id: String) -> int:
	return int(_consumed.get(_key(port_id, good_id), 0))


func take_season_produced(port_id: String, good_id: String) -> int:
	## Read current season total (caller may clear after sample).
	return produced(port_id, good_id)


func reset_counters() -> void:
	clear()


func _on_transferred(event: TransferEvent) -> void:
	var reason: StringName = event.reason
	var good_s: String = String(event.good_id)
	var qty: int = int(event.qty)
	if reason == GoodsLedger.REASON_PRODUCE or reason == GoodsLedger.REASON_GENESIS:
		var to_port: String = _port_of(event.to)
		if not to_port.is_empty():
			_add(_produced, to_port, good_s, qty)
	elif reason == GoodsLedger.REASON_CONSUME or reason == GoodsLedger.REASON_CONSTRUCT_USE:
		var from_port: String = _port_of(event.from)
		if not from_port.is_empty():
			_add(_consumed, from_port, good_s, qty)


func _port_of(container: Variant) -> String:
	if typeof(container) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = container
	if String(d.get(GoodsLedger.KEY_KIND, "")) != GoodsLedger.KIND_MARKET:
		return ""
	return String(d.get(GoodsLedger.KEY_PORT, ""))


func _add(map: Dictionary, port_id: String, good_id: String, qty: int) -> void:
	var k: String = _key(port_id, good_id)
	map[k] = int(map.get(k, 0)) + qty


func _key(port_id: String, good_id: String) -> String:
	return "%s|%s" % [port_id, good_id]
