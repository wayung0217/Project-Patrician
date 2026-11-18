extends Node
## Autoload: GoodCatalog — loads res://data/goods/*.tres once, then read-only (TechSpec 3.2 / WP-03).
## _ready() only clears fields; load_and_validate() performs I/O and FRM checks (2.2-01).
## Errors are D-04 ErrorInfo Dictionaries (shared with C-06); no ERR→int.

signal catalog_loaded

const GOODS_DIR := "res://data/goods/"
const TRES_SUFFIX := ".tres"

const SYS_ID := &"SYS-01"

const PRM_GOOD_COUNT_MIN := "PRM-SYS01-GOOD_COUNT_MIN"
const PRM_GOOD_COUNT_MAX := "PRM-SYS01-GOOD_COUNT_MAX"
const PRM_TIER_MAX := "PRM-SYS01-TIER_MAX"
const PRM_FREE_PORT_TIER_MAX := "PRM-SYS01-FREE_PORT_TIER_MAX"

## LCR-23 / FRM-SYS01-01 staple names (米、鹽、魚乾、木材).
const STAPLE_NAME_RICE := "米"
const STAPLE_NAME_SALT := "鹽"
const STAPLE_NAME_DRIED_FISH := "魚乾"
const STAPLE_NAME_TIMBER := "木材"

const ERR_SYS01_01 := &"ERR-SYS01-01"
const ERR_SYS01_02 := &"ERR-SYS01-02"
const ERR_SYS01_03 := &"ERR-SYS01-03"
const ERR_SYS01_04 := &"ERR-SYS01-04"
const ERR_SYS01_05 := &"ERR-SYS01-05"

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_LOAD_FAIL := &"LOAD_FAIL"
const CODE_LOAD_TYPE := &"LOAD_TYPE"
const CODE_NOT_LOADED := &"NOT_LOADED"
const CODE_DIR_OPEN := &"DIR_OPEN"

const FIELD_GOOD_ID := "good_id"
const FIELD_TIER := "tier"
const FIELD_BASE_PRICE_LI := "base_price_li"
const FIELD_COUNT := "goods_count"
const FIELD_STAPLE := "is_staple"
const FIELD_PARAMS := "Params"

const TIER_MIN := 1

var _by_id: Dictionary = {}
var _ids_sorted: PackedStringArray = PackedStringArray()
var _loaded: bool = false


func _ready() -> void:
	_clear_state()


func load_and_validate(goods_dir: String = GOODS_DIR) -> Array:
	# C-06: collect every ErrorInfo; do not stop at the first.
	var errors: Array = []
	_clear_state()

	if not Params.is_loaded():
		errors.append(_err(CODE_PARAMS_NOT_LOADED, goods_dir, FIELD_PARAMS, null, "Params must load_and_validate before GoodCatalog"))
		_emit_errors(errors)
		return errors

	var dir_path := goods_dir
	if not dir_path.ends_with("/"):
		dir_path = "%s/" % dir_path

	var entries: Array = _list_tres_paths(dir_path, errors)
	if not errors.is_empty() and entries.is_empty():
		_emit_errors(errors)
		return errors

	var loaded: Array = []
	for path_variant in entries:
		var path: String = String(path_variant)
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			errors.append(_err(CODE_LOAD_FAIL, path, "", null, "ResourceLoader.load failed"))
			continue
		if not (res is GoodDef):
			errors.append(_err(CODE_LOAD_TYPE, path, "", res.get_class(), "expected GoodDef Resource"))
			continue
		loaded.append({"path": path, "def": res as GoodDef})

	# FRM-SYS01-01 — validate the loaded set (may append more errors).
	errors.append_array(_validate_loaded(loaded))

	if not errors.is_empty():
		_clear_state()
		_emit_errors(errors)
		return errors

	# FRM-SYS01-02 — derive controlled_scale_only after validation passes.
	var free_port_tier_max: int = Params.get_int(PRM_FREE_PORT_TIER_MAX)
	for item in loaded:
		var def: GoodDef = item["def"]
		def.controlled_scale_only = (def.tier > free_port_tier_max) or def.is_strategic
		_by_id[def.good_id] = def

	var ids: Array = _by_id.keys()
	ids.sort()
	_ids_sorted = PackedStringArray(ids)
	_loaded = true
	catalog_loaded.emit()
	return errors


func validate() -> Array:
	## Re-run FRM-SYS01-01 on the currently held catalog (H observability).
	if not _loaded:
		return [_err(CODE_NOT_LOADED, GOODS_DIR, "", null, "GoodCatalog.validate called before successful load")]
	var loaded: Array = []
	for id_variant in all_ids():
		var id: String = String(id_variant)
		var def: GoodDef = _by_id[id]
		loaded.append({"path": GOODS_DIR, "def": def})
	return _validate_loaded(loaded)


func get_good(id: String) -> GoodDef:
	# 缺口 C-05: unknown-id failure path not specified; keep assert (do not invent).
	assert(_loaded, "GoodCatalog.get_good before successful load")
	assert(_by_id.has(id), "GoodCatalog.get_good unknown id: %s" % id)
	return _by_id[id] as GoodDef


func all_ids() -> PackedStringArray:
	assert(_loaded, "GoodCatalog.all_ids before successful load")
	return _ids_sorted


func is_loaded() -> bool:
	return _loaded


func _validate_loaded(loaded: Array) -> Array:
	# FRM-SYS01-01
	var errors: Array = []
	var tier_max: int = Params.get_int(PRM_TIER_MAX)
	var count_min: int = Params.get_int(PRM_GOOD_COUNT_MIN)
	var count_max: int = Params.get_int(PRM_GOOD_COUNT_MAX)

	var count: int = loaded.size()
	# ERR-SYS01-04 — goods count out of [GOOD_COUNT_MIN, GOOD_COUNT_MAX]
	if count < count_min or count > count_max:
		errors.append(_err(ERR_SYS01_04, GOODS_DIR, FIELD_COUNT, count, "goods count out of PRM-SYS01 range"))

	var seen_ids: Dictionary = {}
	var staple_counts: Dictionary = {}

	# Deterministic order by good_id then path (C-08).
	var ordered: Array = loaded.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var id_a: String = (a["def"] as GoodDef).good_id
		var id_b: String = (b["def"] as GoodDef).good_id
		if id_a == id_b:
			return String(a["path"]) < String(b["path"])
		return id_a < id_b
	)

	for item in ordered:
		var path: String = String(item["path"])
		var def: GoodDef = item["def"]

		# ERR-SYS01-01 — duplicate good_id
		if seen_ids.has(def.good_id):
			errors.append(_err(ERR_SYS01_01, path, FIELD_GOOD_ID, def.good_id, "duplicate good_id"))
		else:
			seen_ids[def.good_id] = path

		# ERR-SYS01-02 — tier out of [1, TIER_MAX]
		if def.tier < TIER_MIN or def.tier > tier_max:
			errors.append(_err(ERR_SYS01_02, path, FIELD_TIER, def.tier, "tier out of [1, PRM-SYS01-TIER_MAX]"))

		# ERR-SYS01-03 — base_price_li <= 0
		if def.base_price_li <= 0:
			errors.append(_err(ERR_SYS01_03, path, FIELD_BASE_PRICE_LI, def.base_price_li, "base_price_li must be > 0"))

		if def.is_staple:
			var prev: int = int(staple_counts.get(def.name_zh, 0))
			staple_counts[def.name_zh] = prev + 1

	# ERR-SYS01-05 — staple set must be exactly LCR-23 four names, one each (FRM-SYS01-01)
	var required: PackedStringArray = _staple_names()
	for name in required:
		var n: int = int(staple_counts.get(name, 0))
		if n != 1:
			errors.append(_err(ERR_SYS01_05, GOODS_DIR, FIELD_STAPLE, name, "staple must appear exactly once: %s" % name))
	var staple_keys: Array = staple_counts.keys()
	staple_keys.sort()
	for key_variant in staple_keys:
		var key: String = String(key_variant)
		if not required.has(key):
			errors.append(_err(ERR_SYS01_05, GOODS_DIR, FIELD_STAPLE, key, "unexpected staple name_zh"))

	return errors


func _staple_names() -> PackedStringArray:
	return PackedStringArray([
		STAPLE_NAME_RICE,
		STAPLE_NAME_SALT,
		STAPLE_NAME_DRIED_FISH,
		STAPLE_NAME_TIMBER,
	])


func _list_tres_paths(dir_path: String, errors: Array) -> Array:
	var paths: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append(_err(CODE_DIR_OPEN, dir_path, "", DirAccess.get_open_error(), "cannot open goods directory"))
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(TRES_SUFFIX):
			paths.append("%s%s" % [dir_path, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


func _clear_state() -> void:
	_by_id = {}
	_ids_sorted = PackedStringArray()
	_loaded = false


func _err(code: StringName, file_path: String, field: String, value: Variant, message: String) -> Dictionary:
	# D-04 ErrorInfo = {code, sys, detail}; C-06 file/field/value live in detail.
	return ErrorInfoUtil.make_validation(code, SYS_ID, file_path, field, value, message)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("GoodCatalog: %s" % str(e))
