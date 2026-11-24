extends SceneTree
## WP-62b: formal boot → sum MARKET stocks; expect 136088 dan（D-107）.
## Usage: godot --headless --path . -s res://tools/wp62b_opening_stock_probe.gd


const SCENARIO_PATH := "res://docs/spec/scenario_L1_baseline.json"
const EXPECT_TOTAL := 136088
const TOP_N := 20


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var boot: Dictionary = _boot_formal()
	var boot_errs: Array = boot.get("errors", [])
	## D-111(f)／F4: print measured boot error count (not a hardcoded 0).
	print("WP62B_BOOT_ERRORS %d" % boot_errs.size())
	if not bool(boot.get("ok")):
		push_error("WP62B boot failed: %s" % str(boot_errs))
		quit(2)
		return
	var root: Window = get_root()
	var goods: Node = root.get_node("GoodsLedger")
	var ports_n: Node = root.get_node("PortRegistry")
	var catalog: Node = root.get_node("GoodCatalog")
	var ports: PackedStringArray = ports_n.call("all_ids")
	ports.sort()
	var gids: PackedStringArray = catalog.call("all_ids")
	gids.sort()
	var total := 0
	var cells: Array = []
	for pid_v in ports:
		var pid: String = String(pid_v)
		var mkt: Dictionary = goods.call("make_market", pid)
		for gid_v in gids:
			var gid: String = String(gid_v)
			var q: int = int(goods.call("get_qty", mkt, StringName(gid)))
			if q <= 0:
				continue
			total += q
			cells.append({"port": pid, "good": gid, "q": q})
	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["q"]) > int(b["q"]))
	print("WP62B_OPENING_STOCK total_dan=%d expect≈%d delta=%d" % [total, EXPECT_TOTAL, total - EXPECT_TOTAL])
	print("WP62B_TOP%d" % TOP_N)
	for i in range(mini(TOP_N, cells.size())):
		var c: Dictionary = cells[i]
		print("rank=%d port=%s good=%s q=%d" % [i + 1, c["port"], c["good"], c["q"]])
	## D-111(f)／F4: conservation once at end (not inside TOP_N loop).
	var cons: int = int(goods.call("check_conservation"))
	print("WP62B_CONSERVATION %d" % cons)
	print("WP62B OK")
	quit(0)


func _boot_formal() -> Dictionary:
	var root: Window = get_root()
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var scen: Dictionary = JSON.parse_string(raw)
	var overrides: Dictionary = scen.get("overrides", {})
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merged_path := "user://sim_merged/wp62b_stock.json"
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
