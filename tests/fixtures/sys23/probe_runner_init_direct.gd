extends SceneTree
## Probe: work from _init only — Autoload nodes may be absent.


func _init() -> void:
	print("PROBE_DIRECT: _init entered")
	## get_root may be null this early.
	var root: Window = get_root()
	print("PROBE_DIRECT: root=%s" % str(root))
	if root != null:
		print("PROBE_DIRECT: Params=%s" % str(root.get_node_or_null("Params")))
	else:
		print("PROBE_DIRECT: root is null — Autoloads unreachable")
	var gds: GDScript = load("res://sim/scenario_validator.gd") as GDScript
	print("PROBE_DIRECT: loaded_validator=%s" % str(gds != null))
	if gds != null:
		## May fail if Autoload identifiers inside validator resolve at call time.
		var r: Variant = gds.call(
			"validate_file",
			"res://tests/fixtures/sys23/scenario_ok_layer1.json",
			""
		)
		print("PROBE_DIRECT: validate_typeof=%s" % str(typeof(r)))
		if typeof(r) == TYPE_DICTIONARY:
			print("PROBE_DIRECT: validate_ok=%s" % str((r as Dictionary).get("ok", null)))
	## Cannot quit from _init reliably before main loop — deferred quit only for process exit.
	call_deferred("quit", 0)
