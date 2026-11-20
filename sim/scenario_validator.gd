class_name SimScenarioValidator
extends RefCounted
## SYS-23 scenario.json validation — 03_Systems 9.6 / ERR-SYS23-01..06 (WP-26).
## Collect every error (C-06); no clamp; no invented defaults for required keys.

const ERR_SYS23_01 := "ERR-SYS23-01"
const ERR_SYS23_02 := "ERR-SYS23-02"
const ERR_SYS23_03 := "ERR-SYS23-03"
const ERR_SYS23_04 := "ERR-SYS23-04"
const ERR_SYS23_05 := "ERR-SYS23-05"
const ERR_SYS23_06 := "ERR-SYS23-06"

const KEY_SCENARIO_ID := "scenario_id"
const KEY_YEARS := "years"
const KEY_WARMUP := "warmup_years"
const KEY_SEEDS := "seeds"
const KEY_LAYERS := "layers"
const KEY_RELOCATE_F := "relocate_f"
const KEY_OVERRIDES := "overrides"
const KEY_GRID := "grid"
const KEY_DAILY_PORTS := "daily_detail_ports"
const KEY_THRESHOLDS := "thresholds"
const KEY_RELOCATE := "RELOCATE"

const SCHEMA_PATH := "res://data/params/params_schema.json"

## 9.6 allowed top-level keys (exact).
const ALLOWED_KEYS: PackedStringArray = [
	KEY_SCENARIO_ID,
	KEY_YEARS,
	KEY_WARMUP,
	KEY_SEEDS,
	KEY_LAYERS,
	KEY_RELOCATE_F,
	KEY_OVERRIDES,
	KEY_GRID,
	KEY_DAILY_PORTS,
	KEY_THRESHOLDS,
]

const REQUIRED_KEYS: PackedStringArray = [
	KEY_SCENARIO_ID,
	KEY_YEARS,
	KEY_WARMUP,
	KEY_SEEDS,
	KEY_LAYERS,
]


static func validate_file(scenario_path: String, ports_dir: String = "") -> Dictionary:
	## Returns {ok: bool, errors: PackedStringArray, scenario: Dictionary}.
	var out := {"ok": false, "errors": PackedStringArray(), "scenario": {}}
	if scenario_path.is_empty() or not FileAccess.file_exists(scenario_path):
		out["errors"] = PackedStringArray([
			"%s: scenario file missing: %s" % [ERR_SYS23_01, scenario_path]
		])
		return out
	var raw: String = FileAccess.get_file_as_string(scenario_path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		out["errors"] = PackedStringArray([
			"%s: scenario JSON parse failed: %s" % [ERR_SYS23_01, scenario_path]
		])
		return out
	return validate_dict(parsed as Dictionary, ports_dir)


static func validate_dict(scenario: Dictionary, ports_dir: String = "") -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	_check_keys(scenario, errors)
	if not errors.is_empty():
		## Still continue type checks on known keys when present (C-06 all-at-once).
		pass
	_check_required_present(scenario, errors)
	_check_scenario_id(scenario, errors)
	_check_years(scenario, errors)
	_check_seeds(scenario, errors)
	_check_layers_and_f(scenario, errors)
	_check_overrides_grid(scenario, errors)
	_check_daily_ports(scenario, ports_dir, errors)
	_check_thresholds(scenario, errors)
	var out := {
		"ok": errors.is_empty(),
		"errors": errors,
		"scenario": _normalize_optional(scenario),
	}
	return out


static func _normalize_optional(scenario: Dictionary) -> Dictionary:
	## Spec defaults for optional keys when absent (9.6 預設); required already validated.
	var s: Dictionary = scenario.duplicate(true)
	if not s.has(KEY_OVERRIDES):
		s[KEY_OVERRIDES] = {}
	if not s.has(KEY_GRID):
		s[KEY_GRID] = {}
	if not s.has(KEY_DAILY_PORTS):
		s[KEY_DAILY_PORTS] = []
	if not s.has(KEY_THRESHOLDS):
		s[KEY_THRESHOLDS] = {}
	return s


static func _check_keys(scenario: Dictionary, errors: PackedStringArray) -> void:
	var keys: Array = scenario.keys()
	keys.sort()
	var allowed: Dictionary = {}
	for k in ALLOWED_KEYS:
		allowed[String(k)] = true
	for k_v in keys:
		var k: String = String(k_v)
		if not allowed.has(k):
			errors.append("%s: unknown scenario key '%s'" % [ERR_SYS23_02, k])


static func _check_required_present(scenario: Dictionary, errors: PackedStringArray) -> void:
	for k in REQUIRED_KEYS:
		if not scenario.has(k):
			errors.append("%s: missing required key '%s'" % [ERR_SYS23_02, k])


static func _check_scenario_id(scenario: Dictionary, errors: PackedStringArray) -> void:
	if not scenario.has(KEY_SCENARIO_ID):
		return
	var v: Variant = scenario[KEY_SCENARIO_ID]
	if typeof(v) != TYPE_STRING:
		errors.append("%s: scenario_id must be String" % ERR_SYS23_03)
		return
	var sid: String = String(v)
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_-]+$")
	if re.search(sid) == null:
		errors.append("%s: scenario_id charset must be [A-Za-z0-9_-]" % ERR_SYS23_03)


static func _check_years(scenario: Dictionary, errors: PackedStringArray) -> void:
	## Validate each present key independently so C-06 lists type errors even when
	## a sibling required key is missing (all-at-once).
	var years_ok := false
	var y: int = 0
	if scenario.has(KEY_YEARS):
		if not _is_json_int(scenario[KEY_YEARS]):
			errors.append("%s: years must be int ≥ 1" % ERR_SYS23_03)
		else:
			y = _as_int(scenario[KEY_YEARS])
			if y < 1:
				errors.append("%s: years must be int ≥ 1" % ERR_SYS23_03)
			else:
				years_ok = true
	if scenario.has(KEY_WARMUP):
		if not _is_json_int(scenario[KEY_WARMUP]):
			errors.append("%s: warmup_years must be int ≥ 0 and < years" % ERR_SYS23_03)
		else:
			var w: int = _as_int(scenario[KEY_WARMUP])
			if w < 0:
				errors.append("%s: warmup_years must be int ≥ 0 and < years" % ERR_SYS23_03)
			elif years_ok and w >= y:
				errors.append("%s: warmup_years must be < years" % ERR_SYS23_03)


static func _check_seeds(scenario: Dictionary, errors: PackedStringArray) -> void:
	if not scenario.has(KEY_SEEDS):
		return
	var v: Variant = scenario[KEY_SEEDS]
	if typeof(v) != TYPE_ARRAY:
		errors.append("%s: seeds must be non-empty int array" % ERR_SYS23_03)
		return
	var arr: Array = v
	if arr.is_empty():
		errors.append("%s: seeds must be non-empty int array" % ERR_SYS23_03)
		return
	var seen: Dictionary = {}
	for i in range(arr.size()):
		var elem: Variant = arr[i]
		if not _is_json_int(elem):
			errors.append("%s: seeds[%d] must be int" % [ERR_SYS23_03, i])
			continue
		var s: int = _as_int(elem)
		if seen.has(s):
			errors.append("%s: seeds must not contain duplicates (%d)" % [ERR_SYS23_03, s])
		else:
			seen[s] = true


static func _check_layers_and_f(scenario: Dictionary, errors: PackedStringArray) -> void:
	var relocate_on := false
	if scenario.has(KEY_LAYERS):
		var layers_v: Variant = scenario[KEY_LAYERS]
		if typeof(layers_v) != TYPE_DICTIONARY:
			errors.append("%s: layers must be object" % ERR_SYS23_03)
		else:
			var layers: Dictionary = layers_v
			if not layers.has(KEY_RELOCATE):
				errors.append("%s: layers missing RELOCATE bool" % ERR_SYS23_03)
			else:
				var r: Variant = layers[KEY_RELOCATE]
				if typeof(r) != TYPE_BOOL:
					errors.append("%s: layers.RELOCATE must be bool" % ERR_SYS23_03)
				else:
					relocate_on = bool(r)
			## Reject unknown layer keys.
			for lk_v in layers.keys():
				var lk: String = String(lk_v)
				if lk != KEY_RELOCATE:
					errors.append("%s: unknown layers key '%s'" % [ERR_SYS23_03, lk])
	var has_f: bool = scenario.has(KEY_RELOCATE_F)
	if relocate_on:
		if not has_f:
			errors.append(
				"%s: layers.RELOCATE true requires relocate_f" % ERR_SYS23_06
			)
		else:
			var fv: Variant = scenario[KEY_RELOCATE_F]
			if typeof(fv) != TYPE_FLOAT and typeof(fv) != TYPE_INT:
				errors.append("%s: relocate_f must be number in [0, 1]" % ERR_SYS23_03)
			else:
				var f: float = float(fv)
				if f < 0.0 or f > 1.0:
					errors.append("%s: relocate_f must be number in [0, 1]" % ERR_SYS23_03)
	else:
		if has_f:
			errors.append(
				"%s: relocate_f must not appear when layers.RELOCATE is false" % ERR_SYS23_06
			)


static func _check_overrides_grid(scenario: Dictionary, errors: PackedStringArray) -> void:
	var prm_ids: Dictionary = _load_prm_ids()
	var override_keys: Dictionary = {}
	if scenario.has(KEY_OVERRIDES):
		var ov: Variant = scenario[KEY_OVERRIDES]
		if typeof(ov) != TYPE_DICTIONARY:
			errors.append("%s: overrides must be object" % ERR_SYS23_03)
		else:
			for k_v in (ov as Dictionary).keys():
				var k: String = String(k_v)
				override_keys[k] = true
				if not prm_ids.has(k):
					errors.append(
						"%s: overrides key '%s' is not a registered PRM" % [ERR_SYS23_04, k]
					)
	if scenario.has(KEY_GRID):
		var gv: Variant = scenario[KEY_GRID]
		if typeof(gv) != TYPE_DICTIONARY:
			errors.append("%s: grid must be object" % ERR_SYS23_03)
		else:
			var grid: Dictionary = gv
			for k_v in grid.keys():
				var k: String = String(k_v)
				if not prm_ids.has(k):
					errors.append(
						"%s: grid key '%s' is not a registered PRM" % [ERR_SYS23_04, k]
					)
				if override_keys.has(k):
					errors.append(
						"%s: key '%s' appears in both overrides and grid" % [ERR_SYS23_04, k]
					)
				var cand: Variant = grid[k]
				if typeof(cand) != TYPE_ARRAY:
					errors.append("%s: grid['%s'] must be array of candidates" % [ERR_SYS23_03, k])
				elif (cand as Array).is_empty():
					errors.append("%s: grid['%s'] candidate array must be non-empty" % [ERR_SYS23_03, k])


static func _check_daily_ports(
	scenario: Dictionary, ports_dir: String, errors: PackedStringArray
) -> void:
	if not scenario.has(KEY_DAILY_PORTS):
		return
	var v: Variant = scenario[KEY_DAILY_PORTS]
	if typeof(v) != TYPE_ARRAY:
		errors.append("%s: daily_detail_ports must be array" % ERR_SYS23_03)
		return
	var ports: Dictionary = _list_port_ids(ports_dir)
	for elem in (v as Array):
		if typeof(elem) != TYPE_STRING:
			errors.append("%s: daily_detail_ports entries must be port_id strings" % ERR_SYS23_03)
			continue
		var pid: String = String(elem)
		if ports.is_empty():
			## No ports loaded yet — still flag as nonexistent when dir empty／unknown.
			errors.append("%s: daily_detail_ports unknown port_id '%s'" % [ERR_SYS23_05, pid])
		elif not ports.has(pid):
			errors.append("%s: daily_detail_ports unknown port_id '%s'" % [ERR_SYS23_05, pid])


static func _check_thresholds(scenario: Dictionary, errors: PackedStringArray) -> void:
	if not scenario.has(KEY_THRESHOLDS):
		return
	var v: Variant = scenario[KEY_THRESHOLDS]
	if typeof(v) != TYPE_DICTIONARY:
		errors.append("%s: thresholds must be object" % ERR_SYS23_03)


static func _load_prm_ids() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(SCHEMA_PATH):
		return out
	var raw: String = FileAccess.get_file_as_string(SCHEMA_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for k_v in (parsed as Dictionary).keys():
		out[String(k_v)] = true
	return out


static func _list_port_ids(ports_dir: String) -> Dictionary:
	var out: Dictionary = {}
	var dir_path: String = ports_dir
	if dir_path.is_empty():
		dir_path = PortRegistry.PORTS_DIR
	if not dir_path.ends_with("/"):
		dir_path = "%s/" % dir_path
	var abs_path: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(abs_path):
		return out
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var fname: String = d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.ends_with(".tres"):
			var res: Resource = ResourceLoader.load(dir_path + fname, "", ResourceLoader.CACHE_MODE_IGNORE)
			if res != null and res is PortDef:
				out[String((res as PortDef).port_id)] = true
		fname = d.get_next()
	d.list_dir_end()
	return out


static func _is_json_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	if typeof(v) == TYPE_FLOAT:
		var f: float = float(v)
		return f == floorf(f)
	return false


static func _as_int(v: Variant) -> int:
	return int(floori(float(v)))
