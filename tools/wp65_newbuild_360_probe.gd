extends SceneTree
## D-111(b) blind-2: formal 360d — list each city-queue new-build (port_id, cb_id, day).
## Public APIs only (buildings_for_port / get_building_def / city_queue_position).
## Usage: godot --headless --path . -s res://tools/wp65_newbuild_360_probe.gd -- --days 360


const SCENARIO_PATH := "res://docs/spec/scenario_L1_baseline.json"
const DEFAULT_DAYS := 360


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var days: int = DEFAULT_DAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if String(args[i]) == "--days" and i + 1 < args.size():
			days = int(args[i + 1])
	var boot: Dictionary = _boot_formal()
	if not bool(boot.get("ok")):
		push_error("WP65_NEWBUILD boot failed: %s" % str(boot.get("errors")))
		quit(2)
		return
	var root: Window = get_root()
	var sim_loop: Node = root.get_node("SimLoop")
	var clock: Node = root.get_node("Clock")
	var be: Node = root.get_node("BuildingEconomy")
	var ports: PackedStringArray = root.get_node("PortRegistry").call("all_ids")
	ports.sort()
	var seen_ids: Dictionary = {}
	for pid_v in ports:
		for b_v in be.call("buildings_for_port", String(pid_v)):
			seen_ids[String(b_v.get("building_id"))] = true
	print("WP65_NEWBUILD_PROBE days=%d" % days)
	var listed := 0
	for d in range(1, days + 1):
		sim_loop.call("tick_day")
		var day_n: int = int(clock.get("day")) if clock != null else d
		for pid_v2 in ports:
			var pid2: String = String(pid_v2)
			for b_v2 in be.call("buildings_for_port", pid2):
				var b: Object = b_v2
				var bid: String = String(b.get("building_id"))
				if seen_ids.has(bid):
					continue
				seen_ids[bid] = true
				## City PUBLIC new-build: level 1, has cb_id, CITY owner.
				if int(b.get("level")) != 1:
					continue
				var cb: String = String(b.get("cb_id"))
				if cb.is_empty():
					cb = String(b.get("type"))
				if not cb.begins_with("CB-"):
					continue
				var def: Object = be.call("get_building_def", StringName(cb))
				if def == null:
					push_error(
						"WP65_NEWBUILD missing BuildingDef port=%s cb=%s day=%d" % [pid2, cb, day_n]
					)
					quit(1)
					return
				print(
					"WP65_NEWBUILD port=%s cb=%s day=%d def_class=%s building_id=%s"
					% [pid2, cb, day_n, String(def.get("build_class")), bid]
				)
				listed += 1
	print("WP65_NEWBUILD_TOTAL %d" % listed)
	print("WP65_NEWBUILD_OK")
	quit(0)


func _boot_formal() -> Dictionary:
	var root: Window = get_root()
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var scen: Dictionary = JSON.parse_string(raw)
	var overrides: Dictionary = scen.get("overrides", {})
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merged_path := "user://sim_merged/wp65_newbuild.json"
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
