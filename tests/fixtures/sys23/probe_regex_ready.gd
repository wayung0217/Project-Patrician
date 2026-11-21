extends SceneTree
## Probe: is GoodCatalog regex compiled at _initialize vs after process_frame?


func _initialize() -> void:
	print("PROBE_R: _initialize")
	_check("init")
	call_deferred("_deferred_check")


func _deferred_check() -> void:
	print("PROBE_R: deferred")
	_check("deferred")
	## One frame later.
	await process_frame
	print("PROBE_R: after_await_frame")
	_check("await_frame")
	quit(0)


func _check(tag: String) -> void:
	var gc: Node = get_root().get_node_or_null("GoodCatalog")
	## Peek private regex via call — use search through a tiny validate trick:
	## ResourceLoader load GoodDef and search pattern via RegEx on node if exposed.
	## Instead: load_and_validate empty dir vs pattern — read script property if accessible.
	var rx: Variant = gc.get("_good_id_regex")
	print("PROBE_R: %s regex_obj=%s" % [tag, str(rx)])
	if rx != null:
		var m: Variant = rx.call("search", "GD-001")
		print("PROBE_R: %s search_GD001=%s" % [tag, str(m)])
		var m2: Variant = rx.call("search", "NOPE")
		print("PROBE_R: %s search_NOPE=%s" % [tag, str(m2)])
