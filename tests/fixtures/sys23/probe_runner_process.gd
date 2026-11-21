extends SceneTree
## Probe: SceneTree `_process` first frame — Autoload `_ready` should have completed.
## Mirrors sim_runner entry (bool re-entry guard; no call_deferred／await／Timer).


var _started: bool = false


func _process(_delta: float) -> bool:
	## MainLoop._process returns bool (Godot 4.7).
	if _started:
		return false
	_started = true
	print("PROBE_PROCESS: first _process entered")
	var root: Window = get_root()
	print("PROBE_PROCESS: root=%s" % str(root))
	var params_node: Node = root.get_node_or_null("Params")
	print("PROBE_PROCESS: Params_node=%s" % str(params_node))
	var catalog: Node = root.get_node_or_null("GoodCatalog")
	print("PROBE_PROCESS: GoodCatalog_node=%s" % str(catalog))
	var rx: Variant = null
	if catalog != null:
		rx = catalog.get("_good_id_regex")
	print("PROBE_PROCESS: regex_obj=%s" % str(rx))
	var search_ok := false
	if rx != null:
		var m: Variant = rx.call("search", "GD-001")
		print("PROBE_PROCESS: search_GD001=%s" % str(m))
		search_ok = m != null
	## Load sim_engine after ready (same as sim_runner._main).
	var eng_gds: GDScript = load("res://sim/sim_engine.gd") as GDScript
	print("PROBE_PROCESS: loaded_engine=%s" % str(eng_gds != null))
	if eng_gds != null:
		var eng: RefCounted = eng_gds.new()
		print("PROBE_PROCESS: engine_new=%s" % str(eng != null))
	print("PROBE_PROCESS: regex_ready=%s" % str(search_ok))
	quit(0 if search_ok else 1)
	return false
