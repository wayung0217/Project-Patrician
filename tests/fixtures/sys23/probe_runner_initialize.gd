extends SceneTree
## Probe: MainLoop._initialize — no call_deferred / await; no Autoload identifiers at parse time.


func _initialize() -> void:
	print("PROBE_INIT: _initialize entered")
	var root: Window = get_root()
	print("PROBE_INIT: root=%s" % str(root))
	var params_node: Node = root.get_node_or_null("Params")
	print("PROBE_INIT: Params_node=%s" % str(params_node))
	var clock_node: Node = root.get_node_or_null("Clock")
	print("PROBE_INIT: Clock_node=%s" % str(clock_node))
	## load() sim module after Autoload nodes exist (no class_name parse on this file).
	var gds: GDScript = load("res://sim/scenario_validator.gd") as GDScript
	print("PROBE_INIT: loaded_validator=%s" % str(gds != null))
	if gds != null:
		var r: Variant = gds.call(
			"validate_file",
			"res://tests/fixtures/sys23/scenario_ok_layer1.json",
			""
		)
		print("PROBE_INIT: validate_result_typeof=%s" % str(typeof(r)))
		if typeof(r) == TYPE_DICTIONARY:
			var d: Dictionary = r
			print("PROBE_INIT: validate_ok=%s errors=%s" % [str(d.get("ok", null)), str(d.get("errors", []))])
	## Also new() a class that used to fail under -s when parsed too early.
	var eng_gds: GDScript = load("res://sim/sim_engine.gd") as GDScript
	print("PROBE_INIT: loaded_engine=%s" % str(eng_gds != null))
	if eng_gds != null:
		var eng: RefCounted = eng_gds.new()
		print("PROBE_INIT: engine_new=%s" % str(eng != null))
	quit(0)
