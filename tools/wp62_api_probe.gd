extends SceneTree
## S9h／D-111(f)／F5: probe WP-62 D-95(d) public APIs only (C-07 — no set() on _ members).
## godot --headless --path . -s res://tools/wp62_api_probe.gd


const SCENARIO_PATH := "res://docs/spec/scenario_L1_baseline.json"


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
	print("PROBE has_container_used=", goods.has_method("container_used"))
	print("PROBE has_lane_ids=", lanes.has_method("lane_ids"))
	print("PROBE has_last_trade_total_li=", desk.has_method("last_trade_total_li"))

	var boot: Dictionary = _boot_formal()
	if not bool(boot.get("ok")):
		push_error("WP62_PROBE boot failed: %s" % str(boot.get("errors")))
		quit(2)
		return

	print("PROBE last_trade_total_li_boot=", desk.call("last_trade_total_li"))
	var ids: Array = lanes.call("lane_ids")
	var joined: PackedStringArray = PackedStringArray()
	for lid in ids:
		joined.append(String(lid))
	print("PROBE lane_ids_count=", ids.size())
	print("PROBE lane_ids_sample=", ",".join(joined.slice(0, mini(3, joined.size()))))

	var ports: PackedStringArray = get_root().get_node("PortRegistry").call("all_ids")
	if ports.size() > 0:
		var mkt: Dictionary = goods.call("make_market", String(ports[0]))
		print("PROBE container_used=", goods.call("container_used", mkt))
	print("WP62_PROBE_DONE")
	quit(0)


func _boot_formal() -> Dictionary:
	var root: Window = get_root()
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var scen: Dictionary = JSON.parse_string(raw)
	var overrides: Dictionary = scen.get("overrides", {})
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merged_path := "user://sim_merged/wp62_api_probe.json"
	var merge_res: Dictionary = merge_gds.call(
		"merge_to_user", "res://data/params/params.json", overrides, {}, merged_path
	)
	if not bool(merge_res.get("ok")):
		return {"ok": false, "errors": merge_res.get("errors", [])}
	var sim_loop: Node = root.get_node_or_null("SimLoop")
	var intel: Node = root.get_node_or_null("IntelLedger")
	if intel != null and not bool(intel.call("has_broker_provider")):
		intel.call("set_broker_provider", load("res://sim/sim_broker_fixture.gd").new())
	var trade_desk: Node = root.get_node_or_null("TradeDesk")
	if trade_desk != null:
		if not bool(trade_desk.call("has_qualification_provider")):
			trade_desk.call(
				"set_qualification_provider", load("res://sim/sim_qualification_fixture.gd").new()
			)
		if not bool(trade_desk.call("has_trade_observers")):
			trade_desk.call(
				"set_trade_observers", [load("res://sim/sim_trade_observer_fixture.gd").new()]
			)
	var boot_errors: Array = sim_loop.call(
		"boot",
		String(merge_res["path"]),
		"res://data/goods/",
		"res://data/ports/",
		"res://data/market/price_curve.tres",
		"res://data/sea/nodes/",
		"res://data/sea/regions/",
		"res://data/sea/lanes/",
		"res://data/demand/"
	)
	return {
		"ok": boot_errors.is_empty() and bool(sim_loop.call("is_booted")),
		"errors": boot_errors,
	}
