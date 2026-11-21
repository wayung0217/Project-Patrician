extends SceneTree
## After formal boot, tick N days and report ms/day (diagnostics for L1 runtime).


var _started: bool = false
const TICK_DAYS := 30


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	var root: Window = get_root()
	var scen: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/spec/scenario_L1_baseline.json")
	)
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merge_res: Dictionary = merge_gds.call(
		"merge_to_user",
		"res://data/params/params.json",
		scen.get("overrides", {}),
		{},
		"user://sim_merged/probe_l1_tick.json"
	)
	var sim_loop: Node = root.get_node("SimLoop")
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
	print("TICKRATE: is_booted=%s errs=%s" % [str(sim_loop.call("is_booted")), str(boot_errors.size())])
	if not boot_errors.is_empty():
		quit(1)
		return
	var clock: Node = root.get_node("Clock")
	clock.call("set_paused", false)
	var t0: int = Time.get_ticks_msec()
	for i in range(TICK_DAYS):
		sim_loop.call("tick_day")
		if (i + 1) % 10 == 0:
			var elapsed: int = Time.get_ticks_msec() - t0
			print("TICKRATE: after_days=%s elapsed_ms=%s ms_per_day=%s" % [
				str(i + 1), str(elapsed), str(float(elapsed) / float(i + 1))
			])
	var total: int = Time.get_ticks_msec() - t0
	var days_needed: int = 10 * 4 * 90 ## years * seasons * days
	print("TICKRATE: total_ms=%s ms_per_day=%s estimate_3600d_min=%s" % [
		str(total),
		str(float(total) / float(TICK_DAYS)),
		str(float(total) / float(TICK_DAYS) * float(days_needed) / 60000.0),
	])
	quit(0)
