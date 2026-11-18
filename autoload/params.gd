extends Node
## Autoload: Params — reads res://data/params/params.json (TechSpec 1-A2 / WP-01 / WP-16).
## _ready() only clears fields; load_and_validate() performs I/O and checks (2.2-01).

const PARAMS_PATH := "res://data/params/params.json"
const SCHEMA_PATH := "res://data/params/params_schema.json"

const KEY_DEBUG := "debug"
const KEY_RELEASE := "release"
const TYPE_INT_NAME := "int"
const TYPE_FLOAT_NAME := "float"
const TYPE_BOOL_DEBUG_RELEASE_NAME := "bool_debug_release"
const TYPE_INT_ENUM_NAME := "int_enum"
const TYPE_INT_ARRAY_NAME := "int_array"
const TYPE_FLOAT_ARRAY_NAME := "float_array"
const TYPE_INT_OBJECT_NAME := "int_object"
const TYPE_BUILD_MAT_OBJECT_NAME := "build_mat_object"
const TYPE_UPGRADE_PER_CAPITA_ARRAY_NAME := "upgrade_per_capita_array"
const TYPE_KONTOR_UPGRADE_ARRAY_NAME := "kontor_upgrade_array"
const SCHEMA_TYPE := "type"
const SCHEMA_MIN := "min"
const SCHEMA_MAX := "max"
const SCHEMA_MIN_EXCLUSIVE := "min_exclusive"
const SCHEMA_LENGTH := "length"
const SCHEMA_KEYS := "keys"
const SCHEMA_VALUES := "values"
const SCHEMA_GOOD_ID_PATTERN := "good_id_pattern"
const SCHEMA_CASH_KEY := "cash_key"
const SCHEMA_DAYS_KEY := "days_key"
const SCHEMA_DAYS_MIN := "days_min"

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
			# 1-A8 / TechSpec §4 / D-09f: missing required PRM key → refuse boot.
			errors.append(_err("MISSING_KEY", params_path, key, null, "required PRM key missing"))
			continue
		var value: Variant = params[key]
		if _is_empty_value(value):
			# TechSpec 10-04 / brief: empty value → refuse boot; do not invent defaults.
			errors.append(_err("EMPTY_VALUE", params_path, key, value, "required PRM value empty"))
			continue
		var parsed: Variant = _parse_and_check(key, value, rule, params_path, errors)
		if parsed != null:
			_values[key] = parsed

	# Unknown keys in params.json are reported (do not silently ignore).
	var param_keys: Array = params.keys()
	param_keys.sort()
	for key_variant in param_keys:
		var key: String = String(key_variant)
		if not _schema.has(key):
			errors.append(_err("UNKNOWN_KEY", params_path, key, params[key], "key not in TechSpec §4 / WP-16 params.json schema"))

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


func get_value(prm_id: StringName) -> Variant:
	# WP-16: arrays／objects／scalars after successful load (TechSpec 10-02).
	var key := String(prm_id)
	assert(_loaded and _values.has(key), "Params.get_value before successful load: %s" % key)
	return _values[key]


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


func _is_empty_value(value: Variant) -> bool:
	if value == null:
		return true
	if typeof(value) == TYPE_STRING and String(value).is_empty():
		return true
	return false


func _parse_and_check(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	var type_name := _rule_type(rule)
	match type_name:
		TYPE_INT_NAME:
			return _parse_int_scalar(key, value, rule, file_path, errors)
		TYPE_FLOAT_NAME:
			return _parse_float_scalar(key, value, rule, file_path, errors)
		TYPE_BOOL_DEBUG_RELEASE_NAME:
			return _parse_bool_debug_release(key, value, file_path, errors)
		TYPE_INT_ENUM_NAME:
			return _parse_int_enum(key, value, rule, file_path, errors)
		TYPE_INT_ARRAY_NAME:
			return _parse_int_array(key, value, rule, file_path, errors)
		TYPE_FLOAT_ARRAY_NAME:
			return _parse_float_array(key, value, rule, file_path, errors)
		TYPE_INT_OBJECT_NAME:
			return _parse_int_object(key, value, rule, file_path, errors)
		TYPE_BUILD_MAT_OBJECT_NAME:
			return _parse_build_mat_object(key, value, rule, file_path, errors)
		TYPE_UPGRADE_PER_CAPITA_ARRAY_NAME:
			return _parse_upgrade_per_capita_array(key, value, rule, file_path, errors)
		TYPE_KONTOR_UPGRADE_ARRAY_NAME:
			return _parse_kontor_upgrade_array(key, value, rule, file_path, errors)
		_:
			errors.append(_err("SCHEMA_TYPE", SCHEMA_PATH, key, type_name, "unknown schema type"))
			return null


func _parse_int_scalar(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	if not _is_json_int(value):
		errors.append(_err("TYPE", file_path, key, value, "expected int (JSON whole number)"))
		return null
	var as_int: int = floori(float(value))
	if not _in_range_number(float(as_int), rule):
		errors.append(_err("RANGE", file_path, key, as_int, "int out of TechSpec range"))
		return null
	return as_int


func _parse_float_scalar(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		errors.append(_err("TYPE", file_path, key, value, "expected float/定點數"))
		return null
	var as_float := float(value)
	if not _in_range_number(as_float, rule):
		errors.append(_err("RANGE", file_path, key, as_float, "float out of TechSpec range"))
		return null
	return as_float


func _parse_bool_debug_release(key: String, value: Variant, file_path: String, errors: Array) -> Variant:
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


func _parse_int_enum(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	if not _is_json_int(value):
		errors.append(_err("TYPE", file_path, key, value, "expected int enum"))
		return null
	var as_int: int = floori(float(value))
	if not rule.has(SCHEMA_VALUES) or typeof(rule[SCHEMA_VALUES]) != TYPE_ARRAY:
		errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "int_enum requires values array"))
		return null
	var allowed: Array = rule[SCHEMA_VALUES]
	var ok := false
	for v in allowed:
		if _is_json_int(v) and floori(float(v)) == as_int:
			ok = true
			break
	if not ok:
		errors.append(_err("ENUM", file_path, key, as_int, "int not in allowed enum set"))
		return null
	return as_int


func _parse_int_array(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	if typeof(value) != TYPE_ARRAY:
		errors.append(_err("TYPE", file_path, key, value, "expected int array"))
		return null
	var arr: Array = value
	if rule.has(SCHEMA_LENGTH) and arr.size() != int(rule[SCHEMA_LENGTH]):
		errors.append(_err("LENGTH", file_path, key, arr.size(), "array length mismatch"))
		return null
	var out: Array = []
	var had_error := false
	for i in range(arr.size()):
		var elem: Variant = arr[i]
		var field := "%s[%d]" % [key, i]
		if not _is_json_int(elem):
			errors.append(_err("TYPE", file_path, field, elem, "expected int element"))
			had_error = true
			continue
		var as_int: int = floori(float(elem))
		if not _in_range_number(float(as_int), rule):
			errors.append(_err("RANGE", file_path, field, as_int, "int element out of range"))
			had_error = true
			continue
		out.append(as_int)
	if had_error:
		return null
	return out


func _parse_float_array(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	if typeof(value) != TYPE_ARRAY:
		errors.append(_err("TYPE", file_path, key, value, "expected float array"))
		return null
	var arr: Array = value
	if rule.has(SCHEMA_LENGTH) and arr.size() != int(rule[SCHEMA_LENGTH]):
		errors.append(_err("LENGTH", file_path, key, arr.size(), "array length mismatch"))
		return null
	var out: Array = []
	var had_error := false
	for i in range(arr.size()):
		var elem: Variant = arr[i]
		var field := "%s[%d]" % [key, i]
		if typeof(elem) != TYPE_FLOAT and typeof(elem) != TYPE_INT:
			errors.append(_err("TYPE", file_path, field, elem, "expected float element"))
			had_error = true
			continue
		var as_float := float(elem)
		if not _in_range_number(as_float, rule):
			errors.append(_err("RANGE", file_path, field, as_float, "float element out of range"))
			had_error = true
			continue
		out.append(as_float)
	if had_error:
		return null
	return out


func _parse_int_object(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append(_err("TYPE", file_path, key, value, "expected int object"))
		return null
	if not rule.has(SCHEMA_KEYS) or typeof(rule[SCHEMA_KEYS]) != TYPE_ARRAY:
		errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "int_object requires keys array"))
		return null
	var required_keys: Array = rule[SCHEMA_KEYS]
	var obj: Dictionary = value
	var had_error := false
	# D-10a: object keys must be exactly the enum set (missing and extra both wrong).
	for req_variant in required_keys:
		var req: String = String(req_variant)
		if not obj.has(req):
			errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [key, req], null, "object missing required key"))
			had_error = true
	for obj_key_variant in obj.keys():
		var obj_key: String = String(obj_key_variant)
		if not _array_has_string(required_keys, obj_key):
			errors.append(_err("UNKNOWN_KEY", file_path, "%s.%s" % [key, obj_key], obj[obj_key], "object has extra key"))
			had_error = true
	var out: Dictionary = {}
	for req_variant in required_keys:
		var req: String = String(req_variant)
		if not obj.has(req):
			continue
		var elem: Variant = obj[req]
		var field := "%s.%s" % [key, req]
		if not _is_json_int(elem):
			errors.append(_err("TYPE", file_path, field, elem, "expected int value"))
			had_error = true
			continue
		var as_int: int = floori(float(elem))
		if not _in_range_number(float(as_int), rule):
			errors.append(_err("RANGE", file_path, field, as_int, "int value out of range"))
			had_error = true
			continue
		out[req] = as_int
	if had_error:
		return null
	return out


func _parse_build_mat_object(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	# D-10a / 8.7 I: build_class → {good_id: 擔數 int}; good_id format only (existence at WP-18).
	if typeof(value) != TYPE_DICTIONARY:
		errors.append(_err("TYPE", file_path, key, value, "expected build_mat object"))
		return null
	if not rule.has(SCHEMA_KEYS) or typeof(rule[SCHEMA_KEYS]) != TYPE_ARRAY:
		errors.append(_err("SCHEMA_RULE", SCHEMA_PATH, key, rule, "build_mat_object requires keys array"))
		return null
	var pattern := String(rule.get(SCHEMA_GOOD_ID_PATTERN, ""))
	var required_keys: Array = rule[SCHEMA_KEYS]
	var obj: Dictionary = value
	var had_error := false
	for req_variant in required_keys:
		var req: String = String(req_variant)
		if not obj.has(req):
			errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [key, req], null, "object missing required key"))
			had_error = true
	for obj_key_variant in obj.keys():
		var obj_key: String = String(obj_key_variant)
		if not _array_has_string(required_keys, obj_key):
			errors.append(_err("UNKNOWN_KEY", file_path, "%s.%s" % [key, obj_key], obj[obj_key], "object has extra key"))
			had_error = true
	var out: Dictionary = {}
	for req_variant in required_keys:
		var req: String = String(req_variant)
		if not obj.has(req):
			continue
		var nested_raw: Variant = obj[req]
		var field := "%s.%s" % [key, req]
		if typeof(nested_raw) != TYPE_DICTIONARY:
			errors.append(_err("TYPE", file_path, field, nested_raw, "expected {good_id: int}"))
			had_error = true
			continue
		var nested: Dictionary = nested_raw
		var nested_out: Dictionary = {}
		var nested_bad := false
		for gid_variant in nested.keys():
			var gid: String = String(gid_variant)
			var gfield := "%s.%s" % [field, gid]
			if not _matches_pattern(gid, pattern):
				errors.append(_err("TYPE", file_path, gfield, gid, "good_id format mismatch"))
				nested_bad = true
				continue
			var qty: Variant = nested[gid]
			if not _is_json_int(qty):
				errors.append(_err("TYPE", file_path, gfield, qty, "expected int 擔數"))
				nested_bad = true
				continue
			var as_int: int = floori(float(qty))
			if not _in_range_number(float(as_int), rule):
				errors.append(_err("RANGE", file_path, gfield, as_int, "擔數 out of range"))
				nested_bad = true
				continue
			nested_out[gid] = as_int
		if nested_bad:
			had_error = true
			continue
		out[req] = nested_out
	if had_error:
		return null
	return out


func _parse_upgrade_per_capita_array(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	# 8.7 I: length 2; each element {"CASH_LI": int, good_id: 定點數}.
	if typeof(value) != TYPE_ARRAY:
		errors.append(_err("TYPE", file_path, key, value, "expected upgrade_per_capita array"))
		return null
	var arr: Array = value
	if rule.has(SCHEMA_LENGTH) and arr.size() != int(rule[SCHEMA_LENGTH]):
		errors.append(_err("LENGTH", file_path, key, arr.size(), "array length mismatch"))
		return null
	var cash_key := String(rule.get(SCHEMA_CASH_KEY, "CASH_LI"))
	var pattern := String(rule.get(SCHEMA_GOOD_ID_PATTERN, ""))
	var out: Array = []
	var had_error := false
	for i in range(arr.size()):
		var elem: Variant = arr[i]
		var field := "%s[%d]" % [key, i]
		if typeof(elem) != TYPE_DICTIONARY:
			errors.append(_err("TYPE", file_path, field, elem, "expected object element"))
			had_error = true
			continue
		var d: Dictionary = elem
		if not d.has(cash_key):
			errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [field, cash_key], null, "missing CASH_LI"))
			had_error = true
			continue
		var cash_raw: Variant = d[cash_key]
		if not _is_json_int(cash_raw):
			errors.append(_err("TYPE", file_path, "%s.%s" % [field, cash_key], cash_raw, "expected int CASH_LI"))
			had_error = true
			continue
		var cash_int: int = floori(float(cash_raw))
		if not _in_range_number(float(cash_int), rule):
			errors.append(_err("RANGE", file_path, "%s.%s" % [field, cash_key], cash_int, "CASH_LI out of range"))
			had_error = true
			continue
		var elem_out: Dictionary = {}
		elem_out[cash_key] = cash_int
		var elem_bad := false
		for k_variant in d.keys():
			var k: String = String(k_variant)
			if k == cash_key:
				continue
			var gfield := "%s.%s" % [field, k]
			if not _matches_pattern(k, pattern):
				errors.append(_err("TYPE", file_path, gfield, k, "good_id format mismatch"))
				elem_bad = true
				continue
			var qty: Variant = d[k]
			if typeof(qty) != TYPE_FLOAT and typeof(qty) != TYPE_INT:
				errors.append(_err("TYPE", file_path, gfield, qty, "expected float/定點數"))
				elem_bad = true
				continue
			var as_float := float(qty)
			if not _in_range_number(as_float, rule):
				errors.append(_err("RANGE", file_path, gfield, as_float, "qty out of range"))
				elem_bad = true
				continue
			elem_out[k] = as_float
		if elem_bad:
			had_error = true
			continue
		out.append(elem_out)
	if had_error:
		return null
	return out


func _parse_kontor_upgrade_array(key: String, value: Variant, rule: Dictionary, file_path: String, errors: Array) -> Variant:
	## D-12b / D-15b: length 2; each {"CASH_LI": int, "DAYS": int ≥ 1, good_id: 擔數 int}.
	if typeof(value) != TYPE_ARRAY:
		errors.append(_err("TYPE", file_path, key, value, "expected kontor_upgrade array"))
		return null
	var arr: Array = value
	if rule.has(SCHEMA_LENGTH) and arr.size() != int(rule[SCHEMA_LENGTH]):
		errors.append(_err("LENGTH", file_path, key, arr.size(), "array length mismatch"))
		return null
	var cash_key := String(rule.get(SCHEMA_CASH_KEY, "CASH_LI"))
	var days_key := String(rule.get(SCHEMA_DAYS_KEY, "DAYS"))
	var days_min: int = int(rule.get(SCHEMA_DAYS_MIN, 1))
	var pattern := String(rule.get(SCHEMA_GOOD_ID_PATTERN, ""))
	var out: Array = []
	var had_error := false
	for i in range(arr.size()):
		var elem: Variant = arr[i]
		var field := "%s[%d]" % [key, i]
		if typeof(elem) != TYPE_DICTIONARY:
			errors.append(_err("TYPE", file_path, field, elem, "expected object element"))
			had_error = true
			continue
		var d: Dictionary = elem
		if not d.has(cash_key):
			errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [field, cash_key], null, "missing CASH_LI"))
			had_error = true
			continue
		if not d.has(days_key):
			errors.append(_err("MISSING_KEY", file_path, "%s.%s" % [field, days_key], null, "missing DAYS"))
			had_error = true
			continue
		var cash_raw: Variant = d[cash_key]
		var days_raw: Variant = d[days_key]
		if not _is_json_int(cash_raw) or not _is_json_int(days_raw):
			errors.append(_err("TYPE", file_path, field, elem, "CASH_LI／DAYS must be int"))
			had_error = true
			continue
		var cash_int: int = floori(float(cash_raw))
		var days_int: int = floori(float(days_raw))
		if not _in_range_number(float(cash_int), rule) or days_int < days_min:
			errors.append(_err("RANGE", file_path, field, elem, "CASH_LI／DAYS out of range"))
			had_error = true
			continue
		var elem_out: Dictionary = {}
		elem_out[cash_key] = cash_int
		elem_out[days_key] = days_int
		var elem_bad := false
		for k_variant in d.keys():
			var k: String = String(k_variant)
			if k == cash_key or k == days_key:
				continue
			var gfield := "%s.%s" % [field, k]
			if not _matches_pattern(k, pattern):
				errors.append(_err("TYPE", file_path, gfield, k, "good_id format mismatch"))
				elem_bad = true
				continue
			var qty: Variant = d[k]
			if not _is_json_int(qty):
				errors.append(_err("TYPE", file_path, gfield, qty, "expected int 擔數"))
				elem_bad = true
				continue
			var as_int: int = floori(float(qty))
			if not _in_range_number(float(as_int), rule):
				errors.append(_err("RANGE", file_path, gfield, as_int, "擔數 out of range"))
				elem_bad = true
				continue
			elem_out[k] = as_int
		if elem_bad:
			had_error = true
			continue
		out.append(elem_out)
	if had_error:
		return null
	return out


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
	if rule.has(SCHEMA_MIN_EXCLUSIVE):
		if value <= float(rule[SCHEMA_MIN_EXCLUSIVE]):
			return false
	if rule.has(SCHEMA_MAX):
		if value > float(rule[SCHEMA_MAX]):
			return false
	return true


func _array_has_string(arr: Array, needle: String) -> bool:
	for v in arr:
		if String(v) == needle:
			return true
	return false


func _matches_pattern(text: String, pattern: String) -> bool:
	if pattern.is_empty():
		return true
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		return false
	var m := re.search(text)
	return m != null and m.get_start() == 0 and m.get_end() == text.length()


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
