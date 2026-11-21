class_name SimParamsMerge
extends RefCounted
## FRM-SYS23-01 — formal params.json ← overrides ← grid cell; write user:// temp JSON.


const FORMAL_PARAMS_PATH := "res://data/params/params.json"


static func merge_to_user(
	formal_path: String,
	overrides: Dictionary,
	grid_cell: Dictionary,
	out_user_path: String
) -> Dictionary:
	## Returns {ok: bool, path: String, errors: PackedStringArray, merged: Dictionary}.
	var errors: PackedStringArray = PackedStringArray()
	if not FileAccess.file_exists(formal_path):
		errors.append("formal params missing: %s" % formal_path)
		return {"ok": false, "path": "", "errors": errors, "merged": {}}
	var raw: String = FileAccess.get_file_as_string(formal_path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("formal params JSON root must be Dictionary")
		return {"ok": false, "path": "", "errors": errors, "merged": {}}
	var merged: Dictionary = (parsed as Dictionary).duplicate(true)
	_apply_dict(merged, overrides)
	_apply_dict(merged, grid_cell)
	var parent: String = out_user_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
	var f := FileAccess.open(out_user_path, FileAccess.WRITE)
	if f == null:
		errors.append("cannot write merged params: %s" % out_user_path)
		return {"ok": false, "path": "", "errors": errors, "merged": merged}
	f.store_string(JSON.stringify(merged, "\t"))
	f.close()
	return {"ok": true, "path": out_user_path, "errors": errors, "merged": merged}


static func _apply_dict(target: Dictionary, patch: Dictionary) -> void:
	var keys: Array = patch.keys()
	keys.sort()
	for k_v in keys:
		var k: String = String(k_v)
		target[k] = patch[k]
