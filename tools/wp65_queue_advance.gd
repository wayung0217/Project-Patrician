extends SceneTree
## WP-65／C3 (17-52): formal boot, **no** cash/material inject, 2y queue probe.
## Per-port: steps reached, stuck step, reason (slot／prereq／cash／materials／done).
## Expect: no port stuck on missing public slot or missing prereq building.
## Usage: godot --headless --path . -s res://tools/wp65_queue_advance.gd


const SCENARIO_PATH := "res://docs/spec/scenario_L1_baseline.json"
const YEARS := 2


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var boot: Dictionary = _boot_formal()
	if not bool(boot.get("ok")):
		push_error("WP65_QUEUE boot failed: %s" % str(boot.get("errors")))
		quit(2)
		return
	var root: Window = get_root()
	var params: Node = root.get_node("Params")
	var be: Node = root.get_node("BuildingEconomy")
	var sim_loop: Node = root.get_node("SimLoop")
	var cash: Node = root.get_node("CashLedger")

	var days_d: int = int(params.call("get_int", "PRM-SYS00-DAYS_PER_SEASON"))
	var seasons_y: int = int(params.call("get_int", "PRM-SYS00-SEASONS_PER_YEAR"))
	var total_days: int = YEARS * seasons_y * days_d
	print("WP65_QUEUE years=%d days=%d inject=none" % [YEARS, total_days])

	var queue_by: Dictionary = be.get("_queue_by_port")
	var queue_pos: Dictionary = be.get("_queue_pos")
	var ports: Array = queue_by.keys()
	ports.sort()
	print("WP65_QUEUE_BEFORE")
	for pid_v in ports:
		var pid: String = String(pid_v)
		var steps: int = (queue_by.get(pid, []) as Array).size()
		var pos: int = int(queue_pos.get(pid, 0))
		print("port=%s steps=%d pos=%d" % [pid, steps, pos])

	for _d in range(total_days):
		sim_loop.call("tick_day")

	queue_by = be.get("_queue_by_port")
	queue_pos = be.get("_queue_pos")
	print("WP65_QUEUE_AFTER")
	var stuck_slot := 0
	var stuck_prereq := 0
	var stuck_cash := 0
	var stuck_mats := 0
	var stuck_other := 0
	for pid_v2 in ports:
		var pid2: String = String(pid_v2)
		var steps_arr: Array = queue_by.get(pid2, []) as Array
		var steps2: int = steps_arr.size()
		var pos2: int = int(queue_pos.get(pid2, 0))
		var reason := "done"
		var stuck_step := -1
		if pos2 < steps2:
			stuck_step = pos2
			reason = _stuck_reason(be, cash, pid2, steps_arr, pos2)
			match reason:
				"slot":
					stuck_slot += 1
				"prereq":
					stuck_prereq += 1
				"cash":
					stuck_cash += 1
				"materials":
					stuck_mats += 1
				_:
					stuck_other += 1
		print(
			(
				"port=%s steps=%d pos=%d advanced=%d stuck_step=%d reason=%s"
				% [pid2, steps2, pos2, pos2, stuck_step, reason]
			)
		)
	print(
		(
			"WP65_QUEUE stuck_slot=%d stuck_prereq=%d stuck_cash=%d stuck_materials=%d stuck_other=%d"
			% [stuck_slot, stuck_prereq, stuck_cash, stuck_mats, stuck_other]
		)
	)
	## C3 rewrite (17-52): new build_queue.csv → expect no slot／prereq stuck.
	if stuck_slot > 0 or stuck_prereq > 0:
		push_error(
			"WP65_QUEUE FAIL: slot/prereq stuck (slot=%d prereq=%d)" % [stuck_slot, stuck_prereq]
		)
		quit(1)
		return
	print("WP65_QUEUE OK")
	quit(0)


func _stuck_reason(be: Node, cash: Node, port_id: String, steps: Array, pos: int) -> String:
	if pos < 0 or pos >= steps.size():
		return "other"
	var step: Object = steps[pos]
	if step == null:
		return "other"
	var target_level: int = int(step.get("target_level"))
	var cb: StringName = StringName(String(step.get("cb_id")))
	var city: StringName = cash.call("make_city_id", port_id)
	var params: Node = get_root().get_node("Params")
	var cost: int = 0
	if target_level <= 1:
		var cash_map: Dictionary = params.call("get_value", "PRM-SYS08-BUILD_CASH_LI")
		cost = int(cash_map.get("PUBLIC", 0))
		var slot_id: StringName = be.call("_find_public_slot", port_id)
		if slot_id == &"":
			return "slot"
		if int(cash.call("balance", city)) < cost:
			return "cash"
		## Cash+slot OK but still stuck → materials／order_build fail.
		return "materials"
	## Upgrade path.
	cost = int(be.call("_public_upgrade_cash", port_id, target_level))
	if cost < 0:
		return "other"
	var need_level: int = target_level - 1
	var found_active: Variant = be.call(
		"_find_city_public_upgrade_target", port_id, city, cb, need_level
	)
	if found_active != null:
		if int(cash.call("balance", city)) < cost:
			return "cash"
		return "materials"
	## No ACTIVE target: distinguish missing building vs still constructing.
	var any_match := false
	var buildings: Array = be.get("_buildings_by_port").get(port_id, [])
	for bld_v in buildings:
		var bld: Object = bld_v
		if bld == null:
			continue
		if bld.get("owner") != city:
			continue
		if String(bld.get("build_class")) != "PUBLIC":
			continue
		var bcb: StringName = bld.get("cb_id")
		var btype: StringName = bld.get("type")
		if bcb != cb and btype != cb:
			continue
		if int(bld.get("level")) != need_level:
			continue
		any_match = true
		break
	if not any_match:
		return "prereq"
	## Exists but not ACTIVE → waiting on construction／materials.
	if int(cash.call("balance", city)) < cost:
		return "cash"
	return "materials"


func _boot_formal() -> Dictionary:
	var root: Window = get_root()
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var scen: Dictionary = JSON.parse_string(raw)
	var overrides: Dictionary = scen.get("overrides", {})
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merged_path := "user://sim_merged/wp65_queue.json"
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
