extends SceneTree
## Boot-only probe: formal data + scenario_L1_baseline overrides (no years loop).
## No Autoload identifiers at parse time (same constraint as sim_runner -s).


var _started: bool = false


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	var root: Window = get_root()
	var scen_path := "res://docs/spec/scenario_L1_baseline.json"
	var raw: String = FileAccess.get_file_as_string(scen_path)
	var scen: Dictionary = JSON.parse_string(raw)
	var overrides: Dictionary = scen.get("overrides", {})
	print("PROBE_BOOT: scenario_id=%s years=%s overrides=%s" % [
		str(scen.get("scenario_id")), str(scen.get("years")), str(overrides.size())
	])
	var merge_gds: GDScript = load("res://sim/params_merge.gd") as GDScript
	var merged_path := "user://sim_merged/probe_l1_boot.json"
	var merge_res: Dictionary = merge_gds.call(
		"merge_to_user",
		"res://data/params/params.json",
		overrides,
		{},
		merged_path
	)
	print("PROBE_BOOT: merge_ok=%s path=%s errors=%s" % [
		str(merge_res.get("ok")), str(merge_res.get("path")), str(merge_res.get("errors"))
	])
	if not bool(merge_res.get("ok")):
		quit(1)
		return
	var sim_loop: Node = root.get_node_or_null("SimLoop")
	var good_cat: Node = root.get_node_or_null("GoodCatalog")
	var port_reg: Node = root.get_node_or_null("PortRegistry")
	var market: Node = root.get_node_or_null("MarketPricer")
	var sea: Node = root.get_node_or_null("SeaLanes")
	var demand: Node = root.get_node_or_null("DemandModel")
	var goods_dir: String = String(good_cat.get("GOODS_DIR")) if good_cat else "res://data/goods/"
	var ports_dir: String = String(port_reg.get("PORTS_DIR")) if port_reg else "res://data/ports/"
	var curve_path: String = String(market.get("CURVE_PATH")) if market else "res://data/market/price_curve.tres"
	var nodes_dir: String = String(sea.get("NODES_DIR")) if sea else "res://data/sea/nodes/"
	var regions_dir: String = String(sea.get("REGIONS_DIR")) if sea else "res://data/sea/regions/"
	var lanes_dir: String = String(sea.get("LANES_DIR")) if sea else "res://data/sea/lanes/"
	var tables_path: String = String(demand.get("TABLES_PATH")) if demand else "res://data/demand/"
	## Consts on Autoload scripts are often on the script, not instance — fall back.
	if goods_dir.is_empty() or goods_dir == "<null>":
		goods_dir = "res://data/goods/"
	if ports_dir.is_empty() or ports_dir == "<null>":
		ports_dir = "res://data/ports/"
	if curve_path.is_empty() or curve_path == "<null>":
		curve_path = "res://data/market/price_curve.tres"
	if nodes_dir.is_empty() or nodes_dir == "<null>":
		nodes_dir = "res://data/sea/nodes/"
	if regions_dir.is_empty() or regions_dir == "<null>":
		regions_dir = "res://data/sea/regions/"
	if lanes_dir.is_empty() or lanes_dir == "<null>":
		lanes_dir = "res://data/sea/lanes/"
	if tables_path.is_empty() or tables_path == "<null>":
		tables_path = "res://data/demand/"
	print("PROBE_BOOT: paths goods=%s ports=%s demand=%s" % [goods_dir, ports_dir, tables_path])
	## D-60f: probe expects successful boot → inject deny-all fixture（not formal always-allow）.
	var intel: Node = root.get_node_or_null("IntelLedger")
	if intel != null and not bool(intel.call("has_broker_provider")):
		var fixture_script: GDScript = load("res://sim/sim_broker_fixture.gd") as GDScript
		intel.call("set_broker_provider", fixture_script.new())
	var t0: int = Time.get_ticks_msec()
	var boot_errors: Array = sim_loop.call(
		"boot",
		String(merge_res["path"]),
		goods_dir,
		ports_dir,
		curve_path,
		nodes_dir,
		regions_dir,
		lanes_dir,
		tables_path
	)
	var elapsed: int = Time.get_ticks_msec() - t0
	var is_booted: bool = bool(sim_loop.call("is_booted"))
	print("PROBE_BOOT: is_booted=%s err_count=%s elapsed_ms=%s" % [
		str(is_booted), str(boot_errors.size()), str(elapsed)
	])
	print("PROBE_BOOT_ERRORS_BEGIN")
	for e in boot_errors:
		print(str(e))
	print("PROBE_BOOT_ERRORS_END count=%s" % str(boot_errors.size()))
	quit(0 if boot_errors.is_empty() and is_booted else 1)
