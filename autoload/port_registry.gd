extends Node
## Autoload: PortRegistry — loads res://data/ports/*.tres, owns ST-ROLE (TechSpec 3.3 / WP-04).
## _ready() only clears fields; load_and_validate() performs I/O and FRM checks (2.2-01).
## draft_limit_class stored on PortDef only — no validation / no logic (Owner B3 / 1-A5).
## WAREHOUSE / HOLD capacity are SYS-08 / SYS-13 — out of scope.
## Errors are D-04 ErrorInfo Dictionaries (shared with C-06); no ERR→int.
## D-02: queue_role_change(..., payload) rejects bad payload at enqueue.
## D-08b: port_id ^PT-[0-9]{2}$／name_zh strip非空；D-08c: get_port 未知 id → null＋last_error().

signal role_changed(port: String, good: String, old_role: int, new_role: int)

const PORTS_DIR := "res://data/ports/"
const TRES_SUFFIX := ".tres"

const SYS_ID := &"SYS-02"

## D-08b: named format constant (fixed width so string sort stays correct).
const PORT_ID_PATTERN := "^PT-[0-9]{2}$"

## Role enum ints — declaration order PRODUCER／TRANSIT／TERMINAL (03_Systems r261); no NONE.
## Numeric mapping not spelled in TechSpec H (unlike MarketPricer BUY=0); Godot enum order 0..n-1.
enum Role {
	PRODUCER,
	TRANSIT,
	TERMINAL,
}

const ROLE_PRODUCER := Role.PRODUCER
const ROLE_TRANSIT := Role.TRANSIT
const ROLE_TERMINAL := Role.TERMINAL

const PRM_PORT_COUNT_MIN := "PRM-SYS02-PORT_COUNT_MIN"
const PRM_PORT_COUNT_MAX := "PRM-SYS02-PORT_COUNT_MAX"
const PRM_FREE_PORT_RATIO_MIN := "PRM-SYS02-FREE_PORT_RATIO_MIN"
const PRM_FREE_PORT_RATIO_MAX := "PRM-SYS02-FREE_PORT_RATIO_MAX"

const ERR_SYS02_01 := &"ERR-SYS02-01"
const ERR_SYS02_02 := &"ERR-SYS02-02"
const ERR_SYS02_03 := &"ERR-SYS02-03"
const ERR_SYS02_04 := &"ERR-SYS02-04"
const ERR_SYS02_05 := &"ERR-SYS02-05"
const ERR_SYS02_06 := &"ERR-SYS02-06"
const ERR_SYS02_07 := &"ERR-SYS02-07"
const ERR_SYS02_08 := &"ERR-SYS02-08"
const ERR_SYS02_09 := &"ERR-SYS02-09"
const WRN_SYS02_01 := &"WRN-SYS02-01"

const CODE_PARAMS_NOT_LOADED := &"PARAMS_NOT_LOADED"
const CODE_GOOD_CATALOG_NOT_LOADED := &"GOOD_CATALOG_NOT_LOADED"
const CODE_LOAD_FAIL := &"LOAD_FAIL"
const CODE_LOAD_TYPE := &"LOAD_TYPE"
const CODE_NOT_LOADED := &"NOT_LOADED"
const CODE_DIR_OPEN := &"DIR_OPEN"
const CODE_DUPLICATE_PORT_ID := &"DUPLICATE_PORT_ID"

const FIELD_PORT_ID := "port_id"
const FIELD_NAME_ZH := "name_zh"
const FIELD_ROLE := "role"
const FIELD_DOWNSTREAM := "downstream_terminals"
const FIELD_OUTPUT := "base_output_per_season"
const FIELD_IS_FREE_PORT := "is_free_port"
const FIELD_PORT_COUNT := "port_count"
const FIELD_FREE_PORT_RATIO := "free_port_ratio"
const FIELD_ROLE_CELLS := "role_cells"
const FIELD_PARAMS := "Params"
const FIELD_GOOD_CATALOG := "GoodCatalog"
const FIELD_PAYLOAD := "payload"

const QUEUE_KEY_PORT := "port"
const QUEUE_KEY_GOOD := "good"
const QUEUE_KEY_NEW_ROLE := "new_role"
const QUEUE_KEY_PAYLOAD := "payload"

var _by_id: Dictionary = {}
var _ids_sorted: PackedStringArray = PackedStringArray()
var _loaded: bool = false
var _warnings: Array = []
var _role_change_queue: Array = []
## D-04／D-08c: last single-call ErrorInfo {code,sys,detail}; empty Dictionary when none.
var _last_error: Dictionary = {}
var _port_id_regex: RegEx = RegEx.new()


func _ready() -> void:
	var compile_err: int = _port_id_regex.compile(PORT_ID_PATTERN)
	assert(compile_err == OK, "PortRegistry PORT_ID_PATTERN must compile")
	_clear_state()


func load_and_validate(ports_dir: String = PORTS_DIR) -> Array:
	# C-06: collect every ErrorInfo; do not stop at the first.
	var errors: Array = []
	_clear_state()

	if not Params.is_loaded():
		errors.append(_err(CODE_PARAMS_NOT_LOADED, ports_dir, FIELD_PARAMS, null, "Params must load_and_validate before PortRegistry"))
		_emit_errors(errors)
		return errors

	if not GoodCatalog.is_loaded():
		errors.append(_err(CODE_GOOD_CATALOG_NOT_LOADED, ports_dir, FIELD_GOOD_CATALOG, null, "GoodCatalog must load_and_validate before PortRegistry"))
		_emit_errors(errors)
		return errors

	var dir_path := ports_dir
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
		if not (res is PortDef):
			errors.append(_err(CODE_LOAD_TYPE, path, "", res.get_class(), "expected PortDef Resource"))
			continue
		loaded.append({"path": path, "def": res as PortDef})

	errors.append_array(_validate_loaded(loaded))
	_warnings = _collect_warnings(loaded)

	if not errors.is_empty():
		_clear_state()
		_emit_errors(errors)
		return errors

	for item in loaded:
		var def: PortDef = item["def"]
		_by_id[def.port_id] = def

	var ids: Array = _by_id.keys()
	ids.sort()
	_ids_sorted = PackedStringArray(ids)
	_loaded = true
	return errors


func validate() -> Array:
	## Re-run FRM-SYS02-01 on the currently held registry (H observability).
	if not _loaded:
		return [_err(CODE_NOT_LOADED, PORTS_DIR, "", null, "PortRegistry.validate called before successful load")]
	var loaded: Array = []
	for id_variant in all_ids():
		var id: String = String(id_variant)
		var def: PortDef = _by_id[id]
		loaded.append({"path": PORTS_DIR, "def": def})
	return _validate_loaded(loaded)


func get_port(id: String) -> PortDef:
	# D-08c: unknown id → null + last_error ERR-SYS02-09; do not abort / do not return blank PortDef.
	assert(_loaded, "PortRegistry.get_port before successful load")
	_clear_last_error()
	if not _by_id.has(id):
		_record_error(ERR_SYS02_09, FIELD_PORT_ID, id, "unknown port_id")
		return null
	return _by_id[id] as PortDef


func last_error() -> Dictionary:
	# D-04／D-08c: single-call failures (get_port unknown id) expose ErrorInfo here.
	return _last_error.duplicate(true)


func get_role(port: String, good: String) -> int:
	assert(_loaded, "PortRegistry.get_role before successful load")
	var cell: RoleCell = _require_cell(port, good)
	return cell.role


func get_downstream(port: String, good: String) -> PackedStringArray:
	assert(_loaded, "PortRegistry.get_downstream before successful load")
	var cell: RoleCell = _require_cell(port, good)
	return cell.downstream_terminals.duplicate()


func producers_of(good: String) -> PackedStringArray:
	assert(_loaded, "PortRegistry.producers_of before successful load")
	return _ports_with_role(good, ROLE_PRODUCER)


func terminals_of(good: String) -> PackedStringArray:
	assert(_loaded, "PortRegistry.terminals_of before successful load")
	return _ports_with_role(good, ROLE_TERMINAL)


func all_ids() -> PackedStringArray:
	assert(_loaded, "PortRegistry.all_ids before successful load")
	return _ids_sorted


func is_loaded() -> bool:
	return _loaded


func get_warnings() -> Array:
	return _warnings.duplicate()


func queue_role_change(port_id: String, good_id: String, new_role: int, payload: Dictionary) -> Array:
	## EV-SYS02-ROLE_CHANGE / D-02 — enqueue with role payload; applied only via apply_queued_role_changes (2.3-05(a)).
	## Bad payload → reject immediately with ERR-SYS02-* ErrorInfo; do not enqueue (must not wait for cutoff).
	assert(_loaded, "PortRegistry.queue_role_change before successful load")
	assert(_by_id.has(port_id), "PortRegistry.queue_role_change unknown port: %s" % port_id)
	var def: PortDef = _by_id[port_id]
	assert(def.role_cells.has(good_id), "PortRegistry.queue_role_change unknown good cell: %s @ %s" % [good_id, port_id])

	var errors: Array = _validate_role_change_payload(new_role, payload)
	if not errors.is_empty():
		_emit_errors(errors)
		return errors

	_role_change_queue.append({
		QUEUE_KEY_PORT: port_id,
		QUEUE_KEY_GOOD: good_id,
		QUEUE_KEY_NEW_ROLE: new_role,
		QUEUE_KEY_PAYLOAD: payload.duplicate(true),
	})
	return errors


func apply_queued_role_changes() -> Array:
	## 2.3-05(a) / D-02: apply queue (payload fields), re-validate FRM-SYS02-01 (1)–(6) before commit; emit role_changed.
	assert(_loaded, "PortRegistry.apply_queued_role_changes before successful load")
	if _role_change_queue.is_empty():
		return []

	var pending: Array = _role_change_queue.duplicate(true)
	_role_change_queue.clear()

	# Snapshot role fields for rollback (C-06: reject whole apply on FRM failure).
	var snapshot: Dictionary = _snapshot_role_fields()
	var applied: Array = []

	for item_variant in pending:
		var item: Dictionary = item_variant
		var port: String = String(item[QUEUE_KEY_PORT])
		var good: String = String(item[QUEUE_KEY_GOOD])
		var new_role: int = int(item[QUEUE_KEY_NEW_ROLE])
		var payload: Dictionary = item[QUEUE_KEY_PAYLOAD]
		var cell: RoleCell = _require_cell(port, good)
		var old_role: int = cell.role
		_apply_role_payload(cell, new_role, payload)
		if old_role == new_role:
			# Still apply payload field updates even when role int unchanged.
			pass
		applied.append({
			QUEUE_KEY_PORT: port,
			QUEUE_KEY_GOOD: good,
			"old_role": old_role,
			QUEUE_KEY_NEW_ROLE: new_role,
		})

	var errors: Array = validate()
	if not errors.is_empty():
		_restore_role_fields(snapshot)
		_emit_errors(errors)
		return errors

	_warnings = _collect_warnings(_loaded_items_view())
	for change_variant in applied:
		var change: Dictionary = change_variant
		var old_role_emit: int = int(change["old_role"])
		var new_role_emit: int = int(change[QUEUE_KEY_NEW_ROLE])
		if old_role_emit == new_role_emit:
			continue
		role_changed.emit(
			String(change[QUEUE_KEY_PORT]),
			String(change[QUEUE_KEY_GOOD]),
			old_role_emit,
			new_role_emit
		)
	return errors


func _validate_role_change_payload(new_role: int, payload: Dictionary) -> Array:
	# D-02: missing / extra / wrong-type keys → ERR-SYS02 corresponding codes at enqueue.
	var errors: Array = []
	if not _is_valid_role(new_role):
		errors.append(_err(ERR_SYS02_01, PORTS_DIR, FIELD_ROLE, new_role, "role must be PRODUCER／TRANSIT／TERMINAL"))
		return errors

	var keys: Array = payload.keys()
	keys.sort()

	if new_role == ROLE_PRODUCER:
		for key_variant in keys:
			var key: String = String(key_variant)
			if key == FIELD_DOWNSTREAM:
				errors.append(_err(ERR_SYS02_02, PORTS_DIR, FIELD_DOWNSTREAM, payload[key], "PRODUCER payload must not contain downstream_terminals"))
			elif key != FIELD_OUTPUT:
				errors.append(_err(ERR_SYS02_01, PORTS_DIR, FIELD_PAYLOAD, key, "PRODUCER payload unknown key"))
		if not payload.has(FIELD_OUTPUT):
			errors.append(_err(ERR_SYS02_03, PORTS_DIR, FIELD_OUTPUT, null, "PRODUCER payload requires base_output_per_season > 0"))
		else:
			var output_variant: Variant = payload[FIELD_OUTPUT]
			if typeof(output_variant) != TYPE_INT:
				errors.append(_err(ERR_SYS02_03, PORTS_DIR, FIELD_OUTPUT, output_variant, "PRODUCER base_output_per_season must be int > 0"))
			elif int(output_variant) <= 0:
				errors.append(_err(ERR_SYS02_03, PORTS_DIR, FIELD_OUTPUT, output_variant, "PRODUCER base_output_per_season must be > 0"))
		return errors

	if new_role == ROLE_TRANSIT:
		for key_variant in keys:
			var key: String = String(key_variant)
			if key == FIELD_OUTPUT:
				errors.append(_err(ERR_SYS02_03, PORTS_DIR, FIELD_OUTPUT, payload[key], "TRANSIT payload must not contain base_output_per_season"))
			elif key != FIELD_DOWNSTREAM:
				errors.append(_err(ERR_SYS02_01, PORTS_DIR, FIELD_PAYLOAD, key, "TRANSIT payload unknown key"))
		if not payload.has(FIELD_DOWNSTREAM):
			errors.append(_err(ERR_SYS02_02, PORTS_DIR, FIELD_DOWNSTREAM, null, "TRANSIT payload requires non-empty downstream_terminals"))
		else:
			var down_variant: Variant = payload[FIELD_DOWNSTREAM]
			var downs: PackedStringArray = PackedStringArray()
			var type_ok: bool = false
			if typeof(down_variant) == TYPE_PACKED_STRING_ARRAY:
				downs = down_variant
				type_ok = true
			elif typeof(down_variant) == TYPE_ARRAY:
				type_ok = true
				for item in down_variant:
					if typeof(item) != TYPE_STRING:
						type_ok = false
						break
					downs.append(String(item))
			if not type_ok:
				errors.append(_err(ERR_SYS02_02, PORTS_DIR, FIELD_DOWNSTREAM, down_variant, "TRANSIT downstream_terminals must be string array"))
			elif downs.is_empty():
				errors.append(_err(ERR_SYS02_02, PORTS_DIR, FIELD_DOWNSTREAM, downs, "TRANSIT downstream_terminals must be non-empty"))
		return errors

	# TERMINAL: payload must be empty.
	for key_variant in keys:
		var key: String = String(key_variant)
		if key == FIELD_OUTPUT:
			errors.append(_err(ERR_SYS02_03, PORTS_DIR, FIELD_OUTPUT, payload[key], "TERMINAL payload must be empty (no base_output_per_season)"))
		elif key == FIELD_DOWNSTREAM:
			errors.append(_err(ERR_SYS02_02, PORTS_DIR, FIELD_DOWNSTREAM, payload[key], "TERMINAL payload must be empty (no downstream_terminals)"))
		else:
			errors.append(_err(ERR_SYS02_01, PORTS_DIR, FIELD_PAYLOAD, key, "TERMINAL payload must be empty"))
	return errors


func _apply_role_payload(cell: RoleCell, new_role: int, payload: Dictionary) -> void:
	# D-02: payload supplies required fields; clear non-applicable role fields (not a substitute for payload).
	cell.role = new_role
	if new_role == ROLE_PRODUCER:
		cell.base_output_per_season = int(payload[FIELD_OUTPUT])
		cell.downstream_terminals = PackedStringArray()
	elif new_role == ROLE_TRANSIT:
		cell.base_output_per_season = 0
		var down_variant: Variant = payload[FIELD_DOWNSTREAM]
		if typeof(down_variant) == TYPE_PACKED_STRING_ARRAY:
			cell.downstream_terminals = (down_variant as PackedStringArray).duplicate()
		else:
			var downs := PackedStringArray()
			for item in down_variant:
				downs.append(String(item))
			cell.downstream_terminals = downs
	else:
		cell.base_output_per_season = 0
		cell.downstream_terminals = PackedStringArray()


func _validate_loaded(loaded: Array) -> Array:
	# FRM-SYS02-01 (1)–(6)
	var errors: Array = []
	var port_count_min: int = Params.get_int(PRM_PORT_COUNT_MIN)
	var port_count_max: int = Params.get_int(PRM_PORT_COUNT_MAX)
	var free_ratio_min: float = Params.get_float(PRM_FREE_PORT_RATIO_MIN)
	var free_ratio_max: float = Params.get_float(PRM_FREE_PORT_RATIO_MAX)
	var good_ids: PackedStringArray = GoodCatalog.all_ids()

	var count: int = loaded.size()
	# ERR-SYS02-05 — port count out of [PORT_COUNT_MIN, PORT_COUNT_MAX]
	if count < port_count_min or count > port_count_max:
		errors.append(_err(ERR_SYS02_05, PORTS_DIR, FIELD_PORT_COUNT, count, "port count out of PRM-SYS02 range"))

	var seen_ids: Dictionary = {}
	var free_count: int = 0

	# Deterministic order by port_id then path (C-08).
	var ordered: Array = loaded.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var id_a: String = (a["def"] as PortDef).port_id
		var id_b: String = (b["def"] as PortDef).port_id
		if id_a == id_b:
			return String(a["path"]) < String(b["path"])
		return id_a < id_b
	)

	var by_port: Dictionary = {}
	for item in ordered:
		var path: String = String(item["path"])
		var def: PortDef = item["def"]

		# D-08b: port_id must match PORT_ID_PATTERN (^PT-[0-9]{2}$).
		if not _is_valid_port_id(def.port_id):
			errors.append(_err(ERR_SYS02_07, path, FIELD_PORT_ID, def.port_id, "port_id must match PORT_ID_PATTERN"))

		if seen_ids.has(def.port_id):
			errors.append(_err(CODE_DUPLICATE_PORT_ID, path, FIELD_PORT_ID, def.port_id, "duplicate port_id"))
		else:
			seen_ids[def.port_id] = path
			by_port[def.port_id] = def

		# D-08b: name_zh strip_edges 後不得為空 → ERR-SYS02-08.
		if def.name_zh.strip_edges().is_empty():
			errors.append(_err(ERR_SYS02_08, path, FIELD_NAME_ZH, def.name_zh, "name_zh must be non-empty after strip"))

		if def.is_free_port:
			free_count += 1

		errors.append_array(_validate_role_cells_for_port(def, path, good_ids))

	# ERR-SYS02-06 — free port ratio out of range (skip ratio when count is 0).
	if count > 0:
		var ratio: float = float(free_count) / float(count)
		if ratio < free_ratio_min or ratio > free_ratio_max:
			errors.append(_err(ERR_SYS02_06, PORTS_DIR, FIELD_FREE_PORT_RATIO, ratio, "free port ratio out of PRM-SYS02 range"))

	# FRM-SYS02-01 (2) downstream TERMINAL checks need cross-port lookup.
	errors.append_array(_validate_transit_downstreams(ordered, by_port))

	# FRM-SYS02-01 (4) each good ≥1 PRODUCER and ≥1 TERMINAL.
	errors.append_array(_validate_good_role_coverage(ordered, good_ids))

	return errors


func _validate_role_cells_for_port(def: PortDef, path: String, good_ids: PackedStringArray) -> Array:
	var errors: Array = []
	var cells: Dictionary = def.role_cells

	# FRM-SYS02-01 (1): exactly one role per port × good (no NONE / missing / invalid).
	for good_variant in good_ids:
		var good_id: String = String(good_variant)
		if not cells.has(good_id):
			errors.append(_err(ERR_SYS02_01, path, FIELD_ROLE_CELLS, good_id, "missing RoleCell for good (no NONE)"))
			continue
		var cell_variant: Variant = cells[good_id]
		if not (cell_variant is RoleCell):
			errors.append(_err(ERR_SYS02_01, path, FIELD_ROLE, good_id, "role_cells value is not RoleCell"))
			continue
		var cell: RoleCell = cell_variant
		if not _is_valid_role(cell.role):
			errors.append(_err(ERR_SYS02_01, path, FIELD_ROLE, cell.role, "role must be PRODUCER／TRANSIT／TERMINAL"))

		# FRM-SYS02-01 (3): PRODUCER output > 0; others = 0.
		if cell.role == ROLE_PRODUCER:
			if cell.base_output_per_season <= 0:
				errors.append(_err(ERR_SYS02_03, path, FIELD_OUTPUT, cell.base_output_per_season, "PRODUCER base_output_per_season must be > 0"))
		else:
			if cell.base_output_per_season != 0:
				errors.append(_err(ERR_SYS02_03, path, FIELD_OUTPUT, cell.base_output_per_season, "non-PRODUCER base_output_per_season must be 0"))

		# TRANSIT must have ≥1 downstream (existence); target role checked in cross-port pass.
		if cell.role == ROLE_TRANSIT:
			if cell.downstream_terminals.is_empty():
				errors.append(_err(ERR_SYS02_02, path, FIELD_DOWNSTREAM, good_id, "TRANSIT requires ≥1 downstream_terminals"))
		else:
			if not cell.downstream_terminals.is_empty():
				# Spec: downstream only for TRANSIT; treat stray list as ERR-SYS02-02 family.
				errors.append(_err(ERR_SYS02_02, path, FIELD_DOWNSTREAM, good_id, "downstream_terminals only allowed on TRANSIT"))

	# Extra goods not in catalog → reject (exactly one per catalog good implies no extras).
	var cell_keys: Array = cells.keys()
	cell_keys.sort()
	for key_variant in cell_keys:
		var key: String = String(key_variant)
		if not good_ids.has(key):
			errors.append(_err(ERR_SYS02_01, path, FIELD_ROLE_CELLS, key, "RoleCell good_id not in GoodCatalog"))

	return errors


func _validate_transit_downstreams(ordered: Array, by_port: Dictionary) -> Array:
	var errors: Array = []
	for item in ordered:
		var path: String = String(item["path"])
		var def: PortDef = item["def"]
		var cell_keys: Array = def.role_cells.keys()
		cell_keys.sort()
		for good_variant in cell_keys:
			var good_id: String = String(good_variant)
			var cell_variant: Variant = def.role_cells[good_id]
			if not (cell_variant is RoleCell):
				continue
			var cell: RoleCell = cell_variant
			if cell.role != ROLE_TRANSIT:
				continue
			var downs: PackedStringArray = cell.downstream_terminals
			for i in range(downs.size()):
				var down_id: String = downs[i]
				if down_id == def.port_id:
					errors.append(_err(ERR_SYS02_02, path, FIELD_DOWNSTREAM, down_id, "TRANSIT downstream must not be self"))
					continue
				if not by_port.has(down_id):
					errors.append(_err(ERR_SYS02_02, path, FIELD_DOWNSTREAM, down_id, "TRANSIT downstream port unknown"))
					continue
				var down_def: PortDef = by_port[down_id]
				if not down_def.role_cells.has(good_id):
					errors.append(_err(ERR_SYS02_02, path, FIELD_DOWNSTREAM, down_id, "TRANSIT downstream missing RoleCell for good"))
					continue
				var down_cell_variant: Variant = down_def.role_cells[good_id]
				if not (down_cell_variant is RoleCell):
					errors.append(_err(ERR_SYS02_02, path, FIELD_DOWNSTREAM, down_id, "TRANSIT downstream cell not RoleCell"))
					continue
				var down_cell: RoleCell = down_cell_variant
				if down_cell.role != ROLE_TERMINAL:
					errors.append(_err(ERR_SYS02_02, path, FIELD_DOWNSTREAM, down_id, "TRANSIT downstream must be TERMINAL for good"))
	return errors


func _validate_good_role_coverage(ordered: Array, good_ids: PackedStringArray) -> Array:
	var errors: Array = []
	for good_variant in good_ids:
		var good_id: String = String(good_variant)
		var producer_n: int = 0
		var terminal_n: int = 0
		for item in ordered:
			var def: PortDef = item["def"]
			if not def.role_cells.has(good_id):
				continue
			var cell_variant: Variant = def.role_cells[good_id]
			if not (cell_variant is RoleCell):
				continue
			var cell: RoleCell = cell_variant
			if cell.role == ROLE_PRODUCER:
				producer_n += 1
			elif cell.role == ROLE_TERMINAL:
				terminal_n += 1
		if producer_n < 1 or terminal_n < 1:
			errors.append(_err(
				ERR_SYS02_04,
				PORTS_DIR,
				FIELD_ROLE,
				good_id,
				"each good needs ≥1 PRODUCER and ≥1 TERMINAL (producers=%d terminals=%d)" % [producer_n, terminal_n]
			))
	return errors


func _collect_warnings(loaded: Array) -> Array:
	# FRM-SYS02-02 / WRN-SYS02-01 — free port + controlled_scale_only PRODUCER (warn only).
	var warnings: Array = []
	if not GoodCatalog.is_loaded():
		return warnings
	var ordered: Array = loaded.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["def"] as PortDef).port_id < (b["def"] as PortDef).port_id
	)
	for item in ordered:
		var path: String = String(item["path"])
		var def: PortDef = item["def"]
		if not def.is_free_port:
			continue
		var cell_keys: Array = def.role_cells.keys()
		cell_keys.sort()
		for good_variant in cell_keys:
			var good_id: String = String(good_variant)
			if not GoodCatalog.all_ids().has(good_id):
				continue
			var cell_variant: Variant = def.role_cells[good_id]
			if not (cell_variant is RoleCell):
				continue
			var cell: RoleCell = cell_variant
			if cell.role != ROLE_PRODUCER:
				continue
			var good_def: GoodDef = GoodCatalog.get_good(good_id)
			if good_def.controlled_scale_only:
				warnings.append(_err(WRN_SYS02_01, path, FIELD_ROLE, good_id, "free port PRODUCER on controlled_scale_only good"))
	return warnings


func _snapshot_role_fields() -> Dictionary:
	var snap: Dictionary = {}
	for id_variant in all_ids():
		var port_id: String = String(id_variant)
		var def: PortDef = _by_id[port_id]
		var port_snap: Dictionary = {}
		var keys: Array = def.role_cells.keys()
		keys.sort()
		for good_variant in keys:
			var good_id: String = String(good_variant)
			var cell: RoleCell = def.role_cells[good_id]
			port_snap[good_id] = {
				FIELD_ROLE: cell.role,
				FIELD_OUTPUT: cell.base_output_per_season,
				FIELD_DOWNSTREAM: cell.downstream_terminals.duplicate(),
			}
		snap[port_id] = port_snap
	return snap


func _restore_role_fields(snapshot: Dictionary) -> void:
	var port_keys: Array = snapshot.keys()
	port_keys.sort()
	for port_variant in port_keys:
		var port_id: String = String(port_variant)
		var def: PortDef = _by_id[port_id]
		var port_snap: Dictionary = snapshot[port_id]
		var good_keys: Array = port_snap.keys()
		good_keys.sort()
		for good_variant in good_keys:
			var good_id: String = String(good_variant)
			var cell: RoleCell = def.role_cells[good_id]
			var cell_snap: Dictionary = port_snap[good_id]
			cell.role = int(cell_snap[FIELD_ROLE])
			cell.base_output_per_season = int(cell_snap[FIELD_OUTPUT])
			cell.downstream_terminals = PackedStringArray(cell_snap[FIELD_DOWNSTREAM])


func _loaded_items_view() -> Array:
	var loaded: Array = []
	for id_variant in all_ids():
		var id: String = String(id_variant)
		loaded.append({"path": PORTS_DIR, "def": _by_id[id]})
	return loaded


func _ports_with_role(good: String, role: int) -> PackedStringArray:
	var ports: Array = []
	for id_variant in all_ids():
		var port_id: String = String(id_variant)
		var def: PortDef = _by_id[port_id]
		if not def.role_cells.has(good):
			continue
		var cell: RoleCell = def.role_cells[good]
		if cell.role == role:
			ports.append(port_id)
	ports.sort()
	return PackedStringArray(ports)


func _require_cell(port: String, good: String) -> RoleCell:
	assert(_by_id.has(port), "PortRegistry unknown port: %s" % port)
	var def: PortDef = _by_id[port]
	assert(def.role_cells.has(good), "PortRegistry unknown good cell: %s @ %s" % [good, port])
	return def.role_cells[good] as RoleCell


func _is_valid_role(role: int) -> bool:
	return role == ROLE_PRODUCER or role == ROLE_TRANSIT or role == ROLE_TERMINAL


func _is_valid_port_id(port_id: String) -> bool:
	# D-08b: full-string match against named PORT_ID_PATTERN.
	var m: RegExMatch = _port_id_regex.search(port_id)
	return m != null and m.get_string() == port_id


func _list_tres_paths(dir_path: String, errors: Array) -> Array:
	var paths: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		errors.append(_err(CODE_DIR_OPEN, dir_path, "", DirAccess.get_open_error(), "cannot open ports directory"))
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
	_warnings = []
	_role_change_queue = []
	_clear_last_error()


func _clear_last_error() -> void:
	_last_error = {}


func _record_error(code: StringName, field: String, value: Variant, message: String) -> void:
	_last_error = _err(code, PORTS_DIR, field, value, message)


func _err(code: StringName, file_path: String, field: String, value: Variant, message: String) -> Dictionary:
	# D-04 ErrorInfo = {code, sys, detail}; C-06 file/field/value live in detail.
	return ErrorInfoUtil.make_validation(code, SYS_ID, file_path, field, value, message)


func _emit_errors(errors: Array) -> void:
	for e in errors:
		push_error("PortRegistry: %s" % str(e))
