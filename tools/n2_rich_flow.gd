extends SceneTree
## N2 (17-52): L1 10y rich_flow diagnose — public queries only（FRM-SYS07-07／08）.
## Writes rich_flow.csv under user://n2_rich_flow/ and prints GAP lines for missing APIs.
## Usage: godot --headless --path . -s res://tools/n2_rich_flow.gd


const SCENARIO_PATH := "res://docs/spec/scenario_L1_baseline.json"
const OUT_DIR := "user://n2_rich_flow/"
const YEARS := 10
const CB_ACADEMY := &"CB-12"
const CB_GUILD := &"CB-13"


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var boot: Dictionary = _boot_formal()
	if not bool(boot.get("ok")):
		push_error("N2_RICH boot failed: %s" % str(boot.get("errors")))
		quit(2)
		return
	var root: Window = get_root()
	var params: Node = root.get_node("Params")
	var pop: Node = root.get_node("PopulationModel")
	var be: Node = root.get_node("BuildingEconomy")
	var sim_loop: Node = root.get_node("SimLoop")
	var ports_n: Node = root.get_node("PortRegistry")

	var days_d: int = int(params.call("get_int", "PRM-SYS00-DAYS_PER_SEASON"))
	var seasons_y: int = int(params.call("get_int", "PRM-SYS00-SEASONS_PER_YEAR"))
	var total_days: int = YEARS * seasons_y * days_d
	var up2_need: int = int(params.call("get_int", "PRM-SYS07-UP2_STREAK_DAYS"))
	var tier3_need: int = int(params.call("get_int", "PRM-SYS07-TIER3_MIN_ACTIVE"))
	print("N2_RICH years=%d days=%d UP2_STREAK=%d TIER3_MIN=%d" % [YEARS, total_days, up2_need, tier3_need])
	print("N2_GAP PF-3/PF-4 event counters: no public API（cannot count season PF-3／PF-4 moves without private PortPop.acc／_compute_flows）")
	print("N2_GAP PF-3 failed-condition itemization: inferred from public gates only（streak／tier3／academy／guild）")

	var abs_out: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_out)
	var path: String = OUT_DIR + "rich_flow.csv"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("N2_RICH cannot write %s" % path)
		quit(1)
		return
	f.store_line(
		"port_id,season_index,rich,citizen,season_max_streak_up2,UP2_STREAK_DAYS,active_tier3,TIER3_MIN_ACTIVE,academy_level,guildhall_level,season_pf3_count,season_pf4_count,pf3_failed_conditions"
	)

	var ports: PackedStringArray = ports_n.call("all_ids")
	ports.sort()
	## Per-port season max streak; prev rich for delta inference（gap-noted）.
	var max_streak: Dictionary = {}
	var prev_rich: Dictionary = {}
	var prev_cit: Dictionary = {}
	for pid_v in ports:
		max_streak[String(pid_v)] = 0
		prev_rich[String(pid_v)] = int(pop.call("population", StringName(String(pid_v)), &"RICH"))
		prev_cit[String(pid_v)] = int(pop.call("population", StringName(String(pid_v)), &"CITIZEN"))

	var day := 0
	var season_index := 0
	while day < total_days:
		sim_loop.call("tick_day")
		day += 1
		for pid_v2 in ports:
			var pid: String = String(pid_v2)
			var st: int = int(pop.call("get_upgrade_streak", pid, &"UP2"))
			if st > int(max_streak.get(pid, 0)):
				max_streak[pid] = st
		if day % days_d != 0:
			continue
		## Season boundary sample.
		for pid_v3 in ports:
			var pid3: String = String(pid_v3)
			var rich: int = int(pop.call("population", StringName(pid3), &"RICH"))
			var cit: int = int(pop.call("population", StringName(pid3), &"CITIZEN"))
			var streak_max: int = int(max_streak.get(pid3, 0))
			var tier3: int = _active_tier3(be, pop, pid3)
			var academy: int = int(be.call("public_level", StringName(pid3), CB_ACADEMY))
			var guild: int = int(be.call("public_level", StringName(pid3), CB_GUILD))
			## Infer PF counts from class deltas（gap: not true event counts）.
			var d_rich: int = rich - int(prev_rich.get(pid3, rich))
			var pf3_inf: int = maxi(0, d_rich)
			var pf4_inf: int = maxi(0, 0 - d_rich)
			var failed: String = _pf3_failed(
				streak_max, up2_need, tier3, tier3_need, academy, guild
			)
			f.store_line(
				"%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\""
				% [
					pid3,
					season_index,
					rich,
					cit,
					streak_max,
					up2_need,
					tier3,
					tier3_need,
					academy,
					guild,
					pf3_inf,
					pf4_inf,
					failed,
				]
			)
			prev_rich[pid3] = rich
			prev_cit[pid3] = cit
			max_streak[pid3] = int(pop.call("get_upgrade_streak", pid3, &"UP2"))
		season_index += 1

	f.close()
	print("N2_RICH wrote %s seasons=%d" % [path, season_index])
	print("N2_RICH OK")
	quit(0)


func _active_tier3(be: Node, pop: Node, port_id: String) -> int:
	## Rebuild _active_tier_workshops via public workplaces／defs／workers.
	var n := 0
	var wps: Array = be.call("workplaces", StringName(port_id))
	for bld_v in wps:
		var bld: Object = bld_v
		if bld == null:
			continue
		var def: Object = be.call("get_building_def", StringName(String(bld.get("type"))))
		if def == null:
			continue
		if int(def.get("tier")) != 3:
			continue
		if int(pop.call("workers", bld.get("building_id"))) >= 1:
			n += 1
	return n


func _pf3_failed(
	streak_max: int, up2_need: int, tier3: int, tier3_need: int, academy: int, guild: int
) -> String:
	var fails: PackedStringArray = PackedStringArray()
	if streak_max < up2_need:
		fails.append("streak_up2<%d" % up2_need)
	var academy_ok: bool = academy > 0 and guild > 0
	if tier3 < tier3_need and not academy_ok:
		fails.append("tier3<%d" % tier3_need)
		if academy <= 0:
			fails.append("academy_level=0")
		if guild <= 0:
			fails.append("guildhall_level=0")
	return ";".join(fails)


func _boot_formal() -> Dictionary:
	var root: Window = get_root()
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var scen: Dictionary = JSON.parse_string(raw)
	var overrides: Dictionary = scen.get("overrides", {})
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merged_path := "user://sim_merged/n2_rich.json"
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
