extends Node
## Autoload: Params — reads res://data/params/params.json (TechSpec 1-A2 / WP-01).
## _ready() only clears fields; load_and_validate() performs I/O and checks (2.2-01).

const PARAMS_PATH := "res://data/params/params.json"
const SCHEMA_PATH := "res://data/params/params_schema.json"

const KEY_DEBUG := "debug"
const KEY_RELEASE := "release"
const TYPE_INT_NAME := "int"
const TYPE_FLOAT_NAME := "float"
const TYPE_BOOL_DEBUG_RELEASE_NAME := "bool_debug_release"
const SCHEMA_TYPE := "type"
const SCHEMA_MIN := "min"
const SCHEMA_MAX := "max"

var _values: Dictionary = {}
var _schema: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	_values = {}
	_schema = {}
	_loaded = false


func load_and_validate(params_path: String = PARAMS_PATH) -> Array:
	# C-06: collect every error; do not stop at the first.
	var errors: Array = []
	_values = {}
	_schema = {}
	_loaded = false

	var schema_raw: Variant = _read_json_file(SCHEMA_PATH, errors)
	if schema_raw == null:
		_emit_errors(errors)
		return errors
	if typeof(schema_raw) != TYPE_DICTIONARY:
		errors.append(_err("SCHEMA_TYPE", SCHEMA_PATH, "", schema_raw, "schema root must be Dictionary"))
		_emit_errors(errors)
		return errors
	_schema = schema_raw

	var params_raw: Variant = _read_json_file(params_path, errors)
	if params_raw == null:
		_emit_errors(errors)
		return errors
	if typeof(params_raw) != TYPE_DICTIONARY:
		errors.append(_err("PARAMS_TYPE", params_path, "", params_raw, "params root must be Dictionary"))
		_emit_errors(errors)
		return errors
	var params: Dictionary = params_raw

	var schema_keys: Array = _schema.keys()
	schema_keys.sort()
	for key_variant in schema_keys:
		var key: String = String(key_variant)
		var rule: Variant = _schema[key]
		if typeof(rule) != TYPE_DICTIONARY:
			errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "schema rule must be Dictionary"))
			continue
		if not params.has(key):
			# 1-A8 / TechSpec §4: missing required PRM key → refuse boot.
			errors.append(_err("MISSING_KEY", params_path, key, null, "required PRM key missing"))
			continue
		var value: Variant = params[key]
		var parsed: Variant = _parse_and_check(key, value, rule, params_path, errors)
		if parsed != null:
			_values[key] = parsed

	# Unknown keys in params.json are reported (do not silently ignore).
	var param_keys: Array = params.keys()
	param_keys.sort()
	for key_variant in param_keys:
		var key: String = String(key_variant)
		if not _schema.has(key):
			errors.append(_err("UNKNOWN_KEY", params_path, key, params[key], "key not in TechSpec §4 params.json schema"))

	if errors.is_empty():
		_loaded = true
	else:
		_loaded = false
		_values = {}
		_emit_errors(errors)
	return errors


func is_loaded() -> bool:
	return _loaded


func has_prm(prm_id: StringName) -> bool:
	return _values.has(String(prm_id))


func get_int(prm_id: StringName) -> int:
	var key := String(prm_id)
	assert(_loaded and _values.has(key), "Params.get_int before successful load: %s" % key)
	return int(_values[key])


func get_float(prm_id: StringName) -> float:
	var key := String(prm_id)
	assert(_loaded and _values.has(key), "Params.get_float before successful load: %s" % key)
	return float(_values[key])


func get_bool(prm_id: StringName) -> bool:
	# PRM-SYS03-CONSERVATION_CHECK_EVERY_TICK: select debug/release via OS.is_debug_build() (2.3-04).
	var key := String(prm_id)
	assert(_loaded and _values.has(key), "Params.get_bool before successful load: %s" % key)
	var stored: Variant = _values[key]
	if typeof(stored) == TYPE_DICTIONARY:
		var d: Dictionary = stored
		if OS.is_debug_build():
			return bool(d[KEY_DEBUG])
		return bool(d[KEY_RELEASE])
	return bool(stored)


func all_prm_ids() -> PackedStringArray:
	var ids: Array = _values.keys()
	ids.sort()
	return PackedStringArray(ids)


func _read_json_file(path: String, errors: Array) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append(_err("FILE_MISSING", path, "", null, "file not found"))
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append(_err("FILE_OPEN", path, "", FileAccess.get_open_error(), "cannot open file"))
		return null
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		errors.append(_err("JSON_PARSE", path, "", null, "JSON.parse_string failed"))
		return null
	return parsed


func _parse_and_check(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	var type_name := _rule_type(rule)
	match type_name:
		TYPE_INT_NAME:
			if not _is_json_int(value):
				errors.append(_err("TYPE", file_path, key, value, "expected int (JSON whole number)"))
				return null
			var as_int: int = floori(float(value))
			if not _in_range_number(float(as_int), rule):
				errors.append(_err("RANGE", file_path, key, as_int, "int out of TechSpec §4 range"))
				return null
			return as_int
		TYPE_FLOAT_NAME:
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				errors.append(_err("TYPE", file_path, key, value, "expected float/定點數"))
				return null
			var as_float := float(value)
			if not _in_range_number(as_float, rule):
				errors.append(_err("RANGE", file_path, key, as_float, "float out of TechSpec §4 range"))
				return null
			return as_float
		TYPE_BOOL_DEBUG_RELEASE_NAME:
			if typeof(value) != TYPE_DICTIONARY:
				errors.append(_err("TYPE", file_path, key, value, "expected {debug:bool, release:bool}"))
				return null
			var d: Dictionary = value
			if not d.has(KEY_DEBUG) or not d.has(KEY_RELEASE):
				errors.append(_err("TYPE", file_path, key, value, "missing debug/release"))
				return null
			if typeof(d[KEY_DEBUG]) != TYPE_BOOL or typeof(d[KEY_RELEASE]) != TYPE_BOOL:
				errors.append(_err("TYPE", file_path, key, value, "debug/release must be bool"))
				return null
			return {
				KEY_DEBUG: d[KEY_DEBUG],
				KEY_RELEASE: d[KEY_RELEASE],
			}
		_:
			errors.append(_err("SCHEMA_TYPE", SCHEMA_PATH, key, type_name, "unknown schema type"))
			return null


func _rule_type(rule: Dictionary) -> String:
	return String(rule.get(SCHEMA_TYPE, ""))


func _is_json_int(value: Variant) -> bool:
	# Godot JSON parses numbers as float; accept whole numbers only (4-N1).
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return float(value) == floorf(float(value))
	return false


func _in_range_number(value: float, rule: Dictionary) -> bool:
	if rule.has(SCHEMA_MIN):
		if value < float(rule[SCHEMA_MIN]):
			return false
	if rule.has(SCHEMA_MAX):
		if value > float(rule[SCHEMA_MAX]):
			return false
	return true


func _err(code: String, file_path: String, field: String, value: Variant, message: String) -> Dictionary:
	return {
		"code": code,
		"file": file_path,
		"field": field,
		"value": value,
		"message": message,
	}


func _emit_errors(errors: Array) -> void:
	for e in errors:
		# 1-A8: push_error on reject; C-06: report every error.
		push_error("Params: %s" % str(e))
