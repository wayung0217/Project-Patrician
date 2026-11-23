extends SceneTree
## Step0 D-107: run all 2.1-04 csv_import batches against data/import (from docs/spec).
## Usage: godot --headless --path . -s res://tools/step0_csv_import_all.gd
## Loads csv_import after the tree is up so Autoload Params is available.


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var CsvImport: GDScript = load("res://tools/csv_import.gd") as GDScript
	if CsvImport == null:
		push_error("step0_csv_import_all: failed to load csv_import.gd")
		quit(2)
		return

	var batches: Array = [
		{"name": "D-08i", "result": CsvImport.call("run_batch")},
		{"name": "WP-17", "result": CsvImport.call("run_batch_wp17")},
		{"name": "WP-18", "result": CsvImport.call("run_batch_wp18")},
		{"name": "opening_population", "result": CsvImport.call("run_batch_opening_population")},
		{"name": "WP-29", "result": CsvImport.call("run_batch_wp29")},
	]
	var scales: Dictionary = CsvImport.call("_read_demand_scales_from_params")
	if not bool(scales.get("ok", false)):
		print("BATCH WP-34 ok=false written=0 errors=%s" % str(scales.get("errors", [])))
	else:
		var wp34: Dictionary = CsvImport.call(
			"run_batch_demand",
			"res://data/import/",
			"res://data/demand/rates/",
			"res://data/demand/weights/",
			"res://data/demand/substitutions/",
			scales["rate_scale"] as int,
			scales["ppm_scale"] as int,
			scales["weight_sum"] as int
		)
		batches.append({"name": "WP-34", "result": wp34})

	var all_ok := true
	for b in batches:
		var name: String = String(b["name"])
		var res: Dictionary = b["result"] as Dictionary
		var ok: bool = bool(res.get("ok", false))
		var written: Array = res.get("written", []) as Array
		var errors: PackedStringArray = res.get("errors", PackedStringArray()) as PackedStringArray
		print(
			"BATCH %s ok=%s written=%d errors=%d"
			% [name, str(ok).to_lower(), written.size(), errors.size()]
		)
		if errors.size() > 0:
			for e in errors:
				print("  ERR: %s" % str(e))
		if not ok:
			all_ok = false
	print("CSV_IMPORT_ALL ok=%s" % str(all_ok).to_lower())
	quit(0 if all_ok else 1)
