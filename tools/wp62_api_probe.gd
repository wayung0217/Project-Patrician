extends SceneTree
## S9h probe for WP-62 D-95(d) APIs (golden v2 columns unchanged by UI／export／API surface).
## godot --headless --path . -s res://tools/wp62_api_probe.gd


var _started: bool = false


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	print("WP62_PROBE_START")
	var desk: Node = get_root().get_node("TradeDesk")
	var lanes: Node = get_root().get_node("SeaLanes")
	var goods: Node = get_root().get_node("GoodsLedger")
	print("PROBE last_trade_total_li_boot=", desk.call("last_trade_total_li"))
	desk.set("_last_trade_total_li", 12345)
	print("PROBE last_trade_total_li_set=", desk.call("last_trade_total_li"))
	desk.call("_clear_state")
	print("PROBE last_trade_total_li_after_clear=", desk.call("last_trade_total_li"))

	lanes.set("_loaded", true)
	lanes.set("_lane_ids_sorted", PackedStringArray(["LN-01", "LN-09", "LN-10"]))
	var ids: Array = lanes.call("lane_ids")
	var joined: PackedStringArray = PackedStringArray()
	for lid in ids:
		joined.append(String(lid))
	print("PROBE lane_ids=", ",".join(joined))
	lanes.set("_loaded", false)

	print("PROBE has_container_used=", goods.has_method("container_used"))
	print("PROBE has_lane_ids=", lanes.has_method("lane_ids"))
	print("PROBE has_last_trade_total_li=", desk.has_method("last_trade_total_li"))
	print("WP62_PROBE_DONE")
	quit(0)
