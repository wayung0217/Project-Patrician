extends SceneTree
## Probe: does GoodCatalog._ready (regex compile) run before _initialize?


func _initialize() -> void:
	print("PROBE_G: _initialize")
	var root: Window = get_root()
	var gc: Node = root.get_node_or_null("GoodCatalog")
	print("PROBE_G: GoodCatalog=%s" % str(gc))
	## Call load on formal/fixture goods via script load to avoid parse-time Autoload ids.
	## Use call on the node directly.
	if gc != null:
		## Reflect whether regex is ready by attempting validate path used in tests.
		var user_goods := "user://sys23_goods/base/"
		var err: Variant = gc.call("load_and_validate", user_goods)
		print("PROBE_G: load_and_validate_typeof=%s" % str(typeof(err)))
		if typeof(err) == TYPE_ARRAY:
			print("PROBE_G: errors_n=%s" % str((err as Array).size()))
			if (err as Array).size() > 0:
				print("PROBE_G: first_err=%s" % str((err as Array)[0]))
	## Also try after deferred.
	call_deferred("_after")


func _after() -> void:
	print("PROBE_G: deferred after")
	var root: Window = get_root()
	var gc: Node = root.get_node_or_null("GoodCatalog")
	var user_goods := "user://sys23_goods/base/"
	var err: Variant = gc.call("load_and_validate", user_goods)
	print("PROBE_G: deferred_errors_n=%s" % str((err as Array).size() if typeof(err) == TYPE_ARRAY else -1))
	if typeof(err) == TYPE_ARRAY and (err as Array).size() > 0:
		print("PROBE_G: deferred_first=%s" % str((err as Array)[0]))
	quit(0)
