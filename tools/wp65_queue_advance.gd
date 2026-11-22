extends SceneTree
## WP-65: formal boot → seed mats/cash → 2 years → per-port queue_pos.
## Usage: godot --headless --path . -s res://tools/wp65_queue_advance.gd


const SCENARIO_PATH := "res://docs/spec/scenario_L1_baseline.json"
const YEARS := 2
const FUND_LI := 200_000_000
const MAT_QTY := 50_000
const MAT_IDS: Array[String] = ["GD-003", "GD-004", "GD-021"]


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
	var ports_n: Node = root.get_node("PortRegistry")
	var cash: Node = root.get_node("CashLedger")
	var goods: Node = root.get_node("GoodsLedger")
	var catalog: Node = root.get_node("GoodCatalog")

	_seed_mats_and_cash(ports_n, cash, goods, catalog)
	var days_d: int = int(params.call("get_int", "PRM-SYS00-DAYS_PER_SEASON"))
	var seasons_y: int = int(params.call("get_int", "PRM-SYS00-SEASONS_PER_YEAR"))
	var total_days: int = YEARS * seasons_y * days_d
	print("WP65_QUEUE years=%d days=%d" % [YEARS, total_days])

	var queue_by: Dictionary = be.get("_queue_by_port")
	var queue_pos: Dictionary = be.get("_queue_pos")
	var ports: Array = queue_by.keys()
	ports.sort()
	print("WP65_QUEUE_BEFORE")
	for pid_v in ports:
		var pid: String = String(pid_v)
		var steps: int = (queue_by.get(pid, []) as Array).size()
		var pos: int = int(queue_pos.get(pid, 0))
		var first_up: int = _first_upgrade_step(queue_by, pid)
		print("port=%s steps=%d pos=%d first_upgrade_step=%d" % [pid, steps, pos, first_up])

	for _d in range(total_days):
		sim_loop.call("tick_day")

	queue_by = be.get("_queue_by_port")
	queue_pos = be.get("_queue_pos")
	print("WP65_QUEUE_AFTER")
	var stuck := 0
	var stuck_missing := 0
	for pid_v2 in ports:
		var pid2: String = String(pid_v2)
		var steps2: int = (queue_by.get(pid2, []) as Array).size()
		var pos2: int = int(queue_pos.get(pid2, 0))
		var first_up2: int = _first_upgrade_step(queue_by, pid2)
		var stuck_first: bool = first_up2 >= 0 and pos2 == first_up2
		var miss_reason := ""
		if stuck_first:
			stuck += 1
			miss_reason = _missing_upgrade_reason(be, pid2, queue_by, first_up2)
			if not miss_reason.is_empty():
				stuck_missing += 1
		print(
			(
				"port=%s steps=%d pos=%d advanced=%d first_upgrade_step=%d stuck_at_first_upgrade=%s missing_target=%s"
				% [pid2, steps2, pos2, pos2, first_up2, str(stuck_first), miss_reason]
			)
		)
	print(
		"WP65_QUEUE stuck_at_first_upgrade_count=%d missing_target_count=%d"
		% [stuck, stuck_missing]
	)
	## A8／WP-65: stop-on-missing-target is required. Formal queue PT-07 asks CB-16 L2
	## with no opening／prior L1 — counted as expected stop, not product jam.
	if stuck > stuck_missing:
		push_error("WP65_QUEUE FAIL: port stuck at first upgrade for non-missing reason")
		quit(1)
		return
	print("WP65_QUEUE OK")
	quit(0)


func _first_upgrade_step(queue_by: Dictionary, port_id: String) -> int:
	var steps: Array = queue_by.get(port_id, [])
	for i in range(steps.size()):
		var s: Object = steps[i]
		if s != null and int(s.get("target_level")) >= 2:
			return i
	return -1


func _missing_upgrade_reason(
	be: Node, port_id: String, queue_by: Dictionary, step_idx: int
) -> String:
	var steps: Array = queue_by.get(port_id, [])
	if step_idx < 0 or step_idx >= steps.size():
		return ""
	var step: Object = steps[step_idx]
	var cb: StringName = StringName(String(step.get("cb_id")))
	var need_level: int = int(step.get("target_level")) - 1
	var city: StringName = get_root().get_node("CashLedger").call("make_city_id", port_id)
	var found: Variant = be.call(
		"_find_city_public_upgrade_target", port_id, city, cb, need_level
	)
	if found == null:
		return "%s@L%d" % [String(cb), need_level]
	return ""


func _seed_mats_and_cash(ports_n: Node, cash: Node, goods: Node, catalog: Node) -> void:
	var ports: PackedStringArray = ports_n.call("all_ids")
	ports.sort()
	var id_source: StringName = cash.get("ID_SOURCE")
	var reason_produce: StringName = goods.get("REASON_PRODUCE")
	for pid_v in ports:
		var pid: String = String(pid_v)
		var city: StringName = cash.call("make_city_id", pid)
		## Boot already created CITY accounts; top up cash.
		cash.call(
			"post",
			[
				cash.call("make_entry", id_source, 0 - FUND_LI),
				cash.call("make_entry", city, FUND_LI),
			],
			&"WP65_FUND",
			&"SYS-08"
		)
		var mkt: Dictionary = goods.call("make_market", pid)
		var external: Variant = goods.call("make_external")
		for gid in MAT_IDS:
			if catalog.call("get_good", gid) == null:
				continue
			goods.call(
				"transfer",
				external,
				mkt,
				StringName(gid),
				MAT_QTY,
				reason_produce,
				&"WP65_SEED"
			)


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
